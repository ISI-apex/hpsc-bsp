#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=b3eaedaef9c56494bf58ed01556d22a6fb77530a
export GIT_BRANCH="hpsc"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
