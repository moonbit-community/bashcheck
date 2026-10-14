#!/bin/bash
f() { f; }
cd() { cd "$1" || exit; }
