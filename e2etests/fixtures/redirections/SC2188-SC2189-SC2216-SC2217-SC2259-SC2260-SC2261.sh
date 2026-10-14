#!/bin/bash
> file
> file | grep foo
grep foo | > bar
foo | echo bar
foo | basename < file.txt
ls > foo > bar
ls > foo 2> bar > baz
