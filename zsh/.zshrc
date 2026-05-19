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

# Load .pre.zsh if it exists
if [ -f ~/.pre.zsh ]; then
	source ~/.pre.zsh
fi

# Fix $TEMP if it does not exist (sometimes a problem with vscode+direnv+nix)
if [[ -n "${TEMP:-}" ]]; then
  mkdir -p $TEMP || true
fi

function iscmd {
	if command -v "$1" >/dev/null; then
		return 0
	else
		return 1
	fi
}

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

# Load antidote
ZSH_DISABLE_COMPFIX=true
ANTIDOTE_DIR="$HOME/.cache/antidote"
ANTIDOTE_SCRIPT="$ANTIDOTE_DIR/antidote.zsh"

if [ -f "$ANTIDOTE_SCRIPT" ]; then
	source "$ANTIDOTE_SCRIPT"
elif command -v antidote >/dev/null; then
	source <(antidote init)
else
	echo -ne "$PENDING Downloading antidote..."
	mkdir -p "$ANTIDOTE_DIR"
	git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR" >/dev/null 2>&1 || {
		echo -e "$ERR FAILED TO INSTALL ANTIDOTE"
		return 1
	}
	echo -e "\r$TICK Downloading antidote"
	source "$ANTIDOTE_SCRIPT"
fi
antidote load ~/.zsh_plugins.txt

# Auto ls
function auto-ls-newline {
	echo ""
}
AUTO_LS_COMMANDS=(newline ls)
AUTO_LS_NEWLINE=false

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt EXTENDED_HISTORY      # Write the history file in the ": 1234567890:0;command" format.
setopt SHARE_HISTORY         # Share history between all sessions.
setopt APPEND_HISTORY        # Allow multiple sessions to append to one history file.
setopt INC_APPEND_HISTORY    # Write to the history file immediately, not when the shell exits.
setopt HIST_IGNORE_DUPS      # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS  # Delete old recorded event if new event is a duplicate.
setopt HIST_IGNORE_SPACE     # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS     # Do not write duplicate events to history file.
setopt HIST_VERIFY           # Do not execute immediately upon history expansion.

# history search
bindkey '\eOA' history-substring-search-up
bindkey '\eOB' history-substring-search-down
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# Keybindings
bindkey "\e[1~" beginning-of-line # Home
bindkey "\e[4~" end-of-line       # End
bindkey "\e[3~" delete-char       # Del
bindkey "\e[H"  beginning-of-line # Home (xterm)
bindkey "\e[F"  end-of-line       # End (xterm)
bindkey "\eOH"  beginning-of-line # Home (gnome)
bindkey "\eOF"  end-of-line       # End (gnome)

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
