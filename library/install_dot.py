#!/usr/bin/python
"""
A simple module to create symlink to given 'src' to 'dest'.  If 'dest' already
exists and does not point to 'src' it is backed up in directory given by
'backup_dir' before creating the symlink to 'src'.

Works only on localhost, never needed to provision a remote machine with my dots :)
"""

import os
import re
import datetime
import shutil
import errno

from ansible.module_utils.basic import *

def is_regular_file(file):
    return (
        os.path.isfile(file) or
        os.path.isdir(file) or
        os.path.islink(file)
    )

def non_regular_files(directory, names):
    return [
        name
        for name in names
        if not is_regular_file(os.path.join(directory, name))
    ]

def main():
    module = AnsibleModule(
        argument_spec={
            'src': {
                'required': True,
                'type': 'str'
            },
            'dest': {
                'required': True,
                'type': 'str'
            },
            'backup_dir': {
                'required': False,
                'type': 'str',
                'default': '/var/tmp/dotPlaybook'
            }
        },
        supports_check_mode=True
    )

    src = os.path.expanduser(module.params['src'])
    dest = os.path.expanduser(module.params['dest'])
    backup_dir = os.path.expanduser(module.params['backup_dir'])

    result = {}

    if not os.path.exists(dest) or os.path.realpath(dest) != src:
        # If the 'destination' does not already link to source, first
        # back it up
        if os.path.exists(dest):
            # Backup file/directory is of the format <backup_dir>/<destination>-<current-time>

            timestamp = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
            unhidden_backup_path = os.path.sep.join(
                [re.sub('^\.', '_', entry) for entry in dest.split(os.path.sep)]
            )
            backup_path = '{0}-{1}'.format(unhidden_backup_path, timestamp)

            backup_dest = os.path.normpath(backup_dir + os.path.sep + backup_path)

            if module.check_mode:
                module.exit_json(changed=True, backedup_at=backup_dest)

            try:
                # Ensure the parent directories of the backup location exist
                os.makedirs(os.path.dirname(backup_dest))
            except OSError as exc:
                if exc.errno != errno.EEXIST:
                    raise

            if os.path.isdir(os.path.realpath(dest)):
                shutil.copytree(
                    dest,
                    backup_dest,
                    symlinks=True,
                    ignore=non_regular_files
                )

            else:
                shutil.copy2(dest, backup_dest)

            if os.path.isdir(dest) and not os.path.islink(dest):
                shutil.rmtree(dest)

            else:
                os.unlink(dest)

            result['backedup_at'] = backup_dest

        elif os.path.islink(dest):
            # If the path does not exist but is the symlink, it means that the
            # target does not exist
            os.unlink(dest)

        try:
            # Create the parent directory if it does not exist
            os.makedirs(os.path.dirname(dest))
        except OSError as exc:
            if exc.errno != errno.EEXIST:
                raise

        os.symlink(src, dest)
        module.exit_json(changed=True, **result)

    module.exit_json(changed=False)

if __name__ == '__main__':
    main()
