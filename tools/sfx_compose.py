"""Layers recorded sources + shaped noise into finished game sounds.

Usage: python3 tools/sfx_compose.py
Reads from assets/audio/impacts and assets/audio/sources, writes 48 kHz mono
WAVs to assets/audio/composed/.
"""
import math
import os
import random
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_synth as syn  # noqa: E402  (filters and noise helpers)

SR = 48000
syn.SR = SR
rng = random.Random(7)
OUT = "assets/audio/composed"


def load(path):
    w = wave.open(path)
    ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    x = []
    for i in range(0, len(raw), ch * sw):
        acc = 0.0
        for c in range(ch):
            b = raw[i + c * sw: i + (c + 1) * sw]
            acc += int.from_bytes(b, "little", signed=True) / float(1 << (8 * sw - 1))
        x.append(acc / ch)
    if sr != SR:
        ratio = sr / SR
        x = [x[min(int(i * ratio), len(x) - 1)] for i in range(int(len(x) / ratio))]
    return x


def at(track, t, src, gain=1.0):
    st = int(t * SR)
    need = st + len(src)
    if len(track) < need:
        track.extend([0.0] * (need - len(track)))
    for i, v in enumerate(src):
        track[st + i] += v * gain


def trim(x, dur, fade=0.04):
    n = min(len(x), int(dur * SR))
    y = x[:n]
    f = int(fade * SR)
    for i in range(min(f, n)):
        y[n - 1 - i] *= i / f
    return y


def burst(n_s, lp, decay, hp=0.0):
    n = int(n_s * SR)
    x = syn.noise(n)
    if lp:
        x = syn.lowpass(x, lp)
    if hp:
        x = syn.highpass(x, hp)
    return syn.mul(x, syn.env(n, 0.0005, decay))


def thump(f0, f1, dur, decay):
    n = int(dur * SR)
    return syn.mul(syn.sweep_sine(n, f0, f1, 10), syn.env(n, 0.001, decay))


def write(name, x, peak=0.95):
    m = max(1e-6, max(abs(v) for v in x))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v / m * peak)) * 32767)) for v in x))
    print("wrote", name)


def main():
    os.makedirs(OUT, exist_ok=True)
    I = "assets/audio/impacts/"
    S = "assets/audio/sources/"
    # Axe: body blow + bone crunch + dry crack + low thud, slightly saturated.
    for k in range(4):
        t = []
        at(t, 0.0, load(I + "punch_heavy_%d.wav" % k), 1.0)
        at(t, 0.004, syn.highpass(trim(load(S + "crunch_%d.wav" % (k + 1)), 0.45), 350), 0.85)
        at(t, 0.0, burst(0.05, 0, 0.012, 2500), 0.55)
        at(t, 0.0, thump(95, 42, 0.5, 0.11), 0.8)
        at(t, 0.01, burst(0.3, 900, 0.06), 0.35)
        write("axe_crunch_%d" % (k + 1), syn.sat(trim(t, 0.7), 1.6))
    # Finisher: everything heavier plus falling grit.
    t = []
    at(t, 0.0, load(I + "punch_heavy_4.wav"), 1.0)
    at(t, 0.0, syn.highpass(trim(load(S + "crunch_5.wav"), 0.6), 250), 0.9)
    at(t, 0.0, thump(80, 30, 1.0, 0.25), 1.1)
    at(t, 0.0, burst(0.06, 0, 0.015, 2200), 0.6)
    for _ in range(25):
        at(t, rng.uniform(0.04, 0.5), burst(0.03, 3000, 0.006, 800), rng.uniform(0.08, 0.25))
    write("axe_crunch_heavy", syn.sat(trim(t, 1.1), 1.5))
    # Getting hit: a dull, muffled body blow with a soft crunch underneath.
    for k in range(3):
        t = []
        at(t, 0.0, syn.lowpass(load(I + "punch_medium_%d.wav" % k), 1300), 1.0)
        at(t, 0.0, syn.lowpass(trim(load(S + "crunch_%d.wav" % (k + 2)), 0.3), 1800), 0.35)
        at(t, 0.0, thump(80, 45, 0.35, 0.07), 0.5)
        write("player_hit_%d" % (k + 1), trim(t, 0.5), 0.75)
    # Combat roll: cloth and light armour tumbling, shoulder then feet touch down.
    for k in range(2):
        t = []
        at(t, 0.0, load(S + "cloth-heavy.wav"), 0.9)
        at(t, 0.06, load(S + "armor-light.wav"), 0.35)
        at(t, 0.17 + k * 0.02, syn.mix((burst(0.2, 380, 0.05), 1.0), (thump(75, 50, 0.2, 0.05), 0.6)), 0.75)
        at(t, 0.3, load(S + "cloth.wav"), 0.55)
        at(t, 0.5, syn.mix((burst(0.2, 420, 0.04), 1.0), (burst(0.06, 0, 0.01, 2500), 0.15)), 0.55)
        at(t, 0.52, load(S + ("chainmail1.wav" if k == 0 else "chainmail2.wav")), 0.22)
        write("roll_body_%d" % (k + 1), trim(t, 0.95))
    # Jump: a quick leather/armour creak, nothing else.
    for k in range(2):
        t = []
        at(t, 0.0, trim(load(S + ("cloth-heavy.wav" if k == 0 else "cloth.wav")), 0.3), 0.7)
        at(t, 0.02, trim(load(S + "armor-light.wav"), 0.3), 0.4)
        write("jump_gear_%d" % (k + 1), trim(t, 0.35), 0.6)
    # Landing: boot heel on packed dirt, a little grit, a soft gear settle.
    for k in range(3):
        t = []
        at(t, 0.0, burst(0.18, 520 + k * 60, 0.035), 1.0)
        at(t, 0.0, burst(0.05, 0, 0.012, 2000 + k * 300), 0.28)
        at(t, 0.015, syn.lowpass(burst(0.12, 1400, 0.03), 900), 0.4)
        at(t, 0.03, trim(load(S + "armor-light.wav"), 0.3), 0.3)
        at(t, 0.05, trim(load(S + "chainmail2.wav"), 0.35), 0.15)
        write("land_boot_%d" % (k + 1), trim(t, 0.4), 0.7)
    # Footsteps: boot heel + toe on packed earth with buckles and mail shifting.
    for k in range(4):
        t = []
        at(t, 0.0, burst(0.12, 420 + k * 50, 0.022), 1.0)
        at(t, 0.0, burst(0.03, 0, 0.006, 2600 + k * 200), 0.14)
        at(t, 0.06, burst(0.08, 900, 0.015), 0.35)
        at(t, 0.02, trim(load(S + ("chainmail1.wav" if k % 2 else "chainmail2.wav")), 0.18), 0.1)
        at(t, 0.0, trim(load(S + "armor-light.wav"), 0.15), 0.12)
        write("step_gear_%d" % (k + 1), trim(t, 0.3), 0.5)


if __name__ == "__main__":
    main()
