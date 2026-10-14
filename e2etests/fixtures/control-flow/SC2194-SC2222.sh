#!/bin/bash
# shellcheck disable=SC2154
case foo in bar) true; esac
case foo-$bar in ??|*) true; esac
case $f in cow) true;; bar|cow) false;; esac
