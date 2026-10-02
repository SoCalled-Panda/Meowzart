# Visual Assets and AI Image Prompts: Meowzart

Prompts are written for general text-to-image tools (Midjourney, DALL·E / GPT-Image, Flux, Stable Diffusion, Ideogram, etc.). Copy the **Style Anchor** into every prompt, then add the asset-specific text.

---

## 0. How to use this file

1. **First, do the non-AI work (30 min):** bundle the `Fredoka` font and build the UI in code. You can ship a full game with zero images except placeholders.
2. Generate the **style anchor** image next (Section 1). Pick the best result and use it as a **reference image** (`--sref` in Midjourney, image reference in GPT-Image/Flux) for every other asset. That is how you get a consistent look.
3. Generate assets at a large size, then downscale to the target size in the spec table.
4. For sprites: ask for a **plain flat background**, then remove it (`rembg` CLI: `rembg p in/ out/`, or Photopea). Export PNG with transparency. **Use a background color that contrasts with the subject** — a white cat on a cream background will lose its edges. Mochi (white) → "plain solid mid-grey background"; Miso (orange) and Luna (black) → "plain solid light cream background".
5. Keep a folder per category and follow the naming in the table below.
6. For consistent cats, generate one **character sheet** per cat first, then use it as a reference for each pose.
7. **Legal:** check your tool's commercial-use terms. Keep prompt + tool + date in `assets/LICENSES.md`.

### Palette (use across all assets)

| Role | Hex | Name |
|---|---|---|
| Background deep | `#2B2440` | Night plum |
| Background mid | `#4A3B6B` | Dusk violet |
| Warm light | `#FFC98B` | Lamp amber |
| Cream | `#FFF4E3` | Milk cream |
| Accent pink | `#FF8FB1` | Paw pink |
| Accent teal | `#7ADCC9` | Mint |
| Accent yellow | `#FFE27A` | Butter |
| Lane blue | `#8FB8FF` | Rain blue |

### Global style anchor (paste into every prompt)

```
cozy hand-painted 2D game art, soft rounded shapes, gentle gradients, warm lamp lighting,
pastel and muted colors with a plum-violet night palette and amber highlights,
kawaii-inspired but polished, clean vector-like edges, subtle paper-grain texture,
flat 2D (no 3D render), storybook charm, mobile game asset, high quality
```

### Global negative prompt (paste into every negative field or "avoid" line)

```
text, letters, watermark, signature, logo (unless requested), realistic photo, 3D render,
harsh shadows, dark or scary mood, blood, extra limbs, extra tails, extra ears, deformed paws,
blurry, low resolution, cluttered composition, oversaturated neon
```

> **Conflict warning:** this negative prompt bans letters, so it will fight any prompt asking for words ("Perfect!", "Zzz"). **Do not generate lettering as an image at all** — render every word and number with a bundled font in Flutter (see §14). This is faster, sharper, and impossible to misspell.

### Two rules that save the most time

1. **Generate only 19 images for the MVP** (see the P0 rows in §2). Everything else in this file is a P1/P2 idea, not a task.
2. **Bundle a font instead of generating UI.** Add `Fredoka` (SIL OFL — record it in `LICENSES.md`) under `assets/fonts/`. Buttons, panels, stars, the mood bar, judgement words, numbers and the logo wordmark are then all drawn in code: a `Container` with a 24 px radius, a gradient, and text. Crisp at every resolution, free, and perfectly on-palette.

---

## 1. Style anchor image (do this first)

**File:** `_reference/style_anchor.png` | **Size:** 1536×1536

```
A cozy scene: a small round orange tabby cat curled on a plum-colored cushion next to a rainy window at night,
warm amber lamp glowing, tiny floating music notes, soft raindrops on the glass.
[GLOBAL STYLE ANCHOR]
```

---

## 2. Asset list, priorities and specs

**P0 = generate it (19 images total). P1 = after the build works. P2 = idea only, skip.**
Anything not marked P0 should be drawn in code with the bundled font and the palette.

| ID | Asset | Pri | Count | Final size (px) | File |
|---|---|---|---|---|---|
| A0 | Style anchor (reference only) | P0 | 1 | 1536×1536 | `_reference/style_anchor.png` |
| A1 | Logo: cat emblem, **no text** (wordmark is a font) | P0 | 1 | 1024×1024 | `ui/emblem.png` |
| A2 | App icon: foreground subject only | P0 | 1 | 1024×1024 | `icon/app_icon.png` |
| A4 | Main menu background | P0 | 1 | 1080×1920 | `backgrounds/bg_menu.png` |
| A6 | Gameplay background (one, reused by all songs) | P0 | 1 | 1080×1920 | `backgrounds/bg_bedroom.png` |
| A7 | Note tiles (shape + color per lane) | P0 | 4 | 256×256 | `tiles/tile_0..3.png` |
| A8 | Hit line strip (lane strips drawn in code) | P0 | 1 | 1080×160 | `tiles/hitline.png` |
| A9 | Cats × 3 × **3 states** (idle, happy, sleepy) | P0 | 9 | 512×512 | `cats/{cat}_{state}.png` |
| A5 | Song select background | P1 | 1 | 1080×1920 | `backgrounds/bg_select.png` |
| A6b | Extra gameplay backgrounds | P1 | 2 | 1080×1920 | `backgrounds/bg_cafe.png`, `bg_attic.png` |
| A10 | Cat portraits for the select screen (crop the idle sprite instead if lazy) | P1 | 3 | 512×512 | `cats/{cat}_portrait.png` |
| A12 | Judgement burst VFX (or draw a radial gradient in code) | P1 | 2 | 256×256 | `vfx/perfect.png`, `good.png` |
| A13 | Particles: music note, heart, sparkle, raindrop | P1 | 4 | 64×64 | `vfx/*.png` |
| A18 | Song cover art | P1 | 3 | 512×512 | `ui/cover_{song}.png` |
| A19 | Calibration illustration | P1 | 1 | 1024×1024 | `ui/calibrate.png` |
| A21 | Store feature graphic + screenshot frames | P1 | 1 | 1024×500 | `store/feature.png` |
| A3 | Splash screen | P2 | — | — | use the menu background |
| A11 | Locked cat silhouette (all cats are free now) | P2 | — | — | `ColorFilter` in code if ever needed |
| A14 | Buttons, panels, icons | P2 | — | — | **draw in code** + font |
| A15 | Stars | P2 | — | — | font glyph `★` |
| A16 | Mood meter | P2 | — | — | **draw in code**: gradient bar + font |
| A17 | Results elements (ribbon, confetti) | P2 | — | — | code + the celebrate sprite |
| A20 | Accessories | P2 | — | — | skip |

**Total P0 generation work:** 1 style anchor + 1 emblem + 1 icon + 2 backgrounds + 4 tiles + 1 hit line + 9 cat sprites = **19 images**, of which 9 are reference-based variants of 3 character sheets.

### Generated-on-black assets need additive blending

Anything asked for "on flat black background" that glows (hit line, sparkles, bursts, rain streaks) must be drawn with `BlendMode.plus` in Flame, otherwise you get a black rectangle. Assets that are solid and opaque (tiles, cats) should be extracted to transparency normally.

---

## 3. Logo (A1) — emblem + font, not generated lettering

Do **not** ask an AI for the word "Meowzart". Six letters where three are unusual in sequence is exactly the case where generators produce "Meowzarl" / "Meorzart", and the global negative prompt bans text anyway. Compose the logo in code (or Figma) from two parts:

1. **Emblem image (generate this):**
```
Round emblem badge of a cute cat face wearing small headphones, a tiny music note and a paw print
orbiting it, cream and amber on a deep plum circle, thick clean outline, centered,
on a flat solid dark plum background, app logo mark, [GLOBAL STYLE ANCHOR]
```
**Negative:** `text, letters, words, watermark, realistic, 3D`

2. **Wordmark:** the string `Meowzart` in *Fredoka SemiBold* (or *Baloo 2*), cream `#FFF4E3` with a 6 px plum `#2B2440` outline and a soft amber glow. Put the emblem where the "o" would go, or above the word.

Fallback (only if you really want an AI-drawn logo): generate a **text-free** emblem and add the text in Figma/Canva.

## 4. App icon (A2)

```
Mobile app icon foreground: a cute round orange tabby cat face with big shiny eyes and a happy open
mouth mid-meow, tiny music note floating from its mouth, centered subject only, bold simple shapes
readable at small size, soft amber glow behind it, [GLOBAL STYLE ANCHOR]
```
**Notes:**
- Generate the **foreground subject on a plain plum background**, then let `flutter_launcher_icons` build the adaptive icon and do the masking. Do not bake a rounded square into the image — the Play Store wants a full-bleed square with its own mask.
- Keep the subject inside the central 66% (Android adaptive-icon safe zone). No text.
- No version of the icon should contain the wordmark.

## 5. Splash screen (A3) — cut

Not needed: launch straight into the main menu with the logo on the menu background. Skip.

## 6. Main menu background (A4)

```
Vertical 9:16 mobile game menu background: a cozy bedroom by a large rainy window at night,
warm amber desk lamp, a stack of books, a plant, a cushion bed, string lights, soft rain streaks on the glass,
city lights blurred in the distance, the bottom third has a calm empty area for buttons,
top third has clear space for a logo, no characters, [GLOBAL STYLE ANCHOR], portrait
```

## 7. Song select background (A5) — P1

For the MVP, reuse `bg_menu.png` with a dark scrim (`#2B2440` at 60% opacity) behind the cards.

```
Vertical 9:16 background: a cozy record-shop or library corner at dusk, wooden shelves with vinyl records and books,
warm hanging lamps, soft bokeh lights, muted colors so foreground cards remain readable, no characters,
low contrast and slightly blurred, [GLOBAL STYLE ANCHOR], portrait
```

## 8. Gameplay backgrounds (A6)

Key rule: the **center 60% (where lanes go) must be low contrast and uncluttered**. Details go on the edges. Generate slightly darker and blurrier than looks good in isolation.

**Only 8a is P0.** 8b and 8c are P1 — one background for every song is fine.

### 8a. Rainy bedroom (default, P0)
```
Vertical 9:16 game background, view of a cozy attic bedroom at night, large window with rain running down the glass
on the left, warm amber lamp glow, plum wooden floor, soft rug in the center bottom, bookshelf edges on the right,
center area is calm, dark, and low-contrast with a subtle vignette, no characters, no bright objects in the center,
[GLOBAL STYLE ANCHOR], portrait
```

### 8b. Cozy café (P1)
```
Vertical 9:16 game background, cozy late-night café interior, warm hanging lamps, steaming cups on a wooden counter
at the edges, rain on a large window, chalkboard menu blurred, muted teal and amber tones,
center is dark, soft, and uncluttered for gameplay readability, no characters, [GLOBAL STYLE ANCHOR], portrait
```

### 8c. Starry attic / rooftop (P1)
```
Vertical 9:16 game background, a quiet rooftop at night with a tiny cat-sized tent and string lights,
huge soft moon and pastel stars, gentle clouds, blue and violet palette with amber accents,
center area is dark and calm for gameplay readability, no characters, [GLOBAL STYLE ANCHOR], portrait
```

**Animated layers (P1):** generate a separate transparent **rain streak overlay** (`vfx/rain_overlay.png`, tileable vertically) and animate it with Flame.
```
Seamless vertically tileable overlay of thin soft diagonal rain streaks on a fully transparent background,
pale blue-white, low opacity, minimal, no other elements
```
(If the generator can't output transparency, render on solid black and use additive/screen blending in-game.)

---

## 9. Note tiles (A7)

Tiles must be readable by **shape + color**, not color alone (accessibility). Each lane has its own shape/color. Use a paw-bean motif so notes feel like cat elements.

**Common prompt base:**
```
Single rhythm-game note tile icon, rounded square tile with a soft glossy candy finish, centered small [MOTIF] emblem
in cream, thin lighter rim highlight, no drop shadow, no background gradient, flat solid dark background for easy
extraction, game UI asset, [GLOBAL STYLE ANCHOR]
```

| Lane | Color | [MOTIF] | Filename |
|---|---|---|---|
| 0 | Paw pink `#FF8FB1` | paw print | `tile_0.png` |
| 1 | Mint `#7ADCC9` | fish | `tile_1.png` |
| 2 | Butter `#FFE27A` | yarn ball | `tile_2.png` |
| 3 | Rain blue `#8FB8FF` | cat head (two ears) | `tile_3.png` |

Put the hex code **and** the color name in every tile prompt — models follow hex codes surprisingly well and it keeps the four tiles in one family. Generate all four in a single image ("a row of four rhythm-game note tiles, pink, mint, butter, blue...") if the tool supports it: that is the cheapest way to guarantee they match.

**Example (lane 0):**
```
Single rhythm-game note tile icon, rounded square tile in soft paw-pink (#FF8FB1) with a glossy candy finish,
a cream paw print emblem in the center, thin lighter rim highlight, no drop shadow,
flat solid dark background, game UI asset, [GLOBAL STYLE ANCHOR]
```

**Do not ask for a drop shadow** — the tile is extracted to transparency and drawn over a dark background, so a baked shadow shows up as a dirty halo. Add the glow in code (`BoxShadow` / Flame glow) instead.

**Extras (P1):**
- **Tile hit-flash** (`tile_hit.png`): `white-gold radial burst star, sparkle, on flat black background, glow, game VFX`
- **Tile missed:** draw in code — tint the tile `#8E86A8` at 60% opacity, no image needed.

## 10. Hit line and lane guides (A8)

**Hit line (P0):**
```
Horizontal glowing strip for a rhythm game hit line, soft cream-amber light beam with tiny paw print marks
evenly spaced along it, fading edges, on flat black background, game UI, [GLOBAL STYLE ANCHOR]
```
Draw with `BlendMode.plus` in Flame (it is generated on black).

**Lane target markers (4 pads at the hit line, P1):**
```
Set of four round tap-target pads for a rhythm game, each a soft circular cushion ring with a faint paw outline
in [pink / mint / butter / blue], glowing softly, viewed from above, on flat black background,
game UI, [GLOBAL STYLE ANCHOR]
```
Generate each color separately for consistency.

**Lane background strips and tap pads: draw in code.** A `Container` with 30-40% opacity dusk violet, a 1 px lighter border, and a rounded top is indistinguishable from a generated strip and scales to every screen size. Same for the four tap pads: a `DecoratedBox` circle with a border in the lane color.

---

## 11. Cats (A9, A10, A11)

### 11.1 Cat roster

| ID | Name | Look | Personality | Status |
|---|---|---|---|---|
| `miso` | Miso | Round orange tabby, green eyes | Cheerful, default | **P0** |
| `luna` | Luna | Slim black cat, big yellow eyes | Calm, mysterious | **P0** |
| `mochi` | Mochi | Fluffy white cat, blue eyes, pink nose | Sweet, sleepy | **P0** |
| `biscuit` | Biscuit | Calico with patches | Playful | P2 |
| `pepper` | Pepper | Blue-grey tabby, amber eyes | Elegant | P2 |
| `sir_whiskers` | Sir Whiskers | Tuxedo cat with bow tie | Fancy conductor | P2 |

No star costs: all three MVP cats are free.

### 11.2 Character sheet (generate one per cat FIRST, use as reference)

```
Character design sheet of a cute chibi cat named Miso, [DESCRIPTION], round body, big head, large sparkly eyes,
small triangle ears, short legs, fluffy curved tail, sitting pose on the left, plus front view, side view,
and three face expressions (happy, sleepy, surprised), on [BG],
consistent proportions, clean outlines, [GLOBAL STYLE ANCHOR]
```
`[BG]` = `plain solid light cream background` for Miso and Luna, `plain solid mid-grey background` for Mochi (a white cat disappears into a cream one during cutout).

**Descriptions to insert:**
- Miso: `orange tabby with cream belly, darker orange stripes, green eyes`
- Luna: `black cat with a tiny white star-shaped chest patch, huge yellow eyes, slim`
- Mochi: `fluffy white cat like a rice cake, blue eyes, small pink nose, pink inner ears, extra round`
- Biscuit (P2): `calico cat with orange, black and white patches, one green and one amber eye`
- Pepper (P2): `blue-grey tabby with white paws and muzzle, amber eyes, elegant slim tail`
- Sir Whiskers (P2): `black and white tuxedo cat with a small red bow tie, white chest and paws, dignified look`

### 11.3 Pose/state sprites (use the character sheet as an image reference)

For each cat, generate these **3 states** (not 4). Keep camera, scale, and framing identical so sprites swap cleanly.

**Template:**
```
The same cat as the reference image, [POSE], full body, front-facing three-quarter view, centered,
consistent size and proportions with the reference, plain flat background for easy extraction,
[GLOBAL STYLE ANCHOR]
```

| State | [POSE] text | Filename | Used for |
|---|---|---|---|
| Idle | `sitting upright with a calm smile, tail curled around its feet, eyes open, ears up` | `{cat}_idle.png` | menu, default |
| Happy | `sitting with a big open-mouth meow, eyes closed in joy, tiny music notes and small hearts floating, tail up in a curl` | `{cat}_happy.png` | hits, results |
| Sleepy | `curled up drowsy with half-closed eyes, ears slightly drooped, gentle sad-sleepy expression` | `{cat}_sleepy.png` | the nap state |

(No "z" in the sprite — the global negative prompt bans letters. Draw the sleep z over the cat with the font in code.)

**Celebrate reuses `happy`** plus sparkles/confetti drawn in code — a fourth pose per cat is 9 more generations for very little payoff.

**Optional extra frames (P1) for simple animation:**
- `{cat}_idle_2.png`: `same as idle but head slightly tilted and tail tip flicked` (2-frame idle loop)
- `{cat}_meow.png`: `mouth wide open mid-meow, eyes squeezed, ears back slightly` (flash on each hit)

### 11.4 Cat portrait for select screen (A10) — P1

Skip for the MVP: crop the head from `idle.png` and put it on a dusk-violet circle with a `ClipOval`.

```
Bust portrait of the same cat as the reference, head and shoulders, cheerful expression, slight head tilt,
soft warm rim light, circular vignette background in dusk violet, [GLOBAL STYLE ANCHOR], square composition
```

### 11.5 Locked silhouette (A11) — cut

All cats are free, so there is nothing to lock.

---

## 12. Accessories (A20, P2)

```
Small cute cat accessory icon: [ITEM], front view, centered, soft glossy shading, on flat light background
for extraction, sized to fit on a chibi cat head, [GLOBAL STYLE ANCHOR]
```
`[ITEM]` options: `tiny knitted beanie in mint`, `round golden-rimmed glasses`, `red bow tie`, `small wizard hat with stars`, `little headphones`.
Attach in-game as overlays positioned to each cat's head anchor.

---

## 13. VFX and particles (A12, A13) — all P1

The MVP plays fine with the cat sprite swap + a scale/fade tween in code. Generate these only if the game already works.

| Asset | Prompt |
|---|---|
| Perfect burst | `radial starburst of soft gold and cream sparkles with a small paw print in the center, glowing, on flat black background, game VFX` |
| Good burst | `smaller soft pink and cream sparkle ring, subtle, on flat black background, game VFX` |
| Music note particle | `single small cream-colored eighth music note with a soft glow, on flat black background, 64px icon` |
| Heart particle | `single small pink heart, glossy, soft glow, on flat black background, 64px icon` |
| Sparkle | `single four-point sparkle star in warm gold, on flat black background` |
| Raindrop | `single soft blue-white teardrop, glossy highlight, on flat black background` |

**Never generate lettering** ("Perfect!", "Good", "Zzz"). The global negative prompt bans letters, so those prompts fight it and come back garbled half the time. Render them with the bundled Fredoka font — `Text('Perfect!', style: ...)` with a plum stroke — or draw the sleep "z" as a `Path`. Faster, sharper, and free.

---

## 14. UI elements (A14, A15, A16, A17) — draw all of it in code

None of this needs an image. Every item below is a `Container` / `DecoratedBox` with a 24 px radius, a linear gradient from the palette, a 2 px cream border at 30% opacity, and a `Text` child in Fredoka. It stays crisp on every screen, costs zero generations, and never needs a background cutout.

| Element | How |
|---|---|
| Buttons (14.1) | `Container` + gradient (amber for primary, dusk violet for secondary) + `Text`, with a `GestureDetector` scale tween on press |
| Icons (14.2) | `Icon(...)` from Material icons, tinted cream — or a single generated sheet at P1 |
| Panels / cards (14.3) | `DecoratedBox`, dusk violet at 85% opacity, 2 px cream border at 25% |
| Stars (14.4) | `Text('★')` in Fredoka, gold `#FFD76A` when filled, `#6B5F8C` when empty |
| Mood meter (14.5) | `ClipRRect` bar with a mint→amber→pink gradient fill; the mood icon is the cat's `idle`/`sleepy` sprite, not a new image |
| Results (14.6) | The `happy` sprite + `Text` + a code-drawn star row |

Prompts for these are kept below as P1 reference only, in case you later want a more painterly look.

### 14.1 Buttons (P1 reference)
```
Set of rounded pill-shaped game UI buttons in a cozy style: primary button in warm amber with cream text area,
secondary button in soft violet, disabled button in grey-lavender, subtle glossy top highlight, soft drop shadow,
blank (no text), on flat dark background, [GLOBAL STYLE ANCHOR]
```

### 14.2 Icon set (P1 reference)
```
Icon set of 8 cute rounded game UI icons on a plain dark plum background, arranged in a grid,
consistent line weight and style, cream color with soft pink accents:
play triangle, pause bars, settings gear, home house, paw print, retry circular arrow, volume speaker, vibration waves,
no text, [GLOBAL STYLE ANCHOR]
```

### 14.3 Panels / cards (P1 reference)
```
Rounded rectangle UI panel with a frosted glass look in dusk violet, thin cream border, soft inner glow,
tiny paw print pattern in the corners, blank inside, on flat dark background, game UI, [GLOBAL STYLE ANCHOR]
```

### 14.4 Stars (A15, P1 reference)
```
A single chunky rounded five-point star, glossy warm gold with a cream highlight, tiny sparkle, soft shadow,
on flat black background, game UI icon, [GLOBAL STYLE ANCHOR]
```
Empty version:
```
A single chunky rounded five-point star outline, empty hollow center, muted lavender-grey with subtle inner shadow,
on flat black background, game UI icon
```

### 14.5 Mood meter (A16, P1 reference)
**Bar frame:**
```
Horizontal progress bar frame, rounded pill shape, cream wooden or glass look with a thin outline, empty inside,
tiny paw print at the left end, on flat black background, game UI
```
**Fill:** draw in code as a gradient (mint → amber → pink). **Mood icons (96×96):**
- happy: `cute cat face, big smile, sparkling eyes, pink cheeks, icon, flat black background`
- neutral: `cute cat face, calm content smile, icon, flat black background`
- sleepy: `cute cat face, half-closed eyes, droopy ears, icon, flat black background`

### 14.6 Results screen elements (P1 reference)
- **Ribbon banner:** `soft cream ribbon banner, blank, gentle curve, slight paper texture, flat black background`
- **Confetti:** `small pastel confetti pieces and paw prints scattered on transparent/black background`

---

## 15. Song cover art (A18) — P1

For the MVP, the song card is a code-drawn gradient (one per song) with the title in Fredoka. Square 512×512 if you generate them later.

```
Album cover art for the classical piece "Spring" by Vivaldi, cozy interpretation: a cat sitting in a blooming
flower meadow with a tiny violin, pastel spring colors with cherry blossoms and gentle sunrise,
[GLOBAL STYLE ANCHOR], square, no text
```
```
Album cover art for Pachelbel's "Canon in D", cozy interpretation: two cats sitting on a windowsill sharing a
scarf, snow falling outside, warm lamp, [GLOBAL STYLE ANCHOR], square, no text
```
```
Album cover art for Beethoven's "Ode to Joy", cozy interpretation: a small choir of cats singing joyfully with
sheet music, confetti and golden light, [GLOBAL STYLE ANCHOR], square, no text
```

## 16. Calibration screen illustration (A19) — P1

The calibration screen itself is P1. Until then there is only an offset slider.

```
A cute cat wearing big over-ear headphones tapping its paw in time, a soft pulsing circle rhythm indicator behind it,
tiny metronome on the side, calm plum background, [GLOBAL STYLE ANCHOR], square, no text
```

## 17. Store assets (A21) — P2

Skip until the game ships. If you need it:

**Feature graphic (1024×500):**
```
Wide banner: a row of cute cats of different colors sitting on a rainy windowsill playing tiny instruments,
music notes floating, warm amber lamp light, [GLOBAL STYLE ANCHOR], wide 2:1, leave the left third calm for a logo
```
Screenshots: take real in-game screens and add frames/captions in Figma/Canva.

---

## 18. Production workflow

**Target: 19 images, in this order, batched.**

1. **Day 0 (before or during coding):** style anchor → Miso character sheet → gameplay background → the 4 tiles in one image. Four generations and the game already looks real.
2. Luna + Mochi character sheets (reference = style anchor).
3. All 9 cat poses as reference-based variants (3 cats × 3 states), batched.
4. Emblem, app icon, menu background, hit line.
5. Batch background removal (`rembg p in_folder out_folder`).
6. Resize with a script (ImageMagick: `magick in.png -resize 512x512 out.png`).
7. Compress PNGs (`pngquant` or `oxipng`) to keep the APK small.
8. Review everything on a phone for contrast and readability, especially tiles on the gameplay background.

Sprite atlases (TexturePacker) are optional at this size — skip them.

### Consistency tips
- Always attach the same reference images.
- Fix the seed (Stable Diffusion/Flux) for a character across poses when possible.
- Use the same lighting descriptor words each time ("warm lamp lighting").
- The style anchor contains a cat; when generating backgrounds, keep `no characters` in the prompt and, in Midjourney, add `--no cat` so the reference does not drag one in.
- If a pose fails, edit the closest good render instead of regenerating from scratch (inpainting / image edit).
- Expect to fix paws and eye alignment manually.

### Quality checklist per asset
- [ ] Transparent background where needed
- [ ] Correct size and aspect ratio
- [ ] Consistent palette and outline style
- [ ] No stray text or watermark
- [ ] Readable at the smallest display size (view the tiles at 64 px)
- [ ] No baked-in drop shadow on anything that gets cut out
- [ ] Documented in `LICENSES.md` (prompt, tool, date, license)
