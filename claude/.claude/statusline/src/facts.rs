//! What does the outside world say? OS icon, `~`-collapsed paths, terminal
//! width, wall clock, whoami/hostname/euid -- and the derivation of
//! repo/worktree/branch/dir out of git.rs's four raw filesystem facts.

use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

pub struct GitFacts {
    pub repo: String,
    pub wt: Option<String>,
    pub branch: Option<String>,
    pub dir: String,
}

fn leaf(p: &Path) -> String {
    p.file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

/// Strip a trailing `/.git` **or else** a trailing `.git` -- test, don't
/// chain, so a checkout inside a directory literally named `x.git` stays
/// `x.git` rather than losing its suffix twice.
fn repo_name(common: &Path) -> String {
    let s = common.to_string_lossy();
    let stripped = s
        .strip_suffix("/.git")
        .or_else(|| s.strip_suffix(".git"))
        .unwrap_or(s.as_ref());
    leaf(Path::new(stripped))
}

/// Repo/worktree/branch/dir out of git.rs's four raw facts. `None` covers
/// every "not a work tree" case uniformly (no repo, a bare repo addressed
/// directly, cwd deleted from under us) -- the caller falls back to the
/// `~`-collapsed path either way, so nothing downstream needs to know which.
pub fn git(cwd: &Path) -> Option<GitFacts> {
    // Canonicalize before walking, not after: discovery must see the same
    // PHYSICAL path real git does (see git::discover's doc comment), and
    // popping components off an already-canonical path stays canonical, so
    // `g.workdir` below comes out physical for free -- no second
    // canonicalize needed just to strip the prefix. A failed canonicalize
    // (deleted cwd, permission denied) drops the whole git block via `?` --
    // a filesystem hiccup looks like "not a repo", which is a safe
    // direction to be wrong in.
    let cwd = cwd.canonicalize().ok()?;
    let g = crate::git::discover(&cwd)?;
    let repo = repo_name(&g.common);
    // A git dir whose common dir IS the filesystem root (only reachable via
    // `git init /`, or a `gitdir:` pointer resolving there) strips to an
    // empty leaf. Treating that as "not a work tree" -- same as no repo at
    // all -- means the caller falls back to printing the plain path instead
    // of a blank repo segment sitting next to a blank dir segment, which is
    // strictly less information for no benefit.
    if repo.is_empty() {
        return None;
    }
    let wt = (g.git_dir != g.common).then(|| {
        let name = leaf(&g.workdir);
        // Worktrees are often parked as `<repo>/<name>`; when the worktree's
        // own leaf collides with the repo name, the parent directory is the
        // name that actually distinguishes it.
        if name == repo {
            g.workdir.parent().map(leaf).unwrap_or(name)
        } else {
            name
        }
    });
    let branch = g.head.as_deref().and_then(crate::git::branch_from_head);

    // Ask the filesystem for the prefix rather than subtracting strings, so
    // a symlinked `/home -> /var/home` can't produce a wrong one.
    let dir = cwd
        .strip_prefix(&g.workdir)
        .ok()?
        .to_string_lossy()
        .trim_end_matches('/')
        .to_string();
    // Standing inside the git dir is not standing in a work tree; git's own
    // --show-toplevel refuses there too.
    if dir == ".git" || dir.starts_with(".git/") {
        return None;
    }
    Some(GitFacts {
        repo,
        wt,
        branch,
        dir,
    })
}

fn home_dir() -> Option<PathBuf> {
    std::env::var("HOME")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
}

/// `$HOME` collapsed to `~`, requiring a `/` boundary. The reference does a
/// bare prefix substitution, so `/home/codex` under `HOME=/home/code`
/// becomes `~x`; requiring the boundary is strictly saner and costs nothing
/// real repos or users ever notice.
pub fn tilde(path: &str) -> String {
    let Some(home) = home_dir() else {
        return path.to_string();
    };
    let home = home.to_string_lossy();
    if path == home {
        return "~".to_string();
    }
    match path.strip_prefix(home.as_ref()) {
        Some(rest) if rest.starts_with('/') => format!("~{rest}"),
        _ => path.to_string(),
    }
}

/// A value's first `"..."` or `'...'` run, stopping at the matching quote --
/// so a trailing ` # comment` after the close quote is dropped along with
/// it. Falls back to the bare trimmed text for an unquoted value.
fn quoted(s: &str) -> String {
    let s = s.trim();
    let mut chars = s.chars();
    match chars.next() {
        Some(q @ ('"' | '\'')) => {
            let rest = chars.as_str();
            rest.find(q)
                .map(|end| &rest[..end])
                .unwrap_or(rest)
                .to_string()
        }
        _ => s.to_string(),
    }
}

/// `(ID, ID_LIKE words)` from `/etc/os-release`. Not a shell-source: split
/// each line on the first `=`, unquote, skip `#` comments. os-release(5)
/// forbids shell expansion and multi-word bare values, so this agrees with
/// every conforming file; the worst case for a non-conforming one is the
/// wrong distro logo or none, and "no logo" is already a supported state.
fn os_release() -> (String, Vec<String>) {
    let (mut id, mut like) = (String::new(), Vec::new());
    let path = Path::new("/etc/os-release");
    // WHY the metadata guard (issue 5): this was the one read left in the
    // crate without one -- read_trim in git.rs and os_symbols below both
    // require a regular file and cap its size, so a FIFO swapped in here
    // (verified: hangs the read forever, with no writer ever arriving) or an
    // oversized file can do here what they were built to rule out everywhere
    // else.
    if fs::metadata(path).is_ok_and(|m| m.is_file() && m.len() <= 64 * 1024) {
        if let Ok(content) = fs::read_to_string(path) {
            for line in content.lines() {
                let Some((k, v)) = line.trim().split_once('=') else {
                    continue;
                };
                match k.trim() {
                    "ID" => id = quoted(v),
                    "ID_LIKE" => like = quoted(v).split_whitespace().map(String::from).collect(),
                    _ => {}
                }
            }
        }
    }
    (id, like)
}

/// A ~20-line stand-in for a TOML parser: the `[os.symbols]` table only,
/// case-insensitive keys, last duplicate wins, a trailing comment on the
/// header is fine. Not a general TOML reader -- an inline table or a dotted
/// key loses its glyph, degrading to the already-supported "no icon" state.
/// Capped at 1 MiB so a mischievous `STARSHIP_CONFIG` can't run us out of
/// memory; required to be a regular file so a FIFO with no writer can't
/// hang `File::open` forever -- Claude Code re-runs this every second, so a
/// hang here would pile up processes.
fn os_symbols(path: &Path) -> HashMap<String, String> {
    let mut map = HashMap::new();
    if !fs::metadata(path).is_ok_and(|m| m.is_file()) {
        return map;
    }
    let Ok(f) = fs::File::open(path) else {
        return map;
    };
    let mut buf = String::new();
    if f.take(1 << 20).read_to_string(&mut buf).is_err() {
        return map;
    }
    let mut in_table = false;
    for line in buf.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix('[') {
            let header = rest.split(']').next().unwrap_or("").trim();
            in_table = header.eq_ignore_ascii_case("os.symbols");
            continue;
        }
        if !in_table {
            continue;
        }
        let Some((k, v)) = line.split_once('=') else {
            continue;
        };
        let key = k.trim().trim_matches(['"', '\'']).to_lowercase();
        map.insert(key, quoted(v));
    }
    map
}

/// The distro glyph out of the user's own Starship config, so the line
/// matches whatever `[os.symbols]` they already maintain instead of
/// duplicating a second distro->glyph table. Candidates in order: `ID`,
/// each word of `ID_LIKE`, `Linux`, `Unknown`, case-insensitive; the FIRST
/// KEY THAT EXISTS wins, whether or not its value is empty -- matching a
/// config that blanks a key on purpose to suppress the icon. The whole
/// trimmed value is returned, not just its first codepoint, so a flag,
/// ZWJ family or VS16 emoji glyph survives intact rather than losing all
/// but its first codepoint. Missing config, empty table, no match, or a
/// matched-but-blank value all mean the same thing: no icon, no indent.
pub fn os_icon() -> Option<String> {
    let cfg = std::env::var("STARSHIP_CONFIG")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .or_else(|| home_dir().map(|h| h.join(".config/starship.toml")))?;
    let table = os_symbols(&cfg);
    let (id, like) = os_release();
    let mut candidates = std::iter::once(id)
        .chain(like)
        .chain(["Linux".to_string(), "Unknown".to_string()])
        .filter(|c| !c.is_empty());
    let value = candidates.find_map(|c| table.get(&c.to_lowercase()))?;
    Some(value.trim())
        .filter(|v| !v.is_empty())
        .map(str::to_string)
}

fn tty_cols() -> Option<i64> {
    let f = fs::File::open("/dev/tty").ok()?;
    let ws = rustix::termios::tcgetwinsize(&f).ok()?;
    (ws.ws_col > 0).then_some(ws.ws_col as i64)
}

// WHY 10_000, not 1_000 (m2, correcting issue 7): the first cut of this
// ceiling was checked only against the harness's widest fixture (240) and a
// single pathological report (`COLUMNS=100_000`), never against a real wide
// terminal -- so it clipped every terminal past 1_004 columns down to
// 1_004, losing flush-right alignment at, say, `COLUMNS=2_000` (a real,
// measured width, 996 columns short of flush under the old ceiling). A
// triple-8K-monitor span at the smallest legible monospace cell (~4px)
// tops out around 2_880 columns, so 10_000 clears any plausible real
// terminal with room to spare, while staying two orders of magnitude below
// the pathological value that motivated having a ceiling at all: a
// `COLUMNS=100_000` terminal now repaints at most 10_000 columns a second,
// not 100_000.
const WIDTH_CEILING: i64 = 10_000;

/// The -4/clamp arithmetic alone, split out so a test can drive it with a
/// raw number instead of an env var or a real tty -- see `width`.
fn clamp_width(raw: i64) -> usize {
    raw.saturating_sub(4).clamp(20, WIDTH_CEILING) as usize
}

/// `COLUMNS`, else the tty, else 80. The -4 is Claude Code's own UI chrome,
/// which eats a few columns beyond what this subprocess can see; the high
/// clamp is what makes a separate padding ceiling unnecessary everywhere
/// else -- every width downstream is bounded by construction.
pub fn width() -> usize {
    let raw = std::env::var("COLUMNS")
        .ok()
        .and_then(|c| c.trim().parse::<i64>().ok())
        .or_else(tty_cols)
        .unwrap_or(80);
    clamp_width(raw)
}

/// One wall-clock reading, epoch seconds. `rem_euclid` in the effort
/// flourishes (not this function) is what keeps a pre-epoch result safe.
pub fn now() -> i64 {
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(d) => d.as_secs() as i64,
        Err(e) => -(e.duration().as_secs() as i64),
    }
}

/// NSS wins whenever it came back non-empty; otherwise `$USER`, then
/// `$LOGNAME`; `""` if none of the three did. Split out of `who()` as a
/// pure function so a test can pin the PRECEDENCE itself -- not just
/// today's inputs -- see `pick_user_prefers_nss_then_user_then_logname`
/// below.
///
/// WHY the fallback exists (M2): a nix-built binary links nixpkgs' glibc,
/// which has no /etc/ld.so.cache and can only dlopen NSS modules from its
/// own store closure -- so on a host whose account comes from a
/// non-builtin NSS source (SSSD, LDAP, winbind: a common corporate-Linux
/// setup), getpwuid_r fails, NSS comes back empty, and the line silently
/// drops to a bare "@host". `$USER`/`$LOGNAME` are what the login stack
/// already exported for this session, recovering the name for free --
/// verified: `strace -f -e trace=openat` shows the nix binary never opens
/// ld.so.cache while a system-glibc build does. NSS must still come
/// first, though: falling back to an unverified env var on a host where
/// NSS already works would be a silent downgrade, not a recovery.
fn pick_user(nss: Option<String>, user: Option<String>, logname: Option<String>) -> String {
    [nss, user, logname]
        .into_iter()
        .find_map(|s| s.filter(|s| !s.is_empty()))
        .unwrap_or_default()
}

/// `(username, short hostname, uid == 0)`. Username is `pick_user` over
/// NSS via `whoami`, `$USER`, `$LOGNAME` in that order; hostname is
/// `gethostname`, a syscall with no NSS dependency, so it has no such
/// fallback. The harness runs under `env -i`, where both env vars are
/// empty too, so the fallback is a no-op there.
pub fn who() -> (String, Option<String>, bool) {
    let user = pick_user(
        whoami::fallible::username().ok(),
        std::env::var("USER").ok(),
        std::env::var("LOGNAME").ok(),
    );
    let host = whoami::fallible::hostname()
        .ok()
        .and_then(|h| h.split('.').next().map(|s| s.to_string()))
        .filter(|h| !h.is_empty());
    let root = rustix::process::geteuid().is_root();
    (user, host, root)
}

#[cfg(test)]
mod tests {
    use super::*;

    // m1: regression coverage for issue 7 (a ceiling must exist) and its
    // m2 correction (the ceiling must not be so tight it clips a real
    // terminal) together, since after m2 the two are one behaviour: a
    // COLUMNS a real terminal can plausibly report passes through
    // unclamped, while a pathological one is still bounded, not left to
    // repaint tens of thousands of columns a second.
    #[test]
    fn clamp_width_bounds_a_pathological_columns_without_clipping_a_real_one() {
        assert_eq!(clamp_width(2_000), 1_996); // m2: real, measured; must stay flush
        assert_eq!(clamp_width(240), 236); // the widest harness fixture
        assert_eq!(clamp_width(100_000), WIDTH_CEILING as usize); // issue 7: still bounded
        assert_eq!(clamp_width(5), 20); // low clamp, unrelated to either ceiling
    }

    // m2: regression coverage for the M2 fallback in `pick_user` -- pins
    // the PRECEDENCE (NSS, then $USER, then $LOGNAME, then "") so a future
    // simplification pass can't quietly delete the fallback without a red
    // test, the way it could before this existed.
    #[test]
    fn pick_user_prefers_nss_then_user_then_logname() {
        // NSS wins over a bogus $USER/$LOGNAME -- the property that keeps
        // this from trusting an unverified env var on a host where NSS
        // already works (see WHY on `pick_user`).
        assert_eq!(
            pick_user(
                Some("real".into()),
                Some("bogus".into()),
                Some("bogus2".into())
            ),
            "real"
        );
        // Empty NSS (whoami's failure-but-Ok("") case, or a plain None)
        // falls to $USER.
        assert_eq!(
            pick_user(None, Some("envuser".into()), Some("logname".into())),
            "envuser"
        );
        // NSS and $USER both empty falls to $LOGNAME.
        assert_eq!(
            pick_user(
                Some(String::new()),
                Some(String::new()),
                Some("fallback".into())
            ),
            "fallback"
        );
        // All three empty/absent -- "", same as the pre-M2 behaviour.
        assert_eq!(pick_user(None, None, None), "");
    }

    #[test]
    fn repo_name_strips_one_git_suffix_never_two() {
        assert_eq!(repo_name(Path::new("/home/user/project/.git")), "project");
        // A bare repo conventionally named `<repo>.git`: the suffix IS the
        // name, so it strips once -- matching how such repos are normally
        // displayed.
        assert_eq!(repo_name(Path::new("/home/user/bare.git")), "bare");
        // A NORMAL (non-bare) repo whose own checkout directory happens to
        // be named `x.git`: only the internal `/.git` strips, so the real
        // directory name survives intact. This is the "test, don't chain"
        // the function's doc comment calls out.
        assert_eq!(repo_name(Path::new("/home/user/x.git/.git")), "x.git");
    }

    #[test]
    fn tilde_requires_a_path_boundary() {
        // A sibling that merely shares the prefix textually (`HOME`-suffixed
        // by one more character) must NOT collapse -- the documented
        // deviation from the reference's bare string substitution.
        if let Ok(home) = std::env::var("HOME") {
            if !home.is_empty() {
                assert_eq!(tilde(&home), "~");
                assert_eq!(tilde(&format!("{home}/project")), "~/project");
                let sibling = format!("{home}x/project");
                assert_eq!(tilde(&sibling), sibling);
            }
        }
        assert_eq!(tilde("/etc/os-release"), "/etc/os-release");
    }
}
