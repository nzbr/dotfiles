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
abbr r 'ranger'

# use exa instead of ls
abbr ls 'exa'
abbr la 'exa -la'
abbr l 'exa -l'

# abbr re 'exec $SHELL' # Restart the current shell
abbr temp 'cd (mktemp -d)'
abbr qemu-kvm 'qemu-system-x86_64 --enable-kvm'

# git abbres
abbr clone    'git clone'
abbr add      'git add'
abbr addall   'git add --all'
abbr commit   'git commit'
abbr fetch    'git fetch; and git status'
abbr pull     'git pull'
abbr push     'git push'
abbr stash    'git stash'
abbr pop      'git stash pop'
abbr gdiff    'git diff'
abbr gtree    'git log --graph --oneline --all'

if test -f ~/.secrets
	source ~/.secrets
end

if [ "$STARTED" != "true" ]; and tty # Run neofetch when opening a terminal (or loggin in)
	neofetch
	set -x STARTED true
end

if test -f ~/.secrets
	source ~/.secrets
end

