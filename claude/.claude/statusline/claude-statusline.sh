#!/bin/bash
# Wrapper for the statusline crate in this directory, on a machine with no
# nix: build once, then exec the cached binary.
#
# Where home-manager is in charge, package.nix beside this script builds the
# crate and dotfiles.nix links the result to `claude-statusline` in this very
# directory, re-pointed on every generation switch; SKILL.md's merge template
# names that binary directly and this script is never called. What the two
# packaged deployments DO change for this script when it is called anyway (by
# hand, or from a settings.json that names it) is the in-directory binary
# check below, which prefers the built binary over compiling a second copy --
# the COI image build installs one to the same name. Everything below that is
# what runs when neither is true: `control.sh install` (plain xstow) with no
# nix and no built binary here, where this script is the only thing that can
# produce a binary at all.
#
# Claude Code re-runs this every second, so the steady state must be one exec
# and nothing else -- no forks, not even to decide whether the cache is stale.
# So the source hash is not recomputed per call: it lives in a stamp file next
# to the binary, and the hot path only asks bash's builtin `-nt` whether any
# input is newer than that stamp. Two builtin tests and a `read`, then exec.
#
# `exec`, not a child: the test harness (and faketime generally) reaches the
# binary through LD_PRELOAD, which a forked child would not inherit correctly
# for the frozen-clock scenarios.
set -u

dir="${BASH_SOURCE[0]%/*}"
[ "$dir" = "${BASH_SOURCE[0]}" ] && dir="."
case "$dir" in
	/*) ;;
	*) dir="$PWD/$dir" ;;
esac
# Fold "//" and "/./" back out of that path, so the settings.json spelling and a
# `bash ./claude-statusline.sh` from the directory itself land on one cache entry
# instead of building the same sources twice. Parameter substitution only:
# resolving the path properly would mean a `pwd -P` subshell, and the hot path
# below may not fork at all.
while [ "$dir" != "${dir//\/\///}" ]; do dir="${dir//\/\///}"; done
while [ "$dir" != "${dir//\/.\//\/}" ]; do dir="${dir//\/.\//\/}"; done
dir="${dir%/.}"
[ -n "${dir%/}" ] && dir="${dir%/}"

# A built binary sitting in this directory wins: home-manager rebuilds and
# re-points it on every generation switch and the COI image build installs one
# here, so it can never be stale, and preferring it stops a second copy being
# compiled into the cache below. Directory-relative and not $HOME-relative on
# purpose -- running this wrapper out of a working tree finds no binary beside
# it there and so still builds and runs that working tree. Being IN the
# directory rather than beside it is also what makes one test enough on a
# deployed machine: the logical path and the symlink-resolved physical path of
# this script both contain the binary, so neither spelling can miss it. (Run
# straight out of the nix store there is no binary beside this script, and the
# compile path below runs -- correct, if slow, and not a case anything invokes.)
builtbin="$dir/claude-statusline"
[ -x "$builtbin" ] && exec "$builtbin"

# Everything the build depends on. Cargo.lock is listed as well as pinned via
# `--locked`, so a dependency bump produces a new binary rather than a stale
# one plus a lockfile error.
inputs=("$dir/Cargo.toml" "$dir/Cargo.lock" "$dir"/src/*.rs)

cache="${XDG_CACHE_HOME:-${HOME:-/nonexistent}/.cache}/claude-statusline"
# The project path is part of the key, so two checkouts cannot fight over one
# entry; both ends are kept because a file name cannot exceed 255 bytes and a
# nix store path carries its hash at the front.
key="${dir#/}"
key="${key//\//-}"
[ "${#key}" -gt 180 ] && key="${key:0:90}-${key: -90}"
stamp="$cache/$key.stamp"

# --- hot path: builtins only, no forks --------------------------------------
if [ -r "$stamp" ] && read -r cached <"$stamp" && [ -x "$cache/$key-$cached" ]; then
	stale="$cache/$key-$cached"
	for f in "${inputs[@]}"; do
		[ "$f" -nt "$stamp" ] && stale="" && break
	done
	[ -n "$stale" ] && exec "$stale"
	stale="$cache/$key-$cached" # sources moved on; still better than nothing
else
	stale=""
fi

# --- cold path ---------------------------------------------------------------
fail() {
	[ -n "$stale" ] && exec "$stale"
	printf 'statusline: %s\n' "$1" >&2
	exit 127
}

# `cksum` stays INSIDE the pipeline on both sides of `||`: if it read the
# command substitution's own stdin instead (e.g. `... sha256sum || cksum`,
# with no pipe on the right side), a machine with no sha256sum would hash
# that tick's Claude Code JSON instead of the sources -- consuming the JSON
# so that render loses every JSON-derived segment, and keying the cache on a
# per-second-varying payload instead of a stable one.
hash=$(cat "${inputs[@]}" 2>/dev/null | sha256sum 2>/dev/null ||
	cat "${inputs[@]}" 2>/dev/null | cksum) || fail "cannot hash $dir"
hash="${hash%% *}"
bin="$cache/$key-${hash:0:16}"
mkdir -p "$cache" 2>/dev/null
[ -w "$cache" ] || fail "cache $cache is not writable"

# Written last and atomically, so a concurrent invocation sees either the old
# hash and its binary or the new one, never a half-written name.
stamp_it() {
	printf '%s\n' "${hash:0:16}" >"$stamp.$$" && mv -f "$stamp.$$" "$stamp"
	rm -f "$stamp.$$"
}

[ -x "$bin" ] && {
	stamp_it
	exec "$bin"
}
command -v cargo >/dev/null 2>&1 || fail "cargo not found on PATH; cannot build $dir"

log="$cache/build.log"
tmp="$bin.$$.tmp"
if CARGO_TARGET_DIR="$cache/target" cargo build --release --locked \
	--manifest-path "$dir/Cargo.toml" >"$log" 2>&1 &&
	cp -f "$cache/target/release/claude-statusline" "$tmp" && chmod +x "$tmp" &&
	mv -f "$tmp" "$bin"; then
	stamp_it
	for old in "$cache/$key"-*; do
		case "$old" in *.tmp | "$bin") continue ;; esac
		rm -f "$old" 2>/dev/null
	done
	exec "$bin"
fi
rm -f "$tmp" 2>/dev/null
cat "$log" >&2
fail "build failed"
