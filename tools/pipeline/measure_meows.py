"""Measure the fundamental of every meow recording -> SAMPLE_ROOTS values.

The chart stores pitch *shifts* relative to the pitch each meow sample was
recorded at (pipeline §4). Guessing those roots detunes every lane, so measure
them instead:

    python tools/pipeline/measure_meows.py

Prints the measured f0 (Hz), nearest MIDI note and deviation in cents for each
file, then the exact `SAMPLE_ROOTS = {...}` line to paste into make_chart.py.
Read-only: nothing is written.

Method: autocorrelation of every 60 ms frame loud enough to carry the pitch
(robust for short, noisy, inharmonic cat sounds), octave-corrected with a
harmonic-sum score so a strong 2nd harmonic does not win, then the median of
those frames. The median matters: a meow's attack can momentarily show only
its even harmonics and read an octave high (high.mp3 does exactly that on its
first frame). The printed `spread` is the p10..p90 of the frame estimates in
semitones — a small number means the measurement is trustworthy.
"""
import glob
import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEOW_DIR = os.path.join(ROOT, 'assets', 'audio', 'meows')
FRAME_S = 0.06
FMIN, FMAX = 120.0, 1200.0     # plausible cat meow range


def load_mono(path):
    x, sr = sf.read(path, dtype='float32')
    if x.ndim > 1:
        x = x.mean(axis=1)
    return x, sr


def hz_to_midi(f0):
    return 69.0 + 12.0 * np.log2(f0 / 440.0)


def autocorr_f0(frame, sr):
    """Fundamental via autocorrelation + harmonic-sum octave check."""
    frame = frame - frame.mean()
    n = len(frame)
    spec = np.fft.rfft(frame, 2 * n)
    ac = np.fft.irfft(spec * np.conj(spec))[:n]
    lo = max(int(sr / FMAX), 2)
    hi = min(int(sr / FMIN), n - 1)
    if hi <= lo:
        return 0.0
    lag = lo + int(np.argmax(ac[lo:hi]))
    f0 = sr / lag
    # Octave check: pick the candidate whose first 6 harmonics carry the most
    # energy (avoids reporting 2*f0 for buzzy meows).
    best, best_score = f0, -1.0
    for div in (1, 2, 3):
        cand = f0 / div
        if cand < FMIN:
            continue
        score = 0.0
        for k in range(1, 7):
            f = cand * k
            if f >= sr / 2:
                break
            score += float(np.abs(np.fft.rfft(frame)[int(round(f * 2 * n / sr))]))
        if score > best_score:
            best, best_score = cand, score
    return best


def f0_frames(x, sr):
    """Per-frame f0 estimate for every frame loud enough to carry the pitch."""
    win = max(int(sr * FRAME_S), 256)
    hop = win // 2
    if len(x) < win:
        return []
    out = []
    frames = [(x[i:i + win], float(np.sqrt(np.mean(x[i:i + win] ** 2))))
              for i in range(0, len(x) - win, hop)]
    gate = 0.5 * max(r for _, r in frames) if frames else 0.0
    for frame, rms in frames:
        if rms >= gate and rms > 0.0:
            f0 = autocorr_f0(frame, sr)
            if f0 > 0:
                out.append(f0)
    return out


def f0_of(x, sr):
    """Median f0 over the frames that carry the sound, or 0.0 if too short.

    One frame is not a measurement: the attack of a meow can briefly show only
    its even harmonics, which reads a whole octave high (high.mp3 does exactly
    that on its first frame), so the median is taken twice — once to find the
    centre, once over only the frames within an octave of it, which drops the
    outliers. Stable whether you hand it the raw recording or the one-shot.
    """
    vals = _inliers(x, sr)
    return float(np.median(vals)) if vals else 0.0


def _inliers(x, sr):
    """Frame estimates minus the octave-jumping outliers."""
    vals = f0_frames(x, sr)
    if len(vals) < 3:
        return vals
    centre = float(np.median(vals))
    return [v for v in vals
            if abs(12.0 * np.log2(v / centre)) <= 6.0] or vals


def spread_st(x, sr):
    """p10..p90 spread of the inlier frame estimates, in semitones."""
    vals = _inliers(x, sr)
    if len(vals) < 3:
        return 0.0
    lo, hi = np.percentile(vals, [10, 90])
    return float(12.0 * np.log2(hi / lo))


def measure(path):
    x, sr = load_mono(path)
    return f0_of(x, sr), len(x) / sr, float(np.abs(x).max())


def main():
    files = sorted(glob.glob(os.path.join(MEOW_DIR, '*.mp3')) +
                   glob.glob(os.path.join(MEOW_DIR, '*.wav')))
    if not files:
        print(f'no meow files in {MEOW_DIR}')
        return
    measured = {}
    for path in files:
        f0, dur, peak = measure(path)
        name = os.path.basename(path)
        if f0 <= 0:
            print(f'{name:<22} {dur:5.2f}s peak {peak:4.2f}  -- no pitch found')
            continue
        midi = hz_to_midi(f0)
        x, sr = load_mono(path)
        print(f'{name:<22} {dur:5.2f}s peak {peak:4.2f}  '
              f'f0 {f0:7.2f}Hz  MIDI {midi:6.2f}  ({midi - round(midi):+.2f} st)  '
              f'spread {spread_st(x, sr):4.2f} st')
        measured[name] = midi
    # Suggest roots for the five canonical samples, when present.
    roots = {}
    for key in ('low', 'lowMid', 'mid', 'midHigh', 'high'):
        for name, midi in measured.items():
            if os.path.splitext(name)[0] == key:
                roots[key] = int(round(midi))
    if roots:
        print('\nPaste into make_chart.py:')
        print(f'SAMPLE_ROOTS = {roots!r}')


if __name__ == '__main__':
    main()