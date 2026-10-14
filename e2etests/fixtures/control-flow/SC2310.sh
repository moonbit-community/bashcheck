#!/bin/bash
# shellcheck enable=check-set-e-suppressed
set -e
f(){ false; }
f && echo ok
if f; then :; fi
while f; do :; done
! f
