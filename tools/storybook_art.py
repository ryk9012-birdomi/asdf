"""Storybook heroes: the knight, rogue and mage from the character sheet, drawn for the
same puppet rig (same part names and pivots as generate_hero_art.py).

Round chibi faces in three-quarter view with big shining eyes and rosy cheeks, soft brown
outlines, and a warm palette: olive green, leather brown, ochre, cream, royal blue and
brick red. Called from generate_hero_art.main(); writes godot/art/heroes/<class>/.
"""
import math
import os

import generate_hero_art as base

LINE = "#5a3a28"
SW = f'stroke="{LINE}" stroke-width="1.1" stroke-linejoin="round" stroke-linecap="round"'
THIN = f'stroke="{LINE}" stroke-width="0.7" stroke-linejoin="round" stroke-linecap="round"'
SKIN = ("#fde6d2", "#f6cfb2", "#e8b090")
GOLD = ("#f6d77a", "#d9a441", "#a8752a")
LEATHER = ("#b07a4a", "#8a5a34", "#5e3a20")
STEEL = ("#f1f2f0", "#c9ccd0", "#8e949c")
CREAM = ("#fbf4e4", "#f1e4c8", "#d9c6a0")

# Where the head's drawing sits in its canvas: the rig's head pivot is (20+LEFT, 46+TOP).
LEFT, TOP, HEAD_W = 16, 30, 80


def grad(name, colors, vertical=False):
    x2, y2 = ("0", "1") if vertical else ("1", "0.25")
    stops = "".join(f'<stop offset="{i / (len(colors) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(colors))
    return f'<linearGradient id="{name}" x1="0" y1="0" x2="{x2}" y2="{y2}">{stops}</linearGradient>'


def common(skin=SKIN):
    return [grad("skin", [skin[2], skin[0], skin[1]]), grad("gold", GOLD, True), grad("leather", [LEATHER[2], LEATHER[0], LEATHER[1]]),
            grad("steel", [STEEL[2], STEEL[0], STEEL[1], STEEL[2]]), grad("steelv", STEEL, True), grad("cream", [CREAM[2], CREAM[0], CREAM[1]])]


def write(folder, name, w, h, defs, body):
    base.write(folder, name, w, h, defs, body)


def fleur(cx, cy, r, color="url(#gold)"):
    """Fleur-de-lis from three petals and a band."""
    return (f'<path d="M{cx} {cy - r * 1.6} Q{cx + r * 0.7} {cy - r * 0.6} {cx} {cy + r * 0.2} Q{cx - r * 0.7} {cy - r * 0.6} {cx} {cy - r * 1.6} Z" fill="{color}" {THIN}/>'
            f'<path d="M{cx - r * 0.2} {cy - r * 0.1} Q{cx - r * 1.5} {cy - r * 1.0} {cx - r * 1.3} {cy + r * 0.3} Q{cx - r * 0.9} {cy + r * 0.1} {cx - r * 0.3} {cy + r * 0.5} Z" fill="{color}" {THIN}/>'
            f'<path d="M{cx + r * 0.2} {cy - r * 0.1} Q{cx + r * 1.5} {cy - r * 1.0} {cx + r * 1.3} {cy + r * 0.3} Q{cx + r * 0.9} {cy + r * 0.1} {cx + r * 0.3} {cy + r * 0.5} Z" fill="{color}" {THIN}/>'
            f'<rect x="{cx - r * 0.8}" y="{cy + r * 0.35}" width="{r * 1.6}" height="{r * 0.35}" rx="{r * 0.15}" fill="{color}" {THIN}/>'
            f'<path d="M{cx} {cy + r * 0.7} L{cx - r * 0.35} {cy + r * 1.4} L{cx + r * 0.35} {cy + r * 1.4} Z" fill="{color}" {THIN}/>')


def leaf(cx, cy, r, angle, color):
    return (f'<path d="M0 0 Q{r * 0.6} {-r * 0.5} {r * 1.4} 0 Q{r * 0.6} {r * 0.5} 0 0 Z" transform="translate({cx},{cy}) rotate({angle})" fill="{color}" opacity="0.85"/>')


def flower(cx, cy, r, petal, heart="#e8b040"):
    out = ""
    for i in range(5):
        a = math.tau * i / 5
        out += f'<circle cx="{cx + math.cos(a) * r * 0.8:.2f}" cy="{cy + math.sin(a) * r * 0.8:.2f}" r="{r * 0.62:.2f}" fill="{petal}" {THIN}/>'
    return out + f'<circle cx="{cx}" cy="{cy}" r="{r * 0.45:.2f}" fill="{heart}"/>'


# ------------------------------------------------------------------ faces
# Face coordinates: the neck pivot is at (20,46); the round face is centred near (25,25).

FACE = ("M8.6 24 Q8 9 24 7.6 Q40 7.6 42.4 22 Q43.4 30 40 36.6 Q35 44 26 44.4 Q15 44.6 10.6 36 Q8.8 31 8.6 24 Z")


def eye(x, y, mood, near=True, iris="#6a4226"):
    rx, ry = (3.4, 4.4) if near else (2.8, 4.0)
    if mood in ("blink", "down"):
        # Closed: a happy arc when blinking, a tired line when down.
        bend = -2.4 if mood == "blink" else 1.2
        return f'<path d="M{x - rx} {y + 0.6} Q{x} {y + bend} {x + rx} {y + 0.6}" fill="none" stroke="{LINE}" stroke-width="1.3" stroke-linecap="round"/>'
    if mood == "hurt":
        side = 1 if near else -1
        return f'<path d="M{x - rx * side} {y - 2.6} L{x + rx * 0.8 * side} {y} L{x - rx * side} {y + 2.6}" fill="none" stroke="{LINE}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    return (f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{iris}" stroke="{LINE}" stroke-width="0.8"/>'
            f'<ellipse cx="{x + 0.3}" cy="{y + 1.2}" rx="{rx * 0.62}" ry="{ry * 0.55}" fill="{base.shade(iris, 0.55)}"/>'
            f'<circle cx="{x - rx * 0.35}" cy="{y - ry * 0.4}" r="{rx * 0.42}" fill="#ffffff"/>'
            f'<circle cx="{x + rx * 0.4}" cy="{y + ry * 0.35}" r="{rx * 0.2}" fill="#ffffff" opacity="0.85"/>'
            f'<path d="M{x - rx - 0.6} {y - ry + 0.4} Q{x} {y - ry - 1.6} {x + rx + 0.4} {y - ry + 0.2}" fill="none" stroke="{LINE}" stroke-width="1.4" stroke-linecap="round"/>')


def face(mood, iris="#6a4226", brow="#8a5a34", ear=True, glow=None, mask=None, nose=None, fang=False):
    brows = {
        "shout": (f"M20.6 16.4 L27 18.4", f"M32.6 18.2 L38.4 16.8"),
        "hurt": (f"M20.8 18.4 Q24 15.6 27 16.4", f"M32.8 16.6 Q36 15.6 38.6 17.6"),
    }.get(mood, (f"M20.8 17 Q24 15.4 27 16.2", f"M32.6 16.2 Q35.8 15.2 38.4 16.6"))
    mouth = {
        "idle": f'<path d="M31 35.6 Q33.6 37.8 36.4 35.4" fill="none" stroke="{LINE}" stroke-width="1.1" stroke-linecap="round"/>',
        "blink": f'<path d="M30.4 35 Q33.6 39.6 37 34.8 Z" fill="#c8504a" {THIN}/>',
        "shout": f'<path d="M29.6 34.2 Q33.6 33.4 37.6 34 Q37.4 40.6 33.4 41 Q29.6 40.4 29.6 34.2 Z" fill="#b8403a" {THIN}/><path d="M31 38.8 Q33.4 40.2 36 38.8" fill="none" stroke="#f08a80" stroke-width="1"/>',
        "hurt": f'<path d="M30.4 37.4 Q32 35.8 33.6 37.2 Q35 38.6 36.8 36.8" fill="none" stroke="{LINE}" stroke-width="1.1" stroke-linecap="round"/>',
        "down": f'<path d="M31 37 Q33.6 36 36.2 37.2" fill="none" stroke="{LINE}" stroke-width="1" stroke-linecap="round"/>',
    }[mood]
    extra = ""
    if mood == "hurt":
        extra = '<path d="M41 12 Q43.4 16 41.6 18 Q39.6 16.6 41 12 Z" fill="#9fd4ff" stroke="#5a8ab0" stroke-width="0.6"/>'
    if mood == "down":
        extra = '<path d="M36 6 q2 -2 4 0 q2 2 4 0" fill="none" stroke="#9a8aa0" stroke-width="0.9"/>'
    if glow and mood not in ("blink", "down"):
        eyes = "".join(f'<ellipse cx="{x}" cy="25" rx="{r * 1.8}" ry="{r * 1.4}" fill="{glow}" opacity="0.35"/><ellipse cx="{x}" cy="25" rx="{r}" ry="{r * 0.75}" fill="{glow}"/>' for x, r in ((24.4, 2.6), (36.2, 2.2)))
    else:
        eyes = eye(24.4, 25, mood, True, iris) + eye(36.2, 25, mood, False, iris)
    if fang and mood in ("idle", "blink"):
        mouth += f'<path d="M33 36.2 L34 38.6 L35 36.2 Z" fill="#ffffff" {THIN}/>'
    if nose:
        extra += nose
    cover = ""
    if mask:
        cover = f'<path d="M9.4 30 Q26 26 42.8 29.6 Q42 38 36 42.4 Q26 46.6 15 43 Q9.6 38 9.4 30 Z" fill="{mask}" {SW}/>'
        mouth = ""
    return (f'<path d="{FACE}" fill="url(#skin)" {SW}/>'
            + (f'<path d="M11.4 24 Q9 22 8 25 Q7.6 29.6 11.6 30.6 Z" fill="url(#skin)" {THIN}/>' if ear else "")
            + ('' if mask else f'<ellipse cx="24.4" cy="32" rx="3.4" ry="2" fill="#f49a9a" opacity="0.55"/><ellipse cx="38" cy="32" rx="2.8" ry="1.8" fill="#f49a9a" opacity="0.55"/>')
            + cover + eyes +
            f'<path d="{brows[0]}" fill="none" stroke="{brow}" stroke-width="1.3" stroke-linecap="round"/>'
            f'<path d="{brows[1]}" fill="none" stroke="{brow}" stroke-width="1.2" stroke-linecap="round"/>'
            f'<path d="M41 30.4 Q42.2 31.4 41 32" fill="none" stroke="{SKIN[2]}" stroke-width="1" stroke-linecap="round"/>'
            + mouth + extra)


def curls(points, radius, fill, line=SW):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" {line}/>' for x, y, r in [(p[0], p[1], p[2] * radius) for p in points])


def heads(folder, defs, back, front, iris="#6a4226", brow="#8a5a34", top=TOP, draw=None, **looks):
    """Five expressions. `draw(mood)` replaces the face entirely (skulls); `looks` go to face()."""
    for mood in ["idle", "blink", "shout", "hurt", "down"]:
        name = "head" if mood == "idle" else "head_" + mood
        neck = f'<path d="M16 40 L28 40 L29 50 L15 50 Z" fill="url(#skin)" {THIN}/>'
        middle = draw(mood) if draw else face(mood, iris, brow, **looks)
        write(folder, name, HEAD_W, 50 + top + 14, defs,
              f'<g transform="translate({LEFT},{top})">{back}{neck}{middle}{front}</g>')
    write(folder, "plume", 30, 24, [], "")


# ------------------------------------------------------------------ shared body parts

def boots(folder, color=LEATHER, cuff="#c8925a"):
    write(folder, "shin", 32, 38, common(), f'''
<path d="M6.4 4 Q11 2.4 15.8 4 L15.6 18 L6.6 18 Z" fill="{{legs}}" {SW}/>
<path d="M5.4 14 Q11 12 16.8 14 L16.4 27 Q22.4 26.6 27.6 29.6 Q30 31.6 29 34.4 Q28.6 36.2 26 36.2 L6.4 36.4 Q4.4 31 5.4 26 Z" fill="url(#leather)" {SW}/>
<path d="M4.6 12.6 Q11 10 17.6 12.6 L17.2 17.6 Q11 15.6 5 17.6 Z" fill="{cuff}" {SW}/>
<path d="M8 22 L14 21 M8.4 25.6 L14.4 24.8" stroke="{LEATHER[2]}" stroke-width="0.8"/>
<path d="M5.8 34.6 L28.6 34.6" stroke="{LINE}" stroke-width="1"/>
<path d="M19 29.4 Q23 29.6 26.4 31.6" fill="none" stroke="#ffffff" stroke-width="0.9" opacity="0.45"/>''')


def legs_file(folder, legs, extra=""):
    path = os.path.join(folder, "shin.svg")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    with open(path, "w", encoding="utf-8") as f:
        f.write(text.replace("{legs}", legs))
    write(folder, "thigh", 22, 36, common(), f'''
<path d="M4.6 1.6 Q11 -0.4 17.4 1.6 L16.6 31.4 Q11 33.4 5.4 31.4 Z" fill="{legs}" {SW}/>
<path d="M9 6 Q9.6 16 9 28" fill="none" stroke="#ffffff" stroke-width="0.9" opacity="0.25"/>{extra}''')


def glove_hand(folder, color, fingers=None):
    tips = ""
    if fingers:
        tips = f'<path d="M3 11.2 Q8 14.8 13.4 11.4 L13.8 13 Q8 16.6 2.6 13 Z" fill="url(#skin)" {THIN}/>'
    write(folder, "hand", 16, 18, common(), f'''
<path d="M2.6 2.6 Q8 0.8 13.4 2.6 L14 12.4 Q8 15.2 2.4 12.4 Z" fill="{color}" {SW}/>
<path d="M3 6.8 L13.4 6.8" stroke="#000000" stroke-opacity="0.2" stroke-width="0.8"/>
<path d="M12.6 3.6 Q15.4 6.4 13.4 9.8" fill="none" stroke="{LINE}" stroke-width="0.9"/>{tips}''')


# ------------------------------------------------------------------ knight

def knight(folder):
    d = common() + [grad("blue", ["#2e467e", "#4a6ab0", "#34508e"]), grad("bluev", ["#4a6ab0", "#2e467e"], True)]
    legs_color = "#4a3a52"
    boots(folder)
    legs_file(folder, legs_color, f'<path d="M4 3 Q11 0 18 3 L17.2 20 Q11 23.4 4.8 20 Z" fill="url(#steel)" {SW}/><circle cx="11" cy="22.4" r="3.4" fill="url(#steelv)" {SW}/>')
    write(folder, "torso", 52, 72, d, f'''
<path d="M11 46 L40 46 L42.6 64 Q26 67.6 9 64 Z" fill="url(#blue)" {SW}/>
<path d="M12 46 L20 46 L19 58 Q15 59 11.6 57.6 Z M31 46 L39.6 46 L40.6 57.6 Q36 59 32 58 Z" fill="url(#steel)" {THIN}/>
<path d="M12.6 20 Q14.6 12.6 25 12 Q37 12 40.6 19.6 Q44 30 40.6 45 L12 46 Q8.8 34 12.6 20 Z" fill="url(#steel)" {SW}/>
<path d="M21 16 Q30 15 38.6 19 Q41.6 32 39.4 47 L40.6 64 Q30 66.8 21.4 64 L22.6 47 Q20.4 32 21 16 Z" fill="url(#cream)" {SW}/>
<path d="M22.4 18 Q30 16.8 38 20.4 M39.6 62 Q30 64.6 22.4 62" fill="none" stroke="url(#gold)" stroke-width="1.6"/>
{fleur(30.4, 31, 3.4)}
{fleur(30.8, 54, 2.2)}
<path d="M10.4 43.4 L41.6 43.4 L41.8 48.4 L10.2 48.4 Z" fill="url(#leather)" {SW}/>
<rect x="28" y="42.6" width="6" height="6.6" rx="1.2" fill="url(#gold)" {THIN}/>
<rect x="14" y="47" width="6" height="6.4" rx="1.2" fill="url(#leather)" {THIN}/>
<path d="M15.4 11 Q25 7.6 35.4 11 L36.4 17.4 Q25 15 14.6 17.4 Z" fill="url(#steelv)" {SW}/>''')
    write(folder, "cape", 36, 92, d, f'''
<path d="M18 2 Q29 -0.4 31 6 L29.6 40 Q29 62 31.6 84 Q20 88 9 84 Q2 82 1 78 Q5.6 50 10 20 Q12 6 18 2 Z" fill="url(#blue)" {SW}/>
<path d="M1 78 Q5.6 50 10 20 Q9.8 50 5.6 80 Z" fill="#26386a"/>
<path d="M9 84 Q20 88 31.6 84 L31.2 80.6 Q20 84.4 9.4 80.6 Z" fill="url(#gold)" {THIN}/>
{"".join(fleur(x, y, 1.6) for x, y in ((18, 26), (24, 44), (15, 58), (23, 70)))}
<path d="M20 12 Q18.4 46 16.6 82 M26 12 Q25.4 48 26 82" fill="none" stroke="#26386a" stroke-width="1"/>''')
    write(folder, "arm_upper", 30, 30, d, f'''
<path d="M9 7 L19.4 7 L18.8 27 L9.6 27 Z" fill="url(#blue)" {SW}/>
<path d="M3 12.4 Q3.6 1 15 0.6 Q26.4 1 27 12.4 Q21 9 15 9.2 Q9 9.4 3 12.4 Z" fill="url(#steelv)" {SW}/>
<path d="M4.6 15.6 Q15 11.6 25.4 15.6 L24.8 19 Q15 15.6 5.2 19 Z" fill="url(#steelv)" {THIN}/>
<path d="M6 6.6 Q10 2.6 16 2.4" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.7"/>
<circle cx="15" cy="5.6" r="1.2" fill="url(#gold)" {THIN}/>''')
    write(folder, "arm_lower", 18, 30, d, f'''
<path d="M4.4 4 L13.6 4 L12.6 20 L5.4 20 Z" fill="url(#steel)" {SW}/>
<circle cx="9" cy="4" r="4.2" fill="url(#steelv)" {SW}/>
<path d="M3.4 16.4 Q9 14.6 14.6 16.4 L15 22.6 Q9 24 3 22.6 Z" fill="url(#leather)" {SW}/>''')
    glove_hand(folder, "url(#leather)")
    back = curls([(8, 22, 1.2), (6, 30, 1.0), (10, 12, 1.2), (18, 6, 1.3), (28, 4.6, 1.3), (37, 7, 1.2), (43, 13, 1.0), (8, 37, 0.9)],
                 6.4, "url(#hair)")
    front = (curls([(22, 9, 0.9), (29, 8, 0.85), (35, 10, 0.8), (40, 14, 0.7), (16, 12, 0.8)], 5.2, "url(#hair)")
             + '<path d="M14 16 Q16 10 22 12 M26 12 Q30 8 34 13" fill="none" stroke="#b07a2a" stroke-width="0.9"/>')
    heads(folder, d + [grad("hair", ["#f6d58a", "#e0b060", "#c08a3a"], True)], back, front, iris="#5a7ab0", brow="#b07a2a")
    base.write(folder, "weapon", 28, 110, d, f'''
<path d="M14 26 L17.6 33 L17 81 L11 81 L10.4 33 Z" fill="url(#steel)" {SW}/>
<path d="M14 33 L14 78" stroke="#8e949c" stroke-width="0.9"/>
<path d="M5 79.6 Q14 77 23 79.6 Q24.6 81.8 23 84 Q14 81.8 5 84 Q3.4 81.8 5 79.6 Z" fill="url(#gold)" {SW}/>
<rect x="11.8" y="84" width="4.4" height="11" rx="1.2" fill="url(#leather)" {THIN}/>
<circle cx="14" cy="98" r="3.2" fill="url(#gold)" {SW}/>''')
    base.write(folder, "shield", 40, 50, d, f'''
<path d="M4 4 L36 4 L35.2 22 Q32 38 20 47 Q8 38 4.8 22 Z" fill="url(#gold)" {SW}/>
<path d="M6.8 6.8 L33.2 6.8 L32.6 21.6 Q29.8 35 20 43.4 Q10.2 35 7.4 21.6 Z" fill="url(#blue)" {THIN}/>
{fleur(20, 22, 5)}
<path d="M9.6 9.6 Q13 8.6 16 8.6" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.6"/>''')
    base.glow(folder)


# ------------------------------------------------------------------ rogue

def rogue(folder):
    green = ("#8a9a52", "#6b7a3e", "#4a5a2a")
    d = common() + [grad("green", [green[2], green[0], green[1]]), grad("greenv", [green[0], green[2]], True)]
    boots(folder, cuff="#a8703e")
    legs_file(folder, "#4a3a44")
    motif = "".join(leaf(x, y, 2.4, a, GOLD[1]) for x, y, a in ((14, 26, -30), (22, 40, 20), (12, 52, -10), (20, 64, 30), (26, 20, 60)))
    write(folder, "torso", 52, 72, d, f'''
<path d="M12 45 L40 45 L42 62 L36 58 L32 64 L27 58 L22 64 L17 58 L10 62 Z" fill="url(#green)" {SW}/>
<path d="M12.6 20 Q14.6 12.6 25 12 Q37 12 40.6 19.6 Q44 30 40.6 45 L12 46 Q8.8 34 12.6 20 Z" fill="url(#cream)" {SW}/>
<path d="M16 16 Q22 14 28 15 L27 46 L15 46 Q12.6 30 16 16 Z M33 16 Q38 17 40 21 Q42.6 32 40 46 L33.6 46 Z" fill="url(#leather)" {SW}/>
<path d="M14 18 L39 40 L37.4 43 L12.4 21 Z" fill="{LEATHER[2]}" {THIN}/>
<path d="M10.4 43.4 L41.6 43.4 L41.8 48.4 L10.2 48.4 Z" fill="url(#leather)" {SW}/>
<rect x="28.4" y="42.6" width="5.6" height="6.6" rx="1.2" fill="url(#gold)" {THIN}/>
<rect x="15" y="47" width="7" height="8" rx="1.6" fill="url(#leather)" {SW}/>
<path d="M15 50 L22 50" stroke="{LEATHER[2]}" stroke-width="0.8"/>
<rect x="33" y="47" width="6" height="7" rx="1.4" fill="url(#leather)" {SW}/>
<path d="M17 11.4 Q25 8.6 34.6 11.6 L35.6 17 Q25 14.8 16 17 Z" fill="url(#green)" {SW}/>''')
    write(folder, "cape", 40, 92, d, f'''
<path d="M24 0 L32 -4" stroke="none"/>
<rect x="26" y="-2" width="7" height="30" rx="2" transform="rotate(18 29 12)" fill="url(#leather)" {SW}/>
{"".join(f'<path d="M{27 + i * 2.4} -2 l1.2 -5 l1.2 5 Z" fill="#e8e0c8" {THIN} transform="rotate(18 29 12)"/>' for i in range(3))}
<path d="M18 2 Q29 -0.4 31 6 L29.4 36 Q29 50 31 62 L26 58 L22 64 L17.6 58.6 L12 64 L9 57 L3 60 Q6 40 10 20 Q12 6 18 2 Z" fill="url(#green)" {SW}/>
{motif}
<path d="M20 12 Q18.6 36 17.4 58 M25.6 12 Q25 36 25.6 58" fill="none" stroke="{green[2]}" stroke-width="1"/>''')
    write(folder, "arm_upper", 30, 30, d, f'''
<path d="M7.4 5 Q14 1.6 20.6 5 L21 25 Q14 28.6 7.6 25 Z" fill="url(#cream)" {SW}/>
<path d="M10.6 10 Q11.4 18 10.6 24 M17.6 10 Q17 18 17.8 24" fill="none" stroke="{CREAM[2]}" stroke-width="0.8"/>
<path d="M5 9.4 Q6 1.6 14.6 1.2 Q23 1.6 23.6 9.4 Q18.6 7 14.4 7.2 Q9.4 7.4 5 9.4 Z" fill="url(#green)" {SW}/>''')
    write(folder, "arm_lower", 18, 30, d, f'''
<path d="M4.6 2.6 L13.4 2.6 L12.8 10 L5.2 10 Z" fill="url(#cream)" {SW}/>
<path d="M4 8.6 Q9 7.2 14 8.6 L13.4 22.4 Q9 23.6 4.6 22.4 Z" fill="url(#leather)" {SW}/>
<path d="M4.6 13 L13.4 13 M4.8 17.6 L13.2 17.6" stroke="{LEATHER[2]}" stroke-width="0.8"/>''')
    glove_hand(folder, "url(#leather)", fingers=True)
    hood_back = (f'<path d="M1 44 Q-7 6 22 -6 Q44 -8 48.6 14 Q49.6 22 45.6 29 L42 20 Q36 10 26 10 Q16 10 12 20 L12.6 58 L-1 58 Q-2 50 1 44 Z" fill="url(#green)" {SW}/>'
                 + "".join(leaf(x, y, 2.4, a, GOLD[1]) for x, y, a in ((4, 30, -70), (6, 44, -80), (2, 52, -90))))
    hair = ('<path d="M14 21 Q16 10 27 10.6 Q37.6 11 41 20 Q35 17 30 18 Q26 14 21 18 Q17 17 14 21 Z" fill="url(#hair)" stroke="#5a3a28" stroke-width="0.8"/>'
            '<path d="M11.6 24 Q9.6 34 12.6 40 Q14 32 14.6 26 Z" fill="url(#hair)" stroke="#5a3a28" stroke-width="0.7"/>')
    hood_front = (f'<path d="M45.6 29 Q49.6 16 41 5.6 Q30 -2 17 2.4 Q7.6 7.6 9 24 L12.6 22 Q14.4 11.6 26 10.2 Q37.4 10.4 42.4 21 Z" fill="url(#green)" {SW}/>'
                  f'<path d="M12.6 22 Q14.4 11.6 26 10.2 Q37.4 10.4 42.4 21" fill="none" stroke="{green[2]}" stroke-width="2"/>'
                  + "".join(leaf(x, y, 2.2, a, GOLD[1]) for x, y, a in ((18, 4, -20), (30, 2, 10), (8, 16, -70), (42, 9, 50))))
    heads(folder, d + [grad("hair", ["#9a6a40", "#7a4a2a", "#5a3420"], True)], hood_back, hair + hood_front, iris="#6a4226", brow="#6a4226")
    b = base.BLADES["steel"]
    dagger = (f'<path d="M14 54 L17.2 60 L16.8 81 L11.2 81 L10.8 60 Z" fill="url(#steel)" {SW}/>'
              f'<path d="M7.6 79.8 Q14 78.2 20.4 79.8 Q21.6 81.6 20.4 83.4 Q14 82 7.6 83.4 Q6.4 81.6 7.6 79.8 Z" fill="url(#gold)" {SW}/>'
              f'<rect x="12" y="83.4" width="4" height="10" rx="1" fill="url(#leather)" {THIN}/>'
              f'<circle cx="14" cy="95.6" r="2.4" fill="url(#gold)" {THIN}/>')
    base.write(folder, "weapon", 28, 110, d, dagger)
    base.write(folder, "shield", 64, 64, d, f'<g transform="rotate(-42 20 22)"><g transform="translate(6,-68) rotate(180 14 90)">{dagger}</g></g>')
    base.glow(folder, ("#fff6e8", "#ffe0a8", "#ffb070"))


# ------------------------------------------------------------------ mage

def mage(folder):
    red = ("#d45a4a", "#b8423a", "#8a2a26")
    d = common() + [grad("red", [red[2], red[0], red[1]]), grad("redv", [red[0], red[2]], True)]
    boots(folder)
    legs_file(folder, "#f1e4c8")
    embroidery = "".join(flower(x, 104, 1.6, "#d46a5a") for x in (8, 16, 24, 32, 40))
    write(folder, "torso", 52, 114, d, f'''
<path d="M13 44 Q10 70 4 106 Q26 112 48 106 Q42 70 39 44 Z" fill="url(#cream)" {SW}/>
<path d="M4.6 100 Q26 106 47.4 100 L48 106 Q26 112 4 106 Z" fill="#f6ecd8" {THIN}/>
{embroidery}
<path d="M18 52 Q16 78 12 102 M34 52 Q37 78 40 102" fill="none" stroke="{CREAM[2]}" stroke-width="0.9"/>
<path d="M12.6 20 Q14.6 12.6 25 12 Q37 12 40.6 19.6 Q44 30 40.6 45 L12 46 Q8.8 34 12.6 20 Z" fill="url(#cream)" {SW}/>
<path d="M25 18 L27 44 M31 18 L31 44" stroke="#d46a5a" stroke-width="0.9" stroke-dasharray="1.6 1.6"/>
{flower(28.6, 26, 1.8, "#d46a5a")}{flower(28.6, 36, 1.6, "#d46a5a")}
<path d="M10.4 43 L41.6 43 L41.8 47.6 L10.2 47.6 Z" fill="url(#leather)" {SW}/>
<path d="M36 45 L44 64 L40 66 L33 47 Z" fill="url(#leather)" {THIN}/>
<rect x="38" y="60" width="10" height="11" rx="2.4" fill="url(#leather)" {SW}/>
<path d="M38 63.4 L48 63.4" stroke="{LEATHER[2]}" stroke-width="0.9"/>
{flower(45, 60, 1.8, "#f6b8c4")}
<path d="M14 11.6 Q25 7 36 11.6 L37 18 Q25 15 13 18 Z" fill="url(#red)" {SW}/>
<circle cx="31" cy="16.4" r="2.2" fill="url(#gold)" {THIN}/>''')
    write(folder, "cape", 38, 104, d, f'''
<path d="M18 2 Q29 -0.4 31 6 L29.4 40 Q29 70 33 98 Q18 102 4 96 Q6 60 10 20 Q12 6 18 2 Z" fill="url(#red)" {SW}/>
<path d="M4 96 Q18 102 33 98 L32.6 94 Q18 98 4.4 92 Z" fill="url(#gold)" {THIN}/>
{"".join(flower(x, y, 1.4, "#f0a080", "#f6d77a") for x, y in ((18, 30), (24, 50), (14, 66), (22, 80)))}
<path d="M20 12 Q18.6 54 16 94 M26 12 Q25.4 56 26.4 96" fill="none" stroke="{red[2]}" stroke-width="1"/>''')
    write(folder, "arm_upper", 30, 30, d, f'''
<path d="M6.4 5 Q14 0 21.6 5 L22.4 26 Q14 29.6 6 26 Z" fill="url(#cream)" {SW}/>
<path d="M10 10 Q11 18 10 24 M18 10 Q17.4 18 18.4 24" fill="none" stroke="{CREAM[2]}" stroke-width="0.8"/>
<path d="M4.6 9 Q5.6 1 14.6 0.8 Q23.6 1 24.4 9 Q19 6.6 14.4 6.8 Q9.6 7 4.6 9 Z" fill="url(#red)" {SW}/>''')
    write(folder, "arm_lower", 20, 32, d, f'''<g transform="translate(9,1.6) scale(0.92,1) translate(-13,0)">
<path d="M8.4 1.4 L17.6 1.4 L22 20 Q23.6 23.6 20 24.4 L6 24.4 Q2.4 23.6 4 20 Z" fill="url(#cream)" {SW}/>
<path d="M4 21 Q13 19 22 21 L21.6 24 Q13 22.4 4.4 24 Z" fill="#d46a5a" {THIN}/></g>''')
    write(folder, "hand", 16, 16, d, f'''
<path d="M3 2.6 Q8 1 13 2.6 L13.6 11.6 Q8 14.4 2.6 11.6 Z" fill="url(#skin)" {SW}/>
<path d="M12.4 3.6 Q15.2 6.4 13.2 9.6" fill="none" stroke="{LINE}" stroke-width="0.8"/>''')
    hair_back = (f'<path d="M6 10 Q-2 26 1 44 Q-2 54 4 62 Q10 66 14 60 Q10 52 13 44 Q12 30 18 18 Z" fill="url(#hair)" {SW}/>'
                 f'<path d="M3 30 Q6 40 3 50 M7 26 Q10 38 8 52" fill="none" stroke="#c0903a" stroke-width="0.9"/>'
                 f'<path d="M36 18 Q46 24 44 40 Q48 50 42 58 Q38 52 40 44 Q40 32 34 24 Z" fill="url(#hair)" {SW}/>')
    bangs = ('<path d="M12 22 Q14 10 26 9 Q38 9 42 20 Q36 15 31 18 Q28 12 23 17 Q18 14 12 22 Z" fill="url(#hair)" stroke="#5a3a28" stroke-width="0.9"/>')
    hat = (f'<path d="M9 12 L41 10 Q38 -4 30 -14 Q22 -24 6 -26 Q14 -18 14 -8 Q12 2 9 12 Z" fill="url(#red)" {SW}/>'
           f'<path d="M6 -26 Q2 -24 3 -20 Q6 -22 8 -22 Z" fill="url(#red)" {THIN}/>'
           f'<path d="M12 4 Q16 -8 11 -18 M26 6 Q24 -4 18 -12" fill="none" stroke="{red[2]}" stroke-width="0.9"/>'
           f'<path d="M-4 15 Q22 6 50 12 Q50 16 44 17 Q22 11 -2 19 Q-6 18 -4 15 Z" fill="url(#red)" {SW}/>'
           f'<path d="M9.6 9.6 L40.4 8 L40.8 11.4 L10 13 Z" fill="url(#gold)" {THIN}/>'
           + flower(14, 9.4, 2.6, "#fbe7ee") + flower(20, 8.4, 2.2, "#f6b8c4") + flower(9, 10.6, 2, "#fff6d8")
           + leaf(24, 9, 3.2, -20, "#7a9a4a") + leaf(6, 11, 3, 200, "#7a9a4a"))
    heads(folder, d + [grad("hair", ["#fbe3a0", "#e8c070", "#c89a48"], True)], hair_back, bangs + hat, iris="#7a5a3a", brow="#c0903a", top=TOP + 6)
    gem = '''<radialGradient id="orb" cx="0.38" cy="0.35" r="0.65"><stop offset="0" stop-color="#f0fbff"/><stop offset="0.5" stop-color="#8fd0ff"/><stop offset="1" stop-color="#3a7ae0"/></radialGradient>'''
    base.write(folder, "weapon", 28, 110, d + [gem, grad("wood", ["#6a4424", "#b07a44", "#6a4424"])], f'''
<path d="M12.4 108 Q11.2 82 12.8 58 Q11.2 40 13 22 L15.8 22 Q16.8 40 15.6 58 Q16.8 82 15.8 108 Z" fill="url(#wood)" {SW}/>
<path d="M11.4 22 Q5.4 18 6.4 6 Q9.6 12 12.6 14 Z M16.6 22 Q22.6 18 21.6 6 Q18.4 12 15.4 14 Z" fill="url(#wood)" {THIN}/>
<path d="M14 2 L19 10 L14 19 L9 10 Z" fill="url(#orb)" {SW}/>
<path d="M14 2 L14 19 M9 10 L19 10" stroke="#ffffff" stroke-width="0.6" opacity="0.7"/>
{leaf(16, 24, 3.4, 30, "#7a9a4a")}{flower(11, 26, 1.8, "#f6b8c4")}
<rect x="11.6" y="84" width="4.8" height="9" rx="1.2" fill="url(#gold)" {THIN}/>''')
    base.write(folder, "shield", 40, 50, [], "")
    base.glow(folder, ("#f0fbff", "#9fd8ff", "#4a8aff"))


def build(root):
    for name, make in (("paladin", knight), ("rogue", rogue), ("wizard", mage)):
        folder = os.path.join(root, "art", "heroes", name)
        os.makedirs(folder, exist_ok=True)
        make(folder)
    enemies(root)


# ------------------------------------------------------------------ enemies
# Bodies come from generate_hero_art.enemy_parts drawn with these soft outlines; each gets
# a chibi storybook head. The rig reads these heads with margins [LEFT, TOP].

def skin_grad(colors):
    return grad("skin", [colors[2], colors[0], colors[1]])


def hood(color, pattern=None):
    back = (f'<path d="M1 44 Q-7 6 22 -6 Q44 -8 48.6 14 Q49.6 22 45.6 29 L42 20 Q36 10 26 10 Q16 10 12 20 L12.6 58 L-1 58 Q-2 50 1 44 Z" fill="{color}" {SW}/>')
    rim = (f'<path d="M45.6 29 Q49.6 16 41 5.6 Q30 -2 17 2.4 Q7.6 7.6 9 24 L12.6 22 Q14.4 11.6 26 10.2 Q37.4 10.4 42.4 21 Z" fill="{color}" {SW}/>')
    if pattern:
        rim += "".join(leaf(x, y, 2.2, a, pattern) for x, y, a in ((18, 4, -20), (30, 2, 10), (42, 9, 50)))
    return back, rim


def goblin_ears(skin_dark):
    back = (f'<path d="M12 20 Q-4 8 -10 -2 Q-4 16 10 30 Z" fill="url(#skin)" {SW}/>'
            f'<path d="M10 21 Q-2 11 -6 4 Q-1 16 9 26 Z" fill="{skin_dark}" opacity="0.5"/>')
    front = f'<path d="M40 16 Q50 6 54 0 Q50 14 42 22 Z" fill="url(#skin)" {SW}/>'
    return back, front


def skull(mood):
    lit = mood != "down"
    jaw = 3 if mood == "shout" else 0
    eyes = ""
    for x, r in ((24.4, 4.2), (36.2, 3.6)):
        eyes += f'<ellipse cx="{x}" cy="25" rx="{r}" ry="{r * 1.1}" fill="#3a2a38"/>'
        if lit:
            dim = 0.45 if mood == "blink" else 1.0
            eyes += f'<circle cx="{x + 0.4}" cy="25.4" r="{r * 0.45}" fill="#8fd8ff" opacity="{dim}"/><circle cx="{x + 0.4}" cy="25.4" r="{r * 0.9}" fill="#8fd8ff" opacity="{0.25 * dim}"/>'
    teeth = "".join(f'<rect x="{x}" y="{37 + jaw}" width="2.2" height="2.6" rx="0.6" fill="#fffaf0" {THIN}/>' for x in (28.4, 30.8, 33.2, 35.6))
    return (f'<path d="M8.6 24 Q8 8 25 7 Q41 7.6 42.4 22 Q43 30 38.6 34 L37 38 Q26 40 20 38.6 L14 36 Q9 31 8.6 24 Z" fill="url(#bone)" {SW}/>'
            + eyes +
            f'<path d="M40.4 30 L42 32.6 L39.4 32.6 Z" fill="#3a2a38"/>'
            f'<path d="M20 {38 + jaw} Q28 {35 + jaw} 38.6 {36 + jaw} L37.6 {41 + jaw} Q28 {43 + jaw} 21 {41.6 + jaw} Z" fill="url(#bone)" {SW}/>'
            + teeth +
            f'<path d="M14 16 Q17 20 15 24" fill="none" stroke="#c8b898" stroke-width="0.9"/>')


def enemy_heads(folder, kind):
    hair = lambda colors: grad("hair", colors, True)
    if kind in ("goblin_raider", "goblin_archer"):
        colors = ("#b8d88a", "#94bc68", "#6a9448")
        back, front = goblin_ears(colors[2])
        nose = f'<path d="M40 26 Q47 29 46 33 Q42 34 39.6 31 Z" fill="url(#skin)" {THIN}/>'
        cap = ""
        if kind == "goblin_archer":
            cap = (f'<path d="M8 20 Q8 4 25 3 Q40 3 43 16 Q32 12 22 14 Q13 15 8 20 Z" fill="url(#leather)" {SW}/>'
                   f'<path d="M24 3 Q27 -6 22 -10 Q31 -6 29 4 Z" fill="#d8503a" {THIN}/>')
        heads(folder, common(colors), back, front + cap, iris="#c89a2a", brow="#4a6a2a", ear=False, nose=nose, fang=True)
    elif kind == "hobgoblin_captain":
        colors = ("#f6b884", "#e2925a", "#b86a3a")
        helm = (f'<path d="M7 22 Q6 4 25 2.6 Q42 3 43.6 18 Q33 12 24 13 Q14 14 7 22 Z" fill="url(#steelv)" {SW}/>'
                f'<path d="M16 3 Q24 -12 38 -8 Q33 -2 34 4 Q26 1 16 3 Z" fill="#d8503a" {SW}/>'
                f'<path d="M7.6 18 Q24 11 43 15.6" fill="none" stroke="url(#gold)" stroke-width="1.8"/>')
        tusks = f'<path d="M29.4 38.4 L30.4 33.6 L31.6 38.4 Z M36.4 37.6 L37.4 32.8 L38.6 37.6 Z" fill="#fffaf0" {THIN}/>'
        heads(folder, common(colors), "", helm + tusks, iris="#b8502a", brow="#7a3a1a", ear=True)
    elif kind == "orc_berserker":
        colors = ("#a8c088", "#86a068", "#5e7848")
        mohawk = (f'<path d="M12 12 Q14 -8 32 -6 Q27 -1 34 1 Q25 2 27 7 Q19 5 17 12 Z" fill="#3a2a2a" {SW}/>')
        tusks = f'<path d="M28.6 39 L29.8 32.6 L31.4 39 Z M36.6 38.2 L37.8 31.8 L39.4 38.2 Z" fill="#fffaf0" {THIN}/>'
        heads(folder, common(colors), "", mohawk + tusks, iris="#a83a2a", brow="#3a2a1a", ear=True)
    elif kind == "skeleton_warrior":
        bone = grad("bone", ["#c8b898", "#fbf6e8", "#e0d4b8"])
        helm = (f'<path d="M-2 16 Q24 7 51 13 Q51 16.6 46 17 Q24 12 0 19.4 Q-4 18.6 -2 16 Z" fill="url(#rust)" {SW}/>'
                f'<path d="M8 14.6 Q9 -1 25 -1.6 Q40 -1 41.6 12.4 Q25 9 8 14.6 Z" fill="url(#rust)" {SW}/>')
        heads(folder, common() + [bone, grad("rust", ["#8a5a3a", "#d09a6a", "#7a4a2e"])], "", helm, draw=skull)
    elif kind == "cult_zealot":
        back, rim = hood("#c0443a", "#f6d77a")
        heads(folder, common(SKIN), back, rim, iris="#6a2a1a", brow="#5a2a1a", ear=False, mask="#3a2a30")
    elif kind == "cult_hexer":
        back, rim = hood("#6a5a8a", "#e8e0c8")
        heads(folder, common(("#e8f0e4", "#c8d4c4", "#98a896")), back, rim, ear=False, glow="#c88aff", mask="#f4ecd8", top=TOP + 6)
    elif kind == "ember_priest":
        back, rim = hood("#a8322a", "#f6d77a")
        horns = (f'<path d="M26 12 Q20 -2 28 -10 Q34 -14 38 -8 Q32 -8 30 -2 Q28 4 31 12 Z" fill="url(#gold)" {SW}/>'
                 f'<path d="M40 16 Q46 6 44 -2 Q49 3 48.6 11 Q46.6 17 42 20 Z" fill="url(#gold)" {SW}/>')
        heads(folder, common(("#f6d77a", "#d9a441", "#a8752a")), back, rim + horns, ear=False, glow="#ffb03a", mask="#d9a441")


def enemies(root):
    saved = (base.INK, base.SW, base.THIN)
    base.use_lines(LINE, 1.1, 0.7)
    for k in base.ENEMIES:
        folder = os.path.join(root, "art", "enemies", k["id"])
        base.enemy_parts(k, folder)
        enemy_heads(folder, k["id"])
    base.use_lines(saved[0], 1.5, 0.9)
