# screengrab

An [opencode](https://opencode.ai) skill for creating **screenshots of the live
display** on this Wayland/Wayfire box, via the stock `screengrab` (lxqt) CLI.

- capture the full screen in ~0.1 s, saved to `~/screenNN.jpg`,
- crop a region out of the capture (the CLI's `-r` is interactive-only),
- know exactly what is and isn't in the image (layer-shell overlays and the
  mouse pointer are config/compositor-dependent).

Everything is grounded in the [lxqt/screengrab](https://github.com/lxqt/screengrab)
source (3.1.0) plus live verification on this box. No wrapper daemon — only a
running display.

## Install

```bash
bash screengrab/install.sh
```

This copies the skill (SKILL.md + `scripts/snap.sh`) to
`~/.config/opencode/skills/screengrab/` and checks dependencies.

## Prerequisites

- `screengrab` (Gentoo: `emerge kde-apps/screengrab`)
- `convert` (ImageMagick) for `snap.sh` crop mode
- A running Wayland session — captures go through the
  `zwlr_screencopy_manager_v1` (ext-screencopy) protocol, so the compositor
  must provide it (wayfire does)

The pointer is included in captures only when "Include mouse pointer" is ON
in the screengrab GUI (`Base.includeCursor`; it is ON on this box).

## Usage in opencode

Once installed, asking for a screenshot loads the skill automatically.
Examples:

- "create a screenshot of the desktop"
- "take a screenshot and show me what's on screen"
- "screenshot the region around the window title bar"
- "grab the screen, then crop out the menu"

The skill is advertised from a short `description` (loading only the summary
into context); the full instructions and script load only when the skill is
invoked.

## The key facts (why the skill documents them)

- `screengrab -f -n` is the unattended pattern: fullscreen, save + exit, no
  window. `-n` acts on the first screenshot only; the process exits after.
- No `--output` flag: the name is `defDir` + `defFilename` + per-process
  counter → `~/screen.jpg`, `~/screen01.jpg`, … Pick the result with
  `ls -t ~/screen*.jpg | head -1`.
- This box's binary defaults to **jpg** (upstream source defaults to png —
  packaged build differs).
- On Wayland, `-a` (active window) silently falls back to fullscreen — there
  is no per-window code path.
- Layer-shell overlays (wayfire menus) are **not** in the capture; the mouse
  pointer only when `includeCursor` is set.
- `-r` (region) blocks on interactive mouse input — use `snap.sh x0 y0 x1 y1`
  (full capture + ImageMagick crop) instead.
