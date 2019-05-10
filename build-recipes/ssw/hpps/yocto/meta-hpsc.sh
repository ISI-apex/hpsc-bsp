#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/meta-hpsc.git"
export GIT_REV=ef5c291824bda167ab68443710b57441f4117854
export GIT_BRANCH="hpsc"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
