#!/bin/zsh

export PATH="$HOME/local_packages/bin:$HOME/local_packages/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/bin:$PATH"

function exists { which $1 &> /dev/null }

if exists tmux; then
    if [[ -z $TMUX && -z $INSIDE_EMACS && -n $TERM && "$TERM" != "dumb" ]]; then
        if tmux list-sessions > /dev/null 2>&1; then
            tmux attach
            exit
        else
            exec tmux
        fi
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
if exists percol && [ -z $INSIDE_EMACS ]; then
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

if [[ -f ~/software/dircolors-solarized/dircolors.ansi-dark ]]; then
    eval `dircolors ~/software/dircolors-solarized/dircolors.ansi-dark`
fi

GPG_TTY=$(tty)
export GPG_TTY

if [[ -f ~/.zshrc-private ]]
then
    source ~/.zshrc-private
fi
