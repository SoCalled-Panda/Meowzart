"""A MIDI file -> Meowzart chart JSON + melody-stripped, transposed backing.

Run from repo root, defaults to Summer:
    python tools/pipeline/make_chart.py
    python tools/pipeline/make_chart.py --midi "midi/canon in D.mid" \
        --id canon --title "Canon in D" --composer "Johann Pachelbel"

In : the MIDI named by --midi (pick the melody track with inspect_midi.py)
Out: assets/charts/<id>.json + tools/out/<id>_backing.mid
"""
import argparse
import collections
import json
import os
import statistics

import mido
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MIDI_PATH = os.path.join(ROOT, 'midi', 'vivaldi-summer-piano.mid')
CHART_PATH = os.path.join(ROOT, 'assets', 'charts', 'summer.json')
BACKING_PATH = os.path.join(ROOT, 'tools', 'out', 'summer_backing.mid')

MELODY_TRACK = 0
DIFFICULTIES = {'easy': 350, 'normal': 180}
NUM_LANES = 4
# Measured from the WAVs that ship (tools/pipeline/measure_meows.py, median of
# the loud frames): low = 186.8Hz = MIDI 54.17, mid = 313.7Hz = MIDI 63.14,
# high = 457.2Hz = MIDI 69.66. A meow is a glide, not a tone, so each root is
# only good to about +/-1 semitone (the audit prints the spread).
SAMPLE_ROOTS = {'low': 54, 'lowMid': 55, 'mid': 63, 'midHigh': 64, 'high': 70}
MAX_SHIFT = 5
# Coverage is the union of each sample's ±MAX_SHIFT window, so the melody's
# register has to land inside it (see fit_transposition). Vivaldi Summer's
# melody spans 53-98; the pipeline transposes the whole song to fit and folds
# the handful of extreme outliers by whole octaves.



def track_notes_timed(mid, index):
    track = mid.tracks[index]
    ticks = mid.ticks_per_beat
    abs_tempo = []
    for tr in mid.tracks:
        t = 0
        for msg in tr:
            t += msg.time
            if msg.type == 'set_tempo':
                abs_tempo.append((t, msg.tempo))
    tempos = sorted(abs_tempo) if abs_tempo else [(0, 500000)]
    if tempos[0][0] != 0:
        tempos.insert(0, (0, 500000))

    def to_sec(tick):
        s = 0.0
        for i, (t0, tp) in enumerate(tempos):
            nxt = tempos[i + 1][0] if i + 1 < len(tempos) else None
            if tick <= t0:
                break
            end = tick if nxt is None or tick < nxt else nxt
            s += (end - t0) * tp / 1e6 / ticks
            if nxt is not None and tick >= nxt:
                continue
            break
        return s

    open_n = {}
    notes = []
    t = 0
    for msg in track:
        t += msg.time
        if msg.type == 'note_on' and msg.velocity > 0:
            open_n[(msg.channel, msg.note)] = t
        elif msg.type in ('note_off', 'note_on'):
            key = (getattr(msg, 'channel', 0), getattr(msg, 'note', -1))
            if key in open_n:
                t0 = open_n.pop(key)
                notes.append((to_sec(t0), to_sec(t), msg.note))
    notes.sort()
    return notes


def flatten_chords(notes, window=0.03):
    out = []
    for n in notes:
        if out and n[0] - out[-1][0] < window:
            if n[2] > out[-1][2]:
                out[-1] = n
        else:
            out.append(n)
    return out


def thin(notes, min_gap_s, min_dur_s=0.04):
    out, last = [], -1e9
    for n in notes:
        if n[1] - n[0] < min_dur_s:
            continue
        if n[0] - last < min_gap_s:
            continue
        out.append(n)
        last = n[0]
    return out


def reachable(p):
    """True if some recorded sample can play pitch p within MAX_SHIFT."""
    return any(abs(p - r) <= MAX_SHIFT for r in SAMPLE_ROOTS.values())


def coverage_gaps():
    """Unplayable pitch bands between the samples' windows, e.g. [68, 75]."""
    windows = sorted((r - MAX_SHIFT, r + MAX_SHIFT)
                     for r in SAMPLE_ROOTS.values())
    gaps, reach_hi = [], windows[0][1]
    for lo, hi in windows[1:]:
        if lo > reach_hi + 1:
            gaps.append((reach_hi + 1, lo - 1))
        reach_hi = max(reach_hi, hi)
    return gaps


def fold_to_reachable(p, prev=None, max_octaves=2):
    """Octave-move p onto a playable pitch. Returns (pitch, octave_moves).

    Whole octaves only: the pitch class (and so the key) is preserved, which is
    what keeps a folded note in tune with the backing. When [prev] is given
    (the previous note's final pitch) the candidate closest to it wins, so a
    note that has to fold keeps the melody's contour instead of jumping two
    octaves away from its neighbours. Returns (None, max_octaves) if the pitch
    is out of reach at every octave.
    """
    candidates = [(abs(o), p + 12 * o * s)
                  for o in range(max_octaves + 1)
                  for s in ((0,) if o == 0 else (1, -1))
                  if reachable(p + 12 * o * s)]
    if not candidates:
        return None, max_octaves
    # Fewest octave moves first — a playable note must never fold. Only when a
    # note *has* to fold does [prev] pick the direction that keeps the contour.
    fewest = min(moves for moves, _ in candidates)
    playable = [q for moves, q in candidates if moves == fewest]
    if prev is None:
        q = min(playable, key=lambda c: (abs(c - p), c))
    else:
        q = min(playable, key=lambda c: (abs(c - prev), abs(c - p)))
    return q, fewest


def fit_transposition(pitches):
    """Pick the whole-song transpose that needs the fewest octave folds.

    Coverage is the union of every sample's ±MAX_SHIFT window; with the five
    measured roots that union is one contiguous band (49..75), and the melody
    is wider (46 semitones) than the coverage, so some notes must fold an
    octave. Folding keeps them in key; clamping the shift at ±5 instead would
    sound a wrong interval, which is far worse.
    """
    best = None
    for t in range(-12, 13):
        moves = 0
        unplayable = 0
        adj = []
        prev = None
        for p in pitches:
            q, n = fold_to_reachable(p + t, prev)
            if q is None:
                # Nothing can reach it: park it on the closest root (audible
                # only for extreme outliers, reported as `clamped`).
                unplayable += 1
                q = min(SAMPLE_ROOTS.values(), key=lambda r: abs(r - (p + t)))
            else:
                moves += n
            adj.append(q)
            prev = q
        score = (unplayable, moves, abs(t))
        if best is None or score < best[0]:
            best = (score, t, adj)
    score, t, adj = best
    return t, score[1], score[0], adj



def meow_for_pitch(p):
    name, root = min(SAMPLE_ROOTS.items(), key=lambda kv: abs(kv[1] - p))
    return name, max(-MAX_SHIFT, min(MAX_SHIFT, p - root))


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--midi', default=MIDI_PATH,
                        help='source MIDI file')
    parser.add_argument('--id', default='summer',
                        help='chart id; names the JSON, backing and ogg')
    parser.add_argument('--title', default='Summer (Presto)')
    parser.add_argument('--composer', default='Antonio Vivaldi')
    parser.add_argument('--bpm', type=float, default=120.0)
    parser.add_argument('--melody-track', type=int, default=MELODY_TRACK,
                        help='track index holding the melody (inspect_midi)')
    parser.add_argument('--chart-out', default=None,
                        help='default: assets/charts/<id>.json')
    parser.add_argument('--backing-out', default=None,
                        help='default: tools/out/<id>_backing.mid')
    return parser.parse_args(argv)


def main():
    args = parse_args()
    chart_path = args.chart_out or os.path.join(
        ROOT, 'assets', 'charts', f'{args.id}.json')
    backing_path = args.backing_out or os.path.join(
        ROOT, 'tools', 'out', f'{args.id}_backing.mid')
    mid = mido.MidiFile(args.midi)
    melody = track_notes_timed(mid, args.melody_track)
    flat = flatten_chords(melody)
    print(f'melody raw={len(melody)} flat={len(flat)} '
          f'range={min(p for _, _, p in flat)}-{max(p for _, _, p in flat)}')
    duration_s = max(n[1] for n in flat)
    transpose, folded, clamped, adj = fit_transposition(
        [p for _, _, p in flat])
    print(f'T={transpose:+d} octave_folds={folded} clamped={clamped}')
    win = sorted((r - MAX_SHIFT, r + MAX_SHIFT) for r in SAMPLE_ROOTS.values())
    print(f'sample coverage={win[0][0]}..{win[-1][1]} holes={coverage_gaps()}')
    if coverage_gaps():
        print('WARNING: notes landing in a hole fold a whole octave. Record one '
              'more meow in that range (SAMPLE_ROOTS, then re-run this script '
              'and render_backing.py) to remove the folds.')
    shifted = [(s, e, q) for (s, e, _), q in zip(flat, adj)]
    diffs = {}
    for name, gap_ms in DIFFICULTIES.items():
        th = thin(shifted, gap_ms / 1000.0)
        edges = np.quantile([p for _, _, p in th], np.linspace(0, 1, 5)[1:-1])
        notes = []
        for s, _, p in th:
            lane = int(np.searchsorted(edges, p, side='right'))
            sample, shift = meow_for_pitch(p)
            notes.append({'t': round(s, 3), 'lane': lane,
                          'sample': sample, 'shift': shift})
        lanes = [sum(1 for n in notes if n['lane'] == l) for l in range(4)]
        gaps = [b['t'] - a['t'] for a, b in zip(notes, notes[1:])]
        print(f'{name}: n={len(notes)} lanes={lanes} '
              f'mingap={min(gaps)*1000:.0f}ms nps={len(notes)/duration_s:.2f}')
        diffs[name] = {'min_gap_ms': gap_ms, 'notes': notes}
    chart = {
        'version': 1, 'id': args.id, 'title': args.title,
        'composer': args.composer, 'bpm': args.bpm,
        'duration_s': round(duration_s, 3),
        'audio': f'songs/{args.id}.ogg',
        'audio_offset_ms': 0, 'transpose': transpose,
        'lanes': 4, 'difficulties': diffs,
    }
    os.makedirs(os.path.dirname(chart_path), exist_ok=True)
    with open(chart_path, 'w') as f:
        json.dump(chart, f, indent=2)
    print('wrote', chart_path)
    out = mido.MidiFile(ticks_per_beat=mid.ticks_per_beat, type=1)
    for i, track in enumerate(mid.tracks):
        if i == args.melody_track:
            continue
        nt = mido.MidiTrack()
        for msg in track:
            if msg.type in ('note_on', 'note_off') and hasattr(msg, 'note'):
                msg = msg.copy(note=max(0, min(127, msg.note + transpose)))
            nt.append(msg)
        out.tracks.append(nt)
    os.makedirs(os.path.dirname(backing_path), exist_ok=True)
    out.save(backing_path)
    print('wrote', backing_path)


if __name__ == '__main__':
    main()


