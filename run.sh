#!/bin/sh

repo=iqbalansari/dotPlaybook
repo_url=https://github.com/$repo

if [ -z "$PLAYBOOK_DIR" ] ;
then
    repo_dir=~/dotPlaybook
else
    repo_dir=$PLAYBOOK_DIR
fi

update_apt_cache_if_needed () {
    local now=$(date +%s)
    local last_apt_update=0

    if [ -f /var/cache/apt/pkgcache.bin ]
    then
        last_apt_update=$(stat --printf '%Y' /var/cache/apt/pkgcache.bin)
    fi

    if [ $((now - last_apt_update)) -gt 604800 ]
    then
        echo "apt cache is older than a week, updating now ... "
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
    echo "Installing $1 ... "

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
            sudo apt-add-repository -y "$ppa"
            sudo apt-get update
        else
            update_apt_cache_if_needed
        fi

        sudo apt-get install -y "$pkg"
        echo "$1 installed"
    else
        echo "$1 is already installed, skipping ... "
    fi
}

parse_arguments () {
    if [ "$1" = "-d" ] && [ -n "$2" ]
    then
        repo_dir="$2"
    fi
}

install_dependencies () {
    apt_install python-software-properties
    apt_install git
    apt_install ansible 1.9.1 ppa:ansible/ansible
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
        echo "Pulling the playbook ... "
        if [ -d $repo_dir ]
        then
            # If the repo already exists just cd to it
            read -p "Found '$repo_dir', is it a previously cloned copy of the playbook [y/n]? " answer < /dev/tty
            if echo "$answer" | grep -iq "^y"
            then
                echo "Run the script from the cloned repo, to avoid this check"
                cd $repo_dir

            else
                echo "Cannot clone repo since '$repo_dir' already exists"
                echo "You can specify the directory to install dotfiles with -d"
                echo "Aborting ... "
                exit

            fi
        else
            # Otherwise clone it
            echo "Cloning playbook in $repo_dir directory ... "
            git clone $repo_url $repo_dir
            cd $repo_dir
        fi
    fi

    # Get the branch for the release
    # Check if branch exists for the release
    echo "Switching to branch for current release"

    # If it exists locally
    if git rev-parse -q --verify "$release" > /dev/null
    then
        # Just checkout to it
        if ! (git checkout -q "$release")
        then
            echo "Failed to checkout to branch for release '$release', aborting ... "
            exit
        fi
    # Else check if the repo exists at remote
    elif git ls-remote --exit-code origin "$release" > /dev/null
    then
        # And create a local branch
        if ! (git checkout -q -b "$release" "origin/$release")
        then
            echo "Failed to checkout to branch for release '$release', aborting ... "
            exit
        fi
    else
        echo "No branch exists for '$release'"
        echo "Aborting ... "
    fi

    # Pull the latest changes
    echo "Getting latest changes ... "
    if ! (git pull -q)
    then
        echo "There were some errors while pulling, please fix them, aborting"
        exit
    fi
}

run_ansible () {
    echo "Running the playbook ... "
    ansible-playbook playbook.yaml --ask-sudo-pass
}

main () {
    parse_arguments $*
    install_dependencies
    pull_playbook
    run_ansible
}

main $*
