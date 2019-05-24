#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=4e599b8ab341ec7f5a9c8fad3db0e23d448d1fab
export GIT_BRANCH="hpsc"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
