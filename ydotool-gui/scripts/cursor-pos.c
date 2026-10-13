/*
 * cursor-pos — programmatic cursor position on Wayland (wayfire).
 *
 * Why this exists: Wayland has no global "cursor position" query API, and
 * pixel-detection on screenshots is theme-dependent. This tool creates a
 * transparent fullscreen above-layer surface on the compositor's ACTIVE
 * output and reports the pointer position in that output's local (logical,
 * scaled) coordinates, plus the output name and global virtual position.
 *
 * Output info comes from the `wlr-randr` CLI (wlr-output-management
 * protocol) — reliable on this box, where zxdg_output events do not arrive.
 *
 * Wayfire quirk (verified in src/core/seat/pointer.cpp): the active output is
 * only updated on POINTER BUTTON PRESS, not on movement. So to query the
 * cursor while it is on output X, CLICK on X first (the layer surface is
 * placed on the active output at map time).
 *
 * Output:
 *   --list:
 *     OUTPUT <name> POS <x> <y> LOGICAL <w>x<h> PHYS <w>x<h> SCALE <s>
 *     (POS = virtual position in physical px; LOGICAL = scaled size)
 *   query (default):
 *     CURSOR <x> <y> SURFACE <w>x<h>          (local logical coords)
 *     ON <name> GLOBAL <gx> <gy> SCALE <s>    (only if the surface's output
 *                                              is uniquely identified by
 *                                              logical size; GLOBAL = virtual
 *                                              px)
 *
 * Exit codes: 0 with position; 1 incomplete; 2 on failure.
 * If the cursor is not on the active output, no pointer events arrive — the
 * process blocks; wrap with `timeout 5 cursor-pos`.
 *
 * Build: build-cursor-pos.sh (wayland-scanner + gcc, -lwayland-client).
 * Requires: wlr-randr in PATH.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <wayland-client.h>
#include "wlr-layer-shell-unstable-v1.h"

#define MAX_OUTPUTS 16

struct output_info {
    char name[64];
    int x, y; /* virtual position (physical px) */
    int logical_w, logical_h;
    int phys_w, phys_h; /* current mode, effective (post-transform) */
    int scale;
    int transform; /* 1 = 90/270 rotation */
};

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wl_seat *seat;
static struct wl_pointer *pointer;
static struct wl_shm *shm;

static struct output_info outputs[MAX_OUTPUTS];
static int n_outputs;

static struct wl_surface *surface;
static struct zwlr_layer_surface_v1 *layer_surface;
static struct wl_buffer *buffer;

static int surf_w = 0, surf_h = 0;
static int pos_x = 0, pos_y = 0;
static int have_pos = 0;
static int list_only = 0;

/* ── wlr-randr parsing ────────────────────────────────────────────────────── */

static void finalize_outputs(void)
{
    for (int i = 0; i < n_outputs; i++)
    {
        struct output_info *o = &outputs[i];
        if (o->transform)
        {
            int t = o->phys_w;
            o->phys_w = o->phys_h;
            o->phys_h = t;
        }
        o->logical_w = o->phys_w / o->scale;
        o->logical_h = o->phys_h / o->scale;
    }
}

static int parse_wlrrandr(void)
{
    FILE *f = popen("wlr-randr 2>/dev/null", "r");
    if (!f)
        return -1;
    char line[512];
    int in_modes = 0;
    while (fgets(line, sizeof(line), f))
    {
        if (line[0] != ' ' && line[0] != '\n' && line[0] != '\0' &&
            strchr(line, '"') != NULL)
        {
            /* new output block: Name "description..." (names may start
             * lowercase, e.g. eDP-1) */
            if (n_outputs < MAX_OUTPUTS)
            {
                struct output_info *o = &outputs[n_outputs++];
                memset(o, 0, sizeof(*o));
                sscanf(line, "%63s", o->name);
                o->scale = 1;
            }
            in_modes = 0;
        }
        else if (n_outputs > 0)
        {
            struct output_info *o = &outputs[n_outputs - 1];
            int x, y, w, h;
            float scale;
            char tf[32];
            if (sscanf(line, "  Position: %d,%d", &x, &y) == 2)
            {
                o->x = x;
                o->y = y;
            }
            else if (sscanf(line, "  Scale: %f", &scale) == 1)
            {
                o->scale = scale > 0.5 ? (int)(scale + 0.5) : 1;
            }
            else if (sscanf(line, "  Transform: %31s", tf) == 1)
            {
                o->transform = 0;
                if (strcmp(tf, "90") == 0 || strcmp(tf, "270") == 0)
                    o->transform = 1;
            }
            else if (strncmp(line, "  Modes:", 8) == 0)
            {
                in_modes = 1;
            }
            else if (in_modes && strstr(line, "current") &&
                     sscanf(line, "    %dx%d px", &w, &h) == 2)
            {
                /* raw current mode; effective size + logical size are
                 * computed in finalize_outputs() (Scale/Transform lines
                 * come after Modes in the output) */
                o->phys_w = w;
                o->phys_h = h;
            }
        }
    }
    pclose(f);
    return n_outputs;
}

/* ── pointer ──────────────────────────────────────────────────────────────── */

static void pointer_enter(void *data, struct wl_pointer *p, uint32_t serial,
                          struct wl_surface *s, wl_fixed_t x, wl_fixed_t y)
{
    (void)data;
    (void)p;
    (void)serial;
    (void)s;
    pos_x = wl_fixed_to_int(x);
    pos_y = wl_fixed_to_int(y);
    have_pos = 1;
}

static void pointer_motion(void *data, struct wl_pointer *p, uint32_t t,
                           wl_fixed_t x, wl_fixed_t y)
{
    (void)data;
    (void)p;
    (void)t;
    pos_x = wl_fixed_to_int(x);
    pos_y = wl_fixed_to_int(y);
    have_pos = 1;
}

static void pn_frame(void *data, struct wl_pointer *p)
{
    (void)data;
    (void)p;
}

static void pn_leave(void *data, struct wl_pointer *p, uint32_t serial,
                     struct wl_surface *s)
{
    (void)data;
    (void)p;
    (void)serial;
    (void)s;
}

static void pn_button(void *data, struct wl_pointer *p, uint32_t time,
                      uint32_t serial, uint32_t button, uint32_t state)
{
    (void)data;
    (void)p;
    (void)time;
    (void)serial;
    (void)button;
    (void)state;
}

static void pn_axis(void *data, struct wl_pointer *p, uint32_t time,
                    uint32_t axis, wl_fixed_t value)
{
    (void)data;
    (void)p;
    (void)time;
    (void)axis;
    (void)value;
}

static void pn_axis_source(void *data, struct wl_pointer *p, uint32_t source)
{
    (void)data;
    (void)p;
    (void)source;
}

static void pn_axis_stop(void *data, struct wl_pointer *p, uint32_t time,
                         uint32_t axis)
{
    (void)data;
    (void)p;
    (void)time;
    (void)axis;
}

static void pn_axis_discrete(void *data, struct wl_pointer *p, uint32_t axis,
                             int32_t discrete)
{
    (void)data;
    (void)p;
    (void)axis;
    (void)discrete;
}

static void pn_axis_value120(void *data, struct wl_pointer *p, uint32_t axis,
                             int32_t value120)
{
    (void)data;
    (void)p;
    (void)axis;
    (void)value120;
}

static void pn_axis_rel_dir(void *data, struct wl_pointer *p, uint32_t axis,
                            uint32_t direction)
{
    (void)data;
    (void)p;
    (void)axis;
    (void)direction;
}

static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pn_leave,
    .motion = pointer_motion,
    .button = pn_button,
    .axis = pn_axis,
    .frame = pn_frame,
    .axis_source = pn_axis_source,
    .axis_stop = pn_axis_stop,
    .axis_discrete = pn_axis_discrete,
    .axis_value120 = pn_axis_value120,
    .axis_relative_direction = pn_axis_rel_dir,
};

static void seat_handle_capabilities(void *data, struct wl_seat *s,
                                     uint32_t caps)
{
    (void)data;
    if (caps & WL_SEAT_CAPABILITY_POINTER)
    {
        if (pointer)
            wl_pointer_destroy(pointer);
        pointer = wl_seat_get_pointer(s);
        wl_pointer_add_listener(pointer, &pointer_listener, NULL);
    }
}

static void seat_handle_name(void *data, struct wl_seat *s, const char *name)
{
    (void)data;
    (void)s;
    (void)name;
}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_handle_capabilities,
    .name = seat_handle_name,
};

/* ── layer surface / buffer ───────────────────────────────────────────────── */

static int make_buffer(int w, int h)
{
    int size = w * h * 4;
    int fd = memfd_create("cursor-pos", 0);
    if (fd < 0)
        return -1;
    if (ftruncate(fd, size) < 0)
    {
        close(fd);
        return -1;
    }
    void *map = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED)
    {
        close(fd);
        return -1;
    }
    memset(map, 0, size); /* fully transparent */

    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
    buffer = wl_shm_pool_create_buffer(pool, 0, w, h, w * 4,
                                       WL_SHM_FORMAT_ARGB8888);
    close(fd);
    munmap(map, size);
    return buffer ? 0 : -1;
}

static void layer_handle_configure(void *data,
                                   struct zwlr_layer_surface_v1 *ls,
                                   uint32_t serial, uint32_t w, uint32_t h)
{
    (void)data;
    surf_w = (int)w;
    surf_h = (int)h;
    zwlr_layer_surface_v1_ack_configure(ls, serial);
    if (surf_w > 0 && surf_h > 0 && !buffer)
    {
        if (make_buffer(surf_w, surf_h) < 0)
        {
            fprintf(stderr, "cursor-pos: buffer allocation failed\n");
            exit(2);
        }
        wl_surface_attach(surface, buffer, 0, 0);
    }
    wl_surface_damage(surface, 0, 0, surf_w, surf_h);
    wl_surface_commit(surface);
}

static void layer_handle_closed(void *data, struct zwlr_layer_surface_v1 *ls)
{
    (void)data;
    (void)ls;
}

static const struct zwlr_layer_surface_v1_listener layer_listener = {
    .configure = layer_handle_configure,
    .closed = layer_handle_closed,
};

/* ── registry ─────────────────────────────────────────────────────────────── */

static void registry_handle_global(void *data, struct wl_registry *reg,
                                   uint32_t id, const char *iface,
                                   uint32_t ver)
{
    (void)data;
    if (strcmp(iface, "zwlr_layer_shell_v1") == 0)
    {
        layer_shell =
            wl_registry_bind(reg, id, &zwlr_layer_shell_v1_interface, 1);
    }
    else if (strcmp(iface, "wl_seat") == 0)
    {
        seat = wl_registry_bind(reg, id, &wl_seat_interface,
                                ver < 5 ? ver : 5);
        wl_seat_add_listener(seat, &seat_listener, NULL);
    }
    else if (strcmp(iface, "wl_compositor") == 0)
    {
        compositor =
            wl_registry_bind(reg, id, &wl_compositor_interface,
                             ver < 4 ? ver : 4);
    }
    else if (strcmp(iface, "wl_shm") == 0)
    {
        shm = wl_registry_bind(reg, id, &wl_shm_interface, 1);
    }
}

static void registry_handle_global_remove(void *data, struct wl_registry *reg,
                                          uint32_t id)
{
    (void)data;
    (void)reg;
    (void)id;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

/* ── helpers ──────────────────────────────────────────────────────────────── */

static int find_output_by_size(int w, int h, int *ambig)
{
    int match = -1, count = 0;
    for (int i = 0; i < n_outputs; i++)
        if (outputs[i].name[0] && outputs[i].logical_w == w &&
            outputs[i].logical_h == h)
        {
            match = i;
            count++;
        }
    *ambig = count > 1;
    return match;
}

static void print_list(void)
{
    for (int i = 0; i < n_outputs; i++)
        printf("OUTPUT %s POS %d %d LOGICAL %dx%d PHYS %dx%d SCALE %d\n",
               outputs[i].name, outputs[i].x, outputs[i].y,
               outputs[i].logical_w, outputs[i].logical_h,
               outputs[i].phys_w, outputs[i].phys_h, outputs[i].scale);
}

int main(int argc, char **argv)
{
    list_only = argc > 1 && strcmp(argv[1], "--list") == 0;

    if (parse_wlrrandr() <= 0)
    {
        fprintf(stderr, "cursor-pos: wlr-randr parsing failed\n");
        return 2;
    }
    finalize_outputs();
    if (list_only)
    {
        print_list();
        return 0;
    }

    display = wl_display_connect(NULL);
    if (!display)
    {
        fprintf(stderr, "cursor-pos: cannot connect to Wayland display\n");
        return 2;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!layer_shell || !compositor || !shm)
    {
        fprintf(stderr, "cursor-pos: required globals not available\n");
        return 1;
    }

    surface = wl_compositor_create_surface(compositor);
    layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        layer_shell, surface, NULL, ZWLR_LAYER_SHELL_V1_LAYER_TOP,
        "cursor-pos");
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, 0);
    zwlr_layer_surface_v1_add_listener(layer_surface, &layer_listener, NULL);
    zwlr_layer_surface_v1_set_anchor(
        layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
            ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    wl_surface_commit(surface);

    /* Event loop. */
    for (;;)
    {
        if (have_pos)
        {
            /* The above-layer surface is anchored to the WORKAREA: reserved
             * areas (panels) shrink it from the output's logical size. With
             * the default top/left panel placement, local surface coords are
             * offset from output coords by (logical - surface). Correct that
             * so the reported position is in OUTPUT local coordinates. */
            int ambig = 0;
            int m = find_output_by_size(surf_w, surf_h, &ambig);
            int ox = pos_x, oy = pos_y;
            if (m >= 0 && !ambig)
            {
                ox = pos_x + (outputs[m].logical_w - surf_w);
                oy = pos_y + (outputs[m].logical_h - surf_h);
            }
            printf("CURSOR %d %d SURFACE %dx%d\n", ox, oy, surf_w, surf_h);
            if (m >= 0 && !ambig)
            {
                int gx = outputs[m].x + ox * outputs[m].scale;
                int gy = outputs[m].y + oy * outputs[m].scale;
                printf("ON %s GLOBAL %d %d SCALE %d\n", outputs[m].name, gx,
                       gy, outputs[m].scale);
            }
            return 0;
        }
        if (wl_display_dispatch(display) < 0)
            break;
    }
    return 1;
}
