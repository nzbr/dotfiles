#!/bin/bash
cp -vr "$(dirname $0)" ~/.
mv -v ~/.git ~/.git-hidden
if command -v vim >/dev/null; then
	vim -c "PlugUpdate | qa"
fi
if command -v nvim >/dev/null; then
	nvim -c "PlugUpdate | qa"
fi
touch ~/.update
