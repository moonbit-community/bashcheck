#!/bin/bash
# shellcheck disable=SC2154,SC2164
for f in *; do cd "$f"; git pull; cd ..; done
