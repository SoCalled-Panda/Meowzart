# Full Detail Checklist: Meowzart

Legend: **[P0]** must ship, **[P1]** should, **[P2]** nice. Time estimates assume a comfortable Flutter dev.
Rule: get an ugly-but-playable build first, art comes last (use colored rectangles until then).
**Cut list lives in `PRD.md` §2 — if it is not on this list, it is not this weekend.**

Status markers: **[x]** done · **[~]** partial / needs device verification · **[ ]** not started · **[!]** open risk

---

## Status snapshot (2026-10-02)

- **[x] `flutter analyze`: 0 issues. `flutter test`: 52 tests green** — unit (judge, score, mood, stars, chart parse), asset integrity (manifest, chart playability, WAV/OGG bytes, licence rows), UI flow (menu → songs → partner → difficulty against the real chart; run screen on the silent-song fallback with a dead audio engine).
- **[x] Pipeline green:** `prep_meows.py` → `measure_meows.py` → `make_chart.py` → `validate_chart.py` = **0 errors, 0 warnings**. Summer: T = −8, 100 octave folds, 0 clamped, coverage 49..75 no holes, all shifts within ±5.
- **[x] Meow sources:** five ElevenLabs takes shipped in `assets/audio/meows/`, licences + measured roots in `assets/LICENSES.md`: `low` 187.5 Hz = MIDI 54 · `lowMid` 196.7 = 55 · `mid` 315.8 = 63 · `midHigh` 328.8 = 64 · `high` 461.5 = 70. Pipeline and game now consume **all five** (Workstream B done): `SAMPLE_ROOTS` = 54/55/63/64/70, chart regenerated, every sample used on both difficulties.
- **[!] Open P0s:** real-device smoke test, first code commit (git has only the docs commit f0b0acd — **lib/, test/, assets/, tools/ are untracked**, deletions are permanent), Fredoka font, all of Phase 5 art, persistence (Workstream D).

### Workstreams in flight

| # | Workstream | State | Next step |
|---|---|---|---|
| A | Real-device smoke test (audio latency, taps, DFJK) | [~] smoke test passed 2026-10-02 | APK built (Aliyun mirrors first) + installed on SM-A145F (Android 14): menu → songs → cat select → loader (553 notes · 3:13) → gameplay → pause all verified, input→meow audio active in logcat, no crashes. **Remaining:** tune `latencyOffsetMs` by ear on the pause slider + verify sync at 10 checkpoints |
| B | 5-pitch meow expansion (pipeline + game use all five) | [x] done 2026-10-02 | `MeowSample` + `_meowAssets` + prep/measure/`SAMPLE_ROOTS` extended to 5 (54/55/63/64/70), two new WAVs pre-p'd, files renamed `low mid.mp3`→`lowMid.mp3` / `mid high.mp3`→`midHigh.mp3`, chart regenerated with all 5 samples used, tests + docs synced |
| C | Licensing | [~] meows + 2026-10-03 UI art logged (art tool/date still to record); ElevenLabs plan terms, MIDI transcription source, font pending | Log `midi/vivaldi-summer-piano.mid` source URL + licence; fill tool + date on the new art rows; font in Phase 5 |
| D | Persistence | [ ] | `shared_preferences` is installed but unused: best score, stars, selected cat, volumes, offset |
| E | Git hygiene | [~] repo + `.gitignore` + one docs commit | First commit of code + assets; the former "stray" takes `low mid.mp3` / `mid high.mp3` are now intentional (Workstream B), not strays |

---

## Phase 0: Setup (Fri night or Sat morning, ~1 h)

- [x] [P0] `flutter create meowzart --platforms=android,ios` (android/ and ios/ exist)
- [x] [P0] Lock portrait orientation (`SystemChrome.setPreferredOrientations` in `main.dart`)
- [x] [P0] Add dependencies: `flame`, `flutter_soloud`, `flutter_riverpod`, `shared_preferences`, `vibration`, `collection` (all in `pubspec.yaml`)
- [x] [P0] Create folder structure from `architecture.md`
- [x] [P0] Declare assets in `pubspec.yaml` (meows, songs, sfx, charts, images, LICENSES.md)
- [~] [P0] Git repo initialized, `.gitignore`, first commit — repo + ignore exist, but only the docs commit landed; **code/assets still untracked**
- [x] [P0] Create `assets/LICENSES.md` — one literal row per file, enforced by `test/assets_test.dart`; meows record ElevenLabs provenance
- [ ] [P0] Bundle the `Fredoka` font (SIL OFL) in `assets/fonts/` — pubspec entry is stubbed as a comment, file missing
- [ ] [P0] Test that a build runs on a **real Android device** (emulators have bad audio latency) — Workstream A
- [ ] [P1] Set app name, package id, and placeholder icon (`flutter_launcher_icons`)

## Phase 1: Core game loop (Sat morning, ~4 h)

### Audio clock and sync
- [x] [P0] Initialize SoLoud in `AudioService` (`ensureReady`/`init`, silent-song fallback when the engine or asset is unavailable — proven by test)
- [x] [P0] Load and play a test backing track (`startSong`)
- [x] [P0] Read playback position (`getPosition`) into `songTimeMs` (`pollPosition`, falls back to last good value)
- [x] [P0] Stopwatch interpolation between audio position updates (`SongClock.now`, re-anchors only past `kMaxClockDriftS`)
- [x] [P0] Apply `latencyOffsetMs` and the chart's `audio_offset_ms` once, in `SongClock`
- [x] [P0] 2-second lead-in: clock starts at −2 s, audio at 0 (never both this and `lead_in_s`)
- [x] [P0] Handle app pause/resume: `didChangeAppLifecycleState` → pause sheet; clock + audio stop together

### Lanes and notes
- [x] [P0] `MeowGame extends FlameGame` with 4 lane columns sized to the screen
- [x] [P0] Draw the hit line (rectangle placeholder)
- [x] [P0] Note position `y = hitY − (note.t − songTime) × scrollSpeed` (`lane_components.dart`)
- [x] [P0] Spawn notes inside the lookahead, remove past the miss window
- [~] [P0] Object pooling or reuse for notes — no pool found; notes are created/disposed per event, verify GC hitches when profiling (Phase 6)
- [x] [P0] Hardcoded 20-note test chart — superseded by the real chart pipeline

### Input and judgement
- [x] [P0] Multi-touch tap handling per lane (`TapCallbacks` / `onTapDown`) — desktop taps verified; multi-finger on device still Phase 6
- [x] [P0] Nearest unhit note in the tapped lane within ±110 ms (`judge.dart`)
- [x] [P0] Judge Perfect (≤50 ms) / Good (≤110 ms) / Miss — unit-tested
- [x] [P0] Auto-miss notes past `t + 110 ms`
- [x] [P0] Ignore stray taps silently (PRD §5.2)
- [x] [P0] Judgement popup text in the HUD (`HudState.judgement`)

### Scoring and mood
- [x] [P0] Score, combo, multiplier logic (pure Dart, unit-tested: `score_keeper_test.dart`)
- [x] [P0] Mood meter (start 60, +2/+1/−6, clamp 0–100) — `mood_meter_test.dart`
- [x] [P0] Nap state at mood 0: 5 s scoring pause, wake at 30, count naps — tested
- [x] [P0] HUD: score, combo, multiplier, mood bar, pause button (`HudBar`)
- [x] [P0] End-of-song detection → results data (accuracy, max combo, naps, stars; any nap caps at 2 stars) — `star_rating_test.dart`, `results_screen.dart`

## Phase 2: Audio and meows (Sat evening, ~2 h)

- [x] [P0] Source meow samples, record the license — five ElevenLabs takes (`low`, `lowMid`, `mid`, `midHigh`, `high`), all logged in `assets/LICENSES.md`; pipeline and game consume all five (Workstream B done)
- [x] [P0] Trim silence, normalize, export mono WAV, keep 150–400 ms (`prep_meows.py`: −40 dBFS gate, loudest-window crop, 0.45 s cap, 30 ms fades, −1 dBFS peak)
- [x] [P0] Measure each sample's pitch → `SAMPLE_ROOTS` (`measure_meows.py`: median over loud inlier frames with octave-outlier rejection; 54/55/63/64/70, source vs shipped <0.5 st apart)
- [x] [P0] Load meow samples as SoLoud sources (WAV first, MP3 fallback via `_meowAssets`/`_loadFirstAvailable`)
- [x] [P0] On hit: play sample with `setRelativePlaySpeed(2^(shift/12))` (`playMeow`; validator caps |shift| ≤ 5)
- [x] [P0] Cap simultaneous voices (`_maxVoices = 32` → `setMaxActiveVoiceCount`)
- [x] [P0] Short fade tail on meows to avoid clicks (fades in `prep_meows.py`)
- [x] [P0] Miss: silent
- [~] [P0] Backing track volume below meows — default 0.6; PRD asked ~30 %, tune on device (Workstream A)
- [x] [P0] Separate volume sliders: music vs meows, live in the pause menu (`PauseMenuSheet`, plus latency slider)
- [ ] [P2] Per-cat meow variants

## Phase 3: MIDI to chart pipeline (Sun morning, ~3 h)

Details in `midi_to_chart_pipeline.md`. Note: ship order in practice was **Summer (Presto) first** — Canon/Ode/Spring not started (check PRD §2 cut list).

- [x] [P0] Set up Python venv, install `pretty_midi`, `mido`, `numpy`, `matplotlib` (scripts run clean)
- [~] [P0] Download public-domain MIDIs, log source and license — one transcription shipped (`midi/vivaldi-summer-piano.mid`); **source URL + licence still unlogged (Workstream C)**
- [x] [P0] Script: list tracks with note counts and pitch ranges (`make_chart.py` report)
- [x] [P0] Select the melody track (manual override flag per song)
- [x] [P0] Measure the meow fundamentals → `SAMPLE_ROOTS` (once, for all songs; `measure_meows.py`)
- [x] [P0] `fit_transposition`: move melody into the samples' coverage, write `*_backing.mid` (T = −8, folds 100, clamped 0)
- [x] [P0] Thin notes by minimum gap per difficulty (easy 375 ms / normal 250 ms)
- [x] [P0] Map pitch → lane (quantile-based, not fixed ranges; all 4 lanes used on both difficulties)
- [x] [P0] Compute meow sample + semitone shift per note (nearest root; **octave folding IS applied**, validator enforces |shift| ≤ 5 — original "no octave folding" was revised, see pipeline doc)
- [x] [P0] Export `song_id.json` per the schema (`lead_in_s` stays 0)
- [x] [P0] Render backing audio from `*_backing.mid` — in practice an additive synth (`synth_audio.py`/`render_backing.py`) → WAV → OGG, melody stripped, aligned to t=0 (not fluidsynth)
- [x] [P0] Validation script: sorted times, valid lanes, shift histogram, sample spread, density (`validate_chart.py` — currently 0 errors, 0 warnings)
- [~] [P0] Visual review of each chart with the matplotlib preview — console stats only; **no preview script in `tools/pipeline/` yet**
- [x] [P0] `ChartRepository` loads JSON and parses into `Chart` / `NoteData` (tests; decodes inline, not via `loadString`, so widget tests don't deadlock)
- [x] [P1] Ship Easy + Normal only (pipeline emits Hard for free — don't tune it)
- [ ] [P1] Debug overlay in game: song time, note count, current offset

## Phase 4: Menus and meta (Sun afternoon, ~3 h)

- [x] [P0] Routing: Menu → Song select → Cat select → Game → Results (widget-tested end to end)
- [x] [P0] Song select list built from `songs.json` (code-drawn gradient cards)
- [x] [P0] Difficulty toggle (Easy / Normal) in the chart loader with live note counts
- [~] [P0] Cat select, 3 cats — list rows, not a carousel
- [~] [P0] Cat companion in the game — HUD shows a `Cat`/`Zzz` text placeholder; no sprite yet
- [~] [P0] Results screen with Retry / Menu — screen works; **star animation not built**
- [ ] [P0] Save: best score, stars per song and difficulty, selected cat, offset, volumes (`shared_preferences` — installed, unused)
- [x] [P0] Pause menu: Resume, Restart, Quit to songs/menu + music/meow volume sliders + latency offset slider (±100 ms)
- [ ] [P0] 2-frame cat bob (scale/rotate tween) — blocked on sprite art
- [ ] [P1] Tap-to-calibration screen (8 beats → median offset)
- [ ] [P1] Haptics on Perfect/Good — `vibration` dependency installed, not wired
- [ ] [P1] Settings extras: scroll speed, reset progress
- [ ] [P2] Accessories, daily reward, star-gated cats

## Phase 5: Art and polish (Sun afternoon-evening, ~3 h)

Prompts in `visual_assets.md`. **P0 is exactly 19 images — everything else is drawn in code with the Fredoka font.** All placeholder art today (UNVERIFIED rows in `LICENSES.md`).

- [ ] [P0] Generate style anchor image, lock the style
- [~] [P0] Emblem (no text) + app icon; the "Meowzart" wordmark is font, not AI — real app icon wired 2026-10-03 (`export_ui_art.py` → `mipmap-*/ic_launcher.png`); emblem still placeholder
- [ ] [P0] Main menu background
- [ ] [P0] 1 gameplay background
- [~] [P0] 4 note tiles (one image, 4 colors) + hit line strip — placeholder sheet exists (`slice_sprites.py` output), needs real art
- [~] [P0] 3 cats × 3 states (idle, happy, sleepy) = 9 sprites — placeholder PNGs only
- [ ] [P0] Remove backgrounds (transparent PNG), export at correct sizes, compress
- [x] [P0] UI in code: buttons, panels, mood bar gradient, judgement text (`theme.dart`); stars + the 8 game icons now use the real pixel art (2026-10-03)
- [~] [P0] UI art drop 2026-10-03: 8 icons (play/pause/gear/home/retry/speaker/waves×2), star slots, song-select background, menu hero wired via `export_ui_art.py`; still staged for later: hit line + lane guides, mood meter, panels/cards, calibration art, Pachelbel cover (all in `assets/`, unsliced)
- [ ] [P1] Extra backgrounds, cat portraits, judgement VFX, particles, rain overlay
- [ ] [P1] Screen transitions and button press feedback
- [ ] [P2] Ambient rain sound loop, store graphics

## Phase 6: Testing (Sun evening, ~1.5 h)

- [ ] [P0] Play each song fully on a real Android device — Workstream A
- [ ] [P0] Sync test: check the first, middle, and last 10 notes against audio
- [ ] [P0] Test with wired and Bluetooth headphones, tune the offset slider on both
- [ ] [P0] Test interruptions: incoming call, app backgrounded, screen lock (code path exists via lifecycle → pause sheet; device pass pending)
- [ ] [P0] Test multi-touch with 2 to 3 fingers (per-lane `onTapDown` implemented; device pass pending)
- [ ] [P0] Test small and large screens and notches — `SafeArea` used in menu/game/pause; device pass pending
- [ ] [P0] Profile: FPS ≥ 55 during dense sections, no memory growth when replaying songs (also settles the pooling question)
- [x] [P0] Unit tests: judgement windows, score/combo, mood logic, chart parsing — **52 green**, plus asset-integrity (`assets_test.dart`) and UI-flow (`app_flow_test.dart`) suites
- [ ] [P1] Second device/OS version test
- [ ] [P1] Colorblind check: tiles differ by shape/icon, not only color
- [ ] [P1] Fix top 5 bugs from playtest (no playtest yet)

## Phase 7: Release prep (after the weekend)

- [ ] [P0] Build a release APK / AAB (`flutter build apk --release`)
- [~] [P0] App icon and adaptive icon set — legacy `mipmap-*` icons replaced with real art 2026-10-03; adaptive-icon layers still pending
- [~] [P0] Verify all licenses listed in `LICENSES.md` and an in-app Credits screen — rows exist and are test-enforced; ElevenLabs plan terms + font + art + MIDI source still pending (Workstream C); **no Credits screen yet**
- [ ] [P1] Store listing: screenshots, short/long description, privacy policy (no data collected)
- [ ] [P1] Content rating questionnaire
- [ ] [P1] Internal testing track on Play Console
- [ ] [P2] iOS build and TestFlight

## Definition of done (MVP)

- [~] A new player can launch, pick a cat and a song, finish the song, see stars, and replay, with no crashes — **automated flow test passes; real-device run pending (A)**
- [ ] Two songs playable with visible sync accuracy — **only Summer ships today; second song not started (check PRD §2 cut list)**
- [x] Every audio asset has a documented license/source (font/art/MIDI-source entries tracked under Pending in `LICENSES.md`)
- [ ] APK installs on a clean device

---

## How to re-verify status from scratch

```bash
flutter analyze                      # expect 0 issues
flutter test                         # expect 52 tests, all green
python tools/pipeline/measure_meows.py
python tools/pipeline/prep_meows.py  # only when meow sources change
python tools/pipeline/make_chart.py && python tools/pipeline/validate_chart.py
```




