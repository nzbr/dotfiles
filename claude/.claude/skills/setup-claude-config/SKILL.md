---
name: setup-claude-config
description: Use when setting up Claude Code on a new computer, or after the .claude scripts are first deployed to a machine, to wire the status line and desktop notification hook into ~/.claude/settings.json. Also use to repair or re-check that wiring.
---

# Set up Claude Code's settings.json

The scripts under `~/.claude/` are deployed by external config management —
which tool that is varies per machine (nix/home-manager, chezmoi, stow,
ansible, a git checkout). Whatever it is, it cannot own `settings.json`:
Claude Code rewrites that file at runtime (theme, model, plugin toggles), so
it has to stay a real, mutable file. This skill is the imperative half. It
merges the entries that point at the deployed scripts into whatever
`settings.json` already contains.

Assume the scripts are already in place. If they are missing, the machine's
config management has not been applied — say so and stop. Do not hand-create
them here; they would then be unmanaged and drift.

## 1. Confirm the scripts are present

```bash
for f in statusline-command.sh notify.sh claude.png; do
  [ -e "$HOME/.claude/$f" ] && echo "ok      $f" || echo "MISSING $f"
done
```

Any of these may be a symlink into a read-only store. That is normal and
fine — the scripts are read and executed, never written.

## 2. Derive the dependencies from the scripts themselves

Read `statusline-command.sh` and `notify.sh` and work out what they need.
Do not rely on a list in this file: the scripts are maintained elsewhere and
this document will go stale. What to look for:

- **Commands invoked.** Skip shell builtins; you want the external binaries.
- **Explicit self-checks.** A `REQUIRED_COMMANDS=(...)` array or a series of
  `command -v x ||` guards is the script telling you its own contract — that
  is the authoritative list, prefer it over your own grep.
- **Data files at absolute paths.** The notification icon, and the sound
  theme directory. A missing data file breaks things just as thoroughly as a
  missing binary, and is easier to overlook.
- **Sound IDs.** `notify.sh` passes ids to `canberra-gtk-play -i`. Extract
  each one and confirm a matching `<id>.oga` exists in the sound theme
  directory — a theme can be installed but incomplete.

Distinguish hard requirements from soft ones as you read. A command used
behind a `command -v` guard degrades gracefully; one called unconditionally
does not. Note which is which — it decides whether a gap blocks setup or
merely gets reported.

Sanity check: this should come out to a handful of small CLI tools plus
libnotify, libcanberra and a freedesktop sound theme. If your reading turns
up nothing resembling that, you have misread the scripts — look again.

## 3. Verify availability — this is a gate

Check everything from step 2 and classify each gap as hard or soft.

**Resolve hard gaps before merging.** A statusline or hook that references a
missing binary fails silently at the worst possible moment: hooks swallow
their own errors by design, so a broken notification looks exactly like a
quiet one. Do not write the config and leave the user to discover this.

Soft gaps: report them, then continue.

### Before offering to install anything, check whether the system is declarative

```bash
[ -e /run/current-system/nixos-version ] || [ -e /etc/NIXOS ] && echo "NixOS"
[ -e /run/ostree-booted ] && echo "ostree/bootc image-based (Silverblue, Bluefin, etc.)"
[ -d /gnu/store ] && echo "Guix"
```

**Declarative system → do not install.** An imperative install is either
impossible or gets wiped on the next rebuild. Instead identify the package
names and give the user the exact change to make in their own config, then
stop and let them apply it.

On ostree/bootc specifically, offer the choice rather than assuming: package
layering (`rpm-ostree install`) works but needs a reboot to take effect,
whereas a toolbox/distrobox, `brew`, or a nix profile installs immediately
without touching the base image. Which is right depends on how the user
treats that machine — ask.

**Non-declarative system → offer to install.** Detect the package manager
(`dnf`, `apt`, `pacman`, `zypper`, `apk`, `brew`, …), then map each missing
file to a package using that distro's own file-to-package query rather than
guessing a name:

```bash
dnf provides '*/bin/notify-send'        # Fedora/RHEL — works for data paths too
apt-file search bin/notify-send         # Debian/Ubuntu
pacman -F usr/bin/notify-send           # Arch
zypper what-provides '*/notify-send'    # openSUSE
```

Then **ask before installing.** It needs sudo and changes the system, so it
is the user's call, not yours — present the resolved package list and wait.
Never run the install unprompted, and if they decline, say plainly which
features will be dead and continue to the merge anyway.

## 4. Merge

Guard first — never clobber a settings file that is unreadable or unwritable:

```bash
S=$HOME/.claude/settings.json
[ -e "$S" ] || echo '{}' > "$S"
jq -e . "$S" >/dev/null || { echo "settings.json is not valid JSON — stop, show it to the user"; exit 1; }
[ -w "$S" ] || { echo "settings.json is not writable — is config management wrongly owning it? stop"; exit 1; }
```

Then merge in one pass. Do it with `jq`, not by editing text: this must
preserve unrelated keys, stay idempotent, and not race Claude Code's own
writes to the same file.

```bash
SL='{"type":"command","command":"bash ~/.claude/statusline-command.sh","refreshInterval":1}'
NH='{"matcher":".*","hooks":[{"type":"command","command":"bash ~/.claude/notify.sh","timeout":10}]}'

jq --argjson sl "$SL" --argjson nh "$NH" '
  .statusLine = $sl
  | .hooks = (.hooks // {})
  | .hooks.Notification = (
      ((.hooks.Notification // [])
        | map(select([.hooks[]?.command // ""] | any(test("notify\\.sh")) | not)))
      + [$nh])
' "$S" > "$S.new" && mv "$S.new" "$S"
```

Why it is shaped that way:

- `.hooks.Notification` drops any prior entry that calls `notify.sh` and
  re-appends one, so running twice yields one hook, not two — while any
  *unrelated* Notification hook the user added is preserved.
- The matcher is `.*` on purpose. All routing — which `notification_type`
  gets which sound and urgency, and which get nothing at all — lives in the
  `case` statement inside `notify.sh`, one place rather than split across
  matcher regexes. Do not "helpfully" split this back into per-type matchers.
- `.statusLine` is overwritten outright. If it held something different,
  mention that in the report — on a new machine it won't.

Out of scope: `model`, `effortLevel`, `theme`, `skipAutoPermissionPrompt`,
`enabledPlugins`. Those are preferences, not script wiring, and are set
through `/config` and `/plugin`. Add them here only if asked.

## 5. Verify

```bash
S=$HOME/.claude/settings.json
jq -e . "$S" >/dev/null && echo "JSON valid"
jq -e '.statusLine.command' "$S"
jq -e '.hooks.Notification[] | select(.hooks[]?.command | test("notify\\.sh")) | .matcher' "$S"
echo "notify.sh hook entries: $(jq '[.hooks.Notification[]? | select(.hooks[]?.command | test("notify\\.sh"))] | length' "$S")"
jq -r 'keys | join(", ")' "$S"
```

Expect valid JSON, both selectors printing, exactly **1** notify.sh entry,
and every pre-existing key still listed.

Then prove the scripts actually run. This matters most on new hardware,
where an absent notification daemon or sound theme is the likely failure:

```bash
printf '{"hook_event_name":"Notification","notification_type":"auth_success","message":"Claude Code notifications are live","title":"Claude Code"}' \
  | bash "$HOME/.claude/notify.sh"; echo "  notify.sh exit=$?"
```

Build the statusline's test payload from the fields you saw it read in step 2
rather than copying one from here, and pipe it in the same way. It must print
a non-empty line.

`notify.sh` must exit 0 **and** produce a visible toast with sound. Exit 0
alone proves nothing — it swallows every error by design so that it can never
fail a hook. Ask the user whether they saw and heard it. If not, the wiring
is fine and the desktop side is at fault: no notification daemon running, or
the sound theme is missing.

## 6. Report

State what changed, what was already correct, and any gap from step 3 —
with the package that closes it, and whether you installed it or left it to
the user.

Close with: the statusline appears on the next prompt, but a newly written
hook is only picked up once Claude Code reloads its config — tell the user to
open `/hooks` once, or restart. You cannot do this for them; `/hooks` is an
interactive menu and opening it ends the turn.
