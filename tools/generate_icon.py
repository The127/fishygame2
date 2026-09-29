#!/usr/bin/env python3
"""Draws the project icon (icon.png) from scratch: a glowing fish on a dark ocean tile.

Original artwork, nothing to license. Needs Pillow. Re-run after editing and commit the PNG:

    python3 tools/generate_icon.py

Godot's Web export derives the favicon and apple-touch-icon from this file.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 512
SCALE = 4  # supersampling for smooth edges
OUT = Path(__file__).resolve().parent.parent / "icon.png"

CYAN = (64, 240, 220)
GREEN = (120, 255, 170)


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(n: int) -> Image.Image:
    img = Image.new("RGB", (n, n))
    px = img.load()
    top, bottom = (10, 34, 52), (2, 8, 20)
    for y in range(n):
        row = lerp(top, bottom, y / (n - 1))
        for x in range(n):
            px[x, y] = row
    return img


def fish_mask(n: int, shrink: float = 1.0) -> Image.Image:
    s = n / 100.0
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    cx, cy = 56, 52
    bw, bh = 27 * shrink, 17 * shrink
    d.ellipse([(cx - bw) * s, (cy - bh) * s, (cx + bw) * s, (cy + bh) * s], fill=255)
    tx = cx - bw + 3
    d.polygon(
        [(tx * s, cy * s), ((tx - 17 * shrink) * s, (cy - 17 * shrink) * s), ((tx - 13 * shrink) * s, cy * s), ((tx - 17 * shrink) * s, (cy + 17 * shrink) * s)],
        fill=255,
    )
    d.polygon(
        [((cx - 6) * s, (cy - bh + 2) * s), ((cx + 8) * s, (cy - bh - 10 * shrink) * s), ((cx + 14) * s, (cy - bh + 4) * s)],
        fill=255,
    )
    return m


def main() -> None:
    n = SIZE * SCALE
    img = background(n)

    glow = Image.new("RGB", (n, n), GREEN)
    halo = fish_mask(n, 1.25).filter(ImageFilter.GaussianBlur(n * 0.07))
    halo = halo.point(lambda v: int(v * 0.85))
    img = Image.composite(glow, img, halo)

    body = Image.new("RGB", (n, n), CYAN)
    grad = Image.linear_gradient("L").resize((n, n))
    body = Image.composite(Image.new("RGB", (n, n), GREEN), body, grad.point(lambda v: v // 2))
    img = Image.composite(body, img, fish_mask(n))

    d = ImageDraw.Draw(img)
    s = n / 100.0
    # gill line, eye
    d.arc([56 * s, 41 * s, 68 * s, 63 * s], 250, 110, fill=(10, 60, 70), width=int(1.6 * s))
    ex, ey, er = 68, 47, 3.4
    d.ellipse([(ex - er) * s, (ey - er) * s, (ex + er) * s, (ey + er) * s], fill=(4, 12, 24))
    d.ellipse([(ex - 1.6) * s, (ey - 2.4) * s, (ex + 0.2) * s, (ey - 0.6) * s], fill=(255, 255, 255))
    # bubbles
    for bx, by, br in ((84, 30, 3.2), (89, 21, 2.2), (80, 16, 1.5)):
        d.ellipse([(bx - br) * s, (by - br) * s, (bx + br) * s, (by + br) * s], outline=CYAN, width=int(0.9 * s))

    # rounded tile with a transparent margin
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=255)
    out = img.convert("RGBA")
    out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    out.resize((SIZE, SIZE), Image.LANCZOS).save(OUT, optimize=True)


if __name__ == "__main__":
    main()
