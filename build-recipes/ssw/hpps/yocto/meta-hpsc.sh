#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=5d8754814a7c5b41bf485bc8e15ead0887223b47
export GIT_BRANCH=hpsc

# Yocto layers aren't built
export DO_FETCH_ONLY=1
