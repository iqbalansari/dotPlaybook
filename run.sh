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

ensure_system_dependencies () {
    # Make sure we are in the directory containing the script
    cd `dirname $0`

    local system=$(determine_system)

    log "Installing system dependencies for '$system'" info high

    if (exists git)
    then
        local origin="$(git config --get remote.origin.url)"

        if (test "${origin#*$repo}" != "$origin")
        then
            log "Installing system dependencies for '$system' from cloned repository" info low
            . "install-$system-dependencies.sh"

        else
            fetch_system_dependencies_script

        fi
    else
        fetch_system_dependencies_script
    fi

    # This function is exposed by the system-dependencies.sh script
    install_system_dependencies
}

fetch_system_dependencies_script () {
    local system=$(determine_system)

    log "Fetching script to install system dependencies from '$system'" info low

    if ! eval "$(curl -fsL https://raw.githubusercontent.com/$repo/master/install-$system-dependencies.sh || echo 'false')"
    then
        log "Could fetch the script to install system dependencies for '$system' aborting ..." error high
        exit 1
    else
        log "Successfully fetched the script to install system dependencies for '$system'" change low
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
    if ! (test -f .venv/bin/pip3)  ; then
        virtualenv -p $(which python3) --system-site-packages .venv
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
