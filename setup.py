#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils import Extension
from glob import glob


import sys
import os
from os import path
from os.path import splitext

from distutils.sysconfig import get_python_inc

virtual_env = os.environ.get('VIRTUAL_ENV', '')

includes = []

if 'VIRTUAL_ENV' in os.environ:
    includes += glob(path.join(os.environ['VIRTUAL_ENV'], 'include', 'site', '*'))
else:
    # If you're not using virtualenv, set your include dir here.
    pass


exts = [Extension("preshed.maps", ["preshed/maps.pyx"], include_dirs=includes),
        Extension("preshed.tries", ["preshed/tries.pyx"], include_dirs=includes),
        Extension("preshed.counter", ["preshed/counter.pyx"], include_dirs=includes)]

setup(
    ext_modules=cythonize(exts),
    name="preshed",
    packages=["preshed"],
    version="0.20",
    author="Matthew Honnibal",
    author_email="honnibal@gmail.com",
    url="http://github.com/syllog1sm/preshed",
    package_data={"preshed": ["*.pxd", "*.pyx", "*.c"]},
    description="""Cython hash table that trusts the keys are pre-hashed""",
    classifiers=[
                'Environment :: Console',
                'Operating System :: OS Independent',
                'Intended Audience :: Science/Research',
                'Programming Language :: Cython',
                'Topic :: Scientific/Engineering'],
)
