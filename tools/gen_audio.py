#!/usr/bin/env python3
"""Genera todos los sonidos del juego por síntesis (numpy). Coste 0: sin muestras externas.
Uso: python3 tools/gen_audio.py  -> escribe res://audio/*.wav (16 bit, mono, 22050 Hz)."""
import numpy as np, wave, os, sys

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def t_(dur): return np.arange(int(dur * SR)) / SR

def env_exp(n, decay, attack=0.004):
    t = np.arange(n) / SR
    e = np.exp(-t * decay)
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0, 1, a)
    return e

def sine(f, dur, ph=0.0):
    return np.sin(2 * np.pi * f * t_(dur) + ph)

def sweep(f0, f1, dur):
    t = t_(dur)
    f = f0 + (f1 - f0) * (t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)

def noise(dur): return rng.standard_normal(int(dur * SR))

def fft_filter(x, lo=None, hi=None, order=2.0):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi is not None: g *= 1.0 / (1.0 + (f / hi) ** (2 * order))
    if lo is not None: g *= 1.0 - 1.0 / (1.0 + (f / max(lo, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * g, len(x))

def lowpass(x, fc): return fft_filter(x, None, fc)
def highpass(x, fc): return fft_filter(x, fc, None)
def bandpass(x, lo, hi): return fft_filter(x, lo, hi)

def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x

def fade_edges(x, ms=4):
    n = int(ms / 1000 * SR)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x

def bell(f, dur, decay=6.0, h=(1.0, 0.45, 0.25, 0.12)):
    n = int(dur * SR)
    y = np.zeros(n)
    for i, a in enumerate(h):
        y += a * np.sin(2 * np.pi * f * (i + 1) * t_(dur)) * np.exp(-t_(dur) * decay * (1 + 0.6 * i))
    return y

def mix(parts, total):
    out = np.zeros(int(total * SR))
    for off, snd, gain in parts:
        s = int(off * SR)
        e = min(len(out), s + len(snd))
        out[s:e] += snd[: e - s] * gain
    return out

def save(name, x, peak=0.85, loop=False):
    x = np.asarray(x, dtype=np.float64)
    if not loop:
        x = fade_edges(x)
    x = norm(x, peak)
    pcm = np.int16(np.clip(x, -1, 1) * 32767)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    rms = float(np.sqrt(np.mean(x ** 2)))
    print(f"{name:10s} {len(x)/SR:5.2f}s  peak={np.max(np.abs(x)):.2f} rms={rms:.3f}")

# ---------------------------------------------------------------- efectos
def s_click():
    d = 0.05
    return sine(1500, d) * env_exp(int(d * SR), 90) + 0.25 * highpass(noise(d), 2500) * env_exp(int(d * SR), 120)

def s_order():
    a = sine(520, 0.09) * env_exp(int(0.09 * SR), 25)
    b = sine(780, 0.12) * env_exp(int(0.12 * SR), 22)
    return mix([(0, a, 0.8), (0.07, b, 0.8)], 0.22) + 0.15 * mix([(0, sine(1040, 0.09) * env_exp(int(0.09 * SR), 30), 1), (0.07, sine(1560, 0.12) * env_exp(int(0.12 * SR), 30), 1)], 0.22)

def s_place():
    d = 0.2
    thump = sweep(190, 90, d) * env_exp(int(d * SR), 22)
    tap = lowpass(noise(d), 1400) * env_exp(int(d * SR), 45)
    return thump + 0.6 * tap

def s_built():
    notes = [523.25, 659.25, 783.99]
    return mix([(i * 0.11, bell(f, 0.7, 5.5), 1.0) for i, f in enumerate(notes)], 0.95)

def s_hit():
    d = 0.16
    clang = (sine(1850, d) * 0.5 + sine(2730, d) * 0.35 + sine(4100, d) * 0.15) * env_exp(int(d * SR), 38)
    body = bandpass(noise(d), 300, 3000) * env_exp(int(d * SR), 30)
    thud = sine(120, d) * env_exp(int(d * SR), 40)
    return 0.5 * clang + 0.9 * body + 0.7 * thud

def s_arrow():
    d = 0.22
    n = noise(d)
    t = np.linspace(0, 1, len(n))
    sw = bandpass(n, 1200, 5200) * np.sin(np.pi * t) ** 1.5
    tick = highpass(noise(0.04), 2000) * env_exp(int(0.04 * SR), 120)
    return mix([(0, sw, 0.8), (0.17, tick, 0.6)], d)

def s_death():
    d = 0.4
    body = sweep(260, 70, d) * env_exp(int(d * SR), 8)
    air = lowpass(noise(d), 900) * env_exp(int(d * SR), 9)
    return body * 0.8 + air * 0.6

def s_crash():
    d = 1.0
    n = noise(d)
    t = t_(d)
    sweep_cut = np.concatenate([lowpass(n[: SR // 4], 4000), lowpass(n[SR // 4: SR // 2], 1800), lowpass(n[SR // 2:], 600)])
    rumble = lowpass(noise(d), 160) * 2.2
    env = np.exp(-t * 3.2) * (1 + 0.5 * np.sin(2 * np.pi * 14 * t))
    crack = highpass(noise(0.08), 1500) * env_exp(int(0.08 * SR), 60)
    out = (sweep_cut[: len(env)] * 0.8 + rumble[: len(env)]) * env
    out[: len(crack)] += crack * 0.8
    return out

def s_trained():
    a = bell(392.0, 0.4, 7)
    b = bell(523.25, 0.55, 6)
    return mix([(0, a, 0.8), (0.12, b, 1.0)], 0.7)

def s_alarm():
    out = np.zeros(int(1.0 * SR))
    for k, off in enumerate((0.0, 0.5)):
        d = 0.38
        t = t_(d)
        f = 330 + 6 * np.sin(2 * np.pi * 6 * t)
        ph = 2 * np.pi * np.cumsum(f) / SR
        horn = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.33 * np.sin(3 * ph) + 0.2 * np.sin(4 * ph))
        e = np.minimum(1, t / 0.03) * np.minimum(1, (d - t) / 0.08)
        s = int(off * SR)
        out[s: s + len(t)] += horn * e
    return lowpass(out, 3200)

def s_age():
    notes = [(0, 392.0), (0.16, 523.25), (0.32, 659.25), (0.48, 783.99)]
    parts = [(o, bell(f, 1.1, 3.6), 1.0) for o, f in notes]
    parts.append((0.48, bell(523.25, 1.1, 3.0), 0.7))
    return mix(parts, 1.7)

def s_victory():
    seq = [(0, 523.25), (0.18, 659.25), (0.36, 783.99), (0.54, 1046.5), (0.9, 783.99), (1.08, 1046.5)]
    parts = [(o, bell(f, 1.3, 3.0), 1.0) for o, f in seq]
    for f in (523.25, 659.25, 783.99, 1046.5):
        parts.append((1.3, bell(f, 1.6, 2.6), 0.6))
    return mix(parts, 2.9)

def s_defeat():
    seq = [(0, 440.0), (0.35, 392.0), (0.7, 349.23), (1.05, 293.66)]
    parts = [(o, bell(f, 1.2, 3.2, (1.0, 0.3, 0.15)), 1.0) for o, f in seq]
    parts.append((1.05, bell(220.0, 1.6, 2.4, (1.0, 0.4, 0.2)), 0.8))
    return mix(parts, 2.5)

def s_error():
    d = 0.16
    t = t_(d)
    sq = np.sign(np.sin(2 * np.pi * 150 * t)) * 0.5 + np.sin(2 * np.pi * 150 * t) * 0.5
    return lowpass(sq, 1200) * env_exp(int(d * SR), 12)

def s_deposit():
    # dos «clinks» agudos y un golpe sordo: monedas/madera cayendo en el almacén
    a = bell(1318.5, 0.22, 16, (1.0, 0.5, 0.2))
    b = bell(1760.0, 0.26, 15, (1.0, 0.4, 0.15))
    thud = sine(150, 0.1) * env_exp(int(0.1 * SR), 40)
    return mix([(0, thud, 0.5), (0.0, a, 0.9), (0.07, b, 0.8)], 0.34)

# ---------------------------------------------------------------- ambientes (periódicos)
def amb_wind(dur=10.0):
    n = int(dur * SR)
    x = bandpass(noise(dur), 120, 1100)
    t = np.arange(n) / SR
    k = round(dur * 0.25)
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * (k / dur) * t + 1.0) * np.sin(2 * np.pi * (round(dur * 0.13) / dur) * t + 0.3)
    return x * mod

def amb_sea(dur=12.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = lowpass(noise(dur), 420)
    foam = bandpass(noise(dur), 900, 5000)
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * (round(dur / 6.0) / dur) * t)
    swell = swell ** 2
    return base * (0.35 + 0.65 * swell) + 0.28 * foam * swell ** 1.5

def amb_forest(dur=14.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    leaves = bandpass(noise(dur), 1200, 4500) * (0.25 + 0.2 * np.sin(2 * np.pi * (round(dur / 4) / dur) * t))
    wind = lowpass(noise(dur), 300) * 0.7
    out = leaves * 0.5 + wind * 0.5
    for _ in range(18):
        start = rng.uniform(0.2, dur - 1.0)
        f0 = rng.uniform(2300, 4300)
        for j in range(rng.integers(2, 5)):
            d = rng.uniform(0.05, 0.11)
            tt = np.arange(int(d * SR)) / SR
            f = f0 * (1 + 0.25 * np.sin(np.pi * tt / d) + rng.uniform(-0.1, 0.1))
            chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / d) ** 2
            s = int((start + j * rng.uniform(0.09, 0.15)) * SR)
            if s + len(chirp) < n:
                out[s: s + len(chirp)] += chirp * 0.22
    return out

def amb_rain(dur=12.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    hiss = bandpass(noise(dur), 1400, 7500)
    bed = lowpass(noise(dur), 650) * 0.35
    mod = 0.80 + 0.20 * np.sin(2 * np.pi * (round(dur / 3.0) / dur) * t + 0.7)
    out = (hiss * 0.8 + bed) * mod
    # gotas sueltas sobre superficies
    for _ in range(int(dur * 14)):
        s0 = int(rng.uniform(0, n - 600))
        d = rng.uniform(0.012, 0.03)
        k = int(d * SR)
        tt = np.arange(k) / SR
        f = rng.uniform(1800, 4200)
        out[s0:s0 + k] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 260) * rng.uniform(0.05, 0.16)
    return out

def make_loop(x, name, peak=0.6):
    # el ruido filtrado por FFT y las modulaciones con ciclos enteros son periódicos: sin costura
    save(name, x - np.mean(x), peak, loop=True)

if __name__ == "__main__" and len(sys.argv) > 1:
    # python3 tools/gen_audio.py deposit  -> solo regenera esos sonidos, sin tocar el resto
    only = {"deposit": lambda: save("deposit", s_deposit(), 0.7),
            "rain": lambda: make_loop(amb_rain(), "rain", 0.5)}
    for a in sys.argv[1:]:
        only[a]()
elif __name__ == "__main__":
    save("deposit", s_deposit(), 0.7)
    save("click", s_click(), 0.7)
    save("order", s_order(), 0.7)
    save("place", s_place(), 0.8)
    save("built", s_built(), 0.75)
    save("hit", s_hit(), 0.85)
    save("arrow", s_arrow(), 0.7)
    save("death", s_death(), 0.8)
    save("crash", s_crash(), 0.9)
    save("trained", s_trained(), 0.7)
    save("alarm", s_alarm(), 0.8)
    save("age", s_age(), 0.8)
    save("victory", s_victory(), 0.85)
    save("defeat", s_defeat(), 0.8)
    save("error", s_error(), 0.6)
    make_loop(amb_wind(), "wind", 0.5)
    make_loop(amb_sea(), "sea", 0.6)
    make_loop(amb_forest(), "forest", 0.6)
    make_loop(amb_rain(), "rain", 0.5)
    tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("total KB:", tot // 1024)
