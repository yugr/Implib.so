#!/bin/sh

set -eu

pkg update
pkg upgrade
pkg install gcc g++ binutils python3
