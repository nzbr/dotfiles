#!/bin/bash
# /usr/bin/blurlock

# take screenshot
import -window root /tmp/screenshot.png

# blur it
#cp /tmp/screenshot.png /tmp/screenshot2.png #convert /tmp/screenshot.png -blur 0x5 /tmp/screenshot2.png
#convert to greyscale, but make original colors percieevable
convert /tmp/screenshot.png -modulate 100,10 /tmp/screenshot3.png
convert /tmp/screenshot3.png -colorspace Gray /tmp/screenshot4.png
convert /tmp/screenshot4.png -normalize	/tmp/screenshot5.png

# lock the screen
/usr/bin/i3lock -f -i /tmp/screenshot5.png
rm /tmp/screenshot*

# sleep 1 adds a small delay to prevent possible race conditions with suspend
sleep 1

exit 0
