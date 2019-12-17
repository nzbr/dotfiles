#!/bin/bash
set -euxo pipefail

#get wallpaper
in="$(cat ~/.config/nitrogen/bg-saved.cfg | grep '^file=' | cut -c 6-)"

if ! [ "$(cat ~/.wallock.png.img)" == "$in" ]; then
	#screen properties
	width="$(xdpyinfo | awk -F '[ x]+' '/dimensions:/{print $3}')"
	height="$(xdpyinfo | awk -F '[ x]+' '/dimensions:/{print $4}')"

	#resize
	convert "$in" -resize "$width"x"$height"'^' -gravity center -extent "$width"x"$height" /tmp/lock2.png

	#convert to greyscale
	convert /tmp/lock2.png -modulate 100,10 /tmp/lock.png
	convert /tmp/lock.png -colorspace Gray /tmp/lock2.png
	convert /tmp/lock2.png -normalize	/tmp/lock.png

	cp /tmp/lock.png ~/.wallock.png
	rm /tmp/lock.png /tmp/lock2.png

	printf "$in" >~/.wallock.png.img
fi

# lock the screen
/usr/bin/i3lock -f -i ~/.wallock.png

# sleep 1 adds a small delay to prevent possible race conditions with suspend
sleep 1

exit 0
