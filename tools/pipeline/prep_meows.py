"""Turn the raw meow recordings into game-ready one-shots.

Sources:  assets/audio/meows/{low,lowMid,mid,midHigh,high}.mp3  (ElevenLabs takes)
Outputs:  assets/audio/meows/meow_{low,lowMid,mid,midHigh,high}.wav

The game plays the WAVs: PCM one-shots are what a rhythm game wants (no MP3
encoder padding, exact sample 0), and SoLoud loads them fully into memory.
Per pipeline §7 / PRD P0 each output is:
  * mono, source sample rate kept (no needless resampling),
  * silence-trimmed on both ends (-40 dBFS gate on a smoothed envelope),
  * capped at MAX_LEN_S around its loudest window (so a long gliding meow
    keeps its characteristic part) with a short fade in/out,
  * peak-normalised to -1 dBFS so lanes sound equally loud.

The printed SAMPLE_ROOTS are measured from the WAVs that ship, so
make_chart.py's shifts line up with what the player actually hears.

Run: python tools/pipeline/prep_meows.py
Then: python tools/pipeline/measure_meows.py  (audit every file's pitch)
"""
import os
import sys
import wave

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_meows import f0_of, hz_to_midi  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEOW_DIR = os.path.join(ROOT, 'assets', 'audio', 'meows')

SAMPLES = ('low', 'lowMid', 'mid', 'midHigh', 'high')
TRIM_DB = -40.0        # gate relative to the recording's peak
MIN_LEN_S = 0.12       # never trim a meow away entirely
MAX_LEN_S = 0.45       # PRD: 150-400 ms one-shots, 450 is the safe ceiling
FADE_S = 0.03
PEAK = 0.89            # -1 dBFS


def source_for(name):
    for ext in ('.mp3', '.wav', '.ogg', '.flac'):
        path = os.path.join(MEOW_DIR, name + ext)
        if os.path.isfile(path):
            return path
    return None


def envelope(x, sr):
    """Smoothed rectified envelope (~5 ms window)."""
    win = max(int(0.005 * sr), 1)
    kernel = np.ones(win, dtype=np.float32) / win
    return np.convolve(np.abs(x).astype(np.float32), kernel, mode='same')


def trim(x, sr):
    env = envelope(x, sr)
    gate = env.max() * 10 ** (TRIM_DB / 20.0)
    above = np.flatnonzero(env > gate)
    if above.size == 0:
        return x
    lo, hi = int(above[0]), int(above[-1]) + 1
    # Keep a hair of the attack so the meow does not start abruptly.
    pad = int(0.01 * sr)
    return x[max(lo - pad, 0):min(hi + pad, len(x))]


def crop_to_loudest(x, n_max):
    """Keep the loudest [n_max] samples instead of the head.

    A 2 s recording that glides (mid.mp3 rises) loses its characteristic part
    and its measured root if you cut at the first 0.45 s. Cropping around the
    energy peak also keeps the root stable between the raw file and the
    one-shot the game plays.
    """
    if len(x) <= n_max:
        return x
    energy = np.cumsum(np.concatenate(([0.0], x.astype(np.float64) ** 2)))
    windows = energy[n_max:] - energy[:-n_max]
    start = int(np.argmax(windows))
    return x[start:start + n_max]


def prepare(x, sr):
    x = x.mean(axis=1) if x.ndim > 1 else x
    x = trim(np.asarray(x, dtype=np.float32), sr)
    n_max = int(MAX_LEN_S * sr)
    if len(x) > n_max:
        x = crop_to_loudest(x, n_max)
        fade = int(FADE_S * sr)
        # Fade both ends: the crop can land mid-glide.
        x[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)
        x[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    if len(x) < MIN_LEN_S * sr:
        raise ValueError(f'only {len(x) / sr:.3f}s of sound after trimming')
    peak = float(np.abs(x).max())
    if peak <= 0:
        raise ValueError('recording is silent')
    return x * (PEAK / peak)


def write_wav(path, x, sr):
    ints = (np.clip(x, -1.0, 1.0) * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(ints.tobytes())


def main():
    roots = {}
    for name in SAMPLES:
        src = source_for(name)
        if src is None:
            print(f'{name}: no recording found, keeping the existing '
                  f'meow_{name}.wav (synth_audio.py makes a placeholder)')
            continue
        x, sr = sf.read(src, dtype='float32')
        y = prepare(x, sr)
        out = os.path.join(MEOW_DIR, f'meow_{name}.wav')
        write_wav(out, y, sr)
        # Measure what ships, not the source: after trimming/cropping the
        # loudest frame (and therefore the root) can move.
        f0 = f0_of(y, sr)
        print(f'{name}: {os.path.basename(src)} ({len(x) / sr:.2f}s) -> '
              f'meow_{name}.wav ({len(y) / sr:.2f}s {sr}Hz mono, '
              f'f0 {f0:.1f}Hz = MIDI {hz_to_midi(f0):.2f})')
        roots[name] = int(round(hz_to_midi(f0)))
    if len(roots) == len(SAMPLES):
        print(f'\nSAMPLE_ROOTS = {roots!r}   # keep make_chart.py in sync')


if __name__ == '__main__':
    main()