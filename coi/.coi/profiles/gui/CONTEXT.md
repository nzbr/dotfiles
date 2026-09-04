## This sandbox has a graphical display

You can start Wayland applications here. `WAYLAND_DISPLAY` and
`XDG_RUNTIME_DIR` are already set, so GUI toolkits find the display with no
extra setup, and the compositor starts on demand the first time something
connects — there is nothing to launch first.

**Prefer the real, windowed version of a tool over its headless equivalent.**
Run the actual browser rather than a headless one, the real GUI application
rather than a virtual-framebuffer or `--no-sandbox --headless` variant. The
windowed version is usually the one that behaves like the thing the user
actually runs, so it is the better thing to test against.

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

Capture the whole output only when the arrangement of the windows is itself
what you are checking:

    nix run nixpkgs#wayshot -- shot.png
    nix run nixpkgs#wayshot -- --geometry "<x>,<y> <w>x<h>" shot.png

Do that whenever you have drawn something: check how it actually rendered
rather than assuming, and rather than asking the user to describe it. A
screenshot is also the quickest way to tell an application that failed to
start from one that started and drew nothing.
