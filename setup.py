#!/usr/bin/env python
#from distutils.core import setup
import subprocess
from setuptools import setup
from glob import glob

import sys
import os
from os import path
from os.path import splitext


includes = ['.', path.join(sys.prefix, 'include')]


from distutils.core import Extension

exts = [Extension("preshed.maps", ["preshed/maps.c"], include_dirs=includes,
            extra_compile_args=['-O3'], extra_link_args=['-O3']),
        Extension("preshed.tries", ["preshed/tries.c"], include_dirs=includes,
            extra_compile_args=['-O3'], extra_link_args=['-O3']),
        Extension("preshed.counter", ["preshed/counter.c"], include_dirs=includes,
            extra_compile_args=['-O3'], extra_link_args=['-O3'])
    ]


setup(
    ext_modules=exts,
    name="preshed",
    packages=["preshed"],
    version="0.35",
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
    install_requires=["murmurhash", "cymem"],
    setup_requires=["headers_workaround"]
)


import headers_workaround


headers_workaround.fix_venv_pypy_include()
headers_workaround.install_headers('murmurhash')
