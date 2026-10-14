#!/bin/bash
# shellcheck disable=SC2034,SC2102,SC2154,SC2206
declare -A foo; foo=(bar)
arr=( [foo]= bar )
declare -A map; map=( var=value )
arr=( 1=value )
arr=( $a=value )
arr=( $((1+1))=value )
arr=( [foo] = bar )
