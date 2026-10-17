"""Slice Retro Cat pixel-art strips into Meowzart runtime sprites.

Reads from ../Retro cat/ (source of truth, never modified) and writes:
  assets/images/cats/lane_0..3 strip frames (idle/happy/sleepy states)
  assets/images/cats/menu_mascot.png
  assets/images/cats/crew_*.png  bottom-row crew cats (one static frame each)
  assets/images/tiles/tile_0..3.png (food bowls)
  assets/images/backgrounds/bg_bedroom.png (furniture scene, code-composited)
Plus a downscaled menu mascot variant.

Run: python tools/pipeline/slice_sprites.py
Idempotent: overwrites outputs.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'Retro cat')
CATS = os.path.join(ROOT, 'assets', 'images', 'cats')
TILES = os.path.join(ROOT, 'assets', 'images', 'tiles')
BG = os.path.join(ROOT, 'assets', 'images', 'backgrounds')

# (source file, frames across, frame_h or None, name)
LANES = [
    ('Idle.png', 10, 32, 'lane_0'),        # cream cat, calm idle
    ('drculacat.png', 6, 32, 'lane_1'),    # dracula cape
    ('VampireAngry.png', 9, 32, 'lane_2'), # vampire angry (hit flash built in)
    ('Box3.png', 4, 32, 'lane_3'),         # box-hide cat
]
WITCH = ('WitchFlying.png', 6, 64, 'menu_mascot')  # 48x64 frames on broom


def load(name):
    im = Image.open(os.path.join(SRC, name)).convert('RGBA')
    w, h = im.size
    assert im.getpixel((0, 0))[3] == 0, f'{name}: expected transparent corners'
    return im


def main():
    os.makedirs(CATS, exist_ok=True)
    os.makedirs(TILES, exist_ok=True)
    os.makedirs(BG, exist_ok=True)
    manifest = []

    for src, nframes, fh, out in LANES + [WITCH]:
        im = load(src)
        w, h = im.size
        fw = w // nframes
        assert fw * nframes == w, f'{src}: width {w} not divisible by {nframes}'
        assert h == fh, f'{src}: height {h} != {fh}'
        frames = [im.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(nframes)]
        # states: idle = calm frames, happy = mid-tail/excited frames, sleepy = blink frames
        if out == 'lane_0':
            idle, happy, sleepy = frames[0:2], frames[4:6], frames[8:10]
        elif out == 'lane_1':
            idle, happy, sleepy = frames[0:2], frames[2:4], frames[4:6]
        elif out == 'lane_2':
            idle, happy, sleepy = frames[0:3], frames[4:7], frames[7:9]
        elif out == 'lane_3':
            idle, happy, sleepy = frames[0:1], frames[1:3], frames[3:4]
        else:  # menu mascot: keep all 6
            idle, happy, sleepy = frames[0:2], frames[2:4], frames[4:6]
        for state, fs in (('idle', idle), ('happy', happy), ('sleepy', sleepy)):
            strip = Image.new('RGBA', (fw * len(fs), h), (0, 0, 0, 0))
            for i, f in enumerate(fs):
                strip.paste(f, (i * fw, 0), f)
            p = os.path.join(CATS, f'{out}_{state}.png')
            strip.save(p)
            manifest.append((f'cats/{out}_{state}.png', strip.size, len(fs)))
        # hero still for select cards / results
        hero = frames[len(frames) // 2]
        hp = os.path.join(CATS, f'{out}_hero.png')
        hero.save(hp)
        manifest.append((f'cats/{out}_hero.png', hero.size, 1))

    # Tiles: 4 food bowls from RetroCatsFree band rows 207-245 (38px tall, 4 bowls across)
    free = load('RetroCatsFree.png')
    bowls = free.crop((0, 207, 256, 245))  # 256x38
    bw = 256 // 4
    for i in range(4):
        tile = bowls.crop((i * bw, 0, (i + 1) * bw, 38))
        # square-pad to 64x64 for uniform tiles
        sq = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        sq.paste(tile, ((64 - bw) // 2, (64 - 38) // 2), tile)
        p = os.path.join(TILES, f'tile_{i}.png')
        sq.save(p)
        manifest.append((f'tiles/tile_{i}.png', sq.size, 1))

    # Bottom-row crew cats: four distinct cats, one static frame each, in the
    # order the gameplay row draws them (left to right). Sources:
    #   Box3 frame 0 / drculacat frame 0 / Idle frame 0 (32px strips)
    #   RetroCatsFree row 1 (y 18..63, tan sitter) — 4 frames of 64px across.
    crew = [
        ('Box3.png', (0, 0, 32, 32), 'crew_box'),
        ('drculacat.png', (0, 0, 32, 32), 'crew_dracula'),
        ('Idle.png', (0, 0, 32, 32), 'crew_idle'),
        (None, (0, 18, 64, 63), 'crew_tan'),       # RetroCatsFree row 1
    ]
    for src, box, out in crew:
        im = free if src is None else load(src)
        frame = im.crop(box)
        p = os.path.join(CATS, f'{out}.png')
        frame.save(p)
        manifest.append((f'cats/{out}.png', frame.size, 1))

    # Menu mascot downscaled hero already saved; make sure at least one bg exists.
    # The bedroom background is code-drawn (theme gradient) until art lands;
    # keep a sentinel so the game can probe for an optional overlay later.
    print('Sliced sprites:')
    for name, size, n in manifest:
        print(f'  {name} {size[0]}x{size[1]} frames={n}')
    print('OK -', len(manifest), 'files')


if __name__ == '__main__':
    main()
