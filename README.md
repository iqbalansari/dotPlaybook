Ansible playbook to install the software I use regularly. The playbook works on
Ubuntu 18.04, Ubuntu 16.04, macOS Mojave and High Seirra.

The `run.sh` script in the repo is used to install the dependencies (git,
ansible) and run the playbook. Below is a one-liner I use to get things up and
running

```
curl -L https://github.com/iqbalansari/dotPlaybook/raw/master/run.sh | sh
```

To setup dotfiles in a directory other than the default `~/.playbook` directory
pass the path to the desired directory as `-d` argument

```
curl -L https://github.com/iqbalansari/dotPlaybook/raw/master/run.sh | sh -s -- -d=/desired/path
```

`sudo` password is needed by the ansible playbook to install packages using
apt. Re-login might be required for some of the configuration to take effect.
