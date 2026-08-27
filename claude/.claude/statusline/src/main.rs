//! What is on the line? JSON path walkers, the three ordered segment lists
//! (`core` / `limits` / `right`), `fit`, the layout ladder, and `main`.
//!
//! A segment is one call in one of the three list-builder functions below,
//! and each function reads top to bottom in render order -- that IS the
//! model. There is no `Segment` type and no builder table: adding, removing
//! or reordering a segment is an edit to one line in one place. See
//! `README.md` for a worked example.

mod facts;
mod git;
mod paint;

use paint::*;
use serde_json::Value;
use std::io::{Read, Write};
use std::path::PathBuf;

// ---- JSON access: five lines cover all eleven paths the line reads --------
fn at<'a>(j: &'a Value, p: &str) -> Option<&'a Value> {
    p.split('.').try_fold(j, |v, k| v.get(k))
}
// See `paint::has_visible`'s doc comment for why this filters at all.
fn text<'a>(j: &'a Value, p: &str) -> Option<&'a str> {
    at(j, p).and_then(Value::as_str).filter(|s| has_visible(s))
}
// WHY: Claude Code has been observed sending a percentage as a JSON STRING
// (`"used_percentage":"50"`) rather than a number. The bash original parsed
// it through `jq`, which is untyped, and rendered the segment as usual;
// before this fallback, `as_f64` returned `None` for a string value
// and the whole segment vanished -- a missing segment, which is the one
// class of difference this project always treats as a bug, not drift. The
// `.filter` still runs LAST, over both paths, so "nan"/"inf" parsed out of a
// string are rejected exactly like a `NaN`/`Infinity` JSON number already was.
fn num(j: &Value, p: &str) -> Option<f64> {
    at(j, p)
        .and_then(Value::as_f64)
        .or_else(|| at(j, p)?.as_str()?.trim().parse().ok())
        .filter(|n| n.is_finite())
}
/// A percentage as the reference prints it: `%.0f`, i.e. ROUND HALF TO
/// EVEN, clamped to a legal percentage. `format!("{:.0}")` is half-to-even;
/// `f64::round()` is not (62.5 -> 63) -- use the format, not `.round()`.
fn round_pct(n: f64) -> i32 {
    format!("{:.0}", n.clamp(0.0, 100.0)).parse().unwrap_or(0)
}
fn pct(j: &Value, p: &str) -> Option<i32> {
    num(j, p).map(round_pct)
}

// ---- core: the left group ---------------------------------------------------
// ---- ADD / REMOVE / REORDER A LEFT SEGMENT BY EDITING THIS FUNCTION ----
fn core(j: &Value) -> Buf {
    let mut b = Buf::default();
    let (user, host, root) = facts::who();

    // Two spaces, not one: a distro logo is inked to the edges of its cell
    // where a letter has side bearing, so one space would weld it to the name.
    if let Some(icon) = facts::os_icon() {
        b.plain(&format!("{icon}  "));
    }
    b.paint(if root { RED } else { GREEN }, &user);
    if let Some(h) = host {
        b.paint(GREEN, &format!("@{h}"));
    }

    let cwd = text(j, "workspace.current_dir")
        .or_else(|| text(j, "cwd"))
        .map_or_else(
            || std::env::current_dir().unwrap_or_default(),
            PathBuf::from,
        );
    match facts::git(&cwd) {
        Some(g) => {
            b.seg(ROSE, REPO, Some(g.repo.as_str()));
            b.seg(GOLD, WT, g.wt.as_deref()); // linked worktrees only
            b.seg(ORANGE, BRANCH, g.branch.as_deref());
            b.seg(NONE, DIR, Some(g.dir.as_str())); // NONE = "" = uncoloured,
        } // matching Starship's [directory]
        None => {
            let path = facts::tilde(&cwd.to_string_lossy());
            b.seg(NONE, DIR, Some(path.as_str())); // not in a repo: the whole path
        }
    }
    b
}

// ---- limits: the rate-limit gauges ------------------------------------------
/// The rate-limit windows, in display order. A window IS its JSON key, its
/// label glyph and its countdown kind (0 none, 1 h:mm, 2 the weekly
/// d:h:mm/coarse form) together, so adding a window is one row here.
///
/// The two clock-bearing glyphs are deliberate: the pair reads as one idea
/// at two scales (near window, far window). "fable" names a model, not a
/// time window, so nothing pictorial or temporal says it -- hence a bare
/// letter and no countdown. Claude Code does not send it today; this is a
/// forward-compatible lookup that costs three lines.
const LIMITS: &[(&str, char, u8)] = &[
    ("five_hour", '\u{f06b0}', 1), // nf-md-update
    ("seven_day", '\u{f16e1}', 2), // nf-md-calendar_clock_outline
    ("fable", 'F', 0),
];

fn limits(j: &Value, now: i64, wide: bool) -> Buf {
    let mut out = Buf::default();
    for (key, label, kind) in LIMITS.iter().copied() {
        let Some(used) = pct(j, &format!("rate_limits.{key}.used_percentage")) else {
            continue;
        };
        let mut b = Buf::default();
        b.plain(&label.to_string()); // labels are uncoloured, like the path
        b.plain(" ");
        let resets_at = num(j, &format!("rate_limits.{key}.resets_at")).unwrap_or(0.0) as i64;
        let left = resets_at.saturating_sub(now);
        if kind > 0 {
            if let Some(c) = countdown(left, kind == 2, wide) {
                b.plain(&c);
                b.plain(" ");
            }
        }
        b.add(&gauge(used, wide));
        out.bar_join(&b);
    }
    out
}

// ---- right: the right group --------------------------------------------------
// Tier / level lookup tables. First matching key wins; no match falls back
// to DIM so an unrecognised model or effort level still shows, just uncoloured.
const MODELS: &[(&str, &str)] = &[
    ("haiku", HAIKU),
    ("sonnet", SONNET),
    ("opus", OPUS),
    ("fable", FABLE),
];
const EFFORTS: &[(&str, &str)] = &[("low", LOW), ("medium", MEDIUM), ("high", HIGH)];

fn right(j: &Value, now: i64, wide: bool) -> Buf {
    let mut b = Buf::default();
    // ---- ADD / REMOVE / REORDER A RIGHT SEGMENT BY EDITING THESE BLOCKS ----
    if let Some(name) = text(j, "model.display_name") {
        // Tier matched on "{id} {display_name}", lowercased, substring,
        // first hit wins in haiku -> sonnet -> opus -> fable order.
        let id = format!("{} {name}", text(j, "model.id").unwrap_or("")).to_lowercase();
        let c = MODELS
            .iter()
            .find(|&&(k, _)| id.contains(k))
            .map_or(DIM, |&(_, c)| c);
        b.seg(c, MODEL, Some(name));
    }
    if let Some(level) = text(j, "effort.level") {
        if b.w > 0 {
            b.plain(" ");
        }
        // The glyph joins the word BEFORE styling, so the sweep and the
        // rainbow cross the icon too -- keeping it outside would mean
        // choosing a solid colour to stand beside a word that deliberately
        // has none.
        let word = format!("{EFFORT} {level}");
        match level {
            "xhigh" => b.add(&shiny(&word, now)),
            "max" => b.add(&rainbow(&word, now)),
            _ => {
                let c = EFFORTS
                    .iter()
                    .find(|&&(k, _)| k == level)
                    .map_or(DIM, |&(_, c)| c);
                b.paint(c, &word);
            }
        }
    }
    let used = num(j, "context_window.total_input_tokens");
    let size = num(j, "context_window.context_window_size").filter(|s| *s > 0.0);
    let p =
        pct(j, "context_window.used_percentage").or_else(|| Some(round_pct(used? / size? * 100.0)));
    if let Some(p) = p {
        let color = ramp(p);
        let label = format!("{p}%");
        b.seg(&color, ring(p), Some(label.as_str()));
        // Dropped first when room is short: the percentage already says how
        // full the window is, and the denominator never changes in a session.
        if wide {
            if let (Some(u), Some(s)) = (used, size) {
                b.plain(" "); // uncoloured, like the divider spaces
                b.paint(DIM, &format!("({}/{})", tokens(u), tokens(s)));
            }
        }
    }
    b
}

// ---- layout: fit + the degradation ladder ------------------------------------

/// `left`, a dim `│`, then spaces out to the right edge. `None` if it
/// doesn't fit, which is how the ladder tests a rung.
///
/// The divider closes the LEFT block rather than opening the right one, so
/// it travels with the percentage it separates and lands where the other
/// dividers on that side already sit, instead of floating off at the far
/// margin. It's priced into the fit here, so it can never be what pushes
/// the line over. Present only when BOTH sides are non-empty -- same rule
/// as `Buf::bar_join` -- so a limits-less split doesn't open line 2 with a
/// divider that separates nothing from nothing.
fn fit(l: &Buf, r: &Buf, w: usize) -> Option<String> {
    let sep_w = if l.w > 0 && r.w > 0 { 2 } else { 0 }; // " " + "│"
    let pad = w.checked_sub(l.w + sep_w + r.w)?;
    (pad >= 1).then(|| {
        if sep_w > 0 {
            format!("{} {DIM}│{RESET}{}{}", l.s, " ".repeat(pad), r.s)
        } else {
            format!("{}{}{}", l.s, " ".repeat(pad), r.s)
        }
    })
}

/// Bar gauges before icon gauges, one line before two: narrowing the
/// batteries costs only detail -- every label, percentage and colour
/// survives the swap -- while splitting costs a whole row of the user's
/// terminal. Rung 3 re-tries the bars because a line carrying only the
/// limits and the right block has far more room than one that also carries
/// the directory.
///
/// `wide` selects which of the two pre-rendered `limits`/`right` pairs a
/// rung uses (index 1, bar gauges + the right group's full token-pair
/// detail; index 0, icon gauges + the terse form) -- it is not "this rung
/// draws a bar", it is "this rung gets the roomier of the two renders".
const LADDER: &[(bool /* wide */, bool /* split */)] =
    &[(true, false), (false, false), (true, true), (false, true)];

// WHY (issue 3): a leading BOM or trailing NUL fails serde_json outright,
// and `unwrap_or` below turns that into Null, dropping every segment for
// a one-byte cause. A prior fix trimmed only a BOM at position 0 and a
// NUL at the very end, so a NUL+anything (e.g. a trailing newline) or a
// leading NUL still lost the line. `trim_matches` peels BOM/NUL/
// whitespace off both ends -- free, since serde_json already tolerates it.
// A standalone fn, not inlined into `render`, so it has something a unit
// test can call without going through stdin.
fn clean_stdin(s: &str) -> &str {
    s.trim_matches(|c: char| c == '\u{feff}' || c == '\0' || c.is_whitespace())
}

fn render() -> String {
    let mut raw = Vec::new();
    // Bytes, not String::read_to_string: one invalid byte anywhere in stdin
    // must not cost the whole JSON.
    let _ = std::io::stdin().read_to_end(&mut raw);
    let lossy = String::from_utf8_lossy(&raw);
    let text = clean_stdin(&lossy);
    let j: Value = serde_json::from_str(text).unwrap_or(Value::Null); // malformed => Null, SILENTLY

    let now = facts::now();
    let w = facts::width();
    let core = core(&j);
    let lim = [limits(&j, now, false), limits(&j, now, true)]; // [icon, bar]
    let rgt = [right(&j, now, false), right(&j, now, true)]; // [narrow, wide]

    // Special case: with nothing to right-align there is nothing to
    // displace onto a second line, so the only lever left is gauge width.
    // Tested with a plain `<= w`, printed left-flush with no padding and no
    // divider.
    if rgt[1].w == 0 {
        for i in [1usize, 0] {
            let mut l = core.clone();
            l.bar_join(&lim[i]);
            if l.w <= w || i == 0 {
                return l.s;
            }
        }
    }

    for (wide, split) in LADDER.iter().copied() {
        let i = usize::from(wide);
        // Line 1 of a split is the core with NO width test at all: the
        // reference refuses to clip or degrade it, so a core wider than the
        // terminal must still reach rung 3 (split, bars) rather than
        // falling through to icons. Do not "fix" this into a fit().
        let mut l = if split { Buf::default() } else { core.clone() };
        l.bar_join(&lim[i]);
        if let Some(line) = fit(&l, &rgt[i], w) {
            return if split {
                format!("{}\n{line}", core.s)
            } else {
                line
            };
        }
    }

    // Rung 5: emit the narrowest style and let it run long rather than clip.
    let mut l = Buf::default();
    l.bar_join(&lim[0]);
    l.bar_join(&rgt[0]);
    format!("{}\n{}", core.s, l.s)
}

fn main() {
    // Any bug, anywhere, degrades to a blank statusline with exit 0 rather
    // than an abort message landing in the user's terminal -- in a RELEASE
    // build. WHY the cfg (issue 6c): silencing the panic hook unconditionally
    // used to hide a real panic from stderr even in a debug build with
    // RUST_BACKTRACE set, which makes this file hostile to whoever is
    // editing it next. A debug build is by definition not the one running
    // in the user's terminal, so let it stay loud; `catch_unwind` below
    // still recovers to a blank line either way, so this only changes what
    // reaches stderr, never the exit code or stdout.
    #[cfg(not(debug_assertions))]
    std::panic::set_hook(Box::new(|_| {})); // a bug must not add stderr noise either
    let out = std::panic::catch_unwind(render).unwrap_or_default();
    let _ = std::io::stdout().write_all(out.as_bytes()); // and no EPIPE panic
}

#[cfg(test)]
mod tests {
    use super::*;

    // m1: regression coverage for issue 1 -- reverting `num`'s string-number
    // `.or_else` fallback (see the WHY above the function) makes this fail,
    // proven with the revert-gate tooling rather than assumed.
    #[test]
    fn num_falls_back_to_a_json_string_number_issue_1() {
        let j: Value = serde_json::from_str(r#"{"p":"50"}"#).unwrap();
        assert_eq!(num(&j, "p"), Some(50.0)); // the fallback path
        let j: Value = serde_json::from_str(r#"{"p":50}"#).unwrap();
        assert_eq!(num(&j, "p"), Some(50.0)); // the plain-number path, unaffected
        let j: Value = serde_json::from_str(r#"{"p":"nan"}"#).unwrap();
        assert_eq!(num(&j, "p"), None); // still rejected post-fallback
    }

    // m1: regression coverage for issue 3 -- reverting `clean_stdin` back to
    // a bare BOM-prefix-only / NUL-suffix-only trim (or no trim at all)
    // makes this fail; see that function's WHY comment for the bug.
    #[test]
    fn clean_stdin_strips_bom_nul_and_whitespace_off_both_ends_issue_3() {
        assert_eq!(clean_stdin("\u{feff}{}"), "{}"); // leading BOM
        assert_eq!(clean_stdin("{}\0"), "{}"); // trailing NUL
        assert_eq!(clean_stdin("{}\0\n"), "{}"); // NUL, then what most tools append
        assert_eq!(clean_stdin("{}\0 "), "{}"); // NUL then a space
        assert_eq!(clean_stdin("{}\0\r\n"), "{}"); // NUL then CRLF
        assert_eq!(clean_stdin("\0{}"), "{}"); // LEADING (not just trailing) NUL
        assert_eq!(clean_stdin("  {}  "), "{}"); // plain whitespace, either end
    }

    #[test]
    fn round_pct_is_half_to_even_and_clamped_to_a_legal_percentage() {
        assert_eq!(round_pct(0.0), 0);
        assert_eq!(round_pct(62.5), 62); // ties go to the nearest EVEN digit
        assert_eq!(round_pct(63.5), 64);
        assert_eq!(round_pct(150.0), 100); // clamped before rounding
        assert_eq!(round_pct(-5.0), 0);
    }

    #[test]
    fn fit_requires_at_least_one_column_of_padding() {
        let l = Buf {
            s: "abc".into(),
            w: 3,
        };
        let r = Buf {
            s: "xy".into(),
            w: 2,
        };
        // Total width including the " │ " divider is 3 + 2 + 2 = 7.
        assert!(fit(&l, &r, 7).is_none()); // exactly full: no room to pad
        assert!(fit(&l, &r, 6).is_none()); // would overflow outright
        let out = fit(&l, &r, 8).unwrap();
        assert!(out.starts_with("abc "));
        assert!(out.ends_with("xy"));
    }

    #[test]
    fn fit_skips_the_divider_when_either_side_is_empty() {
        let out = fit(
            &Buf::default(),
            &Buf {
                s: "xy".into(),
                w: 2,
            },
            5,
        )
        .unwrap();
        assert!(!out.contains('│'));
        assert!(out.ends_with("xy"));
    }
}
