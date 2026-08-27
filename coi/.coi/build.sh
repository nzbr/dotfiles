set -euxo pipefail

# coi's own build script
# Everything below builds on it, but coi keeps it embedded in its binary and only
# pushes *this* file into the build container, so fetch the matching copy.
# Bump on `coi update`; `coi version` prints what this should be.
COI_VERSION=v0.11.0

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl

curl -fsSL -o /tmp/coi-build.sh \
	"https://raw.githubusercontent.com/mensfeld/code-on-incus/$COI_VERSION/internal/image/build.sh"
bash /tmp/coi-build.sh
rm -f /tmp/coi-build.sh

# Its cleanup drops the apt lists again
apt-get update
apt-get -y upgrade
# socat is needed by the claude notification relay
apt-get install -y --no-install-recommends \
	nix-bin \
	ca-certificates \
	direnv \
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

# Shared Claude Code History
sudo -u code mkdir -p /home/code/.claude{,-shared/projects}
rm -rf /home/code/.claude/projects
ln -sfn /home/code/.claude-shared/projects /home/code/.claude/projects
chown -h 1000:1000 /home/code/.claude/projects

# Claude notification relay
cat >/etc/tmpfiles.d/run-user-1000.conf <<EOF
d /run/user/1000 0700 1000 1000 - -
EOF

# Dotfiles
sudo -u code sh -c 'curl -s https://raw.githubusercontent.com/nzbr/dotfiles/refs/heads/master/control.sh | bash -'

apt-get clean
rm -rf /var/lib/apt/lists/*

