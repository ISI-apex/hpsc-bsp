#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=734ead4148d6765e44aebb3c85e779468e62da1b
export GIT_BRANCH=hpsc

# Yocto layers aren't built
export DO_FETCH_ONLY=1
