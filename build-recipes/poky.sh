#!/bin/bash

export GIT_REPO="https://git.yoctoproject.org/git/poky"
export GIT_REV=1cab405d88149fd63322a867c6adb4a80ba68db3 # thud-20.0.1 tag
export GIT_BRANCH="thud"

# poky is built by hpsc-yocto, which integrates layers
export DO_FETCH_ONLY=1
