#!/bin/bash
# shellcheck disable=SC2154
# shellcheck enable=avoid-nullary-conditions,avoid-negated-conditions
! [ -n "$var" ]
[[ $(cmd) ]]
! [[ $var -gt 3 ]]
