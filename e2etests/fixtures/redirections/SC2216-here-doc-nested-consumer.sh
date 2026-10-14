#!/bin/bash
foo | cat <<EOF
$(cat)
EOF
