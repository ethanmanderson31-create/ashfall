"""Water, ambience and small world sounds for Ashfall (session 2).

Registered into tools/sfx_synth.py, so build them the usual way:
    python3 -I tools/sfx_synth.py assets/audio/synth <names>
Every sound here is synthesized (no recordings), deterministic per name.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_synth as S  # noqa: E402

secs, noise, lowpass, highpass, bandpass = S.secs, S.noise, S.lowpass, S.highpass, S.bandpass
env, mul, mix, place, reverb = S.env, S.mul, S.mix, S.place, S.reverb


def _rng(name):
    S.rng.seed(sum(ord(c) * (i + 1) for i, c in enumerate(name)))
    return random.Random(len(name) * 7919 + ord(name[0]))


def loop_fade(x, fade_s):
    f = secs(fade_s)
    n = len(x)
    for i in range(f):
        k = i / f
        x[i] = x[i] * k + x[n - f + i] * (1 - k)
    return x[: n - f]


# ------------------------------------------------------------------ water
# Water = lots of tiny resonant "bubbles" (sines whose pitch rises as they
# collapse) over filtered noise for the body of the slosh.

def bubble(f0, dur, rise=1.0):
    n = secs(dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        ph += 2 * math.pi * f0 * (1 + rise * t) / S.SR
        out.append(math.sin(ph) * math.exp(-t * 5.0) * min(1.0, i / 40.0))
    return out


def bubbles(track, r, t0, t1, count, f_lo, f_hi, g_lo, g_hi, d_lo=0.02, d_hi=0.07):
    for _ in range(count):
        place(track, r.uniform(t0, t1), bubble(r.uniform(f_lo, f_hi), r.uniform(d_lo, d_hi), r.uniform(0.5, 1.6)), r.uniform(g_lo, g_hi))


def swish(dur, f0, f1, attack=0.03, decay=0.12):
    n = secs(dur)
    cut = [f1 + (f0 - f1) * math.exp(-4.0 * i / n) for i in range(n)]
    return mul(lowpass(lowpass(noise(n), cut), cut), env(n, attack, decay))


def swim_stroke(v):
    """Gentle paddle: a soft, low slosh with a few bubbles."""
    r = _rng("stroke%d1" % v)
    t = []
    place(t, 0.0, swish(0.5, 1300, 380, 0.05, 0.14), 1.0)
    bubbles(t, r, 0.04, 0.3, 9, 300, 900, 0.08, 0.22, 0.03, 0.09)
    return t


def swim_tread(v):
    r = _rng("tread%d" % v)
    t = []
    n = secs(0.7)
    place(t, 0.0, mul(bandpass(noise(n), 480 + v * 60, 1.2), [math.sin(math.pi * i / n) ** 2 for i in range(n)]), 1.0)
    bubbles(t, r, 0.1, 0.55, 5, 250, 650, 0.06, 0.16, 0.04, 0.1)
    return t


def water_splash():
    """Plunge: a splash, a body thump and a rush of bubbles."""
    r = _rng("splash0")
    t = []
    place(t, 0.0, S.mul(S.sweep_sine(secs(0.4), 85, 40, 8), env(secs(0.4), 0.002, 0.09)), 0.9)
    place(t, 0.0, mul(lowpass(noise(secs(0.6)), 3800), env(secs(0.6), 0.004, 0.14)), 1.0)
    place(t, 0.05, swish(0.9, 1800, 300, 0.05, 0.25), 0.7)
    bubbles(t, r, 0.03, 0.9, 55, 220, 1400, 0.06, 0.28, 0.03, 0.12)
    bubbles(t, r, 0.25, 1.2, 22, 1200, 3200, 0.03, 0.1, 0.01, 0.03)
    return t


def water_exit():
    """Water pouring off armour, then drips."""
    r = _rng("exit0")
    t = []
    n = secs(1.3)
    run = mul(bandpass(noise(n), 1300, 0.9), [math.exp(-3.0 * i / n) * min(1.0, i / 800) for i in range(n)])
    place(t, 0.0, run, 0.45)
    for _ in range(26):
        place(t, r.uniform(0.05, 1.3), bubble(r.uniform(1400, 3600), r.uniform(0.012, 0.03), 1.2), r.uniform(0.05, 0.22))
    return t


def wade_step(v):
    """Splashy wading step: a bright kick of water."""
    r = _rng("wade%d1" % v)
    t = []
    place(t, 0.0, swish(0.35, 2400, 400, 0.01, 0.07), 1.0)
    bubbles(t, r, 0.01, 0.2, 10, 400, 1600, 0.06, 0.2)
    bubbles(t, r, 0.1, 0.35, 6, 1800, 3400, 0.03, 0.08, 0.01, 0.025)
    return t


def brook_loop():
    """Seamless loop of trickling water for the nearest shore."""
    r = _rng("lap1")
    dur = 12.0
    t = [0.0] * secs(dur + 1.0)
    n = len(t)
    bed = mul(bandpass(noise(n), 900, 0.7), [0.18 + 0.06 * math.sin(2 * math.pi * i / n * 5) for i in range(n)])
    place(t, 0.0, bed, 1.0)
    bubbles(t, r, 0.0, dur, 420, 500, 2600, 0.03, 0.14, 0.015, 0.06)
    return loop_fade(t[: secs(dur + 1.0)], 1.0)


# ------------------------------------------------------------------ ambience

def insects_loop():
    """Crickets and a low insect hum."""
    r = _rng("insects")
    dur = 10.0
    n = secs(dur + 1.0)
    t = [0.0] * n
    for voice in range(3):
        f = r.uniform(4200, 5200)
        rate = r.uniform(14, 22)
        ph = 0.0
        g = [0.0] * n
        for i in range(n):
            ph += 2 * math.pi * f / S.SR
            pulse = max(0.0, math.sin(2 * math.pi * rate * i / S.SR)) ** 4
            chirp_on = 1.0 if (i / S.SR * 0.5 + voice * 0.3) % 1.0 < 0.6 else 0.15
            g[i] = math.sin(ph) * pulse * chirp_on
        place(t, 0.0, g, 0.18)
    hum = mul(bandpass(noise(n), 220, 2.0), [0.12] * n)
    place(t, 0.0, hum, 1.0)
    return loop_fade(t, 1.0)


def beacon_drone():
    """Ember beacon: a warm low drone with a little crackle."""
    r = _rng("beacon0")
    dur = 8.0
    n = secs(dur + 1.0)
    t = [0.0] * n
    place(t, 0.0, S.warm_pad([(55.0, 0.5), (110.0, 0.35), (164.8, 0.12)], n, 1.0, dur + 5, 1.0), 1.0)
    for _ in range(50):
        st = r.uniform(0.0, dur)
        ln = r.randint(200, 1000)
        place(t, st, mul(bandpass(noise(ln), r.uniform(1500, 4500), 4), env(ln, 0.0002, 0.004)), r.uniform(0.05, 0.25))
    return loop_fade(t, 1.0)


# ------------------------------------------------------------------ actions

def air_jump():
    """Spark burst: a small fire puff with crackling sparks."""
    t = []
    place(t, 0.0, S.ember_puff(0.25, 2200), 0.6)
    r = _rng("spark")
    for _ in range(26):
        ln = r.randint(150, 600)
        place(t, r.uniform(0.0, 0.35), mul(bandpass(noise(ln), r.uniform(3000, 7000), 6), env(ln, 0.0002, 0.003)), r.uniform(0.1, 0.4))
    return t


def mag_drop():
    """A dull drop in the dirt, two small bounces, a plastic tick."""
    t = []
    for at, g in [(0.0, 1.0), (0.11, 0.45), (0.19, 0.2)]:
        place(t, at, mul(lowpass(noise(secs(0.08)), 700), env(secs(0.08), 0.0005, 0.02)), g)
        place(t, at, mul(bandpass(noise(secs(0.04)), 2300, 5), env(secs(0.04), 0.0003, 0.006)), g * 0.6)
    return t


def bullet_miss(v):
    """Stone chip: a crack and a scatter of rock chips."""
    r = _rng("miss%d1" % v)
    t = []
    place(t, 0.0, mul(highpass(noise(secs(0.04)), 2500), env(secs(0.04), 0.0003, 0.005)), 0.5)
    place(t, 0.0, mul(bandpass(noise(secs(0.12)), 1700 + v * 150, 3), env(secs(0.12), 0.0005, 0.02)), 1.0)
    for _ in range(7):
        ln = r.randint(300, 900)
        place(t, r.uniform(0.04, 0.3), mul(bandpass(noise(ln), r.uniform(2000, 4000), 5), env(ln, 0.0003, 0.004)), r.uniform(0.1, 0.3))
    return t


def creature_step(v):
    """Ember crunch: a heavy stone footfall with cracking cinder underneath."""
    r = _rng("cstep%d1" % v)
    t = []
    place(t, 0.0, mul(lowpass(noise(secs(0.18)), 260 + v * 30), env(secs(0.18), 0.002, 0.04)), 1.0)
    place(t, 0.0, mul(S.sweep_sine(secs(0.15), 70, 45, 6), env(secs(0.15), 0.002, 0.04)), 0.5)
    for _ in range(9):
        ln = r.randint(300, 1100)
        place(t, r.uniform(0.0, 0.08), mul(bandpass(noise(ln), r.uniform(1200, 2600), 3), env(ln, 0.0003, 0.006)), r.uniform(0.12, 0.3))
    return t


def player_death_fade():
    """Dying: the heartbeat slows and a low choir sinks away."""
    t = []
    for k, at in enumerate([0.0, 0.85, 1.9, 3.2]):
        place(t, at, S.heartbeat(), 0.9 - k * 0.2)
    place(t, 0.2, S.choir([(110.0, 0.25), (130.8, 0.2), (164.8, 0.15)], 3.5, 0.6, 1.6), 0.5)
    return reverb(t, 0.4, 1.2)


def arcana_open():
    """A page rustle and three soft harp notes."""
    t = []
    for k in range(3):
        n = secs(0.08)
        place(t, k * 0.05, mul(bandpass(noise(n), 3200, 1.5), env(n, 0.003, 0.02)), 0.25)
    for k, f in enumerate([523.25, 659.25, 783.99]):
        place(t, 0.06 + k * 0.05, S.harp(f, 0.8, 0.3), 0.3)
    place(t, 0.05, S.shimmer(0.5, 18, 0.1), 1.0)
    return reverb(t, 0.3, 0.6)


def jobs():
    j = {
        "swim_soft_1": lambda: swim_stroke(0), "swim_soft_2": lambda: swim_stroke(1),
        "swim_tread_1": lambda: swim_tread(0), "swim_tread_2": lambda: swim_tread(1),
        "water_plunge": water_splash, "water_drip": water_exit,
        "wade_splash_1": lambda: wade_step(0), "wade_splash_2": lambda: wade_step(1),
        "brook_loop": brook_loop, "insects_loop": insects_loop, "beacon_drone_loop": beacon_drone,
        "air_jump_sparks": air_jump, "mag_drop_dirt": mag_drop, "death_fade": player_death_fade,
        "arcana_harp": arcana_open,
    }
    for v in range(3):
        j["miss_stone_%d" % (v + 1)] = (lambda v=v: bullet_miss(v))
        j["cstep_crunch_%d" % (v + 1)] = (lambda v=v: creature_step(v))
    return j


GAINS = {"brook_loop": 0.55, "insects_loop": 0.4, "beacon_drone_loop": 0.6, "arcana_harp": 0.45, "death_fade": 0.8}
