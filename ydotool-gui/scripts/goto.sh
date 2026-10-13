#!/usr/bin/env bash
# goto.sh TX TY [OUTPUT] [CLICK]
#
# Move the cursor to (TX,TY) — LOCAL LOGICAL coordinates on OUTPUT — with a
# verified closed loop, then optionally click.
#
#   TX TY      target in the target output's local logical (scaled) coords
#   OUTPUT     target output name (e.g. DP-1, eDP-1). If omitted, the target
#              is assumed to be on the output the cursor is currently on.
#   CLICK      "1" = click once when on target.
#
# Why it exists: on multi-monitor boxes the same numeric coordinates exist on
# several outputs; a blind move+click can land on the wrong monitor. This
# script (1) probes the exact current position+output with cursor-pos,
# (2) if needed moves to the target output's center and CLICKS there to make
# it the active output (wayfire updates the active output on button press,
# not on move), (3) closes the loop in small steps.
#
# Move model: on this box, input delta ≈ delta in the output's LOCAL LOGICAL
# pixels (the libinput DPI normalization cancels the scale factor). Verified
# on scale 1.0 and 2.0 outputs.
set -uo pipefail

export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CP="$SKILL_DIR/cursor-pos"

TX="${1:?usage: goto.sh TX TY [OUTPUT] [CLICK]}"
TY="${2:?usage: goto.sh TX TY [OUTPUT] [CLICK]}"
OUTPUT="${3:-}"
DOCLICK="${4:-0}"

[ -x "$CP" ] || { echo "GOTO-FAIL cursor-pos not built (run build-cursor-pos.sh)"; exit 1; }

probe() { timeout 5 "$CP" 2>/dev/null; }

pos=$(probe)
if [ -z "$pos" ]; then
    echo "GOTO-FAIL no position (cursor not on active output — click the target output first, then retry)"
    exit 1
fi

on_line=$(echo "$pos" | grep '^ON ' || true)
cur_out=$(echo "$on_line" | awk '{print $2}')
cur_scale=1
[ -n "$cur_out" ] && cur_scale=$(echo "$on_line" | awk '{print $7}')
# current local + global (global only present on the ON line)
read -r _ ex ey _ _ _ <<<"$pos"

# ── If the target output is known and we are not on it: cross over + click ──
if [ -n "$OUTPUT" ] && [ "$cur_out" != "$OUTPUT" ]; then
    list=$(timeout 5 "$CP" --list 2>/dev/null)
    row=$(echo "$list" | awk -v n="$OUTPUT" '$2==n {print; exit}')
    if [ -z "$row" ]; then
        echo "GOTO-FAIL output '$OUTPUT' not in: $(echo "$list" | awk '{print $2}' | tr '\n' ' ')"
        exit 1
    fi
    # row: OUTPUT <name> POS <x> <y> LOGICAL <w>x<h> PHYS <w>x<h> SCALE <s>
    read -r _ _ _ cx cy _ lsize _ _ _ sc <<<"$row"
    lw=${lsize%x*}; lh=${lsize#*x}
    gcx=$(( cx + (lw / 2) * sc ))
    gcy=$(( cy + (lh / 2) * sc ))

    if [ -n "$cur_out" ]; then
        cgx=$(echo "$on_line" | awk '{print $4}')
        cgy=$(echo "$on_line" | awk '{print $5}')
    else
        # position known but output not identified: fall back to local×scale
        cgx=$(( ex * cur_scale )); cgy=$(( ey * cur_scale ))
    fi
    # global delta → input on the current output (input = global/scale)
    dxin=$(( (gcx - cgx) / cur_scale ))
    dyin=$(( (gcy - cgy) / cur_scale ))
    N=$(( (dxin > 0 ? dxin : -dxin) / 8 + 1 ))
    M=$(( (dyin > 0 ? dyin : -dyin) / 8 + 1 ))
    [ "$M" -gt "$N" ] && N=$M
    sx=$(( dxin / N )); sy=$(( dyin / N ))
    for _ in $(seq 1 "$N"); do
        ydotool mousemove -x "$sx" -y "$sy" >/dev/null 2>&1
        sleep 0.04
    done
    sleep 0.5
    ydotool click 0xC0 >/dev/null 2>&1   # activate the target output
    sleep 0.5
    pos=$(probe)
    if [ -z "$pos" ]; then
        echo "GOTO-FAIL could not place cursor on '$OUTPUT' (verify its position with cursor-pos --list)"
        exit 1
    fi
fi

# ── Closed loop (max 4 passes) ───────────────────────────────────────────────
for i in 1 2 3 4; do
    read -r _ ex ey _ _ _ <<<"$pos"
    dx=$(( TX - ex )); dy=$(( TY - ey ))
    adx=${dx#-}; ady=${dy#-}
    if [ "$adx" -le 4 ] && [ "$ady" -le 4 ]; then
        if [ "$DOCLICK" = "1" ]; then
            ydotool click 0xC0 >/dev/null 2>&1
            echo "GOTO-CLICKED at $ex $ey (pass $i${OUTPUT:+ on $OUTPUT})"
        else
            echo "GOTO-OK at $ex $ey (pass $i${OUTPUT:+ on $OUTPUT})"
        fi
        exit 0
    fi
    # small steps: input = local-logical delta (verified ~1:1 on this box)
    N=$(( (dx > 0 ? dx : -dx) / 8 + 1 ))
    M=$(( (dy > 0 ? dy : -dy) / 8 + 1 ))
    [ "$M" -gt "$N" ] && N=$M
    sx=$(( dx / N )); sy=$(( dy / N ))
    for _ in $(seq 1 "$N"); do
        ydotool mousemove -x "$sx" -y "$sy" >/dev/null 2>&1
        sleep 0.04
    done
    sleep 0.3
    pos=$(probe)
    if [ -z "$pos" ]; then
        echo "GOTO-FAIL lost position during move (crossed outputs? click the target output and retry)"
        exit 1
    fi
done
echo "GOTO-FAIL at $ex $ey (target $TX $TY${OUTPUT:+ on $OUTPUT})"
exit 1
