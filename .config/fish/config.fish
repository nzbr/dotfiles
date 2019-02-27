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
abbr v 'vim'
abbr vrc 'vim ~/.vimrc'
abbr r 'ranger'
abbr x 'xdg-open'
abbr h 'highlight'
abbr c 'cat'

abbr re 'exec $SHELL' # Restart the current shell
abbr temp 'cd (mktemp -d)'

# use exa instead of ls
abbr ls 'exa'
abbr la 'exa -la'
abbr l 'exa -l'

# QEMU
set kvmcmd 'qemu-system-x86_64 --enable-kvm'
abbr qemu-kvm $kvmcmd
abbr kvm $kvmcmd

# git abbrs
abbr gcl    'git clone'
abbr ga     'git add'
abbr gaa    'git add --all'
abbr gc     'git commit'
abbr gf     'git fetch; and git status'
abbr gpl    'git pull'
abbr gps    'git push'
abbr gst    'git stash'
abbr gsp    'git stash pop'
abbr gch    'git checkout'
abbr gd     'git diff'
abbr gt     'git log --graph --oneline --all'

# git abbrs for dotfiles
abbr hgcl    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME clone'
abbr hga     'git --git-dir=$HOME/.git-hidden --work-tree=$HOME add'
abbr hgaa    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME add --all'
abbr hgc     'git --git-dir=$HOME/.git-hidden --work-tree=$HOME commit'
abbr hgf     'git --git-dir=$HOME/.git-hidden --work-tree=$HOME fetch; and git --git-dir=$HOME/.git-hidden --work-tree=$HOME status'
abbr hgpl    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME pull'
abbr hgps    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME push'
abbr hgst    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME stash'
abbr hgsp    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME stash pop'
abbr hgch    'git --git-dir=$HOME/.git-hidden --work-tree=$HOME checkout'
abbr hgd     'git --git-dir=$HOME/.git-hidden --work-tree=$HOME diff'
abbr hgt     'git --git-dir=$HOME/.git-hidden --work-tree=$HOME log --graph --oneline --all'

function mcd
	mkdir -p $argv
	cd $argv
end

if test -f ~/.secrets
	source ~/.secrets
end

if [ "$STARTED" != "true" ]; and [ (id -u) != "0" ]; and tty >/dev/null # Run neofetch when opening a terminal (or loggin in)
	tty
	neofetch
	set -x STARTED true
end

