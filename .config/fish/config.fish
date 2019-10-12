#                 ___
#  ___======____=---=)
#/T            \_--===)
#[ \ (O)   \~    \_-==)
# \      / )J~~    \-=)
#  \\___/  )JJ~~~   \)                    __ _     _
#   \_____/JJJ~~~~    \                  / _(_)___| |__
#   / \  , \J~~~~~     \                | |_| / __| '_ \
#  (-\)\=|\\\~~~~       L__             |  _| \__ \ | | |
#  (\\)  (\\\)_           \==__         |_| |_|___/_| |_|
#   \V    \\\) ===_____   \\\\\\
#          \V)     \_) \\\\JJ\J\)
#                      /J\JT\JJJJ)
#                      (JJJ| \UUU)
#                       (UU)

if test -f ~/.pre.fish
	source ~/.pre.fish
end

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
abbr fupdate 'rm ~/.update; exec fish'
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
abbr gf      'git fetch'
abbr gs      'git fetch; git status'
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
abbr  hgf    'dotgit fetch'
abbr  hgs    'dotgit fetch; dotgit status'
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

# Network
set -x IP4 (curl -m 1 -4s icanhazip.com ^/dev/null)
set -x IP6 (curl -m 1 -6s icanhazip.com ^/dev/null)
set -x HOST (host "$IP4" ^/dev/null | awk '{print $NF;}' | head -c -2)
set -x HOST6 (host "$IP6" ^/dev/null | awk '{print $NF;}' | head -c -2)

set -x KERNEL (uname -sr)

# Package manager
if command -v pacman >/dev/null
	set cnf "pacman -Fsq"
	set updatecmd "sudo pacman --noconfirm -Fy && sudo pacman --noconfirm -Syu"
    if command -v yay >/dev/null
        set cnf "yay -Fsq"
        set updatecmd "yay --noconfirm -Fy && yay --noconfirm -Syu"
    end
else if command -v apt-get >/dev/null
	set cnf "echo 'To see suggestions, install command-not-found and restart fish'"
	if test -f /usr/lib/command-not-found
		set cnf /usr/lib/command-not-found
	end
	set updatecmd "sudo apt-get update && sudo apt-get -y upgrade"
else if command -v dnf >/dev/null
	set cnf "dnf provides"
	set updatecmd 'sudo dnf -y upgrade --exclude=kernel\* && sudo dnf -y upgrade'
else if command -v zypper >/dev/null
	set cnf "cnf"
	set updatecmd 'zypper dup -y'
end

function fish_greeting
	if ! set -q SUDO_USER
		if ! find $HOME -maxdepth 1 -name '.update' -mtime 0 | grep -q '.*'
			touch $HOME/.update
			fish -c "$updatecmd"
			printf "\n\nUpdating dotfiles\n"
			dotgit pull
			exec fish # Restart
		end
		printf "\nWelcome to fish!\n================\n\n"
		printf "User:\t$USER\n"
		printf "Kernel:\t$KERNEL\n"
		printf "WAN:\tIP4:\t$IP4\n\tIP6:\t$IP6\n\tHOST:\t$HOST\n\tHOST6:\t$HOST6\n"
		if command -v ip >/dev/null
			printf "LAN:"
			ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {print "\t"$2"!\t"$4}' | grep -v ':' | sed 's/!/:/;s@/.*$@@'
		end
		printf "Date:\t"
		date
	end
end

function __fish_command_not_found_handler --on-event fish_command_not_found
	printf "$argv[1] is not installed. Showing suggestions:\n"
	fish -c "$cnf $argv[1]"
	printf "\n$argv[1]: command not found\n"
end

if test -f ~/.post.fish
	source ~/.post.fish
end

