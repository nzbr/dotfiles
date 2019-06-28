#                   __ _              __ _     _
#   ___ ___  _ __  / _(_) __ _       / _(_)___| |__
#  / __/ _ \| '_ \| |_| |/ _` |     | |_| / __| '_ \
# | (_| (_) | | | |  _| | (_| |  _  |  _| \__ \ | | |
#  \___\___/|_| |_|_| |_|\__, | (_) |_| |_|___/_| |_|
#                        |___/

if test -e "/usr/share/powerline/bindings/fish/powerline-setup.fish"
	set fish_function_path $fish_function_path "/usr/share/powerline/bindings/fish"
else
	set fish_function_path $fish_function_path "/usr/share/powerline/fish"
end
powerline-setup

# export shell variables
set -x EDITOR vim
set -x PATH $PATH ~/scripts ~/.local/bin
set -x MAKEFLAGS -j(nproc) #Make make use all cores, makes AUR faster

# Shortcuts
abbr vi 'vim'
abbr r 'ranger'
abbr x 'xdg-open'

abbr re 'exec fish' # Restart fish
abbr temp 'cd (mktemp -d)'
abbr mkdir 'mkdir -p'

# use exa instead of ls
if command -v exa >/dev/null
	abbr ls 'exa'
	abbr la 'exa -la --git'
	abbr l 'exa -l --git'
end

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
abbr gco    'git checkout'
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

function cd
	builtin cd $argv
	if command -v exa >/dev/null
		exa
	else
		ls
	end
end
function c
	if [ "$argv" = "" ]
		set argv .
	end
	if [ -f $argv ]
		cat $argv
	else
		ls $argv
	end
end

function mcd
	mkdir -p $argv
	cd $argv
end

if test -f ~/.secrets
	source ~/.secrets
end

function fish_greeting
	#if [ "$SUDO_USER" = "" ]
	#	bash --login -c neofetch
	#end
	if command -v pacman >/dev/null
		if pacman -Qu ^&1 >/dev/null
			echo '
###################################
#    !!! UPDATES AVAILABLE !!!    #
###################################
			'
			pacman -Qu
			printf '\n'
		end
	end
end

