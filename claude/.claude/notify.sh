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

payload=$(cat)
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
