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


includes = ['.', path.join(sys.prefix, 'include')]


exts = [Extension("preshed.maps", ["preshed/maps.pyx"], include_dirs=includes,
                  extra_compile_args=['-O3'], extra_link_args=['-O3']),
        Extension("preshed.counter", ["preshed/counter.pyx"], include_dirs=includes,
                  extra_compile_args=['-O3'], extra_link_args=['-O3'])
       ]

setup(
    ext_modules=cythonize(exts),
    name="preshed",
    packages=["preshed"],
    version="0.38",
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
    requires=["cymem", "murmurhash"]
)
