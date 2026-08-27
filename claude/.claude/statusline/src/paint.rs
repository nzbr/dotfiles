//! What does it look like? The whole palette, every glyph and both gauge
//! shapes live within a screenful of each other -- and `Buf`, the buffer
//! that counts display width as it writes, so nothing downstream ever has
//! to measure a styled string by stripping the colour back out of it.

use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

/// Display width: the LARGER of the per-character sum and the string-level
/// width, because each one alone undercounts a different multi-codepoint
/// sequence, and undercounting is the one direction that can overflow a
/// line.
///
/// `unicode-width`'s string-level width merges emoji ZWJ, modifier and
/// regional-indicator-flag sequences down to the 1-2 columns they are
/// INTENDED to occupy -- correct on terminals that render them merged, but
/// an undercount on ones that draw each component separately, where a
/// summed-per-character width is the correct, larger figure.
///
/// A variation-selector emoji (base char + U+FE0F) is the mirror image:
/// U+FE0F is a zero-width combining mark on its own, so summing per
/// character gives the BASE character's narrow text-presentation width
/// (verified: 1, not 2) -- an undercount on the terminals that honour the
/// selector and draw the pair as one wide emoji glyph, where the
/// string-level width is the correct, larger figure.
///
/// Taking the max is never narrower than either case, at the cost of a
/// little unused padding on whichever terminal family a given sequence
/// doesn't match, and it costs nothing extra for every other glyph this
/// line emits (single codepoints, where both methods already agree).
fn width(t: &str) -> usize {
    let per_char: usize = t.chars().map(|c| c.width().unwrap_or(0)).sum();
    per_char.max(t.width())
}

// ---- SGR building blocks ---------------------------------------------------
pub const RESET: &str = "\x1b[0m";
pub const DIM: &str = "\x1b[2m"; // furniture: dividers, casing, fallback colour
pub const GREEN: &str = "\x1b[32m"; // basic SGR (not truecolor) so user@host
pub const RED: &str = "\x1b[31m"; // follows the terminal's own theme
pub const NONE: &str = ""; // "" = uncoloured; `Buf::paint` treats it specially
pub const TRACK: &str = "\x1b[48;2;78;78;78m"; // #4E4E4E background, drained cells

fn rgb(c: [i32; 3]) -> String {
    format!("\x1b[38;2;{};{};{}m", c[0], c[1], c[2])
}

// ---- fixed palette ----------------------------------------------------------
// Rose / gold / orange are deliberately three separated hues, not three
// shades of one: repo and branch sit side by side on every line inside a
// repo, and Claude Code dims the whole row, so a single hue step would
// collapse them into each other. Rose is exactly xterm-256 index 168 in
// truecolor form, so it survives a non-RGB terminal unchanged.
pub const ROSE: &str = "\x1b[38;2;215;95;135m"; // repo     #D75F87
pub const GOLD: &str = "\x1b[38;2;252;203;125m"; // worktree #FCCB7D
pub const ORANGE: &str = "\x1b[38;2;252;161;125m"; // branch   #FCA17D

pub const HAIKU: &str = "\x1b[38;2;126;231;200m"; // #7EE7C8
pub const SONNET: &str = "\x1b[38;2;111;168;255m"; // #6FA8FF
pub const OPUS: &str = "\x1b[38;2;199;146;234m"; // #C792EA
pub const FABLE: &str = "\x1b[38;2;255;216;102m"; // #FFD866

pub const LOW: &str = "\x1b[38;2;255;193;7m"; // #FFC107
pub const MEDIUM: &str = "\x1b[38;2;78;186;101m"; // #4EBA65
pub const HIGH: &str = "\x1b[38;2;177;185;249m"; // #B1B9F9
const XHIGH: [i32; 3] = [175, 135, 255]; // #AF87FF, base of the shiny sweep

// ---- glyphs (Nerd Font PUA codepoints; all width 1 under unicode-width) ----
pub const REPO: char = '\u{f401}'; // nf-oct-repo
pub const WT: char = '\u{f00fb}'; // nf-md-call_split
pub const BRANCH: char = '\u{f418}'; // nf-oct-git_branch
pub const DIR: char = '\u{f413}'; // nf-oct-file_directory
pub const MODEL: char = '\u{f0ae2}'; // nf-md-star_four_points
pub const EFFORT: char = '\u{f04c5}'; // nf-md-speedometer

// A nine-step filling circle, nearest eighth.
const RING: [char; 9] = [
    '\u{f043d}',
    '\u{f0a9e}',
    '\u{f0a9f}',
    '\u{f0aa0}',
    '\u{f0aa1}',
    '\u{f0aa2}',
    '\u{f0aa3}',
    '\u{f0aa4}',
    '\u{f0aa5}',
];
/// 0%, 1-4%, 5-9%, then one glyph per ten, then 100% -- 13 states, floored
/// to their ten, with three extra stages inside the last tenth, where
/// knowing how close the limit is matters most.
const BATT: [char; 13] = [
    '\u{f125e}',
    '\u{f10cd}',
    '\u{f008e}',
    '\u{f007a}',
    '\u{f007b}',
    '\u{f007c}',
    '\u{f007d}',
    '\u{f007e}',
    '\u{f007f}',
    '\u{f0080}',
    '\u{f0081}',
    '\u{f0082}',
    '\u{f0079}',
];
// Indexed by eighths remaining in the partial cell; index 0 (no remainder)
// is the empty string on purpose, so callers never special-case it.
const EIGHTHS: [&str; 8] = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"];

/// Every percentage on the line -- both gauges and the context ring -- goes
/// through this one gradient, so a number and its glyph always agree and
/// "cool = empty, hot = full" reads the same way everywhere. Integer lerp
/// on purpose: a float lerp would shift a channel by one for free, and nothing
/// here needs that precision. The 33/33/34 stop widths fall out of the table
/// below, so nobody has to remember the third leg is one wider.
const STOPS: [(i32, [i32; 3]); 4] = [
    (0, [70, 140, 235]),
    (33, [90, 200, 110]),
    (66, [235, 200, 70]),
    (100, [235, 80, 70]),
];

pub fn ramp(p: i32) -> String {
    let p = p.clamp(0, 100);
    let i = STOPS.iter().rposition(|s| p >= s.0).unwrap_or(0).min(2);
    let (a, b) = (STOPS[i], STOPS[i + 1]);
    rgb(std::array::from_fn(|c| {
        a.1[c] + (b.1[c] - a.1[c]) * (p - a.0) / (b.0 - a.0)
    }))
}

/// Bucket = nearest eighth of `p`, i.e. `round(p * 8 / 100)` done as
/// integers by adding half the denominator first.
pub fn ring(p: i32) -> char {
    RING[((p * 8 + 50) / 100).clamp(0, 8) as usize]
}

/// `used` is a USED percentage; the gauge draws and prints what is LEFT but
/// is coloured by what is USED, so a nearly-exhausted limit is a short RED
/// 8%, not a reassuring green one -- and the palette stays consistent with
/// the context ring, which shows *and* colours used. This is deliberate;
/// do not "fix" it.
pub fn gauge(used: i32, bar: bool) -> Buf {
    let (c, left) = (ramp(used), 100 - used.clamp(0, 100));
    let mut b = Buf::default();
    if !bar {
        let i = match left {
            0 => 0,
            1..=4 => 1,
            5..=9 => 2,
            100 => 12,
            _ => 2 + left / 10,
        };
        b.paint(&c, &format!("{} {left}%", BATT[i as usize]));
        return b;
    }
    // 8 cells x 8 eighths = 64 slices. Eight cells because the quarter marks
    // then fall on cell boundaries (2 cells = exactly 25%), so halving the
    // bar by eye is accurate; ten cells cannot do that. The clamp does both
    // rules at once: any charge at all shows >= 1 slice (a nearly-dead limit
    // is never a bare track), and eight full cells is reserved for exactly
    // 100% (a bar that looks full really is).
    let slices = (left * 64 / 100).clamp(i32::from(left > 0), 63 + i32::from(left == 100));
    let (filled, part) = ((slices / 8) as usize, EIGHTHS[(slices % 8) as usize]);
    // The casing walls each ink the half of their cell facing the charge, so
    // they butt straight against it with no dead gap -- box-drawing walls
    // draw down the centre of their cell and cannot. U+1FB1B also inks the
    // middle-right sixth, the battery's positive terminal, at no extra column.
    b.raw(DIM);
    b.plain("▐");
    b.raw(RESET);
    b.raw(&c);
    b.plain(&"█".repeat(filled));
    // Drained cells are blank on the grey track, not dim stipple: the charge
    // then ends on a hard edge instead of fading into a second texture.
    b.raw(TRACK);
    b.plain(part);
    b.plain(&" ".repeat(8 - filled - usize::from(!part.is_empty())));
    b.raw(RESET);
    b.raw(DIM);
    b.plain("\u{1fb1b}");
    b.raw(RESET);
    b.plain(" ");
    b.paint(&c, &format!("{left}%"));
    b
}

/// h:mm, d:hh:mm, or the coarse `Nd`/`Nh` the icon style uses. All FLOORED:
/// rounding up would turn 23h59m into "24h", contradicting the day tier
/// above it -- a worse lie than "0h". Fixed width is the point: a
/// variable-length countdown would shift everything after it every refresh.
pub fn countdown(secs: i64, weekly: bool, bar: bool) -> Option<String> {
    if secs <= 0 {
        return None;
    }
    let (d, h, m) = (secs / 86_400, (secs % 86_400) / 3600, (secs % 3600) / 60);
    Some(if !weekly {
        format!("{:02}:{:02}", secs / 3600, m)
    } else if bar {
        format!("{d}:{h:02}:{m:02}")
    } else if d > 0 {
        format!("{d}d")
    } else {
        format!("{h}h")
    })
}

/// `n < 1000` verbatim, else thousands with a `k`.
pub fn tokens(n: f64) -> String {
    if n < 1000.0 {
        format!("{n:.0}")
    } else {
        format!("{:.0}k", n / 1000.0)
    }
}

/// A bright pip walks the word once a second, then a three-second pause,
/// then loops. Stateless: the frame comes straight from the wall clock
/// because Claude Code re-runs this program from scratch on every refresh.
pub fn shiny(word: &str, now: i64) -> Buf {
    let len = word.chars().count() as i64;
    // rem_euclid, not `%`: a pre-1970 clock (a faketime test fixture, say)
    // must still yield a valid, non-panicking frame.
    let p = now.rem_euclid(len + 3);
    let pos = if p < len { p } else { -100 }; // -100: comfortably >1 from any i, i.e. "paused"
    let mut b = Buf::default();
    for (i, ch) in word.chars().enumerate() {
        let dist = (i as i64 - pos).abs();
        let k = match dist {
            0 => 100,
            1 => 45,
            _ => 0,
        };
        let c = rgb(std::array::from_fn(|c| {
            XHIGH[c] + (255 - XHIGH[c]) * k / 100
        }));
        b.paint(&c, &ch.to_string());
    }
    b
}

/// Every character sits at a different point on the hue wheel and the whole
/// wheel spins: 60 degrees of hue per character, 97 degrees per second (97
/// is coprime with 360, so the sequence doesn't visibly loop at 1 fps).
pub fn rainbow(word: &str, now: i64) -> Buf {
    let mut b = Buf::default();
    for (i, ch) in word.chars().enumerate() {
        let h = (now.wrapping_mul(97) + i as i64 * 60).rem_euclid(360) as f64 / 60.0;
        // Standard HSV->RGB at value=100%. Saturation 65, not 100: at full
        // saturation one channel always bottoms out at 0, which reads
        // noticeably darker than the others; 65 lifts that floor to
        // floor(0.35*255)=89 so every hue in the rotation looks equally
        // bright. This is the single most important number in this function.
        let f = |n: f64| {
            let k = (n + h) % 6.0;
            (255.0 * (1.0 - 0.65 * k.min(4.0 - k).clamp(0.0, 1.0))) as i32
        };
        let c = rgb([f(5.0), f(3.0), f(1.0)]);
        b.paint(&c, &ch.to_string());
    }
    b
}

/// Does `s` have at least one NON-control character? Issue 6b: the shared
/// predicate behind `main::text` (should a JSON field count as present) and
/// `Buf::seg` below (should a segment render at all) -- unified because the
/// two were the same closure with two near-identical explanations of it. An
/// all-control-character value (a lone "\n", found by fuzzing) must count as
/// absent: `Buf::plain` strips control characters before counting width, so
/// something that renders as nothing must not still open a glyph and a
/// space for it.
pub fn has_visible(s: &str) -> bool {
    s.chars().any(|c| !c.is_control())
}

/// A styled run of text that always knows its own display width, so nothing
/// downstream ever has to strip SGR back out to measure it -- and a segment
/// cannot be added without its width being added in the same call.
#[derive(Default, Clone)]
pub struct Buf {
    pub s: String,
    pub w: usize,
}

impl Buf {
    /// Escape bytes. Zero columns, and the ONLY way an ESC enters the buffer.
    pub fn raw(&mut self, esc: &str) {
        self.s.push_str(esc);
    }

    /// Visible text, counted. Control characters are dropped first: a
    /// branch or model name carrying a raw `\x1b[41m` would otherwise
    /// recolour the rest of the line, and would score as one column instead
    /// of the five it actually occupies as text -- so the invariant "the
    /// buffer's width matches what lands on screen" would silently break.
    /// Filtering here rather than at each ingest point makes it structural.
    pub fn plain(&mut self, t: &str) {
        if t.chars().any(char::is_control) {
            let clean: String = t.chars().filter(|c| !c.is_control()).collect();
            self.w += width(&clean);
            self.s.push_str(&clean);
            return;
        }
        self.w += width(t);
        self.s.push_str(t);
    }

    pub fn paint(&mut self, c: &str, t: &str) {
        if c.is_empty() {
            return self.plain(t); // "" == uncoloured, matches NONE
        }
        self.raw(c);
        self.plain(t);
        self.raw(RESET);
    }

    pub fn add(&mut self, o: &Buf) {
        self.s.push_str(&o.s);
        self.w += o.w;
    }

    /// ` <glyph> <text>`, or nothing when there is no text. The leading
    /// space appears only when something already precedes it, so an absent
    /// segment leaves no stray gap and a group never opens with one. This
    /// one method is the whole of "an absent segment leaves no double
    /// space", for both the left group and the right one.
    pub fn seg(&mut self, c: &str, g: char, t: Option<&str>) {
        // Not just `!t.is_empty()`: see `has_visible`'s doc comment.
        if let Some(t) = t.filter(|t| has_visible(t)) {
            if self.w > 0 {
                self.plain(" ");
            }
            self.paint(c, &format!("{g} {t}"));
        }
    }

    /// ` │ ` (dim) between two non-empty runs; nothing when either is
    /// empty. This is the whole of "no dividers around a missing sibling",
    /// and it's also what makes the core-to-limits divider the same rule as
    /// limit-to-limit.
    pub fn bar_join(&mut self, o: &Buf) {
        if o.w == 0 {
            return;
        }
        if self.w > 0 {
            self.plain(" ");
            self.paint(DIM, "│");
            self.plain(" ");
        }
        self.add(o);
    }
}

// Pure-function arithmetic only: the exact spots the module's own doc
// comments call out as "must stay exact" (the ramp's integer lerp, the
// ring's nearest-eighth bucketing, the gauge's 64-slice clamp, the
// countdown's floor). None of this needs I/O, so none of it needs a harness
// to catch a regression.
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ramp_hits_its_four_stops_exactly_and_clamps_outside_them() {
        assert_eq!(ramp(0), rgb([70, 140, 235]));
        assert_eq!(ramp(33), rgb([90, 200, 110]));
        assert_eq!(ramp(66), rgb([235, 200, 70]));
        assert_eq!(ramp(100), rgb([235, 80, 70]));
        assert_eq!(ramp(150), ramp(100));
        assert_eq!(ramp(-10), ramp(0));
        // Integer lerp partway between two stops -- verified, not just
        // "some colour in between".
        assert_eq!(ramp(50), rgb([164, 200, 90]));
    }

    #[test]
    fn ring_buckets_to_the_nearest_eighth() {
        assert_eq!(ring(6), RING[0]); // 6.25% rounds down to the empty ring
        assert_eq!(ring(7), RING[1]); // one eighth up from there
        assert_eq!(ring(93), RING[7]);
        assert_eq!(ring(94), RING[8]); // 93.75% is the flip to "full"
        assert_eq!(ring(100), RING[8]);
    }

    #[test]
    fn gauge_bar_never_shows_a_bare_track_while_anything_remains() {
        // 99% used = 1% left: a sliver, not an empty track.
        let almost_empty = gauge(99, true);
        assert!(!almost_empty.s.contains('█'));
        assert!(almost_empty.s.contains('▏'));
        // 0% used = 100% left: all 8 cells solid, no partial cell.
        assert_eq!(gauge(0, true).s.matches('█').count(), 8);
        // 100% used = 0% left: fully drained.
        assert_eq!(gauge(100, true).s.matches('█').count(), 0);
    }

    #[test]
    fn gauge_icon_buckets_left_percentage_into_the_right_glyph() {
        assert!(gauge(100, false).s.contains(BATT[0])); // 0% left
        assert!(gauge(96, false).s.contains(BATT[1])); // 4% left
        assert!(gauge(91, false).s.contains(BATT[2])); // 9% left
        assert!(gauge(50, false).s.contains(BATT[7])); // 50% left
        assert!(gauge(0, false).s.contains(BATT[12])); // 100% left
    }

    #[test]
    fn countdown_floors_instead_of_rounding_up_a_tier() {
        assert_eq!(countdown(0, false, false), None);
        assert_eq!(countdown(-5, false, false), None);
        assert_eq!(countdown(3661, false, false).as_deref(), Some("01:01"));
        assert_eq!(countdown(36_000, false, false).as_deref(), Some("10:00"));
        assert_eq!(countdown(90_000, true, true).as_deref(), Some("1:01:00"));
        assert_eq!(countdown(90_000, true, false).as_deref(), Some("1d"));
        assert_eq!(countdown(18_000, true, false).as_deref(), Some("5h"));
        // A day minus one second must NOT round up to "1d".
        assert_eq!(countdown(86_399, true, false).as_deref(), Some("23h"));
    }

    #[test]
    fn tokens_switches_to_k_at_one_thousand() {
        assert_eq!(tokens(999.0), "999");
        assert_eq!(tokens(1000.0), "1k");
        assert_eq!(tokens(1500.0), "2k"); // half-to-even, same as round_pct
        assert_eq!(tokens(84_000.0), "84k");
    }
}
