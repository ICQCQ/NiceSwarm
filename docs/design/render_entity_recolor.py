"""Render a before/after entity recolor sheet for NiceSwarm.

Standalone run-once design utility: `python docs/design/render_entity_recolor.py`.
Nothing imports it. Reads no data files; writes one PNG
(docs/design/entity_recolor_before_after.png). Colour values are hardcoded
literals mirrored from scripts/config/enemy_config.gd and scripts/core/player.gd.

Faithfully replicates the Godot `_draw()` geometry/colours of every drawn entity
(player, all 34 enemy tiers, pickups, xp gems) so the proposed colour-psychology
remap can be reviewed visually BEFORE editing any config.

Fidelity notes (must match the GDScript):
- Enemy bodies pass through `_muted()` = HSV(h, s*0.8, v*0.9); overlays/player do NOT.
- Background fill = Color(0.07,0.08,0.12) — value-contrast baseline.
- Shapes: square = n4 + pi/4 (axis-aligned), diamond = n4 at heading, hex = n6,
  star = 10pts alt R/0.45R, triangle = n3. from_angle(0)=+X, Y-down (PIL matches).
- Overlay rings: elite gold(r+4), boss crimson(r+9), caster reticle(r+5)+cross,
  warden steel(r-3), burster 3 inner dark cells, sentinel shield bubble, immune aura.
"""
import colorsys, math
from PIL import Image, ImageDraw, ImageFont

SCALE = 2.0           # px per game unit for entity radius
BG = (0.07, 0.08, 0.12)


def c(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def muted(col):
    h, s, v = colorsys.rgb_to_hsv(col[0], col[1], col[2])
    return colorsys.hsv_to_rgb(h, s * 0.8, v * 0.9)


def darkened(col, amt):
    return (col[0] * (1 - amt), col[1] * (1 - amt), col[2] * (1 - amt))


def poly_pts(cx, cy, r, n, a0):
    return [(cx + math.cos(a0 + math.tau * i / n) * r,
             cy + math.sin(a0 + math.tau * i / n) * r) for i in range(n)]


def star_pts(cx, cy, r, a0):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a0 + math.tau * i / 10.0) * rr,
                    cy + math.sin(a0 + math.tau * i / 10.0) * rr))
    return pts


def draw_body(d, cx, cy, r, shape, col, heading=-math.pi / 2):
    """Replicates Enemy._draw_body / Player.draw_shape silhouettes."""
    fill = c(*col)
    if shape == "circle":
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    elif shape == "triangle":
        d.polygon(poly_pts(cx, cy, r, 3, heading), fill=fill)
    elif shape == "square":
        d.polygon(poly_pts(cx, cy, r, 4, heading + math.pi / 4), fill=fill)
    elif shape == "diamond":
        d.polygon(poly_pts(cx, cy, r, 4, heading), fill=fill)
    elif shape == "hex":
        d.polygon(poly_pts(cx, cy, r, 6, heading), fill=fill)
    elif shape == "star":
        d.polygon(star_pts(cx, cy, r, heading), fill=fill)


def arc(d, cx, cy, r, col, w):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c(*col), width=max(1, int(w)))


def draw_enemy(d, cx, cy, e):
    r = e["r"] * SCALE
    col = muted(e["col"])
    body = (1, 1, 1) if e.get("flash") else col
    draw_body(d, cx, cy, r, e["shape"], body)
    if e.get("burster"):
        for i in range(3):
            a = math.tau * i / 3.0
            p = (cx + math.cos(a) * r * 0.4, cy + math.sin(a) * r * 0.4)
            rr = r * 0.22
            d.ellipse([p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr], fill=c(*darkened(e["col"], 0.3)))
    if e.get("elite"):
        arc(d, cx, cy, r + 4 * SCALE, (1.0, 0.85, 0.3), 3)
    if e.get("boss"):
        arc(d, cx, cy, r + 9 * SCALE, (1.0, 0.15, 0.15), 4)
    if e.get("caster"):
        arc(d, cx, cy, r + 5 * SCALE, (1.0, 0.4, 0.3), 2)
        d.line([cx - r - 8 * SCALE, cy, cx + r + 8 * SCALE, cy], fill=c(1.0, 0.4, 0.3), width=2)
        d.line([cx, cy - r - 8 * SCALE, cx, cy + r + 8 * SCALE], fill=c(1.0, 0.4, 0.3), width=2)
    if e.get("resist"):
        arc(d, cx, cy, r - 3 * SCALE, (0.85, 0.9, 1.0), 3)
    if e.get("immune") is not None:
        elem = {"fire": (1.0, 0.5, 0.2), "ice": (0.6, 0.85, 1.0), "energy": (0.8, 0.7, 1.0)}[e["immune"]]
        arc(d, cx, cy, r + 3 * SCALE, elem, 2)
    if e.get("shielded"):
        rr = r + 6 * SCALE
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c(0.5, 0.8, 1.0, 0.28))
        arc(d, cx, cy, rr, (0.7, 0.9, 1.0), 2)


def draw_player(d, cx, cy, body):
    r = 14.0 * SCALE
    rr = r + 3 * SCALE
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c(0, 0, 0, 0.5))
    draw_body(d, cx, cy, r, "circle", body)
    rc = r * 0.45
    d.ellipse([cx - rc, cy - rc, cx + rc, cy + rc], fill=c(0.1, 0.25, 0.4))
    fa = -math.pi / 2
    notch = [(cx + math.cos(fa) * (r + 5 * SCALE), cy + math.sin(fa) * (r + 5 * SCALE)),
             (cx + math.cos(fa + 0.45) * (r - 1 * SCALE), cy + math.sin(fa + 0.45) * (r - 1 * SCALE)),
             (cx + math.cos(fa - 0.45) * (r - 1 * SCALE), cy + math.sin(fa - 0.45) * (r - 1 * SCALE))]
    d.polygon(notch, fill=c(1, 1, 1, 0.9))


# ---- entity tables: name, shape, r, before-col, after-col, flags ----
E = [
    ("Grunt", "circle", 12, (0.85,0.3,0.35), (0.85,0.3,0.35), {}),
    ("Bruiser", "circle", 15, (0.9,0.42,0.32), (0.9,0.42,0.32), {}),
    ("Reaver", "circle", 17, (0.98,0.52,0.36), (0.98,0.52,0.36), {}),
    ("Runner", "triangle", 9, (0.95,0.6,0.2), (0.95,0.6,0.2), {}),
    ("Sprinter", "triangle", 10, (1.0,0.72,0.2), (1.0,0.72,0.2), {}),
    ("Brute", "hex", 24, (0.6,0.2,0.7), (0.6,0.2,0.7), {}),
    ("Behemoth", "hex", 30, (0.72,0.26,0.82), (0.72,0.26,0.82), {}),
    ("Bomber", "circle", 15, (0.55,0.12,0.12), (0.55,0.12,0.12), {"caster":1}),
    ("Diviner", "circle", 16, (0.4,0.2,0.6), (0.4,0.2,0.6), {"caster":1}),
    ("Oracle", "circle", 18, (0.55,0.25,0.72), (0.55,0.25,0.72), {"caster":1}),
    ("Shieldling", "square", 16, (0.55,0.6,0.72), (0.72,0.5,0.4), {"resist":1}),
    ("Bulwark", "square", 20, (0.62,0.67,0.8), (0.8,0.58,0.45), {"resist":1}),
    ("Spore", "star", 14, (0.4,0.72,0.42), (0.88,0.62,0.18), {"burster":1}),
    ("Brood", "star", 18, (0.45,0.82,0.46), (0.95,0.7,0.2), {"burster":1}),
    ("Shard", "triangle", 7, (0.6,0.95,0.6), (1.0,0.5,0.25), {}),
    ("Sentinel", "square", 16, (0.35,0.55,0.7), (0.5,0.3,0.55), {"shielded":1}),
    ("Aegis", "square", 19, (0.4,0.62,0.78), (0.58,0.36,0.62), {"shielded":1}),
    ("Mote", "diamond", 11, (0.8,0.7,1.0), (0.66,0.45,0.95), {"immune":"energy"}),
    ("Wisp", "diamond", 13, (0.86,0.76,1.0), (0.72,0.5,1.0), {"immune":"energy"}),
    ("Caroms", "diamond", 14, (0.95,0.85,0.3), (1.0,0.35,0.5), {}),
    ("Pinball", "diamond", 16, (1.0,0.9,0.35), (1.0,0.4,0.55), {}),
    ("Hexer", "diamond", 15, (0.6,0.3,0.7), (0.6,0.3,0.7), {"caster":1}),
    ("Nullifier", "diamond", 17, (0.66,0.34,0.78), (0.66,0.34,0.78), {"caster":1}),
    ("Warlock", "diamond", 16, (0.45,0.25,0.6), (0.45,0.25,0.6), {"caster":1}),
    ("Defiler", "diamond", 18, (0.5,0.28,0.66), (0.5,0.28,0.66), {"caster":1}),
    ("Jammer", "hex", 17, (0.25,0.75,0.85), (0.6,0.15,0.28), {}),
    ("Scrambler", "hex", 16, (0.3,0.8,0.9), (0.7,0.2,0.32), {}),
    ("Disperser", "hex", 17, (0.35,0.85,0.95), (0.8,0.25,0.35), {}),
    ("Overseer", "hex", 19, (0.4,0.9,1.0), (0.9,0.3,0.4), {}),
    ("Elite", "circle", 18, (0.95,0.35,0.5), (0.95,0.35,0.5), {"elite":1}),
    ("Champion", "circle", 22, (1.0,0.45,0.6), (1.0,0.45,0.6), {"elite":1}),
    ("Juggernaut", "hex", 34, (0.55,0.05,0.05), (0.55,0.05,0.05), {"boss":1,"elite":1}),
    ("Harbinger", "star", 30, (0.35,0.05,0.5), (0.35,0.05,0.5), {"boss":1,"elite":1}),
    ("Eclipse", "circle", 38, (0.1,0.04,0.16), (0.1,0.04,0.16), {"boss":1,"elite":1}),
]

PLAYER_BEFORE = [(0.45,0.9,1.0),(0.5,1.0,0.6),(1.0,0.85,0.4),(1.0,0.55,0.8),(0.7,0.55,1.0),(1.0,0.6,0.3)]
PLAYER_AFTER  = [(0.40,0.88,1.0),(0.55,1.0,0.55),(1.0,0.85,0.35),(0.25,0.95,0.80),(0.45,0.62,1.0),(0.80,1.0,0.45)]
PLAYER_NAMES = ["P0 cyan (keep)","P1 green (keep)","P2 amber (keep)","P3 pink->aqua","P4 purple->azure","P5 orange->chartreuse"]

ITEMS = [
    ("XP gem (normal)", "gem", (0.45,1.0,0.55), (0.45,1.0,0.55)),
    ("XP gem (condensed)", "gem_hi", (1.0,0.3,0.3), (1.0,0.85,0.4)),
    ("Heart (heal*)", "heart", (0.95,0.3,0.4), (0.95,0.3,0.4)),
    ("Magnet", "magnet", (0.35,0.6,1.0), (0.35,0.6,1.0)),
]


def draw_item(d, cx, cy, key, col):
    r = 13 * SCALE
    if key in ("gem", "gem_hi"):
        d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=c(*col))
        if key == "gem_hi":
            rr = r*0.5
            d.ellipse([cx-rr, cy-rr, cx+rr, cy+rr], fill=c(1,1,1))
    elif key == "heart":
        d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=c(*col))
        d.line([cx-7*SCALE, cy, cx+7*SCALE, cy], fill=c(1,1,1), width=int(3*SCALE))
        d.line([cx, cy-7*SCALE, cx, cy+7*SCALE], fill=c(1,1,1), width=int(3*SCALE))
    elif key == "magnet":
        arc(d, cx, cy, r, col, 4)


# ---- layout ----
TILE = 190
LABEL_W = 160
COL_W = TILE
PAD = 14
HEADER_H = 40

try:
    font = ImageFont.truetype("arial.ttf", 14)
    fontB = ImageFont.truetype("arialbd.ttf", 16)
except Exception:
    font = fontB = ImageFont.load_default()

rows = [("header", "PLAYER  - cool / bright / high-value (60 body | 30 dark core+halo | 10 white notch)")]
rows += [("player", i) for i in range(6)]
rows.append(("header", "ENEMIES  - warm danger band (red / orange / deep-violet); SHAPE = archetype id"))
rows += [("enemy", e) for e in E]
rows.append(("header", "PICKUPS / XP  - stay player-coded so loot never reads as a threat"))
rows += [("item", it) for it in ITEMS]

H = PAD + sum(HEADER_H if k == "header" else TILE for k, _ in rows) + PAD
W = LABEL_W + COL_W * 2 + PAD * 2

img = Image.new("RGB", (W, H), (8, 8, 13))
d = ImageDraw.Draw(img, "RGBA")

y = PAD
for kind, payload in rows:
    if kind == "header":
        d.rectangle([0, y, W, y + HEADER_H], fill=(20, 22, 34))
        d.text((PAD, y + 11), payload, font=fontB, fill=(235, 235, 245))
        d.text((LABEL_W + COL_W*0.5 - 28, y + 12), "BEFORE", font=font, fill=(150,150,160))
        d.text((LABEL_W + COL_W*1.5 - 22, y + 12), "AFTER", font=font, fill=(150,210,150))
        y += HEADER_H
        continue
    name = PLAYER_NAMES[payload] if kind == "player" else payload[0]
    d.text((PAD, y + TILE//2 - 8), name, font=fontB, fill=(220,220,230))
    for col_i, which in enumerate(("before", "after")):
        tx = LABEL_W + col_i * COL_W
        d.rectangle([tx+4, y+4, tx+COL_W-4, y+TILE-4], fill=c(*BG)[:3])
        cx, cy = tx + COL_W/2, y + TILE/2
        if kind == "player":
            draw_player(d, cx, cy, PLAYER_BEFORE[payload] if which == "before" else PLAYER_AFTER[payload])
        elif kind == "enemy":
            name_, shape, r, b4, af, flags = payload
            draw_enemy(d, cx, cy, {"shape": shape, "r": r, "col": b4 if which == "before" else af, **flags})
        else:
            name_, key, b4, af = payload
            draw_item(d, cx, cy, key, b4 if which == "before" else af)
    y += TILE

img.save("docs/design/entity_recolor_before_after.png")
print("saved docs/design/entity_recolor_before_after.png", img.size)
