#!/usr/bin/env bash
# Desktop notification for Claude Code's Notification hook.
#
# Reads the hook payload on stdin and routes on .notification_type:
# what sound plays, how urgent the toast is, and whether to notify at all
# are all decided here. settings.json just points every notification at
# this script. Always exits 0 so a missing tool can never fail the hook.
#
# Sound ids come from the freedesktop theme (/usr/share/sounds/freedesktop).
# window-question       = a modal dialog is waiting on you (choices or input)
# message-new-instant   = the prompt itself is idle, waiting on you
# service-login         = logged in
#
# urgency critical toasts persist until dismissed; normal and low time out.
#
# Over SSH the desktop is at the other end of the connection, where neither
# D-Bus nor PipeWire can be reached from here. If the client forwarded a relay
# socket in, the payload is handed over untouched and the client's own copy of
# this script routes and renders it -- so a remote box needs only bash and
# socat, not libnotify, libcanberra or a sound theme. See the
# setup-claude-config skill for the ssh and listener side.

payload=$(cat)

# The relay path is deliberately *not* the name the listener binds locally, so
# a desktop run can never connect to itself; CLAUDE_NOTIFY_RENDER, which the
# listener sets, is the second guard against a symmetric misconfiguration
# turning this into a loop.
relay=${CLAUDE_NOTIFY_RELAY:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claude-notify-relay.sock}
if [ -z "${CLAUDE_NOTIFY_RENDER:-}" ] && [ -S "$relay" ] && command -v socat >/dev/null 2>&1; then
  # A socket left behind by a dead tunnel fails to connect -- in that case fall
  # through and render here, which is right when this is the desktop after all.
  printf '%s' "$payload" | socat -u - "UNIX-CONNECT:$relay" 2>/dev/null && exit 0
fi

extract() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }

message=$(extract .message)
[ -n "$message" ] || exit 0

case $(extract .notification_type) in
  # a multiple-choice dialog is open
  permission_prompt | worker_permission_prompt | agent_needs_input)
    urgency=critical sound=window-question ;;
  # MCP elicitation: usually a text field, sometimes a picker or a URL to
  # open -- still a modal dialog blocking on you, so it shares the sound above
  elicitation_dialog | elicitation_url_dialog)
    urgency=critical sound=window-question ;;
  # you have been away from the prompt for 60s
  idle_prompt)
    urgency=normal sound=message-new-instant ;;
  auth_success)
    urgency=low sound=service-login ;;
  # everything else needs no input from you, so stay quiet:
  # elicitation_complete, elicitation_response, agent_completed,
  # computer_use_enter, computer_use_exit, push_notification
  *)
    exit 0 ;;
esac

notify-send -a 'Claude Code' -u "$urgency" -i "$HOME/.claude/claude.png" \
  'Claude Code' "$message" 2>/dev/null

canberra-gtk-play -i "$sound" 2>/dev/null

exit 0
