"""Creator Dashboard icons for the game passes and Cred packs (after the user's sketch): each item's
store picture on a bright round badge, a gradient from light in the middle to deep at the edge,
pale light rays turning out from behind it and a dark rim, every badge its own colour.
Run: python make_icons.py <hi-res pictures dir> <out dir>
(the pictures: ART_SIZE=420 python draw_store_art.py <fonts> <dir> <names>)."""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PICTURES, OUT = sys.argv[1], sys.argv[2]
S = 512  # Roblox shows these as circles, so the badge fills the square
SS = 2  # drawn this much bigger, then shrunk (smooth edges)
RIM = (24, 18, 30)
RAYS = 14

# name: (picture, colour)
ICONS = {
    "Cred100": ("Cred100", (60, 200, 90)),
    "Cred500": ("Cred500", (40, 170, 230)),
    "Cred1000": ("Cred1000", (150, 90, 240)),
    "Cred5000": ("Cred5000", (240, 70, 170)),
    "Cred25000": ("Cred25000", (255, 140, 30)),
    "Cred100000": ("Cred100000", (235, 40, 50)),
    "BigBaller": ("PassBigBaller", (255, 190, 20)),
    "Rainbow": ("PassRainbow", None),  # a rainbow badge
    "DoubleCash": ("PassDoubleCash", (230, 40, 45)),
    "DoubleLuck": ("PassDoubleLuck", (40, 190, 80)),
    "MegaBag": ("PassMegaBag", (120, 80, 220)),
    "FatStack": ("PassFatStack", (20, 175, 160)),
    "TipJar": ("PassTipJar", (255, 120, 40)),
    "DoubleCred": ("PassDoubleCred", (60, 70, 215)),  # not yellow: its coin is gold
    "BailMoney": ("PassBail", (60, 120, 235)),
    "CleanRecord": ("PassClean", (40, 200, 230)),
    "VIP": ("PassVip", (200, 50, 200)),
}


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hue_ring(angle):
    """A rainbow colour by angle (radians)."""
    import colorsys

    r, g, b = colorsys.hsv_to_rgb((angle / (2 * math.pi)) % 1, 0.75, 1)
    return (int(r * 255), int(g * 255), int(b * 255))


def badge(color):
    n = S * SS
    c = (n - 1) / 2
    y, x = np.mgrid[0:n, 0:n]
    dx, dy = x - c, y - c
    dist = np.sqrt(dx * dx + dy * dy) / (n / 2)
    angle = np.arctan2(dy, dx)
    rgb = np.zeros((n, n, 3), dtype=np.float32)
    # The gradient: pale in the middle, the colour, deeper at the edge.
    t = np.clip(dist / 0.92, 0, 1)[..., None]
    if color is None:
        base = np.zeros((n, n, 3), dtype=np.float32)
        hues = np.array([hue_ring(a) for a in np.linspace(-math.pi, math.pi, 361)], dtype=np.float32)
        index = ((angle + math.pi) / (2 * math.pi) * 360).astype(int)
        base[:] = hues[index]
    else:
        base = np.empty((n, n, 3), dtype=np.float32)
        base[:] = color
    light = base * 0.35 + 255 * 0.65
    deep = base * 0.62
    inner = light + (base - light) * np.clip(t / 0.55, 0, 1)
    outer = base + (deep - base) * np.clip((t - 0.55) / 0.45, 0, 1)
    rgb = np.where(t < 0.55, inner, outer)
    # Light rays: soft wedges from the middle, brightest near the centre.
    wedge = (np.cos(angle * RAYS) + 1) / 2
    ray = np.clip((wedge - 0.55) / 0.45, 0, 1) * np.clip(1.15 - dist, 0, 1) * 0.55
    rgb = rgb + (255 - rgb) * ray[..., None]
    # A dark rim and a thin bright line inside it.
    rim = (dist > 0.92) & (dist <= 0.985)
    rgb[rim] = RIM
    line = (dist > 0.875) & (dist <= 0.905)
    rgb[line] = rgb[line] + (255 - rgb[line]) * 0.5
    alpha = np.clip((0.985 - dist) * n / 2, 0, 1) * 255
    image = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(image, "RGBA").resize((S, S), Image.LANCZOS)


def shine(icon):
    """A soft gloss across the top of the badge."""
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(gloss)
    draw.ellipse([S * 0.16, S * 0.07, S * 0.84, S * 0.45], fill=(255, 255, 255, 60))
    gloss = gloss.filter(ImageFilter.GaussianBlur(S * 0.03))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([S * 0.06, S * 0.06, S * 0.94, S * 0.94], fill=255)
    clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    clipped.paste(gloss, (0, 0), Image.composite(gloss.getchannel("A"), Image.new("L", (S, S), 0), mask))
    icon.alpha_composite(clipped)


def drop_shadow(picture):
    shadow = Image.new("RGBA", picture.size, (0, 0, 0, 0))
    shadow.putalpha(picture.getchannel("A").point(lambda a: int(a * 0.45)))
    return shadow.filter(ImageFilter.GaussianBlur(10))


os.makedirs(OUT, exist_ok=True)
for name, (picture_name, color) in ICONS.items():
    icon = badge(color)
    shine(icon)
    picture = Image.open(os.path.join(PICTURES, picture_name + ".png")).convert("RGBA")
    size = int(S * 0.74)
    picture = picture.resize((size, size), Image.LANCZOS)
    at = ((S - size) // 2, (S - size) // 2)
    icon.alpha_composite(drop_shadow(picture), (at[0] + 6, at[1] + 10))
    icon.alpha_composite(picture, at)
    icon.save(os.path.join(OUT, name + ".png"))
    print("made", name)
