#!/bin/bash

export GIT_REPO="https://git.yoctoproject.org/git/poky"
export GIT_REV=e7f0177ef3b6e06b8bc1722fca0241fef08a1530 # thud-20.0.2 tag
export GIT_BRANCH="thud"

# poky is built by hpsc-yocto, which integrates layers
export DO_FETCH_ONLY=1
