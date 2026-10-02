# Full Detail Checklist: Meowzart

Legend: **[P0]** must ship, **[P1]** should, **[P2]** nice. Time estimates assume a comfortable Flutter dev.
Rule: get an ugly-but-playable build first, art comes last (use colored rectangles until then).
**Cut list lives in `PRD.md` §2 — if it is not on this list, it is not this weekend.**

---

## Phase 0: Setup (Fri night or Sat morning, ~1 h)

- [ ] [P0] `flutter create meowzart --platforms=android,ios`
- [ ] [P0] Lock portrait orientation (`SystemChrome.setPreferredOrientations`)
- [ ] [P0] Add dependencies: `flame`, `flutter_soloud`, `flutter_riverpod`, `shared_preferences`, `vibration` (or `haptic_feedback`), `collection`
- [ ] [P0] Create folder structure from `architecture.md`
- [ ] [P0] Declare assets in `pubspec.yaml` (`assets/audio/`, `assets/charts/`, `assets/images/`)
- [ ] [P0] Git repo initialized, `.gitignore`, first commit
- [ ] [P0] Create `assets/LICENSES.md` (source and license for every audio/art/font file)
- [ ] [P0] Bundle the `Fredoka` font (SIL OFL) in `assets/fonts/` — all UI text uses it
- [ ] [P0] Test that a build runs on a **real Android device** (emulators have bad audio latency)
- [ ] [P1] Set app name, package id, and placeholder icon (`flutter_launcher_icons`)

## Phase 1: Core game loop (Sat morning, ~4 h)

### Audio clock and sync
- [ ] [P0] Initialize SoLoud in `AudioService` (`SoLoud.instance.init()`)
- [ ] [P0] Load and play a test backing track
- [ ] [P0] Read playback position (`getPosition(handle)`) into `songTimeMs`
- [ ] [P0] Add stopwatch interpolation between audio position updates (smooth motion)
- [ ] [P0] Apply `latencyOffsetMs` and the chart's `audio_offset_ms` to the song clock (once, in `SongClock`)
- [ ] [P0] 2-second lead-in: the clock starts at −2 s and the audio at 0 (never both this and `lead_in_s`)
- [ ] [P0] Handle app pause/resume: pause the audio and game clock together

### Lanes and notes
- [ ] [P0] `MeowGame extends FlameGame` with 4 lane columns sized to the screen
- [ ] [P0] Draw the hit line (rectangle placeholder)
- [ ] [P0] `NoteComponent`: position computed as `y = hitY - (note.t - songTime) * scrollSpeed`
- [ ] [P0] Spawn notes when `note.t - songTime < lookaheadSeconds`, remove after the miss window
- [ ] [P0] Object pooling or reuse for notes (avoid GC hitches)
- [ ] [P0] Hardcoded 20-note test chart in Dart

### Input and judgement
- [ ] [P0] Multi-touch tap handling per lane (`TapCallbacks` / raw pointer events)
- [ ] [P0] Find the nearest unhit note in the tapped lane within ±110 ms
- [ ] [P0] Judge Perfect (≤50 ms) / Good (≤110 ms) / Miss
- [ ] [P0] Auto-miss notes that pass `t + 110 ms`
- [ ] [P0] Ignore stray taps (silently — no penalty, decided in PRD §5.2)
- [ ] [P0] Judgement popup text ("Perfect!", "Good") near the hit line, rendered with the bundled font

### Scoring and mood
- [ ] [P0] Score, combo, multiplier logic (pure Dart, unit-tested)
- [ ] [P0] Mood meter (start 60, +2/+1/-6, clamp 0-100)
- [ ] [P0] Nap state at mood 0: 5 s scoring pause, wake at 30, count naps
- [ ] [P0] HUD: score, combo, multiplier, mood bar, pause button
- [ ] [P0] End-of-song detection → results data (accuracy, max combo, naps, stars; any nap caps at 2 stars)

## Phase 2: Audio and meows (Sat evening, ~2 h)

- [ ] [P0] Source 3 meow samples (low/mid/high), CC0 or self-recorded, record the license
- [ ] [P0] Trim silence, normalize, export mono WAV/OGG, keep them 150-400 ms long
- [ ] [P0] Measure each sample's pitch (`librosa.pyin` or by ear) → `SAMPLE_ROOTS` in the pipeline
- [ ] [P0] Load meow samples as SoLoud sources
- [ ] [P0] On hit: play the sample with `setRelativePlaySpeed(2^(shift/12))`
- [ ] [P0] Cap simultaneous voices (e.g. 8) and stop the oldest meows if exceeded
- [ ] [P0] Short fade tail on meows to avoid clicks
- [ ] [P0] Miss: silent
- [ ] [P0] Backing track volume at ~30% relative to meows
- [ ] [P1] Separate volume sliders: music vs meows (both live in the pause menu)
- [ ] [P2] Per-cat meow variants

## Phase 3: MIDI to chart pipeline (Sun morning, ~3 h)

Details in `midi_to_chart_pipeline.md`. **Ship order: Canon in D → Ode to Joy → Spring (only if time).**

- [ ] [P0] Set up Python venv, install `pretty_midi`, `mido`, `numpy`, `matplotlib`
- [ ] [P0] Download 2 public-domain MIDIs, log source and license
- [ ] [P0] Script: list tracks with note counts and pitch ranges
- [ ] [P0] Select the melody track (manual override flag per song)
- [ ] [P0] Measure the 3 meow fundamentals → `SAMPLE_ROOTS` (once, for all songs)
- [ ] [P0] `fit_transposition`: move the melody into the samples' coverage window, write `*_backing.mid`
- [ ] [P0] Thin notes by minimum gap per difficulty
- [ ] [P0] Map pitch → lane (quantile-based, not fixed ranges)
- [ ] [P0] Compute meow sample + semitone shift per note (nearest root, no octave folding)
- [ ] [P0] Export `song_id.json` per the schema (`lead_in_s` stays 0)
- [ ] [P0] Render backing audio from `*_backing.mid` (fluidsynth → WAV → OGG), melody stripped, aligned to t=0
- [ ] [P0] Validation script: sorted times, valid lanes, shift histogram, sample spread, density
- [ ] [P0] Visual review of each chart with the matplotlib preview
- [ ] [P0] `ChartRepository` loads JSON and parses into `Chart` / `NoteData`
- [ ] [P1] Ship Easy + Normal only (the pipeline emits Hard for free — don't tune it)
- [ ] [P1] Debug overlay in game: shows song time, note count, current offset

## Phase 4: Menus and meta (Sun afternoon, ~3 h)

- [ ] [P0] Routing: Menu → Song select → Cat select → Game → Results
- [ ] [P0] Song select list built from `songs.json` manifest (code-drawn cards, gradient cover)
- [ ] [P0] Difficulty toggle (Easy / Normal)
- [ ] [P0] Cat select carousel, 3 cats
- [ ] [P0] Cat companion sprite in the game (idle / happy / sleepy)
- [ ] [P0] Results screen with star animation, Retry / Menu
- [ ] [P0] Save: best score, stars per song and difficulty, selected cat, offset, volumes (`shared_preferences`)
- [ ] [P0] Pause menu: Resume, Restart, Quit + music/meow volume sliders + latency offset slider (±100 ms)
- [ ] [P0] 2-frame cat bob (scale/rotate tween on the idle sprite) — no extra art needed
- [ ] [P1] Tap-to-calibration screen (8 beats → median offset)
- [ ] [P1] Haptics on Perfect/Good, toggle in the pause menu
- [ ] [P1] Settings extras: scroll speed, reset progress
- [ ] [P2] Accessories, daily reward, star-gated cats

## Phase 5: Art and polish (Sun afternoon-evening, ~3 h)

Prompts in `visual_assets.md`. **P0 is exactly 19 images — everything else is drawn in code with the Fredoka font.**

- [ ] [P0] Generate style anchor image, lock the style
- [ ] [P0] Emblem (no text) + app icon; the "Meowzart" wordmark is font, not AI
- [ ] [P0] Main menu background
- [ ] [P0] 1 gameplay background
- [ ] [P0] 4 note tiles (one image, 4 colors) + hit line strip
- [ ] [P0] 3 cats × 3 states (idle, happy, sleepy) = 9 sprites
- [ ] [P0] Remove backgrounds (transparent PNG), export at correct sizes, compress
- [ ] [P0] UI in code: buttons, panels, stars `★`, mood bar gradient, judgement text — all font + gradients
- [ ] [P1] Extra backgrounds, cat portraits, judgement VFX, particles, rain overlay
- [ ] [P1] Screen transitions and button press feedback
- [ ] [P2] Ambient rain sound loop, store graphics

## Phase 6: Testing (Sun evening, ~1.5 h)

- [ ] [P0] Play each song fully on a real device
- [ ] [P0] Sync test: check the first, middle, and last 10 notes against audio
- [ ] [P0] Test with wired and Bluetooth headphones, tune the offset slider on both
- [ ] [P0] Test interruptions: incoming call, app backgrounded, screen lock
- [ ] [P0] Test multi-touch with 2 to 3 fingers
- [ ] [P0] Test small and large screens and notches (safe areas)
- [ ] [P0] Profile: FPS ≥ 55 during dense sections, no memory growth when replaying songs
- [ ] [P0] Unit tests: judgement windows, score/combo, mood logic, chart parsing
- [ ] [P1] Second device/OS version test
- [ ] [P1] Colorblind check: tiles differ by shape/icon, not only color
- [ ] [P1] Fix top 5 bugs from playtest

## Phase 7: Release prep (after the weekend)

- [ ] [P0] Build a release APK / AAB (`flutter build apk --release`)
- [ ] [P0] App icon and adaptive icon set
- [ ] [P0] Verify all licenses listed in `LICENSES.md` and an in-app Credits screen
- [ ] [P1] Store listing: screenshots, short/long description, privacy policy (no data collected)
- [ ] [P1] Content rating questionnaire
- [ ] [P1] Internal testing track on Play Console
- [ ] [P2] iOS build and TestFlight

## Definition of done (MVP)

- [ ] A new player can launch, pick a cat and a song, finish the song, see stars, and replay, with no crashes.
- [ ] Two songs playable with visible sync accuracy (Spring is a bonus third).
- [ ] Every audio, art and font asset has a documented license/source.
- [ ] APK installs on a clean device.
