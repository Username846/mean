#!/usr/bin/env python3
"""Procedural chiptune composer for Bug My Brother.

Renders one looping track per scene into assets/music/*.ogg.
Usage: python3 tools/gen_music.py
Requires numpy and ffmpeg (with libvorbis).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music")

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "harm": [0, 2, 3, 5, 7, 8, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixo": [0, 2, 4, 5, 7, 9, 10],
}


def mtof(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


# ---------------------------------------------------------------- synthesis

def tone(kind, midi, dur, vol=1.0, duty=0.5, a=0.005, d=0.08, s=0.6, r=0.05,
         vib=0.0, slide=0.0):
    n = max(1, int(dur * SR))
    t = np.arange(n) / SR
    f = mtof(midi) * np.ones(n)
    if slide:
        f *= 2 ** (slide * np.minimum(t / 0.06, 1.0) / 12.0 - slide / 12.0)
    if vib:
        f *= 2 ** (vib * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.25, 1) / 12.0)
    ph = np.cumsum(f) / SR % 1.0
    if kind == "square":
        w = np.where(ph < duty, 1.0, -1.0)
    elif kind == "tri":
        w = 4 * np.abs(ph - 0.5) - 1
    elif kind == "saw":
        w = 2 * ph - 1
    elif kind == "sine":
        w = np.sin(2 * np.pi * ph)
    elif kind == "organ":
        w = (np.sin(2 * np.pi * ph) + 0.5 * np.sin(4 * np.pi * ph)
             + 0.25 * np.sin(6 * np.pi * ph)) / 1.75
    elif kind == "bell":
        w = (np.sin(2 * np.pi * ph) + 0.4 * np.sin(2 * np.pi * ph * 3.01)
             * np.exp(-t * 6)) / 1.4
    else:
        raise ValueError(kind)
    env = np.ones(n)
    na = max(1, int(a * SR))
    nd = max(1, int(d * SR))
    env[:na] = np.linspace(0, 1, na)[: n]
    if na < n:
        seg = env[na:na + nd]
        env[na:na + nd] = np.linspace(1, s, nd)[: len(seg)]
        env[na + nd:] = s
    nr = min(n, max(1, int(r * SR)))
    env[-nr:] *= np.linspace(1, 0, nr)
    return w * env * vol


def kick(vol=1.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t * 30)
    ph = np.cumsum(f) / SR
    return np.sin(2 * np.pi * ph) * np.exp(-t * 14) * vol


def snare(vol=1.0, rng=None):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return (noise * np.exp(-t * 22) * 0.7 + body * 0.5) * vol


def hat(vol=1.0, rng=None, open_=False):
    n = int((0.2 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    noise = np.diff(np.concatenate([[0], noise]))
    return noise * np.exp(-t * (12 if open_ else 70)) * 0.35 * vol


def clap(vol=1.0, rng=None):
    n = int(0.15 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    env = np.exp(-t * 25) + 0.6 * np.exp(-((t - 0.012) * 300) ** 2)
    return noise * env * 0.6 * vol


def add(buf, sig, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def wrap_add(buf, sig, start):
    """Add a signal, wrapping overflow back to the beginning (seamless loops)."""
    i = int(start * SR) % len(buf)
    j = i + len(sig)
    if j <= len(buf):
        buf[i:j] += sig
    else:
        k = len(buf) - i
        buf[i:] += sig[:k]
        buf[: j - len(buf)] += sig[k:]


# ---------------------------------------------------------------- composition

RHYTHMS_4 = [
    [(0, 4), (4, 2), (6, 2), (8, 4), (12, 4)],
    [(0, 2), (2, 2), (4, 2), (6, 2), (8, 4), (12, 2), (14, 2)],
    [(0, 6), (6, 2), (8, 6), (14, 2)],
    [(0, 3), (3, 3), (6, 2), (8, 8)],
    [(0, 2), (4, 2), (6, 2), (8, 2), (10, 2), (12, 4)],
    [(0, 4), (6, 2), (8, 2), (10, 2), (12, 4)],
    [(2, 2), (4, 2), (6, 2), (8, 2), (10, 2), (12, 2), (14, 2)],
]
RHYTHMS_3 = [
    [(0, 4), (4, 4), (8, 4)],
    [(0, 6), (6, 2), (8, 4)],
    [(0, 2), (2, 2), (4, 4), (8, 4)],
    [(0, 4), (4, 2), (6, 2), (8, 4)],
]


class Track:
    def __init__(self, spec):
        self.s = spec
        self.rng = np.random.default_rng(spec["seed"])
        self.beats = spec.get("beats", 4)
        self.steps = self.beats * 4
        self.step_t = 60.0 / spec["bpm"] / 4.0
        self.bars = spec.get("bars", 16)
        self.scale = SCALES[spec["scale"]]
        self.root = spec["root"]
        self.length = self.bars * self.steps * self.step_t
        self.buf = {k: np.zeros(int(self.length * SR) + 1)
                    for k in ("lead", "bass", "arp", "pad", "drum", "chord")}

    def st(self, bar, step):
        t = (bar * self.steps + step) * self.step_t
        swing = self.s.get("swing", 0.0)
        if swing and step % 2 == 1:
            t += swing * self.step_t
        return t

    def deg_to_midi(self, deg, base):
        L = len(self.scale)
        return base + 12 * (deg // L) + self.scale[deg % L]

    def chord_degs(self, chord):
        return [chord, chord + 2, chord + 4]

    def progression(self):
        a = self.s["prog"]
        b = self.s.get("prog_b", a)
        form = self.s.get("form", "AABA")
        out = []
        for part in form:
            src = a if part == "A" else b
            out += [src[i % len(src)] for i in range(4)]
        return (out * 8)[: self.bars]

    def make_phrase(self, chords, seed_off):
        rng = np.random.default_rng(self.s["seed"] + seed_off)
        pats = RHYTHMS_3 if self.beats == 3 else RHYTHMS_4
        pats = [pats[i] for i in self.s.get("rhythms", range(len(pats)))
                if i < len(pats)]
        notes = []
        cur = 7 + rng.integers(0, 3)
        for bi, ch in enumerate(chords):
            pat = pats[rng.integers(0, len(pats))]
            if bi == 3:
                pat = [(0, 4), (4, 4), (8, self.steps - 8)] if self.beats == 4 \
                    else [(0, 4), (4, 8)]
            ct = self.chord_degs(ch)
            for k, (stp, ln) in enumerate(pat):
                strong = stp % 4 == 0
                if strong or (bi == 3 and k == len(pat) - 1):
                    cands = [c + 7 * o for c in ct for o in (0, 1, 2)]
                    cands = [c for c in cands if abs(c - cur) <= 4] or cands
                    cur = int(rng.choice(cands))
                else:
                    cur += int(rng.choice([-2, -1, -1, 1, 1, 2]))
                cur = int(np.clip(cur, 3, 15))
                notes.append((bi, stp, ln, cur))
        return notes

    def render(self):
        s = self.s
        prog = self.progression()
        A = self.make_phrase(prog[0:4], 1)
        B = self.make_phrase(prog[4:8] if s.get("form", "AABA")[1] == "B"
                             else prog[8:12], 2)
        A2 = self.make_phrase(prog[0:4], 3)
        A2 = [n for n in A if n[0] < 3] + [n for n in A2 if n[0] == 3]
        form = s.get("form", "AABA")
        phrases = {"A": A, "B": B}
        mel = []
        for p, part in enumerate(form):
            src = phrases[part]
            if part == "A" and p == 1:
                src = A2
            for (bi, stp, ln, d) in src:
                mel.append((p * 4 + bi, stp, ln, d))

        lead = s.get("lead", ("square", 0.5))
        lead_oct = self.root + 12 * s.get("lead_oct", 1)
        lvol = s.get("lead_vol", 0.30)
        for (bar, stp, ln, d) in mel:
            if bar >= self.bars:
                continue
            dur = ln * self.step_t * s.get("legato", 0.9)
            m = self.deg_to_midi(d, lead_oct)
            sig = tone(lead[0], m, dur, lvol, duty=lead[1], vib=s.get("vib", 0.25),
                       d=0.1, s=s.get("lead_sus", 0.7), r=0.04,
                       slide=s.get("slide", 0.0))
            wrap_add(self.buf["lead"], sig, self.st(bar, stp))
            if s.get("echo_lead"):
                wrap_add(self.buf["lead"], sig * 0.3, self.st(bar, stp) + self.step_t * 3)

        for bar in range(self.bars):
            ch = prog[bar]
            self.render_bass(bar, ch)
            self.render_arp(bar, ch)
            self.render_pad(bar, ch)
            self.render_drums(bar)

        mix = s.get("mix", {})
        out = np.zeros_like(self.buf["lead"])
        for k, b in self.buf.items():
            out += b * mix.get(k, 1.0)
        if s.get("reverb"):
            out = self.reverb(out, s["reverb"])
        peak = np.max(np.abs(out)) + 1e-9
        out = np.tanh(out / peak * 1.3) * 0.85
        return out

    def reverb(self, x, amt):
        y = x.copy()
        for dly, g in ((0.071, 0.5), (0.113, 0.4), (0.167, 0.32), (0.229, 0.25)):
            n = int(dly * SR)
            y += np.roll(x, n) * g * amt
        return y

    def render_bass(self, bar, ch):
        s = self.s
        style = s.get("bass", "root8")
        base = self.root - 12 * s.get("bass_down", 1)
        kind = s.get("bass_kind", "tri")
        v = s.get("bass_vol", 0.45)
        r = self.deg_to_midi(ch, base)
        fifth = self.deg_to_midi(ch + 4, base)
        third = self.deg_to_midi(ch + 2, base)
        b = self.buf["bass"]
        T = self.step_t
        if style == "root8":
            for i in range(0, self.steps, 2):
                m = r + (12 if (i // 2) % 2 else 0)
                wrap_add(b, tone(kind, m, T * 1.8, v, d=0.05, s=0.5), self.st(bar, i))
        elif style == "pulse":
            for i in range(self.steps):
                m = r + (12 if i % 4 == 2 else 0)
                wrap_add(b, tone(kind, m, T * 0.9, v, duty=0.25, d=0.03, s=0.4), self.st(bar, i))
        elif style == "oompah":
            for beat in range(self.beats):
                if beat % 2 == 0 or self.beats == 3 and beat == 0:
                    m = r if (beat // 2) % 2 == 0 else fifth - 12
                    wrap_add(b, tone(kind, m, T * 3, v, d=0.06, s=0.4), self.st(bar, beat * 4))
                else:
                    for dd in self.chord_degs(ch):
                        mm = self.deg_to_midi(dd, self.root)
                        wrap_add(self.buf["chord"], tone("square", mm, T * 1.5, 0.08, duty=0.3,
                                                         d=0.05, s=0.3), self.st(bar, beat * 4))
        elif style == "waltz":
            wrap_add(b, tone(kind, r, T * 3.5, v, d=0.08, s=0.5), self.st(bar, 0))
            for beat in (1, 2):
                for dd in self.chord_degs(ch):
                    mm = self.deg_to_midi(dd, self.root)
                    wrap_add(self.buf["chord"], tone("square", mm, T * 1.5, 0.07, duty=0.3,
                                                     d=0.05, s=0.3), self.st(bar, beat * 4))
        elif style == "walk":
            seq = [r, third, fifth, fifth + 1 if self.rng.random() < 0.5 else r + 12]
            for beat in range(self.beats):
                wrap_add(b, tone(kind, seq[beat % 4], T * 3.6, v, d=0.06, s=0.6), self.st(bar, beat * 4))
        elif style == "sneak":
            seq = [r, None, fifth, None, r + 12, None, fifth, third]
            for i, m in enumerate(seq):
                if m is not None:
                    wrap_add(b, tone(kind, m, T * 1.2, v, d=0.03, s=0.3, r=0.02),
                             self.st(bar, i * 2))
        elif style == "reggae":
            for i, m in ((0, r), (3, r), (6, fifth), (10, r + 12), (12, third)):
                wrap_add(b, tone(kind, m, T * 2.5, v, d=0.06, s=0.6), self.st(bar, i))
            for beat in range(4):
                for dd in self.chord_degs(ch):
                    mm = self.deg_to_midi(dd, self.root + 12)
                    wrap_add(self.buf["chord"], tone("square", mm, T * 1.0, 0.06, duty=0.2,
                                                     d=0.03, s=0.2), self.st(bar, beat * 4 + 2))
        elif style == "drone":
            wrap_add(b, tone(kind, r, self.steps * T, v, a=0.2, d=0.3, s=0.8, r=0.3),
                     self.st(bar, 0))

    def render_arp(self, bar, ch):
        s = self.s
        if not s.get("arp"):
            return
        kind, duty, vol, rate = s["arp"]
        degs = self.chord_degs(ch) + [ch + 7]
        order = s.get("arp_order", [0, 1, 2, 3, 2, 1])
        T = self.step_t
        k = 0
        for i in range(0, self.steps, rate):
            d = degs[order[k % len(order)]]
            k += 1
            m = self.deg_to_midi(d, self.root + 12 * s.get("arp_oct", 1))
            wrap_add(self.buf["arp"], tone(kind, m, T * rate * 0.8, vol, duty=duty, d=0.04,
                                           s=0.3, r=0.02), self.st(bar, i))

    def render_pad(self, bar, ch):
        s = self.s
        if not s.get("pad"):
            return
        kind, vol = s["pad"]
        dur = self.steps * self.step_t
        for d in self.chord_degs(ch):
            m = self.deg_to_midi(d, self.root)
            wrap_add(self.buf["pad"], tone(kind, m, dur, vol, a=0.15, d=0.2, s=0.8, r=0.2),
                     self.st(bar, 0))

    def render_drums(self, bar):
        s = self.s
        pat = s.get("drums")
        if not pat:
            return
        rng = self.rng
        dv = s.get("drum_vol", 0.6)
        for name, line in pat.items():
            for i, c in enumerate(line):
                if c == ".":
                    continue
                v = dv * (1.0 if c in "Xx" else 0.5)
                if name == "k":
                    sig = kick(v)
                elif name == "s":
                    sig = snare(v, rng)
                elif name == "h":
                    sig = hat(v, rng, open_=(c == "o"))
                elif name == "c":
                    sig = clap(v, rng)
                else:
                    continue
                wrap_add(self.buf["drum"], sig, self.st(bar, i))


# ---------------------------------------------------------------- track specs

FOUR = {
    "k": "X.......X.......",
    "s": "....X.......X...",
    "h": "x.x.x.x.x.x.x.x.",
}

TRACKS = {
    "menu": dict(seed=11, bpm=124, root=60, scale="major", prog=[0, 5, 3, 4],
                 prog_b=[3, 4, 0, 5], form="AABA", lead=("square", 0.5),
                 bass="root8", arp=("square", 0.25, 0.07, 1), drums=FOUR,
                 swing=0.15),
    "living_room": dict(seed=21, bpm=112, root=65, scale="major", prog=[0, 3, 4, 0],
                        prog_b=[5, 3, 1, 4], lead=("square", 0.25), bass="walk",
                        drums={"k": "X.....X.X.......", "s": "....X.......X..x",
                               "h": "x.x.x.x.x.x.x.x."}, swing=0.3,
                        arp=("tri", 0.5, 0.08, 2)),
    "kitchen": dict(seed=31, bpm=150, root=67, scale="major", prog=[0, 4, 4, 0],
                    prog_b=[3, 0, 4, 0], lead=("square", 0.5), bass="oompah",
                    drums={"k": "X.......X.......", "s": "....x.......x...",
                           "h": "..x...x...x...x."}, lead_vol=0.28),
    "backyard": dict(seed=41, bpm=132, root=69, scale="major", prog=[0, 0, 3, 4],
                     prog_b=[5, 3, 0, 4], lead=("saw", 0.5), lead_vol=0.2,
                     bass="root8", bass_kind="square",
                     arp=("square", 0.125, 0.06, 1), arp_order=[0, 1, 2, 3],
                     drums={"k": "X..X..X.X..X..X.", "s": "....X.......X...",
                            "h": "xxxxxxxxxxxxxxxx"}, reverb=0.5),
    "bedroom": dict(seed=51, bpm=88, root=62, scale="minor", prog=[0, 0, 5, 4],
                    prog_b=[3, 3, 4, 4], lead=("tri", 0.5), lead_vol=0.38,
                    bass="sneak", bass_kind="square", bass_vol=0.3, swing=0.33,
                    drums={"h": "..x...x...x...x.", "c": "....x.......x..."},
                    drum_vol=0.35, legato=0.55, echo_lead=True),
    "game_room": dict(seed=61, bpm=162, root=64, scale="harm", prog=[0, 5, 3, 4],
                      prog_b=[0, 3, 5, 4], lead=("square", 0.5), bass="pulse",
                      bass_kind="square", bass_vol=0.3,
                      arp=("square", 0.125, 0.05, 1), arp_order=[0, 2, 1, 3],
                      drums={"k": "X.X...X.X.X...X.", "s": "....X.......X.XX",
                             "h": "x.x.x.x.x.x.x.x."}, vib=0.4),
    "cafeteria": dict(seed=71, bpm=168, beats=3, root=58, scale="major",
                      prog=[0, 4, 4, 0], prog_b=[3, 0, 1, 4], lead=("square", 0.25),
                      bass="waltz", drums={"k": "X...........", "h": "....x...x..."},
                      lead_vol=0.27),
    "snow_park": dict(seed=81, bpm=126, root=60, scale="major", prog=[0, 3, 0, 4],
                      prog_b=[3, 0, 1, 4], lead=("bell", 0.5), lead_vol=0.42,
                      bass="root8", arp=("bell", 0.5, 0.06, 2), arp_oct=2,
                      drums={"k": "X.......X.......", "s": "....X.......X...",
                             "h": "xxxxxxxxxxxxxxxx"}, swing=0.2, reverb=0.6),
    "beach": dict(seed=91, bpm=104, root=64, scale="major", prog=[0, 3, 4, 3],
                  prog_b=[5, 3, 4, 4], lead=("tri", 0.5), lead_vol=0.36,
                  bass="reggae", bass_kind="sine", bass_vol=0.55,
                  drums={"k": "X.........X.....", "s": "........X.......",
                         "h": "..x...x...x...x."}, reverb=0.4),
    "attic": dict(seed=101, bpm=76, root=57, scale="harm", prog=[0, 5, 1, 4],
                  prog_b=[0, 3, 1, 4], lead=("organ", 0.5), lead_vol=0.3,
                  bass="drone", bass_kind="saw", bass_vol=0.18,
                  pad=("tri", 0.06), drums={"k": "X.......X......."},
                  drum_vol=0.5, legato=1.0, vib=0.6, reverb=1.0, echo_lead=True),
    "carnival": dict(seed=111, bpm=176, root=60, scale="major", prog=[0, 4, 4, 0],
                     prog_b=[3, 0, 4, 0], lead=("organ", 0.5), lead_vol=0.32,
                     bass="oompah", bass_kind="square", bass_vol=0.3,
                     drums={"k": "X.......X.......", "c": "....x.......x..."},
                     rhythms=[1, 4, 6]),
    "hospital": dict(seed=131, bpm=92, root=65, scale="major", prog=[0, 5, 3, 4],
                     prog_b=[3, 0, 1, 4], lead=("bell", 0.5), lead_vol=0.36, bass="walk",
                     bass_kind="sine", pad=("tri", 0.05), legato=0.8,
                     drums={"h": "..x...x...x...x."}, drum_vol=0.3, reverb=0.5),
    "victory": dict(seed=121, bpm=132, root=62, scale="major", prog=[0, 3, 4, 0],
                    prog_b=[5, 3, 4, 4], lead=("square", 0.5), bass="root8",
                    arp=("square", 0.25, 0.06, 1), drums=FOUR, bars=8, form="AB"),
}


def write_ogg(name, data):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", "3", dst], check=True)
    os.unlink(tmp)
    print("wrote", dst, f"{len(data) / SR:.1f}s")


if __name__ == "__main__":
    for name, spec in TRACKS.items():
        write_ogg(name, Track(spec).render())
