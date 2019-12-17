#!/bin/bash
if ps -e | grep kwin_x11 >/dev/null; then \
	kill -9 $(pidof kwin_x11)
	i3 &
	exit 0
fi
if ps -e | grep i3 >/dev/null; then \
	kill -9 $(pidof i3)
	kwin_x11 &
	exit 0
fi
