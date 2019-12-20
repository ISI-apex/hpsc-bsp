#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=bb10cb607b89aa0044a7634edc779c09e1dc7972
export GIT_BRANCH=hpsc

# Yocto layers aren't built
export DO_FETCH_ONLY=1
