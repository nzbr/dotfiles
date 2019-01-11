#!/bin/bash
TEMPLATEURL=https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template/master/eisvogel.tex
TEMPLATEDIR=~/.pandoc/templates
TEMPLATE=eisvogel
TEMPLATEFILE=$TEMPLATEDIR/$TEMPLATE.latex
if ! [ -f ~/.pandoc/templates/eisvogel.latex ]; then
	mkdir -p $TEMPLATEDIR
	wget $TEMPLATEURL -O $TEMPLATEFILE
fi
pandoc --template $TEMPLATE -o "${1%.*}.pdf" "$1"
