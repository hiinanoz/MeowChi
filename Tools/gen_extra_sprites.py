#!/usr/bin/env python3
"""TEMPORARY placeholder sprites for the UX update (new cat poses, walk finds, seasonal decor,
celebration cushion, empty-state art, logo). Adds only these assets; it never rewrites the ones
from gen_sprites.py. Final art replaces the PNGs under the same names (see docs/ASSETS.md).
Run: python3 Tools/gen_extra_sprites.py
"""
import importlib.util
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("gen_sprites", HERE / "gen_sprites.py")
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
Canvas, K, W, E, H, small, save_image = g.Canvas, g.K, g.W, g.E, g.H, g.small, g.save_image

# ---------- New front poses (body + every ear style + every accessory) ----------

NEW_FRONT = {
    "yawn_0": dict(eyes="closed", mouth="open"),
    "yawn_1": dict(eyes="closed", mouth="open", breath=1),
    "sniff_0": dict(eyes="open", mouth="flat", head_dy=2),
    "sniff_1": dict(eyes="open", mouth="smile", head_dy=3),
}


def cat_poses():
    out = {}
    for name, kw in NEW_FRONT.items():
        out[f"cat_{name}"] = g.body_front(**kw)
        for acc in g.ACCESSORIES:
            out[f"cat_acc_{acc}_{name}"] = g.accessory(acc, "front", 16, 12 + kw.get("head_dy", 0))
        for style in g.EAR_STYLES:
            out[f"cat_ears_{style}_{name}"] = g.ears(style, "front", 12 + kw.get("head_dy", 0))
    return out


# ---------- Walk finds (collection album) ----------

FIND_PAL = {"K": K, "W": W, "H": H, "Y": (250, 205, 70, 255), "P": (240, 150, 170, 255), "G": (110, 180, 90, 255),
            "D": (70, 130, 60, 255), "T": (176, 120, 70, 255), "B": (120, 170, 230, 255), "S": (190, 190, 200, 255),
            "O": (245, 150, 80, 255), "R": (220, 90, 90, 255)}
FINDS = {
    "find_leaf": ["....KK", "..KKGK", ".KGGDK", "KGGDGK", "KGDGK.", "KDKK..", "K....."],
    "find_flower": [".KK.KK.", "KPPKPPK", ".KPYPK.", "KPPKPPK", ".KK.KK.", "...K...", "..KGK.."],
    "find_acorn": ["..KKK..", ".KTTTK.", "KKKKKKK", ".KOOOK.", ".KOOOK.", "..KOK..", "...K..."],
    "find_button": [".KKKKK.", "KBBBBBK", "KBKBKBK", "KBBBBBK", "KBKBKBK", "KBBBBBK", ".KKKKK."],
    "find_shell": ["...K...", "..KPK..", ".KPWPK.", "KPWPWPK", "KPWPWPK", ".KKKKK.", "..KKK.."],
    "find_starfish": ["...K...", "..KOK..", "KKOOOKK", ".KOOOK.", ".KOKOK.", "KOK.KOK", "KK...KK"],
    "find_feather": [".....KK", "....KWK", "...KWBK", "..KWBK.", ".KWBK..", "KKBK...", "K.K...."],
    "find_pebble": ["..KKK..", ".KSSSK.", "KSSHSSK", "KSSSSSK", ".KSSSK.", "..KKK.."],
}

# ---------- Seasonal decor ----------


def plant_xmas():
    c = Canvas(18, 24)
    green, dark = (70, 140, 80, 255), (50, 110, 60, 255)
    for i, (y, half) in enumerate(((5, 3), (9, 5), (13, 7), (17, 8))):
        c.tri((9, y - 4), (9 - half, y + 2), (9 + half, y + 2), green if i % 2 == 0 else dark)
    c.rect(8, 19, 2, 2, (130, 80, 50, 255))
    c.rect(5, 21, 8, 3, (200, 70, 70, 255))
    for x, y, col in ((7, 9, (250, 205, 70, 255)), (11, 12, (120, 170, 230, 255)), (6, 15, (240, 90, 120, 255)),
                      (12, 17, (250, 205, 70, 255)), (9, 6, (240, 90, 120, 255))):
        c.set(x, y, col)
    c.set(9, 1, (250, 220, 90, 255))
    c.outline()
    return c


def plant_sakura():
    c = Canvas(18, 20)
    c.rect(8, 9, 2, 8, (120, 80, 60, 255))
    c.rect(5, 16, 8, 4, (180, 120, 90, 255))
    for cx, cy, r in ((9, 6, 5), (5, 8, 3), (13, 8, 3)):
        c.ellipse(cx, cy, r, r * 0.8, (250, 190, 205, 255))
    for x, y in ((7, 4), (11, 5), (4, 8), (14, 7), (9, 8)):
        c.set(x, y, (255, 225, 232, 255))
    c.outline()
    return c


def toy_beachball():
    c = Canvas(12, 12)
    c.ellipse(6, 6, 5.5, 5.5, W)
    c.rect(1, 5, 10, 2, (230, 80, 80, 255))
    c.rect(5, 1, 2, 10, (80, 140, 220, 255))
    c.ellipse(6, 6, 1.2, 1.2, (250, 205, 70, 255))
    c.outline()
    return c


# ---------- UI art ----------


def cushion():
    c = Canvas(40, 14)
    c.ellipse(20, 8, 19, 5.5, (200, 90, 110, 255))
    c.ellipse(20, 7, 17, 4, (235, 130, 150, 255))
    for x in (4, 36):
        c.rect(x - 1, 9, 2, 3, (250, 205, 70, 255))
    c.outline()
    return c


def empty_cat():
    """A sleeping cat for empty screens (no photos yet, empty diary)."""
    c = g.compose(g.ears("pointy", "sleep", 22), g.body_sleep(0))
    return c


def paw():
    return small([".K.K.K.", "KPKPKPK", ".K.K.K.", "..KKK..", ".KPPPK.", "KPPPPPK", ".KKKKK."],
                 {"K": K, "P": (240, 150, 170, 255)})


FONT = {  # 5x6 pixel letters for the logo
    "M": ["K...K", "KK.KK", "K.K.K", "K...K", "K...K", "K...K"],
    "e": [".....", ".KKK.", "K...K", "KKKKK", "K....", ".KKK."],
    "o": [".....", ".KKK.", "K...K", "K...K", "K...K", ".KKK."],
    "w": [".....", "K...K", "K...K", "K.K.K", "K.K.K", ".K.K."],
    "c": [".....", ".KKKK", "K....", "K....", "K....", ".KKKK"],
    "h": ["K....", "K....", "KKKK.", "K...K", "K...K", "K...K"],
    "i": ["..K..", ".....", ".KK..", "..K..", "..K..", ".KKK."],
}


def logo():
    text = "Meowchi"
    width = len(text) * 7 + 2
    c = Canvas(width, 9)
    orange, shade = (242, 153, 74, 255), (198, 94, 28, 255)
    for i, ch in enumerate(text):
        for y, row in enumerate(FONT[ch]):
            for x, v in enumerate(row):
                if v == "K":
                    c.set(1 + i * 7 + x + 1, 1 + y + 1, K)  # drop shadow
    for i, ch in enumerate(text):
        for y, row in enumerate(FONT[ch]):
            for x, v in enumerate(row):
                if v == "K":
                    c.set(1 + i * 7 + x, 1 + y, orange if y < 3 else shade)
    return c


def main():
    sprites = {**cat_poses(), "plant_xmas": plant_xmas(), "plant_sakura": plant_sakura(),
               "toy_beachball": toy_beachball(), "ui_cushion": cushion(), "ui_empty_cat": empty_cat(), "ui_logo": logo()}
    for name, canvas in sprites.items():
        save_image("Sprites", name, canvas)
    icons = {name: small([r.ljust(max(len(x) for x in rows), ".") for r in rows], FIND_PAL) for name, rows in FINDS.items()}
    icons["icon_paw"] = paw()
    for name, canvas in icons.items():
        save_image("Icons", name, canvas)
    print(f"{len(sprites)} sprites, {len(icons)} icons")


if __name__ == "__main__":
    main()
