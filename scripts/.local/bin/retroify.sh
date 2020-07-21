#!/bin/bash
set -euxo pipefail

convert "$1" \
	-scale 15% \
	+dither -colors 32 \
	-modulate 100,250 \
	-scale $(identify -format "%[fx:w]x%[fx:h]" "$1") \
	-normalize \
	"${1%.*}"-retro.png
