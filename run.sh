#!/bin/sh

repo_url=https://github.com/iqbalansari/pc-config.git
repo_dir=~/dotfiles

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

    if ! installed "$pkg"  "$version"
    then
        if [ -n "$ppa" ]
        then
            sudo apt-add-repository -y "$ppa"
            sudo apt-get update
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
    apt_install software-properties-common
    apt_install git
    apt_install ansible 1.9.1 ppa:ansible/ansible
}

pull_playbook () {
    # Make sure we are in the directory containing the script
    cd `dirname $0`
    
    if [ -d .git ]
    then
        # If we are already in a cloned repo pull the latest changes
        echo "Getting latest changes ... "
        if ! (git pull) 
        then
            echo "There were some errors while pulling, please fix them, aborting"
            exit
        fi
    else
        # Otherwise we need to clone repo, before pulling check
        # if the repo already exists
        echo "Pulling the playbook ... "
        if [ -d $repo_dir ]
        then
            read -p "Found '$repo_dir', is it the a previously cloned copy of the playbook [y/n]? " answer < /dev/tty
            if echo "$answer" | grep -iq "^y"
            then
                echo "Run the script from the cloned repo, to avoid this check"
                echo "Getting latest changes ... "
                cd $repo_dir
                if ! (git pull) 
                then
                    echo "There were some errors while pulling, please fix them, aborting"
                    exit
                fi
            else
                echo "Cannot clone repo since '$repo_dir' already exists"
                echo "You can specify the directory to install dotfiles with -d"
                echo "Aborting ... "
                exit
            fi
        else
            echo "Cloning playbook in $repo_dir directory ... "
            git clone $repo_url $repo_dir
            cd $repo_dir
        fi
    fi
}

run_ansible () {
    ansible-playbook playbook.yaml --ask-sudo-pass
}

main () {
    parse_arguments $*
    install_dependencies
    pull_playbook
    run_ansible
}

main $*
