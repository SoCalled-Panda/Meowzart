# PRD: Meowzart

**Platform:** Mobile (Android first, iOS optional) | **Stack:** Flutter + Dart, Flame, flutter_soloud
**Scope target:** Weekend MVP (~2 days), solo developer
**Status:** Draft v2 — scoped down for a weekend build (see §2 cut list)

---

## 1. Overview

Meowzart is a cozy rhythm game where notes rain down four lanes and the player taps them in time. Every correct tap plays a **meow at the pitch of the note**, so the player "performs" the song as a cat choir. Songs are public-domain classical pieces (Vivaldi, Pachelbel, Beethoven, etc.) converted offline from MIDI into note charts.

**One-line pitch:** *Play classical music by meowing. Cozy cats, rainy windows, no stress.*

## 2. Goals and non-goals

### Goals
- A playable, satisfying, well-synced rhythm loop with **2 songs minimum (3 if time allows)** and 3 cats.
- A distinctive hook: player taps become the melody, played in cat meows.
- A cozy, low-stress feel: soft failure, warm visuals, gentle audio.
- A reusable offline MIDI-to-chart pipeline (see `midi_to_chart_pipeline.md`).

### Non-goals (MVP)
- Copyrighted pop songs (licensing risk, noisy audio-to-MIDI).
- Online features: leaderboards, accounts, multiplayer.
- On-device audio analysis or user-imported songs.
- Hold notes, swipe notes, or multi-touch chords.
- In-app purchases and ads.

### Explicit cuts (decided — do not reopen during the weekend)
These were P1/P2 in v1 and are **out** of the MVP build. They stay documented only as post-MVP ideas.

| Cut | Why it is safe to cut |
|---|---|
| Auto latency-calibration screen | Per-song `audio_offset_ms` (dev-tuned) + a manual ±ms slider in the pause menu covers it. Ship the tap-to-calibrate screen as P1. |
| Hard difficulty | Easy/Normal are enough to judge feel. |
| 3 gameplay backgrounds | 1 background, reused. Cheap later. |
| 6 cats / star-gated unlocks | 3 free cats, no unlock economy. |
| Per-cat sprite states (4) → (3) | idle / happy / sleepy. Celebrate reuses `happy` + sparkles drawn in code. |
| Separate Settings screen | Volume + haptics + offset slider live in the pause menu. |
| Splash screen | Logo lives on the main menu. |
| Judgement VFX sprites, rain particles, accessories, daily reward, ambient rain audio, MIDI import | All post-MVP. |

## 3. Target audience

- Casual mobile players (13+), fans of cozy games and cats, ages roughly 15-35.
- Short sessions (2-4 minutes per song), one-handed or two-thumb play.
- Players who are put off by harsh fail states in typical rhythm games.

## 4. Core gameplay loop

1. Pick a cat and a song.
2. Notes fall down 4 lanes toward a hit line.
3. Tap the lane as a note reaches the line. A meow plays at the note's pitch.
4. Build combos, keep the cat's mood up.
5. Finish the song, get 1-3 stars. Replay to beat your best. Repeat.

(There is no unlock economy in the MVP: all 3 cats are free from the start.)

## 5. Gameplay rules

### 5.1 Lanes and input
- 4 lanes, tap anywhere inside a lane's column. Single-touch per lane, simultaneous taps in different lanes are allowed.
- Tap notes only in MVP.

### 5.2 Timing windows (default, editable in config)

| Judgement | Window (ms from perfect) | Score | Cat reaction |
|---|---|---|---|
| Perfect | ±50 | 300 | Tail swish + sparkle |
| Good | ±110 | 100 | Small head bop |
| Miss | beyond ±110 or note passes the line | 0 | Mood drops |

- Tapping with no note in range (a stray tap): silent, **no penalty** (decision: keeps the cozy feel and removes a toggle).
- The player latency offset (from the settings slider) is added to all timing.

### 5.3 Combo and score
- Combo increases on each Perfect/Good, resets on Miss.
- Multiplier: x1 (0-9), x2 (10-24), x3 (25-49), x4 (50+).
- Combo milestones (10, 25, 50, 100) trigger a purr animation and a heart burst.

### 5.4 Soft failure: Mood meter (no game over)
- Mood meter from 0 to 100, starts at 60.
- Perfect +2, Good +1, Miss -6.
- At 0 the cat falls asleep: the song **keeps playing**, the cat naps, scoring is paused for 5 seconds, then the cat wakes at mood 30. Napping caps the star rating at 2 (see 5.5). Mood at 0 never ends the run.

### 5.5 Stars

| Stars | Requirement |
|---|---|
| 1 | Finish the song |
| 2 | Accuracy >= 70% (Perfect + Good over total notes) |
| 3 | Accuracy >= 90% and cat napped 0 times |

Any nap caps the result at 2 stars, so rule 3 is the only path to 3 stars.

## 6. Features

### P0: Must have (weekend MVP)
- Flame game screen: 4 lanes, falling notes, hit line, tap detection.
- Audio-clock-driven sync (song position drives note position).
- Judgement, score, combo, mood meter, results screen with stars.
- Pitch-shifted meow playback per hit, quiet backing track.
- **2 songs** (3rd if the pipeline runs smoothly), JSON charts, 2 difficulties (Easy, Normal).
- 3 selectable cats, **3 sprite states each** (idle, happy, sleepy).
- Main menu (with logo), song select, cat select, results, pause menu.
- Manual latency slider (±ms) in the pause menu; auto-calibration is P1.
- Local save (best score, stars, selected cat, offset, volumes).
- 1 rainy-window background + music-ready UI theme.

### P1: Should have (only after a full playable build exists)
- Tap-to-latency-calibration screen.
- Haptic feedback on hits (toggle).
- Hard difficulty.
- Extra backgrounds, judgement VFX, rain particles, 2-frame idle animation.
- Settings extras (scroll speed, reset progress).

### P2: Post-MVP (do not schedule)
- 3 more cats + star-gated unlocks.
- Accessories (hats, scarves), daily reward, ambient rain/cafe sound.
- "Meowify my own MIDI" import, hold notes, per-cat meow sample sets.

## 7. Screens

1. **Main menu:** logo, Play, Cats, (Calibrate P1).
2. **Song select:** scrollable song cards (cover, title, composer, best stars, difficulty toggle).
3. **Cat select:** cat carousel, 3 cats (locked silhouettes are P2).
4. **Gameplay:** lanes, HUD (score, combo, mood meter, pause), cat companion beside/below lanes.
5. **Pause:** resume, restart, quit, volume + latency offset sliders.
6. **Results:** stars, score, accuracy, max combo, cat celebrating/napping, Retry / Next / Menu.
7. **Calibration (P1):** metronome-like beat, player taps in time, average offset stored.

## 8. Content (MVP)

| Song | Composer | Priority |
|---|---|---|
| Canon in D | Pachelbel | **Ship first** — slow, steady, easy-mode friendly, fast to tune |
| Ode to Joy | Beethoven | **Ship second** — very recognizable melody, simple |
| Spring, Allegro (The Four Seasons) | Vivaldi | Third — dense showpiece, only if the pipeline is already smooth |

The pipeline is automated, so a 3rd song is cheap *only after* the first two are tuned. Do not start Spring before the game is playable end to end.

Optional extras: Für Elise, Gymnopédie No. 1, traditional folk songs.
**Legal note:** compositions are public domain, but individual **MIDI files and sound fonts may carry their own licenses**. Record the source and license of every file in `assets/LICENSES.md`.

## 9. Audio requirements

- Meow samples: 3 CC0/self-recorded meows (low, mid, high), mono, 44.1 kHz, trimmed with no leading silence.
- Pitch shift via playback speed within ±5 semitones of the sample root.
- Backing track: rendered offline from MIDI (fluidsynth + permissive sound font), exported as OGG, mixed at about 30% of meow volume.
- Sync accuracy target: **under 30 ms drift** across a 3-minute song.

## 10. Non-functional requirements

- 60 FPS on mid-range Android (2020+ devices).
- Cold start under 3 seconds.
- Input-to-sound latency as low as the platform allows (SoLoud, low-latency buffer).
- Install size under 50 MB.
- Portrait orientation only.
- Offline only, no permissions requested.

## 11. Success metrics (for a hobby/portfolio release)

- Game is playable end to end without crashes on 2 test devices.
- Average session at least 2 songs.
- Personal QA: sync feels tight at 0 offset and after a manual ±ms tweak, wired and Bluetooth.

## 12. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Audio/visual sync drift | Game feels broken | Drive from audio position, smooth with a stopwatch interpolation, per-song `audio_offset_ms`, manual slider |
| Bad auto-generated charts | Not fun | Density thinning, lane mapping tuned, manual pass per song |
| Meow pitch-shifting sounds bad | Hook fails | Per-song sample roots from the melody's own pitch range, shifts kept ≤ ±5 (see pipeline §6) |
| Scope creep in a weekend | Unfinished | Strict P0 list, explicit cut list in §2, art is placeholder-first |
| MIDI/soundfont license issues | Can't publish | Track licenses, use CC0/public-domain sources |
| Android audio latency variance | Uneven feel | SoLoud + offset slider (auto-calibration is P1) |
| AI art inconsistency | Mismatched look | Shared style prompt, reference images, see `visual_assets.md` |

## 13. Milestones

| Milestone | Target |
|---|---|
| M1: Core loop with a hardcoded chart | Sat midday |
| M2: Judgement, score, combo, mood | Sat evening |
| M3: Converter + **Canon in D** + meow audio | Sun morning |
| M4: Menus, cats, save, offset slider | Sun early afternoon |
| M5: Ode to Joy + art pass + test + APK | Sun evening |

## 14. Decisions (resolved — was "open questions")

- **Name:** Meowzart.
- **Meows per cat:** same 3 samples for all cats in MVP; per-cat samples are P2.
- **Hard difficulty:** P1, after the MVP ships.
- **Stray-tap penalty:** off, permanently (cozy).
- **Calibration:** manual ±ms slider in P0; tap-to-calibrate screen is P1.
- **Star gating / unlocks:** cut. All 3 cats are free.
- **Song order:** Canon → Ode to Joy → Spring.
