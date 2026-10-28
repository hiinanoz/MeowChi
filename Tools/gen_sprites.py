#!/usr/bin/env python3
"""Generates TEMPORARY placeholder pixel-art sprites into the asset catalog.

These are NOT production artwork. Final sprites must follow docs/ASSETS.md and
keep the same asset names so they can be swapped without code changes.
Pure standard library (no Pillow). Run: python3 Tools/gen_sprites.py
"""
import json, pathlib, struct, zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Meowchi/Resources/Assets.xcassets"

K = (59, 38, 40, 255)      # outline
O = (242, 153, 74, 255)    # orange fur
D = (198, 94, 28, 255)     # stripes (kept far from OS so the shader can tell them apart)
W = (255, 247, 235, 255)   # white fur
P = (245, 160, 170, 255)   # pink
E = (40, 28, 30, 255)      # eyes
H = (255, 255, 255, 255)   # highlight
OS = (222, 120, 52, 255)   # orange shade
OL = (251, 188, 115, 255)  # orange light
WS = (236, 220, 204, 255)  # white shade


# Art is authored on a logical grid and rasterized SCALE times finer, so outlines and
# highlights come out 1 native pixel thick (64x64 cat from a 32-unit layout).
SCALE = 2


class Canvas:
    def __init__(self, w, h, s=SCALE):
        self.w, self.h, self.s = w, h, s          # logical size
        self.W, self.H = w * s, h * s             # native (PNG) size
        self.p = [[None] * self.W for _ in range(self.H)]

    def pset(self, X, Y, c):
        if 0 <= X < self.W and 0 <= Y < self.H:
            self.p[Y][X] = c

    def set(self, x, y, c):
        for dy in range(self.s):
            for dx in range(self.s):
                self.pset(int(x * self.s) + dx, int(y * self.s) + dy, c)

    def rect(self, x, y, w, h, c):
        for Y in range(int(y * self.s), int((y + h) * self.s)):
            for X in range(int(x * self.s), int((x + w) * self.s)):
                self.pset(X, Y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for Y in range(self.H):
            for X in range(self.W):
                if (((X + .5) / self.s - cx) / rx) ** 2 + (((Y + .5) / self.s - cy) / ry) ** 2 <= 1:
                    self.p[Y][X] = c

    def shaded_ellipse(self, cx, cy, rx, ry, base, shade, light=None):
        """Base fill with a 1px shade band on the lower right and an optional top-left highlight."""
        self.ellipse(cx, cy, rx, ry, shade)
        self.ellipse(cx - .4, cy - .5, rx - .3, ry - .4, base)
        if light:
            self.ellipse(cx - rx * .35, cy - ry * .45, rx * .35, ry * .25, light)

    def tri(self, a, b, c, col):
        def side(p, q, r):
            return (p[0] - r[0]) * (q[1] - r[1]) - (q[0] - r[0]) * (p[1] - r[1])
        for Y in range(self.H):
            for X in range(self.W):
                pt = ((X + .5) / self.s, (Y + .5) / self.s)
                d1, d2, d3 = side(pt, a, b), side(pt, b, c), side(pt, c, a)
                if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
                    self.p[Y][X] = col

    def outline(self, c=K):
        src = [row[:] for row in self.p]
        for Y in range(self.H):
            for X in range(self.W):
                if src[Y][X] is None and any(
                    0 <= X + dx < self.W and 0 <= Y + dy < self.H and src[Y + dy][X + dx] is not None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.p[Y][X] = c

    def stamp(self, rows, palette, ox=0, oy=0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in palette:
                    self.set(ox + x, oy + y, palette[ch])


def write_png(path, canvas, scale=1, background=None):
    w, h = canvas.W * scale, canvas.H * scale
    opaque = background is not None
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            c = canvas.p[y // scale][x // scale] or background or (0, 0, 0, 0)
            raw.extend(c[:3] if opaque else c)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2 if opaque else 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


INFO = {"info": {"author": "xcode", "version": 1}}


def save_image(folder, name, canvas):
    d = ASSETS / folder / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    write_png(d / f"{name}.png", canvas)
    (d / "Contents.json").write_text(json.dumps(
        {"images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}], **INFO}, indent=2))


# ---------- Cat (32x32, feet at bottom center) ----------

# The cat is three layers: body, ears and tail, each 32x32 logical with feet on the bottom row.
# Fur uses the KEY colors O/OS/OL/D; the game recolors them with a palette-swap shader, so
# one set of sprites serves every coat. Final art must use these exact key colors for fur.

EAR_STYLES = ("pointy", "round", "folded")
TAIL_LENGTHS = {"short": 3, "medium": 5, "long": 7}
TAIL_POSES = ("down", "wag0", "wag1", "up")


def face(c, hy, eyes, mouth):
    for ex in (11, 19):
        if eyes == "open":
            c.rect(ex, hy - 1, 2, 3, E); c.rect(ex, hy - 1, 1, 1, H); c.pset(ex * SCALE + 2, hy * SCALE + 3, H)
        elif eyes == "closed":
            c.rect(ex - 1, hy + 1, 4, 1, E)
        elif eyes == "happy":
            for dx, dy in ((-1, 1), (0, 0), (1, 0), (2, 1)):
                c.set(ex + dx, hy + dy, E)
        elif eyes == "sad":
            c.rect(ex, hy, 2, 2, E); c.set(ex, hy, H)
            c.set(ex - 1 if ex < 16 else ex + 2, hy - 2, E)
            c.set(ex if ex < 16 else ex + 1, hy - 2, E)
    c.rect(9, hy + 2, 2, 1, P); c.rect(21, hy + 2, 2, 1, P)
    c.rect(15, hy + 2, 2, 1, P)
    if mouth == "smile":
        for x, y in ((14, hy + 3), (15, hy + 4), (16, hy + 4), (17, hy + 3)):
            c.set(x, y, E)
    elif mouth == "open":
        c.rect(15, hy + 4, 2, 2, P); c.set(14, hy + 4, E); c.set(17, hy + 4, E)
    elif mouth == "flat":
        c.rect(15, hy + 4, 2, 1, E)


def body_front(eyes="open", mouth="smile", breath=0, head_dy=0):
    c = Canvas(32, 32)
    c.shaded_ellipse(16, 24, 7, 6 + breath * .5, O, OS)
    c.shaded_ellipse(16, 25, 4, 4.5, W, WS)
    c.shaded_ellipse(12.5, 29, 2.5, 1.6, W, WS)
    c.shaded_ellipse(19.5, 29, 2.5, 1.6, W, WS)
    hy = 12 + head_dy
    c.shaded_ellipse(16, hy, 9.5, 7.5, O, OS, OL)
    for x, y, w, h in ((12, hy - 6, 1, 2), (15, hy - 7, 2, 2), (19, hy - 6, 1, 2), (7, hy, 2, 1), (23, hy, 2, 1)):
        c.rect(x, y, w, h, D)
    c.ellipse(16, hy + 3.5, 4.5, 2.6, W)
    face(c, hy, eyes, mouth)
    c.outline()
    return c


def body_side(frame):
    """Walking, facing right. Diagonal gait: legs move in opposite pairs over 4 frames."""
    c = Canvas(32, 32)
    bob = .5 if frame % 2 else 0
    for base, phase in ((8, 0), (11, 2), (19, 2), (22, 0)):
        dx = (0, 1, 0, -1)[(frame + phase) % 4]
        lift = 1 if dx == 1 else 0
        c.rect(base + dx, 25, 2, 5 - lift, O if base in (8, 19) else OS)
        c.rect(base + dx, 29 - lift, 2, 1, W)
    c.shaded_ellipse(15, 22 - bob, 9, 5, O, OS, OL)
    c.ellipse(15, 24.5 - bob, 6, 2.2, W)
    for x in (11, 14, 17):
        c.rect(x, 17 - bob, 1, 2, D)
    hy = 15 - bob
    c.shaded_ellipse(24, hy, 6.5, 5.5, O, OS, OL)
    c.ellipse(26.5, hy + 2.2, 2.8, 1.8, W)
    c.rect(26, hy - 1, 1, 2, E); c.pset(26 * SCALE, int((hy - 1) * SCALE), H)
    c.rect(29, hy + 1, 1, 1, P)
    c.rect(21, hy - 2, 2, 1, D)
    c.outline()
    return c


def body_sleep(breath=0):
    c = Canvas(32, 32)
    c.shaded_ellipse(17, 25, 11, 5.5 + breath * .5, O, OS, OL)
    for x in (17, 21, 25):
        c.rect(x, 20 + (1 if x == 25 else 0), 1, 2, D)
    hy = 22
    c.shaded_ellipse(10.5, hy, 7.5, 6, O, OS, OL)
    c.ellipse(10.5, hy + 3, 4, 2.2, W)
    c.rect(6, hy + 1, 3, 1, E); c.rect(12, hy + 1, 3, 1, E)
    c.rect(10, hy + 2, 1, 1, P)
    c.outline()
    return c


def body_scratch(frame):
    """Standing on hind legs facing right, front paws on the scratching post (post is to the right)."""
    c = Canvas(32, 32)
    c.rect(11, 25, 2, 5, OS); c.rect(15, 25, 2, 5, O)
    c.rect(11, 29, 2, 1, W); c.rect(15, 29, 2, 1, W)
    c.shaded_ellipse(14, 20, 5.5, 7.5, O, OS, OL)
    c.ellipse(15.5, 21, 3, 5, W)
    for y in (15, 18, 21):
        c.rect(10, y, 2, 1, D)
    up = (0, 2)[frame]
    for x, y in ((19, 13 + up), (20, 16 - up)):
        c.rect(x, y, 4, 2, O); c.rect(x + 3, y, 2, 2, W)
    hy = 9
    c.shaded_ellipse(17, hy, 6.5, 5.5, O, OS, OL)
    c.ellipse(19.5, hy + 2.2, 2.8, 1.8, W)
    c.rect(19, hy, 3, 1, E)  # eyes closed with joy
    c.rect(22, hy + 1, 1, 1, P)
    c.rect(14, hy - 2, 2, 1, D)
    c.outline()
    return c


def shifted(canvas, dx, dy):
    out = Canvas(canvas.w, canvas.h)
    for Y in range(canvas.H):
        for X in range(canvas.W):
            v = canvas.p[Y][X]
            if v and 0 <= X + dx * SCALE < out.W and 0 <= Y + dy * SCALE < out.H:
                out.p[Y + dy * SCALE][X + dx * SCALE] = v
    return out


def big_paw():
    """Close-up paw for nail trimming (white paw, pink beans)."""
    c = Canvas(48, 40)
    c.shaded_ellipse(24, 28, 17, 12, W, WS)
    for cx, cy in ((10, 12), (19, 7), (29, 7), (38, 12)):
        c.shaded_ellipse(cx, cy, 5.5, 6, W, WS)
        c.ellipse(cx, cy + 1, 2.8, 3, P)
    c.ellipse(24, 29, 8, 6, P)
    c.ellipse(22, 27, 2, 1.5, (250, 200, 210, 255))
    c.outline()
    return c


def claw():
    c = Canvas(5, 7)
    c.tri((1, 7), (4, 7), (3, 0), (236, 236, 228, 255))
    c.rect(2, 2, 1, 4, (210, 210, 200, 255))
    c.outline()
    return c


def ears(style, family, hy):
    """Ear layer, drawn behind the body so the head covers the ear base."""
    c = Canvas(32, 32)
    if family == "front":
        pairs = ((16, -1), (16, 1))
        for cx, side in pairs:
            m = lambda x: cx + (x - cx) * side  # mirror around the head center
            if style == "pointy":
                c.tri((m(6), hy - 9), (m(6.5), hy - 1), (m(13.5), hy - 5), O)
                c.tri((m(7.5), hy - 7.5), (m(8), hy - 4), (m(11), hy - 5.5), P)
            elif style == "round":
                c.shaded_ellipse(m(8.3), hy - 5.6, 3.4, 3.4, O, OS)
                c.ellipse(m(8.3), hy - 6, 1.8, 1.8, P)
            else:  # folded
                c.shaded_ellipse(m(9.5), hy - 6.2, 3.4, 2, O, OS)
                c.rect(int(m(8.5)) - (1 if side > 0 else 0), int(hy - 6), 2, 1, OS)
    elif family == "side":
        if style == "pointy":
            c.tri((20.5, hy - 3), (21.5, hy - 9.5), (24.5, hy - 4.5), OS)
            c.tri((23.5, hy - 4.5), (25.5, hy - 10), (27.5, hy - 3.5), O)
            c.tri((24.6, hy - 5), (25.5, hy - 8), (26.5, hy - 4.5), P)
        elif style == "round":
            c.shaded_ellipse(22, hy - 4.5, 2.6, 2.6, OS, OS)
            c.shaded_ellipse(25.5, hy - 5, 2.8, 2.8, O, OS)
            c.ellipse(25.5, hy - 5.3, 1.4, 1.4, P)
        else:
            c.shaded_ellipse(25, hy - 4.6, 3, 1.6, O, OS)
    else:  # sleep (head at x 10.5)
        if style == "pointy":
            c.tri((4, hy - 8), (4.5, hy - 1), (10.5, hy - 4), O)
            c.tri((17, hy - 8), (16.5, hy - 1), (10.5, hy - 4), O)
            c.tri((5.5, hy - 6.5), (6, hy - 3.5), (8.5, hy - 4.5), P)
        elif style == "round":
            for cx in (5.5, 15.5):
                c.shaded_ellipse(cx, hy - 4.6, 3, 3, O, OS)
            c.ellipse(5.5, hy - 5, 1.5, 1.5, P)
        else:
            for cx in (6.5, 14.5):
                c.shaded_ellipse(cx, hy - 5, 3, 1.8, O, OS)
    c.outline()
    return c


def tail(length, family, pose):
    """Polyline of 2x2 blocks with a white tip. `length` = number of segments."""
    import math
    c = Canvas(32, 32)
    if family == "front":
        start = (22, 25)
        profile = {"down": (25, 0), "wag0": (-20, -100), "wag1": (0, -60), "up": (-82, -95)}[pose]
    elif family == "side":
        start = (7, 20)
        profile = {"down": (150, 105), "wag0": (240, 285), "wag1": (225, 275), "up": (265, 275)}[pose]
    else:  # sleep: wraps along the front of the loaf, drawn in front of the body
        start = (27, 28.5)
        profile = (175, 215)
    x, y = start
    pts = [(x, y)]
    for i in range(length):
        a = math.radians(profile[0] + (profile[1] - profile[0]) * i / max(1, length - 1))
        x, y = x + 2 * math.cos(a), y + 2 * math.sin(a)
        pts.append((x, y))
    for i, (px, py) in enumerate(pts):
        c.rect(round(px), round(py), 2, 2, W if i == len(pts) - 1 else O)
    c.outline()
    return c


ACCESSORIES = ("bow", "flower", "crown", "collar", "scarf")
NECK_ACCESSORIES = ("collar", "scarf")


def accessory(kind, family, hx, hy):
    """Accessory layer drawn in front of the body. (hx, hy) = head center of that frame."""
    c = Canvas(32, 32)
    pink, gold, red, blue = (240, 110, 150, 255), (250, 205, 70, 255), (220, 60, 70, 255), (90, 140, 220, 255)
    side = family in ("side", "scratch")
    if kind == "bow":
        x, y = (hx + 2, hy - 5) if side else (hx - 4, hy - 5) if family == "sleep" else (hx + 6, hy - 6)
        c.tri((x - 3, y - 2), (x - 3, y + 2), (x, y), pink); c.tri((x + 3, y - 2), (x + 3, y + 2), (x, y), pink)
        c.rect(x - .5, y - 1, 1.5, 2, (200, 70, 110, 255))
    elif kind == "flower":
        x, y = (hx + 2, hy - 5) if side else (hx - 4, hy - 5) if family == "sleep" else (hx + 6, hy - 6)
        for dx, dy in ((0, -1.6), (1.6, 0), (0, 1.6), (-1.6, 0)):
            c.ellipse(x + dx, y + dy, 1.4, 1.4, (255, 255, 255, 255))
        c.ellipse(x, y, 1.2, 1.2, gold)
    elif kind == "crown":
        x, y = (hx, hy - 6) if side else (hx - 0.5, hy - 6.5) if family == "sleep" else (hx, hy - 8)
        c.rect(x - 4, y, 8, 2.5, gold)
        for dx in (-4, -0.5, 3):
            c.tri((x + dx, y + .5), (x + dx + 1, y - 2.5), (x + dx + 2, y + .5), gold)
        c.set(x - .5, y + 1, red)
    elif kind in NECK_ACCESSORIES and family != "sleep":
        col = red if kind == "collar" else blue
        if family == "front":
            c.rect(hx - 5, hy + 6.5, 10, 1.5, col)
            if kind == "collar":
                c.ellipse(hx, hy + 9, 1.3, 1.3, gold)
            else:
                c.rect(hx + 1, hy + 8, 3, 4, col)
        else:
            nx = hx - 3 if family == "side" else hx - 2
            c.rect(nx, hy + 3, 2, 4, col)
            if kind == "collar":
                c.ellipse(nx + 1.5, hy + 7, 1.2, 1.2, gold)
            else:
                c.rect(nx - 3, hy + 5, 3, 2, col)
    c.outline()
    return c


FRONT_FRAMES = {
    "idle_0": dict(), "idle_1": dict(breath=1), "blink": dict(eyes="closed"),
    "happy_0": dict(eyes="happy", mouth="open"), "happy_1": dict(eyes="happy", breath=1),
    "sad": dict(eyes="sad", mouth="flat"),
    "eat_0": dict(eyes="closed", mouth="open", head_dy=3), "eat_1": dict(eyes="closed", head_dy=4),
}


def cat_layers():
    """name -> canvas for every body, ear and tail sprite."""
    out = {}
    for name, kw in FRONT_FRAMES.items():
        out[f"cat_{name}"] = body_front(**kw)
        for acc in ACCESSORIES:
            out[f"cat_acc_{acc}_{name}"] = accessory(acc, "front", 16, 12 + kw.get("head_dy", 0))
        for style in EAR_STYLES:
            out[f"cat_ears_{style}_{name}"] = ears(style, "front", 12 + kw.get("head_dy", 0))
    for f in range(4):
        out[f"cat_walk_{f}"] = body_side(f)
        for acc in ACCESSORIES:
            out[f"cat_acc_{acc}_walk_{f}"] = accessory(acc, "side", 24, 15 - (.5 if f % 2 else 0))
        for style in EAR_STYLES:
            out[f"cat_ears_{style}_walk_{f}"] = ears(style, "side", 15 - (.5 if f % 2 else 0))
    for f in range(2):
        out[f"cat_scratch_{f}"] = body_scratch(f)
        for acc in ACCESSORIES:
            out[f"cat_acc_{acc}_scratch_{f}"] = accessory(acc, "scratch", 17, 9)
        for style in EAR_STYLES:
            out[f"cat_ears_{style}_scratch_{f}"] = shifted(ears(style, "side", 9), -7, 0)
    for f in range(2):
        out[f"cat_sleep_{f}"] = body_sleep(f)
        for acc in ACCESSORIES:
            if acc not in NECK_ACCESSORIES:  # neck items are hidden while curled up
                out[f"cat_acc_{acc}_sleep_{f}"] = accessory(acc, "sleep", 10.5, 22)
        for style in EAR_STYLES:
            out[f"cat_ears_{style}_sleep_{f}"] = ears(style, "sleep", 22)
    for length, segments in TAIL_LENGTHS.items():
        for family in ("front", "side"):
            for pose in TAIL_POSES:
                out[f"cat_tail_{length}_{family}_{pose}"] = tail(segments, family, pose)
        out[f"cat_tail_{length}_sleep"] = tail(segments, "sleep", "down")
    return out


def compose(*layers):
    """Flattens layers (first = back) into one canvas, e.g. for the app icon."""
    out = Canvas(layers[0].w, layers[0].h)
    for layer in layers:
        for Y in range(layer.H):
            for X in range(layer.W):
                if layer.p[Y][X]:
                    out.p[Y][X] = layer.p[Y][X]
    return out


def cat_sit(eyes="open", mouth="smile", tail_pose="wag1"):
    return compose(tail(5, "front", tail_pose), ears("pointy", "front", 12), body_front(eyes=eyes, mouth=mouth))


# ---------- Room objects ----------

def bowl(fill):
    c = Canvas(16, 9)
    c.ellipse(8, 5.5, 7, 3.2, (230, 92, 92, 255))
    c.ellipse(8, 3.6, 5.5, 1.6, {"empty": (150, 50, 60, 255), "food": (150, 95, 50, 255),
                                 "water": (110, 180, 230, 255)}[fill])
    if fill == "food":
        for x in (5, 8, 11):
            c.set(x, 2, (190, 130, 70, 255))
    c.rect(3, 6, 10, 1, (200, 70, 80, 255))
    c.outline()
    return c


def bed():
    c = Canvas(36, 14)
    c.ellipse(18, 8.5, 17, 5, (214, 86, 120, 255))
    c.ellipse(18, 7.5, 12.5, 3, (247, 170, 190, 255))
    c.outline()
    return c


def scratching_post():
    c = Canvas(16, 36)
    c.rect(1, 30, 14, 4, (170, 112, 72, 255))
    c.rect(6, 6, 4, 24, (222, 190, 140, 255))
    for y in range(8, 30, 3):
        c.rect(6, y, 4, 1, (190, 150, 100, 255))
    c.rect(2, 2, 12, 4, (170, 120, 200, 255))
    c.outline()
    return c


def yarn():
    c = Canvas(12, 10)
    c.ellipse(5, 5, 4.5, 4.5, (232, 80, 110, 255))
    for x, y in ((3, 3), (4, 4), (5, 5), (6, 6), (6, 2), (7, 3)):
        c.set(x, y, (180, 50, 80, 255))
    c.rect(9, 8, 2, 1, (232, 80, 110, 255))
    c.outline()
    return c


def plant():
    c = Canvas(16, 24)
    g1, g2 = (110, 180, 100, 255), (80, 150, 80, 255)
    c.ellipse(8, 8, 5, 6, g1); c.ellipse(4, 11, 3.5, 3, g2); c.ellipse(12, 11, 3.5, 3, g2)
    c.rect(4, 15, 8, 7, (200, 110, 70, 255)); c.rect(3, 15, 10, 2, (220, 130, 85, 255))
    c.outline()
    return c


def tub():
    c = Canvas(34, 16)
    c.shaded_ellipse(17, 5, 15, 3.5, (240, 250, 255, 255), (200, 220, 235, 255))
    c.rect(3, 5, 28, 8, (235, 245, 252, 255)); c.rect(3, 11, 28, 2, (200, 220, 235, 255))
    for x in (5, 27):
        c.rect(x, 13, 2, 2, (200, 170, 90, 255))
    for x, y, r in ((8, 3, 2.5), (13, 2, 3), (19, 2.5, 2.5), (25, 3, 2.2)):
        c.ellipse(x, y, r, r * .8, (255, 255, 255, 255))
    c.outline()
    return c


def litter(dirty):
    c = Canvas(24, 12)
    c.rect(1, 3, 22, 8, (120, 170, 200, 255)); c.rect(1, 9, 22, 2, (90, 140, 175, 255))
    c.rect(3, 3, 18, 2, (235, 220, 180, 255))
    if dirty:
        for x in (6, 11, 16):
            c.rect(x, 2, 2, 2, (150, 110, 70, 255))
    c.outline()
    return c


BUBBLE = [".KK.", "KHBK", "KBBK", ".KK."]
ALERT = [".KKKKKK.", "KWWKKWWK", "KWWKKWWK", "KWWKKWWK", "KWWWWWWK", "KWWKKWWK", ".KKKKKK.", "...KK...", "..K....."]
SICK = [".KKKKKK.", "KWWRRWWK", "KWWRRWWK", "KRRRRRRK", "KWWRRWWK", "KWWRRWWK", ".KKKKKK.", "...KK...", "..K....."]
LASER = [".RR.", "RHHR", "RHHR", ".RR."]
SPARKLE = ["..Y..", "..Y..", "YYHYY", "..Y..", "..Y.."]
HEART = [".HH.HH.", "HPPHPPH", "HPPPPPH", ".HPPPH.", "..HPH..", "...H..."]
ZED = ["KKKKK", "...K.", "..K..", ".K...", "KKKKK"]


def small(rows, pal):
    c = Canvas(len(rows[0]), len(rows))
    c.stamp(rows, pal)
    return c


ICONS = {
    "icon_hunger": ["..KKK....", ".KOOOK.KK", "KOEOOOKOK", "KOOOOOOOK", ".KOOOK.KK", "..KKK...."],
    "icon_energy": ["....KKK", "...KYK.", "..KYK..", ".KYYYK.", "..KYK..", ".KYK...", "KYK....", "KK....."],
    "icon_happiness": [".KK.KK.", "KPPKPPK", "KPPPPPK", ".KPPPK.", "..KPK..", "...K..."],
    "icon_cleanliness": ["...K...", "..KBK..", ".KBBBK.", "KBBHBBK", "KBBBBBK", ".KBBBK.", "..KKK.."],
    "icon_health": ["..KKK..", "..KRK..", "KKKRKKK", "KRRRRRK", "KKKRKKK", "..KRK..", "..KKK.."],
    "icon_clean": ["..KK..KK", ".KHBKKHK", ".KBBKKBK", "KKKKKKK.", "KSSSSSK.", "KSSSSSK.", ".KKKKK.."],
    "icon_brush": ["....KKK", "...KWWK", "..KWWK.", ".KBBK..", "KBBK...", "KBK....", "KK....."],
    "icon_food_dry": [".KKKKK.", "KTTTTTK", "KTETETK", "KTTTTTK", ".KTTTK.", "..KKK.."],
    "icon_food_wet": [".KKKKK.", "KSSSSSK", "KRRRRRK", "KRSRSRK", "KRRRRRK", ".KKKKK."],
    "icon_food_fish": ["..KKK....", ".KOOOK.KK", "KOEOOOKOK", "KOOOOOOOK", ".KOOOK.KK", "..KKK...."],
    "icon_food_chicken": ["..KKKK.", ".KTTTTK", "KTTTTTK", "KTTTTK.", ".KTTK..", "..KWWK.", "...KWWK", "....KK."],
    "icon_food_treat": ["...K...", "..KPK..", ".KPPPK.", "KPPYPPK", ".KPPPK.", "..KPK..", "...K..."],
    "icon_play": ["...KK..", "..KPPK.", ".KPKPPK", "KPPKPPK", "KPPPKPK", ".KPPPK.", "..KKK.K"],
    "icon_shop": ["..KKK..", ".K...K.", "KKKKKKK", "KYYYYYK", "KYKYKYK", "KYYYYYK", "KKKKKKK"],
    "icon_tasks": ["KKKKKK.", "KWWWWK.", "KWKKWK.", "KWWWWKK", "KWKKWKY", "KWWWWKK", "KKKKKK."],
    "icon_decor": ["..KKK..", ".KYYYK.", "..KWK..", "KKKKKKK", "KPPPPPK", "KPKKKPK", "KK...KK"],
    "icon_settings": ["..K.K..", ".KWKWK.", "KWWWWWK", ".WWKWW.", "KWWWWWK", ".KWKWK.", "..K.K.."],
    "icon_back": ["...K...", "..KK...", ".KWKKKK", "KWWWWWK", ".KWKKKK", "..KK...", "...K..."],
    "icon_menu": ["KKKKKKK", "KWWWWWK", "KKKKKKK", "KWWWWWK", "KKKKKKK", "KWWWWWK", "KKKKKKK"],
    "icon_close": ["KK...KK", "KWK.KWK", ".KWKWK.", "..KWK..", ".KWKWK.", "KWK.KWK", "KK...KK"],
    "icon_badge_bronze": ["KK...KK", "KRK.KRK", ".KRKRK.", ".KKKKK.", "KTTTTTK", "KTTHTTK", "KTTTTTK", ".KKKKK."],
    "icon_badge_silver": ["KK...KK", "KRK.KRK", ".KRKRK.", ".KKKKK.", "KSSSSSK", "KSSHSSK", "KSSSSSK", ".KKKKK."],
    "icon_badge_gold": ["KK...KK", "KRK.KRK", ".KRKRK.", ".KKKKK.", "KYYYYYK", "KYYHYYK", "KYYYYYK", ".KKKKK."],
    "icon_badge_locked": ["KK...KK", "KLK.KLK", ".KLKLK.", ".KKKKK.", "KLLLLLK", "KLLKLLK", "KLLLLLK", ".KKKKK."],
    "icon_camera": ["..KKK..", "KKKKKKK", "KWWKWWK", "KWKBKWK", "KWWKWWK", "KKKKKKK"],
    "icon_collection": ["KKKKKKK", "KYKPKBK", "KKKKKKK", "KPKBKYK", "KKKKKKK", "KBKYKPK", "KKKKKKK"],
    "icon_coin": [".KKKK.", "KYYYYK", "KYKYYK", "KYKYYK", "KYYYYK", ".KKKK."],
    "icon_xp": ["...K...", "..KYK..", "KKYYYKK", ".KYYYK.", ".KYKYK.", "KK...KK"],
}
ICON_PAL = {"L": (170, 165, 160, 255), "K": K, "O": (120, 170, 220, 255), "E": E, "S": (190, 200, 210, 255), "W": W, "T": (196, 134, 72, 255), "Y": (250, 205, 70, 255), "P": (240, 90, 120, 255),
            "B": (110, 180, 230, 255), "H": H, "R": (230, 70, 70, 255)}


# ---------- Room background 180x200 ----------

ROOM_PAD_X, ROOM_PAD_Y = 20, 80  # extra art around the 180x200 core; keep in sync with RoomScene.artPadding


# Wall and floor patterns are grayscale; the game tints them with the chosen wall/floor color.
G_BASE, G_ALT = (255, 255, 255, 255), (243, 238, 234, 255)
WALLS = {  # name: (base, stripe or None, dot or None)
    "wall_stripes": (G_BASE, G_ALT, None),
    "wall_dots": (G_BASE, None, G_ALT),
    "wall_plain": (G_BASE, None, None),
}
FLOORS = {"floor_wood": "wood", "floor_tiles": "tiles"}
RUGS = {  # name: (outer, middle, inner)
    "rug_oval": ((230, 160, 140, 255), (240, 190, 160, 255), (245, 205, 175, 255)),
    "rug_blue": ((120, 160, 210, 255), (150, 190, 230, 255), (185, 215, 240, 255)),
    "rug_leaf": ((120, 175, 110, 255), (160, 205, 140, 255), (195, 225, 170, 255)),
}
FLOOR_TOP = ROOM_PAD_Y + 120  # logical rows, in the padded canvas


def walk_scene(kind):
    """Park / beach / forest: same layout as garden() (ground at row 200, path rows 224-270)."""
    import random
    rnd = random.Random(kind)
    c = Canvas(540, 360)
    ground = 200
    sky = {"park": ((150, 205, 245), (210, 235, 250)), "beach": ((120, 195, 245), (200, 235, 252)),
           "forest": ((150, 195, 200), (205, 230, 215))}[kind]
    for y in range(ground):
        t = y / ground
        c.rect(0, y, 540, 1, tuple(int(a + (b - a) * t) for a, b in zip(*sky)) + (255,))
    for cx, cy in ((80, 50), (300, 35), (470, 60)):
        for dx, dy, r in ((-8, 2, 7), (0, 0, 9), (9, 2, 7)):
            c.ellipse(cx + dx, cy + dy, r * 1.3, r * .8, (255, 255, 255, 255))
    if kind == "park":
        for x in range(0, 540, 26):
            h = rnd.randrange(30, 70)
            c.rect(x, ground - h, 22, h, (190, 200, 220, 255))
        for x in range(0, 540, 2):
            c.rect(x, ground - 4, 2, 4, (150, 200, 120, 255))
        for cx in range(40, 540, 110):
            c.rect(cx - 3, ground - 36, 6, 36, (140, 95, 70, 255))
            c.shaded_ellipse(cx, ground - 48, 24, 20, (100, 170, 95, 255), (80, 140, 75, 255), (135, 200, 120, 255))
        grass, path, edge = (130, 195, 105, 255), (205, 205, 200, 255), (175, 175, 170, 255)
    elif kind == "beach":
        c.ellipse(430, 50, 16, 16, (255, 236, 160, 255))
        c.rect(0, ground - 46, 540, 46, (80, 155, 210, 255))
        for y in range(ground - 42, ground, 6):
            for x in range(rnd.randrange(8), 540, 22):
                c.rect(x, y, 8, 1, (190, 225, 250, 255))
        grass, path, edge = (240, 220, 170, 255), (215, 190, 140, 255), (195, 170, 125, 255)
    else:  # forest
        for layer, col in ((0, (90, 140, 110, 255)), (1, (70, 120, 85, 255))):
            for cx in range(-20 + layer * 30, 560, 60):
                c.rect(cx - 4, ground - 60, 8, 60, (95, 70, 55, 255))
                c.ellipse(cx, ground - 70 - layer * 10, 32, 44, col)
        grass, path, edge = (90, 150, 85, 255), (160, 120, 85, 255), (130, 95, 65, 255)
    for y in range(ground, 360):
        for x in range(540):
            c.set(x, y, grass if (x * 7 + y * 13) % 23 else tuple(max(0, v - 18) for v in grass[:3]) + (255,))
    c.rect(0, ground + 24, 540, 46, path)
    c.rect(0, ground + 24, 540, 2, edge); c.rect(0, ground + 68, 540, 2, edge)
    for _ in range(50):
        c.rect(rnd.randrange(540), rnd.randrange(ground + 27, ground + 66), 2, 1, edge)
    if kind == "park":
        c.ellipse(140, ground + 100, 50, 14, (110, 170, 220, 255)); c.ellipse(140, ground + 98, 40, 9, (150, 200, 240, 255))
        for bx in (60, 330):
            c.rect(bx, ground + 8, 30, 4, (160, 110, 70, 255)); c.rect(bx, ground + 2, 30, 3, (160, 110, 70, 255))
            c.rect(bx + 2, ground + 12, 2, 6, K); c.rect(bx + 26, ground + 12, 2, 6, K)
        for lx in (200, 470):
            c.rect(lx, ground - 30, 2, 50, (60, 60, 70, 255)); c.rect(lx - 3, ground - 34, 8, 5, (250, 230, 150, 255))
    elif kind == "beach":
        for px in (70, 380):
            for i in range(14):
                c.rect(px + i // 3, ground + 10 - i * 4, 4, 4, (150, 110, 70, 255))
            for dx in (-14, -7, 0, 7, 14):
                c.ellipse(px + 6 + dx, ground - 46 + abs(dx) // 3, 9, 3, (80, 160, 90, 255))
        c.tri((250, ground + 6), (280, ground - 14), (310, ground + 6), (240, 90, 100, 255)); c.rect(279, ground - 14, 2, 30, (240, 240, 240, 255))
        for _ in range(40):
            c.rect(rnd.randrange(540), rnd.randrange(ground + 74, 360), 2, 2, rnd.choice([(255, 240, 230, 255), (250, 190, 170, 255)]))
    else:
        for _ in range(16):
            mx, my = rnd.randrange(540), rnd.choice([rnd.randrange(ground + 6, ground + 20), rnd.randrange(ground + 76, 350)])
            c.rect(mx, my + 3, 2, 4, (245, 240, 230, 255)); c.ellipse(mx + 1, my + 2, 4, 2.5, (220, 70, 70, 255))
            c.set(mx, my + 1, (255, 255, 255, 255))
        for _ in range(30):
            fx, fy = rnd.randrange(540), rnd.randrange(ground + 74, 360)
            c.rect(fx, fy, 1, 5, (60, 120, 60, 255)); c.rect(fx - 2, fy + 1, 2, 1, (60, 120, 60, 255)); c.rect(fx + 1, fy + 2, 2, 1, (60, 120, 60, 255))
    return c


def wall(base, stripe, dot):
    """Full padded canvas; only the wall part (and baseboard) is painted."""
    c = Canvas(180 + 2 * ROOM_PAD_X, 200 + 2 * ROOM_PAD_Y)
    for y in range(FLOOR_TOP):
        for x in range(c.w):
            col = base
            if stripe and ((x - ROOM_PAD_X) // 6) % 2:
                col = stripe
            if dot and (x % 10, y % 10) in ((2, 2), (3, 2), (2, 3), (3, 3), (7, 7), (8, 7), (7, 8), (8, 8)):
                col = dot
            c.set(x, y, col)
    return c


def baseboard():
    c = Canvas(180 + 2 * ROOM_PAD_X, 8)
    c.rect(0, 0, c.w, 8, (196, 140, 100, 255)); c.rect(0, 0, c.w, 1, (150, 100, 70, 255))
    return c


def floor(style):
    c = Canvas(180 + 2 * ROOM_PAD_X, 200 + 2 * ROOM_PAD_Y)
    for y in range(FLOOR_TOP, c.h):
        for x in range(c.w):
            r = y - FLOOR_TOP
            if style == "wood":
                seam = (x + (r // 10) * 23) % 46 == 0
                col = (220, 220, 220, 255) if r % 10 == 0 or seam else (255, 255, 255, 255)
            else:
                light = ((x // 12) + (r // 12)) % 2 == 0
                col = (255, 255, 255, 255) if light else (232, 232, 232, 255)
                if x % 12 == 0 or r % 12 == 0:
                    col = (210, 210, 210, 255)
            c.set(x, y, col)
    return c


def window():
    c = Canvas(88, 76)
    ox, oy = 46, 14  # position in the core room, logical
    def r(x, y, w, h, col): c.rect(x - ox, y - oy, w, h, col)
    r(58, 20, 64, 64, K); r(60, 22, 60, 60, (255, 250, 240, 255)); r(63, 25, 54, 54, None)  # glass: the view shows through
    r(89, 25, 2, 54, (255, 250, 240, 255)); r(63, 51, 54, 2, (255, 250, 240, 255))
    r(54, 84, 72, 4, (196, 140, 100, 255)); r(54, 88, 72, 1, K)
    for cx in (50, 122):
        r(cx, 16, 8, 74, (247, 170, 190, 255)); r(cx + 2, 16, 1, 74, (230, 140, 165, 255))
    r(46, 14, 88, 3, (150, 100, 70, 255))
    return c


def view(kind):
    """Window scenery, 54x54 logical, sits behind the window frame's glass."""
    import random
    rnd = random.Random(kind)
    c = Canvas(54, 54)
    sky_top, sky_bottom = {"sky": ((140, 200, 240), (200, 232, 250)), "sakura": ((170, 205, 240), (230, 225, 245)),
                           "sea": ((150, 205, 240), (210, 236, 250)), "city": ((250, 190, 150), (255, 225, 190)),
                           "fuji": ((150, 190, 235), (215, 230, 248))}[kind]
    for y in range(54):
        t = y / 53
        c.rect(0, y, 54, 1, tuple(int(a + (b - a) * t) for a, b in zip(sky_top, sky_bottom)) + (255,))
    if kind == "sky":
        for x, y, w in ((7, 9, 12), (5, 11, 16), (32, 25, 10), (30, 27, 14)):
            c.rect(x, y, w, 2, H)
    elif kind == "sakura":
        c.rect(0, 44, 54, 10, (150, 200, 130, 255))
        c.rect(36, 22, 4, 24, (120, 80, 70, 255)); c.rect(30, 30, 8, 2, (120, 80, 70, 255))
        for _ in range(9):
            c.ellipse(rnd.randrange(20, 54), rnd.randrange(8, 30), rnd.uniform(4, 7), rnd.uniform(3, 5), (248, 190, 210, 255))
        for _ in range(14):
            c.set(rnd.randrange(54), rnd.randrange(54), (255, 215, 230, 255))
    elif kind == "sea":
        c.rect(0, 30, 54, 24, (90, 160, 210, 255))
        for y in range(32, 54, 4):
            for x in range(rnd.randrange(4), 54, 9):
                c.rect(x, y, 4, 1, (200, 230, 250, 255))
        c.ellipse(40, 14, 5, 5, (255, 240, 180, 255)); c.rect(0, 46, 54, 8, (240, 220, 170, 255))
    elif kind == "city":
        c.ellipse(14, 20, 6, 6, (255, 230, 160, 255))
        for x, h in ((0, 20), (8, 30), (17, 24), (25, 36), (34, 22), (41, 30), (49, 26)):
            c.rect(x, 54 - h, 7, h, (110, 100, 140, 255))
            for wy in range(54 - h + 3, 52, 5):
                c.rect(x + 2, wy, 1, 2, (255, 225, 140, 255)); c.rect(x + 4, wy, 1, 2, (255, 225, 140, 255))
    else:  # fuji
        c.tri((4, 46), (27, 14), (50, 46), (120, 130, 175, 255))
        c.tri((21, 22), (27, 14), (33, 22), (250, 250, 255, 255))
        c.rect(23, 21, 2, 2, (250, 250, 255, 255)); c.rect(29, 21, 2, 2, (250, 250, 255, 255))
        c.rect(0, 44, 54, 10, (140, 190, 130, 255))
        c.ellipse(44, 10, 4, 4, (250, 120, 110, 255))
    return c


def tv(kind):
    """36x34 logical, anchor bottom center. Screen hole at x 6..30, y 4..20 (from top) is left empty:
    the game draws the channel behind it."""
    c = Canvas(36, 34)
    if kind == "retro":
        c.rect(6, 28, 3, 6, (120, 80, 60, 255)); c.rect(27, 28, 3, 6, (120, 80, 60, 255))
        c.rect(2, 2, 32, 27, (190, 130, 80, 255)); c.rect(2, 26, 32, 3, (160, 105, 65, 255))
        c.rect(31, 8, 2, 2, (240, 200, 90, 255)); c.rect(31, 12, 2, 2, (240, 200, 90, 255))
        c.rect(14, 0, 1, 2, K); c.rect(21, 0, 1, 2, K)
    else:
        c.rect(15, 24, 6, 6, (90, 95, 110, 255)); c.rect(9, 30, 18, 3, (90, 95, 110, 255))
        c.rect(4, 2, 28, 22, (60, 64, 78, 255))
    c.rect(6, 4, 24, 16, None)
    c.outline()  # also draws a dark bezel just inside the screen hole
    return c


def channel(kind, frame):
    c = Canvas(24, 16)
    if kind == "off":
        c.rect(0, 0, 24, 16, (40, 44, 56, 255)); c.rect(3, 2, 6, 1, (70, 76, 92, 255))
        return c
    if kind == "fish":
        c.rect(0, 0, 24, 16, (90, 160, 220, 255)); c.rect(0, 13, 24, 3, (230, 210, 150, 255))
        c.rect(3, 9, 1, 4, (90, 170, 90, 255)); c.rect(20, 7, 1, 6, (90, 170, 90, 255))
        for i, (y, col) in enumerate(((5, (250, 160, 60, 255)), (10, (250, 230, 90, 255)))):
            x = (frame * 3 + i * 9) % 26 - 2 if i == 0 else 22 - (frame * 2 + 4) % 26
            c.ellipse(x + 2, y, 2.5, 1.5, col); c.set(x - 1 if i == 0 else x + 4, y - 1, col)
        c.set(12, 12 - frame * 3 % 12, (220, 240, 255, 255))
    else:  # birds
        c.rect(0, 0, 24, 16, (170, 215, 245, 255)); c.rect(0, 12, 24, 4, (140, 200, 110, 255))
        c.ellipse(18, 3, 3, 1.5, (255, 255, 255, 255))
        for i in range(2):
            x = (frame * 3 + i * 11) % 28 - 3
            y = 5 + i * 3
            wing = -1 if (frame + i) % 2 else 1
            c.rect(x, y, 3, 1, (70, 70, 90, 255)); c.set(x - 1, y + wing, (70, 70, 90, 255)); c.set(x + 3, y + wing, (70, 70, 90, 255))
    return c


def frame(kind):
    c = Canvas(24, 20)
    c.rect(0, 0, 24, 20, K); c.rect(2, 2, 20, 16, (255, 236, 170, 255) if kind != "fish" else (200, 230, 245, 255))
    if kind == "sun":
        c.ellipse(12, 11, 5, 4, (242, 153, 74, 255))
    elif kind == "fish":
        c.ellipse(11, 10, 5, 3, (120, 170, 220, 255)); c.tri((15, 10), (19, 7), (19, 13), (120, 170, 220, 255)); c.set(9, 9, E)
    else:  # clock
        c.rect(0, 0, 24, 20, None); c.ellipse(12, 10, 9.5, 9.5, K); c.ellipse(12, 10, 8, 8, (255, 250, 240, 255))
        c.rect(12, 4, 1, 6, E); c.rect(12, 10, 4, 1, E)
    return c


def rug(outer, middle, inner):
    c = Canvas(110, 48)
    c.ellipse(55, 24, 54, 23, outer); c.ellipse(55, 24, 50, 20, middle); c.ellipse(55, 24, 38, 14, inner)
    return c


def bed_variant(outer, inner):
    c = Canvas(36, 14)
    c.shaded_ellipse(18, 8.5, 17, 5, outer, tuple(max(0, v - 30) for v in outer[:3]) + (255,))
    c.ellipse(18, 7.5, 12.5, 3, inner)
    c.outline()
    return c


def post_tower():
    c = Canvas(24, 52)
    wood, rope, top = (170, 112, 72, 255), (222, 190, 140, 255), (120, 190, 170, 255)
    c.rect(1, 46, 22, 5, wood)
    c.rect(9, 6, 6, 40, rope)
    for y in range(8, 46, 3):
        c.rect(9, y, 6, 1, (190, 150, 100, 255))
    c.rect(2, 22, 20, 4, top); c.rect(3, 2, 18, 4, top)
    c.outline()
    return c


def cactus():
    c = Canvas(16, 24)
    g1, g2 = (120, 185, 120, 255), (90, 155, 95, 255)
    c.rect(6, 3, 4, 13, g1); c.rect(2, 7, 3, 5, g2); c.rect(11, 5, 3, 6, g2); c.rect(4, 10, 2, 2, g2); c.rect(10, 9, 2, 2, g2)
    c.set(7, 2, (240, 120, 160, 255))
    c.rect(4, 15, 8, 7, (110, 150, 200, 255)); c.rect(3, 15, 10, 2, (130, 170, 220, 255))
    c.outline()
    return c


def toy_mouse():
    c = Canvas(14, 9)
    c.ellipse(6, 5, 5, 3, (170, 170, 185, 255)); c.ellipse(3, 3, 1.6, 1.6, (240, 170, 185, 255))
    c.set(2, 5, E); c.rect(11, 6, 3, 1, (240, 170, 185, 255))
    c.outline()
    return c


def garden():
    """Side-scrolling garden, 540x360 logical (1080x720 PNG). Same vertical layout as the room:
    the 200-row core starts at row 80 and the ground starts 120 rows into the core."""
    import random
    rnd = random.Random(7)
    c = Canvas(540, 360)
    ground = 200
    for y in range(ground):
        t = y / ground
        col = tuple(int(a + (b - a) * t) for a, b in zip((160, 210, 245), (215, 238, 250))) + (255,)
        c.rect(0, y, 540, 1, col)
    for cx, cy in ((60, 60), (210, 40), (380, 70), (500, 35)):
        for dx, dy, r in ((-8, 2, 7), (0, 0, 9), (9, 2, 7)):
            c.ellipse(cx + dx, cy + dy, r * 1.3, r * .8, (255, 255, 255, 255))
    for cx, rx, col in ((90, 130, (170, 215, 160, 255)), (330, 160, (165, 210, 150, 255)), (520, 110, (175, 218, 165, 255))):
        c.ellipse(cx, ground + 6, rx, 44, col)
    for cx in (70, 290, 455):
        c.rect(cx - 3, ground - 34, 6, 34, (150, 100, 70, 255))
        c.shaded_ellipse(cx, ground - 46, 22, 20, (110, 175, 100, 255), (85, 145, 80, 255), (140, 200, 120, 255))
    for x in range(0, 540, 12):
        c.rect(x + 2, ground - 22, 5, 22, (250, 245, 235, 255)); c.rect(x + 2, ground - 22, 5, 1, (210, 200, 190, 255))
    c.rect(0, ground - 16, 540, 2, (235, 228, 215, 255)); c.rect(0, ground - 7, 540, 2, (235, 228, 215, 255))
    for y in range(ground, 360):
        for x in range(540):
            c.set(x, y, (132, 196, 104, 255) if (x * 7 + y * 13) % 23 else (112, 176, 90, 255))
    c.rect(0, ground + 24, 540, 46, (226, 198, 152, 255))
    c.rect(0, ground + 24, 540, 2, (200, 170, 125, 255)); c.rect(0, ground + 68, 540, 2, (200, 170, 125, 255))
    for _ in range(60):
        c.rect(rnd.randrange(540), rnd.randrange(ground + 27, ground + 66), 2, 1, (190, 160, 120, 255))
    for cx in (30, 160, 250, 410, 515):
        c.shaded_ellipse(cx, ground + 4, 14, 8, (95, 160, 85, 255), (75, 135, 70, 255))
    for _ in range(140):
        x, y = rnd.randrange(540), rnd.choice([rnd.randrange(ground + 6, ground + 22), rnd.randrange(ground + 74, 360)])
        c.rect(x, y, 2, 2, rnd.choice([(250, 160, 190, 255), (255, 230, 110, 255), (255, 255, 255, 255), (200, 170, 240, 255)]))
    return c


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps(INFO, indent=2))
    for folder in ("Sprites", "Icons"):
        (ASSETS / folder).mkdir(parents=True, exist_ok=True)
        (ASSETS / folder / "Contents.json").write_text(json.dumps(INFO, indent=2))
    frames = {
        "bowl_empty": bowl("empty"), "bowl_food": bowl("food"),
        "bowl_water": bowl("water"), "bed_basic": bed(), "scratching_post": scratching_post(),
        "bed_cloud": bed_variant((120, 170, 230, 255), (200, 225, 250, 255)),
        "bed_royal": bed_variant((150, 100, 190, 255), (250, 210, 110, 255)),
        "post_tower": post_tower(), "plant_cactus": cactus(), "toy_mouse": toy_mouse(),
        "window_basic": window(), "frame_sun": frame("sun"), "frame_fish": frame("fish"), "frame_clock": frame("clock"),
        "toy_yarn": yarn(), "plant_basic": plant(),
        "bath_tub": tub(), "litter_clean": litter(False), "litter_dirty": litter(True),
        "fx_bubble": small(BUBBLE, {"K": (120, 170, 210, 255), "H": H, "B": (200, 235, 255, 255)}),
        "paw_big": big_paw(), "claw": claw(), "tv_retro": tv("retro"), "tv_modern": tv("modern"),
        "tv_off": channel("off", 0),
        **{f"tv_{k}_{f}": channel(k, f) for k in ("fish", "birds") for f in range(4)},
        "fx_alert": small(ALERT, {"K": K, "W": W}), "fx_sick": small(SICK, {"K": K, "W": W, "R": (230, 70, 70, 255)}),
        "fx_laser": small(LASER, {"R": (240, 50, 60, 255), "H": (255, 200, 200, 255)}),
        "fx_sparkle": small(SPARKLE, {"Y": (250, 220, 90, 255), "H": H}),
        "fx_heart": small(HEART, {"H": K, "P": (240, 90, 120, 255)}), "fx_zzz": small(ZED, {"K": (90, 110, 200, 255)}),
    }
    frames.update({name: wall(*spec) for name, spec in WALLS.items()})
    frames.update({name: floor(style) for name, style in FLOORS.items()})
    frames["baseboard"] = baseboard()
    frames.update({f"view_{kind}": view(kind) for kind in ("sky", "sakura", "sea", "city", "fuji")})
    frames.update({name: rug(*spec) for name, spec in RUGS.items()})
    frames["garden_background"] = garden()
    frames.update({f"{kind}_background": walk_scene(kind) for kind in ("park", "beach", "forest")})
    frames.update(cat_layers())
    for name, canvas in frames.items():
        save_image("Sprites", name, canvas)
    for name, rows in ICONS.items():
        width = max(len(r) for r in rows)
        save_image("Icons", name, small([r.ljust(width, ".") for r in rows], ICON_PAL))
    # The widget extension has its own small catalog with just the icons it draws.
    widget_assets = ROOT / "MeowchiWidget/Assets.xcassets"
    widget_assets.mkdir(parents=True, exist_ok=True)
    (widget_assets / "Contents.json").write_text(json.dumps(INFO, indent=2))
    for name in ("icon_hunger", "icon_energy", "icon_happiness", "icon_cleanliness", "icon_health"):
        rows = ICONS[name]
        width = max(len(r) for r in rows)
        canvas = small([r.ljust(width, ".") for r in rows], ICON_PAL)
        d = widget_assets / f"{name}.imageset"; d.mkdir(exist_ok=True)
        write_png(d / f"{name}.png", canvas)
        (d / "Contents.json").write_text(json.dumps({"images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}], **INFO}, indent=2))
    # App icon (opaque, placeholder)
    icon = ASSETS / "AppIcon.appiconset"; icon.mkdir(parents=True, exist_ok=True)
    write_png(icon / "icon.png", cat_sit(eyes="happy", mouth="open"), scale=1024 // (32 * SCALE),
              background=(255, 214, 170, 255))  # 1024px
    (icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "icon.png", "idiom": "universal",
                                                    "platform": "ios", "size": "1024x1024"}], **INFO}, indent=2))
    accent = ASSETS / "AccentColor.colorset"; accent.mkdir(parents=True, exist_ok=True)
    (accent / "Contents.json").write_text(json.dumps({"colors": [{"idiom": "universal", "color": {
        "color-space": "srgb", "components": {"red": "0.949", "green": "0.600", "blue": "0.290", "alpha": "1.000"}}}],
        **INFO}, indent=2))


if __name__ == "__main__":
    main()
