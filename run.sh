#!/bin/sh

ANSIBLE_VERSION=2.3

repo=iqbalansari/dotPlaybook
repo_url=https://github.com/$repo
ansible_args=''

if [ -z "$PLAYBOOK_DIR" ] ;
then
    repo_dir=~/dotPlaybook
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

update_apt_cache_if_needed () {
    local now=$(date +%s)
    local last_apt_update=0

    if [ -f /var/cache/apt/pkgcache.bin ]
    then
        last_apt_update=$(stat --printf '%Y' /var/cache/apt/pkgcache.bin)
    fi

    if [ $((now - last_apt_update)) -gt 604800 ]
    then
        log "apt cache is older than a week, updating now ... " warn low
        sudo apt-get update
    fi
}

installed () {
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

    if ! installed "$pkg" "$version"
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
            sudo apt-get install -y "$pkg" || exit 1
        else
            sudo apt-get install -y "$pkg=$version*" || exit 1
        fi

        log "$1 installed" change high
    else
        log "$1 is already installed, skipping ... " normal low
    fi
}

install_ansible () {
    cd `dirname $0`

    log "Installing ansible ... " info high

    if (test -f venv/bin/pip) && (venv/bin/pip freeze | grep -q ansible=="$ANSIBLE_VERSION") ; then
        log "ansible is already installed, skipping ... " normal low
        return 0
    fi

    if ! (exists virtualenv) ; then
        log "Installing virtualenv ... " info low
        sudo pip2 install virtualenv
    fi

    # Create a virtualenv for installing the required version of ansible
    if ! (test -f venv/bin/pip)  ; then
        log "Creating virtualenv ... " info low
        virtualenv -p $(which python2) --system-site-packages venv
    fi

    if ! (test -f venv/bin/ansible-playbook) || ! (venv/bin/pip freeze | grep -q ansible=="$ANSIBLE_VERSION") ; then
        log "Installing ansible inside virtualenv ... " info low
        venv/bin/pip install --ignore-installed ansible==2.3
    fi
}

install_system_dependencies () {
    apt_install python2.7
    apt_install python-apt
    apt_install python-software-properties
    apt_install git
}

pull_playbook () {
    # Make sure we are in the directory containing the script
    cd `dirname $0`

    local origin=$(git config --get remote.origin.url)
    local release=$(lsb_release -c -s)

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

    # Get the branch for the release
    # Check if branch exists for the release
    log "Switching to branch for current release" info high

    # If it exists locally
    if git rev-parse -q --verify "$release" > /dev/null
    then
        # Just checkout to it
        if ! (git checkout -q "$release")
        then
            log "Failed to checkout to branch for release '$release', aborting ... " error high
            exit
        fi
    # Else check if the repo exists at remote
    elif git ls-remote --exit-code origin "$release" > /dev/null
    then
        # And create a local branch
        if ! (git checkout -q -b "$release" "origin/$release")
        then
            log "Failed to checkout to branch for release '$release', aborting ... " error high
            exit
        fi
    else
        error "No branch exists for '$release'" high
        error "Aborting ... " high
    fi

    # Pull the latest changes
    log "Getting latest changes ... " normal low
    if ! (git pull -q)
    then
        log "There were some errors while pulling, please fix them, aborting" error high
        exit
    fi
}

run_ansible () {
    cd `dirname $0`

    log "Running the playbook ... " info high
    eval exec "venv/bin/ansible-playbook playbook.yaml --ask-sudo-pass $ansible_args"
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

    install_system_dependencies
    install_ansible
    pull_playbook
    run_ansible
}

main "$@"
