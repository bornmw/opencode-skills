#!/usr/bin/env bash
# ymove.sh <input_dx> <input_dy>
#
# Move the pointer by an INPUT delta in small constant-velocity steps (~10px per
# 50ms) so libinput's adaptive-accel factor stays ~1.0. A single large delta gets
# amplified ~3.5x and flies to a screen corner — never do that.
#
# The pointer moves by input × GAIN pixels on this box (GAIN defaults to 2.05, the
# calibrated DPI-normalization factor). So to move the pointer by D pixels, pass
# D / GAIN. Override with GAIN=... if you recalibrated.
#
#   ymove.sh 604 -54        # moves the pointer ~(+1238,-111) at GAIN 2.05
set -euo pipefail

export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"
GAIN="${GAIN:-2.05}"

python3 - "$1" "$2" "$GAIN" <<'PY'
import sys, subprocess, time
dx = int(sys.argv[1]); dy = int(sys.argv[2]); gain = float(sys.argv[3])
if dx == 0 and dy == 0:
    print("no move"); sys.exit(0)
N = max(abs(dx), abs(dy)) // 10 + 1
N = max(N, 1)
sx = round(dx / N); sy = round(dy / N)
for _ in range(N):
    subprocess.run(["ydotool", "mousemove", "-x", str(sx), "-y", str(sy)], check=False)
    time.sleep(0.05)
print(f"steps={N} step=({sx},{sy}) input_total=({sx*N},{sy*N}) "
      f"expected_actual(gain {gain})=({sx*N*gain:.0f},{sy*N*gain:.0f})")
PY
