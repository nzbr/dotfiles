#!/bin/sh
# This script extracts monitor information from xrandr and stores
# it in the i3 config
primary=$(xrandr | grep primary | awk '{print $1;}' | tr '\n' ' ' | sed s/.$//)
secondary=$(xrandr | grep connected | grep -v primary | awk '{print $1;}' | tr '\n' ' ' | sed s/.$//)
if [ "$secondary" == "" ]; then
	secondary="$primary"
fi
echo Primary:    \"$primary\"
echo Secondary:  \"$secondary\"
echo Setting Monitors
sed -i "s/replace-primary/$primary/g" ~/.i3/config
sed -i "s/replace-secondary/$secondary/g" ~/.i3/config
