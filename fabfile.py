from fabric.api import local, run, lcd, cd, env

import os.path


def make():
    with lcd(os.path.dirname(__file__)):
        local('python setup.py build_ext --inplace')

def clean():
    with lcd(os.path.dirname(__file__)):
        local('python setup.py clean --all')

def test():
    local('py.test -x')
