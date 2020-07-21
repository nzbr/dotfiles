#!/bin/bash

echo "Args: $@"
echo "Env:"
env

# Setup PRIME
if [ -f ~/.prime ]; then xrandr --setprovideroffloadsink nouveau Intel; fi

# KSplash
#echo "Starting KSplash"
#timeout 60s ksplashqml --window --nofork arch.wallpaper &

# Merge colors and settings
echo "Loading .Xrescources"
xrdb ~/.Xresources

# Force KDE environment when running i3
echo "Setting environment variables"
export QT_QPA_PLATFORMTHEME="qt5ct"
export QT_PLUGIN_PATH=$HOME/.kde4/lib/kde4/plugins/:/usr/lib/kde4/plugins/
XDG_CURRENT_DESKTOP=KDE
export DESKTOP_SESSION=kde

export KDEWM=$(which i3)

echo "Setting theme"

# echo "Starting killksplash.sh"
# timeout 300s $HOME/.local/bin/killksplash.sh &

echo "Pre-Processing i3 config"
i3bang $HOME/.i3/_config
sh $HOME/.local/bin/i3-setmonitors.sh $HOME/.i3/config

if isdocked.sh; then
	barrier &
fi

echo "Starting KDE"
exec startplasma-x11 "$@"
