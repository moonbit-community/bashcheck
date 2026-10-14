#!/bin/bash
# shellcheck disable=SC2086,SC2154
echo ${"bar"}
echo ${{var}
echo ${$(x)//x/y}
echo ${'foo'}
echo ${${x%.*}##*/}
echo ${${x}foo!}
