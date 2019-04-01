#!/bin/bash
temp=$(mktemp)
echo "\$ $@" | tee $temp

set -o pipefail
"$@" |& tee -a $temp
code="$?"
set +o pipefail
if ! [ $code -eq 0 ]; then
	less +G $temp
fi

rm $temp
