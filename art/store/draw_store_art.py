"""Cartoon store art for MONEY MONEY MONEY: thick dark outlines, glossy gradients, drawn at 512px and
saved at 256px with a clear background. Run: python art.py <fonts dir> <out dir>"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

FONTS, OUT = sys.argv[1], sys.argv[2]
BLACK_FONT = os.path.join(FONTS, "Montserrat-Black.ttf")
S = 512
INK = (18, 18, 26, 255)
GOLD_HI, GOLD, GOLD_LO = (255, 246, 130), (255, 214, 30), (215, 150, 0)
GREEN_HI, GREEN, GREEN_LO = (130, 240, 95), (70, 205, 60), (25, 140, 25)
BAND = (0.33, 0.57)  # where a bundle's paper band sits along it
# The money's colours (after the user's reference bundle): lime bills with darker green rims and
# corner circles, a cream paper band with a big yellow $, and a near-black green outline.
MONEY_INK = (6, 38, 2, 255)
LIME_HI, LIME, LIME_LO = (208, 246, 44), (166, 224, 22), (112, 192, 10)
LEAF = (48, 136, 2)
CREAM_HI, CREAM, CREAM_LO = (254, 248, 206), (242, 230, 166), (224, 202, 124)
BAND_EDGE = (112, 76, 30)
YELLOW = (255, 222, 0)


def font(size):
    return ImageFont.truetype(BLACK_FONT, int(size))


def new():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def vgrad(size, top, bottom):
    w, h = size
    t = np.linspace(0, 1, h)[:, None, None]
    a = np.array(top[:3], float)
    b = np.array(bottom[:3], float)
    rgb = a * (1 - t) + b * t
    arr = np.concatenate([np.repeat(rgb, w, axis=1), np.full((h, w, 1), 255.0)], axis=2)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def fill(layer, draw_shape, top, bottom, line=6, line_color=INK):
    """Fills a shape (draw_shape(draw) draws it on a mask) with a top-to-bottom gradient."""
    mask = Image.new("L", layer.size, 0)
    draw_shape(ImageDraw.Draw(mask), 255)
    box = mask.getbbox()
    if not box:
        return
    x0, y0, x1, y1 = box
    grad = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    grad.paste(vgrad((x1 - x0, y1 - y0), top, bottom), (x0, y0))
    piece = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    piece.paste(grad, (0, 0), mask)
    layer.alpha_composite(piece)
    if line:
        edge = mask.filter(ImageFilter.MinFilter(line * 2 + 1 if line < 6 else 13))
        ring = Image.fromarray(((np.asarray(mask) > 127) & (np.asarray(edge) < 128)).astype(np.uint8) * 255)
        ink = Image.new("RGBA", layer.size, line_color)
        layer.paste(ink, (0, 0), ring.filter(ImageFilter.GaussianBlur(0.8)))


def poly(points):
    return lambda d, v: d.polygon([tuple(p) for p in points], fill=v)


def ellipse(box):
    return lambda d, v: d.ellipse(box, fill=v)


def rrect(box, r):
    return lambda d, v: d.rounded_rectangle(box, radius=r, fill=v)


def sticker(layer, width=16, color=INK):
    """A thick dark outline round the whole silhouette, behind it."""
    alpha = np.asarray(layer.getchannel("A"))
    dist = ndimage.distance_transform_edt(alpha < 100)
    ring = Image.fromarray((np.clip(width + 1 - dist, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", layer.size, color), (0, 0), ring)
    out.alpha_composite(layer)
    return out


def text(layer, xy, s, size, color, stroke=0, anchor="mm", squash=1.0, angle=0.0):
    f = font(size)
    tmp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((S / 2, S / 2), s, font=f, fill=color, anchor="mm", stroke_width=stroke, stroke_fill=INK)
    if squash != 1.0:
        tmp = tmp.resize((S, max(1, int(S * squash))), Image.LANCZOS)
        pad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        pad.paste(tmp, (0, (S - tmp.height) // 2))
        tmp = pad
    if angle:
        tmp = tmp.rotate(angle, resample=Image.BICUBIC)
    layer.alpha_composite(tmp, (int(xy[0] - S / 2), int(xy[1] - S / 2)))


def gloss(layer, draw_shape, alpha=70):
    """A white sheen over the top part of a shape."""
    mask = Image.new("L", layer.size, 0)
    draw_shape(ImageDraw.Draw(mask), alpha)
    sheet = Image.new("RGBA", layer.size, (255, 255, 255, 255))
    layer.paste(sheet, (0, 0), Image.fromarray(np.minimum(np.asarray(mask), np.asarray(layer.getchannel("A")))))


def sparkle(layer, x, y, r, color=(255, 255, 255, 255)):
    d = ImageDraw.Draw(layer)
    pts = []
    for k in range(8):
        ang = k * math.pi / 4 - math.pi / 2
        rr = r if k % 2 == 0 else r * 0.24
        pts.append((x + rr * math.cos(ang), y + rr * math.sin(ang)))
    glow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([x - r * 0.7, y - r * 0.7, x + r * 0.7, y + r * 0.7], fill=(255, 250, 200, 140))
    layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(r * 0.35)))
    d.polygon(pts, fill=color)


# ---------------------------------------------------------------- bundles of bills, as real 3D boxes
# A bundle is a box (length x thickness x depth) seen by a camera looking down at PITCH, without
# perspective. Each bundle draws only the faces that point at the camera (its top bill, its front
# edge and whichever end is turned toward you), and a pile is drawn back to front, so the sides
# are always the right ones.
PITCH = math.radians(40)
TOWARD = np.array([0.0, math.sin(PITCH), math.cos(PITCH)])  # from the scene toward the camera
LIGHT = np.array([-0.5, 1.0, 0.65]) / np.linalg.norm([-0.5, 1.0, 0.65])
BUNDLE = np.array([1.0, 0.38, 0.52])  # length, thickness, depth (in bundle lengths)
STACK = BUNDLE[1] / 0.3  # piles are laid out for 0.3-thick bundles: their heights scale by this
EDGE = (28, 96, 4, 255)  # the darker green lines between a bundle's faces


def project(p):
    """3D (x right, y up, z toward you) to the picture (x right, y down), 1 unit = 1 pixel."""
    return np.array([p[0], p[2] * math.sin(PITCH) - p[1] * math.cos(PITCH)])


def rot_y(deg):  # turns a bundle on the spot: positive takes its right end away from you
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]])


def rot_x(deg):  # tips a bundle about its length: positive tips its top toward you
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1.0, 0.0, 0.0], [0.0, c, -s], [0.0, s, c]])


def on_plane(layer, tex, o, u, v):
    """Maps tex's rectangle onto the parallelogram o, o+u, o+v."""
    w, h = tex.size
    m = np.array([[u[0], v[0]], [u[1], v[1]]], float)
    mi = np.linalg.inv(m)
    a, b = w * mi[0, 0], w * mi[0, 1]
    c = -(a * o[0] + b * o[1])
    d, e = h * mi[1, 0], h * mi[1, 1]
    f = -(d * o[0] + e * o[1])
    layer.alpha_composite(tex.transform(layer.size, Image.AFFINE, (a, b, c, d, e, f), resample=Image.BICUBIC))


def bill_top(band=True):
    """The top bill: lime, a darker rim with a pale line inside it, darker corner circles, and the
    cream paper band with a big yellow $ on it (a loose bill has the $ in the middle instead)."""
    w, h = 400, 200
    tex = vgrad((w, h), LIME_HI, LIME)
    d = ImageDraw.Draw(tex)
    d.rectangle([0, 0, w - 1, h - 1], outline=LEAF, width=12)
    d.rectangle([20, 20, w - 21, h - 21], outline=(226, 252, 130), width=4)
    r = 46
    for cx, cy in ((0, 0), (w, 0), (0, h), (w, h)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(126, 204, 16), outline=LEAF, width=8)
    if not band:
        d.ellipse([w / 2 - 58, h / 2 - 58, w / 2 + 58, h / 2 + 58], fill=(214, 248, 70), outline=LEAF, width=8)
        d.text((w / 2, h / 2 + 4), "$", font=font(96), fill=LEAF, anchor="mm")
        return tex
    x0, x1 = int(w * BAND[0]), int(w * BAND[1])
    tex.paste(vgrad((x1 - x0, h), CREAM_HI, CREAM), (x0, 0))
    d = ImageDraw.Draw(tex)
    d.rectangle([x0, 0, x0 + 6, h], fill=BAND_EDGE)
    d.rectangle([x1 - 6, 0, x1, h], fill=BAND_EDGE)
    cx = (x0 + x1) / 2
    d.text((cx + 4, h / 2 + 12), "$", font=font(150), fill=(34, 110, 6), anchor="mm", stroke_width=11, stroke_fill=(34, 110, 6))
    d.text((cx, h / 2 + 4), "$", font=font(150), fill=YELLOW, anchor="mm", stroke_width=9, stroke_fill=(30, 104, 4))
    return tex


def bill_side(w, band, layers=4):
    """The stacked bills seen side on: chunky lime layers, each with a bright top, a darker body and
    a dark line under it, and the cream band folded round (`band` is where it sits, or None)."""
    h = 125
    tex = Image.new("RGBA", (w, h), MONEY_INK)
    d = ImageDraw.Draw(tex)
    lh = h / layers
    for k in range(layers):
        y0 = k * lh
        d.rectangle([0, y0, w, y0 + lh], fill=LIME_LO)
        d.rectangle([0, y0, w, y0 + lh * 0.3], fill=LIME_HI)
        d.rectangle([0, y0 + lh * 0.3, w, y0 + lh * 0.58], fill=LIME)
        d.rectangle([0, y0 + lh * 0.8, w, y0 + lh], fill=(28, 98, 2))
    if band:
        x0, x1 = int(w * band[0]), int(w * band[1])
        tex.paste(vgrad((x1 - x0, h), CREAM, CREAM_LO), (x0, 0))
        d = ImageDraw.Draw(tex)
        d.rectangle([x0, 0, x0 + 6, h], fill=BAND_EDGE)
        d.rectangle([x1 - 6, 0, x1, h], fill=BAND_EDGE)
        d.rectangle([x0, h * 0.5 - 3, x1, h * 0.5 + 3], fill=BAND_EDGE)  # where the band''s ends meet
        d.rectangle([x0 + 10, h * 0.5 + 6, x1 - 10, h * 0.5 + 12], fill=CREAM_HI)
    return tex

TEXTURES = {
    "top": bill_top(),
    "front": bill_side(400, BAND),
    "back": bill_side(400, (1 - BAND[1], 1 - BAND[0])),
    "end": bill_side(200, None),
}


def faces(hl, hh, hw):
    """Each face: its outward normal, a corner, the two edges from it, and its texture."""
    return [
        ((0, 1, 0), (-hl, hh, -hw), (2 * hl, 0, 0), (0, 0, 2 * hw), "top"),
        ((0, -1, 0), (-hl, -hh, hw), (2 * hl, 0, 0), (0, 0, -2 * hw), "top"),
        ((0, 0, 1), (-hl, hh, hw), (2 * hl, 0, 0), (0, -2 * hh, 0), "front"),
        ((0, 0, -1), (hl, hh, -hw), (-2 * hl, 0, 0), (0, -2 * hh, 0), "back"),
        ((-1, 0, 0), (-hl, hh, -hw), (0, 0, 2 * hw), (0, -2 * hh, 0), "end"),
        ((1, 0, 0), (hl, hh, hw), (0, 0, -2 * hw), (0, -2 * hh, 0), "end"),
    ]


def draw_bundle(layer, origin, scale, pos, R):
    hl, hh, hw = BUNDLE / 2
    piece = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    quads = []
    for n, corner, e1, e2, kind in faces(hl, hh, hw):
        normal = R @ np.array(n, float)
        if normal @ TOWARD < 0.03:
            continue  # facing away (or edge on): hidden
        p0 = origin + project(pos + R @ np.array(corner, float)) * scale
        pu = project(R @ np.array(e1, float)) * scale
        pv = project(R @ np.array(e2, float)) * scale
        on_plane(piece, TEXTURES[kind], p0, pu, pv)
        quad = [p0, p0 + pu, p0 + pu + pv, p0 + pv]
        light = 0.78 + 0.22 * max(0.0, float(normal @ LIGHT))
        if light < 0.99:
            shade = Image.new("RGBA", layer.size, (0, 0, 0, 0))
            ImageDraw.Draw(shade).polygon([tuple(p) for p in quad], fill=(0, 30, 0, int((1 - light) * 255)))
            piece.alpha_composite(shade)
        quads.append(quad)
    d = ImageDraw.Draw(piece)
    for quad in quads:
        d.line([tuple(p) for p in quad] + [tuple(quad[0])], fill=EDGE, width=max(3, int(scale * 0.012)), joint="curve")
    # Soft rounded corners, like a real wad of bills, and a dark outline of its own (so it stands out
    # from the bundles behind it).
    alpha = np.asarray(piece.getchannel("A")) > 40
    r = max(2, int(scale * 0.06))
    yy, xx = np.ogrid[-r : r + 1, -r : r + 1]
    rounded = ndimage.binary_opening(alpha, structure=(xx * xx + yy * yy) <= r * r)
    soft = np.asarray(Image.fromarray((rounded * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)))
    piece.putalpha(Image.fromarray(np.minimum(np.asarray(piece.getchannel("A")), soft)))
    width = max(3, int(scale * 0.03))
    dist = ndimage.distance_transform_edt(~rounded)
    ring = Image.fromarray((np.clip(width + 1 - dist, 0, 1) * 255).astype(np.uint8))
    layer.paste(Image.new("RGBA", layer.size, MONEY_INK), (0, 0), ring)
    layer.alpha_composite(piece)


def scene(layer, items, cx, cy, size, pile_yaw=0.0, fit=420):
    """Bundles in 3D: (position in bundle lengths, yaw, tilt) each, the whole pile turned by
    pile_yaw, drawn back to front with each bundle `size` pixels long (less if the pile would be
    wider or taller than `fit`) and the pile centred on (cx, cy)."""
    turn = rot_y(pile_yaw)
    placed = [
        (turn @ (np.array(pos, float) * np.array([1.0, STACK, 1.0])), rot_y(pile_yaw + yaw) @ rot_x(tilt))
        for pos, yaw, tilt in items
    ]
    hl, hh, hw = BUNDLE / 2
    points = [
        project(pos + R @ np.array([sx * hl, sy * hh, sz * hw]))
        for pos, R in placed
        for sx in (-1, 1)
        for sy in (-1, 1)
        for sz in (-1, 1)
    ]
    points = np.array(points)
    extent = points.max(axis=0) - points.min(axis=0)
    size = min(size, fit / float(extent.max()))
    middle = (points.min(axis=0) + points.max(axis=0)) / 2
    origin = np.array([cx, cy], float) - middle * size
    for pos, R in sorted(placed, key=lambda item: float(item[0] @ TOWARD)):
        draw_bundle(layer, origin, size, pos, R)


def bundle_at(layer, cx, cy, size, yaw=20.0, tilt=0.0):
    """One bundle centred on (cx, cy)."""
    scene(layer, [((0, 0, 0), yaw, tilt)], cx, cy, size)

# ---------------------------------------------------------------- coins
def coin(layer, cx, cy, r, thick=22, squash=0.42, glyph="C"):
    ry = r * squash
    def body(d, v):
        d.ellipse([cx - r, cy - ry + thick, cx + r, cy + ry + thick], fill=v)
        d.rectangle([cx - r, cy, cx + r, cy + thick], fill=v)
    fill(layer, body, GOLD_LO, (150, 92, 10), line=5)
    fill(layer, ellipse([cx - r, cy - ry, cx + r, cy + ry]), GOLD_HI, GOLD, line=5)
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r * 0.74, cy - ry * 0.74, cx + r * 0.74, cy + ry * 0.74], outline=GOLD_LO, width=5)
    if glyph:
        text(layer, (cx, cy + 2), glyph, r * 1.05, (205, 135, 18), squash=squash)


def coin_stack(layer, cx, base, r, count, thick=20):
    for k in range(count):
        coin(layer, cx + (k % 2) * 3 - 1, base - k * thick, r, thick, glyph="C" if k == count - 1 else "")


def coin_face(layer, cx, cy, r, glyph="C", rim=None):
    fill(layer, ellipse([cx - r, cy - r, cx + r, cy + r]), GOLD_HI, GOLD_LO, line=6)
    inner = r * 0.8
    fill(layer, ellipse([cx - inner, cy - inner, cx + inner, cy + inner]), GOLD, GOLD_HI, line=5, line_color=GOLD_LO + (255,))
    if glyph:
        text(layer, (cx, cy + r * 0.04), glyph, r * 1.1, (200, 128, 16))
    gloss(layer, ellipse([cx - r * 0.7, cy - r * 0.85, cx + r * 0.3, cy - r * 0.15]), 90)


# ---------------------------------------------------------------- the pictures
def save(layer, name, outline=16, color=INK):
    alpha = np.asarray(layer.getchannel("A"))
    m = outline + 2  # the outline needs this much room round the drawing
    if alpha[:m].max() > 20 or alpha[-m:].max() > 20 or alpha[:, :m].max() > 20 or alpha[:, -m:].max() > 20:
        print("TOO CLOSE to the canvas edge:", name, layer.getbbox())
    art = sticker(layer, outline, color)
    # Fit the drawing to the square (a little margin), whatever its shape.
    x0, y0, x1, y1 = art.getbbox()
    side = max(x1 - x0, y1 - y0) * 1.06
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    square = Image.new("RGBA", (int(side), int(side)), (0, 0, 0, 0))
    square.alpha_composite(art.crop((x0, y0, x1, y1)), (int(cx - x0 - (x1 - x0) / 2 + side / 2 - (x1 - x0) / 2), int(side / 2 - (y1 - y0) / 2)))
    art = square.resize((256, 256), Image.LANCZOS)
    art.save(os.path.join(OUT, name + ".png"))
    return art


def cred_100():
    l = new()
    bundle_at(l, 256, 256, 400, 20)
    save(l, "Cred100")


def cred_500():
    l = new()
    # Two bundles stacked, and a third leaning against the front of them.
    scene(l, [((0, 0, 0), 0, 0), ((0.07, 0.3, -0.03), -7, 0), ((0.38, 0.13, 0.43), 10, -60)], 256, 256, 340, 20)
    save(l, "Cred500")


def cred_1000():
    l = new()
    # A pyramid: two bundles side by side, two on top of them, one on top of those.
    scene(
        l,
        [
            ((-0.05, 0, -0.28), 0, 0),
            ((0.06, 0, 0.28), 0, 0),
            ((0.03, 0.3, -0.27), 4, 0),
            ((-0.04, 0.3, 0.28), -3, 0),
            ((0.04, 0.6, 0.0), 3, 0),
        ],
        256,
        256,
        330,
        20,
    )
    save(l, "Cred1000")

def sack(l, cx, top, color_hi, color_lo, emblem, emblem_color, rope=GOLD):
    body = [cx - 175, top + 120, cx + 175, top + 400]
    neck = [(cx - 70, top + 90), (cx + 70, top + 90), (cx + 120, top + 170), (cx - 120, top + 170)]
    def shape(d, v):
        d.ellipse(body, fill=v)
        d.polygon(neck, fill=v)
    fill(l, shape, color_hi, color_lo, line=6)
    frill = [(cx - 50, top + 92), (cx - 115, top + 20), (cx - 60, top + 40), (cx - 20, top + 5), (cx + 20, top + 38),
             (cx + 70, top + 8), (cx + 110, top + 40), (cx + 50, top + 92)]
    fill(l, poly(frill), color_hi, color_lo, line=6)
    fill(l, rrect([cx - 82, top + 78, cx + 82, top + 112], 16), GOLD_HI, rope, line=5)
    fill(l, ellipse([cx + 40, top + 90, cx + 92, top + 150]), GOLD_HI, rope, line=5)
    text(l, (cx, top + 275), emblem, 190, emblem_color, stroke=0)
    gloss(l, ellipse([cx - 150, top + 140, cx - 20, top + 260]), 80)


def cred_5000():
    l = new()
    bundle_at(l, 200, 105, 175, 35, -35)  # poking out of the top of the bag
    bundle_at(l, 305, 90, 165, -12, -40)
    sack(l, 250, 60, (255, 255, 255), (205, 228, 214), "$", (30, 170, 40))
    bundle_at(l, 140, 408, 150, 18)  # and on the ground in front of it
    bundle_at(l, 378, 414, 138, 30)
    save(l, "Cred5000")


def safe(l, x0, y0, w, h, side=60):
    front = [(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)]
    top = [(x0, y0), (x0 + side, y0 - side * 0.6), (x0 + w + side, y0 - side * 0.6), (x0 + w, y0)]
    right = [(x0 + w, y0), (x0 + w + side, y0 - side * 0.6), (x0 + w + side, y0 + h - side * 0.6), (x0 + w, y0 + h)]
    fill(l, poly(top), (120, 126, 140), (90, 96, 110), line=6)
    fill(l, poly(right), (60, 64, 76), (40, 42, 52), line=6)
    fill(l, poly(front), (96, 102, 116), (52, 56, 68), line=6)
    inner = [x0 + 26, y0 + 26, x0 + w - 26, y0 + h - 26]
    fill(l, rrect(inner, 10), (22, 22, 28), (36, 36, 44), line=6)
    return inner


def cred_25000():
    l = new()
    inner = safe(l, 70, 120, 290, 300)
    # Bundles stacked up inside.
    scene(l, [((0, 0, 0), 0, 0), ((0.04, 0.3, 0.0), 3, 0), ((-0.03, 0.6, 0.0), -3, 0)], 215, 275, 185, 8)
    # The door, swung open to the right.
    door = [(360, 120), (470, 160), (470, 450), (360, 420)]
    fill(l, poly(door), (110, 116, 130), (60, 64, 76), line=6)
    fill(l, ellipse([385, 245, 455, 315]), GOLD_HI, GOLD_LO, line=5)
    d = ImageDraw.Draw(l)
    for k in range(8):
        ang = k * math.pi / 4
        d.line([(420, 280), (420 + 30 * math.cos(ang), 280 + 30 * math.sin(ang))], fill=GOLD_LO, width=5)
    d.ellipse([408, 268, 432, 292], fill=INK)
    bundle_at(l, 145, 408, 160, 14)  # and spilling out in front
    bundle_at(l, 330, 410, 148, 32)
    save(l, "Cred25000")


def chest(l, cx, base):
    w, h = 340, 170
    x0, y0 = cx - w / 2, base - h
    lid = [(x0 - 6, y0), (x0 + 20, y0 - 150), (x0 + w - 20, y0 - 150), (x0 + w + 6, y0)]
    fill(l, poly(lid), (150, 92, 50), (108, 62, 32), line=6)
    fill(l, poly([(x0 + 30, y0 - 10), (x0 + 42, y0 - 130), (x0 + w - 42, y0 - 130), (x0 + w - 30, y0 - 10)]),
         (70, 38, 22), (96, 56, 30), line=5)
    # The heap of coins and gems.
    fill(l, ellipse([x0 - 10, y0 - 90, x0 + w + 10, y0 + 70]), GOLD_HI, GOLD, line=6)
    bundle_at(l, x0 + 95, y0 - 45, 170, 28, -22)
    bundle_at(l, x0 + 250, y0 - 50, 165, -14, -26)
    bundle_at(l, x0 + 170, y0 - 95, 160, 12, -32)
    for cxx, cyy, r in [(x0 + 60, y0 + 18, 38), (x0 + 290, y0 + 10, 40)]:
        coin(l, cxx, cyy, r, 12, 0.45, glyph="$")
    for gx, gy, col in [(x0 + 200, y0 - 85, (230, 50, 70)), (x0 + 95, y0 - 70, (60, 140, 240)), (x0 + 285, y0 - 75, (70, 210, 110))]:
        fill(l, poly([(gx, gy - 26), (gx + 22, gy), (gx, gy + 26), (gx - 22, gy)]), (255, 255, 255), col, line=4)
    front = [x0, y0, x0 + w, base]
    fill(l, rrect(front, 14), (160, 100, 54), (110, 64, 34), line=6)
    for bx in (x0 + 40, x0 + w - 60):
        fill(l, rrect([bx, y0, bx + 20, base], 4), GOLD_HI, GOLD_LO, line=4)
    fill(l, rrect([cx - 32, y0 + 30, cx + 32, y0 + 96], 10), GOLD_HI, GOLD_LO, line=5)
    ImageDraw.Draw(l).ellipse([cx - 10, y0 + 50, cx + 10, y0 + 70], fill=INK)


def cred_100000():
    l = new()
    bundle_at(l, 150, 220, 150, 30, -40)  # behind the chest
    bundle_at(l, 368, 206, 140, -20, -40)
    chest(l, 256, 450)
    bundle_at(l, 135, 420, 145, 14)  # and in front of it
    bundle_at(l, 385, 418, 135, 32)
    sparkle(l, 70, 90, 34)
    sparkle(l, 450, 70, 28)
    sparkle(l, 470, 300, 22)
    save(l, "Cred100000")


def medallion(l, inner_draw, label="x2"):
    cx, cy, r = 240, 236, 200
    fill(l, ellipse([cx - r, cy - r, cx + r, cy + r]), GOLD_HI, GOLD_LO, line=6)
    d = ImageDraw.Draw(l)
    for k in range(48):  # the rim's ridges
        ang = k * math.pi / 24
        d.line([(cx + (r - 6) * math.cos(ang), cy + (r - 6) * math.sin(ang)), (cx + (r - 22) * math.cos(ang), cy + (r - 22) * math.sin(ang))],
               fill=GOLD_LO, width=4)
    ri = r - 34
    fill(l, ellipse([cx - ri, cy - ri, cx + ri, cy + ri]), (255, 214, 70), (236, 160, 26), line=6)
    inner_draw(l, cx, cy)
    gloss(l, ellipse([cx - r * 0.75, cy - r * 0.9, cx + r * 0.2, cy - r * 0.2]), 70)
    if label:
        text(l, (cx + 130, cy + 140), label, 150, (255, 230, 120), stroke=12, angle=8)
    sparkle(l, cx - 150, cy - 160, 30)
    sparkle(l, cx + 190, cy - 120, 22)


def pass_double_cash():
    l = new()
    medallion(l, lambda l, cx, cy: bundle_at(l, cx - 5, cy + 5, 255, 20))
    save(l, "PassDoubleCash")


def clover(l, cx, cy, r):
    d = ImageDraw.Draw(l)
    d.line([(cx, cy), (cx + r * 0.4, cy + r * 1.3)], fill=INK, width=22)
    d.line([(cx, cy), (cx + r * 0.4, cy + r * 1.3)], fill=(60, 150, 50), width=12)
    for ang in (45, 135, 225, 315):
        a = math.radians(ang)
        lx, ly = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
        def leaf(dd, v, lx=lx, ly=ly):
            dd.ellipse([lx - r * 0.5, ly - r * 0.5, lx + r * 0.5, ly + r * 0.5], fill=v)
        fill(l, leaf, (130, 230, 90), (40, 150, 50), line=6)
    gloss(l, ellipse([cx - r * 0.9, cy - r * 0.9, cx - r * 0.1, cy - r * 0.3]), 70)


def pass_double_luck():
    l = new()
    medallion(l, lambda l, cx, cy: clover(l, cx - 10, cy - 20, 120))
    save(l, "PassDoubleLuck")


def pass_double_cred():
    l = new()
    def inner(l, cx, cy):
        coin_face(l, cx - 10, cy - 10, 105)
    medallion(l, inner)
    save(l, "PassDoubleCred")


def duffel(l, cx, cy, w=380, h=210):
    x0, y0 = cx - w / 2, cy - h / 2
    d = ImageDraw.Draw(l)
    d.arc([cx - 120, y0 - 120, cx + 120, y0 + 80], 200, 340, fill=INK, width=30)
    d.arc([cx - 120, y0 - 120, cx + 120, y0 + 80], 200, 340, fill=(60, 60, 70), width=16)
    fill(l, rrect([x0, y0, x0 + w, y0 + h], 90), (78, 78, 92), (26, 26, 32), line=6)
    for ex in (x0, x0 + w - 70):
        fill(l, ellipse([ex, y0 + 14, ex + 70, y0 + h - 14]), (56, 56, 66), (20, 20, 26), line=5)
    d.line([(x0 + 90, y0 + 40), (x0 + w - 90, y0 + 40)], fill=GOLD, width=8)
    gloss(l, rrect([x0 + 60, y0 + 14, x0 + w - 60, y0 + 70], 30), 50)


def pass_mega_bag():
    l = new()
    bundle_at(l, 200, 175, 190, 28, -32)
    bundle_at(l, 315, 160, 180, -14, -34)
    duffel(l, 256, 300)
    text(l, (256, 330), "MEGA", 70, (255, 214, 70), stroke=8)
    sparkle(l, 440, 130, 30)
    save(l, "PassMegaBag")


def pass_fat_stack():
    l = new()
    scene(
        l,
        [((0, 0, 0), 0, 0), ((0.05, 0.3, 0.02), 4, 0), ((-0.03, 0.6, -0.01), -4, 0), ((0.04, 0.9, 0.0), 5, 0)],
        256,
        256,
        330,
        20,
    )
    sparkle(l, 430, 110, 32)
    save(l, "PassFatStack")


def pass_tip_jar():
    l = new()
    x0, y0, x1, y1 = 110, 150, 400, 470
    fill(l, rrect([x0, y0, x1, y1], 60), (215, 240, 250), (170, 210, 230), line=6)
    for cx, cy, r in [(190, 420, 58), (300, 425, 56), (250, 370, 54), (180, 350, 46), (320, 350, 46)]:
        coin(l, cx, cy, r, 12, 0.45, glyph="$")
    bundle_at(l, 255, 285, 190, 24, -22)
    glass = Image.new("RGBA", l.size, (0, 0, 0, 0))
    ImageDraw.Draw(glass).rounded_rectangle([x0, y0, x1, y1], radius=60, fill=(220, 245, 255, 70))
    l.alpha_composite(glass)
    ImageDraw.Draw(l).rounded_rectangle([x0, y0, x1, y1], radius=60, outline=INK, width=8)
    gloss(l, rrect([x0 + 24, y0 + 30, x0 + 70, y1 - 60], 20), 110)
    fill(l, rrect([x0 - 14, y0 - 50, x1 + 14, y0 + 6], 18), (180, 120, 70), (120, 74, 40), line=6)
    fill(l, rrect([x0 + 40, y0 + 120, x1 - 40, y0 + 200], 14), (255, 255, 255), (230, 230, 220), line=5)
    text(l, ((x0 + x1) / 2, y0 + 162), "TIPS", 64, (60, 150, 60))
    save(l, "PassTipJar")


def pass_bail():
    l = new()
    fill(l, ellipse([90, 380, 420, 470]), (160, 100, 54), (100, 60, 30), line=6)
    fill(l, rrect([90, 345, 420, 425], 40), (180, 116, 64), (120, 72, 36), line=6)
    fill(l, ellipse([90, 330, 420, 410]), (200, 138, 80), (160, 100, 54), line=6)
    handle = Image.new("RGBA", l.size, (0, 0, 0, 0))
    fill(handle, rrect([232, 120, 272, 400], 18), (200, 140, 80), (130, 80, 40), line=6)
    l.alpha_composite(handle.rotate(-38, center=(252, 260), resample=Image.BICUBIC))
    head = Image.new("RGBA", l.size, (0, 0, 0, 0))
    fill(head, rrect([130, 80, 380, 190], 40), (170, 108, 60), (100, 58, 28), line=6)
    for bx in (170, 320):
        fill(head, rrect([bx, 74, bx + 26, 196], 8), GOLD_HI, GOLD_LO, line=4)
    gloss(head, rrect([150, 92, 360, 130], 20), 70)
    l.alpha_composite(head.rotate(-38, center=(255, 260), resample=Image.BICUBIC))
    sparkle(l, 430, 110, 30)
    save(l, "PassBail")


def pass_clean():
    l = new()
    shield = [(256, 50), (430, 110), (410, 300), (256, 470), (102, 300), (82, 110)]
    fill(l, poly(shield), GOLD_HI, GOLD_LO, line=6)
    inner = [(256, 92), (392, 138), (376, 290), (256, 426), (136, 290), (120, 138)]
    fill(l, poly(inner), (110, 190, 255), (40, 100, 220), line=6)
    d = ImageDraw.Draw(l)
    d.line([(178, 262), (238, 322), (346, 196)], fill=INK, width=58, joint="curve")
    d.line([(178, 262), (238, 322), (346, 196)], fill=(255, 255, 255), width=36, joint="curve")
    gloss(l, poly([(130, 150), (256, 108), (256, 250), (140, 250)]), 60)
    sparkle(l, 430, 70, 32)
    sparkle(l, 90, 420, 24)
    save(l, "PassClean")


def crown(l, cx, cy, w=360, h=230):
    x0, y0 = cx - w / 2, cy - h / 2
    pts = [(x0, y0 + 40), (x0 + w * 0.25, y0 + 130), (x0 + w * 0.5, y0), (x0 + w * 0.75, y0 + 130), (x0 + w, y0 + 40),
           (x0 + w - 30, y0 + h), (x0 + 30, y0 + h)]
    fill(l, poly(pts), GOLD_HI, GOLD_LO, line=6)
    fill(l, rrect([x0 + 20, y0 + h - 60, x0 + w - 20, y0 + h + 10], 14), GOLD, GOLD_LO, line=6)
    for k, col in enumerate([(230, 50, 70), (60, 140, 240), (230, 50, 70)]):
        gx = x0 + w * (0.25 + 0.25 * k)
        fill(l, ellipse([gx - 20, y0 + h - 46, gx + 20, y0 + h - 6]), (255, 255, 255), col, line=4)
    for tx, ty in [(x0, y0 + 40), (x0 + w * 0.5, y0), (x0 + w, y0 + 40)]:
        fill(l, ellipse([tx - 24, ty - 24, tx + 24, ty + 24]), GOLD_HI, GOLD_LO, line=5)
    gloss(l, poly([(x0 + 40, y0 + 60), (x0 + w * 0.5, y0 + 30), (x0 + w * 0.5, y0 + 150), (x0 + 50, y0 + 150)]), 60)


def pass_vip():
    l = new()
    crown(l, 256, 220)
    fill(l, rrect([136, 330, 376, 440], 30), (150, 70, 230), (90, 30, 160), line=6)
    text(l, (256, 386), "VIP", 92, (255, 220, 80), stroke=8)
    sparkle(l, 80, 90, 32)
    sparkle(l, 450, 120, 26)
    save(l, "PassVip")


def pass_big_baller():
    l = new()
    bundle_at(l, 195, 115, 180, 32, -36)
    bundle_at(l, 320, 100, 170, -14, -38)
    sack(l, 256, 60, (255, 240, 140), (220, 150, 20), "$", (60, 150, 60), rope=(200, 60, 60))
    coin_stack(l, 90, 445, 60, 3, 18)
    coin_stack(l, 430, 445, 56, 2, 18)
    sparkle(l, 70, 230, 30)
    sparkle(l, 455, 210, 26)
    save(l, "PassBigBaller")


def pass_rainbow():
    l = new()
    x0, y0, x1, y1 = 90, 220, 422, 470
    stripes = [(255, 70, 80), (255, 160, 40), (255, 230, 60), (90, 210, 90), (70, 150, 255), (170, 100, 255)]
    box = Image.new("RGBA", l.size, (0, 0, 0, 0))
    db = ImageDraw.Draw(box)
    sw = (x1 - x0) / len(stripes)
    for k, col in enumerate(stripes):
        db.rectangle([x0 + k * sw, y0, x0 + (k + 1) * sw + 1, y1], fill=col + (255,))
    mask = Image.new("L", l.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0, y0, x1, y1], radius=24, fill=255)
    piece = Image.new("RGBA", l.size, (0, 0, 0, 0))
    piece.paste(box, (0, 0), mask)
    l.alpha_composite(piece)
    ImageDraw.Draw(l).rounded_rectangle([x0, y0, x1, y1], radius=24, outline=INK, width=8)
    fill(l, rrect([x0 - 20, y0 - 50, x1 + 20, y0 + 30], 22), (255, 255, 255), (220, 220, 235), line=6)
    fill(l, rrect([228, y0 - 50, 284, y1], 10), GOLD_HI, GOLD_LO, line=5)
    for side in (-1, 1):
        loop = [(256, y0 - 50), (256 + side * 130, y0 - 150), (256 + side * 150, y0 - 60)]
        fill(l, poly(loop), GOLD_HI, GOLD_LO, line=6)
    fill(l, ellipse([226, y0 - 80, 286, y0 - 20]), GOLD_HI, GOLD_LO, line=5)
    gloss(l, rrect([x0 + 10, y0 + 40, x0 + 120, y1 - 20], 20), 60)
    sparkle(l, 70, 120, 32)
    sparkle(l, 450, 110, 28)
    sparkle(l, 460, 380, 22)
    save(l, "PassRainbow")


# ---------------------------------------------------------------- flat icons (white with a dark outline)
def flat(name, draw, outline=18):
    l = new()
    draw(ImageDraw.Draw(l), l)
    save(l, name, outline)


def icon_robux(d, l):
    pts = [(256 + 200 * math.cos(math.radians(a)), 256 + 200 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    d.polygon(pts, fill=(255, 255, 255, 255))
    hole = [(256 + 92 * math.cos(math.radians(a)), 256 + 92 * math.sin(math.radians(a))) for a in range(-45, 315, 90)]
    d.polygon(hole, fill=(0, 0, 0, 0))
    d.polygon(hole, outline=INK, width=16)


def icon_gift(d, l):
    w = (255, 255, 255, 255)
    d.rounded_rectangle([100, 230, 412, 460], radius=18, fill=w)
    d.rounded_rectangle([76, 160, 436, 240], radius=18, fill=w)
    d.rectangle([96, 240, 416, 252], fill=INK)
    d.rectangle([228, 160, 284, 460], fill=INK)
    d.rectangle([240, 160, 272, 460], fill=w)
    for side in (-1, 1):
        d.ellipse([256 + side * 30 - 70, 70, 256 + side * 30 + 70, 170], outline=INK, width=26)
        d.ellipse([256 + side * 30 - 58, 82, 256 + side * 30 + 58, 158], outline=w, width=12)


def icon_cart(d, l):
    w = (255, 255, 255, 255)
    d.line([(40, 110), (112, 110), (168, 340), (410, 340)], fill=w, width=44, joint="curve")
    d.polygon([(122, 160), (470, 160), (430, 300), (156, 300)], fill=w)
    d.rounded_rectangle([140, 270, 440, 312], radius=20, fill=w)
    for x in (190, 380):
        d.ellipse([x - 46, 370, x + 46, 462], fill=w, outline=INK, width=12)

def icon_arrow(d, l):
    w = (255, 255, 255, 255)
    d.polygon([(256, 50), (460, 270), (340, 270), (340, 460), (172, 460), (172, 270), (52, 270)], fill=w)


def icon_brush(d, l):
    w = (255, 255, 255, 255)
    tip = Image.new("RGBA", l.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tip)
    td.rounded_rectangle([220, 40, 292, 300], radius=30, fill=w)
    td.rectangle([206, 290, 306, 350], fill=w)
    td.rectangle([206, 310, 306, 322], fill=INK)
    td.polygon([(206, 350), (306, 350), (330, 450), (256, 490), (182, 450)], fill=(255, 92, 147, 255))
    l.alpha_composite(tip.rotate(-35, center=(256, 270), resample=Image.BICUBIC))


def cred_icon():
    l = new()
    coin_face(l, 256, 256, 200)
    save(l, "CredCoin", 14)


# ---------------------------------------------------------------- the Shop's effects
def fit_wide(art, ratio, size):
    """Crops to the drawing and pads it out to width:height = ratio, sitting on the bottom edge."""
    art = art.crop(art.getbbox())
    w, h = art.size
    cw, ch = (w, int(w / ratio)) if w / h >= ratio else (int(h * ratio), h)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((cw - w) // 2, ch - h))
    return canvas.resize(size, Image.LANCZOS)


def loose_bill():
    """One loose bill (no band), for money raining down."""
    tex = bill_top(band=False)
    l = Image.new("RGBA", (tex.width + 60, tex.height + 60), (0, 0, 0, 0))
    l.alpha_composite(tex, (30, 30))
    alpha = np.asarray(l.getchannel("A")) > 40
    yy, xx = np.ogrid[-18:19, -18:19]
    rounded = ndimage.binary_opening(alpha, structure=(xx * xx + yy * yy) <= 18 * 18)
    l.putalpha(Image.fromarray((rounded * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)))
    fit_wide(sticker(l, 12, MONEY_INK), 2.0, (160, 80)).save(os.path.join(OUT, "Bill.png"))


BUNDLE_RATIO = 1.4  # every bundle picture is this wide for its height (the game sizes them by it)


def bundle_sprite(name, yaw, tilt=0.0):
    """One bundle on its own picture, sitting on the bottom edge (the money piles are built from
    these in the game)."""
    l = new()
    bundle_at(l, 256, 256, 400, yaw, tilt)
    art = fit_wide(sticker(l, 4, MONEY_INK), BUNDLE_RATIO, (280, 200))
    art.save(os.path.join(OUT, name + ".png"))


def money_sprites():
    loose_bill()
    bundle_sprite("Bundle", 22)
    bundle_sprite("BundleBack", -24)
    bundle_sprite("BundleUp", 8, 22)

def sparkle_star():
    """A white four-pointed sparkle with a soft glow (tinted in the game)."""
    l = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([176, 176, 336, 336], fill=(255, 255, 255, 170))
    l.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
    pts = []
    for k in range(8):
        ang = k * math.pi / 4 - math.pi / 2
        rr = 236 if k % 2 == 0 else 40
        pts.append((256 + rr * math.cos(ang), 256 + rr * math.sin(ang)))
    ImageDraw.Draw(l).polygon(pts, fill=(255, 255, 255, 255))
    l.resize((128, 128), Image.LANCZOS).save(os.path.join(OUT, "Sparkle.png"))


os.makedirs(OUT, exist_ok=True)
money_sprites()
sparkle_star()
for job in (cred_100, cred_500, cred_1000, cred_5000, cred_25000, cred_100000, pass_double_cash, pass_double_luck,
            pass_double_cred, pass_mega_bag, pass_fat_stack, pass_tip_jar, pass_bail, pass_clean, pass_vip,
            pass_big_baller, pass_rainbow, cred_icon):
    job()
flat("IconRobux", icon_robux)
flat("IconGift", icon_gift)
flat("IconCart", icon_cart)
flat("IconArrow", icon_arrow)
flat("IconBrush", icon_brush)

# The brick tile: an L in each cell (a lighter top-left on dark, a shade on colours).
tile = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
td = ImageDraw.Draw(tile)
td.rounded_rectangle([14, 14, 50, 50], radius=6, fill=(255, 255, 255, 70))
td.line([(16, 12), (16, 50), (54, 50)], fill=(255, 255, 255, 255), width=5)
tile.save(os.path.join(OUT, "Bricks.png"))

# A contact sheet to check them.
names = sorted(n for n in os.listdir(OUT) if n.endswith(".png") and n != "Bricks.png" and n != "sheet.png")
sheet = Image.new("RGBA", (6 * 260, ((len(names) + 5) // 6) * 290), (60, 190, 60, 255))
for k, n in enumerate(names):
    im = Image.open(os.path.join(OUT, n))
    sheet.alpha_composite(im, ((k % 6) * 260 + 2, (k // 6) * 290 + 2))
    ImageDraw.Draw(sheet).text(((k % 6) * 260 + 10, (k // 6) * 290 + 262), n, fill=(255, 255, 255, 255))
sheet.save(os.path.join(OUT, "sheet.png"))
print("drew", len(names), "pictures")
