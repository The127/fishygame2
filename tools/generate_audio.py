#!/usr/bin/env python3
"""Generates every sound in assets/audio/ from scratch (pure Python, no dependencies).

The output is deterministic and original, so there is nothing to license: see
assets/audio/README.md. Re-run after editing and commit the WAV files:

    python3 tools/generate_audio.py
"""

import array
import math
import random
import wave
from pathlib import Path

import music_themes

SAMPLE_RATE = 22050
TAU = 2.0 * math.pi
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"

MUSIC_SECONDS = 32
MUSIC_PEAK = 0.55
SFX_PEAK = 0.85


def n_samples(seconds: float) -> int:
    return int(seconds * SAMPLE_RATE)


def write_wav(
    name: str, samples: list, peak: float, rate: int = SAMPLE_RATE, normalize: bool = True
) -> None:
    """Writes 16-bit mono. Normalizing scales the loudest sample to `peak`."""
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top if normalize else 1.0
    data = array.array("h", (int(max(-1.0, min(1.0, s * scale)) * 32767) for s in samples))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_DIR / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(data.tobytes())
    print(f"{name}: {len(samples) / rate:.2f}s, {len(data) * 2 // 1024} KiB")


def fade_edges(samples: list, ms: float = 4.0) -> list:
    """Short fades so one-shots never click at the start or end."""
    k = max(1, int(SAMPLE_RATE * ms / 1000.0))
    for i in range(min(k, len(samples))):
        g = i / k
        samples[i] *= g
        samples[-1 - i] *= g
    return samples


def tone(freq_fn, seconds: float, env_fn, harmonics=((1.0, 1.0),)) -> list:
    """Sine (plus optional harmonics) with a time-varying frequency and envelope."""
    out = []
    phase = 0.0
    for i in range(n_samples(seconds)):
        t = i / SAMPLE_RATE
        phase += TAU * freq_fn(t) / SAMPLE_RATE
        v = sum(a * math.sin(phase * m) for m, a in harmonics)
        out.append(v * env_fn(t))
    return out


def pluck_env(attack: float, decay: float):
    return lambda t: min(1.0, t / attack) * math.exp(-t / decay)


def mix_into(dst: list, src: list, offset: int = 0, gain: float = 1.0) -> None:
    for i, s in enumerate(src):
        j = offset + i
        if j >= len(dst):
            break
        dst[j] += s * gain


def lowpass(samples: list, cutoff: float) -> list:
    a = 1.0 - math.exp(-TAU * cutoff / SAMPLE_RATE)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def noise(seconds: float, rng: random.Random) -> list:
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(seconds))]


# --- one-shot effects -------------------------------------------------------


def sfx_join() -> list:
    """Two quick rising bubble blips."""
    out = [0.0] * n_samples(0.32)
    for start, f0, f1 in ((0.0, 520.0, 780.0), (0.09, 700.0, 1180.0)):
        blip = tone(
            lambda t, a=f0, b=f1: a + (b - a) * min(1.0, t / 0.08),
            0.2,
            pluck_env(0.004, 0.06),
        )
        mix_into(out, blip, n_samples(start))
    return out


def sfx_tick() -> list:
    return tone(lambda t: 880.0, 0.12, pluck_env(0.003, 0.03), ((1.0, 1.0), (2.0, 0.25)))


def sfx_go() -> list:
    """Brighter, longer than the tick: an open fifth with a rising sparkle."""
    out = [0.0] * n_samples(0.7)
    for f in (523.25, 783.99, 1046.5):
        mix_into(out, tone(lambda t, f=f: f, 0.7, pluck_env(0.005, 0.22), ((1.0, 1.0), (2.0, 0.2))))
    sparkle = tone(lambda t: 1200.0 + 2400.0 * t, 0.25, pluck_env(0.01, 0.08))
    mix_into(out, sparkle, n_samples(0.03), 0.35)
    return out


def sfx_boost() -> list:
    """Rising swoosh: a sweeping sine over band-passed noise."""
    rng = random.Random(11)
    seconds = 0.5
    sweep = tone(
        lambda t: 260.0 * math.pow(5.0, t / seconds),
        seconds,
        lambda t: math.sin(math.pi * min(1.0, t / seconds)) ** 1.5,
        ((1.0, 1.0), (2.0, 0.3)),
    )
    hiss = lowpass(noise(seconds, rng), 3500.0)
    hiss = [h - l for h, l in zip(hiss, lowpass(hiss, 500.0))]
    out = []
    for i, (a, b) in enumerate(zip(sweep, hiss)):
        t = i / SAMPLE_RATE
        out.append(a * 0.7 + b * 1.6 * math.sin(math.pi * min(1.0, t / seconds)))
    return out


def sfx_curse() -> list:
    """Falling, wobbling, detuned drone: reads as bad news."""
    seconds = 0.85
    out = [0.0] * n_samples(seconds)
    for detune in (1.0, 1.035):
        voice = tone(
            lambda t, d=detune: 340.0 * d * math.pow(0.22, t / seconds),
            seconds,
            lambda t: min(1.0, t / 0.02) * math.exp(-t / 0.5),
            ((1.0, 1.0), (3.0, 0.35), (5.0, 0.15)),
        )
        mix_into(out, voice)
    return [s * (0.65 + 0.35 * math.sin(TAU * 11.0 * i / SAMPLE_RATE)) for i, s in enumerate(out)]


def sfx_splash() -> list:
    """Filtered noise burst that darkens as it decays, with a few bubbles."""
    rng = random.Random(23)
    seconds = 0.9
    raw = noise(seconds, rng)
    out = []
    y = 0.0
    for i, s in enumerate(raw):
        t = i / SAMPLE_RATE
        cutoff = 300.0 + 5500.0 * math.exp(-t / 0.12)
        a = 1.0 - math.exp(-TAU * cutoff / SAMPLE_RATE)
        y += a * (s - y)
        out.append(y * math.exp(-t / 0.22) * min(1.0, t / 0.004))
    for start, f in ((0.08, 620.0), (0.17, 830.0), (0.27, 540.0), (0.36, 990.0)):
        bubble = tone(
            lambda t, f=f: f * (1.0 + 1.6 * t),
            0.14,
            pluck_env(0.004, 0.04),
        )
        mix_into(out, bubble, n_samples(start), 0.45)
    return out


def sfx_meow() -> list:
    """A short cat meow: a rising then falling pitch through a vowel-like formant sweep."""
    seconds = 0.5
    out = []
    phase = 0.0
    for i in range(n_samples(seconds)):
        t = i / SAMPLE_RATE
        u = t / seconds
        # Pitch glides up into the "mee" and falls away in the "ow".
        freq = 430.0 + 330.0 * math.sin(math.pi * min(1.0, u * 1.25)) - 90.0 * u
        phase += TAU * freq / SAMPLE_RATE
        # The harmonics that sit near a moving formant get boosted: "ee" (bright) to "ow" (dark).
        formant = 2600.0 - 1900.0 * u
        v = 0.0
        for h in range(1, 13):
            v += math.sin(phase * h) * math.exp(-(((h * freq - formant) / 900.0) ** 2)) / h**0.6
        env = min(1.0, t / 0.03) * math.exp(-max(0.0, u - 0.55) * 4.5) * (0.85 + 0.15 * math.sin(TAU * 7.0 * t))
        out.append(v * env)
    return out


def sfx_win() -> list:
    """Bright arpeggio into a held chord with a soft echo."""
    seconds = 2.4
    out = [0.0] * n_samples(seconds)
    arpeggio = (523.25, 659.25, 783.99, 1046.5)
    for i, f in enumerate(arpeggio):
        note = tone(
            lambda t, f=f: f,
            1.3,
            pluck_env(0.005, 0.35),
            ((1.0, 1.0), (2.0, 0.3), (3.0, 0.1)),
        )
        mix_into(out, note, n_samples(0.12 * i))
    for f in (523.25, 659.25, 783.99, 1046.5, 1318.5):
        chord = tone(lambda t, f=f: f, 1.8, pluck_env(0.02, 0.7), ((1.0, 1.0), (2.0, 0.2)))
        mix_into(out, chord, n_samples(0.5), 0.5)
    echoed = list(out)
    for k, g in ((1, 0.35), (2, 0.15)):
        mix_into(echoed, out, n_samples(0.22 * k), g)
    return echoed


# --- music ------------------------------------------------------------------

# Am - Fmaj - Dm - Em, one chord per 8 seconds, low and dark.
CHORDS = (
    (110.00, 164.81, 220.00, 261.63),
    (87.31, 130.81, 174.61, 220.00),
    (73.42, 110.00, 146.83, 174.61),
    (82.41, 123.47, 164.81, 196.00),
)
# A minor pentatonic, one octave up: sparse bubbly plucks.
PLUCK_NOTES = (440.00, 523.25, 659.25, 783.99, 880.00)


def snap(freq: float) -> float:
    """Snaps to a whole number of cycles per loop so the loop point is seamless."""
    return round(freq * MUSIC_SECONDS) / MUSIC_SECONDS


def music() -> list:
    rng = random.Random(7)
    n = n_samples(MUSIC_SECONDS)
    out = [0.0] * n
    chord_len = MUSIC_SECONDS / len(CHORDS)

    # Sub drone and pads. Each chord fades in and out over two chord lengths (Hann
    # window centered on its slot); neighbours overlap into a constant sum.
    for idx, chord in enumerate(CHORDS):
        center = (idx + 0.5) * chord_len
        for note_no, base in enumerate(chord):
            freq = snap(base)
            lfo_freq = snap(0.08 + 0.02 * note_no)
            lfo_phase = note_no * 1.7
            for i in range(n):
                t = i / SAMPLE_RATE
                d = (t - center + MUSIC_SECONDS / 2) % MUSIC_SECONDS - MUSIC_SECONDS / 2
                if abs(d) >= chord_len:
                    continue
                w = 0.5 + 0.5 * math.cos(math.pi * d / chord_len)
                trem = 0.75 + 0.25 * math.sin(TAU * lfo_freq * t + lfo_phase)
                v = math.sin(TAU * freq * t) + 0.35 * math.sin(TAU * 2 * freq * t + 0.5)
                out[i] += v * w * trem * 0.11
    for i in range(n):
        t = i / SAMPLE_RATE
        out[i] += 0.16 * math.sin(TAU * snap(55.0) * t)

    # Water rumble: low-passed noise, crossfaded so it loops.
    fade = n_samples(2.0)
    raw = lowpass(noise(MUSIC_SECONDS + 2.0, rng), 260.0)
    rumble = raw[:n]
    for i in range(fade):
        g = i / fade
        rumble[i] = rumble[i] * g + raw[n + i] * (1.0 - g)
    for i in range(n):
        t = i / SAMPLE_RATE
        out[i] += rumble[i] * (0.9 + 0.5 * math.sin(TAU * 2.0 / MUSIC_SECONDS * t)) * 1.2

    # Sparse plucks with an echo tail that wraps around the loop point.
    times = sorted(rng.uniform(0.5, MUSIC_SECONDS - 1.0) for _ in range(13))
    for start in times:
        freq = rng.choice(PLUCK_NOTES)
        note = tone(lambda t, f=freq: f, 2.2, pluck_env(0.01, 0.5), ((1.0, 1.0), (2.0, 0.15)))
        for k, g in enumerate((1.0, 0.5, 0.25, 0.12)):
            offset = n_samples(start) + n_samples(0.42) * k
            for i, s in enumerate(note):
                out[(offset + i) % n] += s * g * 0.09
    return out


def main() -> None:
    write_wav("music_ambient.wav", music(), MUSIC_PEAK)
    for map_id, theme in music_themes.THEMES.items():
        write_wav(f"music_{map_id}.wav", music_themes.render(theme), 1.0, music_themes.RATE, False)
    effects = {
        "sfx_join.wav": sfx_join,
        "sfx_tick.wav": sfx_tick,
        "sfx_go.wav": sfx_go,
        "sfx_boost.wav": sfx_boost,
        "sfx_curse.wav": sfx_curse,
        "sfx_splash.wav": sfx_splash,
        "sfx_win.wav": sfx_win,
        "sfx_meow.wav": sfx_meow,
    }
    for name, make in effects.items():
        write_wav(name, fade_edges(make()), SFX_PEAK)


if __name__ == "__main__":
    main()
