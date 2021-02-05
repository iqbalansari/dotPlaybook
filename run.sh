#!/bin/sh

ANSIBLE_VERSION=2.5

repo=iqbalansari/dotPlaybook
repo_url=https://github.com/$repo
ansible_args=''

if [ -z "$PLAYBOOK_DIR" ] ;
then
    repo_dir=~/.playbook
else
    repo_dir=$PLAYBOOK_DIR
fi

exists () {
    which $1 1> /dev/null 2>&1
}

log () {
    local message="$1"
    local type="$2"
    local priority="$3"

    local bold=0
    if [ "$priority" = 'high' ] ; then
        bold=1
    fi

    case $type in
        normal) echo $message ;;
        error)  echo "\033[$bold;31m$message\033[0m" ;;
        info)   echo "\033[$bold;32m$message\033[0m" ;;
        change) echo "\033[$bold;33m$message\033[0m" ;;
        warn)   echo "\033[$bold;34m$message\033[0m" ;;
        *)      echo $message ;;
    esac
}

determine_system () {
    if ! (exists uname)
    then
        log "'uname' does not exist, cannot determine OS version, aborting ..." error high
        exit 1
    fi

    local system="$(uname)"

    case "$system" in
        Linux)
            if [ -f /etc/os-release ]; then
                echo "$(grep '^ID=' /etc/os-release | cut -d= -f 2)"

            else
                log "Unsupported Linux distro, aborting ..." error high
                exit 1
            fi
        ;;
        Darwin)
            echo "macos"
            ;;
        *)
            log "Do not how to run on '$system'" error high
            exit 1
            ;;
    esac
}

update_apt_cache_if_needed () {
    local now=$(date +%s)
    local last_apt_update=0

    if [ -f /var/lib/apt/periodic/update-success-stamp ]
    then
        last_apt_update=$(stat --printf '%Y' /var/lib/apt/periodic/update-success-stamp)
    fi

    if [ $((now - last_apt_update)) -gt 604800 ]
    then
        log "apt cache is older than a week, updating now ... " warn low
        sudo apt-get update
    fi
}

apt_installed () {
    local retval=1

    if dpkg-query -W -f='${Status}' $1 2>/dev/null | grep "ok installed" > /dev/null 2>&1
    then
        if [ -z $2 ]
        then
            retval=0
        else
            if dpkg --compare-versions $(dpkg-query -W -f='${Version}' $1 2>/dev/null) ge $2
            then
                retval=0
            else
                retval=1
            fi
        fi
    else
        retval=1
    fi

    return "$retval"
}

apt_install () {
    log "Installing $1 ... " info high

    if [ $# -ge 3 ]
    then
        local pkg=$1
        local version=$2
        local ppa=$3
    else
        local pkg=$1
        local version=0
        local ppa=$2
    fi

    if ! apt_installed "$pkg" "$version"
    then
        if [ -n "$ppa" ]
        then
            log "Adding PPA for $pkg ... " normal low
            sudo apt-add-repository -y "$ppa" || exit 1
            log "Updating package archives $pkg ... " normal low
            sudo apt-get update || exit 1
        else
            update_apt_cache_if_needed
        fi

        log "$pkg not installed, installing ... "
        if [ "$version" = "0" ]
        then
            sudo apt-get install --no-install-recommends --assume-yes "$pkg" || exit 1
        else
            sudo apt-get install --no-install-recommends --assume-yes "$pkg=$version*" || exit 1
        fi

        log "$1 installed" change high
    else
        log "$1 is already installed, skipping ... " normal low
    fi
}

install_system_dependencies_ubuntu () {
    apt_install python3
    apt_install python3-pip
    apt_install python3-setuptools
    apt_install python3-apt
    apt_install python3-dev

    apt_install software-properties-common

    apt_install git
}

install_system_dependencies_macos () {
    log "Installing brew ... " info high
    if ! (exists brew)
    then
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        log "brew installed" change high
    else
        log "brew is already installed, skipping ... " normal low
    fi

    log "Installing git ... " info high
    if ! (exists git)
    then
        brew install git
        log "git installed" change high
    else
        log "git is already installed, skipping ... " normal low
    fi

    log "Installing python3 ... " info high
    if ! (exists python3)
    then
        brew install python3
        log "python3 installed" change high
    else
        log "python3 is already installed, skipping ... " normal low
    fi

}

ensure_system_dependencies () {
    # Make sure we are in the directory containing the script
    cd `dirname $0`

    local system=$(determine_system)

    log "Installing system dependencies for '$system'" info high

    if type "install_system_dependencies_$system" > /dev/null; then
        eval "install_system_dependencies_$system"
    else
        log "Do not know how to install system dependencies on '$system', aborting ..." error high
        exit 1
    fi
}

pull_playbook () {
    # Make sure we are in the directory containing the script
    cd `dirname $0`

    local origin=$(git config --get remote.origin.url)
    local release=$(determine_system)

    # Go to the directory containing the repo
    if (test "${origin#*$repo}" = "$origin")
    then
        # If we are not in a cloned copy, first clone the repo
        log "Pulling the playbook ... " info high
        if [ -d $repo_dir ]
        then
            # If the repo already exists just cd to it
            read -p "Found '$repo_dir', is it a previously cloned copy of the playbook [y/n]? " answer < /dev/tty
            if echo "$answer" | grep -iq "^y"
            then
                log "Run the script from the cloned repo, to avoid this check" info low
                cd $repo_dir

            else
                log "Cannot clone repo since '$repo_dir' already exists" error high
                log "You can specify the directory to install dotfiles with -d" error high
                log "Aborting ... " error high
                exit

            fi
        else
            # Otherwise clone it
            log "Cloning playbook in $repo_dir directory ... " change low
            git clone $repo_url $repo_dir
            cd $repo_dir
        fi
    fi

    # Pull the latest changes
    log "Getting latest changes ... " info high
    if ! (git pull --rebase)
    then
        log "Could not fetch latest changes, skipping" warn high
    fi
}

get_python3_path() {
    local system=$(determine_system)

    if (test "$system" = "macos")
    then 
        echo "$(brew --prefix python3)/bin/python3"
    else
        echo "$(which python3)"
    fi
}

install_ansible () {
    log "Checking ansible ... " info high
    if (test -f .venv/bin/pip3) && (.venv/bin/pip3 freeze | grep -q ansible=="$ANSIBLE_VERSION") ; then
        log "ansible is already installed, skipping ... " normal low
        return 0
    fi

    # Delete existing .venv/
    rm -rf .venv/

    log "Installing virtualenv ... " info high
    if ! (exists virtualenv) ; then
        sudo pip3 install virtualenv
        log "virtualenv installed" change high
    else
        log "virtualenv is already installed, skipping ... " normal low
    fi

    # Create a virtualenv for installing the required version of ansible
    log "Creating virtualenv ... " info high
    if ! (test -f .venv/bin/pip3) ; then
        virtualenv -p "$(get_python3_path)" --system-site-packages .venv
        log "virtualenv created" change high
    else
        log "virtualenv already created, skipping ... " normal low
    fi

    log "Installing ansible inside virtualenv ... " info high
    if ! (test -f .venv/bin/ansible-playbook) || ! (.venv/bin/pip freeze | grep -q ansible=="$ANSIBLE_VERSION") ; then
        .venv/bin/pip install --ignore-installed ansible=="$ANSIBLE_VERSION"
        log "ansible installed inside virtualenv" change high
    fi
}

run_ansible () {
    log "Running the playbook ... " info high
    log ".venv/bin/ansible-playbook playbook.yaml --ask-sudo-pass $ansible_args" info
    eval exec ".venv/bin/ansible-playbook playbook.yaml --ask-sudo-pass $ansible_args"
}

main () {
    for i in "$@" ; do
        case $i in
            -d=*)
                repo_dir="${i#*=}"
                ;;
            *)
                ansible_args="$ansible_args '$i'"
                ;;
        esac
    done

    ensure_system_dependencies
    pull_playbook
    install_ansible
    run_ansible
}

main "$@"
