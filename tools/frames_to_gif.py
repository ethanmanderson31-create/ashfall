"""Convert raw RGB8 frame dumps (from Godot capture modes) into looping GIFs.

Usage: python3 tools/frames_to_gif.py <frames.rgb> <out.gif> <width> <height> [delay_cs]
Pure standard library: median-cut palette + LZW encoder.
"""
import struct
import sys


def median_cut(pixels, n=256):
    boxes = [pixels]
    while len(boxes) < n:
        # Split the box with the widest channel range.
        best_i, best_range, best_ch = -1, -1, 0
        for i, b in enumerate(boxes):
            if len(b) < 2:
                continue
            for ch in range(3):
                vals = [p[ch] for p in b]
                r = max(vals) - min(vals)
                if r > best_range:
                    best_i, best_range, best_ch = i, r, ch
        if best_i < 0 or best_range <= 0:
            break
        b = sorted(boxes.pop(best_i), key=lambda p: p[best_ch])
        mid = len(b) // 2
        boxes += [b[:mid], b[mid:]]
    pal = []
    for b in boxes:
        k = len(b)
        pal.append(tuple(sum(p[c] for p in b) // k for c in range(3)))
    while len(pal) < n:
        pal.append((0, 0, 0))
    return pal


def lzw(indices, min_size=8):
    clear = 1 << min_size
    eoi = clear + 1
    out = bytearray()
    bitbuf = 0
    bitcnt = 0
    size = min_size + 1

    def emit(code):
        nonlocal bitbuf, bitcnt
        bitbuf |= code << bitcnt
        bitcnt += size
        while bitcnt >= 8:
            out.append(bitbuf & 0xFF)
            bitbuf >>= 8
            bitcnt -= 8

    table = {}
    nxt = eoi + 1
    emit(clear)
    w = indices[0]
    for k in indices[1:]:
        key = (w << 8) | k
        if key in table:
            w = table[key]
            continue
        emit(w)
        if nxt < 4096:
            table[key] = nxt
            nxt += 1
            if nxt > (1 << size) and size < 12:
                size += 1
        else:
            emit(clear)
            table = {}
            nxt = eoi + 1
            size = min_size + 1
        w = k
    emit(w)
    emit(eoi)
    if bitcnt:
        out.append(bitbuf & 0xFF)
    return bytes(out)


def main():
    src, dst, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    delay = int(sys.argv[5]) if len(sys.argv) > 5 else 3
    data = open(src, "rb").read()
    fsize = w * h * 3
    frames = [data[i:i + fsize] for i in range(0, len(data) - fsize + 1, fsize)]
    sample = []
    for fi in range(0, len(frames), 6):
        f = frames[fi]
        for i in range(0, fsize, 3 * 37):
            sample.append((f[i], f[i + 1], f[i + 2]))
    pal = median_cut(sample, 256)
    cache = {}

    def nearest(key):
        r, g, b = (key >> 10) << 3, ((key >> 5) & 31) << 3, (key & 31) << 3
        best, bd = 0, 1 << 30
        for i, (pr, pg, pb) in enumerate(pal):
            d = (pr - r) ** 2 * 3 + (pg - g) ** 2 * 4 + (pb - b) ** 2 * 2
            if d < bd:
                bd, best = d, i
        cache[key] = best
        return best

    out = bytearray(b"GIF89a")
    out += struct.pack("<HHBBB", w, h, 0xF7, 0, 0)
    for c in pal:
        out += bytes(c)
    out += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
    for f in frames:
        idx = bytearray(w * h)
        j = 0
        for i in range(0, fsize, 3):
            key = ((f[i] >> 3) << 10) | ((f[i + 1] >> 3) << 5) | (f[i + 2] >> 3)
            v = cache.get(key)
            if v is None:
                v = nearest(key)
            idx[j] = v
            j += 1
        out += b"\x21\xF9\x04\x04" + struct.pack("<H", delay) + b"\x00\x00"
        out += b"\x2C" + struct.pack("<HHHHB", 0, 0, w, h, 0)
        out += b"\x08"
        comp = lzw(idx)
        for i in range(0, len(comp), 255):
            chunk = comp[i:i + 255]
            out += bytes([len(chunk)]) + chunk
        out += b"\x00"
    out += b"\x3B"
    open(dst, "wb").write(out)
    print(dst, len(frames), "frames", len(out) // 1024, "KB")


if __name__ == "__main__":
    main()
