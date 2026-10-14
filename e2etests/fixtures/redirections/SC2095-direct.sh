#!/bin/bash
while read -r foo; do ssh "$foo" uptime; done
while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
while read -r foo; do mplayer foo.ogv > file; done
while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
