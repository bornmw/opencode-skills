---
name: ydotool-gui
description: |
  Drive the on-screen GUI from the shell on this Wayland/Wayfire box: move the
  cursor, click, type, and screenshot via the `ydotool` client + `screengrab`
  — for headless QA of windows / decorations. Load for: "screenshot the
  desktop / what's on screen", "click that button", "move the mouse to X",
  "open a window and close it", "test the window manager", or any task that
  must drive or capture the live display. Do NOT load for mouse/keyboard
  driving when the `ydotoold` daemon is not running, for screenshots of files
  or web pages the user already has, or in headless environments with no
  display.
---

# ydotool GUI control

Move the mouse, click, type, and screenshot a Wayland/Wayfire desktop from the
shell, via the `ydotool` client and `screengrab`. Used for headless QA of GUIs
(e.g. window-manager decorations). No wrapper daemon beyond stock `ydotoold`.

## When to load

- The task must interact with the live display: move the cursor to a point,
  click a button, press keys, open a window, then verify the result by
  screenshot.
- "screenshot the desktop", "click that close button", "move the mouse", "open
  a test window and close it", "QA the window decorations".
- Not needed: pure headless/CLI work with no display interaction, or when
  `ydotoold` isn't running on this box.

## Multi-monitor — READ THIS FIRST on this box

This box has **three monitors in a non-trivial layout** (one rotated 270°):

```
$ scripts/cursor-pos --list
OUTPUT eDP-1 POS 2560 1440 LOGICAL 1440x900 PHYS 2880x1800 SCALE 2
OUTPUT DP-1 POS 1440 0 LOGICAL 2560x1440 PHYS 2560x1440 SCALE 1
OUTPUT DP-3 POS 4000 0 LOGICAL 1080x1920 PHYS 1080x1920 SCALE 1
```

Consequences that bite:

- **The same numeric coordinates exist on every monitor.** A blind move to
  "(160,120) and click" hits whatever output the cursor happens to be on —
  the same coordinates on a *different* monitor. Always target
  `(x, y, OUTPUT)`, not just `(x, y)`.
- `screengrab -f -n` captures the **active output**, not "the screen".
  Check the image size after each capture (`identify`) — if it isn't the size
  of the monitor you intended, the active output is somewhere else.
- **Wayfire updates the active output on CLICK, not on pointer movement**
  (see `src/core/seat/pointer.cpp` in the local wayfire tree). `cursor-pos`
  places its layer surface on the active output, so it can only report the
  cursor while the cursor is on that output — otherwise it hangs (wrap in
  `timeout`).
- Coordinate spaces: each output has local **logical** (scaled) coordinates.
  `cursor-pos` reports local logical + global virtual (physical px).

**The default move primitive is `scripts/goto.sh`** — it probes the exact
position, crosses to the target output if needed (moving to its center and
clicking to activate it), and closes the loop:

```
scripts/goto.sh TX TY [OUTPUT] [CLICK]
# TX,TY in the OUTPUT's local logical coords; OUTPUT e.g. DP-1, eDP-1, DP-3
# CLICK=1 clicks once on target
scripts/goto.sh 160 123 DP-1 1    # click the thing at DP-1 (160,123)
```

If the user is actively using the mouse (they say so, or the cursor teleports
between your probes), **stop moving it** — re-sync with a read-only
`cursor-pos` query first, and ask before cross-monitor moves.

## Prerequisites (one-time — check before the first move)

### 1. The daemon (run as root)

`ydotoold` must be running with a **user-owned** socket so the client works
without sudo and without new groups / udev rules:

```
ydotoold -o <uid>:<gid> -P 0660        # e.g. -o 1000:1000 -P 0660
```

- `-o <uid>:<gid>` — chown the socket to the GUI user (no `input` group, no
  udev detour; this is the whole point of the non-root model).
- `-P 0660` — socket mode so only the owner+group may connect.
- **Do NOT use `-T`**: broken in v1.0.4 (optstring `mkT` vs `case 'A'` →
  silent `exit 2`). v1.0.4 is the current release; the fix only exists on
  unreleased master.
- openrc: `/etc/init.d/ydotool` with `command_args="-o <uid>:<gid> -P 0660"`;
  persist with `sudo rc-update add ydotool default`.

Verify: `pgrep -a ydotoold` and `ls -l /tmp/.ydotool_socket` (must be owned by
the GUI user, `srw-rw----`).

### 2. Client env

```
export YDOTOOL_SOCKET=/tmp/.ydotool_socket
```

The client's default socket is `$XDG_RUNTIME_DIR/.ydotool_socket`, which does
**not** exist here — the daemon creates `/tmp/.ydotool_socket`. Verify with
`ydotool debug` (connects without sudo).

### 3. Screenshot tool

`screengrab -f -n` → newest `~/screenNN.jpg`. **It captures the active
output** — verify the size of the newest image (`identify`) before using it.
Pick the latest with `ls -t ~/screen*.jpg | head -1`.

- The cursor is only included if **"Include mouse pointer"** is ON (KConfig
  `includeCursor=true`; set it in the ScreenGrab GUI — do **not** hand-edit
  the config). Without it the pointer won't appear in captures.
- Wayfire `screencopy` **excludes** layer-shell overlays (menus) — verify
  overlays by the user's live view, not by the capture. Window content
  captures fine.
- `cursor-pos` also places a brief (≈1 s) transparent layer surface while it
  runs — it may flicker/focus-steal for a moment; it never moves the cursor.

### 4. The move model — input ≈ local logical pixels

Verified on this box (scale 1.0 and 2.0 outputs):

> **input delta ≈ delta in the target output's LOCAL LOGICAL pixels**
> (physical delta = logical × scale; the libinput DPI normalization of the
> uinput device cancels the scale factor).

Old note, superseded: the "~2.05 gain" was measured on eDP-1 (scale 2) as a
*physical* gain — `D/2.05` input for `D` physical px happens to equal `D/2`
logical px × ~1.0. On a scale-1 output that same formula was ~2× off. Use the
logical model.

- A **single large delta** still gets adaptive-accel amplification (~3.5×) →
  flies to a screen corner; always step (~10 px / 40–50 ms).
- `--absolute` is **broken** in v1.0.4 — never use it.
- The compositor clamps to the virtual screen bounds (crossing outputs is
  fine; corners are sticky — from a corner, one big move lands you in the
  virtual corner, not where you aimed).

`scripts/ymove.sh <dx> <dy>` sends a delta in small steps (its `GAIN` variable
is legacy information printout only — default move model is 1:1 logical).

## Cursor movement

```
scripts/goto.sh TX TY [OUTPUT] [CLICK]     # PREFERRED — verified closed loop
scripts/ymove.sh <dx> <dy>                 # low-level: raw input delta, steps
```

Never a single large delta, never `--absolute`. If the pointer isn't where you
expected, re-probe with `cursor-pos` and correct (goto.sh does this) — do not
fire a bigger single step.

## Clicks / keys

```
ydotool click 0xC0     # left button
ydotool click 0xC1     # right
ydotool click 0xC2     # middle
ydotool type "text"
ydotool key 56:1 108:1 108:0 56:0   # Alt+F4  (56=LeftAlt, 108=F4)
ydotool key 125:1 125:0             # Super (opens the wayfire menu)
```

## Cursor position (programmatic — preferred over screenshots)

```
scripts/cursor-pos             # CURSOR <x> <y> + ON <output> GLOBAL <x> <y>
scripts/cursor-pos --list      # all outputs: position, sizes, scale
```

`CURSOR` coordinates are **output-local logical**, corrected for workarea
shrinkage (top/left panels). If the cursor is not on the active output, the
tool blocks — use `timeout 5 scripts/cursor-pos` and treat no output as
"cursor is on a different monitor" (click the target monitor, retry).

Requirements: `wlr-randr` in PATH (output list), gcc + wayland-scanner (build,
one-time: `scripts/build-cursor-pos.sh`).

## Cursor location in a screenshot (fallback)

```
scripts/find_cursor.py <img> [roi_x0 roi_y0 roi_x1 roi_y1] [limit]
```

Prints an `ARROW: center=(x,y) ...` line for the best arrow-shaped candidate
(the usual pointer — signature bbox ~26×39, fill ~0.18) plus a ranked list of
compact bright blobs. Give a tight ROI around the expected location to stay
fast. **When the pointer hovers a clickable button it turns into a hand
pointer** — a clean on-target confirmation before you click.

## Open a test window (for QA)

```
DISPLAY=:1 nohup xterm -geometry 60x15+1500+400 -title "TEST" >/dev/null 2>&1 &
```

Save the PID. **Wayfire is click-to-focus: a new window does NOT auto-grab
focus** — an `Alt+F4` aimed at an unfocused window hits the currently focused
one instead. Click the target window's title bar first if you need it focused.

## Gotchas

- **Multi-monitor**: same coordinates on every output — always pass OUTPUT to
  `goto.sh`; check the `screengrab` image size (active output, not "the
  screen").
- **Active output changes on click** (wayfire): after any click, the
  cursor-pos surface and screengrab follow that output.
- New windows don't auto-grab focus (click-to-focus) — see above.
- `screengrab` CLI has no cursor flag; `includeCursor` is a KConfig entry set
  via the GUI checkbox.
- Restart the daemon after boot: `sudo rc-update add ydotool default`, then
  `sudo rc-service ydotool start` (or reboot).
- The user may move the mouse at any time — treat a "GOTO-FAIL lost
  position" or a teleporting probe as "re-sync", not as a bug to brute-force.
