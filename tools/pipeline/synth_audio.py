"""Synthesize placeholder meow + backing audio so the game runs end to end.

  assets/audio/meows/meow_{low,mid,high}.wav — 300ms blips with
      vibrato + decay envelope at the SAMPLE_ROOTS pitches (A2/D4/G4-ish),
      distinguishable per sample so lanes feel different. Placeholders until
      real recordings are measured (pipeline §7, PRD §9).
  assets/audio/songs/summer.ogg — the real accompaniment render, delegated to
      `render_backing.py` (additive piano synth from the backing MIDI).

Run: python tools/pipeline/synth_audio.py [--meows-only]
Requires: numpy (+ mido/soundfile for the song render).
"""
import argparse
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_chart import SAMPLE_ROOTS  # noqa: E402  (single source of truth)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR = 44100
MEOW_DIR = os.path.join(ROOT, 'assets', 'audio', 'meows')

DUR_S = 0.32
# Placeholders are pitched at the real recordings' roots so a fallback run
# still lines up with the chart's shifts.
MEOWS = dict(SAMPLE_ROOTS)


def has_recording(name):
    """True when a raw recording (prep_meows.py input) exists for this lane."""
    return any(os.path.isfile(os.path.join(MEOW_DIR, name + ext))
               for ext in ('.mp3', '.ogg', '.flac', '.wav'))


def midi_to_freq(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def synth_meow(midi_note):
    f0 = midi_to_freq(midi_note)
    n = int(SR * DUR_S)
    t = np.arange(n) / SR
    # "meow"-ish: pitch glides up then down with vibrato, breathy harmonics
    glide = 1.0 + 0.18 * np.sin(np.pi * t / DUR_S) ** 1.5
    vib = 1.0 + 0.012 * np.sin(2 * np.pi * 6.5 * t)
    f = f0 * glide * vib
    phase = 2 * np.pi * np.cumsum(f) / SR
    env = np.minimum(1.0, t / 0.03) * np.exp(-3.2 * t / DUR_S)
    y = (0.62 * np.sin(phase) + 0.25 * np.sin(2 * phase)
         + 0.13 * np.sin(3 * phase + 0.7))
    return (np.clip(y * env * 0.8, -1, 1) * 32767).astype(np.int16)


def write_wav(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print('wrote', path, f'{len(data)/SR:.2f}s')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--meows-only', action='store_true',
                        help='skip the (slow) backing-track render')
    parser.add_argument('--force', action='store_true',
                        help='overwrite meow_*.wav even if a real recording '
                             'exists (normally prep_meows.py owns those files)')
    args = parser.parse_args()
    for name, midi_note in MEOWS.items():
        out = os.path.join(MEOW_DIR, f'meow_{name}.wav')
        if has_recording(name) and not args.force:
            print(f'{name}: real recording present, not touching {out} '
                  f'(prep_meows.py turns recordings into meow_*.wav)')
            continue
        write_wav(out, synth_meow(midi_note))
    if args.meows_only:
        return
    import render_backing          # shares ROOT/assets paths with this script
    render_backing.render()
    print('NOTE: real meow recordings + a performed backing are still P2 polish.')


if __name__ == '__main__':
    main()
