#!/bin/bash
# shellcheck disable=SC2034
a=(1, 2)
a+=(1,2,3)
a=(1 "foo,bar" 3)
a=('one,' 'two')
a=([a]=b,[c]=d,[e]=f)
