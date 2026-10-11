#!/usr/bin/env python3
"""Locate the pointer cursor in a desktop screenshot.

Usage: find_cursor.py <image> [roi_x0 roi_y0 roi_x1 y1] [limit]

Flood-fills bright pixels into compact blobs and scores them. Prints:
  - an `ARROW: center=(x,y) ...` line for the best arrow-shaped candidate (the
    usual pointer), if one is found, and
  - a ranked list of the top `limit` compact bright blobs (default 12).

The arrow signature on a light-on-dark desktop is roughly bbox 20-35 x 28-45,
low fill (~0.15-0.25). When the pointer hovers a clickable button it becomes a
hand pointer (solid, high fill) — a good on-target confirmation.
"""
import sys
from collections import deque
from PIL import Image


def main():
    img = sys.argv[1]
    if len(sys.argv) >= 5:
        x0, y0, x1, y1 = map(int, sys.argv[2:6])
    else:
        x0, y0, x1, y1 = 0, 0, None, None
    limit = int(sys.argv[6]) if len(sys.argv) > 6 else 12

    im = Image.open(img).convert("L")
    W, H = im.size
    x1 = x1 or W
    y1 = y1 or H
    px = im.load()

    bright = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y] >= 225:
                bright.add((x, y))

    seen = set()
    blobs = []
    for seed in bright:
        if seed in seen:
            continue
        q = deque([seed]); seen.add(seed); comp = []
        minx = maxx = seed[0]; miny = maxy = seed[1]
        while q:
            cx, cy = q.popleft(); comp.append((cx, cy))
            if cx < minx: minx = cx
            if cx > maxx: maxx = cx
            if cy < miny: miny = cy
            if cy > maxy: maxy = cy
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (cx + dx, cy + dy)
                    if n in bright and n not in seen:
                        seen.add(n); q.append(n)
        size = len(comp)
        bw = maxx - minx + 1
        bh = maxy - miny + 1
        if 6 <= bw <= 70 and 8 <= bh <= 80 and size >= 30:
            fill = size / (bw * bh)
            cx = (minx + maxx) / 2.0
            cy = (miny + maxy) / 2.0

            # general "compact blob" score
            score = min(fill, 1.0) * 50
            if 0.5 <= bw / bh <= 1.6:
                score += 30
            if 100 <= size <= 600:
                score += 20

            # arrow-likeness: low fill, taller-than-wide, arrow size
            arrow = 0.0
            if 0.10 <= fill <= 0.30 and 1.1 <= bh / bw <= 2.0 and 80 <= size <= 400 \
                    and 16 <= bw <= 40 and 26 <= bh <= 52:
                arrow = (0.20 - abs(fill - 0.18)) * 100 \
                        + max(0.0, 1.4 - abs(bh / bw - 1.45)) * 30
            blobs.append((score + arrow, arrow, size, int(cx), int(cy), bw, bh, round(fill, 2)))

    blobs.sort(reverse=True)
    print(f"# {img} ROI=({x0},{y0})-({x1},{y1}) bright_px={len(bright)} candidates={len(blobs)}")

    best = next((b for b in blobs if b[1] > 0), None)
    if best:
        _, _, size, cx, cy, bw, bh, fr = best
        print(f"ARROW: center=({cx},{cy}) size={size} bbox={bw}x{bh} fill={fr}")

    for score, _, size, cx, cy, bw, bh, fr in blobs[:limit]:
        print(f"  score={score:6.1f} size={size:4d} center=({cx:4d},{cy:4d}) bbox={bw}x{bh} fill={fr}")


if __name__ == "__main__":
    main()
