#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=19e653af89410f09c24de0dfb515c53a8148e7bb
export GIT_BRANCH="hpsc"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
