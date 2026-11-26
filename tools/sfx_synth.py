"""Synthesizes Ashfall's custom sound effects as 44.1 kHz mono WAVs.

Usage: python3 tools/sfx_synth.py <out_dir> [name ...]   (names limit which sounds to rebuild)
Pure standard library; deterministic (seeded) so rebuilding gives the same files.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
rng = random.Random(1337)


def secs(t):
    return int(t * SR)


def write(path, samples, gain=1.0):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = gain * 0.95 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767)) for s in samples))


def noise(n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a number or a per-sample list."""
    y = []
    z = 0.0
    for i, s in enumerate(x):
        c = cutoff[i] if isinstance(cutoff, list) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * c / SR)
        z += a * (s - z)
        y.append(z)
    return y


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def bandpass(x, f, q=4.0):
    """RBJ biquad bandpass (constant peak gain)."""
    w0 = 2 * math.pi * f / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for s in x:
        o = (b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, s
        y2, y1 = y1, o
        y.append(o)
    return y


def env(n, attack, decay_tau, hold=0.0):
    a = secs(attack)
    h = secs(hold)
    out = []
    for i in range(n):
        if i < a:
            out.append(i / max(a, 1))
        elif i < a + h:
            out.append(1.0)
        else:
            out.append(math.exp(-(i - a - h) / (decay_tau * SR)))
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def mix(*tracks):
    n = max(len(t) for t, _ in tracks)
    out = [0.0] * n
    for t, g in tracks:
        for i, s in enumerate(t):
            out[i] += s * g
    return out


def sweep_sine(n, f0, f1, curve=3.0):
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f1 + (f0 - f1) * math.exp(-t * curve)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph))
    return out


def sat(x, drive):
    return [math.tanh(s * drive) for s in x]


def pad(x, before=0.0):
    return [0.0] * secs(before) + x


# ------------------------------------------------------------------ sounds

def gun_shot(v):
    n = secs(0.55)
    crack = mul(highpass(noise(n), 1800), env(n, 0.0005, 0.018))
    body = mul(lowpass(noise(n), 2200 + v * 300), env(n, 0.001, 0.06))
    thump = mul(sweep_sine(n, 160 + v * 10, 48, 18), env(n, 0.001, 0.09))
    ring = mul(bandpass(noise(n), 3100 + v * 250, 18), env(n, 0.002, 0.14))
    tail = mul(lowpass(noise(n), 700), env(n, 0.01, 0.22))
    return sat(mix((crack, 1.0), (body, 0.9), (thump, 1.3), (ring, 0.35), (tail, 0.25)), 1.6)


def explosion():
    n = secs(1.6)
    boom = mul(sweep_sine(n, 90, 30, 4), env(n, 0.003, 0.35))
    roar = mul(lowpass(noise(n), [900 * math.exp(-i / SR * 3) + 120 for i in range(n)]), env(n, 0.004, 0.45))
    crack = mul(highpass(noise(n), 2500), env(n, 0.0005, 0.03))
    return sat(mix((boom, 1.4), (roar, 1.0), (crack, 0.5)), 1.8)


def axe_impact(v, heavy=False):
    n = secs(0.9 if heavy else 0.6)
    thud = mul(sweep_sine(n, 130 - v * 8, 38, 9), env(n, 0.0008, 0.16 if heavy else 0.1))
    crunch = mul(bandpass(noise(n), 900 + v * 120, 1.2), env(n, 0.0005, 0.05))
    grit = mul(highpass(noise(n), 3000), env(n, 0.0003, 0.012))
    stone = mul(bandpass(noise(n), 1700 + v * 200, 6), env(n, 0.001, 0.09))
    tail = mul(lowpass(noise(n), 300), env(n, 0.01, 0.3)) if heavy else [0.0] * n
    return sat(mix((thud, 1.5), (crunch, 1.0), (grit, 0.6), (stone, 0.4), (tail, 0.7)), 2.2)


def bell(f, n, decay):
    out = [0.0] * n
    for partial, amp, d in [(1.0, 1.0, 1.0), (2.76, 0.45, 0.6), (5.4, 0.25, 0.35), (8.9, 0.12, 0.2)]:
        for i in range(n):
            out[i] += amp * math.sin(2 * math.pi * f * partial * i / SR) * math.exp(-i / (decay * d * SR))
    return out


def xp_chime(v):
    n = secs(0.5)
    f = [1320, 1480, 1660][v]
    b = bell(f, n, 0.18)
    att = env(n, 0.002, 10.0)
    return mul(b, att)


def level_up():
    n = secs(2.2)
    out = [0.0] * n
    notes = [523.25, 659.25, 783.99, 1046.5]
    for k, f in enumerate(notes):
        start = secs(k * 0.11)
        b = bell(f, n - start, 0.9)
        for i, s in enumerate(b):
            out[start + i] += s * 0.6
    shimmer = mul(bandpass(noise(n), 6000, 2), [0.15 * math.sin(math.pi * min(1.0, i / (n * 0.7))) for i in range(n)])
    pad_ = [0.0] * n
    for f in [261.6, 392.0, 523.25]:
        for i in range(n):
            pad_[i] += math.sin(2 * math.pi * f * i / SR) * min(1.0, i / secs(0.4)) * math.exp(-i / secs(0.9))
    return mix((out, 1.0), (shimmer, 1.0), (pad_, 0.25))


def mastery():
    n = secs(3.0)
    out = [0.0] * n
    for k, f in enumerate([196.0, 293.66, 392.0, 587.33]):
        start = secs(k * 0.07)
        b = bell(f, n - start, 1.6)
        for i, s in enumerate(b):
            out[start + i] += s * (0.7 - k * 0.1)
    boom = mul(sweep_sine(n, 70, 40, 3), env(n, 0.01, 0.5))
    return mix((out, 1.0), (boom, 0.6))


def slam_boom():
    n = secs(3.2)
    sub = mul(sweep_sine(n, 70, 26, 2.5), env(n, 0.004, 0.7))
    rumble_env = [math.exp(-i / secs(1.1)) * (0.7 + 0.3 * math.sin(i / SR * 2 * math.pi * 7)) for i in range(n)]
    rumble = mul(lowpass(lowpass(noise(n), 160), 160), rumble_env)
    crack = mul(highpass(noise(n), 1500), env(n, 0.0005, 0.04))
    debris = [0.0] * n
    for _ in range(90):
        t = int(abs(rng.gauss(0.35, 0.45)) * SR)
        if t >= n - 2000:
            continue
        ln = rng.randint(300, 1600)
        f = rng.uniform(600, 2500)
        burst = mul(bandpass(noise(ln), f, 3), env(ln, 0.0003, 0.008))
        g = rng.uniform(0.1, 0.4) * math.exp(-t / secs(1.5))
        for i, s in enumerate(burst):
            debris[t + i] += s * g
    return sat(mix((sub, 2.0), (rumble, 3.5), (crack, 0.5), (debris, 1.0)), 1.6)


def boss_step():
    n = secs(1.2)
    thud = mul(sweep_sine(n, 75, 30, 5), env(n, 0.003, 0.18))
    rumble = mul(lowpass(lowpass(noise(n), 120), 120), env(n, 0.01, 0.35))
    grit = mul(bandpass(noise(n), 900, 2), env(n, 0.001, 0.04))
    return sat(mix((thud, 1.6), (rumble, 3.0), (grit, 0.25)), 1.4)


def snarl(v):
    n = secs(0.9 + v * 0.2)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 78 + v * 10 + 14 * math.sin(t * 2 * math.pi * 3.1) + rng.uniform(-6, 6)
        ph += 2 * math.pi * f / SR
        saw = (ph / math.pi) % 2.0 - 1.0
        trem = 0.55 + 0.45 * math.sin(t * 2 * math.pi * (24 + v * 3))
        out.append(saw * trem)
    voiced = bandpass(out, 520 + v * 60, 1.4)
    breath = mul(bandpass(noise(n), 1400, 1.5), [0.5] * n)
    shape = [min(1.0, i / secs(0.08)) * (1.0 - max(0.0, (i - n * 0.75) / (n * 0.25))) for i in range(n)]
    return sat(mul(mix((voiced, 1.6), (breath, 0.5)), shape), 2.5)


def snap():
    n = secs(0.35)
    click = mul(highpass(noise(n), 2500), env(n, 0.0002, 0.006))
    jaw = mul(bandpass(noise(n), 700, 3), env(n, 0.0005, 0.03))
    thump = mul(sweep_sine(n, 200, 80, 12), env(n, 0.001, 0.04))
    return mix((click, 1.0), (jaw, 1.2), (thump, 0.8))


def whoosh(dur, f0, f1):
    n = secs(dur)
    cut = [f0 + (f1 - f0) * (i / n) for i in range(n)]
    body = []
    src = noise(n)
    # sweeping bandpass approximated by two lowpasses
    lp = lowpass(src, cut)
    hp = highpass(lp, [c * 0.3 for c in cut])
    shape = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
    return mul(hp, shape)


def thump(f=90, dur=0.4):
    n = secs(dur)
    return sat(mix((mul(sweep_sine(n, f, f * 0.45, 8), env(n, 0.001, dur * 0.25)), 1.5), (mul(lowpass(noise(n), 400), env(n, 0.001, 0.05)), 0.6)), 1.8)


def heartbeat():
    n = secs(1.0)
    a = thump(60, 0.3)
    b = thump(52, 0.3)
    out = [0.0] * n
    for i, s in enumerate(a):
        out[i] += s
    off = secs(0.24)
    for i, s in enumerate(b):
        if off + i < n:
            out[off + i] += s * 0.7
    return out


def card(kind):
    n = secs(0.25 if kind == "deal" else 0.18)
    src = bandpass(noise(n), 3200 if kind == "deal" else 2400, 1.0)
    return mul(src, env(n, 0.003, 0.035 if kind == "deal" else 0.025))


def mag_slap():
    n = secs(0.3)
    click = mul(bandpass(noise(n), 2800, 5), env(n, 0.0003, 0.02))
    body = mul(sweep_sine(n, 400, 180, 20), env(n, 0.0005, 0.03))
    return mix((click, 1.0), (body, 0.6))


def wind_loop():
    n = secs(12.0)
    src = noise(n)
    lfo = [600 + 450 * (0.5 + 0.5 * math.sin(2 * math.pi * i / n * 3)) * (0.7 + 0.3 * math.sin(2 * math.pi * i / n * 7)) for i in range(n)]
    w = lowpass(lowpass(src, lfo), lfo)
    amp = [0.6 + 0.4 * math.sin(2 * math.pi * i / n * 2 + 1.0) for i in range(n)]
    w = mul(w, amp)
    # Crossfade the ends so the loop is seamless.
    fade = secs(1.0)
    for i in range(fade):
        t = i / fade
        w[i] = w[i] * t + w[n - fade + i] * (1 - t)
    return w[: n - fade]


def fire_loop():
    n = secs(6.0)
    base = mul(lowpass(noise(n), 500), [0.35] * n)
    hiss = mul(bandpass(noise(n), 3000, 0.8), [0.08] * n)
    pops = [0.0] * n
    for _ in range(140):
        t = rng.randint(0, n - 3000)
        ln = rng.randint(200, 1200)
        burst = mul(bandpass(noise(ln), rng.uniform(1500, 5000), 4), env(ln, 0.0002, 0.004))
        g = rng.uniform(0.2, 1.0)
        for i, s in enumerate(burst):
            pops[t + i] += s * g
    out = mix((base, 1.0), (hiss, 1.0), (pops, 0.8))
    fade = secs(0.5)
    for i in range(fade):
        t = i / fade
        out[i] = out[i] * t + out[n - fade + i] * (1 - t)
    return out[: n - fade]


def rumble_emerge():
    n = secs(1.4)
    r = mul(lowpass(lowpass(noise(n), 180), 180), [math.sin(math.pi * min(1, i / n)) for i in range(n)])
    grit = mul(bandpass(noise(n), 1100, 2), env(n, 0.3, 0.3))
    return sat(mix((r, 3.0), (grit, 0.4)), 1.5)


def codex_open():
    """A rising arcane swell: airy whoosh, choir-like chord, bright bell."""
    n = secs(2.6)
    swell = mul(whoosh(1.4, 200, 5000) + [0.0] * (n - secs(1.4)), [1.0] * n)
    chord = [0.0] * n
    for f, a in [(220.0, 0.5), (277.18, 0.4), (329.63, 0.4), (440.0, 0.3), (659.25, 0.2)]:
        for i in range(n):
            t = i / SR
            vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.2 * t)
            chord[i] += a * math.sin(2 * math.pi * f * vib * t) * min(1.0, t / 0.9) * math.exp(-max(0.0, t - 1.2) / 0.7)
    sparkle = [0.0] * n
    for k in range(14):
        st = secs(0.5 + k * 0.08 + rng.uniform(0, 0.05))
        b = bell(rng.choice([1760, 2093, 2349, 2637, 3136]), secs(0.6), 0.15)
        for i, v in enumerate(b):
            if st + i < n:
                sparkle[st + i] += v * 0.25
    hit = pad(bell(880, secs(1.6), 0.8), 1.05)
    hit = hit + [0.0] * (n - len(hit))
    return mix((swell, 0.9), (chord, 1.0), (sparkle, 1.0), (hit[:n], 0.7))


def card_choose():
    """Claiming a card: deep thump, bright chime, rising shimmer."""
    n = secs(2.4)
    boom = mul(sweep_sine(n, 110, 40, 6), env(n, 0.002, 0.35))
    chime = [0.0] * n
    for k, f in enumerate([523.25, 783.99, 1046.5, 1567.98]):
        st = secs(k * 0.045)
        b = bell(f, n - st, 1.1)
        for i, v in enumerate(b):
            chime[st + i] += v * (0.8 - k * 0.12)
    rise = mul(whoosh(0.9, 400, 7000) + [0.0] * (n - secs(0.9)), [1.0] * n)
    sparkle = mul(bandpass(noise(n), 7000, 1.5), env(n, 0.05, 0.5))
    return sat(mix((boom, 1.3), (chime, 1.0), (rise, 0.5), (sparkle, 0.35)), 1.3)


def card_hover():
    n = secs(0.35)
    return mul(bell(1975.5, n, 0.08), env(n, 0.001, 10.0))


def gun_ember(v):
    """Ember rifle: punchy crack plus a descending fiery zap."""
    base = gun_shot(v)
    n = len(base)
    zap = mul(sweep_sine(n, 1400 + v * 80, 180, 14), env(n, 0.0005, 0.05))
    fizz = mul(bandpass(noise(n), 4500, 2), env(n, 0.002, 0.08))
    return sat(mix((base, 0.8), (zap, 0.5), (fizz, 0.3)), 1.4)


def gun_heavy(v):
    """Heavy rifle: deeper boom and longer echo tail."""
    n = secs(1.0)
    shot = gun_shot(v) + [0.0] * (n - secs(0.55))
    boom = mul(sweep_sine(n, 110, 34, 10), env(n, 0.001, 0.16))
    echo = mul(lowpass(noise(n), 500), [math.exp(-max(0, i - secs(0.12)) / secs(0.35)) * (0.0 if i < secs(0.12) else 1.0) for i in range(n)])
    return sat(mix((shot, 0.9), (boom, 1.2), (echo, 0.35)), 1.6)


def level_up_b():
    """Ember surge: a rising whoosh into a big warm chord."""
    n = secs(2.4)
    rise = whoosh(0.8, 150, 6000) + [0.0] * (n - secs(0.8))
    chord = [0.0] * n
    st = secs(0.62)
    for f in [261.63, 329.63, 392.0, 523.25, 659.25]:
        b = bell(f, n - st, 1.2)
        for i, v in enumerate(b):
            chord[st + i] += v * 0.5
    boom = pad(mul(sweep_sine(secs(1.0), 90, 40, 5), env(secs(1.0), 0.002, 0.25)), 0.62)
    boom = boom + [0.0] * (n - len(boom))
    return mix((rise, 0.6), (chord, 1.0), (boom, 0.9))


def card_choose_b():
    """Fire burst: a whoomph of flame and a low choir swell."""
    n = secs(2.6)
    whoomph = mul(lowpass(noise(n), [3000 * math.exp(-i / SR * 2.5) + 200 for i in range(n)]), env(n, 0.01, 0.4))
    choir = [0.0] * n
    for f in [146.83, 220.0, 293.66, 369.99]:
        for i in range(n):
            t = i / SR
            choir[i] += 0.3 * math.sin(2 * math.pi * f * (1 + 0.003 * math.sin(2 * math.pi * 5 * t)) * t) * min(1.0, t / 0.25) * math.exp(-max(0.0, t - 0.6) / 0.8)
    crackle = fire_loop()[: n]
    crackle = [c * math.exp(-i / secs(0.8)) for i, c in enumerate(crackle)] + [0.0] * max(0, n - len(crackle))
    return sat(mix((whoomph, 1.4), (choir, 1.0), (crackle[:n], 0.8)), 1.3)


def codex_open_b():
    """Ancient tome: deep hum, page rustle, distant bell."""
    n = secs(2.4)
    hum = [0.0] * n
    for f, a in [(65.4, 0.7), (98.0, 0.5), (130.8, 0.35)]:
        for i in range(n):
            t = i / SR
            hum[i] += a * math.sin(2 * math.pi * f * t) * min(1.0, t / 0.6) * math.exp(-max(0.0, t - 1.3) / 0.6)
    rustle = [0.0] * n
    for k in range(5):
        st = secs(0.3 + k * 0.12)
        c = card("deal")
        for i, v in enumerate(c):
            if st + i < n:
                rustle[st + i] += v * 0.6
    bellb = pad(bell(659.25, secs(1.4), 0.7), 0.9)
    bellb = bellb + [0.0] * (n - len(bellb))
    return mix((hum, 1.0), (rustle, 1.0), (bellb[:n], 0.6))


def xp_pluck(v):
    n = secs(0.35)
    f = [880, 988, 1109][v]
    out = []
    for i in range(n):
        t = i / SR
        out.append((math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)) * math.exp(-t / 0.06))
    return out


# ---------------------------------------------------------- bell-free set

def warm_pad(freqs, n, attack, release_at, release):
    out = [0.0] * n
    for f, a in freqs:
        for i in range(n):
            t = i / SR
            vib = 1.0 + 0.003 * math.sin(2 * math.pi * 4.7 * t + f)
            w = math.sin(2 * math.pi * f * vib * t) + 0.25 * math.sin(4 * math.pi * f * vib * t)
            g = min(1.0, t / attack) * (math.exp(-max(0.0, t - release_at) / release))
            out[i] += a * w * g
    return lowpass(out, 1800)


def ember_puff(dur=0.28, f=900):
    """Soft fiery puff: a breath of filtered noise with a warm sub."""
    n = secs(dur)
    puff = mul(lowpass(noise(n), [f * (1 - i / n) + 200 for i in range(n)]), [math.sin(math.pi * min(1.0, i / n)) ** 2 for i in range(n)])
    sub = mul(sweep_sine(n, 220, 140, 3), env(n, 0.01, dur * 0.4))
    return mix((puff, 1.0), (sub, 0.25))


def xp_soft(v):
    return ember_puff(0.22, [900, 1100, 1300][v])


def level_up_warm():
    n = secs(2.4)
    rise = whoosh(0.9, 150, 3500) + [0.0] * (n - secs(0.9))
    pad_ = warm_pad([(130.81, 0.6), (196.0, 0.45), (261.63, 0.35), (329.63, 0.25)], n, 0.6, 1.3, 0.7)
    whoomph = pad(mul(lowpass(noise(secs(1.2)), [2200 * math.exp(-i / SR * 3) + 150 for i in range(secs(1.2))]), env(secs(1.2), 0.01, 0.3)), 0.75)
    whoomph = whoomph + [0.0] * (n - len(whoomph))
    return mix((rise, 0.6), (pad_, 1.0), (whoomph[:n], 0.8))


def codex_warm():
    n = secs(2.6)
    hum = warm_pad([(65.41, 0.8), (98.0, 0.55), (130.81, 0.4), (196.0, 0.2)], n, 0.8, 1.6, 0.6)
    swell = whoosh(1.6, 120, 2800) + [0.0] * (n - secs(1.6))
    pages = [0.0] * n
    for k in range(4):
        st = secs(0.35 + k * 0.14)
        c = card("deal")
        for i, v in enumerate(c):
            if st + i < n:
                pages[st + i] += v * 0.5
    crackle = [c * min(1.0, i / secs(0.8)) * math.exp(-max(0, i - secs(1.4)) / secs(0.5)) for i, c in enumerate(fire_loop()[:n])]
    crackle += [0.0] * (n - len(crackle))
    return mix((hum, 1.0), (swell, 0.5), (pages, 0.8), (crackle[:n], 0.35))


def card_claim_warm():
    n = secs(2.4)
    thump_ = mul(sweep_sine(n, 95, 38, 6), env(n, 0.002, 0.3))
    flame = mul(lowpass(noise(n), [3200 * math.exp(-i / SR * 2.2) + 180 for i in range(n)]), env(n, 0.012, 0.45))
    pad_ = warm_pad([(146.83, 0.5), (220.0, 0.4), (293.66, 0.3)], n, 0.15, 0.7, 0.8)
    crackle = [c * math.exp(-i / secs(0.9)) for i, c in enumerate(fire_loop()[:n])]
    crackle += [0.0] * (n - len(crackle))
    return sat(mix((thump_, 1.3), (flame, 1.2), (pad_, 0.8), (crackle[:n], 0.6)), 1.3)


def card_hover_soft():
    n = secs(0.18)
    return mul(bandpass(noise(n), 1800, 1.2), env(n, 0.004, 0.03))


def mastery_warm():
    n = secs(3.0)
    boom = mul(sweep_sine(n, 70, 32, 3), env(n, 0.01, 0.6))
    rise = whoosh(1.0, 100, 4000) + [0.0] * (n - secs(1.0))
    pad_ = warm_pad([(98.0, 0.6), (146.83, 0.5), (196.0, 0.4), (293.66, 0.25)], n, 0.4, 1.8, 0.8)
    return mix((boom, 1.2), (rise, 0.5), (pad_, 1.0))


def growl(base, n_s, rough=1.0, seed=0):
    """Throaty growl: jittery low saw through a vocal bandpass with breath."""
    r = random.Random(seed)
    n = secs(n_s)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = base * (1 + 0.12 * math.sin(2 * math.pi * 1.3 * t + seed)) + r.uniform(-4, 4) * rough
        ph += 2 * math.pi * f / SR
        saw = (ph / math.pi) % 2.0 - 1.0
        trem = 0.6 + 0.4 * math.sin(2 * math.pi * (17 + seed) * t + r.uniform(0, 0.3))
        out.append(saw * trem)
    voiced = mix((bandpass(out, base * 5.5, 1.2), 1.4), (bandpass(out, base * 11, 2.0), 0.5))
    breath = bandpass(noise(n), 900, 1.0)
    shape = [min(1.0, i / secs(0.12)) * (1.0 - max(0.0, (i - n * 0.7) / (n * 0.3))) for i in range(n)]
    return sat(mul(mix((voiced, 1.0), (breath, 0.35 * rough)), shape), 2.0)


def hound_growl(v):
    return growl(48 + v * 6, 1.3, 1.0, v + 3)


def breath_loop(base, seconds, seed):
    """Seamless loop of rasping breaths with a growl underneath."""
    n = secs(seconds)
    out = [0.0] * n
    t = 0.0
    r = random.Random(seed)
    while t < seconds - 0.3:
        inhale = r.uniform(0.6, 0.9)
        g = growl(base * r.uniform(0.9, 1.1), inhale, 0.7, seed + int(t * 10))
        rasp = mul(bandpass(noise(len(g)), r.uniform(700, 1100), 1.5), [0.5] * len(g))
        st = secs(t)
        for i in range(len(g)):
            if st + i < n:
                out[st + i] += g[i] * 0.8 + rasp[i] * 0.4 * math.sin(math.pi * i / len(g))
        t += inhale + r.uniform(0.3, 0.7)
    fade = secs(0.4)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


# ---------------------------------------------------------- fantasy set
# Plucked harp (Karplus-Strong), an airy choir, soft shimmer and a hall
# reverb. No saturation, no bells, nothing harsh.

def harp(f, dur, bright=0.5):
    n = secs(dur)
    period = max(2, int(SR / f))
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    buf = lowpass(buf, 2000 + bright * 4000)
    out = []
    idx = 0
    decay = 0.996
    for i in range(n):
        v = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = decay * 0.5 * (v + nxt)
        out.append(v)
        idx = (idx + 1) % period
    return mul(out, [min(1.0, i / 60.0) for i in range(n)])


def choir(freqs, dur, attack=0.5, release=0.8):
    n = secs(dur)
    out = [0.0] * n
    for f, a in freqs:
        for voice in (-0.006, 0.0, 0.007):
            ph = rng.uniform(0, 6.28)
            for i in range(n):
                t = i / SR
                ff = f * (1 + voice) * (1 + 0.004 * math.sin(2 * math.pi * 5.0 * t + ph))
                saw = ((t * ff + ph) % 1.0) * 2 - 1
                out[i] += saw * a
    # "aah" formants
    voiced = mix((bandpass(out, 700, 2.5), 1.0), (bandpass(out, 1150, 3.0), 0.6), (bandpass(out, 2600, 4.0), 0.25))
    shape = [min(1.0, (i / SR) / attack) * math.exp(-max(0.0, i / SR - (dur - release)) / (release * 0.5)) for i in range(n)]
    return mul(voiced, shape)


def shimmer(dur, density=30, level=0.25):
    n = secs(dur)
    out = [0.0] * n
    for _ in range(int(density * dur)):
        st = rng.randint(0, max(1, n - secs(0.3)))
        g = mul(bandpass(noise(secs(0.25)), rng.uniform(5000, 9000), 8), env(secs(0.25), 0.04, 0.06))
        for i, v in enumerate(g):
            if st + i < n:
                out[st + i] += v * level
    return out


def reverb(x, wet=0.35, size=1.0):
    n = len(x) + secs(1.8 * size)
    dry = x + [0.0] * (n - len(x))
    combs = [int(d * size) for d in (1557, 1617, 1491, 1422, 1277, 1356)]
    acc = [0.0] * n
    for d in combs:
        d = int(d * SR / 44100)
        buf = [0.0] * n
        fb = 0.84
        for i in range(n):
            y = dry[i] + (buf[i - d] * fb if i >= d else 0.0)
            buf[i] = y
            acc[i] += y
    for d in (225, 556, 441):
        d = int(d * SR / 44100)
        y = [0.0] * n
        for i in range(n):
            xd = acc[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -0.5 * acc[i] + xd + 0.5 * yd
        acc = y
    acc = lowpass(acc, 5000)
    m = max(1e-6, max(abs(v) for v in acc))
    k = wet * max(abs(v) for v in x) / m
    return [dry[i] + acc[i] * k for i in range(n)]


def place(track, t, src, g=1.0):
    st = secs(t)
    if len(track) < st + len(src):
        track.extend([0.0] * (st + len(src) - len(track)))
    for i, v in enumerate(src):
        track[st + i] += v * g


def codex_fantasy():
    t = []
    place(t, 0.0, choir([(220.0, 0.25), (277.18, 0.2), (329.63, 0.2)], 2.4, 0.7, 0.9), 0.9)
    for k, f in enumerate([220.0, 277.18, 329.63, 440.0, 554.37, 659.25, 880.0]):
        place(t, 0.15 + k * 0.07, harp(f, 1.6, 0.4), 0.45)
    place(t, 0.3, shimmer(1.8, 22, 0.18), 1.0)
    return reverb(t, 0.45, 1.1)


def flute(f, dur, vib=0.006):
    """Breathy flute-like tone: soft sine + a little breath noise."""
    n = secs(dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        ff = f * (1 + vib * math.sin(2 * math.pi * 5.5 * t) * min(1.0, t / 0.2))
        ph += 2 * math.pi * ff / SR
        out.append(math.sin(ph) + 0.12 * math.sin(2 * ph))
    breath = mul(bandpass(noise(n), f * 2, 3), [0.08] * n)
    shape = [min(1.0, (i / SR) / 0.06) * math.exp(-max(0.0, i / SR - dur * 0.5) / (dur * 0.35)) for i in range(n)]
    return mul(mix((out, 1.0), (breath, 1.0)), shape)


def claim_fantasy():
    """Whimsical claim: a quick rising harp flourish, a little flute
    answer and fairy-dust sparkles. Light and quiet, no low boom."""
    t = []
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0]
    for k, f in enumerate(notes):
        place(t, k * 0.045, harp(f, 0.9, 0.6), 0.35)
    place(t, 0.3, flute(1046.5, 0.5), 0.22)
    place(t, 0.48, flute(1318.5, 0.7), 0.2)
    place(t, 0.05, shimmer(1.1, 40, 0.16), 1.0)
    return reverb(t, 0.35, 0.6)


def hover_fantasy():
    t = []
    place(t, 0.0, harp(rng.choice([1318.5, 1568.0]), 0.5, 0.2), 0.25)
    place(t, 0.0, shimmer(0.3, 15, 0.12), 1.0)
    return reverb(t, 0.25, 0.5)


def deal_fantasy():
    t = []
    place(t, 0.0, card("deal"), 0.5)
    place(t, 0.02, harp(659.25, 0.6, 0.2), 0.12)
    return t


def levelup_fantasy():
    t = []
    for k, f in enumerate([392.0, 493.88, 587.33, 783.99]):
        place(t, k * 0.09, harp(f, 1.4, 0.5), 0.45)
    place(t, 0.2, choir([(196.0, 0.2), (293.66, 0.18), (392.0, 0.14)], 1.8, 0.3, 0.8), 0.8)
    place(t, 0.2, shimmer(1.2, 20, 0.15), 1.0)
    return reverb(t, 0.4, 1.0)


def mastery_fantasy():
    """A brighter, longer flourish: harp run, flute melody, sparkles."""
    t = []
    for k, f in enumerate([392.0, 493.88, 587.33, 783.99, 987.77, 1174.66, 1567.98]):
        place(t, k * 0.06, harp(f, 1.2, 0.55), 0.32)
    for k, (f, d) in enumerate([(783.99, 0.3), (987.77, 0.3), (1174.66, 0.6)]):
        place(t, 0.45 + k * 0.2, flute(f, d + 0.3), 0.2)
    place(t, 0.1, choir([(392.0, 0.12), (493.88, 0.1), (587.33, 0.08)], 1.8, 0.4, 0.7), 0.35)
    place(t, 0.2, shimmer(1.6, 40, 0.15), 1.0)
    return reverb(t, 0.35, 0.7)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    jobs = {
        "boss_step": boss_step, "emerge_rumble": rumble_emerge, "slam_boom": slam_boom,
        "hound_snarl_1": lambda: snarl(0), "hound_snarl_2": lambda: snarl(1), "hound_snap": snap,
        "hound_growl_1": lambda: hound_growl(0), "hound_growl_2": lambda: hound_growl(1),
        "ghoul_breath_loop": lambda: breath_loop(62, 7.0, 11), "hound_breath_loop": lambda: breath_loop(46, 6.0, 23),
        "colossus_breath_loop": lambda: breath_loop(34, 8.0, 41),
        "heartbeat": heartbeat,
        "card_flip": lambda: card("flip"),
        "xp_soft_1": lambda: xp_soft(0), "xp_soft_2": lambda: xp_soft(1), "xp_soft_3": lambda: xp_soft(2),
        "codex_fantasy": codex_fantasy, "claim_fantasy": claim_fantasy, "hover_fantasy": hover_fantasy,
        "deal_fantasy": deal_fantasy, "levelup_fantasy": levelup_fantasy, "mastery_fantasy": mastery_fantasy,
        "wind_loop": wind_loop, "fire_loop": fire_loop,
    }
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sfx_world  # water, ambience and world sounds
    jobs.update(sfx_world.jobs())
    only = set(sys.argv[2:])
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        gain = {"wind_loop": 0.5, "fire_loop": 0.6, "card_flip": 0.5, "card_deal": 0.6, "card_hover": 0.35, "card_hover_soft": 0.3, "hover_fantasy": 0.35, "deal_fantasy": 0.5, "codex_fantasy": 0.75, "claim_fantasy": 0.55, "levelup_fantasy": 0.7, "mastery_fantasy": 0.6, "xp_soft_1": 0.5, "xp_soft_2": 0.5, "xp_soft_3": 0.5}.get(name, sfx_world.GAINS.get(name, 1.0))
        write(os.path.join(out, name + ".wav"), fn(), gain)
        print("wrote", name)


if __name__ == "__main__":
    main()
