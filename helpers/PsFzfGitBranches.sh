#!/bin/bash

 branches() {
    # TODO: the branch name is intentionally not colored as we can't figure out how to remove VT codes from the output
    git branch "$@" --sort=committerdate --sort=HEAD --format=$'%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' --color=always | column -ts$'\t'
}
case "$1" in
branches)
    echo $'CTRL-A (show all branches)\n'
    branches
    ;;
all-branches)
    echo $'\n'
    branches -a
    ;;
*) exit 1 ;;
esac
