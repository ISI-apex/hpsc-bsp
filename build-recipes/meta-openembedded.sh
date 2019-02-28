#!/bin/bash

export GIT_REPO="https://github.com/openembedded/meta-openembedded.git"
export GIT_REV=6094ae18c8a35e5cc9998ac39869390d7f3bb1e2

function do_build()
{
    : # bitbake layers aren't actually built
}
