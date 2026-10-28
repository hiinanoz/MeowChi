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
D = (214, 111, 44, 255)    # stripes
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

def cat_sit(eyes="open", mouth="smile", tail=0, breath=0, head_dy=0, lift=(0, 0)):
    c = Canvas(32, 32)
    tails = [[(22, 25), (24, 24), (25, 22), (26, 20), (26, 18)],
             [(22, 25), (24, 25), (26, 24), (27, 22), (28, 20)]]
    pts = tails[tail]
    for x, y in pts:
        c.rect(x, y, 2, 2, O)
    c.rect(pts[-1][0], pts[-1][1], 2, 2, W)
    c.shaded_ellipse(16, 24, 7, 6 + breath * .5, O, OS)
    c.shaded_ellipse(16, 25, 4, 4.5, W, WS)
    c.shaded_ellipse(12.5, 29 - lift[0], 2.5, 1.6, W, WS)
    c.shaded_ellipse(19.5, 29 - lift[1], 2.5, 1.6, W, WS)
    hy = 12 + head_dy
    c.tri((6, hy - 9), (6.5, hy - 1), (13.5, hy - 5), O)
    c.tri((26, hy - 9), (25.5, hy - 1), (18.5, hy - 5), O)
    c.shaded_ellipse(16, hy, 9.5, 7.5, O, OS, OL)
    c.tri((7.5, hy - 7), (8, hy - 2.5), (11.5, hy - 4.5), P)
    c.tri((24.5, hy - 7), (24, hy - 2.5), (20.5, hy - 4.5), P)
    for x, y, w, h in ((12, hy - 6, 1, 2), (15, hy - 7, 2, 2), (19, hy - 6, 1, 2), (7, hy, 2, 1), (23, hy, 2, 1)):
        c.rect(x, y, w, h, D)
    c.ellipse(16, hy + 3.5, 4.5, 2.6, W)
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
    c.outline()
    return c


def cat_sleep(breath=0):
    c = Canvas(32, 32)
    c.rect(9, 28, 16, 2, O); c.rect(7, 28, 2, 2, W)
    c.shaded_ellipse(17, 25, 11, 5.5 + breath * .5, O, OS, OL)
    for x in (17, 21, 25):
        c.rect(x, 20 + (1 if x == 25 else 0), 1, 2, D)
    hy = 22
    c.tri((4, hy - 8), (4.5, hy - 1), (10.5, hy - 4), O)
    c.tri((17, hy - 8), (16.5, hy - 1), (10.5, hy - 4), O)
    c.shaded_ellipse(10.5, hy, 7.5, 6, O, OS, OL)
    c.tri((5.5, hy - 6), (6, hy - 2.5), (9, hy - 4), P)
    c.ellipse(10.5, hy + 3, 4, 2.2, W)
    c.rect(6, hy + 1, 3, 1, E); c.rect(12, hy + 1, 3, 1, E)
    c.rect(10, hy + 2, 1, 1, P)
    c.outline()
    return c


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
    "icon_coin": [".KKKK.", "KYYYYK", "KYKYYK", "KYKYYK", "KYYYYK", ".KKKK."],
    "icon_xp": ["...K...", "..KYK..", "KKYYYKK", ".KYYYK.", ".KYKYK.", "KK...KK"],
}
ICON_PAL = {"K": K, "O": (120, 170, 220, 255), "E": E, "S": (190, 200, 210, 255), "W": W, "T": (196, 134, 72, 255), "Y": (250, 205, 70, 255), "P": (240, 90, 120, 255),
            "B": (110, 180, 230, 255), "H": H, "R": (230, 70, 70, 255)}


# ---------- Room background 180x200 ----------

ROOM_PAD_X, ROOM_PAD_Y = 20, 80  # extra art around the 180x200 core; keep in sync with RoomScene.artPadding


WALLS = {  # name: (base, stripe or None, dot or None)
    "wall_stripes": ((250, 226, 200, 255), (244, 212, 184, 255), None),
    "wall_mint": ((214, 240, 226, 255), (196, 228, 212, 255), None),
    "wall_dots": ((236, 226, 250, 255), None, (220, 206, 242, 255)),
}
FLOORS = {"floor_wood": "wood", "floor_tiles": "tiles"}
RUGS = {  # name: (outer, middle, inner)
    "rug_oval": ((230, 160, 140, 255), (240, 190, 160, 255), (245, 205, 175, 255)),
    "rug_blue": ((120, 160, 210, 255), (150, 190, 230, 255), (185, 215, 240, 255)),
    "rug_leaf": ((120, 175, 110, 255), (160, 205, 140, 255), (195, 225, 170, 255)),
}
FLOOR_TOP = ROOM_PAD_Y + 120  # logical rows, in the padded canvas


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
    c.rect(0, FLOOR_TOP - 8, c.w, 8, (196, 140, 100, 255)); c.rect(0, FLOOR_TOP - 8, c.w, 1, (150, 100, 70, 255))
    return c


def floor(style):
    c = Canvas(180 + 2 * ROOM_PAD_X, 200 + 2 * ROOM_PAD_Y)
    for y in range(FLOOR_TOP, c.h):
        for x in range(c.w):
            r = y - FLOOR_TOP
            if style == "wood":
                seam = (x + (r // 10) * 23) % 46 == 0
                col = (176, 112, 70, 255) if r % 10 == 0 or seam else (205, 140, 92, 255)
            else:
                light = ((x // 12) + (r // 12)) % 2 == 0
                col = (240, 236, 228, 255) if light else (206, 196, 186, 255)
                if x % 12 == 0 or r % 12 == 0:
                    col = (180, 170, 160, 255)
            c.set(x, y, col)
    return c


def window():
    c = Canvas(88, 76)
    ox, oy = 46, 14  # position in the core room, logical
    def r(x, y, w, h, col): c.rect(x - ox, y - oy, w, h, col)
    r(58, 20, 64, 64, K); r(60, 22, 60, 60, (255, 250, 240, 255)); r(63, 25, 54, 54, (150, 210, 240, 255))
    for x, y, w in ((70, 34, 12), (68, 36, 16), (95, 50, 10), (93, 52, 14)):
        r(x, y, w, 2, H)
    r(89, 25, 2, 54, (255, 250, 240, 255)); r(63, 51, 54, 2, (255, 250, 240, 255))
    r(54, 84, 72, 4, (196, 140, 100, 255)); r(54, 88, 72, 1, K)
    for cx in (50, 122):
        r(cx, 16, 8, 74, (247, 170, 190, 255)); r(cx + 2, 16, 1, 74, (230, 140, 165, 255))
    r(46, 14, 88, 3, (150, 100, 70, 255))
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


CAT_COLORWAYS = {  # appearance id: palette overrides (orange_white is the default art)
    "gray_white": {"O": (160, 165, 182, 255), "D": (112, 117, 138, 255), "OS": (136, 141, 160, 255), "OL": (196, 200, 214, 255)},
    "cream": {"O": (240, 214, 176, 255), "D": (204, 160, 116, 255), "OS": (220, 190, 150, 255), "OL": (250, 232, 205, 255)},
}


def with_palette(overrides, fn, *args, **kwargs):
    """Recolors the cat by temporarily swapping module palette globals."""
    g = globals()
    saved = {k: g[k] for k in overrides}
    g.update(overrides)
    try:
        return fn(*args, **kwargs)
    finally:
        g.update(saved)


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps(INFO, indent=2))
    for folder in ("Sprites", "Icons"):
        (ASSETS / folder).mkdir(parents=True, exist_ok=True)
        (ASSETS / folder / "Contents.json").write_text(json.dumps(INFO, indent=2))
    frames = {
        "cat_idle_0": cat_sit(tail=0), "cat_idle_1": cat_sit(tail=1, breath=1),
        "cat_blink": cat_sit(eyes="closed", tail=0),
        "cat_walk_0": cat_sit(tail=0, lift=(2, 0)), "cat_walk_1": cat_sit(tail=1, lift=(0, 2)),
        "cat_happy_0": cat_sit(eyes="happy", mouth="open", tail=1),
        "cat_happy_1": cat_sit(eyes="happy", mouth="smile", tail=0, breath=1),
        "cat_sad": cat_sit(eyes="sad", mouth="flat", tail=0),
        "cat_eat_0": cat_sit(eyes="closed", mouth="open", head_dy=3), "cat_eat_1": cat_sit(eyes="closed", mouth="smile", head_dy=4),
        "cat_sleep_0": cat_sleep(0), "cat_sleep_1": cat_sleep(1),
"bowl_empty": bowl("empty"), "bowl_food": bowl("food"),
        "bowl_water": bowl("water"), "bed_basic": bed(), "scratching_post": scratching_post(),
        "bed_cloud": bed_variant((120, 170, 230, 255), (200, 225, 250, 255)),
        "bed_royal": bed_variant((150, 100, 190, 255), (250, 210, 110, 255)),
        "post_tower": post_tower(), "plant_cactus": cactus(), "toy_mouse": toy_mouse(),
        "window_basic": window(), "frame_sun": frame("sun"), "frame_fish": frame("fish"), "frame_clock": frame("clock"),
        "toy_yarn": yarn(), "plant_basic": plant(),
        "bath_tub": tub(), "litter_clean": litter(False), "litter_dirty": litter(True),
        "fx_bubble": small(BUBBLE, {"K": (120, 170, 210, 255), "H": H, "B": (200, 235, 255, 255)}),
        "fx_laser": small(LASER, {"R": (240, 50, 60, 255), "H": (255, 200, 200, 255)}),
        "fx_sparkle": small(SPARKLE, {"Y": (250, 220, 90, 255), "H": H}),
        "fx_heart": small(HEART, {"H": K, "P": (240, 90, 120, 255)}), "fx_zzz": small(ZED, {"K": (90, 110, 200, 255)}),
    }
    frames.update({name: wall(*spec) for name, spec in WALLS.items()})
    frames.update({name: floor(style) for name, style in FLOORS.items()})
    frames.update({name: rug(*spec) for name, spec in RUGS.items()})
    frames["garden_background"] = garden()
    cat_specs = {
        "idle_0": lambda: cat_sit(tail=0), "idle_1": lambda: cat_sit(tail=1, breath=1),
        "blink": lambda: cat_sit(eyes="closed", tail=0),
        "walk_0": lambda: cat_sit(tail=0, lift=(2, 0)), "walk_1": lambda: cat_sit(tail=1, lift=(0, 2)),
        "happy_0": lambda: cat_sit(eyes="happy", mouth="open", tail=1),
        "happy_1": lambda: cat_sit(eyes="happy", mouth="smile", tail=0, breath=1),
        "sad": lambda: cat_sit(eyes="sad", mouth="flat", tail=0),
        "eat_0": lambda: cat_sit(eyes="closed", mouth="open", head_dy=3),
        "eat_1": lambda: cat_sit(eyes="closed", mouth="smile", head_dy=4),
        "sleep_0": lambda: cat_sleep(0), "sleep_1": lambda: cat_sleep(1),
    }
    for appearance, palette in CAT_COLORWAYS.items():
        for frame_name, make in cat_specs.items():
            frames[f"cat_{appearance}_{frame_name}"] = with_palette(palette, make)
    for name, canvas in frames.items():
        save_image("Sprites", name, canvas)
    for name, rows in ICONS.items():
        width = max(len(r) for r in rows)
        save_image("Icons", name, small([r.ljust(width, ".") for r in rows], ICON_PAL))
    # App icon (opaque, placeholder)
    icon = ASSETS / "AppIcon.appiconset"; icon.mkdir(parents=True, exist_ok=True)
    write_png(icon / "icon.png", cat_sit(eyes="happy", mouth="open", tail=1), scale=1024 // (32 * SCALE),
              background=(255, 214, 170, 255))  # 1024px
    (icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "icon.png", "idiom": "universal",
                                                    "platform": "ios", "size": "1024x1024"}], **INFO}, indent=2))
    accent = ASSETS / "AccentColor.colorset"; accent.mkdir(parents=True, exist_ok=True)
    (accent / "Contents.json").write_text(json.dumps({"colors": [{"idiom": "universal", "color": {
        "color-space": "srgb", "components": {"red": "0.949", "green": "0.600", "blue": "0.290", "alpha": "1.000"}}}],
        **INFO}, indent=2))


if __name__ == "__main__":
    main()
