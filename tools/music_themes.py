"""One seamless ambient loop per map, synthesized from scratch (pure Python).

Used by generate_audio.py. Every theme is a dict of layers rendered by `render`: pads over
a chord loop, a sub drone, filtered-noise rumble and a few optional event layers (plucks,
bells, arps, pulses, hiss, pings). Everything is placed modulo the loop length and pad
frequencies are snapped to whole cycles per loop, so the loop point is seamless.
"""

import math
import random

RATE = 16000
SECONDS = 24
TAU = 2.0 * math.pi
N = RATE * SECONDS
# Every theme is scaled to this RMS, so maps are equally loud whatever their layers.
TARGET_RMS = 0.11


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def snap(freq: float) -> float:
    return max(1, round(freq * SECONDS)) / SECONDS


def lowpass(samples: list, cutoff: float) -> list:
    a = 1.0 - math.exp(-TAU * cutoff / RATE)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def bandpass(samples: list, low: float, high: float) -> list:
    hi = lowpass(samples, high)
    lo = lowpass(hi, low)
    return [a - b for a, b in zip(hi, lo)]


def noise(count: int, rng: random.Random) -> list:
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def add(out: list, src: list, start: float, gain: float) -> None:
    """Mixes a snippet in at `start` seconds, wrapping around the loop end."""
    offset = int(start * RATE)
    for i, s in enumerate(src):
        out[(offset + i) % N] += s * gain


def voice(freq_fn, seconds: float, env_fn, partials=((1.0, 1.0),)) -> list:
    phase = 0.0
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        phase += TAU * freq_fn(t) / RATE
        out.append(sum(a * math.sin(phase * m) for m, a in partials) * env_fn(t))
    return out


def pluck(freq: float, seconds: float, decay: float, partials=((1.0, 1.0), (2.0, 0.15))) -> list:
    return voice(
        lambda t: freq, seconds, lambda t: min(1.0, t / 0.008) * math.exp(-t / decay), partials
    )


def echo(out: list, src: list, start: float, gain: float, gaps=(0.4, 0.8, 1.2), fall=0.45) -> None:
    add(out, src, start, gain)
    g = gain
    for gap in gaps:
        g *= fall
        add(out, src, start + gap, g)


def render_pads(out: list, chords, partials, gain: float, trem_rate: float, trem_depth: float):
    """Each chord fades in and out over two chord lengths; neighbours sum to a constant."""
    slot = SECONDS / len(chords)
    for idx, chord in enumerate(chords):
        center = (idx + 0.5) * slot
        for note_no, midi in enumerate(chord[1:]):
            freq = snap(hz(midi))
            lfo = snap(trem_rate * (1.0 + 0.25 * note_no))
            lfo_phase = note_no * 1.7
            first = int((center - slot) * RATE)
            for k in range(int(2 * slot * RATE)):
                i = first + k
                t = i / RATE
                d = t - center
                w = 0.5 + 0.5 * math.cos(math.pi * d / slot)
                trem = 1.0 - trem_depth + trem_depth * math.sin(TAU * lfo * t + lfo_phase)
                v = sum(a * math.sin(TAU * freq * m * t + 0.5 * m) for m, a in partials)
                out[i % N] += v * w * trem * gain
    # Sub drone follows the chord root the same way.
    for idx, chord in enumerate(chords):
        center = (idx + 0.5) * slot
        freq = snap(hz(chord[0]))
        first = int((center - slot) * RATE)
        for k in range(int(2 * slot * RATE)):
            i = first + k
            t = i / RATE
            w = 0.5 + 0.5 * math.cos(math.pi * (t - center) / slot)
            out[i % N] += 0.5 * gain * 1.6 * w * math.sin(TAU * freq * t)


def render_rumble(out: list, rng: random.Random, cutoff: float, gain: float) -> None:
    fade = int(2.0 * RATE)
    raw = lowpass(noise(N + fade, rng), cutoff)
    rumble = raw[:N]
    for i in range(fade):
        g = i / fade
        rumble[i] = rumble[i] * g + raw[N + i] * (1.0 - g)
    top = max(1e-9, max(abs(s) for s in rumble))
    for i in range(N):
        t = i / RATE
        out[i] += rumble[i] / top * gain * (0.8 + 0.3 * math.sin(TAU * 2.0 / SECONDS * t))


def render_plucks(out: list, rng: random.Random, spec: dict) -> None:
    times = sorted(rng.uniform(0.3, SECONDS - 0.5) for _ in range(spec["count"]))
    for start in times:
        midi = rng.choice(spec["notes"])
        if spec.get("bell"):
            f = hz(midi)
            snippet = voice(
                lambda t, f=f: f,
                spec["decay"] * 5,
                lambda t: min(1.0, t / 0.004) * math.exp(-t / spec["decay"]),
                ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2), (8.93, 0.1)),
            )
        elif spec.get("glide"):
            f = hz(midi)
            snippet = voice(
                lambda t, f=f: f * (0.78 + 0.22 * min(1.0, t / 0.18)),
                spec["decay"] * 4,
                lambda t: min(1.0, t / 0.03) * math.exp(-t / spec["decay"]),
                ((1.0, 1.0), (2.0, 0.12)),
            )
        else:
            snippet = pluck(hz(midi), spec["decay"] * 4, spec["decay"])
        echo(out, snippet, start, spec["gain"], spec.get("gaps", (0.42, 0.84, 1.26)))


def render_arp(out: list, spec: dict) -> None:
    """Steady notes cycling through `pattern` (midi), one per step, marimba-like."""
    step = 60.0 / spec["bpm"] / spec.get("div", 2)
    count = int(SECONDS / step + 0.5)
    pattern = spec["pattern"]
    for i in range(count):
        midi = pattern[i % len(pattern)]
        accent = 1.0 if i % spec.get("accent", 4) == 0 else 0.6
        snippet = pluck(hz(midi), spec["decay"] * 4, spec["decay"], spec.get("partials", ((1.0, 1.0), (2.0, 0.15))))
        add(out, snippet, i * step, spec["gain"] * accent)


def render_pulse(out: list, spec: dict) -> None:
    """Soft low thumps on a beat grid; `double` adds a quieter second beat (heartbeat)."""
    step = 60.0 / spec["bpm"]
    for i in range(int(SECONDS / step + 0.5)):
        thump = voice(
            lambda t: spec["freq"] * (0.5 + 0.5 * math.exp(-t / 0.05)),
            0.5,
            lambda t: min(1.0, t / 0.004) * math.exp(-t / spec["decay"]),
        )
        add(out, thump, i * step, spec["gain"])
        if spec.get("double"):
            add(out, thump, i * step + spec["double"], spec["gain"] * 0.6)


def render_hiss(out: list, rng: random.Random, spec: dict) -> None:
    """Short filtered-noise bursts (steam, hats) on given beats of a bpm grid."""
    step = 60.0 / spec["bpm"]
    for i in range(int(SECONDS / step + 0.5)):
        if i % spec["every"] != spec["offset"]:
            continue
        burst = bandpass(noise(int(spec["decay"] * 5 * RATE), rng), spec["low"], spec["high"])
        burst = [b * math.exp(-(k / RATE) / spec["decay"]) for k, b in enumerate(burst)]
        add(out, burst, i * step, spec["gain"] * 6.0)


def render_bass(out: list, spec: dict) -> None:
    step = 60.0 / spec["bpm"] / spec.get("div", 2)
    pattern = spec["pattern"]
    for i in range(int(SECONDS / step + 0.5)):
        midi = pattern[i % len(pattern)]
        if midi is None:
            continue
        snippet = pluck(hz(midi), spec["decay"] * 4, spec["decay"], ((1.0, 1.0), (2.0, 0.3)))
        add(out, snippet, i * step, spec["gain"])


def render_pings(out: list, spec: dict) -> None:
    """Sonar pings with a long echo: single high sines at fixed times."""
    for start in spec["times"]:
        snippet = pluck(spec["freq"], spec["decay"] * 4, spec["decay"], ((1.0, 1.0),))
        echo(out, snippet, start, spec["gain"], spec.get("gaps", (0.9, 1.8, 2.7)), 0.5)


def render_creaks(out: list, rng: random.Random, spec: dict) -> None:
    for start in spec["times"]:
        length = spec["length"]
        raw = bandpass(noise(int(length * RATE), rng), spec["low"], spec["high"])
        creak = [
            r * math.sin(math.pi * k / len(raw)) ** 2 * (0.6 + 0.4 * math.sin(TAU * 7.0 * k / RATE))
            for k, r in enumerate(raw)
        ]
        add(out, creak, start, spec["gain"] * 8.0)


def render_swirl(out: list, rng: random.Random, spec: dict) -> None:
    """Filtered noise swelling in and out like rushing water."""
    fade = int(2.0 * RATE)
    long = bandpass(noise(N + fade, rng), spec["low"], spec["high"])
    raw = long[:N]
    for i in range(fade):  # crossfade the tail into the head so the loop has no tick
        g = i / fade
        raw[i] = raw[i] * g + long[N + i] * (1.0 - g)
    lfo = snap(spec["rate"])
    for i in range(N):
        t = i / RATE
        out[i] += raw[i] * (0.5 + 0.5 * math.sin(TAU * lfo * t)) * spec["gain"] * 6.0


def render_crackle(out: list, rng: random.Random, spec: dict) -> None:
    for _ in range(spec["count"]):
        start = rng.uniform(0.0, SECONDS)
        tick = [
            rng.uniform(-1.0, 1.0) * math.exp(-k / (RATE * 0.004))
            for k in range(int(0.03 * RATE))
        ]
        add(out, tick, start, spec["gain"] * rng.uniform(0.3, 1.0))


def render(theme: dict) -> list:
    rng = random.Random(theme["seed"])
    out = [0.0] * N
    render_pads(
        out,
        theme["chords"],
        theme["pad_partials"],
        theme["pad_gain"],
        theme["trem_rate"],
        theme["trem_depth"],
    )
    render_rumble(out, rng, theme["rumble_cutoff"], theme["rumble_gain"])
    for layer in theme.get("layers", ()):
        kind = layer["kind"]
        if kind == "plucks":
            render_plucks(out, rng, layer)
        elif kind == "arp":
            render_arp(out, layer)
        elif kind == "pulse":
            render_pulse(out, layer)
        elif kind == "hiss":
            render_hiss(out, rng, layer)
        elif kind == "bass":
            render_bass(out, layer)
        elif kind == "pings":
            render_pings(out, layer)
        elif kind == "creaks":
            render_creaks(out, rng, layer)
        elif kind == "swirl":
            render_swirl(out, rng, layer)
        elif kind == "crackle":
            render_crackle(out, rng, layer)
    rms = math.sqrt(sum(s * s for s in out) / N)
    scale = TARGET_RMS * theme.get("level", 1.0) / max(1e-9, rms)
    # Gentle tanh keeps transients from clipping without touching the bed.
    return [math.tanh(s * scale * 1.2) / 1.2 for s in out]


WARM = ((1.0, 1.0), (2.0, 0.35), (3.0, 0.1))
GLASS = ((1.0, 1.0), (2.0, 0.15))
BRASS = ((1.0, 1.0), (2.0, 0.5), (3.0, 0.4), (4.0, 0.25))
MALLET = ((1.0, 1.0), (4.0, 0.3))

# Chords are (root, note, note, note) as MIDI numbers; the root feeds the sub drone.
THEMES = {
    # Kelp forest: warm D dorian pads that sway, soft mallet plucks.
    "zigzag": {
        "seed": 21,
        "chords": (
            (38, 50, 57, 60, 64),
            (43, 50, 55, 59, 62),
            (36, 48, 55, 59, 64),
            (45, 52, 55, 60, 64),
        ),
        "pad_partials": WARM,
        "pad_gain": 0.10,
        "trem_rate": 0.09,
        "trem_depth": 0.3,
        "rumble_cutoff": 220.0,
        "rumble_gain": 0.5,
        "layers": (
            {
                "kind": "plucks",
                "count": 16,
                "notes": (74, 76, 79, 81, 84, 86),
                "decay": 0.55,
                "gain": 0.10,
            },
        ),
    },
    # Crystal cavern: E lydian pads, glassy bells with long echoes.
    "pachinko": {
        "seed": 22,
        "chords": (
            (40, 52, 56, 59, 63),
            (35, 47, 54, 59, 61),
            (37, 49, 56, 59, 64),
            (33, 45, 52, 56, 61),
        ),
        "pad_partials": GLASS,
        "pad_gain": 0.07,
        "trem_rate": 0.12,
        "trem_depth": 0.35,
        "rumble_cutoff": 180.0,
        "rumble_gain": 0.25,
        "layers": (
            {
                "kind": "plucks",
                "count": 26,
                "notes": (76, 80, 83, 85, 88, 92),
                "decay": 0.9,
                "gain": 0.075,
                "bell": True,
                "gaps": (0.33, 0.66, 0.99, 1.32),
            },
        ),
    },
    # Shipwreck: C minor brass-like drone, tolling bell, timber creaks.
    "wreck": {
        "seed": 23,
        "chords": (
            (36, 48, 51, 55, 58),
            (32, 44, 48, 51, 55),
            (29, 41, 48, 53, 56),
            (31, 43, 50, 55, 58),
        ),
        "pad_partials": BRASS,
        "pad_gain": 0.055,
        "trem_rate": 0.06,
        "trem_depth": 0.25,
        "rumble_cutoff": 320.0,
        "rumble_gain": 0.9,
        "layers": (
            {"kind": "pings", "times": (2.0, 14.0), "freq": hz(48), "decay": 1.4,
             "gain": 0.5, "gaps": (1.6, 3.2)},
            {"kind": "creaks", "times": (5.5, 9.0, 17.5, 21.0), "length": 1.6,
             "low": 120.0, "high": 380.0, "gain": 0.09},
            {"kind": "plucks", "count": 5, "notes": (60, 63, 67), "decay": 1.2, "gain": 0.06,
             "bell": True, "gaps": (0.9, 1.8)},
        ),
    },
    # Whirlpool: A minor arpeggio circling round chord tones over rushing water.
    "whirlpool": {
        "seed": 24,
        "chords": (
            (45, 57, 60, 64, 69),
            (41, 53, 57, 60, 65),
            (36, 55, 60, 64, 67),
            (43, 55, 59, 62, 67),
        ),
        "pad_partials": WARM,
        "pad_gain": 0.08,
        "trem_rate": 0.25,
        "trem_depth": 0.4,
        "rumble_cutoff": 280.0,
        "rumble_gain": 0.6,
        "layers": (
            {"kind": "swirl", "low": 250.0, "high": 1400.0, "rate": 0.25, "gain": 0.03},
            {"kind": "arp", "bpm": 120, "div": 2, "decay": 0.28, "gain": 0.075, "accent": 6,
             "pattern": (57, 60, 64, 69, 72, 69, 64, 60, 53, 57, 60, 65, 69, 65, 60, 57,
                         55, 60, 64, 67, 72, 67, 64, 60, 55, 59, 62, 67, 71, 67, 62, 59)},
        ),
    },
    # Jellyfish field: floaty F lydian, big slow tremolo, gliding bloops.
    "jelly": {
        "seed": 25,
        "chords": (
            (41, 53, 57, 60, 64),
            (34, 53, 58, 62, 65),
            (38, 50, 57, 60, 64),
            (36, 55, 60, 62, 67),
        ),
        "pad_partials": GLASS,
        "pad_gain": 0.085,
        "trem_rate": 0.17,
        "trem_depth": 0.45,
        "rumble_cutoff": 200.0,
        "rumble_gain": 0.3,
        "layers": (
            {"kind": "plucks", "count": 11, "notes": (77, 79, 81, 84, 86, 89), "decay": 0.7,
             "gain": 0.10, "glide": True, "gaps": (0.55, 1.1, 1.65)},
        ),
    },
    # Abyss: tritone drone, slow heartbeat, distant sonar.
    "abyss": {
        "seed": 26,
        "level": 0.85,
        "chords": (
            (28, 40, 46, 47, 52),
            (27, 39, 45, 46, 51),
            (25, 37, 43, 44, 49),
            (26, 38, 44, 45, 50),
        ),
        "pad_partials": ((1.0, 1.0), (2.0, 0.5)),
        "pad_gain": 0.09,
        "trem_rate": 0.05,
        "trem_depth": 0.3,
        "rumble_cutoff": 150.0,
        "rumble_gain": 1.0,
        "layers": (
            {"kind": "pulse", "bpm": 45, "freq": 70.0, "decay": 0.16, "gain": 0.35,
             "double": 0.28},
            {"kind": "pings", "times": (3.0, 11.0, 19.0), "freq": 1568.0, "decay": 1.0,
             "gain": 0.06},
        ),
    },
    # Volcanic vents: E phrygian, thumping pulse, steam hiss, lava crackle.
    "vents": {
        "seed": 27,
        "chords": (
            (28, 40, 52, 55, 59),
            (29, 41, 53, 57, 60),
            (28, 40, 52, 55, 59),
            (26, 38, 50, 53, 57),
        ),
        "pad_partials": BRASS,
        "pad_gain": 0.045,
        "trem_rate": 0.1,
        "trem_depth": 0.2,
        "rumble_cutoff": 260.0,
        "rumble_gain": 0.8,
        "layers": (
            {"kind": "pulse", "bpm": 90, "freq": 60.0, "decay": 0.13, "gain": 0.45},
            {"kind": "hiss", "bpm": 90, "every": 2, "offset": 1, "decay": 0.22, "low": 1500.0,
             "high": 5000.0, "gain": 0.05},
            {"kind": "bass", "bpm": 90, "div": 2, "decay": 0.22, "gain": 0.28,
             "pattern": (40, None, 40, 41, 40, None, 43, 41)},
            {"kind": "crackle", "count": 70, "gain": 0.05},
        ),
    },
    # Coral maze: bright G major, bouncy bass and a marimba arpeggio.
    "coral": {
        "seed": 28,
        "chords": (
            (43, 55, 59, 62, 67),
            (40, 52, 55, 59, 64),
            (36, 55, 60, 64, 67),
            (38, 54, 57, 62, 66),
        ),
        "pad_partials": WARM,
        "pad_gain": 0.07,
        "trem_rate": 0.13,
        "trem_depth": 0.25,
        "rumble_cutoff": 200.0,
        "rumble_gain": 0.2,
        "layers": (
            {"kind": "arp", "bpm": 120, "div": 2, "decay": 0.16, "gain": 0.09, "accent": 4,
             "partials": MALLET,
             "pattern": (79, 83, 86, 83, 79, 83, 88, 86,
                         76, 79, 83, 79, 76, 79, 83, 88,
                         72, 76, 79, 76, 72, 76, 84, 79,
                         74, 78, 81, 78, 74, 78, 86, 81)},
            {"kind": "bass", "bpm": 120, "div": 1, "decay": 0.3, "gain": 0.30,
             "pattern": (43, None, 50, None, 40, None, 47, None, 36, None, 43, None, 38, None,
                         45, None)},
            {"kind": "hiss", "bpm": 120, "every": 1, "offset": 0, "decay": 0.03, "low": 3000.0,
             "high": 6000.0, "gain": 0.02},
        ),
    },
    # Kraken's lair: D minor brass drone, slow war drum and a low tolling bell.
    "kraken": {
        "seed": 29,
        "level": 0.9,
        "chords": (
            (26, 38, 45, 50, 53),
            (22, 34, 41, 46, 50),
            (24, 36, 43, 48, 51),
            (21, 33, 40, 45, 49),
        ),
        "pad_partials": BRASS,
        "pad_gain": 0.05,
        "trem_rate": 0.07,
        "trem_depth": 0.3,
        "rumble_cutoff": 170.0,
        "rumble_gain": 0.9,
        "layers": (
            {"kind": "pulse", "bpm": 60, "freq": 52.0, "decay": 0.22, "gain": 0.45,
             "double": 0.5},
            {"kind": "pings", "times": (2.0, 10.0, 18.0), "freq": 293.66, "decay": 1.6,
             "gain": 0.07},
        ),
    },
}
