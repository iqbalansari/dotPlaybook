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

antigen theme ys

antigen apply
