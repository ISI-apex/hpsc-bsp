#!/bin/bash

# Private repository accessible by members of HPSC Group
export GIT_REPO="git@colo-vm84.isi.edu:acolin/baretest.git"
#export GIT_REV=884b624e4824fee0d88d7ab106940422793196a6
#export GIT_BRANCH=hpsc
# Note: Tests for ARM Generic Timer are not integrated in main branch:
export GIT_REV=b464a473c804ab870e6a44daab5f708536a52fcd
export GIT_BRANCH=gtimer

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
