#!/usr/bin/env bash

# nzbr's dotfiles
# https://github.com/nzbr/dotfiles
# ---------------------------------------------------------------------
# Copyright (c) 2020 nzbr
# This software is licensed under the ISC License.
# For more information see the LICENSE file included in this repository
# ---------------------------------------------------------------------
#
# This script is used to install and manage my dotfiles
# Install: curl -sL go.nzbr.de/dotfiles | bash
#

# CONSTANTS

export TICK="[\e[1;32m✓\e[0m]"
export CROSS="[\e[1;31m✗\e[0m]"

export INFO="\e[1;36m:::\e[0m"
export ERR="\e[1;31m!!!\e[0m"
export OK="\e[1;32m:::\e[0m"

# FUNCTIONS

export missing=":"
function chk_cmd { # Tests if a command is known
	if command -v "$1" &>/dev/null; then
		echo -e "${TICK} Checking for $1"
	else
		echo -e "${CROSS} Checking for $1"
		export missing="$missing$1:"
	fi
}
export -f chk_cmd

function is_missing {
	echo "$missing" | grep -q ":$1:"
}
export -f is_missing

function is_present {
	echo "$missing" | grep -vq ":$1:"
}
export -f is_present

export pip="unknown"
function ensurepip {
	if [ "$pip" == "unknown" ]; then
		chk_cmd pip3
		if is_missing pip3; then
			echo -e "\n$INFO Searching for pip"
			if ! python3 -m pip &>/dev/null; then
				echo -e "$CROSS pip is not installed, running ensurepip"
				python3 -m ensurepip --user
				if ! python3 -m pip &>/dev/null; then
					echo -e "$ERR Failed to install pip!"
					exit 1
				fi
				echo -e "$OK pip was installed successfully"
			else
				echo -e "$TICK pip is installed as a python module"
			fi
			export pip="python3 -m pip"
		fi
		export pip="pip3"
	fi
}
export -f ensurepip

stow="unknown"
function search_stow {
	if [ "$stow" == "unknown" ]; then
		echo -e "$INFO Looking for stow"
		chk_cmd xstow
		chk_cmd stow

		# Set correct stow version
		if is_present xstow; then
			stow="xstow"
		elif is_present stow; then
			stow="stow"
		else
			echo -e "$ERR stow is missing on your system!"
			exit 1
		fi
		echo -e "$OK Found $stow\n"
	fi
}

function dolink {
	pushd ~/.dotfiles >/dev/null
	$stow "$@"
	popd >/dev/null
}

function link {
	search_stow
	echo -e "$INFO Linking $1"
	dolink "$1"
}
export -f link

function unlink {
	search_stow
	echo -e "$INFO Unlinking $1"
	dolink -D "$1"
}
export -f unlink

function autolink {
	if is_present "$1"; then
		link "$1"
	else
		unlink "$1"
	fi
}
export -f autolink

function autolink_all {
	pushd ~/.dotfiles >/dev/null

	echo -e "\n$INFO Looking for installed programs"
	chk_cmd abcde
	chk_cmd docker
	chk_cmd fish
	chk_cmd i3
	chk_cmd kitty
	chk_cmd nvim
	chk_cmd picom
	chk_cmd plasmashell
	chk_cmd podman
	chk_cmd python3
	chk_cmd rofi
	chk_cmd vim
	chk_cmd xfce4-session
	chk_cmd zathura
	chk_cmd zsh

	echo ""

	autolink abcde
	if is_present docker || is_present podman; then
		link docker
	else
		unlink docker
	fi
	link dot-control # Always link control scripts
	autolink fish
	if is_present i3; then
		if is_present python3; then
			ensurepip
			$pip install --user i3ipc
		fi
		link i3
	else
		unlink i3
	fi
	autolink kitty
	if is_present vim || is_present nvim; then
		link vim
	else
		unlink vim
	fi
	autolink picom
	autolink rofi
	link scripts # Always link scripts
	autolink xfce4-session
	autolink zathura
	autolink zsh

	popd >/dev/null
}
export -f autolink_all

function install {
	set -euo pipefail

	# Check for .dotfiles
	if [ -e "$HOME/.dotfiles" ]; then
		echo -e "$ERR .dotfiles already exists, aborting!"
		exit 1
	fi

	# Splash
	echo "           _          _           _       _    __ _ _           "
	echo " _ __  ___| |__  _ __( )___    __| | ___ | |_ / _(_) | ___  ___ "
	echo "| '_ \\|_  / '_ \\| '__|// __|  / _\` |/ _ \\| __| |_| | |/ _ \\/ __|"
	echo "| | | |/ /| |_) | |    \\__ \\ | (_| | (_) | |_|  _| | |  __/\\__ \\"
	echo "|_| |_/___|_.__/|_|    |___/  \\__,_|\\___/ \\__|_| |_|_|\\___||___/"
	echo "                                                                "

	# Check for dependecies
	echo -e "$INFO Checking dependencies"

	chk_cmd curl
	chk_cmd git
	chk_cmd ssh
	chk_cmd stow
	chk_cmd wget
	chk_cmd xstow

	if is_missing curl && is_missing wget; then
		echo -e "\n$ERR This script needs either curl or wget to work properly"
		exit 1
	fi
	downloadcmd="curl -sL"
	if is_missing curl; then
		downloadcmd="wget -qO /dev/stdout"
	fi

	if is_missing xstow && is_missing stow; then
		echo -e "$ERR stow is missing on your system!"
		exit 1
	fi

	if is_missing git; then
		echo -e "$ERR git is missing on your system!"
		exit 1
	fi

	echo -e "$OK All dependencies are installed"
	echo -e "\n$INFO Downloading dotfiles"

	cd "$(mktemp -d)"

	# Is there a valid ssh key -> clone from nzbr.de with ssh
	if is_present ssh && [ -f "$HOME/.ssh/id_ed25519.pub" ] && $downloadcmd https://github.com/nzbr.keys | grep -q "$(awk '{print $1" "$2;}' < ~/.ssh/id_ed25519.pub)"; then
		repourl="git@github.com:nzbr/dotfiles.git"
		echo -e "$INFO Downloading via SSH"
	else
		repourl="https://github.com/nzbr/dotfiles.git"
		echo -e "$INFO Downloading via HTTPS"
	fi

	git clone "$repourl" ~/.dotfiles
	cd ~/.dotfiles
	git submodule update --init --recursive
	touch ~/.update
	echo -e "$OK Download successful"

	autolink_all
	link dot-control
}

# Do nothing if sourced
if [ -z "${DOT_NOINSTALL-}" ]; then
	install
fi
