#!/bin/bash
# shellcheck disable=SC2086,SC2154
[ -n $foo ]
[ $foo=3 ]
# shellcheck disable=SC1014,SC2050,SC2154
[ "$a" =~ foo ]
# shellcheck disable=SC2050,SC2071,SC2154
[[ $a \< $b ]]
