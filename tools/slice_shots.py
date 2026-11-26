"""Slices individual gunshots out of long multi-shot recordings.

Usage: python3 tools/slice_shots.py <in.wav> <out_prefix> [max_shots] [length_s]
Reads 16/24-bit PCM, mixes to mono, finds shot onsets, writes 48 kHz 16-bit WAVs.
"""
import struct
import sys
import wave


def read(path):
    w = wave.open(path)
    ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
    raw = w.readframes(n)
    out = []
    step = ch * sw
    for i in range(0, len(raw), step):
        acc = 0.0
        for c in range(ch):
            b = raw[i + c * sw: i + (c + 1) * sw]
            if sw == 3:
                v = int.from_bytes(b, "little", signed=True) / 8388608.0
            elif sw == 2:
                v = int.from_bytes(b, "little", signed=True) / 32768.0
            else:
                v = struct.unpack("<f", b)[0]
            acc += v
        out.append(acc / ch)
    return out, sr


def main():
    src, prefix = sys.argv[1], sys.argv[2]
    max_shots = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    length = float(sys.argv[4]) if len(sys.argv) > 4 else 0.9
    x, sr = read(src)
    win = sr // 200
    env = [max(abs(v) for v in x[i:i + win]) for i in range(0, len(x) - win, win)]
    peak = max(env)
    onsets = []
    quiet = 0
    for k, e in enumerate(env):
        if e < peak * 0.06:
            quiet += 1
        elif e > peak * 0.35 and quiet >= 20:
            onsets.append(max(0, k * win - win))
            quiet = 0
        else:
            quiet = 0 if e > peak * 0.06 else quiet
    if not onsets:
        onsets = [0]
    n = int(length * sr)
    dec = max(1, sr // 48000)
    written = 0
    for o in onsets[:max_shots]:
        seg = x[o:o + n]
        m = max(1e-6, max(abs(v) for v in seg))
        fade = int(0.08 * sr)
        for i in range(fade):
            seg[len(seg) - fade + i] *= 1.0 - i / fade
        seg = [sum(seg[i:i + dec]) / dec for i in range(0, len(seg) - dec + 1, dec)]
        path = "%s_%d.wav" % (prefix, written + 1)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr // dec)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v / m * 0.95)) * 32767)) for v in seg))
        written += 1
        print(path, "onset %.2fs" % (o / sr))


if __name__ == "__main__":
    main()
