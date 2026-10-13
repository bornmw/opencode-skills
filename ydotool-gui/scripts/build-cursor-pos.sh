#!/usr/bin/env bash
# build-cursor-pos.sh — compile cursor-pos.c into ./cursor-pos (next to this
# script). Needs: gcc, wayland-scanner, libwayland-client dev headers.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

WLP="/usr/share/wayland-protocols"
mkdir -p gen
wayland-scanner client-header "$WLP/stable/xdg-shell/xdg-shell.xml" gen/xdg-shell.h
wayland-scanner public-code  "$WLP/stable/xdg-shell/xdg-shell.xml" gen/xdg-shell.c
wayland-scanner client-header "protocols/wlr-layer-shell-unstable-v1.xml" gen/wlr-layer-shell-unstable-v1.h
wayland-scanner public-code  "protocols/wlr-layer-shell-unstable-v1.xml" gen/wlr-layer-shell-unstable-v1.c

gcc -O2 -o cursor-pos cursor-pos.c gen/xdg-shell.c gen/wlr-layer-shell-unstable-v1.c -Igen -lwayland-client
echo "built: $HERE/cursor-pos"
