#!/bin/bash
cp -r "$(dirname \"$0\")" ~/.
if command -v vim >/dev/null; then
	vim -c "PlugUpdate | qa"
fi
if command -v nvim >/dev/null; then
	nvim -c "PlugUpdate | qa"
fi
