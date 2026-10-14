#!/bin/bash
printf %s x > $((i++))
printf %s x 2> $((i+=1))
