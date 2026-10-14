#!/bin/bash
find . -print0 | du --files0-from=/dev/stdin
find . | du --exclude-from=/dev/fd/0
yes | cp -Ri foo/* bar
yes | rm --interactive *
ls 1>&3 3>&1 3>&-
