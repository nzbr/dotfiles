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
	sha256sum ~/.zsh_plugins.txt ~/.zshrc >~/.zsh.sha
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

# Auto ls
function auto-ls-newline {
	echo ""
}
AUTO_LS_COMMANDS=(newline ls)
AUTO_LS_NEWLINE=false

# history search
bindkey '\eOA' history-substring-search-up
bindkey '\eOB' history-substring-search-down
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# PROMPT

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[cyan]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[cyan]%}]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$reset_color%}%{$fg_bold[yellow]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

if [[ $UID -eq 0 ]]; then
	local usercolor="%{$fg[red]%}"
	local user="%{$fg[red]%}%n%{$reset_color%}"
	local symbol='#'
else
	local usercolor="%{$fg[green]%}"
	local user="%{$fg[green]%}%n%{$reset_color%}"
	local symbol='$'
fi

if [ -n "$SSH_CONNECTION" ]; then
	local host="${usercolor}@%m%{$reset_color%}"
else
	local host=""
fi

function build_prompt {
	print "${user}${host}:%{$fg[blue]%}%~%{$reset_color%}${symbol} "
}

function build_rprompt {
}

PROMPT='$(build_prompt)'
RPROMPT='$(build_rprompt)'

# ALIASES
alias :q=exit
alias cls="clear"
alias cre="clear; exec zsh"
alias mkdir="mkdir -p"
alias py="python3"
iscmd "ipython" && alias py="ipython"
alias re="exec zsh"
alias start=xdg-open
alias temp="pushd $(mktemp -d)"
alias vi=vim
alias t="tmux attach || tmux"

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

# svn
alias s="svn"
alias scl="svn co"
alias sa="svn add"
alias sc="svn commit"
alias sst="svn status"
alias spl="svn update"
alias st="svn log | less"

function spawn {
	"$@" >/dev/null 2>&1 &
	disown
}

# Replace ls
alias la="ls -la"
alias l="ls -l"
iscmd eza && {
	alias ls="eza --icons --git"
	alias la="eza --icons --git -la"
	alias l="eza --icons --git -l"
	alias tree="eza --icons --tree"
}

iscmd colordiff && {
	alias gdiff="$(which diff)"
	alias diff="colordiff -u"
}

function mcd {
	mkdir -p "$1"
	cd "$1"
}

# Starship
iscmd starship && eval "$(starship init zsh)"

# Load .post.zsh if it exists
if [ -f ~/.post.zsh ]; then
	source ~/.post.zsh
fi
