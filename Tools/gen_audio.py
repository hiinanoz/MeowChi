#!/usr/bin/env python3
"""Synthesizes Meowchi's background music and sound effects (original, royalty-free).

Music: calm 16-bit style loop in the D "Yo" pentatonic scale (D E G A B), koto-like plucks
(Karplus-Strong), soft pads, bass, wood-tick percussion and a little echo. 32 kHz mono, like SNES audio.
Pure standard library; converts with macOS `afconvert`. Run: python3 Tools/gen_audio.py
"""
import array, math, pathlib, random, struct, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Meowchi/Resources/Audio"
SR = 32000
BPM = 72
BEAT = 60 / BPM
rnd = random.Random(2026)


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


NOTE = {"D3": 50, "E3": 52, "G3": 55, "A3": 57, "B3": 59, "D4": 62, "E4": 64, "G4": 67, "A4": 69, "B4": 71,
        "D5": 74, "E5": 76, "G5": 79, "A5": 81, "D2": 38, "E2": 40, "G2": 43, "A2": 45}


def buffer(seconds):
    return array.array("f", bytes(4 * int(seconds * SR)))


def mix(dst, src, start, gain=1.0):
    i0 = int(start * SR)
    for i, v in enumerate(src):
        j = i0 + i
        if j >= len(dst):
            break
        dst[j] += v * gain


def pluck(freq, seconds, decay=0.996, bright=0.5):
    """Karplus-Strong string: noise burst through an averaging delay line (koto/shamisen-like)."""
    n = max(2, int(SR / freq))
    line = [rnd.uniform(-1, 1) for _ in range(n)]
    out = array.array("f", bytes(4 * int(seconds * SR)))
    prev = 0.0
    for i in range(len(out)):
        k = i % n
        v = line[k]
        nxt = line[(k + 1) % n]
        line[k] = decay * (bright * v + (1 - bright) * nxt)
        out[i] = v * 0.5 + prev * 0.5
        prev = v
    return out


def tone(freq, seconds, wave="sine", attack=0.01, release=0.1, vibrato=0.0, duty=0.5):
    out = array.array("f", bytes(4 * int(seconds * SR)))
    phase = 0.0
    for i in range(len(out)):
        t = i / SR
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5 * t) * min(1, t / 0.3))
        phase = (phase + f / SR) % 1
        if wave == "sine":
            v = math.sin(2 * math.pi * phase) + 0.25 * math.sin(4 * math.pi * phase)
        elif wave == "triangle":
            v = 4 * abs(phase - 0.5) - 1
        elif wave == "saw":
            v = 2 * phase - 1
        else:  # square with duty
            v = 1.0 if phase < duty else -1.0
        env = min(1, t / attack) * min(1, max(0, seconds - t) / release)
        out[i] = v * env
    return out


def lowpass(buf, amount):
    y = 0.0
    for i, v in enumerate(buf):
        y += amount * (v - y)
        buf[i] = y
    return buf


def noise_burst(seconds, decay, tone_hz=None):
    out = array.array("f", bytes(4 * int(seconds * SR)))
    for i in range(len(out)):
        t = i / SR
        v = rnd.uniform(-1, 1) if tone_hz is None else math.sin(2 * math.pi * tone_hz * t)
        out[i] = v * math.exp(-t * decay)
    return out


# ---------- Music ----------

MELODY_A = [  # (beat, length, note) for bars 1-8
    (0, 1, "A4"), (1, .5, "B4"), (1.5, .5, "A4"), (2, 1, "G4"), (3, 1, "E4"),
    (4, 2, "D4"), (6, 1, "E4"), (7, 1, "G4"),
    (8, 1, "A4"), (9, 1, "D5"), (10, 1, "B4"), (11, .5, "A4"), (11.5, .5, "G4"),
    (12, 3, "A4"),
    (16, 1, "B4"), (17, .5, "D5"), (17.5, .5, "E5"), (18, 1, "D5"), (19, 1, "B4"),
    (20, 1.5, "A4"), (21.5, .5, "G4"), (22, 2, "E4"),
    (24, 1, "G4"), (25, 1, "A4"), (26, .5, "B4"), (26.5, .5, "A4"), (27, 1, "G4"),
    (28, 1, "E4"), (29, 3, "D4"),
]
MELODY_B = [  # bars 9-16, played on the flute
    (0, 1.5, "D5"), (1.5, .5, "E5"), (2, 1, "G5"), (3, 1, "E5"),
    (4, 2, "D5"), (6, 2, "B4"),
    (8, 1, "A4"), (9, 1, "B4"), (10, 1, "D5"), (11, 1, "E5"),
    (12, 3, "G5"),
    (16, 1, "E5"), (17, 1, "D5"), (18, 1, "B4"), (19, 1, "A4"),
    (20, 1.5, "B4"), (21.5, .5, "A4"), (22, 2, "G4"),
    (24, 1, "A4"), (25, .5, "G4"), (25.5, .5, "E4"), (26, 1, "D4"), (27, 1, "E4"),
    (28, 4, "D4"),
]
CHORDS_A = [("D2", ["D3", "A3", "E4"]), ("G2", ["G3", "B3", "E4"]), ("E2", ["E3", "B3", "G4"]), ("A2", ["A3", "B3", "E4"])]
CHORDS_B = [("G2", ["G3", "B3", "E4"]), ("D2", ["D3", "A3", "E4"]), ("E2", ["E3", "B3", "G4"]), ("A2", ["A3", "D4", "E4"])]


def music():
    bars = 16
    loop_seconds = bars * 4 * BEAT
    tail = 3.0
    out = buffer(loop_seconds + tail)
    sec = lambda beats: beats * BEAT
    # Melody: koto in A, flute + quiet koto echo in B
    for beat, length, note in MELODY_A:
        mix(out, pluck(midi(NOTE[note]), sec(length) + 1.2), sec(beat), 0.32)
    for beat, length, note in MELODY_B:
        flute = lowpass(tone(midi(NOTE[note]), sec(length), "square", attack=0.06, release=0.15, vibrato=0.006, duty=0.25), 0.25)
        mix(out, flute, sec(32 + beat), 0.07)
        mix(out, pluck(midi(NOTE[note]) * 2, sec(length) + 0.8, decay=0.99), sec(32 + beat + 0.5), 0.07)
    # Pads, bass and arpeggios: one chord per 2 bars
    for half, chords in ((0, CHORDS_A), (32, CHORDS_B)):
        for i, (root, tones) in enumerate(chords):
            start = half + i * 8
            for name in tones:
                mix(out, tone(midi(NOTE[name]), sec(8), "sine", attack=0.8, release=1.2), sec(start), 0.045)
            for b in range(0, 8, 2):
                mix(out, lowpass(tone(midi(NOTE[root]), sec(1.8), "triangle", attack=0.02, release=0.4), 0.3), sec(start + b), 0.16)
            if half == 32:  # gentle arpeggio under the flute
                for k in range(16):
                    note = tones[k % 3]
                    mix(out, pluck(midi(NOTE[note]) * 2, 0.9, decay=0.985), sec(start + k * 0.5), 0.05)
    # Percussion: soft wood ticks on 2 and 4, very quiet shaker on eighths
    for b in range(bars * 4):
        if b % 2 == 1:
            mix(out, noise_burst(0.08, 70, tone_hz=1750), sec(b), 0.05)
        for half_beat in (0, 0.5):
            mix(out, lowpass(noise_burst(0.04, 120), 0.6), sec(b + half_beat), 0.012)
    # Echo (two feedback delays) for a soft, roomy sound
    for delay, fb in ((0.31, 0.32), (0.47, 0.22)):
        d = int(delay * SR)
        for i in range(d, len(out)):
            out[i] += out[i - d] * fb
    # Seamless loop: fold the tail back onto the start
    n = int(loop_seconds * SR)
    looped = out[:n]
    for i in range(len(out) - n):
        looped[i] += out[n + i]
    return looped


# ---------- More tracks ----------

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name):
    """'F#5' -> MIDI number."""
    pitch = NAMES[name[0]] + (1 if "#" in name else -1 if name[1:2] == "b" else 0)
    return 12 * (int(name.lstrip("ABCDEFG#b")) + 1) + pitch


def parse(melody):
    """'A4:1 B4:.5 r:1 | ...' -> [(beat, length, midi)]; bars are only visual."""
    out, beat = [], 0.0
    for token in melody.replace("|", " ").split():
        name, length = token.split(":")
        if name != "r":
            out.append((beat, float(length), note(name)))
        beat += float(length)
    return out


def kick():
    out = buffer(0.18)
    phase = 0.0
    for i in range(len(out)):
        t = i / SR
        phase += (45 + 105 * math.exp(-t * 30)) / SR
        out[i] = math.sin(2 * math.pi * phase) * math.exp(-t * 18)
    return out


def snare(raw=False):
    body = noise_burst(0.18, 22)
    if not raw:
        mix(body, noise_burst(0.1, 40, tone_hz=190), 0, 0.6)
    return body


def hat(raw=False):
    n = noise_burst(0.04, 110)
    if raw:
        return n
    smooth = lowpass(array.array("f", n), 0.3)
    return array.array("f", (a - b for a, b in zip(n, smooth)))


def echo(out, taps):
    for delay, fb in taps:
        d = int(delay * SR)
        for i in range(d, len(out)):
            out[i] += out[i - d] * fb


def finish_loop(out, loop_seconds):
    n = int(loop_seconds * SR)
    looped = out[:n]
    for i in range(len(out) - n):
        looped[i] += out[n + i]
    return looped


def track(bpm, melody, chords, lead, chord_voice, bass_voice, drums, echo_taps, tail=2.0):
    """Generic 16-bar renderer. `chords` = one (bass midi, [tones]) per bar, repeated to 16 bars."""
    beat = 60 / bpm
    bars = 16
    loop_seconds = bars * 4 * beat
    out = buffer(loop_seconds + tail)
    for b, length, n in parse(melody):
        lead(out, b * beat, length * beat, n)
    for bar in range(bars):
        root, tones = chords[bar % len(chords)]
        chord_voice(out, bar * 4 * beat, beat, tones)
        bass_voice(out, bar * 4 * beat, beat, root)
        drums(out, bar * 4 * beat, beat, bar)
    echo(out, echo_taps)
    return finish_loop(out, loop_seconds)


def music_upbeat():
    """Energetic: 120 BPM, D major pentatonic, bright plucks over a bouncy groove."""
    melody = ("F#5:.5 A5:.5 B5:.5 A5:.5 F#5:1 E5:1 | D5:.5 E5:.5 F#5:1 A5:1 r:1 | B5:.5 A5:.5 F#5:.5 E5:.5 D5:1 E5:1 | "
              "F#5:3 r:1 | A5:.5 B5:.5 D6:1 B5:.5 A5:.5 F#5:1 | E5:.5 F#5:.5 A5:1 F#5:1 E5:1 | "
              "D5:.5 E5:.5 F#5:.5 A5:.5 B5:1 A5:1 | D5:3 r:1 | "
              "D5:1 F#5:1 A5:1 F#5:1 | E5:1.5 D5:.5 B4:2 | D5:1 E5:1 F#5:1 A5:1 | B5:4 | "
              "A5:1 F#5:1 E5:1 D5:1 | E5:1.5 F#5:.5 A5:2 | B5:.5 A5:.5 F#5:.5 E5:.5 D5:1 E5:1 | D5:4")
    chords = [(38, [62, 66, 69]), (35, [59, 62, 66]), (43, [55, 59, 62]), (45, [57, 61, 64])]

    def lead(out, t, d, n):
        mix(out, pluck(midi(n), d + 0.6, decay=0.993, bright=0.7), t, 0.28)
        mix(out, lowpass(tone(midi(n), d * 0.9, "square", attack=0.005, release=0.05, duty=0.25), 0.35), t, 0.05)

    def stabs(out, t, beat, tones):
        for k in (0.5, 1.5, 2.5, 3.5):
            for n in tones:
                mix(out, lowpass(tone(midi(n), beat * 0.3, "square", attack=0.003, release=0.05), 0.25), t + k * beat, 0.035)

    def bass(out, t, beat, root):
        for k in range(8):
            n = root + (12 if k % 2 else 0)
            mix(out, lowpass(tone(midi(n), beat * 0.45, "triangle", attack=0.003, release=0.05), 0.5), t + k * beat / 2, 0.2)

    def drums(out, t, beat, bar):
        for k in (0, 2, 2.5 if bar % 2 else 2):
            mix(out, kick(), t + k * beat, 0.5)
        for k in (1, 3):
            mix(out, snare(), t + k * beat, 0.18)
        for k in range(8):
            mix(out, hat(), t + k * beat / 2, 0.07 if k % 2 else 0.04)

    return track(120, melody, chords, lead, stabs, bass, drums, [(0.25, 0.22)])


def music_retro8():
    """8-bit: NES-style pulse lead, pulse arpeggios, triangle bass, raw noise drums. 140 BPM, C major."""
    melody = ("E5:.5 G5:.5 C6:.5 G5:.5 E5:.5 G5:.5 C6:1 | A5:.5 C6:.5 E6:.5 C6:.5 A5:1 G5:1 | "
              "F5:.5 A5:.5 C6:.5 A5:.5 F5:.5 A5:.5 C6:1 | B5:.5 G5:.5 D5:.5 G5:.5 B5:2 | "
              "C6:1 B5:.5 A5:.5 G5:1 E5:1 | A5:1 G5:.5 F5:.5 E5:1 C5:1 | D5:.5 E5:.5 F5:.5 G5:.5 A5:.5 B5:.5 C6:1 | "
              "C6:2 G5:1 r:1 | G5:1 E5:1 C5:1 E5:1 | A5:1.5 G5:.5 E5:2 | F5:1 A5:1 C6:1 A5:1 | G5:1.5 F5:.5 D5:2 | "
              "E5:.5 F5:.5 G5:1 C6:1 G5:1 | A5:.5 G5:.5 F5:1 E5:1 D5:1 | C5:.5 D5:.5 E5:.5 F5:.5 G5:1 B5:1 | C6:3 r:1")
    chords = [(48, [60, 64, 67]), (45, [57, 60, 64]), (41, [53, 57, 60]), (43, [55, 59, 62])]

    def lead(out, t, d, n):
        mix(out, tone(midi(n), d * 0.92, "square", attack=0.002, release=0.02, duty=0.125), t, 0.11)

    def arps(out, t, beat, tones):
        for k in range(16):
            mix(out, tone(midi(tones[k % 3] + 12), beat * 0.22, "square", attack=0.002, release=0.01, duty=0.25), t + k * beat / 4, 0.035)

    def bass(out, t, beat, root):
        for k in range(8):
            mix(out, tone(midi(root - 12 + (12 if k % 2 else 0)), beat * 0.45, "triangle", attack=0.002, release=0.02), t + k * beat / 2, 0.3)

    def drums(out, t, beat, bar):
        for k in (0, 2):
            mix(out, noise_burst(0.06, 60), t + k * beat, 0.25)
        for k in (1, 3):
            mix(out, snare(raw=True), t + k * beat, 0.16)
        for k in range(8):
            mix(out, hat(raw=True), t + k * beat / 2, 0.04)

    return track(140, melody, chords, lead, arps, bass, drums, [], tail=0.5)


def music_retro16():
    """16-bit: SNES-style vibrato lead, string pad, plucked arps, echo. 100 BPM, A minor pentatonic."""
    melody = ("E5:1 D5:.5 C5:.5 D5:1 E5:1 | A5:2 G5:1 E5:1 | C5:1 D5:1 E5:1 G5:1 | D5:3 r:1 | "
              "E5:1 G5:.5 A5:.5 G5:1 E5:1 | C6:1.5 A5:.5 G5:2 | E5:.5 D5:.5 C5:1 D5:1 G4:1 | A4:3 r:1 | "
              "A5:1 C6:1 D6:1 C6:1 | A5:2 G5:2 | F5:1 A5:1 C6:1 A5:1 | G5:3 r:1 | "
              "E5:1 G5:1 A5:1 C6:1 | D6:1.5 C6:.5 A5:2 | G5:.5 A5:.5 G5:.5 E5:.5 D5:1 C5:1 | A4:4")
    chords = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]

    def lead(out, t, d, n):
        mix(out, lowpass(tone(midi(n), d, "square", attack=0.02, release=0.12, vibrato=0.008), 0.2), t, 0.09)

    def strings(out, t, beat, tones):
        for n in tones:
            for detune in (0.997, 1.003):
                mix(out, lowpass(tone(midi(n) * detune, beat * 4, "saw", attack=0.4, release=0.6), 0.08), t, 0.03)
        for k in range(8):
            mix(out, pluck(midi(tones[k % 3] + 12), 0.6, decay=0.985), t + k * beat / 2, 0.06)

    def bass(out, t, beat, root):
        for k in (0, 1.5, 2, 3):
            mix(out, lowpass(tone(midi(root - 12), beat * 0.8, "triangle", attack=0.005, release=0.1), 0.4), t + k * beat, 0.22)

    def drums(out, t, beat, bar):
        for k in (0, 2.5):
            mix(out, kick(), t + k * beat, 0.35)
        for k in (1, 3):
            mix(out, snare(), t + k * beat, 0.12)
        for k in range(4):
            mix(out, hat(), t + k * beat + beat / 2, 0.035)

    return track(100, melody, chords, lead, strings, bass, drums, [(0.3, 0.3), (0.45, 0.18)])


# ---------- Sound effects ----------

def sfx():
    def sweep(f0, f1, seconds, wave="sine"):
        out = buffer(seconds)
        phase = 0.0
        for i in range(len(out)):
            t = i / len(out)
            f = f0 * (f1 / f0) ** t
            phase = (phase + f / SR) % 1
            v = math.sin(2 * math.pi * phase) if wave == "sine" else (1 if phase < .5 else -1)
            out[i] = v * math.sin(math.pi * t)
        return out

    def seq(notes, step, wave="square", length=0.12):
        total = buffer(step * len(notes) + length)
        for i, n in enumerate(notes):
            mix(total, tone(midi(n), length, wave, attack=0.005, release=0.06, duty=0.25), i * step, 0.5)
        return total

    def meow():
        out = buffer(0.5)
        phase = 0.0
        for i in range(len(out)):
            t = i / len(out)
            f = 520 + 380 * math.sin(math.pi * min(1, t * 1.4)) - 120 * t
            phase = (phase + f / SR) % 1
            v = math.sin(2 * math.pi * phase) + 0.5 * math.sin(4 * math.pi * phase) + 0.25 * math.sin(6 * math.pi * phase)
            out[i] = v * math.sin(math.pi * t) ** 0.7 * 0.5
        return lowpass(out, 0.35)

    def purr():
        out = buffer(0.9)
        for i in range(len(out)):
            t = i / SR
            out[i] = rnd.uniform(-1, 1) * (0.5 + 0.5 * math.sin(2 * math.pi * 24 * t)) * math.sin(math.pi * i / len(out))
        return lowpass(lowpass(out, 0.05), 0.08)

    def crunch():
        out = buffer(0.45)
        for k in range(3):
            mix(out, lowpass(noise_burst(0.07, 60), 0.5), k * 0.13, 0.8)
        return out

    return {
        "sfx_tap": seq([84], 0.05, length=0.05),
        "sfx_meow": meow(),
        "sfx_purr": purr(),
        "sfx_eat": crunch(),
        "sfx_coin": seq([83, 88], 0.07),
        "sfx_buy": seq([84, 88, 91], 0.06),
        "sfx_levelup": seq([74, 78, 81, 86], 0.09, length=0.2),
        "sfx_splash": lowpass(noise_burst(0.6, 6), 0.3),
        "sfx_catch": sweep(1200, 400, 0.08),
        "sfx_find": seq([86, 91, 95], 0.05, wave="triangle", length=0.15),
    }


# ---------- Output ----------

def write(name, samples, codec):
    peak = max(1e-6, max(abs(v) for v in samples))
    scale = 0.89 / peak  # about -1 dBFS
    pcm = array.array("h", (int(max(-1, min(1, v * scale)) * 32767) for v in samples))
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / f"{name}.wav"
        data = pcm.tobytes()
        wav.write_bytes(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt " +
                        struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16) + b"data" + struct.pack("<I", len(data)) + data)
        # ALAC for the music: lossless, so the loop point stays gapless. Plain 16-bit PCM for short effects.
        subprocess.run(["afconvert", "-f", "caff", "-d", codec, str(wav), str(OUT / f"{name}.caf")], check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write("music_calm", music(), "alac")
    write("music_upbeat", music_upbeat(), "alac")
    write("music_retro8", music_retro8(), "alac")
    write("music_retro16", music_retro16(), "alac")
    for name, samples in sfx().items():
        write(name, samples, "LEI16")


if __name__ == "__main__":
    main()
