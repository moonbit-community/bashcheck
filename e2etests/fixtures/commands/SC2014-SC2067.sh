#!/bin/bash
find . -exec echo $(date) \;
find . -name '*.php' -exec rm {};
