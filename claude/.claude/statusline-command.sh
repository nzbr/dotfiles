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
#   - usage limits, as progress bars, right after the directory:
#       - Session (5h) limit  <- input.rate_limits.five_hour.used_percentage
#       - Weekly (7d) limit   <- input.rate_limits.seven_day.used_percentage
#       - "Fable" limit       <- input.rate_limits.fable.used_percentage IF
#                                that field is ever added by Claude Code.
#   - [right-aligned] model name (colored by tier: Haiku teal / Sonnet blue /
#     Opus purple / Fable gold)  <- input.model.display_name, input.model.id
#   - [right-aligned, after model] ring NN% (raw/size)  <- ring glyph
#     (○◔◑◕●) fills with input.context_window.used_percentage (falls back to
#     total_input_tokens / context_window_size), followed by "(used/size)"
#     in raw tokens (e.g. "Sonnet 5 ● 84% (168k/200k)"), abbreviated with a
#     "k" suffix.
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
	# $1 = rounded integer percentage, $2 = bar width (default 10); colored
	# via ring_color's gradient, same as the context ring/percentage.
	local p="$1" width="${2:-10}" c filled empty i bar
	c=$(ring_color "$p")
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

# ---------------------------------------------------------------------------
# Line 1 -- Starship-inspired prompt + model, context on the right
# ---------------------------------------------------------------------------

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
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
session_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
# Speculative/forward-compatible only -- see header note above. Empty today.
fable_pct=$(echo "$input" | jq -r '.rate_limits.fable.used_percentage // empty')

limit_segments=()

if [ -n "$session_pct" ]; then
	s_r=$(printf '%.0f' "$session_pct")
	limit_segments+=("${dim}Session${reset} $(progress_bar "$s_r")")
fi

if [ -n "$weekly_pct" ]; then
	w_r=$(printf '%.0f' "$weekly_pct")
	limit_segments+=("${dim}Week${reset} $(progress_bar "$w_r")")
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

model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_key=$(echo "$input" | jq -r '((.model.id // "") + " " + (.model.display_name // ""))' | tr '[:upper:]' '[:lower:]')

case "$model_key" in
	*haiku*) model_color="$haiku_color" ;;
	*sonnet*) model_color="$sonnet_color" ;;
	*opus*) model_color="$opus_color" ;;
	*fable*) model_color="$fable_color" ;;
	*) model_color="$dim" ;;
esac

line1_left="${os_icon} ${user_part}${host_part}${git_part} ${display_dir}"
[ -n "$limits_part" ] && line1_left="${line1_left} ${dim}│${reset} ${limits_part}"

ctx_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -z "$ctx_used" ] && [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
	ctx_used=$(awk -v t="$ctx_tokens" -v s="$ctx_size" 'BEGIN { printf "%.2f", (t / s) * 100 }')
fi

# Right side: model name (colored by tier), then the context ring -- built
# up piece by piece so either can be absent without leaving a stray space.
line1_right=""
[ -n "$model_name" ] && line1_right="${model_color}${model_name}${reset}"

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
		# Not enough room to right-align without overflowing -- fall back to
		# inline placement right after the left side instead of risking
		# clipping off the edge of the visible line.
		line1="${line1_left} ${line1_right}"
	else
		spacer=$(printf '%*s' "$pad" '')
		line1="${line1_left}${spacer}${line1_right}"
	fi
else
	line1="$line1_left"
fi

printf '%s' "$line1"
