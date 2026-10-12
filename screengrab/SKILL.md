---
name: screengrab
description: |
  Create screenshots of the live display with `screengrab` (lxqt) on this
  Wayland/Wayfire box. Load whenever the user asks to create / take / make a
  screenshot, capture the screen or desktop, grab the display, "show me what's
  on screen", or produce a screenshot file of the live GUI. Needs only the
  display — no daemon. Do NOT load for mouse/keyboard driving (use ydotool-gui),
  for screenshots of files/web pages the user already has, or in headless
  environments with no display.
---

# screengrab — screenshot the live display

One command captures the live Wayland/Wayfire display to a file: no daemon, no
window pops up, ~0.1 s. Verified against the lxqt/screengrab 3.1.0 source
(`main.cpp`, `core.cpp`, `wayland/ScreenCopy.cpp`) and against this box.

## Quick recipe

```bash
screengrab -f -n
SHOT=$(ls -t ~/screen*.jpg | head -1)
```

On this box the capture is 2880×1800 JPEG (~400 KB) in `$HOME`. Verify with
`file "$SHOT"` before treating the shot as valid, and pass the image to the
model (or crop it, below) when the user needs the content.

`scripts/snap.sh` wraps this: prints the new shot's path; with `x0 y0 x1 y1`
arguments it crops that rectangle and prints the crop's path.

## CLI parameters (screengrab 3.1.0)

| Flag | Meaning | Unattended |
|---|---|---|
| `-f` / `--fullscreen` | Fullscreen capture | ✓ combine with `-n` |
| `-a` / `--active` | Active window | on Wayland ⇒ fullscreen (see gotchas) |
| `-r` / `--region` | Interactive region select | ✗ blocks on mouse input |
| `-m` / `--minimized` | Hide the main window | only for GUI runs |
| `-n` / `--no-win` | Save and exit, no window | **required** for CLI use |

- No type flag ⇒ configured `defScreenshotType` (FullScreen on this box).
- `-n` applies only to the **first** screenshot; the process exits right after
  saving it (`Core::noWin()` requires `_firstScreen`).
- There is **no `--output` flag** — the file name comes from config + a counter
  (below).
- The rest of `--help` is generic Qt plumbing (`--platform` etc.) — not needed here.

## Where files go and what they are named

`defDir` (default `$HOME`) + `defFilename` (default `screen`) + per-process
counter → `~/screen.jpg`, `~/screen01.jpg`, `~/screen02.jpg`, … The counter
starts at 0 each process and increments while a name already exists
(`getSaveFilePath` / `checkExsistFile`).

- This box's binary defaults to **jpg** (upstream source defaults to png —
  the packaged build differs); switch with `defImgFormat` in
  `~/.config/screengrab/screengrab.conf`. JPEG quality = `imageQuality`
  (default 80; jpg only).
- `insDateTimeInFilename=true` + `templateDateTime` (default
  `yyyy-MM-dd-hh-mm-ss`) gives timestamped names instead.
- Always pick the file **after** the capture with `ls -t | head -1`.

## How it captures (what's in, what's missing)

On Wayland every capture goes through the `zwlr_screencopy_manager_v1`
(ext-screencopy) protocol: the compositor (wayfire) renders the output into a
shared-memory buffer. Consequences:

- Windows, panels, XWayland apps: captured. ✓
- **Layer-shell overlays (wayfire menus etc.) are NOT captured** — verify
  overlays by the user's live view, not by the image.
- **Mouse pointer: only if `includeCursor=true`** (KConfig `Base.includeCursor`;
  set via the "Include mouse pointer" checkbox in the screengrab GUI — do not
  hand-edit the conf). It is ON on this box.
- The X11-only 400 ms fade-compositing sleep is skipped on Wayland, which is
  why the whole run is ~0.1 s.

## Crop instead of `-r`

`-r` needs interactive mouse selection — never usable unattended. For a
specific area:

```bash
scripts/snap.sh 1200 300 1800 800     # crop x0 y0 x1 y1 of the latest full shot
```

…or by hand: `screengrab -f -n` then
`convert "$SHOT" -crop WxH+X+Y +repage out.jpg` (ImageMagick) or
`python3` + PIL `Image.open(...).crop((x0, y0, x1, y1))`. Both are installed
on this box.

## Gotchas

- `-r` hangs forever unattended — don't run it without a human at the mouse.
- `-a` is NOT a window capture on Wayland: `waylandScreenShot()` falls into the
  `default:` (fullscreen) case — there is no per-window path in the code.
  Verified: `screengrab -a -n` produces a 2880×1800 image.
- If a GUI instance is already running and `AllowCopies=false` in the config, a
  CLI call only forwards a message to that instance and writes nothing
  (`main.cpp` single-app check). Unset on this box ⇒ defaults true ⇒ fine.
- No `screenNN.jpg` appearing? Check `pgrep screengrab` and the configured
  `defDir` in `~/.config/screengrab/screengrab.conf` — it may not be `$HOME`.
- This skill captures the **live display only** — for driving the mouse/keyboard
  around before/after the capture, load `ydotool-gui`.
