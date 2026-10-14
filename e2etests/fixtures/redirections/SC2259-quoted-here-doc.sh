#!/bin/bash
echo World | cat << 'EOF'
hello $(cat)
EOF
