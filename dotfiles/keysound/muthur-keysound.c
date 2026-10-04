/*
 * muthur-keysound: the typing ambience of the muthur shell (GitHub issue
 * #21). Listens to muthur-keysound-input's socket — one byte per key
 * press: what kind of key, and roughly where on the keyboard — and plays
 * it through one persistent PipeWire stream, synthesized on the fly (no
 * samples, no process per key).
 *
 * It's built to be heard on headphones. Each key sound is placed where
 * the key is: the far ear hears it a fraction of a millisecond later and
 * a little quieter, the cues the brain uses to place a sound, so typing
 * sweeps from ear to ear. Under it, while typing, an ambience swells and
 * ebbs away a few seconds after the last key: the theme's binaural drone
 * (each ear gets a slightly different pitch, heard as a slow beat inside
 * the head), or a non-tonal one — the inside of a vessel, rain on its
 * hull (bright or muffled), the machinery below deck, the bridge's
 * consoles, life support breathing.
 *
 * Driven by the shell over stdin, one command per line:
 *   theme muthur|nostromo|thocc
 *   ambience drone|vessel|rain|softrain|lowerdeck|bridge|lifesupport
 *   volume 0..1   drone 0..1
 *   test
 * ("drone" is the ambience's level) and reports "input connected" /
 * "input waiting" on stdout. Exits when stdin closes (the shell went away).
 *
 *   muthur-keysound --render FILE SECONDS THEME [AMBIENCE|none]   writes
 *   simulated typing as raw f32 stereo 48 kHz, for testing without the
 *   input service.
 */

#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>

#define RATE 48000
#define CHANNELS 2
#define MAX_VOICES 64
#define DELAY_LEN 64            /* per-voice ring for the interaural delay */
#define MAX_ITD (0.00065 * RATE)/* ~0.65 ms: a sound fully to one side */
#define TAU (2.0 * M_PI)

enum { KEY, SPACE, ENTER, BACKSPACE };
enum { V_BLIP, V_CLICK, V_PLINK, V_THOCC, V_PING, V_HISS };
enum { MUTHUR, NOSTROMO, THOCC, THEMES };
enum { AMB_DRONE, AMB_VESSEL, AMB_HULLRAIN, AMB_SOFTRAIN, AMB_LOWERDECK, AMB_BRIDGE, AMB_LIFESUPPORT, AMBIENCES };

static const char *theme_names[THEMES] = { "muthur", "nostromo", "thocc" };
static const char *ambience_names[AMBIENCES] = { "drone", "vessel", "rain", "softrain", "lowerdeck", "bridge", "lifesupport" };

/* The binaural drone of each theme: carrier pitch, the beat between the
 * ears, a second partial, and a bed of filtered noise. */
struct drone {
    double freq, beat, harmonic, fifth, noise, noise_cutoff;
};

#define ENGINE_ROOM { 70.0, 10.0, 0.45, 0.00, 0.55, 180.0 }
static const struct drone drones[THEMES] = {
    [MUTHUR]     = { 110.0, 6.0,  0.30, 0.00, 0.00, 0.0   }, /* theta: a mainframe's hum */
    [NOSTROMO]   = ENGINE_ROOM,                              /* alpha: the engine room */
    [THOCC]      = ENGINE_ROOM,
};

struct voice {
    int active, type;
    long wait;                 /* samples before it starts */
    long n, length;            /* samples played, total */
    double freq, freq_end, freq2, amp, pan, decay, decay2, decay3;
    double phase, phase2, phase3;
    double bp_z1, bp_z2;       /* band-pass state, for noise bursts */
    double bp_b0, bp_a1, bp_a2;
    float ring[DELAY_LEN];
    int ring_pos;
};

/* One-pole low-pass. */
struct lowpass { double y; };

static double lowpass(struct lowpass *f, double x, double cutoff)
{
    f->y += (1.0 - exp(-TAU * cutoff / RATE)) * (x - f->y);
    return f->y;
}

/* Pink noise (Paul Kellet's economy filter). */
struct pink { double b0, b1, b2; };

struct state {
    int theme, ambience;
    double volume, drone_level;
    struct voice voices[MAX_VOICES];
    double activity;           /* 0..1, follows typing */
    long since_key;            /* samples since the last key */
    double drone_phase[4], lfo, clock;
    double brown_l, brown_r;
    struct lowpass lp[16];
    struct pink pink_l, pink_r;
    long next_event;           /* samples until the ambience's next event */
    unsigned rng;
};

static double frand(struct state *s)
{
    s->rng ^= s->rng << 13;
    s->rng ^= s->rng >> 17;
    s->rng ^= s->rng << 5;
    return (s->rng & 0xffffff) / (double)0x1000000;
}

static double white(struct state *s)
{
    return frand(s) * 2.0 - 1.0;
}

static double pink(struct state *s, struct pink *p)
{
    double w = white(s);
    p->b0 = 0.99765 * p->b0 + w * 0.0990460;
    p->b1 = 0.96300 * p->b1 + w * 0.2965164;
    p->b2 = 0.57000 * p->b2 + w * 1.0526913;
    return (p->b0 + p->b1 + p->b2 + w * 0.1848) * 0.2;
}

static double semitones(double base, double n)
{
    return base * pow(2.0, n / 12.0);
}

/* A minor pentatonic, for MU/TH/UR's blips. */
static const int pentatonic[] = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24 };

static struct voice *spawn(struct state *s, int type, double pan, double amp, double seconds)
{
    struct voice *v = NULL;
    for (int i = 0; i < MAX_VOICES; i++)
        if (!s->voices[i].active) { v = &s->voices[i]; break; }
    if (!v) {                  /* all busy: steal the oldest */
        v = &s->voices[0];
        for (int i = 1; i < MAX_VOICES; i++)
            if (s->voices[i].n > v->n) v = &s->voices[i];
    }
    memset(v, 0, sizeof *v);
    v->active = 1;
    v->type = type;
    v->pan = fmax(-1.0, fmin(1.0, pan));
    v->amp = amp;
    v->length = (long)(seconds * RATE);
    return v;
}

static void bandpass(struct voice *v, double centre, double q)
{
    double w = TAU * centre / RATE, alpha = sin(w) / (2.0 * q), a0 = 1.0 + alpha;
    v->bp_b0 = alpha / a0;
    v->bp_a1 = -2.0 * cos(w) / a0;
    v->bp_a2 = (1.0 - alpha) / a0;
}

/* A raindrop (for the hull rain): a short plink, its pitch rising as
 * the bubble closes. */
static struct voice *plink(struct state *s, double pan, double amp, double freq, double decay, double delay)
{
    struct voice *v = spawn(s, V_PLINK, pan, amp, decay * 6.0 + 0.01);
    v->freq = freq;
    v->decay = decay;
    v->wait = (long)(delay * RATE);
    return v;
}

/* A key press, as each theme plays it. pos is 0 (far left) .. 6. */
static void trigger(struct state *s, int kind, int pos)
{
    double pan = (pos - 3) / 3.0, r = frand(s);
    struct voice *v;
    s->since_key = 0;

    switch (s->theme) {
    case MUTHUR:   /* 1979 terminal: short soft blips, pitched by kind */
        v = spawn(s, V_BLIP, pan, 0.4, 0.05);
        v->freq = semitones(1320.0, pentatonic[(int)(r * 5)]);
        v->freq_end = v->freq;
        v->decay = 0.012;
        if (kind == SPACE) { v->freq = v->freq_end = 660.0; v->decay = 0.02; v->length = RATE / 12; }
        if (kind == ENTER) { v->freq = 880.0; v->freq_end = 1760.0; v->decay = 0.05; v->length = RATE / 6; }
        if (kind == BACKSPACE) { v->freq = 1760.0; v->freq_end = 880.0; v->decay = 0.025; v->length = RATE / 10; }
        break;
    case NOSTROMO: /* a heavy deck: a band-passed click over a low thunk */
        v = spawn(s, V_CLICK, pan, 0.5, 0.06);
        bandpass(v, 2400.0 + r * 1600.0, 2.5);
        v->freq = 150.0 + r * 30.0;
        v->decay = 0.004;
        v->decay2 = 0.012;
        if (kind == SPACE) { v->freq = 85.0; v->decay2 = 0.03; v->amp = 0.6; bandpass(v, 1500.0, 2.0); v->length = RATE / 8; }
        if (kind == ENTER) { v->freq = 100.0; v->decay = 0.008; v->decay2 = 0.04; v->amp = 0.7; v->length = RATE / 6; }
        if (kind == BACKSPACE) { bandpass(v, 1600.0, 3.0); v->freq = 120.0; }
        break;
    case THOCC:    /* deep, muted, rounded: a lubed board on a heavy case */
        v = spawn(s, V_THOCC, pan, 0.7, 0.16);
        bandpass(v, 210.0 + r * 90.0, 0.8);
        v->freq = 58.0 + r * 10.0;            /* the bottom-out */
        v->freq2 = 135.0 + r * 25.0;          /* the case's body resonance */
        v->decay = 0.012;
        v->decay2 = 0.05;
        v->decay3 = 0.03;
        if (kind == SPACE) {   /* the stabilized bar, and its faint rattle */
            v->freq = 46.0; v->freq2 = 110.0; v->decay2 = 0.08; v->amp = 0.8; bandpass(v, 160.0, 0.8); v->length = RATE / 4;
            struct voice *w = spawn(s, V_THOCC, pan, 0.2, 0.08);
            bandpass(w, 420.0, 1.5);
            w->freq = 70.0; w->freq2 = 180.0; w->decay = 0.005; w->decay2 = 0.015; w->decay3 = 0.01;
            w->wait = RATE / 250;
        }
        if (kind == ENTER) { v->freq = 50.0; v->freq2 = 120.0; v->decay2 = 0.07; v->amp = 0.8; bandpass(v, 180.0, 0.9); v->length = RATE / 4; }
        if (kind == BACKSPACE) { bandpass(v, 300.0, 1.0); v->freq = 70.0; v->freq2 = 160.0; }
        break;
    }
}

static double bandpassed(struct state *s, struct voice *v)
{
    /* RBJ band-pass (b1 = 0, b2 = -b0), transposed direct form II. */
    double noise = white(s);
    double y = v->bp_b0 * noise + v->bp_z1;
    v->bp_z1 = -v->bp_a1 * y + v->bp_z2;
    v->bp_z2 = -v->bp_b0 * noise - v->bp_a2 * y;
    return y;
}

/* One mono sample of a voice. */
static double voice_sample(struct state *s, struct voice *v)
{
    double t = (double)v->n / RATE, x = (double)v->n / v->length, out = 0.0;
    double attack = t < 0.002 ? t / 0.002 : 1.0;

    switch (v->type) {
    case V_BLIP: {
        double f = v->freq + (v->freq_end - v->freq) * x;
        v->phase += TAU * f / RATE;
        out = (sin(v->phase) + 0.2 * sin(3.0 * v->phase)) * exp(-t / v->decay);
        break;
    }
    case V_CLICK: {
        double bp = bandpassed(s, v);
        v->phase += TAU * v->freq / RATE;
        out = 3.0 * bp * exp(-t / v->decay) + 0.8 * sin(v->phase) * exp(-t / v->decay2);
        break;
    }
    case V_PLINK: {
        double f = v->freq * (1.0 + 1.1 * fmin(1.0, t / (v->decay * 1.5)));
        v->phase += TAU * f / RATE;
        out = sin(v->phase) * exp(-t / v->decay);
        attack = t < 0.0015 ? t / 0.0015 : 1.0;
        break;
    }
    case V_THOCC: {
        double bp = bandpassed(s, v);
        v->phase += TAU * v->freq / RATE;
        v->phase2 += TAU * v->freq2 / RATE;
        out = 2.5 * bp * exp(-t / v->decay) + 0.9 * sin(v->phase) * exp(-t / v->decay2)
            + 0.4 * sin(v->phase2) * exp(-t / v->decay3);
        attack = t < 0.001 ? t / 0.001 : 1.0;
        break;
    }
    case V_HISS:   /* a vent letting go: band-passed noise, swelling then fading */
        out = 2.0 * bandpassed(s, v) * fmin(1.0, t / 0.15) * exp(-t / v->decay);
        break;
    case V_PING:   /* the hull settling: two inharmonic partials, ringing */
        v->phase += TAU * v->freq / RATE;
        v->phase2 += TAU * v->freq * 2.32 / RATE;
        out = (sin(v->phase) + 0.5 * sin(v->phase2) * exp(-t / (v->decay * 0.4))) * exp(-t / v->decay);
        attack = t < 0.01 ? t / 0.01 : 1.0;
        break;
    }
    return out * attack * v->amp;
}

/* Adds a voice into the stereo frame: level and arrival time differ
 * between the ears according to its pan. */
static void voice_mix(struct state *s, struct voice *v, double *l, double *r)
{
    if (v->wait > 0) {
        v->wait--;
        return;
    }
    float mono = (float)voice_sample(s, v);
    v->ring[v->ring_pos] = mono;
    double angle = (v->pan + 1.0) * M_PI / 4.0;          /* equal power */
    double gl = cos(angle) * 0.6 + 0.4 * M_SQRT1_2;      /* softened: headphones */
    double gr = sin(angle) * 0.6 + 0.4 * M_SQRT1_2;
    int itd = (int)(fabs(v->pan) * MAX_ITD);
    int far = (v->ring_pos - itd + DELAY_LEN) % DELAY_LEN;
    float near_s = mono, far_s = v->ring[far];
    if (v->pan >= 0) { *r += gr * near_s; *l += gl * far_s; }
    else             { *l += gl * near_s; *r += gr * far_s; }
    v->ring_pos = (v->ring_pos + 1) % DELAY_LEN;
    if (++v->n >= v->length + DELAY_LEN)
        v->active = 0;
}

/* --- Ambiences ------------------------------------------------------- */

/* The theme's binaural drone. */
static void drone(struct state *s, double level, double *l, double *r)
{
    const struct drone *d = &drones[s->theme];
    double breath = 0.8 + 0.2 * sin(s->lfo);
    double fl = d->freq, fr = d->freq + d->beat;
    s->drone_phase[0] += TAU * fl / RATE;
    s->drone_phase[1] += TAU * fr / RATE;
    s->drone_phase[2] += TAU * fl * 1.5 / RATE;
    s->drone_phase[3] += TAU * fr * 1.5 / RATE;
    for (int c = 0; c < 4; c++)
        if (s->drone_phase[c] > TAU) s->drone_phase[c] -= TAU;
    double dl = sin(s->drone_phase[0]) + d->harmonic * sin(2.0 * s->drone_phase[0])
              + d->fifth * sin(s->drone_phase[2]);
    double dr = sin(s->drone_phase[1]) + d->harmonic * sin(2.0 * s->drone_phase[1])
              + d->fifth * sin(s->drone_phase[3]);
    if (d->noise > 0.0) {
        /* Brown-ish noise, low-passed, a different stream per ear. */
        s->brown_l = 0.995 * s->brown_l + 0.05 * white(s);
        s->brown_r = 0.995 * s->brown_r + 0.05 * white(s);
        double cutoff = d->noise_cutoff * (0.8 + 0.4 * sin(s->lfo * 3.0));
        dl += d->noise * 4.0 * lowpass(&s->lp[0], s->brown_l, cutoff);
        dr += d->noise * 4.0 * lowpass(&s->lp[1], s->brown_r, cutoff);
    }
    *l += 0.12 * level * breath * dl;
    *r += 0.12 * level * breath * dr;
}

/* Samples until the next event, between a and b seconds away. */
static long after(struct state *s, double a, double b)
{
    return (long)((a + frand(s) * (b - a)) * RATE);
}

/* Inside a vessel: air handling, a deep machinery rumble felt more than
 * heard, each ear drifting on its own so the room has width; now and
 * then the hull ticks or something clanks far off. No pitch to fix on. */
static void vessel(struct state *s, double level, double *l, double *r)
{
    double pl = pink(s, &s->pink_l), pr = pink(s, &s->pink_r);
    s->brown_l = 0.996 * s->brown_l + 0.04 * white(s);
    s->brown_r = 0.996 * s->brown_r + 0.04 * white(s);
    double drift_l = 0.85 + 0.15 * sin(s->clock * TAU * 0.031);
    double drift_r = 0.85 + 0.15 * sin(s->clock * TAU * 0.043 + 1.7);
    double air_l = lowpass(&s->lp[2], pl, 320.0), air_r = lowpass(&s->lp[3], pr, 320.0);
    double vent_l = lowpass(&s->lp[4], pl, 1400.0) - lowpass(&s->lp[5], pl, 700.0);
    double vent_r = lowpass(&s->lp[6], pr, 1400.0) - lowpass(&s->lp[7], pr, 700.0);
    double rumble_l = lowpass(&s->lp[8], s->brown_l, 55.0), rumble_r = lowpass(&s->lp[9], s->brown_r, 55.0);
    *l += 0.065 * level * drift_l * (1.6 * air_l + 0.35 * vent_l + 6.0 * rumble_l);
    *r += 0.065 * level * drift_r * (1.6 * air_r + 0.35 * vent_r + 6.0 * rumble_r);

    if (--s->next_event <= 0) {
        s->next_event = after(s, 4.0, 13.0);
        if (frand(s) < 0.7) {
            struct voice *v = spawn(s, V_PING, frand(s) * 2.0 - 1.0, 0.05 * level, 2.5);
            v->freq = 260.0 + frand(s) * 700.0;
            v->decay = 0.5 + frand(s) * 0.8;
        } else {
            struct voice *v = spawn(s, V_THOCC, frand(s) * 2.0 - 1.0, 0.1 * level, 0.6);
            bandpass(v, 180.0 + frand(s) * 120.0, 1.0);
            v->freq = 42.0; v->freq2 = 600.0 + frand(s) * 300.0;
            v->decay = 0.03; v->decay2 = 0.15; v->decay3 = 0.12;
        }
    }
}

/* Rain on the hull: a hiss of fine drops overhead, a muffled roar
 * through the plating, single drops ticking all around, and a leak
 * somewhere to the left. */
static void hull_rain(struct state *s, double level, double *l, double *r)
{
    double wl = white(s), wr = white(s);
    double flutter = 0.8 + 0.2 * sin(s->clock * TAU * 0.11);
    double hiss_l = wl - lowpass(&s->lp[2], wl, 1800.0), hiss_r = wr - lowpass(&s->lp[3], wr, 1800.0);
    double roar_l = lowpass(&s->lp[4], pink(s, &s->pink_l), 450.0);
    double roar_r = lowpass(&s->lp[5], pink(s, &s->pink_r), 450.0);
    *l += 0.24 * level * (0.05 * flutter * hiss_l + 1.1 * roar_l);
    *r += 0.24 * level * (0.05 * flutter * hiss_r + 1.1 * roar_r);

    if (frand(s) < 22.0 * level / RATE)    /* ~22 drops a second at full */
        plink(s, frand(s) * 2.0 - 1.0, 0.03 + frand(s) * 0.04, 2400.0 + frand(s) * 3800.0, 0.004, 0.0);
    if (--s->next_event <= 0) {
        s->next_event = after(s, 1.8, 3.6);
        plink(s, -0.6, 0.09 * level, 950.0, 0.02, 0.0);
    }
}

/* Rain heard through thick plating: a muffled wash that swells and eases
 * in slow gusts, and now and then a heavy drop landing somewhere on the
 * hull — a dull thud, nothing high, nothing that chirps. */
static void soft_rain(struct state *s, double level, double *l, double *r)
{
    double gust_l = 0.75 + 0.25 * sin(s->clock * TAU / 11.0);
    double gust_r = 0.75 + 0.25 * sin(s->clock * TAU / 13.0 + 2.1);
    double pl = pink(s, &s->pink_l), pr = pink(s, &s->pink_r);
    double wash_l = lowpass(&s->lp[2], lowpass(&s->lp[3], pl, 750.0), 750.0);
    double wash_r = lowpass(&s->lp[4], lowpass(&s->lp[5], pr, 750.0), 750.0);
    s->brown_l = 0.996 * s->brown_l + 0.04 * white(s);
    s->brown_r = 0.996 * s->brown_r + 0.04 * white(s);
    double low_l = lowpass(&s->lp[6], s->brown_l, 90.0), low_r = lowpass(&s->lp[7], s->brown_r, 90.0);
    *l += 0.13 * level * (gust_l * 1.4 * wash_l + 2.0 * low_l);
    *r += 0.13 * level * (gust_r * 1.4 * wash_r + 2.0 * low_r);

    if (--s->next_event <= 0) {
        s->next_event = after(s, 0.5, 2.2);
        struct voice *v = spawn(s, V_THOCC, frand(s) * 2.0 - 1.0, (0.02 + frand(s) * 0.03) * level, 0.3);
        bandpass(v, 220.0 + frand(s) * 120.0, 0.7);
        v->freq = 55.0 + frand(s) * 15.0; v->freq2 = 120.0 + frand(s) * 40.0;
        v->decay = 0.015; v->decay2 = 0.06; v->decay3 = 0.04;
    }
}

/* Below deck: machinery turning over slowly, a broad throb with no
 * pitch in it, a steadier mid-band churn, and a steam vent letting go
 * somewhere now and then. */
static void lower_deck(struct state *s, double level, double *l, double *r)
{
    double throb_l = 0.7 + 0.3 * sin(s->clock * TAU * 0.9);
    double throb_r = 0.7 + 0.3 * sin(s->clock * TAU * 0.9 + 0.6);
    double pl = pink(s, &s->pink_l), pr = pink(s, &s->pink_r);
    s->brown_l = 0.996 * s->brown_l + 0.04 * white(s);
    s->brown_r = 0.996 * s->brown_r + 0.04 * white(s);
    double low_l = lowpass(&s->lp[2], pl, 200.0) + 1.5 * lowpass(&s->lp[3], s->brown_l, 70.0);
    double low_r = lowpass(&s->lp[4], pr, 200.0) + 1.5 * lowpass(&s->lp[5], s->brown_r, 70.0);
    double churn_l = lowpass(&s->lp[6], pl, 600.0) - lowpass(&s->lp[7], pl, 300.0);
    double churn_r = lowpass(&s->lp[8], pr, 600.0) - lowpass(&s->lp[9], pr, 300.0);
    *l += 0.1 * level * (throb_l * 2.4 * low_l + 1.0 * churn_l);
    *r += 0.1 * level * (throb_r * 2.4 * low_r + 1.0 * churn_r);

    if (--s->next_event <= 0) {
        s->next_event = after(s, 9.0, 20.0);
        struct voice *v = spawn(s, V_HISS, frand(s) * 1.6 - 0.8, 0.035 * level, 3.0);
        bandpass(v, 2500.0 + frand(s) * 2000.0, 0.6);
        v->decay = 0.9 + frand(s) * 0.8;
    }
}

/* The bridge: a quiet room — soft air, a faint high hush — and relays
 * ticking in the consoles around you, sometimes a short run of them as
 * something computes. */
static void bridge(struct state *s, double level, double *l, double *r)
{
    double wl = white(s), wr = white(s);
    double pl = pink(s, &s->pink_l), pr = pink(s, &s->pink_r);
    double room_l = lowpass(&s->lp[2], pl, 500.0), room_r = lowpass(&s->lp[3], pr, 500.0);
    double hush_l = wl - lowpass(&s->lp[4], wl, 4000.0), hush_r = wr - lowpass(&s->lp[5], wr, 4000.0);
    *l += 0.24 * level * (1.2 * room_l + 0.012 * hush_l);
    *r += 0.24 * level * (1.2 * room_r + 0.012 * hush_r);

    if (--s->next_event <= 0) {
        s->next_event = after(s, 0.7, 3.5);
        double pan = frand(s) * 2.0 - 1.0;
        int run = frand(s) < 0.2 ? 3 + (int)(frand(s) * 4) : 1;
        for (int i = 0; i < run; i++) {
            struct voice *v = spawn(s, V_CLICK, pan + (frand(s) - 0.5) * 0.2, 0.02 * level, 0.02);
            bandpass(v, 3000.0 + frand(s) * 2500.0, 4.0);
            v->freq = 320.0; v->decay = 0.0015; v->decay2 = 0.002;
            v->wait = (long)(i * (0.05 + frand(s) * 0.04) * RATE);
        }
    }
}

/* Life support: ventilation that breathes, a slow inhale and exhale,
 * and a console somewhere chirping its status. */
static void life_support(struct state *s, double level, double *l, double *r)
{
    double cycle = 0.5 + 0.5 * sin(s->clock * TAU / 7.0);
    double lag = 0.5 + 0.5 * sin(s->clock * TAU / 7.0 - 0.5);
    double pl = pink(s, &s->pink_l), pr = pink(s, &s->pink_r);
    double vl = lowpass(&s->lp[2], lowpass(&s->lp[3], pl, 160.0 + 600.0 * cycle), 160.0 + 600.0 * cycle);
    double vr = lowpass(&s->lp[4], lowpass(&s->lp[5], pr, 160.0 + 600.0 * lag), 160.0 + 600.0 * lag);
    *l += 0.42 * level * (0.6 + 0.4 * cycle) * vl;
    *r += 0.42 * level * (0.6 + 0.4 * lag) * vr;

    if (--s->next_event <= 0) {
        s->next_event = after(s, 8.0, 14.0);
        double pan = frand(s) * 1.6 - 0.8;
        for (int i = 0; i < 2; i++) {
            struct voice *v = spawn(s, V_BLIP, pan, 0.06 * level, 0.08);
            v->freq = v->freq_end = i ? 1250.0 : 1050.0;
            v->decay = 0.03;
            v->wait = i * RATE / 6;
        }
    }
}

static void render(struct state *s, float *out, unsigned frames)
{
    /* Silent between bursts of typing: skip the synthesis. */
    int busy = s->activity > 0.0005 || s->since_key < 4 * RATE;
    for (int k = 0; !busy && k < MAX_VOICES; k++)
        busy = s->voices[k].active;
    if (!busy) {
        memset(out, 0, frames * CHANNELS * sizeof(float));
        s->since_key += frames;
        return;
    }

    for (unsigned i = 0; i < frames; i++) {
        double l = 0.0, r = 0.0;

        for (int k = 0; k < MAX_VOICES; k++)
            if (s->voices[k].active)
                voice_mix(s, &s->voices[k], &l, &r);

        /* The ambience follows typing: swells in within about a second,
         * holds while keys keep coming, ebbs away over ~5 s once they
         * stop. */
        double target = s->since_key < 4 * RATE ? 1.0 : 0.0;
        double tau = target > s->activity ? 0.4 : 1.5;   /* one-pole, seconds */
        s->activity += (target - s->activity) / (tau * RATE);
        s->since_key++;

        double level = s->activity * s->drone_level;
        if (level > 0.0005) {
            s->lfo += TAU * 0.07 / RATE;              /* slow breathing */
            if (s->lfo > TAU) s->lfo -= TAU;
            s->clock += 1.0 / RATE;
            switch (s->ambience) {
            case AMB_DRONE:       drone(s, level, &l, &r); break;
            case AMB_VESSEL:      vessel(s, level, &l, &r); break;
            case AMB_HULLRAIN:    hull_rain(s, level, &l, &r); break;
            case AMB_SOFTRAIN:    soft_rain(s, level, &l, &r); break;
            case AMB_LOWERDECK:   lower_deck(s, level, &l, &r); break;
            case AMB_BRIDGE:      bridge(s, level, &l, &r); break;
            case AMB_LIFESUPPORT: life_support(s, level, &l, &r); break;
            }
        }

        out[2 * i] = (float)tanh(l * s->volume * 1.5);
        out[2 * i + 1] = (float)tanh(r * s->volume * 1.5);
    }
}

/* --- Commands -------------------------------------------------------- */

static void command(struct state *s, char *line)
{
    char word[32];
    double value;
    if (sscanf(line, "theme %31s", word) == 1) {
        for (int i = 0; i < THEMES; i++)
            if (!strcmp(word, theme_names[i])) s->theme = i;
    } else if (sscanf(line, "ambience %31s", word) == 1) {
        for (int i = 0; i < AMBIENCES; i++)
            if (!strcmp(word, ambience_names[i]) && s->ambience != i) {
                s->ambience = i;
                s->next_event = RATE;
            }
    } else if (sscanf(line, "volume %lf", &value) == 1) {
        s->volume = fmax(0.0, fmin(1.0, value));
    } else if (sscanf(line, "drone %lf", &value) == 1) {
        s->drone_level = fmax(0.0, fmin(1.0, value));
    } else if (!strncmp(line, "test", 4)) {
        /* A sweep across the keyboard, for the panel's TEST button. */
        for (int p = 0; p <= 6; p++) trigger(s, KEY, p);
    }
}

/* --- Offline render -------------------------------------------------- */

static int render_file(const char *path, double seconds, const char *theme, const char *ambience)
{
    struct state s = { .volume = 0.8, .drone_level = 0.6, .rng = 0x9e3779b9u };
    char line[64];
    snprintf(line, sizeof line, "theme %s", theme);
    command(&s, line);
    snprintf(line, sizeof line, "ambience %s", ambience);
    command(&s, line);
    if (!strcmp(ambience, "none"))     /* the keys alone */
        s.drone_level = 0.0;
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return 1; }
    float buf[256 * CHANNELS];
    long total = (long)(seconds * RATE), done = 0, next = RATE / 2;
    while (done < total) {
        if (done >= next && done < total - 5 * RATE) {
            /* ~6 keys a second, a space every few, enter now and then. */
            double r = frand(&s);
            trigger(&s, r < 0.15 ? SPACE : r < 0.18 ? ENTER : r < 0.22 ? BACKSPACE : KEY, (int)(frand(&s) * 7));
            next = done + RATE / 8 + (long)(frand(&s) * RATE / 4);
        }
        render(&s, buf, 256);
        fwrite(buf, sizeof(float), 256 * CHANNELS, f);
        done += 256;
    }
    fclose(f);
    return 0;
}

/* --- Live: PipeWire, the input socket, stdin ------------------------- */

struct app {
    struct state s;
    struct pw_main_loop *loop;
    struct pw_stream *stream;
    struct spa_source *sock_source, *stdin_source, *retry;
    int sock;
    char pending[256];
    size_t pending_len;
};

static void on_process(void *data)
{
    struct app *a = data;
    struct pw_buffer *b = pw_stream_dequeue_buffer(a->stream);
    if (!b) return;
    struct spa_buffer *buf = b->buffer;
    float *dst = buf->datas[0].data;
    if (!dst) return;
    uint32_t stride = sizeof(float) * CHANNELS;
    uint32_t frames = buf->datas[0].maxsize / stride;
    if (b->requested) frames = SPA_MIN((uint32_t)b->requested, frames);
    render(&a->s, dst, frames);
    buf->datas[0].chunk->offset = 0;
    buf->datas[0].chunk->stride = stride;
    buf->datas[0].chunk->size = frames * stride;
    pw_stream_queue_buffer(a->stream, b);
}

static const struct pw_stream_events stream_events = {
    PW_VERSION_STREAM_EVENTS,
    .process = on_process,
};

static const char *socket_path(void)
{
    const char *p = getenv("MUTHUR_KEYSOUND_SOCKET");
    return p ? p : "/run/muthur-keysound/events.sock";
}

static void status(const char *what)
{
    printf("input %s\n", what);
    fflush(stdout);
}

static void disconnect(struct app *a);

static void on_socket(void *data, int fd, uint32_t mask)
{
    struct app *a = data;
    unsigned char bytes[64];
    ssize_t n = (mask & SPA_IO_IN) ? read(fd, bytes, sizeof bytes) : 0;
    if (n <= 0 && !(n < 0 && errno == EAGAIN)) {
        disconnect(a);
        return;
    }
    for (ssize_t i = 0; i < n; i++)
        trigger(&a->s, bytes[i] & 3, (bytes[i] >> 2) & 7);
}

static void try_connect(void *data, uint64_t expirations)
{
    struct app *a = data;
    (void)expirations;
    if (a->sock >= 0) return;
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    struct sockaddr_un addr = { .sun_family = AF_UNIX };
    strncpy(addr.sun_path, socket_path(), sizeof addr.sun_path - 1);
    if (fd < 0 || connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        if (fd >= 0) close(fd);
        return;               /* the timer tries again */
    }
    a->sock = fd;
    a->sock_source = pw_loop_add_io(pw_main_loop_get_loop(a->loop), fd,
                                    SPA_IO_IN | SPA_IO_HUP | SPA_IO_ERR, false, on_socket, a);
    status("connected");
}

static void disconnect(struct app *a)
{
    if (a->sock < 0) return;
    pw_loop_destroy_source(pw_main_loop_get_loop(a->loop), a->sock_source);
    close(a->sock);
    a->sock = -1;
    status("waiting");
}

static void on_stdin(void *data, int fd, uint32_t mask)
{
    struct app *a = data;
    char chunk[256];
    ssize_t n = (mask & SPA_IO_IN) ? read(fd, chunk, sizeof chunk) : 0;
    if (n <= 0) {
        pw_main_loop_quit(a->loop);   /* the shell went away */
        return;
    }
    for (ssize_t i = 0; i < n; i++) {
        if (chunk[i] == '\n' || a->pending_len == sizeof a->pending - 1) {
            a->pending[a->pending_len] = 0;
            command(&a->s, a->pending);
            a->pending_len = 0;
        } else {
            a->pending[a->pending_len++] = chunk[i];
        }
    }
}

int main(int argc, char *argv[])
{
    if ((argc == 5 || argc == 6) && !strcmp(argv[1], "--render"))
        return render_file(argv[2], atof(argv[3]), argv[4], argc == 6 ? argv[5] : "drone");

    struct app a = { .s = { .volume = 0.5, .drone_level = 0.5, .rng = 0x9e3779b9u }, .sock = -1 };
    a.s.rng ^= (unsigned)getpid();

    pw_init(&argc, &argv);
    a.loop = pw_main_loop_new(NULL);
    struct pw_loop *loop = pw_main_loop_get_loop(a.loop);

    a.stream = pw_stream_new_simple(loop, "muthur-keysound",
        pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Playback",
            PW_KEY_MEDIA_ROLE, "Game",
            PW_KEY_APP_NAME, "muthur-keysound",
            PW_KEY_NODE_NAME, "muthur-keysound",
            PW_KEY_MEDIA_NAME, "Typing ambience",
            PW_KEY_NODE_LATENCY, "256/48000",
            NULL),
        &stream_events, &a);

    uint8_t pod_buf[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(pod_buf, sizeof pod_buf);
    struct spa_audio_info_raw info = {
        .format = SPA_AUDIO_FORMAT_F32, .rate = RATE, .channels = CHANNELS,
        .position = { SPA_AUDIO_CHANNEL_FL, SPA_AUDIO_CHANNEL_FR },
    };
    const struct spa_pod *params[1] = { spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info) };
    pw_stream_connect(a.stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
                      PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS, params, 1);

    fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);
    a.stdin_source = pw_loop_add_io(loop, STDIN_FILENO, SPA_IO_IN | SPA_IO_HUP, false, on_stdin, &a);

    a.retry = pw_loop_add_timer(loop, try_connect, &a);
    struct timespec first = { 0, 1 }, every = { 2, 0 };
    pw_loop_update_timer(loop, a.retry, &first, &every, false);
    status("waiting");

    pw_main_loop_run(a.loop);

    disconnect(&a);
    pw_stream_destroy(a.stream);
    pw_main_loop_destroy(a.loop);
    pw_deinit();
    return 0;
}
