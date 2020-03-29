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
abbr c 'code'
abbr py 'python'
abbr r 'ranger'
abbr s 'sudo'
abbr ssc 'sudo systemctl'
abbr vi 'vim'
abbr x 'xdg-open'
abbr xc 'xsel -b'

abbr re 'exec fish' # Restart fish
abbr cre 'clear; exec fish'
abbr temp 'pushd (mktemp -d)'
abbr tvim 'vim (mktemp)'
abbr fupdate 'rm ~/.update; exec fish'
abbr mkdir 'mkdir -p'
abbr fork 'kitty &; disown'

## Colors
abbr light 'kitty @ set-colors foreground=black background=white; kitty @ set-bacground-opacity 1'
abbr dark  'kitty @ set-colors --reset; kitty @ set-background-opacity 0.8'
abbr neo   'kitty @ set-colors foreground=green background=black; kitty @ set-background-opacity 1'

# If in a vscode remote shell, open code instead of other editors
if set -q AMD_ENTRYPOINT
	abbr vim code
	abbr vi code
	abbr nano code
else
	abbr --erase vim ^/dev/null
	abbr --erase vi ^/dev/null
	abbr --erase nano ^/dev/null
end

# use exa instead of ls
if command -v exa >/dev/null
	abbr ls 'exa'
	abbr la 'exa -la --git'
	abbr l 'exa -l --git'
else
	abbr --erase ls ^/dev/null
	abbr la "ls -la"
	abbr l "ls -l"
end

# use colordiff
if command -v colordiff >/dev/null
	abbr gdiff (which diff)
	abbr diff colordiff -u
else
	abbr --erase diff ^/dev/null
end

# use bat instead of cat/less
if command -v bat >/dev/null
	abbr cat bat
	abbr less bat
else
	abbr --erase cat ^/dev/null
	abbr --erase less ^/dev/null
end

# QEMU
set kvmcmd 'qemu-system-x86_64 --enable-kvm'
abbr qemu-kvm $kvmcmd
abbr kvm $kvmcmd

# git abbrs
abbr g       'git'
abbr gcl     'git clone'
abbr ga      'git add'
abbr gaa     'git add --all'
abbr gc      'git commit -v'
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
abbr  hgc    'dotgit commit -v'
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

# Subversion
abbr s       'svn'
abbr scl     'svn co'
abbr sa      'svn add'
abbr sc      'svn commit'
abbr sst     'svn status'
abbr spl     'svn update'
abbr st      'svn log | less'

# Custom functions
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

function src
	if ! echo "$argv" | grep -q '.git$'
		echo "This does not look like a git repository"
		return
	end
	builtin cd ~/src
	git clone "$argv"
	cd (echo "$argv" | sed 's:.*/::' | sed 's:\.git$::')
end

# Package manager
if command -v pacman >/dev/null
	set cnf "pacman -Fq"
	set pkginst "sudo pacman -S"
	set updatecmd "sudo pacman --noconfirm -Fy && sudo pacman --noconfirm -Syu"
    if command -v yay >/dev/null
        set cnf "yay -Fq"
		set pkginst "yay -S"
        set updatecmd "yay --noconfirm -Fy && yay --noconfirm -Syu"
    end
	if command -v pkgfile >/dev/null
		set cnf pkgfile
		set updatecmd "$updatecmd && sudo pkgfile -u"
	else
		set cnf "echo -e 'Install pkgfile for faster suggestions\n' >&2; $cnf"
	end
else if command -v zypper >/dev/null
	set cnf "cnf"
	set pkginst 'sudo zypper in'
	set updatecmd 'sudo zypper dup -y'
else if command -v dnf >/dev/null
	set cnf "dnf provides"
	set pkginst 'sudo dnf install'
	set updatecmd 'sudo dnf -y upgrade --exclude=kernel\* && sudo dnf -y upgrade'
else if command -v apt-get >/dev/null
	set cnf "echo 'To see suggestions, install command-not-found and restart fish'"
	if test -f /usr/lib/command-not-found
		set cnf /usr/lib/command-not-found
	end
	set pkginst 'sudo apt-get install'
	set updatecmd "sudo apt-get update && sudo apt-get -y upgrade"
end

function fish_greeting
	if ! set -q SUDO_USER
		# Set Colors
		if test -f ~/.consolecolors.sh
			~/.consolecolors.sh
		end

		# Updates
		if ! find $HOME -maxdepth 1 -name '.update' -mtime 0 | grep -q '.*'
			touch $HOME/.update
			fish -c "$updatecmd"
			printf "\n\nUpdating dotfiles\n"
			dotgit pull
			printf "\n\nUpdating VIM plugins\n"
			if command -v vim >/dev/null
				vim -c "PlugUpdate | qa"
			else if command -v nvim >/dev/null
				nvim -c "PlugUpdate | qa"
			end
			exec fish # Restart
		end
		printf "\nWelcome to fish!\n================\n\n"
		printf "Kernel:\t"(uname -sr)"\n"
		if command -v ip >/dev/null
			printf "LAN:"
			ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {print "\t"$2"!\t"$4}' | grep -v ':' | sed 's/!/:/;s@/.*$@@'
		end
	end
end

function __fish_command_not_found_handler --on-event fish_command_not_found
	printf "$argv[1] is not installed. Showing suggestions:\n"
	if command -v fzf >/dev/null
		fish -c "$pkginst ($cnf $argv[1] | fzf -0 --reverse --height=20% --min-height=7)"
	else
		fish -c "$cnf $argv[1]"
		echo -e "\nfzf is missing on your system. To enable installing suggestions, install fzf"
	end
end

if test -f ~/.post.fish
	source ~/.post.fish
end
