#!/bin/bash
cat foo | while read -r bar; do a=$bar; done
echo "${a:-}"
