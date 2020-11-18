from fabric.api import local, run, lcd, cd, env, settings

import os
from os import path
from os.path import exists as file_exists


PWD = path.dirname(__file__)
VENV_DIR = path.join(PWD, '.env')
DEV_ENV_DIR = path.join(PWD, '.denv')


def login():
    with settings(user="matt"):
        run("ls")
