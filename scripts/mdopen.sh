#!/bin/bash
/home/nzbr/scripts/pdf.sh "$1"
xdg-open "${1%.*}.pdf"
