## This sandbox has a graphical display

You can start Wayland applications here. `WAYLAND_DISPLAY` and
`XDG_RUNTIME_DIR` are already set, so GUI toolkits find the display with no
extra setup, and the compositor starts on demand the first time something
connects — there is nothing to launch first.

**Prefer the real, windowed version of a tool over its headless equivalent.**
Run the actual browser rather than a headless one, the real GUI application
rather than a virtual-framebuffer or `--no-sandbox --headless` variant. The
windowed version is usually the one that behaves like the thing the user
actually runs, so it is the better thing to test against. Starting a browser
and driving it has enough detail of its own that it is a separate section at
the end of this file.

**Opening windows does not disturb the user.** This is a separate, sandboxed
compositor session, not their desktop. Nothing you open appears on their
screen, takes focus, or interrupts what they are doing. They can open a
window into the session whenever they want, so anything you draw is there for
them to look at and interact with on their own schedule. Do not hesitate, ask
permission, or fall back to a headless mode out of concern for interrupting
them — none of those apply here.

**You can screenshot the display.** `wayshot` captures it from inside the
sandbox, and `nix run` fetches it on demand, so there is nothing to install.

**Screenshot the window you care about, not the whole screen.** List the
open windows, then capture one by the identifier the listing gives you:

    nix run nixpkgs#wayshot -- --list-toplevels
    nix run nixpkgs#wayshot -- --toplevel <identifier> shot.png

That photographs the window itself rather than the screen. It crops to just
that window, so nothing else is in frame to read past, and it works on a
window that is behind another one or minimized — you never have to raise,
move, resize or focus anything to get a clean picture of it. Read the image
back and look at it.

The identifier belongs to that particular window, not to the application, so
it changes every time the application restarts. List the toplevels again each
time rather than reusing one you remember.

Capture the whole output only when the arrangement of the windows is itself
what you are checking, or when you need on-screen coordinates to click:

    nix run nixpkgs#wayshot -- shot.png
    nix run nixpkgs#wayshot -- --geometry "<x>,<y> <w>x<h>" shot.png

**Other agents may be sharing this display with you.** Windows you did not
open belong to someone else's session. Do not focus, click into, type into,
move or close them, and leave the clipboard alone unless you put it there —
there is one cursor, one keyboard focus and one clipboard between all of you,
and taking any of them interrupts whoever was using it. Looking is always
safe: capturing a window by identifier touches nothing, so screenshot anything
you like.

**Focus the window first, every single time, before you type or click into
it.** Input goes to whatever holds focus, which is not necessarily the window
you just opened or the one you touched last:

    nix run nixpkgs#wlrctl -- toplevel focus app_id:foot

Skipping this is the usual reason input seems to vanish: the keystrokes land
in another window, or an open menu still holds a pointer grab and eats your
click to dismiss itself instead of pressing what you aimed at. Focus, confirm
with `wlrctl toplevel find app_id:foot state:active`, then act.

`wlrctl toplevel` also takes `minimize`, `maximize`, `fullscreen` and `find`,
matching on `app_id:`, `title:` and `state:`. Fullscreening a window before
you click into it is the cheapest way to make its coordinates predictable,
since its contents then sit at known offsets from the corner of the output.

**You can move the pointer and click.** `wlrctl` drives a virtual pointer, so
you can operate an application rather than only look at it:

    nix run nixpkgs#wlrctl -- pointer move -5000 -5000   # home to the top left
    nix run nixpkgs#wlrctl -- pointer move 640 440       # now absolute pixels
    nix run nixpkgs#wlrctl -- pointer click              # left, or right / middle
    nix run nixpkgs#wlrctl -- pointer scroll 5 0         # vertical, horizontal

`pointer move` is relative, so drive the cursor hard into the top left corner
first — the compositor clamps it to the output — and the move after that lands
on an absolute coordinate. Get the coordinate by capturing the whole output
and reading the position off the image.

Press and release are not exposed separately, so there is no dragging: no
moving a window by its titlebar, no sliders, no drag-selection.

Move the cursor when you have something to click, not to point at things.

**You can type.** `wtype` drives a virtual keyboard:

    nix run nixpkgs#wtype -- -s 100 -d 5 'hello world' -k Return
    nix run nixpkgs#wtype -- -s 100 -M ctrl -k l -m ctrl

`-s 100` is load-bearing: it waits for the keymap to reach the application,
and without it the opening characters are typed into nothing and lost. `-d 5`
spaces out the rest. `-k <name>` sends a named key (`Return`, `Tab`, `Escape`,
`Left`), and `-M` / `-m` hold and release a modifier around one.

**Zoom out to fit more into one screenshot.** Browsers, terminals and editors
almost all zoom with `ctrl` and `-`, and a zoomed-out window carries far more
content per capture — one image to read instead of four, with no scrolling in
between:

    nix run nixpkgs#wlrctl -- toplevel maximize app_id:foot
    nix run nixpkgs#wtype -- -s 100 -M ctrl -k minus -m ctrl   # -k plus to undo

Maximize or fullscreen the window first: a larger window holds more to begin
with, and it pins the size. That second part matters for terminals, which size
themselves in character cells — a floating one answers a zoom by shrinking its
own window around the same content, gaining you nothing, while a maximized one
has to spend the smaller font on more rows and columns. Six presses took one
on a 1280x800 output from 213x59 to 320x86 cells, still easily readable.

There is a floor — a screenshot is scaled down again when you read it back —
so zoom until the text is small rather than until it is gone, and look at the
capture to see which you got.

**Do not `pkill -f` a pattern that also appears in your own command.** The
shell running that command matches the pattern and kills itself, taking
everything after the `pkill` with it — the visible symptom is that the rest of
the script silently did not run, with exit code 144. Kill by PID instead:

    pgrep -a -f '[f]irefox'
    kill <pid>

The character class stops the pattern from matching the shell that is
searching for it, but a shell that genuinely mentions the program — the one
that launched it, say — still matches, so read the `pgrep -a -f` output and
pick the PID out of it rather than trusting the match. That is also how to
check whether something is running: a bare `pgrep -a -f firefox` always finds
the shell doing the checking.

## Driving a browser: Firefox

**There is no browser installed — start one with `nix run`.** `which firefox`
finds nothing and apt has no candidate. As with `wayshot` and `wlrctl`, nix
fetches one on demand:

    mkdir -p ~/ff-profile
    MOZ_ENABLE_WAYLAND=1 nix run nixpkgs#firefox -- --profile ~/ff-profile \
      --no-remote --new-instance --remote-debugging-port 9222 about:blank &

`WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` are already right, but Firefox also
wants `MOZ_ENABLE_WAYLAND=1`, which is not set. Every start logs `Failed to
create DBus proxy for org.a11y.Bus: Cannot autolaunch D-Bus without X11
$DISPLAY`; that is noise, not a failure.

**A second Firefox on the same profile fails quietly.** With one already
running, another `--no-remote --new-instance` start leaves a live process that
never binds the debugging port and never logs the BiDi line. If the port looks
dead, count the processes before debugging anything else.

**`--remote-debugging-port` gives you WebDriver BiDi, which is much cheaper
than typing at the window** — one call per page instead of six keystroke round
trips. Wait for `WebDriver BiDi listening on ws://127.0.0.1:9222` in the log.
Four things to know about it:

- It is BiDi only, not CDP. `http://127.0.0.1:9222/json/version` answers 404,
  so nothing written against the Chrome DevTools Protocol works here.
- Firefox allows exactly one active session, and the session outlives the
  socket that created it. A client that calls `session.new` per invocation
  therefore works once and fails on every call after that with `session not
  created: Maximum number of active sessions`, with nothing to be done about
  it but restart Firefox. Run one long-lived process that owns the session and
  talk to that — over a local HTTP port, say — rather than connecting per
  command.
- BiDi refuses `about:` URLs: `Navigation to "about:policies" is not allowed
  in this context`. Reaching `about:policies`, `about:addons` or
  `about:support` still means `wtype` in the window.
- Write the client in Node. `/usr/bin/python3` has no `pip`, there is no
  mise-managed Python and no `websockets` package in apt, while Node exposes a
  global `WebSocket` — so a Node client needs no dependencies at all.

`browsingContext.captureScreenshot` with `origin: "document"` captures the
whole page including what is scrolled off, needs no focus, and beats `wayshot`
for page content. `wayshot --toplevel` is still the only way to see browser
chrome: toolbar icons, doorhangers, panels.

**Install an adblocker, and install it with an enterprise policy.** A cleaner
page is a cheaper one to read, but the obvious route silently fails: dropping
the `.xpi` into `<profile>/extensions/` does not run the extension, even
though `extensions.json` then describes it as active, not disabled and
`signedState=2`. `extensions.json` is not evidence that an extension is
running. A policy file works, and Firefox reads it from `/etc`:

    sudo mkdir -p /etc/firefox/policies
    sudo tee /etc/firefox/policies/policies.json >/dev/null <<'JSON'
    { "policies": { "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "default_area": "navbar" } } } }
    JSON

Restart Firefox afterwards and give it ten seconds or so to install the
extension and fetch its filter lists; `about:policies` says whether the policy
was picked up. `install_url` has to be the AMO https URL — a `file:///` path
to a local `.xpi` does not install.

**Check the adblocker by looking at it, not by fetching a known ad script.**
uBlock answers `pagead2.googlesyndication.com/pagead/js/adsbygoogle.js` and
`google-analytics.com/analytics.js` with a neutered local stub and HTTP 200
rather than blocking them, so the natural test reports a working adblocker as
broken. Capture the window and look for the uBlock icon and its badge count
instead. If you do want a fetch test, aim it at a host uBlock blocks outright,
such as `ads.pubmatic.com` or `cdn.taboola.com`.

## Driving a browser: Chromium

**Chromium is the easier one to drive and the harder one to start.** The
scripted tier is CDP rather than BiDi: listing and opening tabs takes nothing
but `curl`, there is no session to create and nothing accumulates, so a fresh
websocket per command is fine. `chrome://` pages are reachable that way as
well. Everything above about `wayshot`, `wlrctl`, `wtype` and zooming applies
to it unchanged.

**It needs `--ozone-platform=wayland`.** Without it Chromium picks the X11
backend, finds no `$DISPLAY` and exits 1 with `Missing X server or $DISPLAY`
followed by `The platform failed to initialize.  Exiting.`:

    nix run nixpkgs#chromium -- --ozone-platform=wayland \
      --user-data-dir="$HOME/cr-profile" --remote-debugging-port=9222 \
      about:blank &

Leave `--no-sandbox` off. Unprivileged user namespaces work in this
container, so Chromium's own sandbox comes up without help.

**The first twenty log lines are noise.** Every start fails to find a render
node (`drmGetDevices2() has not found any devices`), fails to initialize EGL
half a dozen times over, ends that with `Exiting GPU process due to errors
during initialization`, and throws in `Failed to connect to the bus` plus, on
and off for as long as it runs, `registration_request.cc` errors from the GCM
client. None of it matters, because the window renders in software and looks
right. Wait for

    DevTools listening on ws://127.0.0.1:9222/devtools/browser/<id>

and ignore the rest.

**Tabs over plain HTTP, everything else over the websocket.**
`http://127.0.0.1:9222/json/version` and `/json/list` answer with JSON, and
`/json/list` is where a target's `webSocketDebuggerUrl` comes from. Two
things about `/json/new`: it refuses `GET` with `Using unsafe HTTP verb GET
to invoke /json/new. This action supports only PUT verb.`, and its `?url=`
does not navigate - the tab opens on `about:blank` whether you encode the URL
or not. Open the tab, then navigate it with `Page.navigate`.

    curl -s http://127.0.0.1:9222/json/list
    curl -s -X PUT http://127.0.0.1:9222/json/new

**Starting Chromium again on the same `--user-data-dir` opens a tab in the
window that is already running.** It prints `Opening in existing browser
session.` and exits 0, which is the cheapest way there is to put a page on
screen. Its own `--remote-debugging-port` is ignored, so the debug port
always belongs to the first instance.

**Write the CDP client in Node**, for the same reasons as with Firefox: a
global `WebSocket` and no dependencies. One command per invocation is fine.

    const [url, method, params] = process.argv.slice(2);
    const sock = new WebSocket(url);
    sock.onopen = () => {
      const command = { id: 1, method, params: JSON.parse(params || "{}") };
      sock.send(JSON.stringify(command));
    };
    sock.onmessage = ({ data }) => {
      const message = JSON.parse(data);
      if (message.id !== 1) return;
      console.log(JSON.stringify(message.result ?? message.error));
      process.exit(0);
    };

`Page.captureScreenshot` with `captureBeyondViewport: true` is the whole page
including what is scrolled off, the counterpart of Firefox's `origin:
"document"`. Save it for pages that need it: one Wikipedia article came out
29 965 pixels tall and 7 MB, where the plain viewport capture is what you can
actually read.

**`chrome://` pages navigate fine and read as empty.** CDP has no objection
to `chrome://policy`, unlike BiDi with `about:` URLs, but the content sits in
shadow DOM, so `document.body.innerText` comes back as an empty string.
Screenshot those pages instead of scraping them - `Page.captureScreenshot`
works on them.

**The app_id is `chromium-browser`, not `chromium`.** So the focus call is
`wlrctl toplevel focus app_id:chromium-browser`, and that same string is what
`wayshot --list-toplevels` prints for the window.

**Install the adblocker through a policy, and install the Lite one.**
Chromium reads `/etc/chromium/policies/managed/*.json`, with no `policies`
wrapper around the object the way Firefox has:

    sudo mkdir -p /etc/chromium/policies/managed
    sudo tee /etc/chromium/policies/managed/ublock.json >/dev/null <<'JSON'
    { "ExtensionSettings": {
      "ddkjiahejlhfcafbddmgiahcphecmpfh": {
        "installation_mode": "force_installed",
        "update_url": "https://clients2.google.com/service/update2/crx",
        "toolbar_pin": "force_pinned" } } }
    JSON

It has to be uBlock Origin **Lite** (`ddkjiahejlhfcafbddmgiahcphecmpfh`).
Plain uBlock Origin is a Manifest V2 extension and this Chromium will not
install one: a force-install entry for `cjpalhdlnbpafiamejdnhcphjbkeiagm`
produces no error and no directory for it under
`<profile>/Default/Extensions`. `toolbar_pin` is the counterpart of Firefox's
`default_area`, and without it the extension stays hidden behind the puzzle
piece with its blocked-request badge out of sight.

Restart Chromium afterwards. `chrome://policy` says whether the file was read
at all - the entry is listed with Source `Platform` and Status `OK` - and an
extension that really installed is a directory named after its id under
`<profile>/Default/Extensions/`, in a fresh profile as much as an existing
one. It also appears in `/json/list` as a `service_worker` target, but only
while that worker is awake, so not finding it there proves nothing.

**Check the blocking the way you would on Firefox.** `ads.pubmatic.com` and
`cdn.taboola.com` fail to fetch while `example.com` loads, and the
googlesyndication and google-analytics scripts answer 200 from a local stub
here too, so those two mislead on Chromium exactly as they do on Firefox.
