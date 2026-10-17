"""Slice the 2026-10-03 UI/gameplay art drops into runtime assets.

Reads from assets/ (source of truth, never modified):
  assets/icons-removebg-preview.png      8-icon strip (play .. waves)
  assets/stars-removebg-preview.png      7-sprite strip (star glyph + slot cards)
  assets/song_select-removebg-preview.png
  assets/hit_line_and_lane_guides-removebg-preview.png
                                         notes motif + hit bar + 4 lane pads
  assets/vivaldi summer cover.jpg
  assets/Pachelbel's Canon in D cover.jpg
  assets/app icon.jpg
  Retro cat/WitchFlying.png              flying-witch loop strip

Writes:
  assets/images/ui/icon_*.png            all 8 icons (every one is wired)
  assets/images/ui/star_slot_*.png       results star slots, earned / not yet
  assets/images/ui/song_select_bg.png    song-select background
  assets/images/ui/cover_summer.jpg      Summer song cover
  assets/images/ui/cover_canon.jpg       Canon in D song cover
  assets/images/ui/notes_motif.png       note cluster (also the Ode card art)
  assets/images/ui/hit_line.png          the paw-print hit bar
  assets/images/ui/lane_guide_0..3.png   candy lane pads, one per lane
  assets/images/ui/witch_fly_*.png       flying-witch loop frames
  android/app/src/main/res/mipmap-*/ic_launcher.png   launcher icon, 48..192 px
  tools/out/ui_slices/*.png              every slice, for reference only

Run: python tools/pipeline/export_ui_art.py
Idempotent: overwrites outputs.
"""
import os
import shutil
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, 'assets')
UI = os.path.join(ASSETS, 'images', 'ui')
PREVIEW = os.path.join(ROOT, 'tools', 'out', 'ui_slices')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# Sprite order = strip order, left to right. These names are the contract the
# Flutter UI loads (`PixelIcon`, results screen) — rename here and there.
ICONS = ['icon_play', 'icon_pause', 'icon_gear', 'icon_home',
         'icon_retry', 'icon_speaker', 'icon_waves', 'icon_waves_triple']
STARS = ['star_big', 'star_slot_filled', 'star_slot_blank', 'panel_wide_paws',
         'star_slot_small', 'panel_tall_paws', 'star_slot_empty']

STRIPS = [
    ('icons-removebg-preview.png', ICONS),
    ('stars-removebg-preview.png', STARS),
]

COPIES = [
    ('assets/song_select-removebg-preview.png', 'song_select_bg.png'),
    ('assets/vivaldi summer cover.jpg', 'cover_summer.jpg'),
    ("assets/Pachelbel's Canon in D cover.jpg", 'cover_canon.jpg'),
]

GAMEPLAY_DROP = 'hit_line_and_lane_guides-removebg-preview.png'
LANE_GUIDE_COUNT = 4
BAND_GAP_PX = 8  # empty rows that split the drop's three bands
WITCH_SRC = os.path.join('Retro cat', 'WitchFlying.png')

# Only the slices the game actually loads ship; the rest stay as references in
# tools/out/ui_slices/ so a later screen can adopt one by adding it here.
SHIPPED = set(ICONS) | {'star_slot_filled', 'star_slot_empty'}

ALPHA_MIN = 20  # ignore the matting crumbs rembg leaves behind
GAP_PX = 6      # merge antialiased fragments separated by a gap this narrow
PAD_PX = 2      # breathing room kept around each sprite's opaque bounds

LAUNCHER_SIZES = {'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
                  'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192}


def column_flags(mask):
    """Per column: does any pixel exceed the alpha threshold?"""
    w, h = mask.size
    px = mask.load()
    return [any(px[x, y] > 0 for y in range(h)) for x in range(w)]


def sprite_runs(flags, gap=GAP_PX):
    """Group columns into sprites, bridging gaps up to [gap] empty columns."""
    runs = []
    x, w = 0, len(flags)
    while x < w:
        if not flags[x]:
            x += 1
            continue
        start = last = x
        empty = 0
        while x < w and empty <= gap:
            if flags[x]:
                last, empty = x, 0
            else:
                empty += 1
            x += 1
        runs.append((start, last))
    return runs


def slice_strip(file_name, names):
    """Crop a strip's alpha-connected sprites into tight RGBA images."""
    path = os.path.join(ASSETS, file_name)
    im = Image.open(path).convert('RGBA')
    if im.getpixel((0, 0))[3] > 0:
        raise SystemExit(f'{file_name}: corner is not transparent — was the '
                         f'background removal skipped?')
    mask = im.split()[3].point(lambda a: 255 if a > ALPHA_MIN else 0)
    runs = sprite_runs(column_flags(mask))
    if len(runs) != len(names):
        raise SystemExit(f'{file_name}: found {len(runs)} sprites but the '
                         f'script knows {len(names)} names — update the list')
    out = {}
    for (c0, c1), name in zip(runs, names):
        sub = mask.crop((c0, 0, c1 + 1, im.height))
        bx0, by0, bx1, by1 = sub.getbbox()
        box = (max(0, c0 + bx0 - PAD_PX), max(0, by0 - PAD_PX),
               min(im.width, c0 + bx1 + PAD_PX),
               min(im.height, by1 + PAD_PX))
        out[name] = im.crop(box)
    return out


def export_launcher_icon():
    """Center-crop the app icon to a square, write the 5 mipmap densities."""
    src = Image.open(os.path.join(ASSETS, 'app icon.jpg')).convert('RGB')
    side = min(src.size)
    left = (src.width - side) // 2
    top = (src.height - side) // 2
    square = src.crop((left, top, left + side, top + side))
    written = []
    for folder, size in LAUNCHER_SIZES.items():
        dest = os.path.join(RES, folder, 'ic_launcher.png')
        square.resize((size, size), Image.LANCZOS).save(dest)
        written.append((f'{folder}/ic_launcher.png', (size, size)))
    return written


def row_flags(mask):
    """Per row: does any pixel exceed the alpha threshold?"""
    w, h = mask.size
    px = mask.load()
    return [any(px[x, y] > 0 for x in range(w)) for y in range(h)]


def export_gameplay_art():
    """Slice the gameplay drop: notes motif, hit bar, four lane pads.

    The drop stacks three bands vertically; the pads are separated by empty
    columns like the icon strips. `lane_guide_{i}` is lane `i`'s pad.
    """
    im = Image.open(os.path.join(ASSETS, GAMEPLAY_DROP)).convert('RGBA')
    mask = im.split()[3].point(lambda a: 255 if a > ALPHA_MIN else 0)
    bands = sprite_runs(row_flags(mask), gap=BAND_GAP_PX)
    if len(bands) != 3:
        raise SystemExit(f'{GAMEPLAY_DROP}: expected 3 bands (notes, bar, '
                         f'pads), found {len(bands)}')
    out = {}
    for name, (r0, r1) in zip(('notes_motif', 'hit_line'), bands[:2]):
        bx0, _, bx1, _ = mask.crop((0, r0, im.width, r1 + 1)).getbbox()
        out[name] = im.crop((max(0, bx0 - PAD_PX), max(0, r0 - PAD_PX),
                             min(im.width, bx1 + PAD_PX),
                             min(im.height, r1 + PAD_PX)))
    r0, r1 = bands[2]
    pads = sprite_runs(column_flags(mask.crop((0, r0, im.width, r1 + 1))))
    if len(pads) != LANE_GUIDE_COUNT:
        raise SystemExit(f'{GAMEPLAY_DROP}: expected {LANE_GUIDE_COUNT} lane '
                         f'pads, found {len(pads)}')
    for i, (c0, c1) in enumerate(pads):
        bx0, by0, bx1, by1 = mask.crop((c0, r0, c1 + 1, r1 + 1)).getbbox()
        out[f'lane_guide_{i}'] = im.crop(
            (max(0, c0 + bx0 - PAD_PX), max(0, r0 + by0 - PAD_PX),
             min(im.width, c0 + bx1 + PAD_PX),
             min(im.height, r0 + by1 + PAD_PX)))
    return out


def export_witch_frames():
    """Slice the flying-witch strip into its loop frames, left to right."""
    im = Image.open(os.path.join(ROOT, WITCH_SRC)).convert('RGBA')
    mask = im.split()[3].point(lambda a: 255 if a > ALPHA_MIN else 0)
    # Frames sit exactly 6 px apart; the default gap bridge would merge the
    # whole strip into one sprite, so bridge nothing.
    runs = sprite_runs(column_flags(mask), gap=0)
    if len(runs) < 2:
        raise SystemExit(f'{WITCH_SRC}: found {len(runs)} frame(s) — is the '
                         f'background still opaque?')
    out = {}
    for i, (c0, c1) in enumerate(runs):
        bx0, by0, bx1, by1 = mask.crop((c0, 0, c1 + 1, im.height)).getbbox()
        out[f'witch_fly_{i}'] = im.crop(
            (max(0, c0 + bx0 - PAD_PX), max(0, by0 - PAD_PX),
             min(im.width, c0 + bx1 + PAD_PX),
             min(im.height, by1 + PAD_PX)))
    return out


def main():
    os.makedirs(UI, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    manifest = []

    for file_name, names in STRIPS:
        for name, sprite in slice_strip(file_name, names).items():
            sprite.save(os.path.join(PREVIEW, f'{name}.png'))
            shipped = name in SHIPPED
            if shipped:
                sprite.save(os.path.join(UI, f'{name}.png'))
            manifest.append((name, sprite.size, shipped))

    for name, sprite in export_gameplay_art().items():
        sprite.save(os.path.join(PREVIEW, f'{name}.png'))
        sprite.save(os.path.join(UI, f'{name}.png'))
        manifest.append((name, sprite.size, True))

    for name, sprite in export_witch_frames().items():
        sprite.save(os.path.join(PREVIEW, f'{name}.png'))
        sprite.save(os.path.join(UI, f'{name}.png'))
        manifest.append((name, sprite.size, True))

    for src_name, dest_name in COPIES:
        dest = os.path.join(UI, dest_name)
        shutil.copyfile(os.path.join(ROOT, src_name), dest)
        manifest.append((dest_name, Image.open(dest).size, True))

    for dest, size in export_launcher_icon():
        manifest.append((dest, size, True))

    print('Exported UI art:')
    for name, size, shipped in manifest:
        where = 'assets/images/ui/' if shipped else 'tools/out/ui_slices/'
        print(f'  {name:32} {size[0]:>4}x{size[1]:<4} {where}')
    print('OK -', len(manifest), 'files')


if __name__ == '__main__':
    main()
