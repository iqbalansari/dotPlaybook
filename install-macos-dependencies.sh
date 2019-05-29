#!/bin/sh

install_system_dependencies () {
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
