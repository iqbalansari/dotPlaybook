Ansible playbook to install the software I use on Ubuntu 14.04 and Ubuntu 12.04
The playbooks are release specific and reside in the different branches. The playbooks
install the following

- tmux (v2.0) [http://tmux.sourceforge.net/]

- ZSH (v5.0.7) [http://zsh.sourceforge.net/]

- GNU Emacs (v24.5) [https://www.gnu.org/software/emacs/]

- xmonad (0.11) [http://xmonad.org/] from [https://launchpad.net/~gekkio/+archive/ubuntu/xmonad]

- git (latest version from PPA) [http://git-scm.com/]

- rofi [https://davedavenport.github.io/rofi/]

- Percol [https://github.com/mooz/percol]

- Plus some extra plugins for zsh and tmux

This was written with ansible version 1.9.1 in mind. Use the `run.sh` script in the repo
to install the dependencies (git, ansible) and run the playbook. Below is a one-liner to
get things up and running

```
curl https://raw.githubusercontent.com/iqbalansari/dotPlaybook/master/run.sh | sh
```

To setup dotfiles in a directory other than the default `~/dotfiles` directory pass the path
to the desired directory as `-d` argument, this won't work if the script is run from a cloned repo.
To pass the the argument to above one liner use

```
curl https://raw.githubusercontent.com/iqbalansari/dotPlaybook/master/run.sh | sh -s -- -d=/desired/path
```

`sudo` password is needed by the ansible playbook to install packages using apt. You might
need to re-login for some of the configuration to take effect.
