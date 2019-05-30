#!/bin/sh

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
            sudo apt-get install -y "$pkg" || exit 1
        else
            sudo apt-get install -y "$pkg=$version*" || exit 1
        fi

        log "$1 installed" change high
    else
        log "$1 is already installed, skipping ... " normal low
    fi
}

install_system_dependencies () {
    apt_install python3
    apt_install python3-pip
    apt_install python3-apt

    if (test "$(lsb_release -c | awk '{print $2}')" = "bionic")
    then
        apt_install software-properties-common
    else
        apt_install python-software-properties
    fi

    apt_install python3-dev
    apt_install git
}
