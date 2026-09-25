#!/usr/bin/env python3
"""Synthesises every music track and sound effect for Oath of Embers.

Nothing is sampled: plucked lute, flute, pads, strings, brass and drums are built from
sine partials and filtered noise, so the whole soundtrack is reproducible from this file.

    pip install numpy soundfile
    python3 tools/generate_audio.py            # writes godot/assets/audio/{music,sfx}/
"""

from pathlib import Path

import numpy as np
import soundfile as sf

RATE = 44100
SFX_RATE = 44100
ROOT = Path(__file__).resolve().parent.parent / "godot" / "assets" / "audio"
rng = np.random.default_rng(1207)

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(name: str) -> float:
    """'D4' -> frequency. Octave number follows scientific pitch (A4 = 440)."""
    pitch, octave = name[:-1], int(name[-1])
    semitone = NOTE_INDEX[pitch] + (octave + 1) * 12
    return 440.0 * 2 ** ((semitone - 69) / 12)


def t_axis(duration: float, rate: int = RATE) -> np.ndarray:
    return np.arange(int(duration * rate)) / rate


def envelope(length: int, attack: float, release: float, rate: int = RATE) -> np.ndarray:
    env = np.ones(length)
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    env[:a] = np.linspace(0, 1, min(a, length))[: min(a, length)]
    if r < length:
        env[-r:] *= np.linspace(1, 0, r)
    return env


def lowpass(signal: np.ndarray, cutoff: float, rate: int = RATE) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / rate)
    spectrum *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(signal))


def bandpass(signal: np.ndarray, low: float, high: float, rate: int = RATE) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / rate)
    mask = 1 / (1 + (low / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * mask, len(signal))


# --- instruments -------------------------------------------------------------------

def pluck(freq: float, duration: float, brightness: float = 1.0) -> np.ndarray:
    """Lute / harp: harmonics that die faster the higher they are, plus a pick click."""
    t = t_axis(duration)
    out = np.zeros_like(t)
    for n in range(1, 11):
        if freq * n > 9000:
            break
        amp = (1 / n ** 1.15) * (0.55 if n % 2 == 0 else 1.0) * (brightness if n > 3 else 1.0)
        decay = 1.8 + n * 1.35
        out += amp * np.sin(2 * np.pi * freq * n * t * (1 + 0.0004 * n)) * np.exp(-decay * t)
    click = rng.normal(0, 1, len(t)) * np.exp(-t * 180) * 0.08
    return (out + click) * envelope(len(t), 0.003, 0.05)


def flute(freq: float, duration: float) -> np.ndarray:
    t = t_axis(duration)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * freq * np.cumsum(vibrato) / RATE
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    breath = lowpass(rng.normal(0, 1, len(t)), 2500) * 0.05
    return (tone + breath) * envelope(len(t), 0.07, 0.12) * 0.55


def pad(freqs: list, duration: float, warmth: float = 1.0) -> np.ndarray:
    t = t_axis(duration)
    out = np.zeros_like(t)
    for freq in freqs:
        for detune in (-0.25, 0.0, 0.3):
            f = freq * (1 + detune * 0.003)
            out += np.sin(2 * np.pi * f * t) + 0.3 * warmth * np.sin(4 * np.pi * f * t) + 0.12 * warmth * np.sin(6 * np.pi * f * t)
    swell = 0.85 + 0.15 * np.sin(2 * np.pi * 0.2 * t)
    return out * swell * envelope(len(t), min(0.9, duration / 3), min(0.9, duration / 3)) / (len(freqs) * 3)


def strings(freq: float, duration: float, bite: float = 1.0) -> np.ndarray:
    """Bowed ensemble: saw-ish partials, slight detune chorus, quick bow attack."""
    t = t_axis(duration)
    out = np.zeros_like(t)
    for n in range(1, 9):
        if freq * n > 8000:
            break
        for detune in (-0.002, 0.002):
            out += (1 / n) * np.sin(2 * np.pi * freq * n * (1 + detune) * t + n)
    return out * envelope(len(t), 0.02 / bite, 0.06) * 0.25


def brass(freq: float, duration: float) -> np.ndarray:
    t = t_axis(duration)
    bright = np.clip(t / 0.08, 0, 1) * np.exp(-t * 1.5) * 0.7 + 0.3
    out = np.zeros_like(t)
    for n in range(1, 10):
        if freq * n > 7000:
            break
        out += (1 / n) * np.sin(2 * np.pi * freq * n * t) * (bright ** (n * 0.35))
    return out * envelope(len(t), 0.03, 0.1) * 0.35


def choir(freq: float, duration: float) -> np.ndarray:
    """'Aah' pad: harmonics weighted by two vowel formants."""
    t = t_axis(duration)
    out = np.zeros_like(t)
    for n in range(1, 16):
        f = freq * n
        weight = np.exp(-((f - 750) / 260) ** 2) + 0.7 * np.exp(-((f - 1150) / 300) ** 2) + 0.3 / n
        vib = 1 + 0.004 * np.sin(2 * np.pi * 4.8 * t + n)
        out += weight * np.sin(2 * np.pi * f * np.cumsum(vib) / RATE)
    return out * envelope(len(t), 0.35, 0.4) * 0.18


def drum(kind: str, duration: float = 0.6) -> np.ndarray:
    t = t_axis(duration)
    if kind == "taiko":
        pitch = 70 + 60 * np.exp(-t * 25)
        body = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 5.5)
        slap = lowpass(rng.normal(0, 1, len(t)), 900) * np.exp(-t * 40) * 0.6
        return (body + slap) * 0.9
    if kind == "frame":
        pitch = 120 + 50 * np.exp(-t * 30)
        body = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 9)
        skin = bandpass(rng.normal(0, 1, len(t)), 300, 3000) * np.exp(-t * 35) * 0.3
        return (body + skin) * 0.6
    if kind == "tak":
        return bandpass(rng.normal(0, 1, len(t)), 900, 5000) * np.exp(-t * 55) * 0.5
    if kind == "shaker":
        return bandpass(rng.normal(0, 1, len(t)), 5000, 11000) * np.exp(-t * 40) * 0.18
    raise ValueError(kind)


# --- mixing ------------------------------------------------------------------------

class Track:
    """Beat-addressed stereo buffer. Notes may ring past the loop point; the tail
    wraps to the start so the rendered loop is seamless."""

    def __init__(self, bpm: float, bars: int, beats_per_bar: int = 4):
        self.beat = 60.0 / bpm
        self.length = int(bars * beats_per_bar * self.beat * RATE)
        self.buffer = np.zeros((self.length + RATE * 4, 2))

    def add(self, sound: np.ndarray, beat: float, gain: float = 1.0, pan: float = 0.0) -> None:
        start = int(beat * self.beat * RATE)
        end = min(start + len(sound), len(self.buffer))
        left = gain * np.sqrt((1 - pan) / 2)
        right = gain * np.sqrt((1 + pan) / 2)
        self.buffer[start:end, 0] += sound[: end - start] * left
        self.buffer[start:end, 1] += sound[: end - start] * right

    def render(self, reverb: float = 0.25, room: float = 1.8, loop: bool = True) -> np.ndarray:
        wet = self.buffer.copy()
        for channel in range(2):
            ir_t = t_axis(room)
            ir = rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t * 3.2 / room)
            ir = lowpass(ir, 5000)
            ir /= np.sqrt(np.sum(ir ** 2))
            size = len(wet) + len(ir)
            wet[:, channel] = np.fft.irfft(np.fft.rfft(self.buffer[:, channel], size) * np.fft.rfft(ir, size), size)[: len(wet)]
        mix = self.buffer + wet * reverb
        if loop:
            body = mix[: self.length].copy()
            tail = mix[self.length:]
            body[: len(tail)] += tail[: self.length]
        else:
            loud = np.nonzero(np.max(np.abs(mix), axis=1) > 1e-4)[0]
            body = mix[: loud[-1] + 1].copy()
            fade = int(0.3 * RATE)
            body[-fade:] *= np.linspace(1, 0, fade)[:, None]
        peak = np.max(np.abs(body))
        return np.tanh(body / peak * 1.2) * 0.82


def write_music(name: str, audio: np.ndarray) -> None:
    path = ROOT / "music" / f"{name}.ogg"
    path.parent.mkdir(parents=True, exist_ok=True)
    # libsndfile's Vorbis encoder can crash on one huge write; feed it in blocks.
    with sf.SoundFile(path, "w", RATE, audio.shape[1], format="OGG", subtype="VORBIS", compression_level=0.55) as file:
        data = np.ascontiguousarray(audio, dtype=np.float32)
        for start in range(0, len(data), 4096):
            file.write(data[start:start + 4096])
    print(f"music/{name}.ogg  {len(audio) / RATE:5.1f}s  {path.stat().st_size // 1024} KB")


def write_sfx(name: str, audio: np.ndarray) -> None:
    path = ROOT / "sfx" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    audio = audio / (np.max(np.abs(audio)) + 1e-9) * 0.85
    fade = min(len(audio), int(0.01 * SFX_RATE))
    audio[-fade:] *= np.linspace(1, 0, fade)
    sf.write(path, audio.astype(np.float32), SFX_RATE, subtype="PCM_16")
    print(f"sfx/{name}.wav  {len(audio) / SFX_RATE:4.2f}s")


def chord_notes(root: str, quality: str, octave: int) -> list:
    base = NOTE_INDEX[root]
    steps = {"m": [0, 3, 7], "M": [0, 4, 7], "sus": [0, 5, 7], "5": [0, 7, 12]}[quality]
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    notes = []
    for step in steps:
        semitone = base + step
        notes.append(f"{names[semitone % 12]}{octave + semitone // 12}")
    return notes


# --- compositions ------------------------------------------------------------------

def menu_theme() -> np.ndarray:
    """Slow D dorian lament: lute arpeggios, low drone, a lone flute."""
    track = Track(bpm=72, bars=16)
    progression = [("D", "m"), ("C", "M"), ("A#", "M"), ("C", "M"), ("D", "m"), ("F", "M"), ("C", "M"), ("D", "m")] * 2
    for bar, (root, quality) in enumerate(progression):
        beat = bar * 4
        track.add(pad([hz(n) for n in chord_notes(root, quality, 3)], 4 * track.beat + 0.8), beat, 0.55)
        arpeggio = chord_notes(root, quality, 3) + chord_notes(root, quality, 4)[:2]
        for step, note in enumerate([arpeggio[i] for i in (0, 1, 2, 3, 4, 3, 2, 1)]):
            track.add(pluck(hz(note), 2.2, 0.8), beat + step * 0.5, 0.42, pan=-0.35 + 0.1 * (step % 3))
        track.add(pluck(hz(chord_notes(root, quality, 2)[0]), 3.5, 0.5), beat, 0.5, pan=0.1)
    melody = [("A4", 0, 2), ("G4", 2, 1), ("F4", 3, 1), ("E4", 4, 3), ("D4", 7, 1),
              ("F4", 8, 2), ("G4", 10, 1), ("A4", 11, 1), ("C5", 12, 3), ("A4", 15, 1),
              ("D5", 16, 2), ("C5", 18, 1), ("A4", 19, 1), ("A#4", 20, 2), ("A4", 22, 2),
              ("G4", 24, 1.5), ("F4", 25.5, 0.5), ("E4", 26, 2), ("D4", 28, 4)]
    for offset in (32,):
        for note, start, length in melody:
            track.add(flute(hz(note), length * track.beat + 0.1), offset + start, 0.5, pan=0.25)
    for note, start, length in melody[:10]:
        track.add(flute(hz(note) / 2, length * track.beat + 0.1), start + 8, 0.25, pan=0.3)
    return track.render(reverb=0.42, room=2.6)


def map_theme() -> np.ndarray:
    """Travelling music in A aeolian: strummed lute, frame drum, recorder tune."""
    track = Track(bpm=100, bars=16)
    progression = [("A", "m"), ("G", "M"), ("F", "M"), ("E", "m"), ("A", "m"), ("C", "M"), ("G", "M"), ("A", "m")] * 2
    strum = [0, 1.5, 2, 3, 3.5]
    for bar, (root, quality) in enumerate(progression):
        beat = bar * 4
        notes = chord_notes(root, quality, 3)
        for hit in strum:
            for index, note in enumerate(notes):
                track.add(pluck(hz(note), 1.4, 1.0), beat + hit + index * 0.02, 0.28, pan=-0.3)
        track.add(pluck(hz(chord_notes(root, quality, 2)[0]), 1.8, 0.4), beat, 0.55)
        track.add(pluck(hz(chord_notes(root, quality, 2)[0]), 1.8, 0.4), beat + 2, 0.4)
        for hit, kind, gain in [(0, "frame", 0.7), (1, "tak", 0.4), (1.5, "frame", 0.4), (2, "frame", 0.6), (3, "tak", 0.45), (3.5, "tak", 0.25)]:
            track.add(drum(kind, 0.5), beat + hit, gain, pan=0.2)
        for eighth in range(8):
            track.add(drum("shaker", 0.15), beat + eighth * 0.5, 0.5 if eighth % 2 else 0.3, pan=0.5)
    tune = [("E5", 0, 1), ("A5", 1, 1), ("G5", 2, 0.5), ("F5", 2.5, 0.5), ("E5", 3, 1),
            ("D5", 4, 1.5), ("E5", 5.5, 0.5), ("C5", 6, 2), ("A4", 8, 1), ("C5", 9, 1),
            ("D5", 10, 1), ("E5", 11, 1), ("B4", 12, 2), ("G4", 14, 2),
            ("A4", 16, 1), ("C5", 17, 1), ("E5", 18, 1.5), ("D5", 19.5, 0.5), ("C5", 20, 2),
            ("G5", 22, 1), ("E5", 23, 1), ("F5", 24, 1.5), ("E5", 25.5, 0.5), ("D5", 26, 1),
            ("B4", 27, 1), ("A4", 28, 4)]
    for offset in (32,):
        for note, start, length in tune:
            track.add(flute(hz(note), length * track.beat + 0.05), offset + start, 0.45, pan=0.2)
    return track.render(reverb=0.3, room=1.6)


def battle_theme(boss: bool = False) -> np.ndarray:
    """Driving D minor (boss: C minor, heavier) with string ostinato, taiko and brass."""
    bpm = 140 if boss else 132
    track = Track(bpm=bpm, bars=16)
    tonic = "C" if boss else "D"
    shift = -2 if boss else 0
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    def transpose(name: str) -> str:
        pitch, octave = name[:-1], int(name[-1])
        semitone = NOTE_INDEX[pitch] + shift
        return f"{names[semitone % 12]}{octave + (semitone // 12)}"

    progression = [("D", "m"), ("D", "m"), ("A#", "M"), ("C", "M"), ("D", "m"), ("D#", "M"), ("C", "M"), ("A", "5")] * 2
    ostinato = [0, 0, 12, 0, 0, 10, 0, 7, 0, 0, 12, 0, 13 if boss else 10, 12, 10, 7]
    for bar, (root, quality) in enumerate(progression):
        beat = bar * 4
        root_note = transpose(chord_notes(root, quality, 2)[0])
        base = hz(root_note)
        for step, interval in enumerate(ostinato):
            track.add(strings(base * 2 ** (interval / 12), track.beat * 0.3, 2.0), beat + step * 0.25, 0.5, pan=-0.25)
        stab = [hz(transpose(n)) for n in chord_notes(root, quality, 3)]
        if bar % 2 == 0:
            for freq in stab:
                track.add(brass(freq, track.beat * 1.6), beat, 0.4, pan=0.3)
        if boss:
            track.add(choir(hz(transpose(chord_notes(root, quality, 3)[0])), track.beat * 4.2), beat, 0.55)
            track.add(choir(hz(transpose(chord_notes(root, quality, 3)[2])), track.beat * 4.2), beat, 0.4)
        pattern = [(0, "taiko", 1.0), (1.5, "taiko", 0.6), (2, "taiko", 0.9), (3, "tak", 0.5), (3.5, "taiko", 0.5)]
        if boss or bar % 4 == 3:
            pattern += [(2.75, "taiko", 0.45), (3.25, "tak", 0.35)]
        for hit, kind, gain in pattern:
            track.add(drum(kind, 0.8), beat + hit, gain * (1.15 if boss else 1.0))
        for eighth in range(8):
            track.add(drum("shaker", 0.12), beat + eighth * 0.5, 0.35, pan=0.45)
    lead = [("A4", 0, 1.5), ("D5", 1.5, 0.5), ("C5", 2, 1), ("A4", 3, 1), ("A#4", 4, 2), ("A4", 6, 1), ("G4", 7, 1),
            ("F4", 8, 1.5), ("G4", 9.5, 0.5), ("A4", 10, 2), ("D5", 12, 1), ("E5", 13, 1), ("F5", 14, 1), ("E5", 15, 1),
            ("D5", 16, 3), ("C5", 19, 1), ("A#4", 20, 2), ("C5", 22, 2), ("A4", 24, 2), ("G4", 26, 1), ("A4", 27, 1), ("D5", 28, 4)]
    for note, start, length in lead:
        track.add(strings(hz(transpose(note)) * 2, length * track.beat, 0.6), 32 + start, 0.6, pan=0.15)
        track.add(brass(hz(transpose(note)), length * track.beat), 32 + start, 0.25, pan=-0.1)
    return track.render(reverb=0.22, room=1.4)


def jingle(victory: bool) -> np.ndarray:
    track = Track(bpm=100, bars=2)
    if victory:
        for step, note in enumerate(["D4", "F#4", "A4", "D5"]):
            track.add(brass(hz(note), 0.5 if step < 3 else 1.8), step * 0.5, 0.6)
        for note in ["D4", "F#4", "A4", "D5"]:
            track.add(pluck(hz(note), 2.5), 2, 0.4)
        track.add(drum("taiko", 0.8), 0, 0.7)
        track.add(drum("taiko", 0.8), 2, 0.9)
    else:
        for step, note in enumerate(["A3", "G3", "F3", "D3"]):
            track.add(strings(hz(note), 0.9 if step < 3 else 2.2, 0.5), step * 1.0, 0.7)
        track.add(choir(hz("D3"), 3.0), 1, 0.6)
        track.add(drum("taiko", 0.9), 3, 0.8)
    return track.render(reverb=0.35, room=2.0, loop=False)


# --- sound effects ------------------------------------------------------------------

def sfx() -> dict:
    t = lambda d: t_axis(d, SFX_RATE)
    noise = lambda n: rng.normal(0, 1, n)
    sounds = {}
    d = t(0.06)
    sounds["ui_click"] = np.sin(2 * np.pi * 1800 * d) * np.exp(-d * 90) + bandpass(noise(len(d)), 2000, 6000) * np.exp(-d * 120) * 0.3
    rattle = np.zeros(len(t(0.55)))
    moment = 0.0
    for hit in range(7):
        start = int(moment * SFX_RATE)
        c = t(0.04)
        click = (np.sin(2 * np.pi * rng.uniform(2200, 3400) * c) + bandpass(noise(len(c)), 1500, 7000) * 0.6) * np.exp(-c * 110)
        rattle[start:start + len(c)] += click[: len(rattle) - start] * (1 - hit * 0.08)
        moment += 0.03 + hit * 0.012
    sounds["dice"] = rattle
    d = t(0.28)
    chunks = np.array_split(noise(len(d)), 4)
    sweep = np.concatenate([bandpass(chunk, 800 + i * 900, 3000 + i * 1500) for i, chunk in enumerate(chunks)])
    sounds["slash"] = sweep * np.sin(np.pi * np.clip(d / 0.28, 0, 1)) ** 2
    d = t(0.35)
    thump = np.sin(2 * np.pi * np.cumsum(90 + 120 * np.exp(-d * 30)) / SFX_RATE) * np.exp(-d * 12)
    sounds["hit"] = thump + bandpass(noise(len(d)), 400, 4000) * np.exp(-d * 45) * 0.7
    d = t(0.8)
    ring = sum(np.sin(2 * np.pi * f * d) * np.exp(-d * k) for f, k in [(1320, 4), (1870, 5), (2640, 7), (3310, 9)]) * 0.35
    sounds["crit"] = np.concatenate([sounds["hit"], np.zeros(len(d) - len(sounds["hit"]))]) * 1.2 + ring
    d = t(0.32)
    sounds["miss"] = bandpass(noise(len(d)), 500, 2500) * np.sin(np.pi * d / 0.32) ** 3
    d = t(0.9)
    sounds["shield"] = sum(np.sin(2 * np.pi * f * d) * np.exp(-d * 3.5) * np.clip((d - delay) * 60, 0, 1)
                           for f, delay in [(880, 0), (1108, 0.06), (1318, 0.12), (1760, 0.18)]) * 0.4 + bandpass(noise(len(d)), 5000, 12000) * np.exp(-d * 6) * 0.08
    d = t(0.65)
    roar = bandpass(noise(len(d)), 200, 1800) * np.sin(np.pi * np.clip(d / 0.5, 0, 1)) ** 1.5
    crackle = np.zeros(len(d))
    for _ in range(40):
        spot = rng.integers(0, len(d) - 200)
        crackle[spot:spot + 200] += bandpass(noise(200), 2000, 8000) * np.exp(-np.arange(200) / 30) * rng.uniform(0.3, 1)
    sounds["fire"] = roar + crackle * 0.4
    d = t(0.5)
    zap = sum(np.sin(2 * np.pi * np.cumsum(f + 900 * d) / SFX_RATE) * np.exp(-((d - s) * 18) ** 2) for f, s in [(700, 0.08), (950, 0.18), (1250, 0.28)])
    sounds["arcane"] = zap * 0.6 + bandpass(noise(len(d)), 6000, 12000) * np.exp(-d * 8) * 0.12
    d = t(0.45)
    twang = np.sin(2 * np.pi * 180 * d) * np.exp(-d * 18) + np.sin(2 * np.pi * 360 * d) * np.exp(-d * 25) * 0.5
    sounds["arrow"] = twang + bandpass(noise(len(d)), 1500, 5000) * np.exp(-((d - 0.2) * 12) ** 2) * 0.5
    d = t(1.0)
    sounds["radiant"] = sum(np.sin(2 * np.pi * f * d) * np.exp(-d * 2.2) for f in (523, 659, 784, 1046)) * 0.3 + bandpass(noise(len(d)), 4000, 10000) * np.exp(-d * 4) * 0.1
    d = t(1.0)
    fall = np.sin(2 * np.pi * np.cumsum(220 * np.exp(-d * 1.5)) / SFX_RATE) * np.exp(-d * 3) * 0.5
    sounds["death"] = fall + np.concatenate([sounds["hit"] * 0.8, np.zeros(len(d) - len(sounds["hit"]))])
    d = t(0.45)
    sounds["coin"] = sum(np.sin(2 * np.pi * f * d) * np.exp(-d * 9) * np.clip((d - s) * 200, 0, 1) for f, s in [(1976, 0), (2637, 0.09)]) * 0.5
    d = t(1.1)
    sounds["heal"] = sum(np.sin(2 * np.pi * f * d) * np.exp(-(d - s) * 4) * np.clip((d - s) * 80, 0, 1)
                         for f, s in [(523, 0), (659, 0.1), (784, 0.2), (1046, 0.3)]) * 0.35
    d = t(0.28)
    sounds["step"] = np.sin(2 * np.pi * np.cumsum(90 + 40 * np.exp(-d * 30)) / SFX_RATE) * np.exp(-d * 20) * 0.6 + bandpass(noise(len(d)), 1500, 6000) * np.exp(-d * 30) * 0.4
    d = t(0.5)
    sounds["turn"] = (np.sin(2 * np.pi * 587 * d) + 0.4 * np.sin(2 * np.pi * 880 * d)) * np.exp(-d * 6) * np.clip(d * 150, 0, 1) * 0.5
    return sounds


def main() -> None:
    write_music("menu", menu_theme())
    write_music("map", map_theme())
    write_music("battle", battle_theme())
    write_music("boss", battle_theme(boss=True))
    write_music("victory", jingle(True))
    write_music("defeat", jingle(False))
    for name, sound in sfx().items():
        write_sfx(name, sound)


if __name__ == "__main__":
    main()
