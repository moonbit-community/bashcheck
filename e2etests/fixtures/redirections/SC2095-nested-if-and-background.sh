#!/bin/bash
while read -r foo; do if true; then ssh "$foo" uptime; fi; done
while read -r foo; do ssh "$foo" uptime & done
