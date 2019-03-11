#!/bin/bash
TEMPLATEURL=https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template/master/eisvogel.tex
TEMPLATEDIR=~/.pandoc/templates
TEMPLATE=eisvogel
TEMPLATEFILE=$TEMPLATEDIR/$TEMPLATE.latex

if ! [ -f ~/.pandoc/templates/eisvogel.latex ]; then
	mkdir -p $TEMPLATEDIR
	wget $TEMPLATEURL -O $TEMPLATEFILE
fi

# pandoc
# texlive-full
# pandoc-include-code (AUR)
# pandoc-plantuml-filter-git (PIP3)

#	--filter pandoc-include-code \

pandoc \
	--template $TEMPLATE \
	--filter pandoc-plantuml \
	-o "${1%.*}.pdf" \
	"$1"
