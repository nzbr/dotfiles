# claude-statusline

A from-scratch Rust rewrite of the Claude Code statusline. It keeps the
segments, order, colours, glyphs and layout-degradation behaviour of the
bash script it replaced, but deliberately drops byte-for-byte parity with it
in favour of being small enough for one person to hold in their head. Small differences
— a rounding edge landing one unit differently, a gauge cell shifting by
one, an exotic locale behaving more sanely than the original — are
intentional. A missing/extra segment, wrong data, a line that overflows the
terminal, a crash, or stderr noise are not: those are bugs.

This file is the crate's only external documentation. Everything else lives
next to the code it explains, as doc comments.

## File layout

Four files. Each answers one question; none needs another open to be
understood.

| file | the question it answers |
|---|---|
| `src/main.rs` | **What is on the line?** JSON path walkers, the three ordered segment lists (`core` / `limits` / `right`), `fit`, the `LADDER` table, `render`, `main`. |
| `src/paint.rs` | **What does it look like?** Palette consts, glyph tables, `ramp`, `ring`, `gauge`, `tokens`, `countdown`, `shiny`, `rainbow`, and `Buf` (the width-counting string buffer). |
| `src/facts.rs` | **What does the outside world say?** OS icon (`/etc/os-release` + the `[os.symbols]` scanner), `home`/`tilde`, terminal width, wall clock, `who`, and the derivation of repo/worktree/branch/dir out of `git.rs`'s four raw facts. |
| `src/git.rs` | **What does the filesystem say about this repo?** Walk up for `.git`, resolve `gitdir:`/`commondir`, read `HEAD`. Nothing else in the crate knows git's on-disk layout. |

Run `wc -l src/*.rs` for the current line count rather than trusting a number
written here — it will drift the moment someone adds a segment, and a stale
number in a doc is worse than no number. As of this file, the four modules
(including their `#[cfg(test)]` blocks) total under 1400 lines.

Why four files and not three: git discovery is the one part of the program
that has to know an on-disk format (`.git`, `gitdir:`, `commondir`, `HEAD`),
so it gets its own file and keeps that knowledge out of `facts.rs`. Why four
and not more: a gauge, a colour ramp and an animation are one concern —
turning a number into pixels — so they all stay in `paint.rs`.

## How to add, remove or reorder a segment

There is no `Segment` type and no builder table. `core()`, `limits()` and
`right()` in `main.rs` each read top to bottom in render order — that IS the
model. Each call to `Buf::seg` (or, for a segment with its own styling
instead of one flat colour, the `if let Some(x) = … { … }` shape effort
uses) is one segment.

Worked example — a Kubernetes context between branch and directory:

1. **`paint.rs`**, two lines beside their neighbours in the const block:
   ```rust
   pub const KUBE: char = '\u{f10fe}'; // nf-md-kubernetes
   pub const KUBE_BLUE: &str = "\x1b[38;2;51;157;222m";
   ```
2. **`facts.rs`**, one line wherever the fact comes from — say `GitFacts`
   gains `pub kube: Option<String>`, or a free `pub fn kube() -> Option<String>`.
3. **`main.rs::core`**, one line, in the position you want it printed:
   ```rust
   b.seg(ORANGE, BRANCH, g.branch.as_deref());
   b.seg(KUBE_BLUE, KUBE, facts::kube().as_deref()); // <-- here
   b.seg(NONE, DIR, Some(g.dir.as_str()));
   ```

Three edits, three files, four lines. The leading space, the
omit-when-absent rule, the column measurement, the padding, and every rung
of the degradation ladder adapt on their own, because `Buf` carries its own
width and the ladder only ever asks a group for its total width.

* **Remove** a segment: delete its `b.seg(...)` (or styling block) line, and
  the now-unused consts.
* **Reorder**: move the line.
* **A right-hand segment**: the same, as a block in `right()`.
* **Make it the first thing dropped when room is short**: guard it with the
  `wide` flag the ladder already threads through `limits()`/`right()` —
  `if wide { … }`, exactly as the context ring's `(used/size)` token pair
  does.
* **A new rate-limit window**: one row in the `LIMITS` table, carrying its
  JSON key, its label glyph and its countdown kind together.
* **A new colour or glyph**: one line in `paint.rs`'s const block, where the
  whole palette and every named glyph sit within a screenful of each other.
* **Reorder or drop a ladder rung**: move or delete a tuple in `LADDER`.
  *Not* "a new ladder rung" — `LADDER`'s four tuples already exhaust every
  `(wide, split)` combination there is, so there is no fifth to add by
  editing the table alone. A genuinely new rung needs a third axis (another
  pre-rendered `limits`/`right` pair beside the existing narrow/wide ones),
  which is a bigger change than one tuple.

## Known deviations from the reference

"The reference" throughout this file is the bash implementation this crate
replaced. It is no longer in the repository, but git still has every version
of it — `git log --diff-filter=D -- claude/.claude/statusline-command.sh`
finds the commit that removed it, and `git show <commit>^:<path>` prints it.
A working copy is also kept outside the repo at `backups/statusline-command.sh`
in the home-manager tree, which is what the verification harness renders
against.

Beyond the rounding-edge and cosmetic drift the intro paragraph already
waives, these spots deliberately print something different from what the bash
reference would, rather than nothing:

* **`HEAD` pointing outside `refs/heads/`** (e.g. `ref: refs/remotes/origin/main`,
  reachable via `git symbolic-ref HEAD`) shows the ref's path with `refs/`
  stripped — `remotes/origin/main` — where the reference falls back to
  `rev-parse --short HEAD` and shows a resolved commit hash instead. Showing
  *nothing* here was issue 4, a bug; showing a ref path rather than resolving
  one more file to a hash is the small-and-simple side of fixing it, and is
  the intentional deviation. See `git::branch_from_head`.
* **`COLUMNS` above 10,000** renders at a 10,000-column width regardless of
  the real value (raised from an earlier, too-tight 1,000 that clipped
  flush-right alignment on any terminal past 1,004 columns). The reference
  has no equivalent ceiling and will keep
  padding a line out as far as `COLUMNS` says (bash itself is the only
  limit); this crate trades that for a bound no real terminal is expected to
  reach. See `facts::width`.

Two more are a **residual limitation**, not a chosen trade-off -- both fall
out of `facts::who`, and neither has a smaller fix available without adding
a crate or a subprocess (ruled out by this project's own goal):

* **A nix-built binary whose account comes from a non-builtin NSS source**
  (SSSD, LDAP, winbind — a common corporate-Linux setup on a non-NixOS host)
  cannot complete the username lookup at all: nixpkgs' glibc has no
  `/etc/ld.so.cache` and can only `dlopen` NSS modules from its own store
  closure, so `getpwuid_r` fails outright. `who` falls back to `$USER`, then
  `$LOGNAME`, which recovers the name whenever the login stack exported
  either — but if NEITHER is set (a stripped non-interactive environment,
  some service-manager contexts), the line still renders a bare `@host`,
  where the bash original (`$(whoami)`, system glibc, unaffected by any of
  this) would still resolve one. Note which way round this falls: the
  nix-built binary IS the home-manager path, so home-manager machines are the
  exposed ones. Machines without home-manager run `claude-statusline.sh`,
  which compiles against the system glibc and can load whatever NSS modules
  the host has, so they are unaffected.
* The same fallback chain means username can now come from **an unverified
  environment variable** instead of NSS on such a host — cosmetically
  identical output, but no longer backed by the same guarantee that the name
  is the account's real, `passwd`-registered one. Harmless for a status
  line; worth knowing if this crate is ever reused somewhere that mattered.

## `git.rs` vs `gix`

`git.rs` does its own `.git` discovery (directory or `gitdir:` file,
`commondir`, `HEAD`) instead of depending on `gix`, because the whole reason
to depend on it — not hand-rolling git's on-disk format — costs more in
compile time and MSRV than the format itself costs to read: it is four
facts, in a file you can `wc -l` for yourself.

This was checked against `gix::discover` across the harness's git fixtures
(normal repo, detached HEAD, bare repo, linked worktree, a worktree whose
leaf collides with the repo name, a worktree of a bare repo, a path with
spaces, a submodule, and an unborn branch) and agreed field-for-field with
one exception: on an unborn branch (a repo with no commits yet), `gix`'s
`head_ref()` returns `None` and drops the branch segment entirely, while
reading `HEAD` directly — as `git.rs` does — recovers the branch name for
free. That one disagreement is `git.rs` being right, not a gap to close.

Re-running that comparison is a one-off exercise (add `gix` as a dev
dependency, discover the same fixtures with both, diff the four fields) —
not something worth keeping as a permanent test dependency for a crate whose
whole point is depending on less.

## How it is built and deployed

Two deployments, one crate, one name.

**With nix/home-manager** — `package.nix` beside this file builds the crate
with `rustPlatform.buildRustPackage`, pinned by the checked-in `Cargo.lock`,
and `dotfiles.nix` links the result to
`~/.claude/statusline/claude-statusline` — beside this file.
home-manager re-points that link on every generation switch, so it can never
be stale and can never name a collected store path. `settings.json`'s
`statusLine.command` names that binary directly — no shell, no cache, no
wrapper; see `../skills/setup-claude-config/SKILL.md`, which writes it.
  `.claude/statusline` is `.stowkeep`-ed in the `runCommand` so it unfolds
into a real directory instead of one folded symlink. Without that marker
xstow folds it and home-manager fails the switch outright with
"Error installing file '.claude/statusline/...' outside $HOME" if you try.

**Migrating a machine that predates the unfold — read this before switching.**
A machine whose `~/.claude/statusline` is still the old folded symlink cannot
switch onto this layout directly. `cleanOldGen` leaves that symlink alone
(the new generation wants a *directory* at that path), so `linkNewGen` then
tries to write through it into the read-only store and the switch fails with
`Existing file '~/.claude/statusline/src' would be clobbered`. Delete the
stale symlink first:

```sh
rm ~/.claude/statusline && home-manager switch
```

Rolling *back* to a pre-unfold generation hits the mirror image of this and
needs `rm -rf ~/.claude/statusline` first.

Do **not** reach for `home-manager switch -b backup` here, even though
home-manager's own error message suggests it. Plain `switch` fails safely —
`$HOME` is untouched and the old generation keeps working — but with a backup
extension set the run gets past `checkLinkTargets` and dies mid-link on
`mv: ... Read-only file system`, having already flipped the profile, deleted
the old binary and left `~/.claude/statusline` pointing into the previous
generation. Both spellings of the statusline are then dead, and one
`nix-collect-garbage` from dangling.
  The switch that first builds this derivation on a given machine (or the
first one after a `nix-collect-garbage`) is not free: measured here
(`nix-store -qR --include-outputs` on the derivation, sizes summed from
`nix path-info`), the build closure `rustPlatform.buildRustPackage` pulls
in to compile it is 504 paths, 2,411 MB on disk / 698 MB to download
(rustc alone is 1,040 MB, `llvm-lib` 540 MB, `gcc` 264 MB, `python3`
135 MB) — none of which is part of the 46.4 MB (7 paths) the built
generation actually keeps at runtime. A machine that GCs between switches
pays that cost again on the next switch that touches this crate's sources,
not just once ever; a machine that never GCs, or whose GC roots keep a prior
generation alive, keeps the toolchain cached and pays it only on an actual
source change.

**Without nix** (`control.sh install`, plain xstow) — nothing has built a
binary ahead of time, so `claude-statusline.sh` beside this file compiles
the crate on first use and caches it under `$XDG_CACHE_HOME/claude-statusline`,
keyed on a hash of `Cargo.toml`, `Cargo.lock` and `src/*.rs`. It needs
`cargo` on `PATH` and says so if there is none. It also prefers a built
binary sitting in its own directory (nix's, or the COI image's), so running
it on a machine that already has one is not a way to end up with a second
copy — while running it out of an undeployed checkout still builds that
checkout.

`package.nix` feeds only `Cargo.toml`, `Cargo.lock` and `src/` into the
build, so editing this README or the wrapper recompiles nothing. Note that
nixpkgs overrides the crate's `strip = true`
(`CARGO_PROFILE_RELEASE_STRIP=false` in its `cargoBuildHook`) and strips
from stdenv instead; `package.nix` sets `stripAllList` to get the same
result.

Build it by hand with:

    nix-build -E 'with import <nixpkgs> {}; callPackage ./package.nix {}'
