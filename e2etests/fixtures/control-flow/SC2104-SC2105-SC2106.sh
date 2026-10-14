#!/bin/bash
# shellcheck disable=SC2034,SC2043
continue 2
foo() { break; }
if true; then continue; fi
for f in a; do ( break; ); done
while true; do true | { break; }; done
