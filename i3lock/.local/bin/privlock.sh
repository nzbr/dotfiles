#!/bin/bash

# take Screenshot
import -window root /tmp/screenshot.png

#Pixelate
convert /tmp/screenshot.png -resize 10% /tmp/screenshot0.png
convert /tmp/screenshot0.png -scale 1000% /tmp/screenshot1.png

#Blur
#convert /tmp/screenshot0.png -blur 0x1 /tmp/screenshot1.png
#convert /tmp/screenshot1.png -scale 2000% /tmp/screenshot2.png

#cp /tmp/screenshot2.png /tmp/screenshot5.png
#convert to grayscale like in graylock.sh
#convert /tmp/screenshot2.png -modulate 100,10 /tmp/screenshot3.png
#convert /tmp/screenshot3.png -colorspace Gray /tmp/screenshot4.png
convert /tmp/screenshot1.png -normalize /tmp/screenshot2.png

/usr/bin/i3lock -f -i /tmp/screenshot2.png
rm /tmp/screenshot*.png

sleep 1
exit 0
