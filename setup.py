#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from Cython.Distutils import Extension


import sys
import os
from os.path import splitext

from distutils.sysconfig import get_python_inc

exts = [Extension("preshed.maps", ["preshed/maps.pyx"]),
        Extension("preshed.tries", ["preshed/tries.pyx"])]

setup(
    ext_modules=cythonize(exts),
    name="preshed",
    packages=["preshed"],
    version="0.1",
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
