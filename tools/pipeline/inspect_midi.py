"""List a MIDI file's tracks so the melody track can be picked by ear.

    python tools/pipeline/inspect_midi.py "midi/canon in D.mid"

Per track: note count, pitch range, average pitch and the first few pitches.
The melody is usually the monophonic-ish track with the highest average pitch;
skip the drum/no-note tracks. make_chart.py plays the chosen index passed as
`--melody-track`. (Pipeline doc §5.)
"""
import sys

import mido


def describe(path):
    mid = mido.MidiFile(path)
    print(f'{path}: type {mid.type}, {len(mid.tracks)} tracks, '
          f'{mid.length:.1f}s, {mid.ticks_per_beat} tpb')
    for i, track in enumerate(mid.tracks):
        label = next((getattr(m, 'text', '') for m in track
                      if m.type == 'track_name'), '')
        notes = [m.note for m in track
                 if m.type == 'note_on' and m.velocity > 0]
        if not notes:
            print(f'  [{i}] {label!r:28} (no notes)')
            continue
        avg = sum(notes) / len(notes)
        print(f'  [{i}] {label!r:28} notes={len(notes):>5} '
              f'range={min(notes)}-{max(notes)} avg={avg:.1f} '
              f'head={notes[:10]}')


if __name__ == '__main__':
    for arg in sys.argv[1:] or ['midi/vivaldi-summer-piano.mid']:
        describe(arg)
