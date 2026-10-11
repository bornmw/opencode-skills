---
name: ydotool-gui
description: |
  Drive the on-screen GUI from the shell on this Wayland/Wayfire box: move the
  cursor, click, type, and screenshot via the `ydotool` client + `screengrab` —
  for headless QA of windows / decorations. Load for: "screenshot the desktop /
  what's on screen", "click that button", "move the mouse to X", "open a window
  and close it", "test the window manager", or any task that must drive or
  capture the live display. Do NOT load for pure headless / CLI work with no
  display interaction, or when the `ydotoold` daemon is not running on the box.
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
- **Do NOT use `-T`**: broken in v1.0.4 (optstring `mkT` vs `case 'A'` → silent
  `exit 2`). v1.0.4 is the current release; the fix only exists on unreleased
  master.
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

`screengrab -f -n` → newest `~/screenNN.jpg` (2880×1800 on this box). Pick the
latest with `ls -t ~/screen*.jpg | head -1`.

- The cursor is only included if **"Include mouse pointer"** is ON (KConfig
  `includeCursor=true`; set it in the ScreenGrab GUI — do **not** hand-edit the
  config). Without it the pointer won't appear in captures.
- Wayfire `screencopy` **excludes** layer-shell overlays (menus) — verify
  overlays by the user's live view, not by the capture. Window content captures
  fine.

### 4. The gain factor — THE key thing

libinput assumes the `ydotoold` virtual device is ~488 DPI, so it scales
**every** relative delta by a constant **~2.05** (measured: `+200 → +413`).
On top of that:

- a **single large delta** gets extra adaptive-accel amplification (~3.5×) →
  flies to a screen corner;
- `--absolute` (the INT32_MIN hack) is **broken** in v1.0.4 → bottom-right corner;
- signs are preserved (no flip); the compositor clamps to screen bounds.

**To move the pointer by `D` pixels, send `D / 2.05` in ~10px steps, ~50ms
apart** (keeps the accel factor at 1.0). `scripts/ymove.sh` does exactly this.

The gain is **machine-specific** (depends on libinput's assumed DPI for the
uinput device). Recalibrate by: park the cursor, capture a baseline, run
`ymove.sh <dx> <dy>`, capture again, measure both with `find_cursor.py`, then
`gain = (end - start) / (dx, dy)` and set `GAIN=...` in the `ymove.sh` env.

## Cursor movement

```
scripts/ymove.sh <input_dx> <input_dy>    # pass D / GAIN; steps ~10px @ 50ms
```

Never a single large delta, never `--absolute`. If the pointer isn't where you
expected, re-measure and correct (see closed-loop below) — do not fire a bigger
single step.

## Clicks / keys

```
ydotool click 0xC0     # left button
ydotool click 0xC1     # right
ydotool click 0xC2     # middle
ydotool type "text"
ydotool key 56:1 108:1 108:0 56:0   # Alt+F4  (56=LeftAlt, 108=F4)
ydotool key 125:1 125:0             # Super (opens the wayfire menu)
```

## Cursor location in a screenshot

```
scripts/find_cursor.py <img> [roi_x0 roi_y0 roi_x1 roi_y1] [limit]
```

Prints an `ARROW: center=(x,y) ...` line for the best arrow-shaped candidate
(the usual pointer — signature bbox ~26×39, fill ~0.18) plus a ranked list of
compact bright blobs. Give a tight ROI around the expected location to stay
fast. **When the pointer hovers a clickable button it turns into a hand
pointer** — a clean on-target confirmation before you click.

## Closed-loop move — the default approach

1. `screengrab -f -n`; copy the newest `~/screen*.jpg`.
2. `find_cursor.py <img>` → current `(x,y)`.
3. `input delta = (target - current) / GAIN`.
4. `ymove.sh <input_dx> <input_dy>`.
5. `screengrab` + `find_cursor.py` again; if off by `R`, run
   `ymove.sh <R_x/GAIN> <R_y/GAIN>`.
6. Verify on-target (zoom crop of the region / hand cursor), then click.

## Open a test window (for QA)

```
DISPLAY=:1 nohup xterm -geometry 60x15+1500+400 -title "TEST" >/dev/null 2>&1 &
```

Save the PID. **Wayfire is click-to-focus: a new window does NOT auto-grab
focus** — an `Alt+F4` aimed at an unfocused window hits the currently focused
one instead. Click the target window's title bar first if you need it focused.

## Gotchas

- New windows don't auto-grab focus (click-to-focus) — see above.
- `screengrab` CLI has no cursor flag; `includeCursor` is a KConfig entry set
  via the GUI checkbox.
- Restart the daemon after boot: `sudo rc-update add ydotool default`, then
  `sudo rc-service ydotool start` (or reboot).
- The `×2.05` gain is calibrated to this box — if the pointer lands consistently
  off by a factor, re-run the recalibration step.
