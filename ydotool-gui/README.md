# ydotool-gui

An [opencode](https://opencode.ai) skill for driving a **Wayland / Wayfire**
desktop from the shell — for headless QA of GUIs (window managers, decorations,
menus, buttons).

It wraps the stock `ydotool` client + `screengrab`:

- move the cursor to a point (with the box's pointer-gain compensated),
- click / type / press keys,
- screenshot the desktop and locate the cursor in it.

Two bundled helper scripts (`scripts/`) do the gain-compensated small-step move
and the cursor-in-screenshot detection. No wrapper daemon beyond `ydotoold`.

## Install

```bash
bash ydotool-gui/install.sh
```

This copies the skill (SKILL.md + `scripts/`) to
`~/.config/opencode/skills/ydotool-gui/` and checks dependencies.

## Prerequisites

All one-time setup. The daemon must run as **root** so it can open the
`uinput` device; the socket is then made user-owned so the client needs no sudo
and no new groups / udev rules.

- `ydotool` v1.0.4 (Gentoo: `emerge app-misc/ydotool`)
- `screengrab` (KDE) for screenshots, with **"Include mouse pointer"** enabled
- `python3` + `PIL` (`python3 -c "import PIL"`) for `find_cursor.py`
- The GUI user's uid/gid (e.g. `1000:1000`) for the daemon's `-o` flag

### The daemon — command-line parameter changes

`ydotoold` is normally started by an openrc init script. Set:

```
command_args="-o 1000:1000 -P 0660"
```

in `/etc/init.d/ydotool`, then:

```bash
sudo rc-service ydotool restart
sudo rc-update add ydotool default          # start on boot
```

- `-o 1000:1000` — chown the socket to the GUI user (uid:gid). This is what lets
  the client connect **without sudo and without an `input` group**.
- `-P 0660` — socket mode so only owner+group can connect.
- **Do NOT add `-T`** — it is broken in v1.0.4 (optstring `mkT` vs `case 'A'` →
  silent `exit 2`). Drop it if an old script has it.
- The daemon creates `/tmp/.ydotool_socket`.

The client then needs:

```bash
export YDOTOOL_SOCKET=/tmp/.ydotool_socket   # client default doesn't exist here
ydotool debug                                 # should connect without sudo
```

## The pointer-gain quirk (why the skill exists)

libinput assumes the virtual device is ~488 DPI, so it scales **every** relative
delta by a constant **~2.05**, and a single large delta gets extra adaptive
acceleration (~3.5×) that flings the cursor to a corner. `--absolute` is broken
in v1.0.4. The skill's move recipe compensates: to move `D` pixels, send
`D / 2.05` in ~10px steps ~50 ms apart (`scripts/ymove.sh`). The gain is
machine-specific — the skill documents a recalibration step if it drifts.

## Usage in opencode

Once installed, mention driving the display and the skill loads automatically.
Examples:

- "screenshot the desktop"
- "move the mouse to the close button of the xterm and click it"
- "open a test window, screenshot, then close it"
- "QA the window decorations — click the minimize button and verify"
- "where is the cursor right now?"

The skill is advertised from a short `description` (loading only the summary
into context); the full instructions and scripts load only when the skill is
invoked.
