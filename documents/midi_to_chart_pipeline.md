# MIDI to Chart Pipeline

Offline Python tooling that turns a MIDI file into (1) a game chart JSON and (2) a backing track. Runs on your computer, never inside the app.

## 1. Overview

```
MIDI file
   │
   ▼
[1] Load + inspect tracks
   ▼
[2] Select melody track (auto or manual)
   ▼
[3] Clean: merge chords → single notes, drop very short notes
   ▼
[4] Thin by difficulty (minimum gap between notes)
   ▼
[5] Fit a global transposition so every pitch is within ±5 of a meow root
   ▼
[6] Map pitch → lane (quantile-based), and pitch → meow sample + semitone shift
   ▼
[7] Export chart JSON + melody-stripped, transposed backing MIDI
   ▼
[8] Render backing audio (fluidsynth on the *_backing.mid) → OGG
   ▼
[9] Validate + preview
```

## 2. Setup

```bash
cd tools
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install pretty_midi mido numpy matplotlib
# For backing audio:
#   macOS:  brew install fluidsynth ffmpeg
#   Ubuntu: sudo apt install fluidsynth ffmpeg
#   Also download a General MIDI soundfont (.sf2). Check its license.
```

`tools/requirements.txt`:
```
pretty_midi
mido
numpy
matplotlib
```

## 3. Sourcing MIDI files (legal checklist)

- The **composition** must be public domain (composer died 70+ years ago in most regions).
- The **MIDI file** is a separate work (someone's sequencing/arrangement) and may be copyrighted. Prefer files that are explicitly CC0/public domain (e.g., Mutopia Project for scores, or MIDI collections stating a free license). Verify the terms.
- The **soundfont** has its own license. Prefer permissive ones and credit where required.
- Record each in `assets/LICENSES.md`:

```
| File | Source URL | License | Notes |
```

Alternative with zero risk: make your own MIDI from a public-domain score in MuseScore and export.

## 4. Folder layout

```
tools/
├─ pipeline/
│  ├─ inspect_midi.py
│  ├─ make_chart.py
│  ├─ render_backing.py
│  ├─ validate_chart.py
│  ├─ preview_chart.py
│  └─ config.py
├─ songs/
│  ├─ spring/
│  │  ├─ spring.mid
│  │  └─ song.yaml   (or config in Python: melody track, bpm override, offsets)
├─ soundfonts/
└─ out/               → copy final files to assets/
```

## 5. Step 1: Inspect

```python
# inspect_midi.py
import sys, pretty_midi

midi = pretty_midi.PrettyMIDI(sys.argv[1])
print(f"Duration: {midi.get_end_time():.1f}s | Tempo estimates: {midi.estimate_tempo():.1f} BPM")
for i, inst in enumerate(midi.instruments):
    if not inst.notes:
        continue
    pitches = [n.pitch for n in inst.notes]
    print(f"[{i}] {inst.name or 'unnamed':<20} drum={inst.is_drum} "
          f"notes={len(inst.notes):>5} range={min(pitches)}-{max(pitches)}")
```

Pick the melody track by looking at the output. It is usually the track with the highest average pitch in a monophonic-ish line (often the violin/flute/right-hand piano). Skip drums. For Vivaldi's Spring, the solo violin is the melody.

## 6. Steps 2 to 7: Chart generation

```python
# make_chart.py
import json, sys, math
import numpy as np
import pretty_midi

DIFFICULTIES = {          # min gap between playable notes, ms
    "easy":   350,
    "normal": 180,
    "hard":   120,
}
NUM_LANES = 4
SAMPLE_ROOTS = {"low": 57, "mid": 64, "high": 71}   # MEASURED MIDI pitch of each meow (see §12)
MAX_SHIFT = 5                                        # semitones
# Coverage window: with roots 57/64/71 and ±5, every pitch in 52..76 can be played in key.
# Anything outside needs a transposition (fit_transposition) or a 4th sample.

def load_melody(path, track_index=None):
    """Returns (midi, melody_instrument, notes_sorted_by_time)."""
    midi = pretty_midi.PrettyMIDI(path)
    cands = [i for i in midi.instruments if not i.is_drum and i.notes]
    inst = cands[track_index] if track_index is not None else max(cands, key=lambda i: len(i.notes))
    return midi, inst, sorted(inst.notes, key=lambda n: (n.start, -n.pitch))

def flatten_chords(notes, window=0.03):
    """If several notes start within `window` seconds, keep only the highest (melody-like)."""
    out = []
    for n in notes:
        if out and n.start - out[-1].start < window:
            if n.pitch > out[-1].pitch:
                out[-1] = n
        else:
            out.append(n)
    return out

def thin(notes, min_gap_s, min_dur_s=0.04):
    out, last = [], -1e9
    for n in notes:
        if n.end - n.start < min_dur_s:
            continue
        if n.start - last < min_gap_s:
            continue
        out.append(n)
        last = n.start
    return out

def lane_edges(pitches, lanes=NUM_LANES):
    """Quantile-based so all lanes are used evenly regardless of the piece's range."""
    qs = np.linspace(0, 1, lanes + 1)[1:-1]
    return np.quantile(pitches, qs)

def pitch_to_lane(p, edges):
    return int(np.searchsorted(edges, p, side="right"))

def meow_for_pitch(p):
    """Pick the sample whose root is closest in ABSOLUTE pitch, then clamp the shift.

    Never fold octaves. Folding (mapping by pitch class only) makes a low note and the
    same note an octave up sound identical, which destroys the melody's register and
    puts the meow out of place against the backing track.
    """
    name, root = min(SAMPLE_ROOTS.items(), key=lambda kv: abs(kv[1] - p))
    shift = max(-MAX_SHIFT, min(MAX_SHIFT, p - root))
    return name, shift

def _out_of_coverage(p):
    root = min(SAMPLE_ROOTS.values(), key=lambda r: abs(r - p))
    return abs(p - root) > MAX_SHIFT

def fit_transposition(pitches):
    """Smallest |T| that moves the whole melody inside the samples' coverage window.

    T is applied to the melody pitches here AND to the MIDI rendered for the backing
    track, so meows and accompaniment stay in key with each other. The song simply plays
    a few semitones higher or lower than the original — nobody notices, and being in key
    matters far more than matching the composer's key.
    Returns (T, clamped_count); clamped_count > 0 means notes are still out of range.
    """
    lo, hi = min(pitches), max(pitches)
    cov_lo = min(SAMPLE_ROOTS.values()) - MAX_SHIFT
    cov_hi = max(SAMPLE_ROOTS.values()) + MAX_SHIFT
    if hi - lo > (cov_hi - cov_lo):          # melody wider than the samples can cover
        T = int(round((cov_lo + cov_hi) / 2 - (lo + hi) / 2))
    else:
        T = 0
        if lo + T < cov_lo: T = cov_lo - lo
        if hi + T > cov_hi: T = cov_hi - hi
    return int(T), sum(1 for p in pitches if _out_of_coverage(p + T))

def build(path, out_path, meta, track_index=None, lead_in_s=0.0, strip_melody=True):
    """Writes <out>.json (the chart) and <out>_backing.mid (melody stripped + transposed)."""
    midi, melody, notes = load_melody(path, track_index)
    notes = flatten_chords(notes)
    all_pitches = [n.pitch for n in notes]

    T, clamped = fit_transposition(all_pitches)
    if clamped:
        print(f"WARNING: {clamped} notes outside sample coverage even after transpose {T:+d} "
              f"-> they will be clamped (slightly out of key)")
    if T:
        # melody notes are the same objects inside midi, so one pass moves everything
        for inst in midi.instruments:
            for n in inst.notes:
                n.pitch += T
        print(f"Transposed {T:+d} semitones so meows and backing stay in key")

    all_pitches = [n.pitch for n in notes]
    edges = lane_edges(all_pitches)

    chart = {
        "version": 1, "id": meta["id"], "title": meta["title"],
        "composer": meta["composer"], "bpm": round(midi.estimate_tempo()),
        "duration_s": round(midi.get_end_time() + lead_in_s, 2),
        "audio": f"songs/{meta['id']}.ogg", "audio_offset_ms": 0,
        "transpose": T, "lanes": NUM_LANES, "difficulties": {},
    }
    for diff, gap_ms in DIFFICULTIES.items():
        sel = thin(notes, gap_ms / 1000)
        out = []
        for n in sel:
            lane = pitch_to_lane(n.pitch, edges)
            sample, shift = meow_for_pitch(n.pitch)
            out.append({"t": round(n.start + lead_in_s, 3), "lane": lane,
                        "sample": sample, "shift": shift})
        chart["difficulties"][diff] = {"min_gap_ms": gap_ms, "notes": out}
    json.dump(chart, open(out_path, "w"), separators=(",", ":"))

    # Backing: drop the melody so the player's meows ARE the melody.
    # strip_melody=False for solo-piano pieces where that leaves almost nothing.
    if strip_melody and melody in midi.instruments:
        midi.instruments.remove(melody)
    backing_path = out_path.replace(".json", "_backing.mid")
    midi.write(backing_path)
    print(f"Chart: {out_path}\nBacking MIDI: {backing_path}  <- render this in step 8")
    return chart

if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2],
          {"id": "canon", "title": "Canon in D", "composer": "Johann Pachelbel"})
```

### Why these choices

- **Highest-note flattening**: melody is usually the top voice, so chords collapse to it.
- **Time-gap thinning** instead of random removal keeps the rhythm's shape while making it playable. Tune per difficulty: ~350 ms easy, ~180 ms normal, ~120 ms hard.
- **Quantile lane mapping**: fixed pitch ranges make some lanes empty in narrow-range pieces, quantiles guarantee balance.
- **Nearest-root, no octave folding**: folding by pitch class makes a note and the same note an octave up produce the identical meow, which flattens the melody's register and puts meows out of place against the backing. Instead each note uses the sample closest in *absolute* pitch, and the whole song is transposed (`fit_transposition`) until it fits the samples' ±5-semitone coverage window. The key changes slightly; the melody keeps its shape and stays in key with the accompaniment.
- The mapping to lanes is *melodic contour*, so high notes appear on the right-hand lanes and low on the left, which feels intuitive.

**On `transpose`:** a healthy value is 0 or ±1..4. If `fit_transposition` returns |T| > 7, do not ship it — it means either `SAMPLE_ROOTS` are wrong (a real cat meow usually sits around MIDI 70-85, much higher than the 57/64/71 placeholder) or the melody is wider than 3 samples can cover. Re-measure the roots first; if the melody really is >24 semitones wide, add a 4th sample or pick a different arrangement.

### Improvements (optional, after the MVP works)

- **Avoid same-lane repeats becoming jacks**: if 3+ consecutive notes share a lane and gap < 200 ms, nudge the middle note to the neighboring lane.
- **Snap to a beat grid**: quantize note times to 1/8 or 1/16 of the beat grid, using `midi.get_beats()`, for cleaner feel (do this only if the MIDI is not performance-recorded).
- **Emphasis notes**: on strong beats, prefer keeping longer or louder notes (`n.velocity`, `n.end - n.start`) when thinning.
- **Sections**: reduce density in the intro/outro for a gentler start/end.

## 7. Step 8: Render backing audio

The backing track must start at **exactly t=0 of the MIDI** so the chart and audio align, and it must be rendered from the **`*_backing.mid` file the pipeline writes** (that file already has the melody removed *and* the `fit_transposition` transposition applied — rendering the original `.mid` would put the accompaniment in a different key from the meows).

**Lead-in: leave `lead_in_s = 0`.** The game clock starts at −2 s instead (see `architecture.md` §6.1). Never apply lead-in in both places or every note is 2 s late.

```bash
# Render MIDI → WAV (use the pipeline's output, not the original)
fluidsynth -ni soundfonts/GeneralUser.sf2 out/canon_backing.mid \
  -F out/canon.wav -r 44100

# Convert → OGG, quiet-ish, mono is fine for backing
ffmpeg -y -i out/canon.wav -ac 2 -c:a libvorbis -q:a 4 out/canon.ogg
```

Removing the melody is the most fun version of the concept — the player's meows *are* the melody, and `build()` already does it (`strip_melody=True` by default). If the accompaniment is too sparse (solo-piano pieces like Ode to Joy), call `build(..., strip_melody=False)` and keep the melody in the backing at low volume instead — pass ~0.25 volume when you mix it in the app.

## 8. Step 9: Validate

```python
# validate_chart.py
import json, sys, collections
chart = json.load(open(sys.argv[1]))
ok = True
print(f'transpose={chart.get("transpose", 0):+d}')
for diff, d in chart["difficulties"].items():
    notes = d["notes"]
    times = [n["t"] for n in notes]
    if times != sorted(times): print(f"{diff}: not sorted"); ok = False
    if any(n["lane"] not in range(chart["lanes"]) for n in notes): print(f"{diff}: bad lane"); ok = False
    if any(abs(n["shift"]) > 5 for n in notes): print(f"{diff}: shift > 5"); ok = False
    if notes and notes[-1]["t"] > chart["duration_s"]: print(f"{diff}: note after end"); ok = False
    lane_counts = [sum(1 for n in notes if n["lane"] == l) for l in range(chart["lanes"])]
    shifts = collections.Counter(n["shift"] for n in notes)
    samples = collections.Counter(n["sample"] for n in notes)
    gaps = [b - a for a, b in zip(times, times[1:])]
    if len(samples) < 3: print(f"{diff}: WARNING only {len(samples)} of 3 meow samples used")
    if notes and max(lane_counts) / len(notes) > 0.5:
        print(f"{diff}: WARNING one lane dominates: {lane_counts}")
    if gaps:
        print(f"{diff}: {len(notes)} notes, lanes={lane_counts}, samples={dict(samples)}, "
              f"shifts={dict(sorted(shifts.items()))}, "
              f"min gap={min(gaps)*1000:.0f} ms, notes/sec={len(notes)/chart['duration_s']:.2f}")
    else:
        print(f"{diff}: {len(notes)} notes (too few to judge density)")
print("OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
```

A healthy chart uses all 3 samples, has shifts clustered around 0 (few at ±5), and shows no lane with 0 notes or >50% of notes.

Target densities (notes per second, averaged): **Easy 1.0-2.0, Normal 2.0-3.5, Hard 3.5-5.0**. Above ~6 on a phone is punishing.

## 9. Preview (fast tuning loop)

```python
# preview_chart.py: piano-roll style plot: x = time, y = lane
import json, sys, matplotlib.pyplot as plt
c = json.load(open(sys.argv[1])); diff = sys.argv[2] if len(sys.argv) > 2 else "normal"
n = c["difficulties"][diff]["notes"]
plt.figure(figsize=(14, 3))
plt.scatter([x["t"] for x in n], [x["lane"] for x in n], s=6)
plt.yticks(range(c["lanes"])); plt.xlabel("seconds"); plt.title(f'{c["title"]} ({diff})')
plt.show()
```

Look for: empty stretches, dense clumps, one lane dominating, long same-lane runs.

## 10. Manual tuning workflow

1. Run the pipeline, then `validate_chart.py`, then `preview_chart.py`.
2. Play the song in the game, note the timestamps that feel wrong (bad spikes, awkward jumps).
3. Add per-song overrides in `song.yaml`:
   ```yaml
   id: canon
   track_index: 0
   min_gap_ms: { easy: 400, normal: 190 }
   drop_ranges: [[45.0, 47.5]]      # remove notes in these time windows
   force_lane: { "12.345": 3 }      # pin a specific note to a lane
   lead_in_s: 0                     # MUST stay 0 — the game clock owns the lead-in
   ```
4. Re-run, re-test, repeat. Budget about 20 minutes per song (Canon and Ode are simple; Spring may need `drop_ranges`).

## 11. Copying to the app

```bash
cp out/canon.json  ../assets/charts/
cp out/canon.ogg   ../assets/audio/songs/
# update assets/charts/songs.json manifest
```

## 12. Tuning the meow samples

- Play each meow at a reference pitch in a DAW (Audacity) or Python `librosa.pyin` to estimate its fundamental, then set `SAMPLE_ROOTS` to the nearest MIDI number. Cat meows are glides, not pure tones, so pick by ear.
- **The roots describe what the recording actually sounds like — never move them to fit a song.** If a root is wrong, every meow is out of key with the backing track. Adaptation is the pipeline's job (`fit_transposition`), not the roots'.
- Three roots a fifth apart give a coverage window of `root_min−5 .. root_max+5`. With roots 57/64/71 that is 52..76 (25 semitones). **Measure before trusting these numbers** — cats typically meow around MIDI 70-85, so your real roots are probably higher, which also means less transposition is needed.
- `validate_chart.py` prints `transpose`; treat |T| > 7 as a bug in the roots, not a normal result.
- Gaps between neighbouring roots must stay ≤ 10 semitones or a hole opens where no sample can reach.
- Keep samples short (150-400 ms) so quick passages don't turn into mush.

## 13. Pop songs: not for the MVP

If you ever want them:
- **Legal**: shipping charts/audio of copyrighted songs needs licensing. Use tracks you own or royalty-free music.
- **Technical**: `librosa.beat.beat_track` and `librosa.onset.onset_detect` for rhythm; Spotify `basic-pitch` for audio → MIDI, then feed the MIDI into this same pipeline. Expect noisy results and lots of manual cleanup.

## 14. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Notes early/late by a constant amount | Backing audio has leading silence or encoder padding | Trim/pad and set `audio_offset_ms`, or use the in-game offset slider |
| Drift grows over time | MIDI tempo changes not reflected, or wrong sample rate | Render with the same MIDI, fixed sample rate (44.1 kHz) |
| Lanes look empty | Fixed pitch bands | Use quantile mapping (above) |
| Chart feels random | Thinning cut structural notes | Increase gap only in dense parts, keep beat-aligned notes |
| Meows sound too chipmunk/monstrous | Shift pinned at ±5, melody wider than coverage | Check the `fit_transposition` warning; pick a narrower-range MIDI or add a 4th sample |
| Meows out of key with the backing | Backing rendered from the original `.mid` instead of `*_backing.mid`, or `SAMPLE_ROOTS` guessed wrong | Re-render from the pipeline output; re-measure the roots |
| Song sounds a few semitones "wrong" | Expected — `transpose != 0` | Nothing to fix, it is in key with itself |
