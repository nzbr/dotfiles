# How the statusline binary is built by nix.
#
# It lives beside the crate, not in the home-manager repo, because flake.nix
# consumes this repository as a plain source input (`flake = false`): outputs
# declared here would never be read, so the only thing that can reach a
# package is `callPackage` on a path. See dotfiles.nix for the call.
#
# By hand:  nix-build -E 'with import <nixpkgs> {}; callPackage ./package.nix {}'
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "claude-statusline";
  # Read out of Cargo.toml rather than duplicated here: a plain file read
  # (Cargo.toml is already in the `fileset` below), not IFD -- there is no
  # derivation build involved in evaluating it.
  version = (lib.importTOML ./Cargo.toml).package.version;

  # An allowlist rather than `./.`: a plain `cargo build` inside the crate
  # leaves a `target/` that .gitignore hides from git but not from nix, so
  # `./.` would drag hundreds of MB into the store. README and wrapper edits
  # would also otherwise force a recompile.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  # The checked-in lockfile IS the dependency pin, so there is no vendor hash
  # to re-compute every time a .rs file changes.
  cargoLock.lockFile = ./Cargo.lock;

  # Cargo.toml asks for `strip = true`, but nixpkgs' cargoBuildHook exports
  # CARGO_PROFILE_RELEASE_STRIP=false and hands stripping to stdenv, which by
  # default removes only debug sections. This restores the crate's intent,
  # worth roughly a fifth of the binary (exact sizes drift with every edit,
  # so measure rather than trusting a number here).
  stripAllList = [ "bin" ];

  meta = {
    description = "Statusline renderer for Claude Code";
    mainProgram = "claude-statusline";
    license = lib.licenses.isc;
    platforms = lib.platforms.unix;
  };
}
