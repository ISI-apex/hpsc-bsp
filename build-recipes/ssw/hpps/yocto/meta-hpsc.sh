#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=0463e9735ee67872ef95a62db11c4a120b42af1a
export GIT_BRANCH=hpsc

# Yocto layers aren't built
export DO_FETCH_ONLY=1
