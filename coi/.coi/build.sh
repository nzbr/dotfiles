set -euxo pipefail

# coi's own build script
# Everything below builds on it, but coi keeps it embedded in its binary and only
# pushes *this* file into the build container, so fetch the matching copy.
# Bump on `coi update`; `coi version` prints what this should be.
COI_VERSION=v0.12.0

# Which agent harnesses get installed into the image
export COI_AGENTS=claude,codex

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl

curl -fsSL -o /tmp/coi-build.sh \
	"https://raw.githubusercontent.com/mensfeld/code-on-incus/$COI_VERSION/internal/image/build.sh"
bash /tmp/coi-build.sh
rm -f /tmp/coi-build.sh

# Its cleanup drops the apt lists again
apt-get update
apt-get -y upgrade
# socat is needed by the claude notification relay, python3 by the login bridge
apt-get install -y --no-install-recommends \
	nix-bin \
	ca-certificates \
	direnv \
	python3 \
	socat \
	xstow

# Starship
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Nix
mkdir -p /nix/store /nix/var/nix/daemon-socket /etc/nix
cat >/etc/nix/nix.conf <<'EOF'
auto-optimise-store = true
experimental-features = nix-command flakes
extra-nix-path = nixpkgs=flake:nixpkgs
max-jobs = auto
ssl-cert-file = /etc/ssl/certs/ca-certificates.crt
bash-prompt-prefix = (nix:$name)\040

extra-substituters = https://nzbr-nix-cache.s3.eu-central-1.wasabisys.com
extra-trusted-public-keys = nzbr-nix-cache.s3.eu-central-1.wasabisys.com:3BzCCe4Frvvwamd5wibtMAcEKwbVs4y2xKUR2vQ8gIo=
EOF

# direnv
sudo -u code mkdir -p /home/code/.config/direnv
cat >/home/code/.config/direnv/direnv.toml <<EOF
[global]
# The first dev-shell load in a cold container is slow; don't nag about it.
warn_timeout = "300s"

[whitelist]
# Security!
prefix = ["/"]
EOF

# mise
# coi's script activates it from /etc/profile.d/mise.sh, ~/.bashrc and ~/.profile,
# all of which run after our hook, and its prompt hook re-prepends the tool dirs on
# every prompt -- so its python won over the dev shell's. Toolchains come from nix
# here, so rip mise out instead of trying to out-order it.
rm -f /usr/local/bin/mise /etc/profile.d/mise.sh
sed -i '/mise/d' /home/code/.bashrc /home/code/.profile
rm -rf /home/code/.local/share/mise /home/code/.config/mise

# tmux
# coi's /etc/tmux.conf leaves terminal-features unset, so tmux assumes the
# outer terminal is 256-color and quantizes every truecolor sequence that passes
# through it. The per-user file is loaded after /etc/tmux.conf, so this wins.
cat >/home/code/.tmux.conf <<'EOF'
set -as terminal-features ",*:RGB"
EOF

# Shell init hook
mkdir -p /etc/coi
cat >/etc/coi/set-environment.sh <<'EOF'
# `coi run` passes no HOME (only `coi shell` does). nix wants it for ~/.cache/nix and
# direnv resolves its config dir from it, failing outright without it.
if [ -z "${HOME:-}" ]; then
  HOME=$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)
  [ -n "$HOME" ] && export HOME
fi

eval "$(direnv hook bash)" || true
eval "$(starship init bash)" || true

[ -n "${COI_DEVSHELL_ACTIVE:-}" ] && return 0
export COI_DEVSHELL_ACTIVE=1
eval "$(direnv export bash)" || true
EOF
chmod +x /etc/coi/set-environment.sh

ln -s /etc/coi/set-environment.sh /etc/profile.d/20-coi.sh

# Claude notification relay
cat >/etc/tmpfiles.d/run-user-1000.conf <<EOF
d /run/user/1000 0700 1000 1000 - -
EOF

# Skills directory
# xstow folds a target directory that does not exist yet into a single symlink
# onto the package, so ~/.claude/skills would land on the git checkout and every
# skill installed later would be written into a working tree. Pre-creating it
# with a .stowkeep inside makes it non-empty, so xstow descends and links the
# individual skills instead. Same trick, and same file name, as the nix path in
# home-manager's dotfiles.nix -- except that one deletes the marker afterwards
# because the tree becomes home-manager file entries; here it stays, so a later
# control.sh re-link keeps the directory unfolded.
#
# ~/.claude/statusline deliberately keeps folding -- the prebuild below writes
# into the checkout through it.
sudo -u code mkdir -p /home/code/.claude/skills
sudo -u code touch /home/code/.claude/skills/.stowkeep

# Dotfiles
sudo -u code sh -c 'curl -s https://raw.githubusercontent.com/nzbr/dotfiles/refs/heads/master/control.sh | bash -'

# Statusline
# The dotfiles install above deploys the wrapper, which compiles the crate
# beside it on first use -- but mise was ripped out above and nix brings no
# toolchain of its own, so there is no cargo in this image and the first
# render would be blank. Build it once here instead, into the statusline
# directory itself -- the path the wrapper execs in preference to compiling,
# and that a settings.json seeded from a nix host names outright.
#
# That directory is the git checkout line 107 cloned (xstow folded
# ~/.claude/statusline into a symlink onto it), so this really does drop a
# build artifact into a working tree. .gitignore in the crate covers the
# name; nobody commits from this throwaway clone anyway.
#
# Ubuntu's cargo and not nix: the crate's MSRV is 1.75, exactly what 24.04
# ships, for 92 MB of downloads against nix's 755 MB. Nix could not do it
# anyway -- /nix/store is bind-mounted from the host at run time, so what
# this build puts in the image's store is invisible there, and a nix-built
# binary copied out of it dies on its missing interpreter.
#
# Fails soft on purpose: an unreachable crates.io, or a Cargo.lock bumped to
# v4 by a newer cargo, must not fail the whole image build. The wrapper is
# deployed either way.
statusline=/home/code/.dotfiles/claude/.claude/statusline
if [ -f "$statusline/Cargo.toml" ]; then
	if apt-get install -y --no-install-recommends cargo &&
		env CARGO_HOME=/tmp/statusline-build/cargo \
			CARGO_TARGET_DIR=/tmp/statusline-build/target \
			cargo build --release --locked --manifest-path "$statusline/Cargo.toml"; then
		install -o code -g code -m 755 \
			/tmp/statusline-build/target/release/claude-statusline \
			"$statusline/claude-statusline"
		# The wrapper looks for the binary beside itself at
		# ~/.claude/statusline/, which reaches the checkout only while xstow
		# keeps folding that directory into a symlink. Say so if it ever stops,
		# rather than silently going back to compiling on first render.
		[ -x /home/code/.claude/statusline/claude-statusline ] ||
			echo "statusline: built, but not reachable via ~/.claude/statusline -- check the xstow layout" >&2
	else
		echo "statusline: prebuild failed; it compiles on first use instead" >&2
	fi
	rm -rf /tmp/statusline-build
	# autoremove rather than a list of names: cargo's dependencies are
	# libstd-rust-<version> and libllvm<version>t64, whose names move with
	# whatever rustc the distro ships.
	apt-get purge -y cargo
	apt-get autoremove -y --purge
fi

# Shared Claude Code History, Skills and Styles
sudo -u code mkdir -p /home/code/.claude{,-shared/{projects,skills,output-styles}}
rm -rf /home/code/.claude/{projects,skills,output-styles}
ln -sfn /home/code/.claude-shared/projects /home/code/.claude/projects
ln -sfn /home/code/.claude-shared/skills /home/code/.claude/skills
ln -sfn /home/code/.claude-shared/output-styles /home/code/.claude/output-styles
chown -h 1000:1000 /home/code/.claude/{projects,skills,output-styles}

apt-get clean
rm -rf /var/lib/apt/lists/*
