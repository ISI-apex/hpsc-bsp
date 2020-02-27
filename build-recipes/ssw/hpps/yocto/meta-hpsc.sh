#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=89ca5ce459b677ba51dbdf6335c0e180e1662223
export GIT_BRANCH=hpsc

# Yocto layers aren't built
export DO_FETCH_ONLY=1
