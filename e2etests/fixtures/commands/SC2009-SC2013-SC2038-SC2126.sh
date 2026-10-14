#!/bin/bash
ps aux | grep foo
ls | grep foo
ls | xargs rm
ls | sort
for f in $(cat foo); do printf '%s\n' "$f"; done
find . | xargs rm
grep foo file | wc -l
