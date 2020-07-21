#!/bin/bash
set -euo pipefail
TEMPLATEURL=https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template/master/eisvogel.tex
TEMPLATEDIR=~/.pandoc/templates
TEMPLATE=eisvogel
TEMPLATEFILE=$TEMPLATEDIR/$TEMPLATE.latex

if ! [ -f ~/.pandoc/templates/eisvogel.latex ]; then
	mkdir -p $TEMPLATEDIR
	wget $TEMPLATEURL -O $TEMPLATEFILE
fi

if ! command -v pandocode >/dev/null; then
	set -x
	instdir=$(python -c 'from sys import argv; print([x for x in argv[1].split(":") if argv[2] in x][-1])' $PATH $HOME)
	pushd $(mktemp -d)
		git clone https://github.com/nzbr/pandocode.git
		cd pandocode
		pip3 install --user -r requirements.txt
		make -j$(nproc)
		cp pandocode.pyz $instdir/pandocode
	popd
	set +x
fi

# pandoc
# texlive-most
# pandoc-include-code (AUR)

if ! [ "${1%/*}" == "$1" ]; then
	pushd "${1%/*}"
fi
pandoc \
	--template $TEMPLATE \
	--filter pandoc-include-code \
	--filter pandocode \
	-o "$(basename ${1%.*}.pdf)" \
	"$(basename $1)"
if ! [ "${1%/*}" == "$1" ]; then
	popd
fi

