#!/usr/bin/env python
import subprocess
from setuptools import setup
from glob import glob

import sys
import os
from os import path
from os.path import splitext


from distutils.core import Extension


def clean(ext):
    for src in ext.sources:
        if src.endswith('.c') or src.endswith('cpp'):
            so = src.rsplit('.', 1)[0] + '.so'
            html = src.rsplit('.', 1)[0] + '.html'
            if os.path.exists(so):
                os.unlink(so)
            if os.path.exists(html):
                os.unlink(html)


def name_to_path(mod_name, ext):
    return '%s.%s' % (mod_name.replace('.', '/'), ext)


def c_ext(mod_name, is_pypy=False, language="c", compile_args=['-O3']):
    includes = ['.', path.join(sys.prefix, 'include')]
    mod_path = name_to_path(mod_name, language)
    return Extension(mod_name, [mod_path], include_dirs=includes,
                     extra_compile_args=compile_args, extra_link_args=compile_args)


def cython_ext(mod_name, language="c"):
    import Cython.Distutils
    import Cython.Build
    mod_path = mod_name.replace('.', '/') + '.pyx'
    return Cython.Build.cythonize(mod_path, language=language)[0]


def run_setup(exts):
    setup(
        ext_modules=exts,
        name="preshed",
        packages=["preshed"],
        version="0.36",
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


def main(modules, is_pypy):
    language = "c"
    ext_func = cython_ext if use_cython else c_ext
    exts = [ext_func(mn) for mn in modules]
    run_setup(exts)


MOD_NAMES = ['preshed.maps', 'preshed.counter', 'preshed.tries']

if __name__ == '__main__':
    use_cython = sys.argv[1] == 'build_ext'
    main(MOD_NAMES, use_cython)
