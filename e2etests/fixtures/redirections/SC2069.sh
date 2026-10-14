#!/bin/bash
printf x 2>&1 > cow
printf x | cat 2>&1 > /dev/null
