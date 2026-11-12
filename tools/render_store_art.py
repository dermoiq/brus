"""Procedurally renders Crystal Rush store art (icon + thumbnail) with Pillow.

Run: /tmp/imgenv/bin/python tools/render_store_art.py
Outputs icon.png (1024x1024) and thumbnail.png (1920x1080) at the repository root.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

VIOLET = (150, 96, 255)
GOLD = (255, 204, 72)
CYAN = (96, 240, 230)
PINK = (255, 96, 180)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def radial_background(size, inner, outer):
    w, h = size
    img = Image.new("RGB", size, outer)
    px = img.load()
    cx, cy = w * 0.5, h * 0.42
    maxd = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / maxd)
            px[x, y] = lerp(inner, outer, t ** 0.8)
    return img


def glow_layer(size, draw_fn, radius):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return layer.filter(ImageFilter.GaussianBlur(radius))


def add_glow(base, layer, strength=1.0):
    base_rgba = base.convert("RGBA")
    if strength != 1.0:
        r, g, b, a = layer.split()
        a = a.point(lambda v: int(v * strength))
        layer = Image.merge("RGBA", (r, g, b, a))
    base_rgba.alpha_composite(layer)
    return base_rgba.convert("RGB")


def sparkles(draw, rng, count, box, color):
    x0, y0, x1, y1 = box
    for _ in range(count):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        s = rng.uniform(4, 16)
        draw.line([(x - s, y), (x + s, y)], fill=color + (255,), width=2)
        draw.line([(x, y - s), (x, y + s)], fill=color + (255,), width=2)
        draw.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 255, 255, 255))


def crystal(draw, cx, cy, height, width, tilt, color):
    """Faceted crystal shard: two lit facets and a shadow facet."""
    ca, sa = math.cos(tilt), math.sin(tilt)

    def rot(px, py):
        return (cx + px * ca - py * sa, cy + px * sa + py * ca)

    top = rot(0, -height)
    left = rot(-width, 0)
    right = rot(width, 0)
    bottom = rot(0, height * 0.25)
    draw.polygon([top, right, bottom], fill=color + (235,))
    draw.polygon([top, left, bottom], fill=lerp(color, (20, 10, 40), 0.35) + (235,))
    mid = rot(width * 0.15, -height * 0.2)
    draw.line([top, mid], fill=(255, 255, 255, 170), width=max(2, int(width * 0.12)))


def pickaxe(draw, cx, cy, scale, shaft, head_color, glow_color):
    """Diagonal pickaxe: shaft from lower-left to upper-right, curved crystal head."""
    angle = math.radians(-38)
    ca, sa = math.cos(angle), math.sin(angle)

    def p(x, y):
        x *= scale
        y *= scale
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)

    draw.line([p(0, 520), p(0, -260)], fill=shaft + (255,), width=int(34 * scale / 1.0))
    head = [p(-360, -210), p(-120, -330), p(0, -300), p(120, -330), p(360, -210),
            p(300, -170), p(120, -250), p(0, -230), p(-120, -250), p(-300, -170)]
    draw.polygon(head, fill=head_color + (255,), outline=glow_color + (255,))
    draw.line([p(-300, -170), p(0, -230), p(300, -170)], fill=(255, 255, 255, 200), width=8)


def draw_icon(path):
    size = 1024
    rng = random.Random(7)
    base = radial_background((size, size), (88, 42, 150), (18, 8, 38))

    def glow(d):
        pickaxe(d, 512, 540, 0.9, (120, 80, 60), VIOLET, PINK)
        for _ in range(14):
            crystal(d, rng.uniform(170, 860), rng.uniform(160, 880), rng.uniform(50, 110),
                    rng.uniform(22, 40), rng.uniform(-0.6, 0.6), rng.choice([VIOLET, CYAN, GOLD, PINK]))

    layer = glow_layer((size, size), glow, 26)
    img = add_glow(base, layer, 1.0)

    d = ImageDraw.Draw(img, "RGBA")
    pickaxe(d, 512, 540, 0.9, (150, 102, 70), (210, 220, 240), CYAN)
    for _ in range(10):
        crystal(d, rng.uniform(150, 880), rng.uniform(150, 890), rng.uniform(40, 90),
                rng.uniform(18, 32), rng.uniform(-0.7, 0.7), rng.choice([VIOLET, CYAN, GOLD, PINK]))
    sparkles(d, rng, 26, (110, 110, 914, 914), (255, 230, 150))

    title_font = ImageFont.truetype(BOLD, 150)
    text = "CRYSTAL"
    text2 = "RUSH"
    for label, y in ((text, 690), (text2, 830)):
        bbox = d.textbbox((0, 0), label, font=title_font, stroke_width=0)
        tw = bbox[2] - bbox[0]
        x = (size - tw) // 2
        d.text((x + 8, y + 10), label, font=title_font, fill=(20, 6, 40, 230), stroke_width=12,
               stroke_fill=(20, 6, 40, 230))
        d.text((x, y), label, font=title_font, fill=(255, 214, 90, 255), stroke_width=12,
               stroke_fill=(60, 20, 90, 255))

    img.save(path, "PNG", optimize=True)


def island(draw, cx, top_y, width, height, rock, grass):
    """Floating island: grassy top, rocky underside tapering to a point."""
    top = [(cx - width / 2, top_y), (cx + width / 2, top_y)]
    under = [(cx + width * 0.3, top_y + height * 0.6), (cx, top_y + height), (cx - width * 0.3, top_y + height * 0.6)]
    draw.polygon(top + under, fill=rock + (255,))
    draw.polygon([(cx - width / 2, top_y), (cx + width / 2, top_y), (cx + width / 2 - 20, top_y + 26),
                  (cx - width / 2 + 20, top_y + 26)], fill=grass + (255,))
    for i in range(6):
        ox = cx - width * 0.4 + i * width * 0.16
        draw.ellipse([ox, top_y + height * 0.2, ox + width * 0.12, top_y + height * 0.2 + 24],
                     fill=lerp(rock, (0, 0, 0), 0.25) + (255,))


def draw_thumbnail(path):
    w, h = 1920, 1080
    rng = random.Random(11)
    base = radial_background((w, h), (120, 70, 190), (16, 40, 70))

    far = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(far)
    for _ in range(40):
        x = rng.uniform(0, w)
        y = rng.uniform(40, 520)
        s = rng.uniform(1.5, 3.5)
        fd.ellipse([x - s, y - s, x + s, y + s], fill=(255, 255, 255, 200))
    base.paste(far, (0, 0), far)

    # Distant islands (blurred for depth).
    haze = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for cx, ty, wd, ht in [(330, 380, 260, 170), (1620, 330, 300, 190), (1000, 300, 170, 110)]:
        island(hd, cx, ty, wd, ht, (110, 90, 150), (120, 170, 150))
    base = base.convert("RGBA")
    base.alpha_composite(haze.filter(ImageFilter.GaussianBlur(3)))

    # Foreground islands.
    fg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(fg)
    island(gd, 960, 640, 760, 330, (92, 70, 110), (110, 200, 110))
    island(gd, 330, 760, 420, 200, (150, 100, 70), (120, 190, 90))
    island(gd, 1600, 720, 360, 190, (120, 130, 150), (150, 210, 140))
    # Crystals on the main island.
    for _ in range(9):
        crystal(gd, rng.uniform(800, 1120), rng.uniform(560, 640), rng.uniform(70, 120),
                rng.uniform(26, 42), rng.uniform(-0.4, 0.4), rng.choice([VIOLET, CYAN, GOLD, PINK]))
    # Waterfalls off the main island edge.
    for x in (790, 1130):
        gd.line([(x, 660), (x + rng.uniform(-8, 8), 960)], fill=(170, 230, 255, 170), width=6)

    base.alpha_composite(fg)

    # Glowing crystal cave mouth on the left island.
    cave = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cave)
    cd.ellipse([240, 760, 420, 860], fill=(64, 255, 200, 200))
    base.alpha_composite(cave.filter(ImageFilter.GaussianBlur(18)))

    # Bloom pass on bright elements.
    glow_src = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gs = ImageDraw.Draw(glow_src)
    for _ in range(12):
        crystal(gs, rng.uniform(780, 1140), rng.uniform(540, 630), rng.uniform(60, 100),
                rng.uniform(20, 34), rng.uniform(-0.4, 0.4), rng.choice([CYAN, PINK, GOLD]))
    base.alpha_composite(glow_src.filter(ImageFilter.GaussianBlur(22)))

    # Character swinging a pickaxe (stylized capsule body).
    char = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(char)
    body_x, body_top, body_bottom = 1260, 560, 660
    cdraw.rounded_rectangle([body_x - 38, body_top + 60, body_x + 38, body_bottom], radius=30,
                            fill=(60, 90, 200, 255))
    cdraw.ellipse([body_x - 36, body_top, body_x + 36, body_top + 76], fill=(255, 214, 180, 255))
    cdraw.line([(body_x - 10, body_bottom), (body_x - 40, body_bottom + 110)], fill=(40, 40, 70, 255), width=34)
    cdraw.line([(body_x + 10, body_bottom), (body_x + 46, body_bottom + 104)], fill=(40, 40, 70, 255), width=34)
    # Swing: arm raised over the head, pick swept in an arc with motion trail.
    for i, a in enumerate(range(-150, -20, 14)):
        r = 300
        ax = body_x + r * math.cos(math.radians(a))
        ay = body_top + 110 + r * math.sin(math.radians(a))
        cdraw.line([(body_x, body_top + 110), (ax, ay)], fill=(255, 220, 120, 40 + i * 12), width=6)
    cdraw.line([(body_x + 18, body_top + 120), (body_x + 150, body_top - 130)], fill=(60, 90, 200, 255), width=30)
    pickaxe(cdraw, body_x + 150, body_top - 100, 0.42, (150, 102, 70), GOLD, PINK)
    base.alpha_composite(char.filter(ImageFilter.GaussianBlur(0.6)))

    # Sparkles and text.
    d = ImageDraw.Draw(base, "RGBA")
    sparkles(d, rng, 60, (60, 60, 1860, 620), (255, 230, 170))

    title_font = ImageFont.truetype(BOLD, 190)
    sub_font = ImageFont.truetype(BOLD, 60)
    title = "CRYSTAL RUSH"
    bbox = d.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    tx = (w - tw) // 2
    ty = 40
    d.text((tx + 8, ty + 10), title, font=title_font, fill=(20, 6, 40, 230), stroke_width=14,
           stroke_fill=(20, 6, 40, 230))
    d.text((tx, ty), title, font=title_font, fill=(255, 214, 90, 255), stroke_width=14,
           stroke_fill=(70, 24, 110, 255))
    sub = "MINE  •  UPGRADE  •  REBIRTH"
    sbox = d.textbbox((0, 0), sub, font=sub_font)
    sw = sbox[2] - sbox[0]
    d.text(((w - sw) // 2, 240), sub, font=sub_font, fill=(230, 220, 255, 255), stroke_width=6,
           stroke_fill=(30, 10, 60, 255))

    base.convert("RGB").save(path, "PNG", optimize=True)


if __name__ == "__main__":
    draw_icon(ROOT / "icon.png")
    draw_thumbnail(ROOT / "thumbnail.png")
    print("wrote icon.png and thumbnail.png")
