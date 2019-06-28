#                   __ _              __ _     _
#   ___ ___  _ __  / _(_) __ _       / _(_)___| |__
#  / __/ _ \| '_ \| |_| |/ _` |     | |_| / __| '_ \
# | (_| (_) | | | |  _| | (_| |  _  |  _| \__ \ | | |
#  \___\___/|_| |_|_| |_|\__, | (_) |_| |_|___/_| |_|
#                        |___/

if ! test -f $HOME/.fish-powerline
	echo Searching for powerline fish binding, this may take some time...
	set powerlinebinding (find -L /usr/share /usr/local/share $HOME/.local -maxdepth 10 -name 'powerline-setup.fish' ^/dev/null | head -n 1)
	if printf "$powerlinebinding" | sed 's/\s//g' | grep -q '.*'
		echo "Found powerline binding in $powerlinebinding"
		echo "source '$powerlinebinding'" >$HOME/.fish-powerline
		echo powerline-setup >>$HOME/.fish-powerline
	else
		echo "Powerline binding was not found!"
		touch $HOME/.fish-powerline
	end
end
source $HOME/.fish-powerline

# export shell variables
set -x EDITOR vim
set -x PATH $PATH ~/scripts ~/.local/bin
set -x MAKEFLAGS -j(nproc) #Make make use all cores

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
abbr gcl     'git clone'
abbr ga      'git add'
abbr gaa     'git add --all'
abbr gc      'git commit'
abbr gf      'git fetch; git status'
abbr gpl     'git pull'
abbr gps     'git push'
abbr gr      'git reset'
abbr gst     'git stash'
abbr gsp     'git stash pop'
abbr gco     'git checkout'
abbr gd      'git diff'
abbr gt      'git log --graph --oneline --all'

# git abbrs for dotfiles
alias dotgit 'git --git-dir=$HOME/.git-hidden --work-tree=$HOME'
abbr  hg     'dotgit'
abbr  hgcl   'dotgit clone'
abbr  hga    'dotgit add'
abbr  hgaa   'dotgit add --all'
abbr  hgc    'dotgit commit'
abbr  hgf    'dotgit fetch; dotgit status'
abbr  hgpl   'dotgit pull'
abbr  hgps   'dotgit push'
abbr  hgr    'dotgit reset'
abbr  hgst   'dotgit stash'
abbr  hgsp   'dotgit stash pop'
abbr  hgco   'dotgit checkout'
abbr  hgd    'dotgit diff'
abbr  hgt    'dotgit log --graph --oneline --all'

function cd
	builtin cd $argv
	if command -v exa >/dev/null
		timeout -v 1 exa
	else
		timeout -v 1 ls
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

