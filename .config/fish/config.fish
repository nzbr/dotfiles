alias dotgit 'command git --git-dir=$HOME/.git-hidden --work-tree=$HOME'

echo "Migrating dotfiles..."
set temp (mktemp)
cp -v control.sh "$temp"

set files (dotgit ls-tree --full-tree --name-only -r HEAD)
rm -vrf $files
for file in $files
	rmdir (dirname $file)
end
rm -rf .git-hidden

bash "$temp"
exec fish

