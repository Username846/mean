#!/usr/bin/env python3
"""Procedural sound effects for Bug My Brother -> assets/sfx/*.ogg"""
import os

import numpy as np

from gen_music import SR, tone, kick, write_ogg
import gen_music

gen_music.OUT = os.path.join(gen_music.ROOT, "assets", "sfx")
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def sweep(f0, f1, dur, kind="sine", curve=1.0):
    t = t_(dur)
    f = f0 + (f1 - f0) * (t / dur) ** curve
    ph = np.cumsum(f) / SR
    if kind == "square":
        return np.where(ph % 1 < 0.5, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph % 1 - 0.5) - 1
    return np.sin(2 * np.pi * ph)


def env_exp(dur, k):
    return np.exp(-t_(dur) * k)


def cat(*xs):
    return np.concatenate(xs)


def mixs(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def silence(d):
    return np.zeros(int(d * SR))


S = {}
S["pop"] = sweep(400, 1200, 0.08) * env_exp(0.08, 30)
S["poke"] = sweep(900, 300, 0.09, "square") * env_exp(0.09, 35) * 0.5
S["bonk"] = mixs(sweep(300, 120, 0.25, "tri") * env_exp(0.25, 12),
                 sweep(1800, 1500, 0.25) * env_exp(0.25, 20) * 0.4)
S["boing"] = sweep(150, 600, 0.45) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t_(0.45))) \
    * env_exp(0.45, 5) * 0.5
S["whoosh"] = lowpass(noise(0.35), 0.15) * np.sin(np.pi * t_(0.35) / 0.35) * 2.5
S["throw"] = lowpass(noise(0.2), 0.25) * np.sin(np.pi * t_(0.2) / 0.2) * 2
S["splat"] = mixs(lowpass(noise(0.35), 0.2) * env_exp(0.35, 10) * 2.5,
                  sweep(200, 60, 0.3) * env_exp(0.3, 12))
S["splash"] = mixs(lowpass(noise(0.9), 0.35) * env_exp(0.9, 4) * 1.6,
                   lowpass(noise(0.9), 0.05) * env_exp(0.9, 3) * 3)
S["bubbles"] = mixs(*[np.pad(sweep(300 + 80 * i, 900 + 100 * i, 0.06) * env_exp(0.06, 30),
                              (int(i * 0.09 * SR), 0)) for i in range(8)])
S["thud"] = mixs(kick(1.0), lowpass(noise(0.15), 0.1) * env_exp(0.15, 25) * 2)
def resonator(x, freq, r):
    """Two-pole resonant filter (a cheap formant)."""
    w = 2 * np.pi * freq / SR
    a1, a2 = 2 * r * np.cos(w), -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y0 = v + a1 * y1 + a2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y * (1 - r)


def fart(seed, dur, base, squeak=0.0, sputter=0.3, wet=0.5):
    """Whoopee-cushion fart: an irregular train of 'flap' pulses (like lips
    buzzing) with wandering pitch, shaped by two cavity resonances, plus
    breathy air and a wet sputter toward the end."""
    rng_ = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    # pitch: smooth random wander, a squeaky start, sagging at the end
    walk = lowpass(rng_.normal(0, 1, n), 0.0004)
    walk /= np.max(np.abs(walk)) + 1e-9
    f = base * (1 + 0.28 * walk) * (1 + squeak * np.exp(-t * 9)) * (1 - 0.35 * (t / dur) ** 2)
    # amplitude: quick attack, fluttering body, tail fade
    flutter = 1 + 0.35 * lowpass(rng_.normal(0, 1, n), 0.002) * 6
    amp = np.minimum(1, t / 0.02) * np.clip(flutter, 0.2, 1.6) * np.clip((dur - t) / (0.25 * dur), 0, 1) ** 0.7
    exc = np.zeros(n)
    i = 0
    while i < n:
        period = SR / max(f[i], 25) * rng_.uniform(0.9, 1.12)
        in_tail = t[i] > dur * (1 - sputter)
        if in_tail and rng_.random() < 0.35:
            i += int(period * rng_.integers(1, 4))  # sputter: skipped flaps
            continue
        # short flap with an abrupt close: rich in upper harmonics ("rippy")
        w = max(4, int(period * rng_.uniform(0.15, 0.28)))
        k = np.arange(w)
        pulse = np.sin(0.5 * np.pi * k / w) ** 2
        j = min(n, i + w)
        exc[i:j] += pulse[: j - i] * amp[i] * rng_.uniform(0.75, 1.0)
        i += int(period)
    exc -= lowpass(exc, 0.01)  # remove DC thump
    body = resonator(exc, 340, 0.98) * 0.6 + resonator(exc, 720, 0.97) * 1.0 + resonator(exc, 1500, 0.94) * 0.45 * (0.5 + wet)
    for _ in range(2):  # 2nd-order high-pass around 300 Hz: keeps it rippy, not boomy
        body -= lowpass(body, 0.045)
    air = (lowpass(rng_.uniform(-1, 1, n), 0.25) - lowpass(rng_.uniform(-1, 1, n), 0.04)) * amp * 0.08
    crackle = (rng_.random(n) > 0.9993).astype(float) * rng_.uniform(-1, 1, n)
    crackle = lowpass(crackle, 0.3) * (t > dur * (1 - sputter)) * 3 * wet
    out = body / (np.max(np.abs(body)) + 1e-9) + air + crackle
    return lowpass(out, 0.5)


S["fart"] = fart(3, 1.15, 135, squeak=0.25, sputter=0.3)
S["fart2"] = fart(11, 0.6, 200, squeak=0.6, sputter=0.2, wet=0.3)
S["fart3"] = fart(29, 1.6, 110, squeak=0.1, sputter=0.45, wet=0.8)
S["tickle"] = cat(*[sweep(1200 + 200 * (i % 3), 1600, 0.05) * env_exp(0.05, 40)
                   for i in range(10)])
S["squeak"] = sweep(1800, 2400, 0.12) * env_exp(0.12, 10) * 0.4
S["marker"] = lowpass(noise(0.12), 0.6) * 0.25
S["chomp"] = cat(mixs(lowpass(noise(0.12), 0.4) * env_exp(0.12, 30), silence(0.15)),
                 lowpass(noise(0.12), 0.4) * env_exp(0.12, 30))
S["crunch"] = lowpass(noise(0.25), 0.5) * env_exp(0.25, 14) * (rng.random(int(0.25 * SR)) > 0.6)
S["sand"] = lowpass(noise(0.4), 0.3) * np.sin(np.pi * t_(0.4) / 0.4) * 0.8
S["pinch"] = cat(sweep(2500, 2000, 0.04, "square") * 0.3, silence(0.05),
                 sweep(2500, 2000, 0.04, "square") * 0.3)
S["creak"] = sweep(180, 260, 0.7, "square") * (rng.random(int(0.7 * SR)) > 0.3) \
    * np.sin(np.pi * t_(0.7) / 0.7) * 0.25
S["boo"] = mixs(sweep(80, 40, 0.8, "square") * env_exp(0.8, 2) * 0.4,
                lowpass(noise(0.8), 0.05) * env_exp(0.8, 3) * 3)
S["sting"] = mixs(*[tone("saw", m, 0.9, 0.25, d=0.3, s=0.5, r=0.2) for m in (70, 71, 76, 77)])
S["ding"] = tone("bell", 88, 0.6, 0.6, d=0.4, s=0.2)
S["bell"] = mixs(tone("bell", 84, 1.0, 0.6, d=0.5, s=0.2), tone("bell", 91, 1.0, 0.3, d=0.5, s=0.2))
S["buzzer"] = tone("square", 40, 0.6, 0.4, duty=0.4, d=0.1, s=0.9)
S["click"] = sweep(1500, 1000, 0.025, "square") * 0.3
S["unplug"] = mixs(sweep(800, 50, 0.5, "square") * env_exp(0.5, 4) * 0.4,
                   lowpass(noise(0.3), 0.6) * env_exp(0.3, 20) * 0.5)
S["powerup"] = cat(*[tone("square", m, 0.07, 0.3, duty=0.25, s=0.8) for m in (60, 64, 67, 72, 76, 79, 84)])
S["levelup"] = cat(*[tone("square", m, d, 0.35, duty=0.5, s=0.8)
                    for m, d in ((72, 0.1), (76, 0.1), (79, 0.1), (84, 0.35))])
S["cheer"] = sum(lowpass(noise(1.4), 0.3 + 0.1 * k) * (0.5 + 0.5 * np.sin(2 * np.pi * (3 + k) * t_(1.4)))
                 for k in range(4)) * np.sin(np.pi * t_(1.4) / 1.4) * 0.6
S["laser"] = sweep(1600, 200, 0.25, "square") * env_exp(0.25, 8) * 0.3
S["hit8"] = mixs(sweep(500, 100, 0.12, "square") * 0.3, noise(0.12) * env_exp(0.12, 30) * 0.3)
S["wipe"] = lowpass(noise(0.3), 0.4) * np.sin(np.pi * t_(0.3) / 0.3) * 0.7
S["slurp"] = sweep(300, 900, 0.5, "tri") * (0.6 + 0.4 * np.sin(2 * np.pi * 25 * t_(0.5))) * 0.4
S["fire"] = lowpass(noise(1.0), 0.2) * (0.6 + 0.4 * rng.random(int(1.0 * SR))) * env_exp(1.0, 2) * 2
S["wave"] = lowpass(noise(1.6), 0.08) * np.sin(np.pi * t_(1.6) / 1.6) * 3
S["seagull"] = cat(*[sweep(1400, 900, 0.18, "tri") * env_exp(0.18, 6) * 0.4 for _ in range(3)])
S["alarm"] = cat(*[tone("square", 93, 0.06, 0.3, duty=0.5, s=1) for _ in range(12)])
S["snore"] = lowpass(noise(1.2), 0.04) * (np.sin(np.pi * t_(1.2) / 1.2) ** 2) * 4
S["giggle"] = cat(*[sweep(700, 500, 0.08, "tri") * env_exp(0.08, 15) * 0.5 for _ in range(5)])
S["cannon"] = mixs(kick(1.0), lowpass(noise(0.5), 0.3) * env_exp(0.5, 7) * 2)
S["step"] = lowpass(noise(0.06), 0.2) * env_exp(0.06, 50) * 2

# --- emergencies
S["siren"] = cat(*[mixs(tone("square", m, 0.42, 0.35, duty=0.5, s=1.0, vib=0.3),
                        tone("saw", m, 0.42, 0.15, s=1.0)) for m in (83, 79) * 4])
_t = t_(1.3)
S["zap"] = (np.where((_t * 60) % 1 < 0.5, 1.0, -1.0) * 0.4 + noise(1.3) * (rng.random(len(_t)) > 0.7) * 0.8) \
    * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * _t)) * np.minimum(1, (1.3 - _t) * 4)


def clang(f0):
    t = t_(1.0)
    parts = sum(np.sin(2 * np.pi * f0 * k * t) * np.exp(-t * (3 + k * 2)) / k for k in (1, 2.76, 5.4, 8.93))
    return parts + noise(1.0) * np.exp(-t * 60) * 0.8


S["clang"] = clang(520)
S["pans"] = mixs(clang(480), np.pad(clang(690), (int(0.18 * SR), 0)) * 0.8,
                 np.pad(clang(380), (int(0.33 * SR), 0)), np.pad(clang(820), (int(0.5 * SR), 0)) * 0.6)
S["crack"] = mixs(noise(0.06) * env_exp(0.06, 40) * 2, lowpass(noise(0.25), 0.3) * env_exp(0.25, 18),
                  sweep(180, 60, 0.25) * env_exp(0.25, 14))
_t = t_(1.6)
S["choke"] = lowpass(noise(1.6), 0.06) * 4 * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 7 * _t))) \
    * np.minimum(1, (1.6 - _t) * 3) + sweep(140, 90, 1.6, "tri") * 0.25 * (np.sin(2 * np.pi * 7 * _t) > 0)
S["beep"] = tone("sine", 95, 0.13, 0.6, d=0.02, s=1.0, r=0.02)
S["crash"] = mixs(kick(1.0), lowpass(noise(1.2), 0.4) * env_exp(1.2, 4) * 1.5, clang(900) * 0.4,
                  np.pad(clang(1300), (int(0.12 * SR), 0)) * 0.3)

_t = t_(1.0)
S["tirepop"] = mixs(noise(0.3) * env_exp(0.3, 25) * 2, kick(1.0), sweep(900, 200, 0.3) * env_exp(0.3, 12) * 0.4)
S["skid"] = (np.sin(2 * np.pi * np.cumsum(2300 + 300 * np.sin(2 * np.pi * 9 * _t) + rng.normal(0, 200, len(_t))) / SR) * 0.4
             + (noise(1.0) - lowpass(noise(1.0), 0.3)) * 0.5) * np.minimum(1, (1.0 - _t) * 4) * np.minimum(1, _t * 20)
_t = t_(3.0)
S["rotor"] = lowpass(noise(3.0), 0.08) * 5 * (0.25 + 0.75 * np.maximum(0, np.sin(2 * np.pi * 11 * _t)) ** 4) \
    + sweep(110, 110, 3.0, "square") * 0.06
S["snip"] = cat(noise(0.03) * 0.8, silence(0.04), sweep(3000, 2200, 0.05, "square") * 0.3 * env_exp(0.05, 50))
S["chitter"] = cat(*[sweep(2600, 3400, 0.04, "tri") * env_exp(0.04, 40) * 0.5 for _ in range(9)])
S["rustle"] = lowpass(noise(0.7), 0.45) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 6 * t_(0.7)))) * np.sin(np.pi * t_(0.7) / 0.7)

if __name__ == "__main__":
    for name, data in S.items():
        data = np.asarray(data, dtype=float)
        peak = np.max(np.abs(data)) + 1e-9
        write_ogg(name, data / peak * 0.85)
