"""Declare valid license metadata for modern and Python 3.7-era builders."""

import sys

from setuptools import setup


runtime_files = ["implib-gen.py", "arch/*/*.ini", "arch/*/*.tpl"]

if sys.version_info >= (3, 9):
    setup(
        script_name="setup.py",
        license_expression="MIT",
        license_files=["LICENSE.txt"],
        package_data={"implib_so": runtime_files},
    )
else:
    # Older metadata cannot declare License-File; ship the notice as package data.
    setup(
        script_name="setup.py",
        license="MIT",
        license_files=[],
        package_data={"implib_so": runtime_files + ["LICENSE.txt"]},
    )
