#!/bin/bash

export GIT_REPO="https://github.com/openembedded/meta-openembedded.git"
export GIT_REV=4cd3a39f22a2712bfa8fc657d09fe2c7765a4005
export GIT_BRANCH="thud"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
