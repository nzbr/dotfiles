#  _________  _   _
# |__  / ___|| | | |
#   / /\___ \| |_| |
#  / /_ ___) |  _  |
# /____|____/|_| |_|
#

# CONSTANTS #
export TICK="[\e[1;32m✓\e[0m]"
export CROSS="[\e[1;31m✗\e[0m]"
export PENDING="[ ]"

export INFO="\e[1;36m:::\e[0m"
export ERR="\e[1;31m!!!\e[0m"
export OK="\e[1;32m:::\e[0m"
#############

# Load in any bash config
if [ -f ~/.bashrc ]; then
	source ~/.bashrc
fi

# Load .pre.zsh if it exists
if [ -f ~/.pre.zsh ]; then
	source ~/.pre.zsh
fi

function iscmd {
	if command -v "$1" >/dev/null; then
		return 0
	else
		return 1
	fi
}

if ! sha256sum -c ~/.zsh.sha >/dev/null 2>&1; then
	SHOWPROGRESS=true
	echo -e "$INFO zsh config was updated"
	sha256sum ~/.zsh_plugins.txt ~/.zshrc > ~/.zsh.sha
else
	SHOWPROGRESS=false
fi

# ENVIRONMENT VARIABLES
export EDITOR=vim
export MAKEFLAGS="-j$(nproc)"

# PATH
function path {
	if [ -d "$1" ]; then
		export PATH="$PATH:$1"
	fi
}
path "/var/lib/flatpak/exports/bin"
path "$HOME/.cargo/bin"
path "$HOME/.local/bin"
path "$HOME/.yarn/bin"
path "$HOME/scripts"
iscmd go && path "$(go env GOPATH)/bin"

# Install thefuck if it isn't
iscmd thefuck || {
	echo -e "$INFO Installing thefuck"
	iscmd pip && pip install --user thefuck
}

# Load antibody
ZSH_DISABLE_COMPFIX=true
ANTIBODY_DIR="$HOME/.cache/antibody"
ANTIBODY="$ANTIBODY_DIR/antibody"
if ! [ -f $ANTIBODY ]; then
	SHOWPROGRESS=true
	echo -ne "$PENDING Downloading antibody..."
	mkdir -p "$ANTIBODY_DIR"
	curl -sSL git.io/antibody -o "$ANTIBODY_DIR/install.zsh"
	zsh "$ANTIBODY_DIR/install.zsh" -b "$ANTIBODY_DIR" >"$ANTIBODY_DIR"/install.log 2>&1 || {
		echo -e "$ERR FAILED TO INSTALL ANTIBODY"
		return 1
	}
	echo -e "\r$TICK Downloading antibody"
fi
if ! [ "$(command -v antibody)" = "$ANTIBODY" ]; then
	export PATH="$ANTIBODY_DIR:$PATH"
	if ! [ "$(command -v antibody)" = "$ANTIBODY" ]; then
		echo -e "$ERR Antibody was not found or found at an unexpected location"
		echo -e "$ERR Expected: $ANTIBODY"
		echo -e "$ERR Found: $(command -v antibody)"
		return 1
	fi
fi

# OMZ Config
export ZSH="$(antibody home)/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh"

# Plugins
$SHOWPROGRESS && echo -ne "$PENDING Starting antibody..."
source <(antibody init)
$SHOWPROGRESS && echo -e "\r$TICK Starting antibody"
$SHOWPROGRESS && echo -ne "$PENDING Loading plugins..."
antibody bundle <~/.zsh_plugins.txt || {
	echo -e "$ERR Failed to load plugins"
	return 1
}
$SHOWPROGRESS && echo -e "\r$TICK Loading plugins"

COMMAND_EXECUTION_TIMER_THRESHOLD=30
COMMAND_EXECUTION_TIMER_PRECISION=0
COMMAND_EXECUTION_TIMER_FOREGROUND=yellow
COMMAND_EXECUTION_TIMER_FORMAT="H:M:S"
COMMAND_EXECUTION_TIMER_PREFIX='\n Took '
add-zsh-hook precmd append_command_execution_duration

# Auto ls
function auto-ls-newline {
	echo ""
}
# function auto-ls-git-status {
# 	if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == true ]]; then
# 		echo ''
# 		git status | grep -P '\t' | sed 's/^\t//;/: /!s/^/untracked:  /'
# 	fi
# }
AUTO_LS_COMMANDS=(newline ls)
AUTO_LS_NEWLINE=false

# PROMPT

ZSH_THEME_GIT_PROMPT_PREFIX=" %{$fg[cyan]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[cyan]%}]%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$reset_color%}%{$fg_bold[yellow]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

if [[ $UID -eq 0 ]]; then
	local user="%{$fg[red]%}%n%{$reset_color%}"
	local symbol='#'
else
	local user="%{$fg[green]%}%n%{$reset_color%}"
	local symbol='$'
fi

function build_prompt {
	if [ -n "$WSL_DISTRO_NAME" ]; then
		if [ "${PWD##/drv/}" != "${PWD}" ]; then
			dir=$(pwd | sed -E 's|/drv/(.)|\U\1:|;s|/|\\\\|g;s|:$|:\\\\|')
			print "ZSH ${dir}$(git_prompt_info)> "
			return 0
		fi
	fi
	print "${user}:%{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info)${symbol} "
}

PROMPT='$(build_prompt)'
# ALIASES
alias :q=exit
alias cls="clear"
alias cre="clear; exec zsh"
alias mkdir="mkdir -p"
alias py="python3"
alias re="exec zsh"
alias start=xdg-open
alias temp="pushd (mktemp -d)"
alias vi=vim
iscmd "ipython" && alias py="ipython"

# git
alias g="git"
alias gcl="git clone"
alias ga="git add"
alias gc="git commit -v"
alias gf="git fetch"
alias gs="git status"
alias gpl="git pull"
alias gps="git push"
alias gst="git stash"
alias gsp="git stash pop"
alias gco="git checkout"
alias gd="git diff"
alias gt="git log --graph --oneline --all"

# svn
alias s="svn"
alias scl="svn co"
alias sa="svn add"
alias sc="svn commit"
alias sst="svn status"
alias spl="svn update"
alias st="svn log | less"

# Kitty
alias title="kitty @set-window-title"
alias light="kitty @set-colors foreground=black background=white; kitty @set-background-opacity 1"
alias dark="kitty @set-colors --reset; kitty @set-background-opacity 0.8"
alias neo="kitty @set-colors foreground=green background=black; kitty @set-background-opacity 1"

# WSL
if [ -n "$WSL_DISTRO_NAME" ]; then
	for drv in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
		upper=$(print $drv | sed 's|.*|\U&|')
		alias "${drv}:"="cd /drv/$drv"
		alias "${upper}:"="cd /drv/$drv"
	done
fi

function spawn {
	"$@" >/dev/null 2>&1 &
	disown
}

# Open files is VSCode if in a remote shell
if [ -n "${AMD_ENTRYPOINT}" ]; then
	export EDITOR="code -w"
	alias vim=code
	alias vi=code
	alias nano=code
fi

# Replace ls
alias la="ls -la"
alias l="ls -l"
iscmd exa && {
	alias ls="exa --git"
	alias la="exa --git -la"
	alias l="exa --git -l"
	alias tree="exa --tree"
}

iscmd colordiff && {
	alias gdiff="$(which diff)"
	alias diff="colordiff -u"
}

iscmd lsusb.py && {
	alias lsusb=lsusb.py
}

iscmd qemu-system-x86_64 && {
	alias qemu-kvm="qemu-system-x86_64 --enable-kvm"
}

function mcd {
	mkdir -p "$1"
	cd "$1"
}

# Load .post.zsh if it exists
if [ -f ~/.post.zsh ]; then
	source ~/.post.zsh
fi
