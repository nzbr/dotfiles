#!/bin/bash
# Claude Code statusline.
#
# Single line, styled after the user's Starship prompt (see $STARSHIP_CONFIG,
# or the default ~/.config/starship.toml) on the left, usage-limit batteries
# right after the directory, and model + context ring right-aligned on the far
# right:
#   - OS icon                  ([os.symbols], looked up in that config itself
#                              rather than duplicated here -- see os_symbol)
#   - username (green/red)     ([username] style_user = fg:green, style_root = fg:red)
#   - @hostname (green)        ([hostname] format, styled like the "[@$hostname](fg:green)" segment)
#   - repo / worktree / branch in a git repo: the repository's name behind a
#                              repo glyph in salmon, the worktree's name
#                              behind a fork glyph in gold when it is a linked
#                              one, then [git_branch]'s own symbol and the
#                              branch in its "fg:#FCA17D" orange -- one hue
#                              step apart, so the three read separately
#   - directory (uncolored)    ([directory] style = "") -- in a repo, only the
#                              part below the worktree root, and nothing at
#                              all when that is where you stand; otherwise the
#                              whole path with $HOME as "~". The glyphs are
#                              this script's own: starship's [directory]
#                              carries no symbol and never truncates
#   - usage limits, drawn as batteries, right after the directory. Each
#     one shows what is REMAINING (charge and number are 100 - used), but
#     stays colored by what is USED -- see battery_bar for why. Two
#     renderings exist, an eight-cell bar and a single icon, and by default
#     the widest one that fits the terminal is used -- see LIMIT_STYLE
#     below and the layout block at the end.
#       - Session (5h) limit  <- input.rate_limits.five_hour.used_percentage
#       - Weekly (7d) limit   <- input.rate_limits.seven_day.used_percentage
#       - "Fable" limit       <- input.rate_limits.fable.used_percentage IF
#                                that field is ever added by Claude Code.
#   - [right-aligned] model name behind a four-pointed star, both colored by
#     tier: Haiku teal / Sonnet blue / Opus purple / Fable gold
#     <- input.model.display_name, input.model.id
#   - [right-aligned, after model] thinking effort level behind a
#     speedometer, e.g. "xhigh" --
#     <- input.effort.level, only shown when the field is present (i.e. the
#     current model supports/exposes a reasoning effort level). Colored to
#     match Claude Code's own /effort picker (sampled from screenshots):
#     low=amber, medium=green, high=periwinkle, xhigh=violet, max=orange.
#     xhigh and max also get simplified versions of that UI's special
#     flourishes instead of a plain solid color -- xhigh's "shiny" traveling
#     highlight (render_shiny) and max's rainbow hue-cycle (render_rainbow).
#     Neither is a real animation loop (this script is stateless -- Claude
#     Code just re-runs it from scratch on every refresh); both derive their
#     current "frame" straight from the wall clock (date +%s) instead, which
#     works because Claude Code re-invokes the statusline on its
#     refreshInterval (settings.json, currently 1s -- the minimum Claude Code
#     allows; fractional values like 0.5 aren't supported) in addition to its
#     normal event-driven triggers, so the frame still visibly advances tick
#     to tick.
#   - [right-aligned, after model/effort] ring NN% (raw/size)  <- ring glyph
#     (○◔◑◕●) fills with input.context_window.used_percentage (falls back to
#     total_input_tokens / context_window_size), followed by "(used/size)"
#     in raw tokens (e.g. "Sonnet 5 xhigh ● 84% (168k/200k)"), abbreviated
#     with a "k" suffix. The raw pair is dropped in the icon style, where
#     the percentage carries the meaning on its own -- see compose_right.
#
#     No trailing "❯"/">" indicator -- intentionally removed.
#
#     NOTE: as of this writing, Claude Code's statusline JSON only exposes
#     `rate_limits.five_hour` and `rate_limits.seven_day` -- there is no
#     separate "fable" usage bucket. Local feature-flag data on this machine
#     (~/.claude.json -> cachedGrowthBookFeatures) shows "Fable"/"Fable 5" is
#     an internal codename for a specific model, and that model draws down
#     the *same* weekly (seven_day) limit (capped at 50% of it) rather than
#     having its own tracked percentage. So there is no genuine number to
#     show for a distinct "Fable limit" today; the lookup below is kept as a
#     harmless forward-compatible check and will simply stay hidden unless
#     Anthropic adds such a field in the future. Do not mistake its
#     appearance for confirmation that it currently works.

# ---------------------------------------------------------------------------
# Which rendering the usage limits get:
#
#   bar    an eight-cell battery plus the number      "▐█████   🬛 63%"
#   icon   one Material Design battery glyph plus the number   "󰁿 63%"
#
# The bar resolves the charge to sixty-four slices across eight cells; the
# icon says the same thing in nine columns less, at ten-percent steps.
#
#   auto   bars while they fit, icons once they don't  (the default)
#
# "auto" is what makes the line responsive. The layout block at the end of
# this script walks the styles in that order and keeps the first that fits,
# so the batteries are narrowed before the line is split in two, and only
# then are they narrowed again on the split line -- see there. Pinning this
# to "bar" or "icon" just drops the other from that ladder; it does not
# disable the splitting, which is the last resort either way.
# ---------------------------------------------------------------------------
LIMIT_STYLE="auto"

# Force a plain '.' decimal separator for printf/awk regardless of the
# invoking environment's locale (e.g. de_DE uses ',' and would make
# `printf '%.0f' "31.5"` fail with "Ungültige Zahl" / invalid number).
export LC_NUMERIC=C

input=$(cat)

reset=$'\033[0m'
dim=$'\033[2m'
green=$'\033[32m'
red=$'\033[31m'
yellow=$'\033[33m'
orange=$'\033[38;2;252;161;125m' # matches starship.toml's [git_branch] #FCA17D

# The rest of the git group fans around that orange instead of repeating it:
# one hue step either side, at the same lightness and saturation, so the
# repository, the worktree and the branch read as three separate facts and
# still as one family. The branch keeps the orange itself, being the only one
# of the three the Starship config has an opinion about.
repo_color=$'\033[38;2;252;133;125m'     # salmon #FC857D
worktree_color=$'\033[38;2;252;203;125m' # gold   #FCCB7D
track_bg=$'\033[48;2;78;78;78m'  # gray #4E4E4E -- battery_bar's drained cells

# Model-tier colors, distinct at a glance:
haiku_color=$'\033[38;2;126;231;200m'  # teal   #7EE7C8 -- small/fast model
sonnet_color=$'\033[38;2;111;168;255m' # blue   #6FA8FF -- balanced model
opus_color=$'\033[38;2;199;146;234m'   # purple #C792EA -- large/capable model
fable_color=$'\033[38;2;255;216;102m'  # gold   #FFD866 -- top-tier model

# Effort-level colors, sampled directly from Claude Code's own /effort picker
# (the color each level's label is rendered in when selected there), so the
# statusline stays visually consistent with that UI:
effort_low_color=$'\033[38;2;255;193;7m'     # amber  #FFC107
effort_medium_color=$'\033[38;2;78;186;101m' # green  #4EBA65
effort_high_color=$'\033[38;2;177;185;249m'  # periwinkle #B1B9F9

# xhigh/max get animated flourishes (render_shiny/render_rainbow) rather than
# one solid color, so these are plain "R G B" components for those render
# functions to build per-character escape codes from, not full escape codes:
effort_xhigh_rgb="175 135 255" # violet #AF87FF -- xhigh's shine sweeps around this

strip_ansi() {
	printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g'
}

vis_len() {
	local stripped
	stripped=$(strip_ansi "$1")
	printf '%s' "${#stripped}"
}

colorize_pct() {
	# $1 = rounded integer percentage; color matches ring_color's continuous
	# green->yellow->red gradient, so the number and the ring always agree.
	local p="$1" c
	c=$(ring_color "$p")
	printf "%s%s%%%s" "$c" "$p" "$reset"
}

ring_color() {
	# $1 = integer percentage 0-100 -> truecolor ANSI fg escape, smoothly
	# interpolated across 4 stops: blue (0%) -> green (33%) -> yellow (66%)
	# -> red (100%), so the whole 0-100 range is one continuous gradient
	# (cool/empty to hot/full) instead of jumping between discrete bands.
	local p="$1" r g b t d
	[ "$p" -lt 0 ] && p=0
	[ "$p" -gt 100 ] && p=100

	local b_r=70  b_g=140 b_b=235 # blue   #4682EB
	local g_r=90  g_g=200 g_b=110 # green  #5AC86E
	local y_r=235 y_g=200 y_b=70  # yellow #EBC846
	local r_r=235 r_g=80  r_b=70  # red    #EB5046

	if [ "$p" -le 33 ]; then
		t="$p"; d=33
		r=$(( b_r + (g_r - b_r) * t / d ))
		g=$(( b_g + (g_g - b_g) * t / d ))
		b=$(( b_b + (g_b - b_b) * t / d ))
	elif [ "$p" -le 66 ]; then
		t=$(( p - 33 )); d=33
		r=$(( g_r + (y_r - g_r) * t / d ))
		g=$(( g_g + (y_g - g_g) * t / d ))
		b=$(( g_b + (y_b - g_b) * t / d ))
	else
		t=$(( p - 66 )); d=34
		r=$(( y_r + (r_r - y_r) * t / d ))
		g=$(( y_g + (r_g - y_g) * t / d ))
		b=$(( y_b + (r_b - y_b) * t / d ))
	fi
	printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

ring_glyph() {
	# $1 = rounded integer percentage -- a 9-step filling ring (0/8..8/8, ~12.5%
	# per step) whose color scales continuously with fullness via ring_color.
	# Uses Nerd Font Material Design Icons circle-slice glyphs
	# (md-circle_slice_1..8 + circle-outline) -- confirmed present in the
	# installed Symbols Nerd Font Mono by reading its cmap directly, and this
	# machine already relies on Nerd Font glyphs for the OS icon above, so a
	# Nerd Font is assumed to be active in the rendering terminal.
	local p="$1" c glyph bucket
	c=$(ring_color "$p")
	bucket=$(( (p * 8 + 50) / 100 ))
	[ "$bucket" -gt 8 ] && bucket=8
	[ "$bucket" -lt 0 ] && bucket=0
	case "$bucket" in
		0) glyph=$'\U000f043d' ;; # nf-md-circle_outline       (0/8, empty)
		1) glyph=$'\U000f0a9e' ;; # nf-md-circle_slice_1       (1/8)
		2) glyph=$'\U000f0a9f' ;; # nf-md-circle_slice_2       (2/8)
		3) glyph=$'\U000f0aa0' ;; # nf-md-circle_slice_3       (3/8)
		4) glyph=$'\U000f0aa1' ;; # nf-md-circle_slice_4       (4/8, half)
		5) glyph=$'\U000f0aa2' ;; # nf-md-circle_slice_5       (5/8)
		6) glyph=$'\U000f0aa3' ;; # nf-md-circle_slice_6       (6/8)
		7) glyph=$'\U000f0aa4' ;; # nf-md-circle_slice_7       (7/8)
		8) glyph=$'\U000f0aa5' ;; # nf-md-circle_slice_8       (8/8, full)
	esac
	printf "%s%s%s" "$c" "$glyph" "$reset"
}

format_tokens() {
	# $1 = raw token count -> "84k" style, or the raw number under 1000
	local n="$1"
	if [ "$n" -ge 1000 ]; then
		awk -v n="$n" 'BEGIN { printf "%dk", int(n / 1000 + 0.5) }'
	else
		printf "%d" "$n"
	fi
}

battery_bar() {
	# $1 = rounded integer USED percentage, $2 = number of cells inside the
	# casing (default 8). Used when LIMIT_STYLE is "bar".
	#
	# Drawn as a battery: a casing wall on each side of the cells, e.g.
	# "▐█████   🬛 63%". Each wall puts its ink on the half of its cell
	# that faces the charge -- ▐ (right half block) fills its right half,
	# 🬛 fills its left half -- so the casing butts straight against the
	# charge with no gap. Box-drawing walls (┃, or ┣/╋) can't do that:
	# they draw down the centre of their cell, so they either leave a
	# half-cell of dead space or have to bridge it with an inward stub.
	#
	# 🬛 also fills the middle-right sixth of its cell, and that sixth is
	# the positive terminal: it protrudes away from the battery only,
	# never inward, and costs no column of its own. It is U+1FB1B BLOCK
	# SEXTANT-1345, from Symbols for Legacy Computing -- much thinner on
	# the ground than box drawing, but the font here is CopperflameMono,
	# an Iosevka build patched with Nerd Fonts, and Iosevka draws that
	# whole sextant range (font/default.nix in nzbr/copperflame, and
	# symbol/mosaic/teletext.ptl in be5invis/Iosevka).
	#
	# The charge is flipped to the user's perspective: the cells and the
	# number show what is REMAINING (100 - used), while the color still
	# tracks USED via ring_color's gradient -- so a nearly-drained limit
	# shows a short red "8%" battery rather than a reassuring-green one, and
	# the palette stays consistent with the context ring, which keeps both
	# showing and coloring used. Reading the two together still lands on
	# the battery convention at the end that matters: nearly empty is
	# red.
	#
	# The casing itself stays dim instead of taking the gradient color, so
	# it reads as an inert shell and only the charge inside carries the
	# color signal.
	#
	# Drained cells are blank cells on a gray background (track_bg) rather
	# than dim ░ glyphs: the charge then ends on a hard edge instead of
	# fading into a second texture, and an exhausted limit reads as an
	# empty track instead of a full bar of stipple.
	#
	# The charge retreats in eighths of a cell, not whole cells: the
	# rightmost cell is drawn as one of ▏▎▍▌▋▊▉ (U+258F..2589, left one
	# eighth through left seven eighths) in the charge color over the gray
	# track, e.g. "▐████▉   🬛 62%". Eight cells therefore carry sixty-four
	# slices. Those are plain Block Elements, so unlike the 🬛 terminal they
	# carry no font risk at all.
	#
	# 1.5625% per slice does not divide 100. Whole slices of a round number
	# of percent are only possible at five or ten cells (twenty slices of
	# 5%), and eight is the width that looks right. Eight buys a different
	# exactness instead: the quarter marks fall on cell boundaries -- two
	# cells is precisely 25%, four precisely 50% -- which ten cells cannot
	# do, so halving the bar by eye is accurate.
	#
	# Rounding is floor with a clamp at each end. Floor means the slices
	# never overstate what is left; the clamps mean any charge at all shows
	# at least the narrowest slice, so a nearly-dead limit is never a bare
	# track, and eight full cells is reserved for exactly 100%, so a bar
	# that looks full is full.
	local used="$1" width="${2:-8}" p c slices filled part empty i cells
	local eighths=("" ▏ ▎ ▍ ▌ ▋ ▊ ▉)
	[ "$used" -lt 0 ] && used=0
	[ "$used" -gt 100 ] && used=100
	c=$(ring_color "$used")
	p=$(( 100 - used ))
	slices=$(( p * width * 8 / 100 ))
	[ "$p" -gt 0 ] && [ "$slices" -lt 1 ] && slices=1
	[ "$p" -lt 100 ] && [ "$slices" -ge $(( width * 8 )) ] && slices=$(( width * 8 - 1 ))
	filled=$(( slices / 8 ))
	part="${eighths[$(( slices % 8 ))]}"
	empty=$(( width - filled ))
	[ -n "$part" ] && empty=$(( empty - 1 ))
	cells=""
	for ((i = 0; i < filled; i++)); do cells+="█"; done
	local cells_empty=""
	for ((i = 0; i < empty; i++)); do cells_empty+=" "; done
	local wall_l="${dim}▐${reset}" wall_r="${dim}🬛${reset}"
	printf "%s%s%s%s%s%s%s%s %s%s%%%s" \
		"$wall_l" \
		"$c" "$cells" \
		"$track_bg" "$part" "$cells_empty" "$reset" \
		"$wall_r" \
		"$c" "$p" "$reset"
}

battery_icon() {
	# $1 = rounded integer USED percentage. Used when LIMIT_STYLE is "icon".
	#
	# One Material Design battery glyph plus the remaining percentage, e.g.
	# "󰁿 63%" -- the compact alternative to battery_bar, which see for why
	# the number is what is REMAINING while the color still tracks what is
	# USED. Thirteen states, more than any other Nerd Font battery set:
	# full, 90 down to 10 in tens, then three separate stages for the last
	# tenth, where knowing how close the limit is matters most -- an empty
	# outline at 5-9%, the exclamation-mark battery at 1-4%, and the
	# struck-through one at 0. (Font Awesome's batteries lie down, which
	# would match the bar's orientation better than these upright ones, but
	# it has five states in total and no alert glyph at all.)
	#
	# Levels floor to their ten rather than rounding to the nearest, so a
	# glyph always means "at least this much left" and only a genuinely
	# untouched limit shows as full.
	local used="$1" p c glyph
	[ "$used" -lt 0 ] && used=0
	[ "$used" -gt 100 ] && used=100
	c=$(ring_color "$used")
	p=$(( 100 - used ))
	if [ "$p" -eq 0 ]; then
		glyph=$'\U000f125e' # nf-md-battery_off_outline            (0%, struck out)
	elif [ "$p" -lt 5 ]; then
		# The _variant_outline alert rather than plain nf-md-battery_alert:
		# that one draws a *filled* battery around its "!", which reads as a
		# charged battery at exactly the moment the limit is nearly gone.
		glyph=$'\U000f10cd' # nf-md-battery_alert_variant_outline  (1-4%)
	elif [ "$p" -lt 10 ]; then
		glyph=$'\U000f008e' # nf-md-battery_outline                (5-9%)
	else
		case $(( p / 10 )) in
			1) glyph=$'\U000f007a' ;; # nf-md-battery_10
			2) glyph=$'\U000f007b' ;; # nf-md-battery_20
			3) glyph=$'\U000f007c' ;; # nf-md-battery_30
			4) glyph=$'\U000f007d' ;; # nf-md-battery_40
			5) glyph=$'\U000f007e' ;; # nf-md-battery_50
			6) glyph=$'\U000f007f' ;; # nf-md-battery_60
			7) glyph=$'\U000f0080' ;; # nf-md-battery_70
			8) glyph=$'\U000f0081' ;; # nf-md-battery_80
			9) glyph=$'\U000f0082' ;; # nf-md-battery_90
			*) glyph=$'\U000f0079' ;; # nf-md-battery         (full, 100%)
		esac
	fi
	printf "%s%s %s%%%s" "$c" "$glyph" "$p" "$reset"
}

limit_gauge() {
	# $1 = style, $2 = rounded integer USED percentage. Draws one limit in
	# the style asked for -- anything that is not "bar" is an icon. Every
	# gauge goes through here, which is what keeps the two renderings
	# interchangeable enough for the layout block to price up both.
	case "$1" in
		bar) battery_bar "$2" ;;
		*) battery_icon "$2" ;;
	esac
}

# The next two build the left-hand side of the line in a given style. They
# read the per-limit values (session_pct, s_r, session_reset_part, ...) and
# core_left out of the linear part of the script further down, so they are
# only callable from the layout block at the very end -- but they live up
# here with the other functions. They exist as functions rather than as a
# string built once because "auto" has to measure both styles before it can
# choose one.

build_limits() {
	# $1 = style -> the whole run of usage limits in that style, joined with
	# the same dim separator the rest of the line uses. Empty when this
	# Claude Code build reported no limits at all.
	local style="$1" segs=() part="" first=true seg
	# Session and Week name time windows, and Material Design has a glyph
	# for each: a clock inside a refresh arrow for the rolling five hours,
	# and a clock on a calendar for the seven days. Both carry a clock face,
	# so the pair reads as one idea at two scales -- the near window and the
	# far one -- where an hourglass next to a refresh arrow would be two
	# unrelated metaphors sharing a line. They are glyphs in both styles
	# rather than only the cramped one: nine columns is worth having even on
	# a line that could afford the words. "Fable" is a model name rather
	# than a window, so nothing pictorial says it; that one keeps a letter.
	#
	# Labels and countdowns carry no color of their own, like the path.
	# Claude Code renders the whole line a shade down already, and a dim of
	# our own on top of that flattened them into the background rather than
	# merely quieting them.
	local s_label=$'\U000f06b0' # nf-md-update
	local w_label=$'\U000f16e1' # nf-md-calendar_clock_outline
	local f_label="F"
	local w_reset="$weekly_reset_part"
	if [ "$style" != bar ]; then
		# The weekly countdown drops to one coarse figure: "3d", or "18h"
		# once the reset is inside a day, where the bar style has
		# "3:12:32". Four or five columns back, and nothing lost that this
		# style was using -- minutes matter for the session window, which
		# empties while you are sitting there, but a weekly reset days out
		# only ever gets read as how far off it is.
		w_reset="$weekly_reset_short"
	fi
	if [ -n "$session_pct" ]; then
		segs+=("${s_label} ${session_reset_part}$(limit_gauge "$style" "$s_r")")
	fi
	if [ -n "$weekly_pct" ]; then
		segs+=("${w_label} ${w_reset}$(limit_gauge "$style" "$w_r")")
	fi
	if [ -n "$fable_pct" ]; then
		segs+=("${f_label} $(limit_gauge "$style" "$f_r")")
	fi
	for seg in "${segs[@]}"; do
		if $first; then
			part="$seg"
			first=false
		else
			part="${part} ${dim}│${reset} ${seg}"
		fi
	done
	printf '%s' "$part"
}

compose_left() {
	# $1 = style -> the core prompt plus the usage limits in that style,
	# i.e. everything that sits left of the right-aligned block.
	local limits
	limits=$(build_limits "$1")
	if [ -n "$limits" ]; then
		printf '%s %s│%s %s' "$core_left" "$dim" "$reset" "$limits"
	else
		printf '%s' "$core_left"
	fi
}

compose_right() {
	# $1 = style -> the right-aligned block (model, effort, context ring).
	# Only its tail varies: the bar style closes with the ring's absolute
	# "(50k/200k)", the compact style stops at the percentage. The ratio is
	# the first thing worth dropping once room is short -- the percentage
	# already says how full the window is, and the denominator never changes
	# within a session, so eleven columns are spent restating it every
	# refresh. Everything before the tail is assembled once further down;
	# only the choice between the two tails happens per style.
	if [ "$1" = bar ]; then
		printf '%s%s' "$line1_right" "$ctx_tokens_part"
	else
		printf '%s' "$line1_right"
	fi
}

render_shiny() {
	# $1 = word, $2/$3/$4 = base r/g/b (0-255), $5 = wall-clock seconds.
	# "Shiny" sweep for xhigh: a bright highlight travels left-to-right across
	# the word's letters, then pauses, then loops. There's no persistent
	# animation state between invocations, so the current frame is derived
	# straight from the wall clock -- good enough since Claude Code re-runs
	# this script every refreshInterval tick (currently 1s, see settings.json;
	# 1 is the minimum Claude Code allows), plenty of ticks to see it move.
	local word="$1" br="$2" bg="$3" bb="$4" now="$5"
	local len=${#word} pause=3 total tick pos i char dist blend r g b out=""
	total=$(( len + pause ))
	tick="$now"
	pos=$(( tick % total ))
	[ "$pos" -ge "$len" ] && pos=-100 # currently in the "paused" part of the loop
	for (( i = 0; i < len; i++ )); do
		char="${word:i:1}"
		dist=$(( i - pos ))
		[ "$dist" -lt 0 ] && dist=$(( -dist ))
		if [ "$dist" -eq 0 ]; then
			blend=100
		elif [ "$dist" -eq 1 ]; then
			blend=45
		else
			blend=0
		fi
		r=$(( br + (255 - br) * blend / 100 ))
		g=$(( bg + (255 - bg) * blend / 100 ))
		b=$(( bb + (255 - bb) * blend / 100 ))
		out="${out}$(printf '\033[38;2;%d;%d;%dm%s' "$r" "$g" "$b" "$char")"
	done
	printf '%s%s' "$out" "$reset"
}

hsv_to_rgb() {
	# $1 = hue in degrees (any integer, wrapped mod 360), $2 = saturation
	# 0-100 (value is always 100/full-bright) -> prints "R G B" (0-255 each).
	# Used by render_rainbow, which deliberately calls this below 100
	# saturation: at full saturation, one channel always bottoms out at 0
	# (pure blue/red/green), which reads as noticeably darker than the
	# others -- lowering saturation raises that floor so every hue in the
	# rotation looks comparably bright.
	awk -v h="$1" -v s="$2" 'BEGIN {
		h = h % 360; if (h < 0) h += 360
		s = s / 100
		hp = h / 60
		hi = int(hp) % 6
		f = hp - int(hp)
		p = 1 - s
		q = 1 - f * s
		t = 1 - (1 - f) * s
		if (hi == 0) { r=1; g=t; b=p }
		else if (hi == 1) { r=q; g=1; b=p }
		else if (hi == 2) { r=p; g=1; b=t }
		else if (hi == 3) { r=p; g=q; b=1 }
		else if (hi == 4) { r=t; g=p; b=1 }
		else { r=1; g=p; b=q }
		printf "%d %d %d", r*255, g*255, b*255
	}'
}

render_rainbow() {
	# $1 = word, $2 = wall-clock seconds.
	# Rainbow cycle for max: each letter sits at a different point around the
	# hue wheel, and the whole wheel spins fast with the wall clock -- same
	# stateless "derive the frame from time" trick as render_shiny. Hue steps
	# by a non-round 97 degrees/tick (coprime with 360) rather than a clean
	# divisor, so the sequence doesn't fall into a short, visibly-repeating
	# loop at only 1 frame/sec.
	local word="$1" now="$2"
	local len=${#word} tick hue_offset i char hue rgb r g b rest out=""
	local sat=65 # <100 -- see hsv_to_rgb -- so every hue stays bright, not just yellow/cyan
	tick="$now"
	hue_offset=$(( (tick * 97) % 360 ))
	for (( i = 0; i < len; i++ )); do
		char="${word:i:1}"
		hue=$(( (hue_offset + i * 60) % 360 ))
		rgb=$(hsv_to_rgb "$hue" "$sat")
		r=${rgb%% *}
		rest=${rgb#* }
		g=${rest%% *}
		b=${rest#* }
		out="${out}$(printf '\033[38;2;%d;%d;%dm%s' "$r" "$g" "$b" "$char")"
	done
	printf '%s%s' "$out" "$reset"
}

# ---------------------------------------------------------------------------
# Dependency check -- external commands this script calls (not shell
# builtins). If any are missing, a warning line is printed ABOVE the normal
# statusline (see the very end of the script) instead of letting the
# affected segments silently blank out with no indication why -- this is
# exactly what happened when `jq` turned out to be missing on PATH: every
# JSON-derived field (rate-limit batteries, model name, context ring) vanished
# at once with nothing to explain it. Add to REQUIRED_COMMANDS if a future
# change introduces a new external tool dependency.
#
# `stty`/`tput` (terminal-width detection) are deliberately NOT in this
# list: their absence -- or simply running without a controlling tty -- is
# already an expected, explicitly-handled fallback path (default 80 columns)
# further below, not a genuine "missing dependency".
# ---------------------------------------------------------------------------
REQUIRED_COMMANDS=(jq git awk sed tr date hostname whoami id cat)
missing_commands=()
for _cmd in "${REQUIRED_COMMANDS[@]}"; do
	command -v "$_cmd" >/dev/null 2>&1 || missing_commands+=("$_cmd")
done

HAS_JQ=1
command -v jq >/dev/null 2>&1 || HAS_JQ=0

jqr() {
	# `jq -r` wrapper: a silent no-op (prints nothing) when jq isn't
	# installed, instead of every call site below trying (and failing) to
	# exec a binary that doesn't exist. Every field read through this already
	# has a `// empty`-style fallback baked into its jq filter, so an empty
	# result here degrades exactly the way a genuinely-absent JSON field
	# would -- the rest of the line still renders with whatever it has.
	[ "$HAS_JQ" -eq 1 ] && jq -r "$@"
	return 0
}

# ---------------------------------------------------------------------------
# Line 1 -- Starship-inspired prompt + model, context on the right
# ---------------------------------------------------------------------------

cwd=$(echo "$input" | jqr '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"
# The whole path with $HOME collapsed to "~", behind a plain folder glyph --
# nf-oct-file_directory, from the same Octicons family as the branch symbol so
# the two match in weight, and uncolored like the path it introduces, since
# starship's [directory] has no symbol of its own to copy. Inside a repo the
# git block below cuts the path down to what sits under the worktree root; the
# glyph is the same either way, still introducing a path and nothing else.
#
# The backslash is load-bearing: an unescaped ~ in the replacement half of a
# substitution is tilde-expanded straight back into $HOME, which quietly turns
# the whole thing into a no-op.
display_dir="${cwd/#$HOME/\~}"
dir_icon=$'\uf413' # nf-oct-file_directory

# OS icon -- read out of the Starship config's [os.symbols] table rather than
# from a second copy of the mapping kept here, so this line and the Starship
# prompt can never disagree about a distro's symbol, and adding one there is
# enough. That makes the Starship config a real dependency of this script:
# autolink_all links the starship package whenever the claude package is
# linked, even on a machine without starship itself (see control.sh).
#
# That table is keyed by Starship's own OS names (from the os_info crate --
# "NixOS", "openSUSE", "Bluefin"), which are not /etc/os-release ID values, so
# the lookup tries, case-insensitively: ID, then each word of ID_LIKE, then
# "Linux", then "Unknown". No ID-to-Starship-name table is needed to bridge
# the two spellings -- case-insensitive matching covers the ones that differ
# only in case (nixos -> NixOS, centos -> CentOS), and ID_LIKE covers the
# rest, which are all derivatives anyway (rhel -> fedora -> Fedora,
# opensuse-tumbleweed -> opensuse -> openSUSE, bluefin -> fedora if the
# installed Starship is too old to have a Bluefin symbol).
#
# A missing or symbol-less config is not an error: os_icon just comes out
# empty and the glyph, with its separating space, is left off the line.
starship_config="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"

os_symbol() {
	# $@ = candidate [os.symbols] keys, in priority order -> prints the first
	# one present in the config, trimmed of the trailing space Starship's
	# values carry (its own [os] format is a bare "$symbol", so the spacing
	# lives in the value; here the space is added by core_left instead).
	[ -r "$starship_config" ] || return 0
	awk -v candidates="$*" '
		BEGIN {
			n = split(tolower(candidates), want, " ")
			sq = sprintf("%c", 39) # single quote, for TOML literal strings
		}
		# Track section headers; only harvest keys inside [os.symbols], and
		# stop as soon as any other table starts.
		/^[[:space:]]*\[/ {
			in_os = ($0 ~ /^[[:space:]]*\[os\.symbols\][[:space:]]*(#.*)?$/)
			next
		}
		!in_os { next }
		# Name = "glyph" (or a literal-string '\''glyph'\''); trailing comments,
		# which cannot contain a quote of the same kind, are ignored.
		match($0, /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/) {
			key = substr($0, 1, RLENGTH - 1)
			gsub(/[[:space:]]/, "", key)
			rest = substr($0, RLENGTH + 1)
			if (match(rest, /"[^"]*"/) || match(rest, sq "[^" sq "]*" sq))
				sym[tolower(key)] = substr(rest, RSTART + 1, RLENGTH - 2)
		}
		END {
			for (i = 1; i <= n; i++)
				if (want[i] in sym) { print sym[want[i]]; exit }
		}
	' "$starship_config" 2>/dev/null | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

os_candidates=""
[ -r /etc/os-release ] && os_candidates=$(. /etc/os-release 2>/dev/null; echo "$ID $ID_LIKE")
# Deliberately unquoted: ID_LIKE is a space-separated list and each word is
# its own candidate.
# shellcheck disable=SC2086
os_icon=$(os_symbol $os_candidates Linux Unknown)

if [ "$(id -u)" -eq 0 ]; then
	user_color="$red"
else
	user_color="$green"
fi
user_part="${user_color}$(whoami)${reset}"
host_part="${green}@$(hostname -s)${reset}"

# One rev-parse answers three things at once: whether this is a work tree at
# all, where its root is, and how far below the root the cwd sits. Asking git
# for that last part rather than subtracting the root from $cwd keeps it right
# when the two disagree about symlinks, which they do on any distro where
# /home is a link to /var/home.
git_part=""
git_info=$(git --no-optional-locks -C "$cwd" rev-parse --show-toplevel --show-prefix 2>/dev/null)
if [ -n "$git_info" ]; then
	{ read -r git_root; read -r git_prefix; } <<<"$git_info"

	# Inside a repo the line names the repository, then the worktree when it
	# is a linked one, then the branch -- and leaves the path to say only what
	# is below the worktree root. Everything above that root is the same for
	# every prompt of a session's work, and the root itself is already named
	# by the repo, so standing at the top of a checkout there is no path left
	# worth printing. This is the one place the line departs from the Starship
	# config, whose [directory] has truncation_length = 0 and never truncates.
	repo_icon=$'\uf401' # nf-oct-repo
	repo_name="${git_root##*/}"

	# git-dir and git-common-dir are one path in the main worktree and two in
	# a linked one, which is both the worktree test and the route to the main
	# checkout, whose directory name is the repository's. But only once both
	# are absolute: asked relatively, a subdirectory of the main worktree
	# answers ".../repo/.git" and "../../.git", the same directory spelled two
	# ways, and every subdirectory would read as a linked tree.
	# --path-format wants git 2.31. Older git fails this call, leaving the
	# repo named after whichever checkout is in hand -- right in the main
	# worktree, the worktree's own name in a linked one -- and no worktree tag.
	wt_part=""
	wt_dirs=$(git --no-optional-locks -C "$cwd" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null)
	if [ -n "$wt_dirs" ]; then
		{ read -r wt_git_dir; read -r wt_common_dir; } <<<"$wt_dirs"
		# A normal repo keeps its common dir at <root>/.git; a bare one is the
		# common dir, named <repo>.git. Exactly one strip can apply, so test
		# rather than chain them: a checkout living in a directory that is
		# itself called "x.git" would otherwise come out as "x".
		if [ "${wt_common_dir%/.git}" != "$wt_common_dir" ]; then
			wt_main="${wt_common_dir%/.git}"
		else
			wt_main="${wt_common_dir%.git}"
		fi
		repo_name="${wt_main##*/}"
		if [ "$wt_git_dir" != "$wt_common_dir" ]; then
			# Which checkout this is: normally the worktree directory's own
			# name, but trees are often parked as <name>/<repo> beside the main
			# one, which leaves every one of them with the repo's name as its
			# leaf. There the directory above is what tells them apart. Behind
			# nf-md-call_split, one line diverging into two, which is what a
			# worktree is: a single history checked out along a second path.
			# That does leave the Octicons the other git glyphs come from, but
			# no Octicon says "the same repo, elsewhere" -- file_submodule, the
			# nearest, actually means a nested different repo.
			wt_name="${git_root##*/}"
			if [ "$wt_name" = "$repo_name" ]; then
				wt_parent="${git_root%/*}"
				wt_name="${wt_parent##*/}"
			fi
			wt_icon=$'\U000f00fb'
			wt_part=" ${worktree_color}${wt_icon} ${wt_name}${reset}"
		fi
	fi

	branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
	[ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
	# nf-oct-git_branch, the same symbol starship.toml's [git_branch] sets,
	# and orange like it too: that block's format is '[ $symbol $branch ]'
	# under one style, so the symbol takes the branch's color there as well.
	# The repository and worktree names sit a hue step either side of that
	# orange rather than sharing it -- see the palette. Each glyph takes its
	# own name's color; only the path stays uncolored.
	branch_icon=$'\uf418'
	git_part=" ${repo_color}${repo_icon} ${repo_name}${reset}${wt_part}"
	[ -n "$branch" ] && git_part="${git_part} ${orange}${branch_icon} ${branch}${reset}"

	# Only what lies below the worktree root, and nothing at all at the root.
	display_dir="${git_prefix%/}"
fi

# Claude Code usage limits, as batteries, shown right after the directory.
session_pct=$(echo "$input" | jqr '.rate_limits.five_hour.used_percentage // empty')
session_resets_at=$(echo "$input" | jqr '.rate_limits.five_hour.resets_at // empty')
weekly_pct=$(echo "$input" | jqr '.rate_limits.seven_day.used_percentage // empty')
weekly_resets_at=$(echo "$input" | jqr '.rate_limits.seven_day.resets_at // empty')
# Speculative/forward-compatible only -- see header note above. Empty today.
fable_pct=$(echo "$input" | jqr '.rate_limits.fable.used_percentage // empty')

if [ -n "$session_pct" ]; then
	s_r=$(printf '%.0f' "$session_pct")

	# "HH:MM" countdown to the 5-hour session reset, right after the session
	# label -- uncolored, like the label and the path, but
	# without the brackets: the label is a glyph now, and "(...)" only reads
	# as a parenthetical beside a word. The weekly block below builds the
	# same countdown for its own window, which is cut to whole days in the
	# icon style -- see build_limits.
	# resets_at is gated the same `// empty` way as session_pct itself (only
	# present for subscribers after the first API response), and a
	# non-positive/garbage remainder is treated the same as "absent" -- no
	# broken/negative countdown, just fall back to the plain "Session <bar>"
	# rendering.
	#
	# Fixed-width zero-padded HH:MM (always exactly 5 characters) rather than
	# variable-width "2h 15m"/"29m"/"<1m" text -- a variable-length countdown
	# shifts everything after it left/right on every refresh as the digit
	# count changes, which defeats the point of a stable layout. Precision at
	# the very tail end is deliberately sacrificed for that stability: under
	# a minute remaining just floors to "00:00" rather than getting its own
	# special case.
	session_reset_part=""
	if [ -n "$session_resets_at" ]; then
		now_epoch=$(date +%s)
		session_remaining_secs=$(( session_resets_at - now_epoch ))
		if [ "$session_remaining_secs" -gt 0 ] 2>/dev/null; then
			r_h=$(( session_remaining_secs / 3600 ))
			r_m=$(( (session_remaining_secs % 3600) / 60 ))
			session_remaining_text=$(printf '%02d:%02d' "$r_h" "$r_m")
			session_reset_part="${session_remaining_text} "
		fi
	fi

fi

if [ -n "$weekly_pct" ]; then
	w_r=$(printf '%.0f' "$weekly_pct")

	# "D:HH:MM" countdown to the 7-day weekly reset, mirroring the session
	# block's countdown above -- same gating (resets_at present + remaining
	# time > 0, else fall back to the bare label plus gauge) and the same
	# uncolored, unbracketed style. Unlike the session, a 7-day window can have
	# multi-day remaining time, so this adds a leading day digit (0-6,
	# realistically never needing zero-padding) ahead of the zero-padded
	# HH:MM, e.g. "3:04:12" for 3 days/4h/12m remaining -- still a fixed
	# width for any value this window can realistically produce, so the
	# layout stays stable as it counts down.
	#
	# A coarse form is built alongside it for the icon style, where the line
	# has no room for seven columns of clock -- see build_limits. Whole days
	# while more than one is left, then hours through the final day, so it
	# never reads "0d" with a reset still the better part of a day away.
	# Both tiers floor, like the session countdown: the last hour reads
	# "0h", where rounding up would turn 23h59m into "24h" -- a worse lie
	# than "0h", and one that contradicts the days tier sitting above it.
	weekly_reset_part=""
	weekly_reset_short=""
	if [ -n "$weekly_resets_at" ]; then
		now_epoch=$(date +%s)
		weekly_remaining_secs=$(( weekly_resets_at - now_epoch ))
		if [ "$weekly_remaining_secs" -gt 0 ] 2>/dev/null; then
			wr_d=$(( weekly_remaining_secs / 86400 ))
			wr_h=$(( (weekly_remaining_secs % 86400) / 3600 ))
			wr_m=$(( (weekly_remaining_secs % 3600) / 60 ))
			weekly_remaining_text=$(printf '%d:%02d:%02d' "$wr_d" "$wr_h" "$wr_m")
			weekly_reset_part="${weekly_remaining_text} "
			if [ "$wr_d" -gt 0 ]; then
				weekly_reset_short="${wr_d}d "
			else
				weekly_reset_short="${wr_h}h "
			fi
		fi
	fi

fi

if [ -n "$fable_pct" ]; then
	f_r=$(printf '%.0f' "$fable_pct")
fi

model_name=$(echo "$input" | jqr '.model.display_name // empty')
model_key=$(echo "$input" | jqr '((.model.id // "") + " " + (.model.display_name // ""))' | tr '[:upper:]' '[:lower:]')
effort_level=$(echo "$input" | jqr '.effort.level // empty')

case "$model_key" in
	*haiku*) model_color="$haiku_color" ;;
	*sonnet*) model_color="$sonnet_color" ;;
	*opus*) model_color="$opus_color" ;;
	*fable*) model_color="$fable_color" ;;
	*) model_color="$dim" ;;
esac

# The spacing is attached to the glyph rather than the join, so that an
# absent one (no Starship config, or no symbol for this OS) leaves no stray
# indent at the line start. Two spaces, not the one the other joins use: a
# distro logo is inked to the edges of its cell where a letter carries its
# own side bearing, so a single space leaves the username looking welded to
# the glyph.
os_part=""
[ -n "$os_icon" ] && os_part="${os_icon}  "
# The path drops out entirely at the top of a checkout, where the repo name
# has already said everything the path could.
dir_part=""
[ -n "$display_dir" ] && dir_part=" ${dir_icon} ${display_dir}"
core_left="${os_part}${user_part}${host_part}${git_part}${dir_part}"

ctx_tokens=$(echo "$input" | jqr '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jqr '.context_window.context_window_size // empty')

ctx_used=$(echo "$input" | jqr '.context_window.used_percentage // empty')
if [ -z "$ctx_used" ] && [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
	ctx_used=$(awk -v t="$ctx_tokens" -v s="$ctx_size" 'BEGIN { printf "%.2f", (t / s) * 100 }')
fi

# Right side: model name (colored by tier), then the thinking effort level
# (dim, when present), then the context ring -- built up piece by piece so
# any of these can be absent without leaving a stray space.
line1_right=""
# nf-md-star_four_points, inside the tier color so it reads as one segment
# with the name, the way the branch symbol sits inside the branch's orange.
model_icon=$'\U000f0ae2'
[ -n "$model_name" ] && line1_right="${model_color}${model_icon} ${model_name}${reset}"

if [ -n "$effort_level" ]; then
	# nf-md-speedometer. The line is full of fill indicators already -- the
	# batteries, the ring -- but this is the one place a dial is the literal
	# subject rather than another metaphor for one: effort is a setting you
	# pick in /effort, not a quantity being consumed.
	#
	# The glyph joins the word before any styling is applied, so it travels
	# through render_shiny and render_rainbow with it and the sweep crosses
	# the icon too. Keeping it outside would mean choosing a solid color to
	# sit beside a word that deliberately has no single color.
	effort_text=$'\U000f04c5'" ${effort_level}"
	case "$effort_level" in
		low) effort_rendered="${effort_low_color}${effort_text}${reset}" ;;
		medium) effort_rendered="${effort_medium_color}${effort_text}${reset}" ;;
		high) effort_rendered="${effort_high_color}${effort_text}${reset}" ;;
		xhigh) effort_rendered=$(render_shiny "$effort_text" $effort_xhigh_rgb "$(date +%s)") ;;
		max) effort_rendered=$(render_rainbow "$effort_text" "$(date +%s)") ;;
		*) effort_rendered="${dim}${effort_text}${reset}" ;;
	esac
	if [ -n "$line1_right" ]; then
		line1_right="${line1_right} ${effort_rendered}"
	else
		line1_right="$effort_rendered"
	fi
fi

if [ -n "$ctx_used" ]; then
	ctx_r=$(printf '%.0f' "$ctx_used")
	ring_part="$(ring_glyph "$ctx_r") $(colorize_pct "$ctx_r")"
	# The absolute "(50k/200k)" is held back rather than appended here: only
	# the bar style shows it, and compose_right decides. It can simply be
	# concatenated on the end because the ring is the last thing to join
	# line1_right, so its tail is the whole block's tail.
	ctx_tokens_part=""
	if [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
		ctx_tokens_part=" ${dim}($(format_tokens "$ctx_tokens")/$(format_tokens "$ctx_size"))${reset}"
	fi
	if [ -n "$line1_right" ]; then
		line1_right="${line1_right} ${ring_part}"
	else
		line1_right="$ring_part"
	fi
fi

line1=""
line2=""

term_width="${COLUMNS:-}"
[ -z "$term_width" ] && term_width=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
[ -z "$term_width" ] && term_width=$(tput cols 2>/dev/null)
[ -z "$term_width" ] && term_width=80

# Safety margin: Claude Code's own UI chrome (borders/indicators) can eat
# a few columns beyond the raw terminal width we're able to detect from
# this subprocess, so don't push all the way to the reported edge.
term_width=$(( term_width - 4 ))
[ "$term_width" -lt 20 ] && term_width=20

# The styles to try, widest first. "auto" gets both, so a narrowing terminal
# swaps the bars for icons; pinning LIMIT_STYLE leaves a one-entry ladder,
# which every loop below still walks correctly, it just never has a second
# option to fall back to.
case "$LIMIT_STYLE" in
	bar) style_ladder=(bar) ;;
	icon) style_ladder=(icon) ;;
	*) style_ladder=(bar icon) ;;
esac
narrowest_style="${style_ladder[-1]}"

fit_lr() {
	# $1 = left, $2 = right -> the two spaced out to exactly term_width,
	# with the right block flush against the edge. Prints nothing and
	# fails if they cannot both fit, which is how the callers below test a
	# candidate layout: assign the output, and let the exit status say
	# whether the candidate was usable.
	#
	# The two get the same dim bar that divides everything else on the line.
	# Right-alignment usually leaves a wide gap between them, but at the
	# widths where the padding shrinks to a single column the last limit's
	# percentage would otherwise sit flush against the model name. The bar
	# closes the left block rather than opening the right one, so it travels
	# with the percentage it is separating and lands where the other dividers
	# on that side already sit, instead of floating off at the far margin. It
	# is priced into the fit, so it cannot be what pushes the line over.
	local l="$1" r="$2" pad sep=""
	[ -n "$l" ] && [ -n "$r" ] && sep=" ${dim}│${reset}"
	pad=$(( term_width - $(vis_len "$l") - $(vis_len "$sep") - $(vis_len "$r") ))
	[ "$pad" -lt 1 ] && return 1
	printf '%s%s%*s%s' "$l" "$sep" "$pad" '' "$r"
}

if [ -z "$line1_right" ]; then
	# Nothing to right-align, so there is nothing to displace onto a second
	# line either -- the only lever left is how wide the batteries are.
	for style in "${style_ladder[@]}"; do
		candidate=$(compose_left "$style")
		if [ "$(vis_len "$candidate")" -le "$term_width" ]; then
			line1="$candidate"
			break
		fi
	done
	[ -z "$line1" ] && line1=$(compose_left "$narrowest_style")
else
	# Degrade in a fixed order, each step giving up less than the next:
	#
	#   1. one line, full-size bars
	#   2. one line, icons                 <- narrow the batteries first...
	#   3. two lines, full-size bars       <- ...and only then split
	#   4. two lines, icons
	#   5. two lines, icons, overflowing
	#
	# Splitting is treated as the more expensive concession because it
	# costs a whole row of the user's terminal, while swapping a bar for an
	# icon costs only detail: sixty-four slices become thirteen glyph
	# states, the weekly countdown drops to whole days, and the ring sheds
	# its raw token pair. Every label, percentage and color -- the things
	# worth reading -- survives the swap. Step 3 then re-tries the bars on the
	# split line, because a line carrying only the limits and the
	# right-hand block has far more room than one that also carries the
	# directory, and there is no reason to keep paying for the icons once
	# that room exists.
	for style in "${style_ladder[@]}"; do
		if candidate=$(fit_lr "$(compose_left "$style")" "$(compose_right "$style")"); then
			line1="$candidate"
			break
		fi
	done

	if [ -z "$line1" ]; then
		# Nothing fit on one line. line1 keeps just the core left-hand side
		# (OS icon, user@host, git branch, directory) and everything from
		# the limits onward moves down, still right-aligned against the
		# same edge.
		line1="$core_left"
		for style in "${style_ladder[@]}"; do
			if candidate=$(fit_lr "$(build_limits "$style")" "$(compose_right "$style")"); then
				line2="$candidate"
				break
			fi
		done
		# Even a line of its own is not enough: emit the narrowest style
		# and let it run long, rather than clipping. Same divider as
		# fit_lr, and the same rule -- only when there is something on
		# both sides of it.
		if [ -z "$line2" ]; then
			line2_limits=$(build_limits "$narrowest_style")
			line2_right=$(compose_right "$narrowest_style")
			if [ -n "$line2_limits" ] && [ -n "$line2_right" ]; then
				line2="${line2_limits} ${dim}│${reset} ${line2_right}"
			else
				line2="${line2_limits}${line2_right}"
			fi
		fi
	fi
fi

# ---------------------------------------------------------------------------
# Assemble final output -- up to three lines, in order:
#   1. dependency warning (only when something's missing, see top of script)
#   2. line1 (core left side, plus rate-limit batteries/model/effort/context
#      ring when everything fit on one line)
#   3. line2 (only when even icon-style batteries could not fit it all on
#      line1 -- see the degradation ladder above; carries the rate-limit
#      batteries onward)
# Built as an array and joined with '\n' so any combination of
# warning/line2 being present or absent still composes correctly, and the
# plain case (no warning, no line2) stays byte-for-byte a single `line1`.
# ---------------------------------------------------------------------------
output_lines=()
if [ "${#missing_commands[@]}" -gt 0 ]; then
	missing_list=$(IFS=', '; echo "${missing_commands[*]}")
	output_lines+=("${red}⚠ statusline: missing required command(s): ${missing_list}${reset}")
fi
output_lines+=("$line1")
[ -n "$line2" ] && output_lines+=("$line2")

_out_first=true
for _out_line in "${output_lines[@]}"; do
	if $_out_first; then
		printf '%s' "$_out_line"
		_out_first=false
	else
		printf '\n%s' "$_out_line"
	fi
done
