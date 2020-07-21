#!/bin/bash
set -euxo pipefail

#get wallpaper
in="$(cat ~/.config/nitrogen/bg-saved.cfg | grep '^file=' | head -n 1 | cut -c 6-)"

# Retroify wallpaper
if ! [ -f "${in%.*}-retro.png" ] || ! [ -f "~/.retrolock.png" ]; then
	width="$(xdpyinfo | awk -F '[ x]+' '/dimensions:/{print $3}')"
	height="$(xdpyinfo | awk -F '[ x]+' '/dimensions:/{print $4}')"
	retroify.sh "$in"
	convert "${in%.*}-retro.png" -scale ${width}x${height}^ ~/.retrolock.png
fi

# lock the screen
/usr/bin/i3lock -f -i ~/.retrolock.png

# sleep 1 adds a small delay to prevent possible race conditions with suspend
sleep 1

exit 0
