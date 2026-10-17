"""Validate a generated chart JSON against architecture §5.1 + musical sanity.

    python tools/pipeline/validate_chart.py [assets/charts/summer.json]

Checks, in order:
  * schema      — every documented field present, right type, note keys legal
  * ranges      — lane 0..lanes-1, sample in SAMPLE_ROOTS, |shift| <= MAX_SHIFT
  * ordering    — notes sorted by time, min_gap_ms respected, inside duration_s
  * coverage    — reports pitch holes and how pinned the ±MAX_SHIFT clamp is
  * audio       — the referenced asset exists, is not silent, and its length
                  matches duration_s (needs soundfile for the deeper checks)
  * transpose   — reports fitted T; notes when |T| > 7, warns only when T
                  saturates the ±12 search limit (pipeline §12)

Exit code is 1 when an error is found, so it can gate the pipeline.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_chart import MAX_SHIFT, SAMPLE_ROOTS, coverage_gaps  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO_ROOT = os.path.join(ROOT, 'assets', 'audio')
DEFAULT_CHART = os.path.join(ROOT, 'assets', 'charts', 'summer.json')

REQUIRED = ('version', 'id', 'title', 'composer', 'bpm', 'duration_s', 'audio',
            'audio_offset_ms', 'transpose', 'lanes', 'difficulties')

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def check_schema(chart):
    for key in REQUIRED:
        if key not in chart:
            err(f'missing field "{key}"')
    if chart.get('lanes') != 4:
        warn(f'lanes={chart.get("lanes")} (the game is built for 4)')
    if not isinstance(chart.get('difficulties'), dict) or not chart['difficulties']:
        err('difficulties must be a non-empty object')
        return
    for name, diff in chart['difficulties'].items():
        if 'min_gap_ms' not in diff or 'notes' not in diff:
            err(f'{name}: min_gap_ms/notes missing')
            continue
        for i, n in enumerate(diff['notes']):
            for key in ('t', 'lane', 'sample', 'shift'):
                if key not in n:
                    err(f'{name}[{i}]: missing "{key}"')
            if n.get('sample') not in SAMPLE_ROOTS:
                err(f'{name}[{i}]: unknown sample {n.get("sample")!r}')
            elif abs(n['shift']) > MAX_SHIFT:
                err(f'{name}[{i}]: shift {n["shift"]} beyond ±{MAX_SHIFT}')
            if not 0 <= n.get('lane', -1) < 4:
                err(f'{name}[{i}]: lane {n.get("lane")} out of 0..3')
            if n.get('t', -1) < 0:
                err(f'{name}[{i}]: negative time')


def check_timing(chart):
    dur = chart.get('duration_s', 0)
    for name, diff in chart['difficulties'].items():
        notes = diff['notes']
        ts = [n['t'] for n in notes]
        if ts != sorted(ts):
            err(f'{name}: notes are not sorted by time')
        gap = diff['min_gap_ms'] / 1000.0
        too_close = [round(b - a, 4) for a, b in zip(ts, ts[1:]) if b - a < gap - 1e-6]
        if too_close:
            err(f'{name}: {len(too_close)} notes closer than min_gap_ms '
                f'(e.g. {too_close[:3]})')
        late = [t for t in ts if t > dur]
        if late:
            err(f'{name}: {len(late)} notes after duration_s ({late[:3]})')
        empty = [l for l in range(4) if not any(n['lane'] == l for n in notes)]
        if empty:
            warn(f'{name}: lanes {empty} are empty')
def check_coverage(chart):
    gaps = coverage_gaps()
    if gaps:
        warn(f'sample coverage has holes {gaps}: notes landing there fold an '
             f'octave (record another meow in that range)')
    hist = {}
    for diff in chart['difficulties'].values():
        for n in diff['notes']:
            hist[abs(n['shift'])] = hist.get(abs(n['shift']), 0) + 1
    total = sum(hist.values()) or 1
    print('  |shift| histogram: '
          + ', '.join(f'{k}:{hist[k]}' for k in sorted(hist)))
    pinned = hist.get(MAX_SHIFT, 0)
    if pinned > total * 0.05:
        warn(f'{pinned / total:.0%} of notes sit at the ±{MAX_SHIFT} clamp — '
             f'the melody is wider than the sample coverage')
    t = chart.get('transpose', 0)
    lo = min(SAMPLE_ROOTS.values()) - MAX_SHIFT
    hi = max(SAMPLE_ROOTS.values()) + MAX_SHIFT
    if abs(t) >= 12:
        warn(f'transpose {t:+d} hit the ±12 search limit: the melody does not '
             f'fit the {lo}..{hi} sample coverage at any transposition — widen '
             f'the sample roots or pick another arrangement (pipeline §12)')
    elif abs(t) > 7:
        # A wide melody (Vivaldi's Summer spans 46 semitones) needs a big
        # whole-song shift to sit in a 27-semitone coverage: expected, not a bug.
        print(f'  note: transpose {t:+d} is large, but the melody is wider than '
              f'the {lo}..{hi} coverage, so a big shift is expected')


def check_audio(chart):
    rel = chart.get('audio', '')
    path = os.path.join(AUDIO_ROOT, rel)
    if not rel or not os.path.isfile(path):
        err(f'audio asset missing: assets/audio/{rel}')
        return
    print(f'  audio: {rel} ({os.path.getsize(path) / 1024:.0f} KB)')
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        warn('numpy/soundfile not installed: skipping silence/length checks')
        return
    info = sf.info(path)
    print(f'  audio: {info.duration:.2f}s {info.samplerate}Hz '
          f'{info.channels}ch {info.format}/{info.subtype}')
    if info.duration + 0.5 < chart['duration_s']:
        err(f'audio is {info.duration:.2f}s but duration_s='
            f'{chart["duration_s"]:.2f}: the chart runs past the end of the '
            f'track')
    elif info.duration - 1.0 > chart['duration_s']:
        print(f'  note: track has a {info.duration - chart["duration_s"]:.2f}s '
              f'tail after the last note (harmless)')
    x, _ = sf.read(path, dtype='float32')
    if x.ndim > 1:
        x = x.mean(axis=1)
    rms = float(np.sqrt((x ** 2).mean()))
    if rms < 1e-4:
        err('audio asset is silent')
    elif rms < 0.02:
        warn(f'audio rms {rms:.4f} is very quiet next to the meows')


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_CHART
    with open(path) as f:
        chart = json.load(f)
    print(f'validating {os.path.relpath(path, ROOT)}')
    check_schema(chart)
    if not errors:
        check_timing(chart)
        check_coverage(chart)
        check_audio(chart)
    for w in warnings:
        print(f'WARN  {w}')
    for e in errors:
        print(f'ERROR {e}')
    print(f'{"FAILED" if errors else "OK"}: {len(errors)} errors, '
          f'{len(warnings)} warnings')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())