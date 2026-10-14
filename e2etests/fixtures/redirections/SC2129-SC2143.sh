#!/bin/bash
foo >> file; bar >> file; baz >> file;
[[ $(foo | grep bar) ]]
[ -z "$(foo | grep bar)" ]
