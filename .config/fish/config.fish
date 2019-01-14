#                   __ _              __ _     _
#   ___ ___  _ __  / _(_) __ _       / _(_)___| |__
#  / __/ _ \| '_ \| |_| |/ _` |     | |_| / __| '_ \
# | (_| (_) | | | |  _| | (_| |  _  |  _| \__ \ | | |
#  \___\___/|_| |_|_| |_|\__, | (_) |_| |_|___/_| |_|
#                        |___/

set fish_function_path $fish_function_path "/usr/share/powerline/bindings/fish"
powerline-setup

# export shell variables
set -x EDITOR vim
set -x PATH $PATH ~/scripts ~/.local/bin
set -x MAKEFLAGS -j(nproc) #Make make use all cores, makes AUR faster

# Shortcuts
alias v "vim"
alias r "ranger"

# use exa instead of ls
alias ls "exa"
alias la "exa -la"
alias l "exa -l"

# alias re "exec $SHELL" # Restart the current shell
alias temp "cd (mktemp -d)"
alias qemu-kvm="qemu-system-x86_64 --enable-kvm"

# git aliases
alias clone    "git clone"
alias add      "git add"
alias addall   "git add --all"
alias commit   "git commit"
alias fetch    "git fetch; and git status"
alias pull     "git pull"
alias push     "git push"
alias stash    "git stash"
alias pop      "git stash pop"
alias gtree    "git log --graph --oneline --all"

if [ "$STARTED" != "true" ]; and tty # Run neofetch when opening a terminal (or loggin in)
	neofetch
	set -x STARTED true
end

