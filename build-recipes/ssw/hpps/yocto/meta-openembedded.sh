#!/bin/bash

export GIT_REPO="https://github.com/openembedded/meta-openembedded.git"
export GIT_REV=f4ccdf2bc3fe4f00778629088baab840c868e36b
export GIT_BRANCH="warrior"

# Yocto layers aren't built
export DO_FETCH_ONLY=1
