#!/usr/bin/python
"""
A simple module to create symlink to given 'src' to 'dest'.  If 'dest' already
exists and does not point to 'src' it is backed up in directory given by
'backup_dir' before creating the symlink to 'src'.

Works only on localhost, never needed to provision a remote machine with my dots :)
"""

import os

from ansible.plugins.action import ActionBase
from ansible.parsing.splitter import parse_kv

class ActionModule(ActionBase):
    def __init__(self, *args, **kargs):
        super(ActionModule, self).__init__(*args, **kargs)
        self._supports_check_mode = True

    def resolve_file_path(self, path):
        path = os.path.expanduser(path)

        if os.path.isabs(path):
            return path

        # pylint: disable=protected-access
        if self._task._role is not None:
            return self._loader.path_dwim_relative(self._task._role._role_path, 'files', path)

        return self._loader.path_dwim_relative(self._loader.get_basedir(), 'files', path)

    def run(self, tmp=None, task_vars=None):
        task_vars = task_vars or {}

        result = super(ActionModule, self).run(tmp, task_vars)

        if 'skipped' in result and result['skipped']:
            return result

        options = self._task.args.copy()

        source = options.get('src', None)
        dest   = options.get('dest', options.get('path', None))

        if not source or not dest:
            result.update({
                'msg': 'src and dest are required',
                'failed': True
            })
            return result

        backup_dir = options.get('backup_dir', os.path.join(self._loader.get_basedir(), '.backups'))

        # Resolve src to any role specific file
        source = self.resolve_file_path(source)

        result.update(
            self._execute_module(
                module_args={'src': source, 'dest': dest, 'backup_dir': backup_dir},
                task_vars=task_vars
            )
        )

        return result
