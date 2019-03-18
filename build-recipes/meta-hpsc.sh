#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=fb5a7e7d1dfd9c59ffb2b43f7c8604c6c3981cc9
export GIT_BRANCH="hpsc"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
