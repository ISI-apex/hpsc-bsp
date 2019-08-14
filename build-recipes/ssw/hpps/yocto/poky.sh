#!/bin/bash

export GIT_REPO="https://git.yoctoproject.org/git/poky"
export GIT_REV=cb26830f765f03309c0663352cc5849491271be8 # thud-20.0.3 tag
export GIT_BRANCH="thud"

# poky is built by hpsc-yocto, which integrates layers
export DO_FETCH_ONLY=1
