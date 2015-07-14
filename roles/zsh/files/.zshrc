#!/bin/zsh

# Make the shell aware of locally installed packages
export PATH="$HOME/local_packages/bin:$HOME/local_packages/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/bin:$PATH"
export PKG_CONFIG_PATH="$HOME/local_packages/lib/pkgconfig"
export LD_LIBRARY_PATH="$HOME/local_packages/lib:"
export ACLOCAL_PATH="$HOME/local_packages/share/aclocal/"
export MANPATH="$HOME/local_packages/share/man:"

# Locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

function exists { which $1 &> /dev/null }

if exists tmux && [[ -z $TMUX && -z $INSIDE_EMACS && -o interactive && -n $TERM && "$TERM" != "dumb" && "$TERM" != "linux" ]] ;
then
    # Attach to existing session
    if tmux list-sessions > /dev/null 2>&1;
    then
        tmux attach
        exit
    else
        exec tmux
    fi
fi

source "$HOME/software/antigen/antigen.zsh"

antigen use oh-my-zsh

antigen bundle robbyrussell/oh-my-zsh
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle Tarrasch/zsh-bd
antigen bundle colored-man

antigen theme ys

antigen apply

# Fancy history search
if exists percol && [ -z $INSIDE_EMACS ];
then
    function percol_select_history() {
        local tac
        exists gtac && tac="gtac" || { exists tac && tac="tac" || { tac="tail -r" } }
        BUFFER=$(fc -l -n 1 | eval $tac | percol --query "$LBUFFER")
        CURSOR=$#BUFFER         # move cursor
        zle -R -c               # refresh
    }

    zle -N percol_select_history
    bindkey '^R' percol_select_history
fi

[[ -s ~/.autojump/etc/profile.d/autojump.sh ]] && source ~/.autojump/etc/profile.d/autojump.sh

if [[ -f ~/software/dircolors-zenburn/dircolors ]];
then
    eval `dircolors ~/software/dircolors-zenburn/dircolors`
fi

GPG_TTY=$(tty)
export GPG_TTY

if [[ -f ~/.zshrc-private ]]
then
    source ~/.zshrc-private
fi

if [[ -o interactive ]] && exists rlwrap ;
then
    alias sh='rlwrap sh'
fi
