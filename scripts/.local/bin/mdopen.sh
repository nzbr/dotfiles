#!/bin/bash
pdf.sh "$1"
xdg-open "${1%.*}.pdf"
