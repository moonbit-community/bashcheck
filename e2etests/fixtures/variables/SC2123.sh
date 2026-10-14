#!/bin/bash
# shellcheck disable=SC2154
PATH="$var/$foo"
PATH="mydir"
PATH=/cow/foo
PATH='/bin:/sbin'
PATH=$OLDPATH
PATH=$PATH:/stuff
PATH="$var/$foo" cmd
