Ansible playbook to install the softwares I use on Ubuntu 12.04, right now it installs

- tmux (v1.9a) [http://tmux.sourceforge.net/]

- ZSH (v5.0.7) [http://zsh.sourceforge.net/]

- GNU Emacs (v24.5) [https://www.gnu.org/software/emacs/]

- xmonad 0.10 [http://xmonad.org/]

- Solarized theme for gnome-terminal [https://github.com/Anthony25/gnome-terminal-colors-solarized]

- Percol [https://github.com/mooz/percol]

- oh-my-zsh [https://github.com/robbyrussell/oh-my-zsh/]

- Plus some extra plugins for zsh and tmux

This was written with ansible version 1.9.0.1 in mind

```
ansible-playbook playbook.yaml -i inventory --ask-sudo-pass
```
