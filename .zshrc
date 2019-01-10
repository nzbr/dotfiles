#       _                                        _
#  ___ | |__        _ __ ___  _   _      _______| |__
# / _ \| '_ \ _____| '_ ` _ \| | | |____|_  / __| '_ \
#| (_) | | | |_____| | | | | | |_| |_____/ /\__ \ | | |
# \___/|_| |_|     |_| |_| |_|\__, |    /___|___/_| |_|
#                             |___/
export ZSH=/usr/share/oh-my-zsh

plugins=(
	git
	fzf
)

source $ZSH/oh-my-zsh.sh

#Powerline
. /usr/share/powerline/bindings/zsh/powerline.zsh


#         _     ____   ____
# _______| |__ |  _ \ / ___|
#|_  / __| '_ \| |_) | |
# / /\__ \ | | |  _ <| |___
#/___|___/_| |_|_| \_\\____|

export EDITOR=vim
export PATH=$PATH:~/scripts
export MAKEFLAGS="-j$(nproc)" #Makes make use all cores, useful for AUR

#Use exa for directory listings
alias ls="exa"
alias la="exa -la"
alias l="exa -l"
alias tree="exa --tree"

#GIT Aliases
alias clone="git clone"
alias add="git add --all ."
alias commit="git commit"
alias fetch="git fetch && git status"
alias pull="git pull"
alias stash="git stash"
alias pop="git stash pop"
alias push="git push"
alias status="git status"
alias gtree="git log --graph --oneline --all"

alias drun="docker run --rm -it -v $PWD:/dir" #Easily disposable docker containers
alias re="exec $SHELL" #Restart the current shell
alias cdt="mktemp -d | cd"

alias qemu-kvm="qemu-system-x86_64 --enable-kvm"

if [ "$STARTED" != "true" ] && tty; then neofetch; fi #Run neofetch when opening a terminal
export STARTED=true

