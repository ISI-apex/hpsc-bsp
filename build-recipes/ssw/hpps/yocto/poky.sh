#!/bin/bash

export GIT_REPO="https://git.yoctoproject.org/git/poky"
export GIT_REV=38d5c8ea98cfa49825c473eba8984c12edf062be # warrior-21.0.1 tag
export GIT_BRANCH="warrior"

# poky is built by hpsc-yocto, which integrates layers
export DO_FETCH_ONLY=1
