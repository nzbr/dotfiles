//! What does the filesystem say about this repo? Walk up for `.git`,
//! resolve `gitdir:`/`commondir`, read `HEAD`. Nothing else in the crate
//! needs to know git's on-disk layout.
//!
//! No subprocess, no crate: `facts::git` (which turns these four raw facts
//! into a repo/worktree/branch/dir the line can print) was verified against
//! every harness git fixture to agree field-for-field with `gix::discover`
//! -- see `../README.md` for the comparison. The one place the two
//! disagree is an unborn branch, where reading HEAD directly (as this does)
//! is the one that's actually right: `gix`'s `head_ref()` returns `None`
//! before the first commit and silently drops the branch segment.

use std::fs;
use std::path::{Component, Path, PathBuf};

pub struct Git {
    pub workdir: PathBuf,
    pub git_dir: PathBuf,
    pub common: PathBuf,
    pub head: Option<String>,
}

/// Join `raw` onto `base` if relative, then pop `..` and drop `.` textually.
/// Not `canonicalize`: git writes paths like `.../worktrees/wt/../..`, and
/// resolving them against the real filesystem would follow symlinks git
/// itself never asked to follow.
fn normalize(base: &Path, raw: &str) -> PathBuf {
    let p = Path::new(raw);
    let joined = if p.is_absolute() {
        p.to_path_buf()
    } else {
        base.join(p)
    };
    let mut out = PathBuf::new();
    for c in joined.components() {
        match c {
            Component::ParentDir => {
                out.pop();
            }
            Component::CurDir => {}
            other => out.push(other.as_os_str()),
        }
    }
    out
}

/// A guarded read: regular files only, capped well above anything git ever
/// writes here (HEAD/commondir/a gitdir pointer are a few dozen bytes). The
/// type check is what keeps a FIFO from blocking forever and a character
/// device (`/dev/zero`) from reading forever; the size check is what keeps
/// an oversized regular file from becoming the rendered line.
fn read_trim(p: &Path) -> Option<String> {
    let meta = fs::metadata(p).ok()?;
    if !meta.is_file() || meta.len() > 64 * 1024 {
        return None;
    }
    fs::read_to_string(p).ok().map(|s| s.trim().to_string())
}

/// Resolve one directory's `.git` entry -- directory or file -- into its
/// actual git dir. A file covers both linked worktrees and submodules:
/// `gitdir: <path>`, absolute or relative to the directory that holds it.
/// `fs::metadata`, not `symlink_metadata`: a `.git` that is itself a
/// symlink to the real git dir must still resolve, matching real git. A
/// `gitdir:` pointer is required to resolve to a directory that actually
/// exists -- git never leaves one dangling, so a dead target means there is
/// no repo here, and the caller keeps walking up instead of inventing a
/// repo name out of a path nothing lives at.
fn dot_git(dir: &Path) -> Option<PathBuf> {
    let entry = dir.join(".git");
    if fs::metadata(&entry).ok()?.is_dir() {
        return Some(entry);
    }
    let content = read_trim(&entry)?;
    let path = content.strip_prefix("gitdir:")?.trim();
    let resolved = normalize(dir, path);
    fs::metadata(&resolved).ok()?.is_dir().then_some(resolved)
}

/// Walk up from `cwd` looking for a `.git` entry. A bare repository
/// addressed directly has none -- that already *is* "not a work tree", so
/// it needs no special case: `discover` simply returns `None`.
///
/// `cwd` must already be canonical (the caller's job, once, before the
/// walk): real git discovers on the PHYSICAL path (it chdirs and getcwd()s),
/// so walking a path with a symlink component can miss an ancestor `.git`
/// entirely, or -- when the symlink sits exactly at the repo root -- return
/// a `workdir` named after the link rather than the repository.
pub fn discover(cwd: &Path) -> Option<Git> {
    let mut dir = cwd.to_path_buf();
    loop {
        if let Some(git_dir) = dot_git(&dir) {
            // No commondir file => not a linked worktree => common == git_dir,
            // and that equality (tested by the caller) IS the worktree test.
            let common = match read_trim(&git_dir.join("commondir")) {
                Some(c) => normalize(&git_dir, &c),
                None => git_dir.clone(),
            };
            let head = read_trim(&git_dir.join("HEAD"));
            return Some(Git {
                workdir: dir,
                git_dir,
                common,
                head,
            });
        }
        if !dir.pop() {
            return None;
        }
    }
}

/// `ref: refs/heads/X` -> `X`, born or unborn. A bare 7-64 hex digit line is
/// a detached HEAD; take the first 7.
///
/// WHY the broader `strip_prefix("ref: refs/")` (issue 4): HEAD pointing at
/// a ref outside `refs/heads/` -- e.g. `ref: refs/remotes/origin/main`,
/// reachable via `git symbolic-ref HEAD` -- used to fall through to neither
/// branch and drop the segment entirely, which is the one class of
/// difference this project always treats as a bug. The reference resolves
/// it further, to `rev-parse --short HEAD`'s hash; this keeps the ref's own
/// path instead (still recognisable, and no new file read to do it) -- a
/// deviation, not a bug, and documented as one in the README.
pub fn branch_from_head(head: &str) -> Option<String> {
    if let Some(rest) = head.strip_prefix("ref: refs/") {
        return Some(rest.strip_prefix("heads/").unwrap_or(rest).to_string());
    }
    // 40 hex = SHA-1, 64 = SHA-256 (git's newer, opt-in object format); either
    // way take the first 7, matching the reference's short-hash width.
    let looks_detached =
        (7..=64).contains(&head.len()) && head.bytes().all(|b| b.is_ascii_hexdigit());
    looks_detached.then(|| head.chars().take(7).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn branch_from_head_reads_a_ref_or_a_detached_short_hash() {
        assert_eq!(
            branch_from_head("ref: refs/heads/main").as_deref(),
            Some("main")
        );
        assert_eq!(
            branch_from_head("ref: refs/heads/feature/x").as_deref(),
            Some("feature/x")
        );
        // 40 hex chars (SHA-1 detached HEAD): first 7, the reference's width.
        let sha1 = "abcdef0123456789abcdef0123456789abcdef01";
        assert_eq!(branch_from_head(sha1).as_deref(), Some("abcdef0"));
        // Too short to be a plausible hash, and not a ref: no guess.
        assert_eq!(branch_from_head("abcd12"), None);
        assert_eq!(branch_from_head("not-hex-and-too-short"), None);
        // Issue 4: HEAD pointing outside refs/heads/ (a tag, or -- the
        // reported repro -- a remote-tracking ref reached via `git
        // symbolic-ref HEAD`) keeps its ref path rather than vanishing.
        assert_eq!(
            branch_from_head("ref: refs/tags/v1.0").as_deref(),
            Some("tags/v1.0")
        );
        assert_eq!(
            branch_from_head("ref: refs/remotes/origin/main").as_deref(),
            Some("remotes/origin/main")
        );
    }
}
