#!/bin/bash
exec foo; true
for f in *; do exec "$f"; done
