"""Per-map win jingles and ambience loops, synthesized from scratch (pure Python).

Used by generate_audio.py. Jingles reuse the music themes' helpers (same key and timbre as each
map's music). Ambience beds are deliberately low-rate (8 kHz, 8 s) to keep the download small:
they are mostly rumble, wash and soft events. Beds are cross-faded at the loop point and events
wrap around it, so every loop is seamless.
"""

import math
import random

import music_themes as mt

TAU = 2.0 * math.pi

# --- win jingles ------------------------------------------------------------

JINGLE_RATE = mt.RATE
JINGLE_SECONDS = 2.8

BELL = ((1.0, 1.0), (2.76, 0.35), (5.4, 0.15))
GLASS = ((1.0, 1.0), (2.0, 0.15))
MALLET = ((1.0, 1.0), (4.0, 0.3))
SOFT = ((1.0, 1.0), (2.0, 0.3))
BRASS = ((1.0, 1.0), (2.0, 0.5), (3.0, 0.4), (4.0, 0.25))

# Each note is (start seconds, midi, seconds, decay). "glide" starts every note that far below
# its pitch (ratio) and slides up; "echo" is (gap, count, falloff); "attack" softens the onset.
JINGLES = {
    # Kelp forest: bright D dorian mallet run.
    "zigzag": {
        "partials": MALLET,
        "notes": ((0.0, 74, 1.0, 0.25), (0.14, 77, 1.0, 0.25), (0.28, 81, 1.0, 0.25),
                  (0.42, 86, 1.6, 0.6), (0.42, 62, 1.6, 0.6), (0.42, 69, 1.6, 0.6)),
        "echo": (0.3, 2, 0.4),
    },
    # Crystal cavern: E lydian bell cascade with a long tail.
    "pachinko": {
        "partials": BELL,
        "notes": ((0.0, 88, 1.8, 0.7), (0.11, 83, 1.8, 0.7), (0.22, 80, 1.8, 0.7),
                  (0.33, 76, 1.8, 0.7), (0.5, 92, 2.2, 0.9), (0.5, 64, 2.2, 0.9)),
        "echo": (0.33, 3, 0.45),
    },
    # Shipwreck: C minor brass swell answered by a tolling bell.
    "wreck": {
        "partials": BRASS,
        "attack": 0.05,
        "notes": ((0.0, 48, 0.9, 0.5), (0.0, 55, 0.9, 0.5), (0.35, 51, 0.9, 0.5),
                  (0.35, 58, 0.9, 0.5), (0.7, 48, 1.8, 0.9), (0.7, 55, 1.8, 0.9),
                  (0.7, 60, 1.8, 0.9)),
        "bell": (1.1, 60, 1.6),
        "echo": (0.5, 2, 0.4),
    },
    # Whirlpool: A minor arpeggio that circles up and resolves.
    "whirlpool": {
        "partials": SOFT,
        "notes": ((0.0, 57, 0.6, 0.2), (0.09, 60, 0.6, 0.2), (0.18, 64, 0.6, 0.2),
                  (0.27, 69, 0.6, 0.2), (0.36, 72, 0.6, 0.2), (0.45, 76, 0.6, 0.2),
                  (0.54, 72, 0.6, 0.2), (0.63, 69, 0.6, 0.2), (0.72, 81, 1.8, 0.7),
                  (0.72, 57, 1.8, 0.7)),
        "echo": (0.25, 2, 0.4),
    },
    # Jellyfish field: F lydian bloops that glide up into a floaty chord.
    "jelly": {
        "partials": GLASS,
        "glide": 0.8,
        "notes": ((0.0, 65, 0.7, 0.3), (0.2, 69, 0.7, 0.3), (0.4, 72, 0.7, 0.3),
                  (0.6, 76, 1.9, 0.9), (0.6, 60, 1.9, 0.9), (0.6, 69, 1.9, 0.9)),
        "echo": (0.4, 3, 0.5),
    },
    # Abyss: two slow low tones a tritone apart and one sonar ping.
    "abyss": {
        "partials": ((1.0, 1.0), (2.0, 0.4)),
        "attack": 0.12,
        "notes": ((0.0, 43, 2.2, 1.1), (0.5, 49, 2.0, 1.0)),
        "bell": (0.9, 91, 1.6),
        "echo": (0.7, 2, 0.45),
    },
    # Volcanic vents: E phrygian brass stabs and a steam burst.
    "vents": {
        "partials": BRASS,
        "notes": ((0.0, 52, 0.5, 0.18), (0.0, 59, 0.5, 0.18), (0.22, 53, 0.5, 0.18),
                  (0.22, 60, 0.5, 0.18), (0.5, 52, 1.6, 0.6), (0.5, 59, 1.6, 0.6),
                  (0.5, 64, 1.6, 0.6), (0.5, 40, 1.6, 0.6)),
        "hiss": 0.5,
        "echo": (0.2, 1, 0.35),
    },
    # Crystal cave: A minor glass chimes falling like a crystal shattering softly, long echo.
    "cave": {
        "partials": BELL,
        "notes": ((0.0, 93, 1.6, 0.6), (0.1, 88, 1.6, 0.6), (0.2, 84, 1.6, 0.6),
                  (0.3, 81, 1.6, 0.6), (0.42, 76, 1.8, 0.7), (0.55, 69, 2.0, 0.8),
                  (0.55, 57, 2.0, 0.8)),
        "echo": (0.3, 3, 0.45),
    },
    # Kraken's lair: D minor brass swell, a dread bell and one more toll.
    "kraken": {
        "partials": BRASS,
        "attack": 0.08,
        "notes": ((0.0, 50, 1.0, 0.5), (0.0, 57, 1.0, 0.5), (0.4, 53, 1.0, 0.5),
                  (0.4, 60, 1.0, 0.5), (0.8, 50, 1.9, 0.9), (0.8, 57, 1.9, 0.9),
                  (0.8, 62, 1.9, 0.9), (0.8, 38, 1.9, 0.9)),
        "bell": (1.2, 74, 1.6),
        "echo": (0.5, 2, 0.4),
    },
    # Gravity flip: D minor arpeggio that climbs, then falls back into a low chord.
    "gravity": {
        "partials": GLASS,
        "glide": 0.5,
        "notes": ((0.0, 62, 0.6, 0.25), (0.14, 69, 0.6, 0.25), (0.28, 74, 0.6, 0.25),
                  (0.42, 77, 0.6, 0.25), (0.56, 74, 0.6, 0.25), (0.7, 69, 0.6, 0.25),
                  (0.84, 62, 1.7, 0.7), (0.84, 65, 1.7, 0.7), (0.84, 57, 1.7, 0.7)),
        "echo": (0.3, 2, 0.4),
    },
    # Ebb tide: D dorian bells that fall like a wave leaving, then a warm settled chord.
    "tide": {
        "partials": BELL,
        "notes": ((0.0, 86, 1.4, 0.5), (0.16, 81, 1.4, 0.5), (0.32, 77, 1.4, 0.5),
                  (0.48, 74, 1.4, 0.5), (0.72, 69, 2.0, 0.9), (0.72, 62, 2.0, 0.9),
                  (0.72, 50, 2.0, 0.9)),
        "echo": (0.3, 3, 0.45),
    },
    # Fork Reef: three glassy notes that split into a lydian chord.
    "fork": {
        "partials": GLASS,
        "notes": ((0.0, 77, 0.6, 0.2), (0.12, 81, 0.6, 0.2), (0.24, 84, 0.6, 0.2),
                  (0.48, 89, 1.7, 0.6), (0.48, 81, 1.7, 0.6), (0.48, 65, 1.7, 0.6)),
        "echo": (0.26, 2, 0.4),
    },
    # Sunken city: A minor bells tolling down the old stairs, then an organ chord settles.
    "city": {
        "partials": BELL,
        "notes": ((0.0, 81, 1.6, 0.6), (0.2, 76, 1.6, 0.6), (0.4, 72, 1.6, 0.6),
                  (0.6, 69, 1.6, 0.6), (0.9, 57, 2.0, 1.0), (0.9, 64, 2.0, 1.0),
                  (0.9, 69, 2.0, 1.0), (0.9, 45, 2.0, 1.0)),
        "echo": (0.35, 3, 0.45),
    },
    # Washing machine: the end-of-cycle beep, three short beeps and a happy C major chord.
    "washer": {
        "partials": ((1.0, 1.0), (3.0, 0.3), (5.0, 0.15)),
        "attack": 0.004,
        "notes": ((0.0, 88, 0.2, 0.12), (0.3, 88, 0.2, 0.12), (0.6, 88, 0.2, 0.12),
                  (1.0, 72, 1.7, 0.8), (1.0, 76, 1.7, 0.8), (1.0, 79, 1.7, 0.8),
                  (1.0, 84, 1.7, 0.8)),
        "echo": (0.3, 1, 0.3),
    },
    # Inside the whale: a wobbly bell line that gets swallowed, then a fat low chord.
    "whale": {
        "partials": BELL,
        "notes": ((0.0, 81, 1.2, 0.5), (0.14, 76, 1.2, 0.5), (0.28, 79, 1.2, 0.5),
                  (0.42, 72, 1.2, 0.5), (0.56, 76, 1.2, 0.5), (0.8, 57, 2.0, 0.9),
                  (0.8, 64, 2.0, 0.9), (0.8, 45, 2.0, 0.9)),
        "echo": (0.3, 3, 0.4),
    },
    # Toilet flush: a bright C major run that spirals down the drain, a whoosh and a cheeky ding.
    "flush": {
        "partials": MALLET,
        "glide": 0.6,
        "hiss": 0.3,
        "notes": ((0.0, 84, 0.5, 0.2), (0.1, 79, 0.5, 0.2), (0.2, 76, 0.5, 0.2),
                  (0.3, 72, 0.5, 0.2), (0.4, 67, 0.5, 0.2), (0.5, 64, 0.5, 0.2),
                  (0.75, 60, 1.7, 0.7), (0.75, 64, 1.7, 0.7), (0.75, 67, 1.7, 0.7),
                  (0.75, 48, 1.7, 0.7)),
        "bell": (1.3, 96, 1.4),
        "echo": (0.3, 2, 0.4),
    },
    # Switchback: a bright A minor run that climbs, turns around and climbs again.
    "switchback": {
        "partials": MALLET,
        "notes": ((0.0, 69, 0.8, 0.25), (0.12, 72, 0.8, 0.25), (0.24, 76, 0.8, 0.25),
                  (0.36, 81, 0.8, 0.25), (0.48, 76, 0.8, 0.25), (0.6, 72, 0.8, 0.25),
                  (0.72, 76, 0.8, 0.25), (0.84, 81, 0.8, 0.25), (1.0, 84, 1.7, 0.7),
                  (1.0, 57, 1.7, 0.7), (1.0, 60, 1.7, 0.7), (1.0, 64, 1.7, 0.7)),
        "echo": (0.3, 2, 0.4),
    },
}


def jingle(spec: dict) -> list:
    n = int(JINGLE_SECONDS * JINGLE_RATE)
    out = [0.0] * n
    attack = spec.get("attack", 0.008)
    glide = spec.get("glide", 0.0)
    gap, count, fall = spec.get("echo", (0.3, 0, 0.0))

    def place(src: list, start: float, gain: float) -> None:
        offset = int(start * JINGLE_RATE)
        for i, s in enumerate(src):
            if offset + i < n:
                out[offset + i] += s * gain

    def note(start: float, midi: float, seconds: float, decay: float, partials, att: float):
        f = mt.hz(midi)
        if glide:
            fn = lambda t, f=f: f * (1.0 - glide * 0.2 * max(0.0, 1.0 - t / 0.12))
        else:
            fn = lambda t, f=f: f
        src = mt.voice(
            fn, seconds, lambda t: min(1.0, t / att) * math.exp(-t / decay), partials
        )
        place(src, start, 1.0)
        g = 1.0
        for k in range(1, count + 1):
            g *= fall
            place(src, start + gap * k, g)

    for start, midi, seconds, decay in spec["notes"]:
        note(start, midi, seconds, decay, spec["partials"], attack)
    if "bell" in spec:
        start, midi, seconds = spec["bell"]
        note(start, midi, seconds, seconds / 2.0, BELL, 0.004)
    if "hiss" in spec:
        rng = random.Random(7)
        burst = mt.bandpass(mt.noise(int(0.9 * JINGLE_RATE), rng), 1500.0, 5000.0)
        env = [math.exp(-i / (0.25 * JINGLE_RATE)) for i in range(len(burst))]
        place([b * e * 0.6 for b, e in zip(burst, env)], spec["hiss"], 1.0)
    return out


# --- ambience loops ---------------------------------------------------------

AMB_RATE = 8000
AMB_SECONDS = 8
AMB_N = AMB_RATE * AMB_SECONDS
AMB_RMS = 0.12


def lowpass(samples: list, cutoff: float) -> list:
    a = 1.0 - math.exp(-TAU * cutoff / AMB_RATE)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def bandpass(samples: list, low: float, high: float) -> list:
    return [a - b for a, b in zip(lowpass(samples, high), lowpass(samples, low))]


def add(out: list, src: list, start: float, gain: float) -> None:
    offset = int(start * AMB_RATE)
    for i, s in enumerate(src):
        out[(offset + i) % AMB_N] += s * gain


def bed(out: list, rng: random.Random, low: float, high: float, gain: float,
        swell: float = 0.3, cycles: int = 1, phase: float = 0.0) -> None:
    """Band-limited noise wash that loops seamlessly, breathing `cycles` times per loop."""
    fade = AMB_RATE
    raw = [rng.uniform(-1.0, 1.0) for _ in range(AMB_N + fade)]
    if low > 0.0:
        raw = bandpass(raw, low, high)
    else:
        raw = lowpass(raw, high)
    wash = raw[:AMB_N]
    for i in range(fade):
        g = i / fade
        wash[i] = wash[i] * g + raw[AMB_N + i] * (1.0 - g)
    for i in range(AMB_N):
        t = i / AMB_RATE
        lfo = 1.0 - swell + swell * (0.5 + 0.5 * math.sin(TAU * cycles * t / AMB_SECONDS + phase))
        out[i] += wash[i] * lfo * gain


def bubbles(out: list, rng: random.Random, count: int, low: float, high: float, gain: float):
    """Small rising blips at random times."""
    for _ in range(count):
        f0 = rng.uniform(low, high)
        length = rng.uniform(0.05, 0.14)
        phase = 0.0
        blip = []
        for i in range(int(length * AMB_RATE)):
            t = i / AMB_RATE
            phase += TAU * f0 * (1.0 + 1.6 * t / length) / AMB_RATE
            blip.append(math.sin(phase) * math.sin(math.pi * t / length))
        add(out, blip, rng.uniform(0.0, AMB_SECONDS), gain * rng.uniform(0.5, 1.0))


def drips(out: list, rng: random.Random, times: tuple, freq: float, gain: float):
    """A tiny falling pluck with two echoes, like a drop in a cavern."""
    for start in times:
        f = freq * rng.uniform(0.9, 1.2)
        drop = [
            math.sin(TAU * f * (1.0 - 0.3 * min(1.0, i / (0.06 * AMB_RATE))) * i / AMB_RATE)
            * math.exp(-i / (0.03 * AMB_RATE))
            for i in range(int(0.3 * AMB_RATE))
        ]
        for k, g in enumerate((1.0, 0.45, 0.2)):
            add(out, drop, start + 0.31 * k, gain * g)


def tinkles(out: list, rng: random.Random, times: tuple, low: float, high: float, gain: float):
    """Faint high glass chimes with a long fade."""
    for start in times:
        f = rng.uniform(low, high)
        chime = [
            (math.sin(TAU * f * i / AMB_RATE) + 0.3 * math.sin(TAU * f * 2.76 * i / AMB_RATE))
            * math.exp(-i / (0.5 * AMB_RATE))
            for i in range(int(1.6 * AMB_RATE))
        ]
        add(out, chime, start, gain)


def creaks(out: list, rng: random.Random, times: tuple, low: float, high: float, gain: float):
    """Timber groans: a wobbling saw through a low-pass, with a hump envelope."""
    for start in times:
        length = rng.uniform(0.9, 1.6)
        f0 = rng.uniform(low, high)
        raw = []
        phase = 0.0
        for i in range(int(length * AMB_RATE)):
            t = i / AMB_RATE
            f = f0 * (1.0 + 0.25 * math.sin(TAU * 0.9 * t) + 0.08 * math.sin(TAU * 7.0 * t))
            phase = (phase + f / AMB_RATE) % 1.0
            raw.append(2.0 * phase - 1.0)
        env = [math.sin(math.pi * i / len(raw)) ** 1.5 for i in range(len(raw))]
        add(out, [s * e for s, e in zip(lowpass(raw, 900.0), env)], start, gain)


def clanks(out: list, times: tuple, freq: float, gain: float):
    """Dull metal knocks, like a chain settling."""
    for start in times:
        knock = [
            (math.sin(TAU * freq * i / AMB_RATE) + 0.5 * math.sin(TAU * freq * 2.4 * i / AMB_RATE))
            * math.exp(-i / (0.12 * AMB_RATE))
            for i in range(int(0.6 * AMB_RATE))
        ]
        add(out, knock, start, gain)


def pings(out: list, times: tuple, freq: float, gain: float):
    """Sonar: one sine ping and a long fading echo."""
    ping = [
        math.sin(TAU * freq * i / AMB_RATE) * min(1.0, i / (0.01 * AMB_RATE))
        * math.exp(-i / (0.25 * AMB_RATE))
        for i in range(int(1.2 * AMB_RATE))
    ]
    for start in times:
        for k, g in enumerate((1.0, 0.4, 0.15)):
            add(out, ping, start + 1.5 * k, gain * g)


def moan(out: list, start: float, low: float, high: float, gain: float):
    """A slow distant whale-like glide."""
    length = 3.0
    phase = 0.0
    sound = []
    for i in range(int(length * AMB_RATE)):
        t = i / AMB_RATE
        f = low + (high - low) * math.sin(math.pi * t / length)
        phase += TAU * f / AMB_RATE
        sound.append((math.sin(phase) + 0.4 * math.sin(2.0 * phase)) * math.sin(math.pi * t / length) ** 2)
    add(out, sound, start, gain)


def thumps(out: list, rng: random.Random, times: tuple, cutoff: float, gain: float):
    """Low rumbling bursts, like a geyser building up."""
    for start in times:
        length = rng.uniform(1.2, 2.0)
        raw = lowpass([rng.uniform(-1.0, 1.0) for _ in range(int(length * AMB_RATE))], cutoff)
        env = [math.sin(math.pi * i / len(raw)) ** 2 for i in range(len(raw))]
        add(out, [s * e for s, e in zip(raw, env)], start, gain)


def steam(out: list, rng: random.Random, times: tuple, gain: float):
    for start in times:
        length = rng.uniform(0.6, 1.1)
        raw = bandpass([rng.uniform(-1.0, 1.0) for _ in range(int(length * AMB_RATE))], 1200.0, 3500.0)
        env = [min(1.0, i / (0.05 * AMB_RATE)) * math.exp(-i / (0.35 * AMB_RATE)) for i in range(len(raw))]
        add(out, [s * e for s, e in zip(raw, env)], start, gain)


def shimmer(out: list, rng: random.Random, times: tuple, low: float, high: float, gain: float):
    """A bunch of high sines fluttering in and out."""
    for start in times:
        length = rng.uniform(1.4, 2.2)
        tones = [(rng.uniform(low, high), rng.uniform(4.0, 9.0), rng.uniform(0, TAU)) for _ in range(4)]
        sound = []
        for i in range(int(length * AMB_RATE)):
            t = i / AMB_RATE
            v = sum(math.sin(TAU * f * t) * (0.6 + 0.4 * math.sin(TAU * r * t + p)) for f, r, p in tones)
            sound.append(v * math.sin(math.pi * t / length) ** 2)
        add(out, sound, start, gain)


def pops(out: list, rng: random.Random, count: int, gain: float):
    """Tiny fish-flick pops."""
    for _ in range(count):
        f = rng.uniform(500.0, 900.0)
        pop = [math.sin(TAU * f * i / AMB_RATE) * math.exp(-i / (0.012 * AMB_RATE))
               for i in range(int(0.08 * AMB_RATE))]
        add(out, pop, rng.uniform(0.0, AMB_SECONDS), gain * rng.uniform(0.5, 1.0))


def _zigzag(out, rng):
    bed(out, rng, 0.0, 500.0, 1.0, swell=0.5, cycles=2)
    bubbles(out, rng, 9, 700.0, 1400.0, 0.12)


def _pachinko(out, rng):
    bed(out, rng, 0.0, 250.0, 0.5, swell=0.3, cycles=1)
    drips(out, rng, (0.7, 2.6, 4.1, 6.3), 1300.0, 0.16)
    tinkles(out, rng, (1.4, 3.3, 5.2, 6.9), 2200.0, 3300.0, 0.05)


def _wreck(out, rng):
    bed(out, rng, 0.0, 400.0, 0.9, swell=0.5, cycles=1)
    creaks(out, rng, (0.5, 2.9, 5.4), 90.0, 170.0, 0.32)
    clanks(out, (1.9, 4.6, 7.0), 320.0, 0.14)


def _whirlpool(out, rng):
    bed(out, rng, 150.0, 1100.0, 1.0, swell=0.75, cycles=2)
    bed(out, rng, 400.0, 2200.0, 0.45, swell=0.85, cycles=2, phase=math.pi / 2.0)
    bed(out, rng, 0.0, 200.0, 0.5, swell=0.4, cycles=1)


def _jelly(out, rng):
    bed(out, rng, 0.0, 260.0, 0.35, swell=0.4, cycles=1)
    shimmer(out, rng, (0.3, 2.6, 5.2), 1400.0, 3000.0, 0.035)
    bubbles(out, rng, 5, 500.0, 900.0, 0.1)


def _abyss(out, rng):
    bed(out, rng, 0.0, 150.0, 0.8, swell=0.3, cycles=1)
    pings(out, (0.4,), 1500.0, 0.2)
    moan(out, 5.0, 60.0, 95.0, 0.3)


def _vents(out, rng):
    bed(out, rng, 0.0, 160.0, 1.0, swell=0.5, cycles=2)
    thumps(out, rng, (0.5, 3.6), 120.0, 0.9)
    steam(out, rng, (2.2, 4.9, 6.6), 0.25)
    bubbles(out, rng, 10, 200.0, 500.0, 0.14)


def _cave(out, rng):
    bed(out, rng, 0.0, 240.0, 0.7, swell=0.3, cycles=1)
    drips(out, rng, (0.7, 2.3, 3.4, 5.2, 6.6), 1500.0, 0.16)
    shimmer(out, rng, (1.8, 4.4, 6.9), 1800.0, 3400.0, 0.03)
    pings(out, (3.0,), 1900.0, 0.08)
def _kraken(out, rng):
    bed(out, rng, 0.0, 140.0, 0.9, swell=0.3, cycles=1)
    thumps(out, rng, (1.0, 4.6), 90.0, 0.6)
    moan(out, 2.6, 55.0, 85.0, 0.3)
    bubbles(out, rng, 6, 250.0, 600.0, 0.1)
def _gravity(out, rng):
    # Two slow swells per loop, like the water sloshing one way then the other.
    bed(out, rng, 60.0, 500.0, 0.9, swell=0.8, cycles=2)
    bed(out, rng, 300.0, 1800.0, 0.3, swell=0.9, cycles=2, phase=math.pi)
    pings(out, (1.2, 5.2), 1100.0, 0.12)
    bubbles(out, rng, 6, 500.0, 1100.0, 0.08)


def _tide(out, rng):
    bed(out, rng, 0.0, 450.0, 0.9, swell=0.6, cycles=1)
    bed(out, rng, 500.0, 2400.0, 0.25, swell=0.7, cycles=1, phase=math.pi)
    drips(out, rng, (1.1, 3.4, 5.0, 6.8), 1100.0, 0.14)
    bubbles(out, rng, 4, 500.0, 1000.0, 0.08)


def _fork(out, rng):
    bed(out, rng, 90.0, 520.0, 0.45, swell=0.4, cycles=2)
    bubbles(out, rng, 9, 700.0, 1500.0, 0.1)
    shimmer(out, rng, (1.0, 3.3, 5.8), 1200.0, 2800.0, 0.03)
    pings(out, (0.6,), 1800.0, 0.12)


def _city(out, rng):
    bed(out, rng, 0.0, 300.0, 0.8, swell=0.4, cycles=1)
    thumps(out, rng, (2.3, 6.1), 70.0, 0.45)
    drips(out, rng, (0.8, 3.9, 5.6), 1200.0, 0.12)
    pings(out, (1.6,), 880.0, 0.1)
    bubbles(out, rng, 4, 300.0, 700.0, 0.07)


def _washer(out, rng):
    # The hum of the motor, water sloshing around the drum and the load tumbling over.
    bed(out, rng, 0.0, 300.0, 0.9, swell=0.3, cycles=2)
    bed(out, rng, 400.0, 1800.0, 0.3, swell=0.8, cycles=2, phase=math.pi)
    thumps(out, rng, (0.8, 2.9, 4.6, 6.5), 180.0, 0.5)
    bubbles(out, rng, 8, 500.0, 1100.0, 0.1)


def heartbeat(out: list, beats: tuple, freq: float, gain: float):
    """Lub-dub: two soft low thumps per beat."""
    for start in beats:
        for k, (delay, g) in enumerate(((0.0, 1.0), (0.32, 0.65))):
            thump = [math.sin(TAU * freq * (1.0 - 0.3 * i / AMB_RATE) * i / AMB_RATE)
                     * math.exp(-i / (0.09 * AMB_RATE)) for i in range(int(0.3 * AMB_RATE))]
            add(out, thump, start + delay, gain * g)


def gurgles(out: list, rng: random.Random, times: tuple, low: float, high: float, gain: float):
    """Wet glugs: short falling tones with a wobble."""
    for start in times:
        f0 = rng.uniform(low, high)
        length = rng.uniform(0.25, 0.5)
        glug = [math.sin(TAU * f0 * (1.0 - 0.5 * i / (length * AMB_RATE)) * i / AMB_RATE
                         + 2.0 * math.sin(TAU * 18.0 * i / AMB_RATE))
                * math.sin(math.pi * i / (length * AMB_RATE)) ** 2
                for i in range(int(length * AMB_RATE))]
        add(out, glug, start, gain)


def _whale(out, rng):
    bed(out, rng, 0.0, 300.0, 0.8, swell=0.4, cycles=1)
    heartbeat(out, (0.5, 2.5, 4.5, 6.5), 55.0, 0.9)
    gurgles(out, rng, (1.3, 3.3, 5.6, 7.2), 140.0, 260.0, 0.35)
    bubbles(out, rng, 5, 300.0, 700.0, 0.09)


def _flush(out, rng):
    bed(out, rng, 0.0, 300.0, 0.9, swell=0.6, cycles=1)
    bed(out, rng, 300.0, 1600.0, 0.3, swell=0.8, cycles=2, phase=math.pi / 3.0)
    drips(out, rng, (0.8, 2.6, 4.1, 6.3, 7.3), 800.0, 0.16)
    bubbles(out, rng, 8, 200.0, 600.0, 0.12)
    clanks(out, (1.5, 5.2), 180.0, 0.12)


def _switchback(out, rng):
    bed(out, rng, 0.0, 300.0, 0.9, swell=0.5, cycles=1)
    bed(out, rng, 300.0, 1400.0, 0.25, swell=0.7, cycles=2, phase=math.pi / 4.0)
    clanks(out, (0.9, 2.7, 4.4, 6.1), 220.0, 0.14)
    bubbles(out, rng, 6, 250.0, 650.0, 0.1)


AMBIENCE = {
    "zigzag": (31, _zigzag),
    "pachinko": (32, _pachinko),
    "wreck": (33, _wreck),
    "whirlpool": (34, _whirlpool),
    "jelly": (35, _jelly),
    "abyss": (36, _abyss),
    "vents": (37, _vents),
    "cave": (38, _cave),
    "kraken": (39, _kraken),
    "gravity": (40, _gravity),
    "tide": (41, _tide),
    "fork": (42, _fork),
    "city": (43, _city),
    "washer": (50, _washer),
    "whale": (51, _whale),
    "flush": (62, _flush),
    "switchback": (72, _switchback),
}


def ambience(map_id: str) -> list:
    seed, build = AMBIENCE[map_id]
    rng = random.Random(seed)
    out = [0.0] * AMB_N
    build(out, rng)
    rms = math.sqrt(sum(s * s for s in out) / AMB_N)
    scale = AMB_RMS / max(1e-9, rms)
    return [math.tanh(s * scale * 1.2) / 1.2 for s in out]
