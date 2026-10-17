"""Render the accompaniment MIDI to a real backing track (OGG Vorbis).

The chart's melody is *not* in this render: it is performed by the player's
meows. Only the accompaniment (everything except `MELODY_TRACK` in
`tools/pipeline/make_chart.py`) is rendered here, already transposed by the
chart builder, so the backing always matches the chart's pitch mapping.

Synth: additive quasi-piano. Each note is a handful of inharmonic partials
with per-partial decay (bright partials die first), a short hammer transient
and a release tail at note-off. A synthetic exponential-decay impulse is then
convolved in (FFT) as a small-room plate, so the track sits behind the meows
instead of on top of them.

In:  tools/out/summer_backing.mid   (written by make_chart.py)
Out: assets/audio/songs/summer.ogg  16-bit mono 22.05 kHz Vorbis

Run: python tools/pipeline/render_backing.py
Requires: numpy + soundfile with libsndfile OGG/Vorbis support.
"""
import argparse
import json
import os
import sys

import numpy as np

try:
    import mido
except ImportError:  # pragma: no cover - tooling only
    mido = None
try:
    import soundfile as sf
except ImportError:  # pragma: no cover - tooling only
    sf = None

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MIDI_PATH = os.path.join(ROOT, 'tools', 'out', 'summer_backing.mid')
CHART_PATH = os.path.join(ROOT, 'assets', 'charts', 'summer.json')
OUT_PATH = os.path.join(ROOT, 'assets', 'audio', 'songs', 'summer.ogg')

SR = 22050          # plenty for a piano-ish pad; keeps the asset small
TAIL_S = 0.6        # rendered past the last note so the final chord decays
RELEASE_S = 0.18    # damper time after note_off
WET = 0.22          # reverb mix
PREDELAY_MS = 18.0
RT60_S = 1.5
OGG_CHUNK = 1 << 17  # 131072 samples per encoder call (see render())

# part-k gain, and how much faster part k decays than the fundamental.
PARTIALS = ((1, 1.00, 1.00), (2, 0.42, 1.70), (3, 0.22, 2.40),
            (4, 0.11, 3.30), (5, 0.06, 4.20), (6, 0.03, 5.20))
BASE_DECAY = 1.9    # 1/s on the fundamental — a sustained, cozy piano
INHARM = 0.0004     # string stiffness: f_k = k*f0*sqrt(1 + INHARM*k^2)
HAMMER = 0.05       # onset transient level


def midi_to_freq(note):
    return 440.0 * 2 ** ((note - 69) / 12)
def read_notes(path):
    """(start_s, dur_s, midi_note, velocity) for every note in the file."""
    mid = mido.MidiFile(path)
    t = 0.0
    open_notes = {}      # (channel, note) -> (start, velocity)
    out = []
    for msg in mid:      # MidiFile.__iter__ yields seconds, merged across tracks
        t += msg.time
        if msg.type == 'note_on' and msg.velocity > 0:
            open_notes[(msg.channel, msg.note)] = (t, msg.velocity)
        elif msg.type in ('note_off', 'note_on'):
            key = (msg.channel, msg.note)
            if key in open_notes:
                start, vel = open_notes.pop(key)
                out.append((start, max(t - start, 0.05), msg.note, vel))
    for (_, note), (start, vel) in open_notes.items():      # unterminated
        out.append((start, max(t - start, 0.05), note, vel))
    out.sort()
    return out, mid.length


def render_note(note, dur, velocity):
    """One note as a float32 array starting at sample 0."""
    f0 = midi_to_freq(note)
    amp = (velocity / 127.0) ** 1.6
    # Long notes still ring after the key is released; short ones just decay.
    ring = dur + RELEASE_S
    n = int(SR * ring)
    if n <= 0:
        return np.zeros(0, dtype=np.float32)
    t = (np.arange(n, dtype=np.float32) / SR)
    # Damper on top of the natural decay: whichever is slower wins.
    damper = np.where(t > dur, np.exp(-(t - dur) / RELEASE_S * 4.0), 1.0)
    y = np.zeros(n, dtype=np.float32)
    for k, gain, decay_mul in PARTIALS:
        fk = k * f0 * np.sqrt(1.0 + INHARM * k * k)
        if fk > SR * 0.45:          # above Nyquist: skip instead of aliasing
            continue
        env = np.exp(-BASE_DECAY * decay_mul * t).astype(np.float32)
        y += gain * env * np.sin(2 * np.pi * fk * t).astype(np.float32)
    # 4 ms attack + a short noise transient: without it every note "pops".
    attack = max(int(0.004 * SR), 1)
    if attack < n:
        y[:attack] *= np.linspace(0.0, 1.0, attack, dtype=np.float32)
        rng = np.random.default_rng((note * 2654435761) % 2 ** 32)
        hammer = rng.standard_normal(n - attack).astype(np.float32) * HAMMER
        hammer *= np.exp(-t[attack:] * 60.0).astype(np.float32)
        y[attack:] += hammer
    return y * (amp * damper).astype(np.float32)


def reverb(x, sr=SR):
    """FFT convolution with a synthetic warm exponential-decay impulse."""
    n_ir = int(sr * RT60_S)
    t = np.arange(n_ir) / sr
    rng = np.random.default_rng(7)
    ir = (rng.standard_normal(n_ir) * np.exp(-6.9 * t / RT60_S)).astype(np.float32)
    for _ in range(2):      # two box blurs ≈ gentle low-pass: keeps it cozy
        ir = np.convolve(ir, np.ones(64, dtype=np.float32) / 64.0, mode='same')
    ir /= np.sqrt((ir ** 2).sum()) + 1e-9
    pad = int(sr * PREDELAY_MS / 1000.0)
    ir = np.concatenate([np.zeros(pad, dtype=np.float32), ir])
    size = 1 << (len(x) + len(ir) - 2).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return x * (1 - WET) + wet[:len(x)].astype(np.float32) * WET * 3.0


def render(midi_path=MIDI_PATH, out_path=OUT_PATH, chart_path=CHART_PATH):
    if mido is None or sf is None:
        print('render_backing: needs mido + soundfile (pip install mido soundfile)')
        return False
    if not os.path.exists(midi_path):
        print(f'render_backing: missing {midi_path} — run make_chart.py first')
        return False
    notes, midi_len = read_notes(midi_path)
    with open(chart_path) as f:
        chart_len = json.load(f)['duration_s']
    # The melody track is stripped from the backing, so the accompaniment can
    # stop before the chart does — render to the chart's length, not the MIDI's.
    total = max(midi_len, chart_len) + TAIL_S
    n = int(SR * total)
    buf = np.zeros(n, dtype=np.float32)
    written = 0
    for start, dur, note, vel in notes:
        i0 = int(start * SR)
        if i0 >= n:
            continue
        seg = render_note(note, dur, vel)
        end = min(n, i0 + len(seg))
        if end <= i0:
            continue
        buf[i0:end] += seg[:end - i0]
        written += 1
    rms = float(np.sqrt((buf ** 2).mean()))
    buf = reverb(buf)[:n]
    top = float(np.abs(buf).max())
    if top > 1e-6:                      # normalize to a sane -1.5 dBFS
        buf = buf * (0.84 / top)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    # Chunked write: one sf.write() call with a multi-million-sample buffer
    # overflows the stack inside libsndfile's Vorbis encoder on Windows.
    with sf.SoundFile(out_path, 'w', SR, channels=1, format='OGG',
                      subtype='VORBIS') as out:
        for i in range(0, len(buf), OGG_CHUNK):
            out.write(buf[i:i + OGG_CHUNK])
    print(f'rendered {written} notes -> {out_path} '
          f'({total:.2f}s, mono {SR}Hz, rms {rms:.4f}, '
          f'{os.path.getsize(out_path) / 1e6:.1f}MB)')
    return True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--midi', default=MIDI_PATH,
                        help='transposed backing MIDI written by make_chart')
    parser.add_argument('--chart', default=CHART_PATH,
                        help='the chart JSON the MIDI was cut for')
    parser.add_argument('--out', default=OUT_PATH,
                        help='destination .ogg under assets/audio/songs/')
    args = parser.parse_args(argv)
    ok = render(midi_path=args.midi, out_path=args.out,
                chart_path=args.chart)
    print('NOTE: swap in a real performance (soundfont/recordings) before release.'
          if ok else 'render failed')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
