#!/bin/bash
cp -r "$(dirname \"$0\")" ~/.
mv ~/.git ~/.git-hidden
if command -v vim >/dev/null; then
	vim -c "PlugUpdate | qa"
fi
if command -v nvim >/dev/null; then
	nvim -c "PlugUpdate | qa"
fi
