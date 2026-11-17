/* ACGame's platform on the host, for tests/host/test_all.sh: the game runs
 * on acsdl12 exactly as on the Amiga, down to ACGame's indexed frame and
 * its palette, and only this file stands in for the Amiga's screen,
 * keyboard and mouse.
 *
 * ACG_SCRIPT names a script, one step a line, at milliseconds from start:
 *   MS down RAW | MS up RAW   an Amiga raw key (hex) pressed or let go
 *   MS tap RAW                pressed, and let go 100 ms later
 *   MS mouse DX DY            the mouse moved
 *   MS shot FILE              the next frame shown, as a PPM picture
 *   MS quit                   Right Amiga + Q held (acsdl12 sends SDL_QUIT)
 * ACG_LOG names a file that gets one line a frame shown: its number, the
 * time and a hash of what is on screen (the pixels through the palette).
 * Copyright (c) 2026 AmiCradle Team. BSD-2-Clause. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "acgame/platform.h"

#define MAXSTEPS 512
typedef struct { unsigned ms; char cmd[8]; int a, b; char file[256]; int done; } step;
static step g_steps[MAXSTEPS];
static int g_nsteps;
static uint8_t g_raw[ACGAME_RAWKEY_COUNT];
static acgame_indexed_surface g_frame;
static acgame_rgb8 g_shown[256];
static unsigned g_width, g_height;
static int g_dx, g_dy;
static const char *g_shot;
static FILE *g_log;
static unsigned long g_frames;
static struct timespec g_t0;

static unsigned now_ms(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (unsigned)((t.tv_sec - g_t0.tv_sec) * 1000 + (t.tv_nsec - g_t0.tv_nsec) / 1000000);
}

static void load_script(void)
{
    const char *f = getenv("ACG_SCRIPT");
    char line[512];
    FILE *in;
    if (!f || !(in = fopen(f, "r")))
        return;
    while (g_nsteps < MAXSTEPS && fgets(line, sizeof line, in)) {
        step *s = &g_steps[g_nsteps];
        char arg1[256] = "", arg2[64] = "";
        if (line[0] == '#' || sscanf(line, "%u %7s %255s %63s", &s->ms, s->cmd, arg1, arg2) < 2)
            continue;
        if (!strcmp(s->cmd, "shot"))
            snprintf(s->file, sizeof s->file, "%s", arg1);
        else if (!strcmp(s->cmd, "mouse"))
            s->a = atoi(arg1), s->b = atoi(arg2);
        else
            s->a = (int)strtol(arg1, NULL, 16);
        if (!strcmp(s->cmd, "tap")) {   /* a down now, an up 100 ms on */
            step *u = &g_steps[++g_nsteps];
            strcpy(s->cmd, "down");
            *u = *s;
            u->ms += 100;
            strcpy(u->cmd, "up");
        }
        g_nsteps++;
    }
    fclose(in);
}

static void run_script(void)
{
    unsigned t = now_ms();
    int i;
    for (i = 0; i < g_nsteps; i++) {
        step *s = &g_steps[i];
        if (s->done || s->ms > t)
            continue;
        s->done = 1;
        if (!strcmp(s->cmd, "down") && s->a < ACGAME_RAWKEY_COUNT)
            g_raw[s->a] = 1;
        else if (!strcmp(s->cmd, "up") && s->a < ACGAME_RAWKEY_COUNT)
            g_raw[s->a] = 0;
        else if (!strcmp(s->cmd, "mouse"))
            g_dx += s->a, g_dy += s->b;
        else if (!strcmp(s->cmd, "shot"))
            g_shot = s->file;
        else if (!strcmp(s->cmd, "quit"))
            g_raw[0x67] = g_raw[0x10] = 1;
    }
}

int acgame_platform_init(const acgame_video_config *config)
{
    clock_gettime(CLOCK_MONOTONIC, &g_t0);
    g_width = config->width;
    g_height = config->height;
    g_frame.width = (uint16_t)g_width;
    g_frame.height = (uint16_t)g_height;
    g_frame.pitch = g_width;
    g_frame.pixels = calloc(g_width, g_height);
    if (getenv("ACG_LOG"))
        g_log = fopen(getenv("ACG_LOG"), "w");
    load_script();
    return g_frame.pixels ? 0 : -1;
}

void acgame_platform_shutdown(void)
{
    free(g_frame.pixels);
    g_frame.pixels = NULL;
    if (g_log)
        fclose(g_log), g_log = NULL;
}

acgame_indexed_surface *acgame_platform_begin_indexed_frame(void)
{
    return g_frame.pixels ? &g_frame : NULL;
}

static void show(const uint8_t *px, size_t pitch, const acgame_rgb8 *pal)
{
    unsigned long long h = 1469598103934665603ULL;
    unsigned x, y;
    run_script();
    g_frames++;
    for (y = 0; y < g_height; y++)
        for (x = 0; x < g_width; x++) {
            const acgame_rgb8 *c = &pal[px[y * pitch + x]];
            h = (h ^ (unsigned)(c->r << 16 | c->g << 8 | c->b)) * 1099511628211ULL;
        }
    if (g_log)
        fprintf(g_log, "%lu %u %016llx\n", g_frames, now_ms(), h);
    if (g_shot) {
        FILE *out = fopen(g_shot, "wb");
        if (out) {
            fprintf(out, "P6\n%u %u\n255\n", g_width, g_height);
            for (y = 0; y < g_height; y++)
                for (x = 0; x < g_width; x++)
                    fwrite(&pal[px[y * pitch + x]], 1, 3, out);
            fclose(out);
        }
        g_shot = NULL;
    }
}

int acgame_platform_present_indexed(const acgame_indexed_surface *frame)
{
    if (!frame)
        return -1;
    memcpy(g_shown, frame->palette, sizeof g_shown);
    show(frame->pixels, frame->pitch, g_shown);
    return 0;
}

int acgame_platform_set_palette(const acgame_rgb8 palette[256])
{
    memcpy(g_shown, palette, sizeof g_shown);
    show(g_frame.pixels, g_frame.pitch, g_shown);
    return 0;
}

int acgame_platform_display_is_planar(void) { return 0; }

int acgame_platform_get_info(acgame_platform_info *info)
{
    if (!info)
        return -1;
    memset(info, 0, sizeof(*info));
    info->screen_width = g_width;
    info->screen_height = g_height;
    return 0;
}

int acgame_platform_present_ham8(const uint8_t *ham_codes, size_t pitch,
                                 const acgame_rgb8 base_palette[64])
{
    (void)ham_codes;
    (void)pitch;
    (void)base_palette;
    return -1;
}

void acgame_platform_poll(acgame_input_state *state)
{
    run_script();
    if (!state)
        return;
    memset(state, 0, sizeof(*state));
    state->mouse_dx = (int16_t)g_dx;
    state->mouse_dy = (int16_t)g_dy;
    g_dx = g_dy = 0;
    state->key[ACGAME_KEY_UP] = g_raw[0x4c];
    state->key[ACGAME_KEY_DOWN] = g_raw[0x4d];
    state->key[ACGAME_KEY_RIGHT] = g_raw[0x4e];
    state->key[ACGAME_KEY_LEFT] = g_raw[0x4f];
    state->key[ACGAME_KEY_FIRE1] = g_raw[0x40];
    state->key[ACGAME_KEY_START] = g_raw[0x44];
    state->key[ACGAME_KEY_ESCAPE] = g_raw[0x45];
}

const uint8_t *acgame_platform_rawkeys(void)
{
    run_script();
    return g_raw;
}

int acgame_platform_pointer(int *x, int *y)
{
    *x = (int)g_width / 2;
    *y = (int)g_height / 2;
    return 0;
}

int acgame_platform_show_pointer(int show_it)
{
    (void)show_it;
    return 0;
}

uint32_t acgame_platform_ticks_ms(void)
{
    if (!g_frame.pixels)
        clock_gettime(CLOCK_MONOTONIC, &g_t0);
    return now_ms();
}

int acgame_platform_audio_s16stereo(const int16_t *samples, unsigned frames, unsigned sample_rate)
{
    (void)samples;
    (void)frames;
    (void)sample_rate;
    return -1;
}
