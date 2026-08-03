#!/bin/bash
# Claude Code statusline.
#
# Single line, styled after the user's Starship prompt (see $STARSHIP_CONFIG,
# or the default ~/.config/starship.toml) on the left, usage-limit bars right
# after the directory, and model + context ring right-aligned on the far
# right:
#   - OS icon                  ([os] module, per-distro symbol)
#   - username (green/red)     ([username] style_user = fg:green, style_root = fg:red)
#   - @hostname (green)        ([hostname] format, styled like the "[@$hostname](fg:green)" segment)
#   - git branch (orange)      ([git_branch] style = "fg:#FCA17D")
#   - directory (uncolored)    ([directory] style = "", full path, no truncation)
#   - usage limits, as progress bars, right after the directory. The bars
#     show what is REMAINING (fill and number are 100 - used), but stay
#     colored by what is USED -- see progress_bar for why:
#       - Session (5h) limit  <- input.rate_limits.five_hour.used_percentage
#       - Weekly (7d) limit   <- input.rate_limits.seven_day.used_percentage
#       - "Fable" limit       <- input.rate_limits.fable.used_percentage IF
#                                that field is ever added by Claude Code.
#   - [right-aligned] model name (colored by tier: Haiku teal / Sonnet blue /
#     Opus purple / Fable gold)  <- input.model.display_name, input.model.id
#   - [right-aligned, after model] thinking effort level, e.g. "xhigh" --
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
#     with a "k" suffix.
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

progress_bar() {
	# $1 = rounded integer USED percentage, $2 = bar width (default 10).
	# The bar is flipped to the user's perspective: fill and number show
	# what is REMAINING (100 - used), while the color still tracks USED via
	# ring_color's gradient -- so a nearly-drained limit shows a short red
	# "8%" bar rather than a reassuring-green one, and the palette stays
	# consistent with the context ring, which keeps both showing and
	# coloring used.
	local used="$1" width="${2:-10}" p c filled empty i bar
	[ "$used" -lt 0 ] && used=0
	[ "$used" -gt 100 ] && used=100
	c=$(ring_color "$used")
	p=$(( 100 - used ))
	filled=$(( (p * width + 50) / 100 ))
	[ "$filled" -gt "$width" ] && filled="$width"
	[ "$filled" -lt 0 ] && filled=0
	empty=$(( width - filled ))
	bar=""
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	local bar_empty=""
	for ((i = 0; i < empty; i++)); do bar_empty+="░"; done
	printf "%s%s%s%s%s %s%s%%%s" "$c" "$bar" "$dim" "$bar_empty" "$reset" "$c" "$p" "$reset"
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
# JSON-derived field (rate-limit bars, model name, context ring) vanished at
# once with nothing to explain it. Add to REQUIRED_COMMANDS if a future
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
display_dir="${cwd/#$HOME/~}"

os_icon=""
if [ -r /etc/os-release ]; then
	os_id=$(. /etc/os-release 2>/dev/null; echo "$ID")
	case "$os_id" in
		fedora) os_icon="" ;;
		ubuntu) os_icon="" ;;
		debian) os_icon="" ;;
		arch) os_icon="" ;;
		alpine) os_icon="" ;;
		nixos) os_icon="" ;;
		*) os_icon="" ;;
	esac
fi

if [ "$(id -u)" -eq 0 ]; then
	user_color="$red"
else
	user_color="$green"
fi
user_part="${user_color}$(whoami)${reset}"
host_part="${green}@$(hostname -s)${reset}"

git_part=""
if git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
	[ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
	[ -n "$branch" ] && git_part=" ${orange}${branch}${reset}"
fi

# Claude Code usage limits, as progress bars, shown right after the directory.
session_pct=$(echo "$input" | jqr '.rate_limits.five_hour.used_percentage // empty')
session_resets_at=$(echo "$input" | jqr '.rate_limits.five_hour.resets_at // empty')
weekly_pct=$(echo "$input" | jqr '.rate_limits.seven_day.used_percentage // empty')
weekly_resets_at=$(echo "$input" | jqr '.rate_limits.seven_day.resets_at // empty')
# Speculative/forward-compatible only -- see header note above. Empty today.
fable_pct=$(echo "$input" | jqr '.rate_limits.fable.used_percentage // empty')

limit_segments=()

if [ -n "$session_pct" ]; then
	s_r=$(printf '%.0f' "$session_pct")

	# "(HH:MM)" countdown to the 5-hour session reset, right after the
	# "Session" label -- styled the same dim "(...)" way the context ring
	# shows "(50k/200k)" next to it. Only "Session" (five_hour) gets this,
	# not "Week" -- the user specifically asked about the current session.
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
			session_reset_part="${dim}(${session_remaining_text})${reset} "
		fi
	fi

	limit_segments+=("${dim}Session${reset} ${session_reset_part}$(progress_bar "$s_r")")
fi

if [ -n "$weekly_pct" ]; then
	w_r=$(printf '%.0f' "$weekly_pct")

	# "(D:HH:MM)" countdown to the 7-day weekly reset, mirroring the Session
	# block's countdown above -- same gating (resets_at present + remaining
	# time > 0, else fall back to the plain "Week <bar>" rendering) and same
	# dim "(...)" wrapper style. Unlike Session, a 7-day window can have
	# multi-day remaining time, so this adds a leading day digit (0-6,
	# realistically never needing zero-padding) ahead of the zero-padded
	# HH:MM, e.g. "3:04:12" for 3 days/4h/12m remaining -- still a fixed
	# width for any value this window can realistically produce, so the
	# layout stays stable as it counts down.
	weekly_reset_part=""
	if [ -n "$weekly_resets_at" ]; then
		now_epoch=$(date +%s)
		weekly_remaining_secs=$(( weekly_resets_at - now_epoch ))
		if [ "$weekly_remaining_secs" -gt 0 ] 2>/dev/null; then
			wr_d=$(( weekly_remaining_secs / 86400 ))
			wr_h=$(( (weekly_remaining_secs % 86400) / 3600 ))
			wr_m=$(( (weekly_remaining_secs % 3600) / 60 ))
			weekly_remaining_text=$(printf '%d:%02d:%02d' "$wr_d" "$wr_h" "$wr_m")
			weekly_reset_part="${dim}(${weekly_remaining_text})${reset} "
		fi
	fi

	limit_segments+=("${dim}Week${reset} ${weekly_reset_part}$(progress_bar "$w_r")")
fi

if [ -n "$fable_pct" ]; then
	f_r=$(printf '%.0f' "$fable_pct")
	limit_segments+=("${dim}Fable${reset} $(progress_bar "$f_r")")
fi

limits_part=""
first=true
for seg in "${limit_segments[@]}"; do
	if $first; then
		limits_part="$seg"
		first=false
	else
		limits_part="${limits_part} ${dim}│${reset} ${seg}"
	fi
done

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

core_left="${os_icon} ${user_part}${host_part}${git_part} ${display_dir}"
line1_left="$core_left"
[ -n "$limits_part" ] && line1_left="${line1_left} ${dim}│${reset} ${limits_part}"

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
[ -n "$model_name" ] && line1_right="${model_color}${model_name}${reset}"

if [ -n "$effort_level" ]; then
	case "$effort_level" in
		low) effort_rendered="${effort_low_color}${effort_level}${reset}" ;;
		medium) effort_rendered="${effort_medium_color}${effort_level}${reset}" ;;
		high) effort_rendered="${effort_high_color}${effort_level}${reset}" ;;
		xhigh) effort_rendered=$(render_shiny "$effort_level" $effort_xhigh_rgb "$(date +%s)") ;;
		max) effort_rendered=$(render_rainbow "$effort_level" "$(date +%s)") ;;
		*) effort_rendered="${dim}${effort_level}${reset}" ;;
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
	if [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
		ring_part="${ring_part} ${dim}($(format_tokens "$ctx_tokens")/$(format_tokens "$ctx_size"))${reset}"
	fi
	if [ -n "$line1_right" ]; then
		line1_right="${line1_right} ${ring_part}"
	else
		line1_right="$ring_part"
	fi
fi

line2=""

if [ -n "$line1_right" ]; then
	term_width="${COLUMNS:-}"
	[ -z "$term_width" ] && term_width=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
	[ -z "$term_width" ] && term_width=$(tput cols 2>/dev/null)
	[ -z "$term_width" ] && term_width=80

	# Safety margin: Claude Code's own UI chrome (borders/indicators) can eat
	# a few columns beyond the raw terminal width we're able to detect from
	# this subprocess, so don't push all the way to the reported edge.
	term_width=$(( term_width - 4 ))
	[ "$term_width" -lt 20 ] && term_width=20

	left_len=$(vis_len "$line1_left")
	right_len=$(vis_len "$line1_right")
	pad=$(( term_width - left_len - right_len ))

	if [ "$pad" -lt 1 ]; then
		# Not enough room to fit everything on one line -- instead of
		# risking clipping/overflow against Claude Code's own UI chrome,
		# move everything from the session-limit bar onward (rate-limit
		# bars, then model/effort/context ring) down to its own second
		# line, leaving line1 as just the core left-hand side (icon,
		# user@host, git branch, directory -- no rate-limit bars).
		line1="$core_left"
		if [ -n "$limits_part" ]; then
			# Right-align line1_right against the terminal edge on line2
			# too -- same term_width and the same vis_len-based spacer math
			# as the line1_left/line1_right split above, just with
			# limits_part standing in for line1_left as the left anchor.
			limits_len=$(vis_len "$limits_part")
			right_len2=$(vis_len "$line1_right")
			pad2=$(( term_width - limits_len - right_len2 ))
			if [ "$pad2" -lt 1 ]; then
				# Even line2 alone doesn't fit -- same single-space
				# fallback the pre-split single-line path used to fall
				# back to in this situation.
				line2="${limits_part} ${line1_right}"
			else
				spacer2=$(printf '%*s' "$pad2" '')
				line2="${limits_part}${spacer2}${line1_right}"
			fi
		else
			line2="$line1_right"
		fi
	else
		spacer=$(printf '%*s' "$pad" '')
		line1="${line1_left}${spacer}${line1_right}"
	fi
else
	line1="$line1_left"
fi

# ---------------------------------------------------------------------------
# Assemble final output -- up to three lines, in order:
#   1. dependency warning (only when something's missing, see top of script)
#   2. line1 (core left side, plus rate-limit bars/model/effort/context ring
#      when everything fit on one line)
#   3. line2 (only when the terminal was too narrow to fit it all on line1 --
#      see the width check above; carries the rate-limit bars onward)
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
