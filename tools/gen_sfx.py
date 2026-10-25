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
S["fart"] = (np.where((np.cumsum(90 + 30 * np.sin(2 * np.pi * 7 * t_(0.9))
                                 + rng.uniform(-20, 20, int(0.9 * SR))) / SR) % 1 < 0.4,
                      1.0, -1.0)
             * np.minimum(1, t_(0.9) * 30) * env_exp(0.9, 2.5))
S["fart"] = lowpass(S["fart"], 0.12) * 1.5
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

if __name__ == "__main__":
    for name, data in S.items():
        data = np.asarray(data, dtype=float)
        peak = np.max(np.abs(data)) + 1e-9
        write_ogg(name, data / peak * 0.85)
