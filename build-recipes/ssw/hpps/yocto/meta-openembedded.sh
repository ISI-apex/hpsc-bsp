#!/bin/bash

export GIT_REPO="https://github.com/openembedded/meta-openembedded.git"
export GIT_REV=9b3b907f30b0d5b92d58c7e68289184fda733d3e
export GIT_BRANCH="thud"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
