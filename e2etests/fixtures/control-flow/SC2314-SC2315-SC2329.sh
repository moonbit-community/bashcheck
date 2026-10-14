#!/bin/bash
@test "negation" { ! true; false; }
@test "condition" { ! [[ -e test ]]; }
f() { echo hidden; }
exit
