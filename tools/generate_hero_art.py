#!/usr/bin/env python3
"""Hero cut-out parts for the puppet rig (scripts/battle/HeroPuppet.gd).

Every hero is the same seventeen parts with the same pivots, so any set drops onto the
rig. Knights pick a steel finish, tabard and emblem, cape, helm, face, weapon and shield;
rogues wear leather and a hood with a dagger in each hand; wizards wear a robe and a
pointed hat and carry an orb staff.

    python tools/generate_hero_art.py

writes godot/art/knights|rogues|wizards/<id>/ for every example, the battle sets in
godot/art/heroes/<class>/ (DEFAULTS picks which example each class wears), and
godot/art/gallery.json for scenes/dev/HeroGallery.tscn.

Part pivots (drawing units; the rig scales them up). A canvas may be larger than listed as
long as its pivot stays put:
    thigh 22x36 (11,4)   shin 32x38 (11,4)   torso 52x72 (24,64)   cape 36x92 (24,4)
    head* 60x60 (26,56)  plume 30x24 (24,20) arm_upper 30x30 (14,7) arm_lower 18x30 (9,3)
    hand 16x16 (8,2)     weapon 28x110 (14,90) shield 40x50 (20,22)  glow 64x64 (32,32)
"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot")
INK = "#1a0f08"
SW = f'stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"'
THIN = f'stroke="{INK}" stroke-width="0.9" stroke-linejoin="round"'

# ---------------------------------------------------------------- palettes
STEELS = {
    "silver": ("#eef2f6", "#b9c2cd", "#6f7885", "#5a626e"),
    "blackened": ("#7d808a", "#4a4d57", "#2a2c33", "#1c1d22"),
    "gilded": ("#fff1c2", "#e2c07a", "#a67c2e", "#7a5716"),
    "bronze": ("#f3c79a", "#c08a55", "#855632", "#5e3a1f"),
    "moon": ("#f4f8ff", "#c3cfe6", "#7b88a6", "#5a6583"),
    "crimson": ("#ff9d8c", "#c2463a", "#7c231d", "#541410"),
    "verdigris": ("#c9ead8", "#7fb39a", "#4b7564", "#34564a"),
    "rusted": ("#c7a58a", "#8a6a55", "#5b4436", "#3e2e24"),
}
TRIMS = {
    "gold": ("#fbe39a", "#e0a93e", "#8e5c17"),
    "silver": ("#ffffff", "#c9d1dc", "#6f7885"),
    "brass": ("#f6d38a", "#b8893c", "#6e4e1a"),
    "red": ("#ff9c8a", "#c63c2c", "#6d1a12"),
    "bone": ("#f4ecd6", "#cbbd98", "#7d7056"),
}
SKINS = {
    "fair": ("#f3caa8", "#e9b893", "#b37752"),
    "tan": ("#e2ad84", "#c98d64", "#8e5a3a"),
    "brown": ("#b27a55", "#8f5c3d", "#5c3822"),
    "dark": ("#8a5a3c", "#6b432b", "#40271a"),
    "pale": ("#fbe6d6", "#efcdb6", "#c0927a"),
    "grave": ("#b9c7b4", "#98a893", "#5d6b5a"),
}

# ---------------------------------------------------------------- the examples
# name / note are shown in the gallery.
VARIANTS = [
    dict(id="aldric", name="알데릭", note="은빛 판금, 태양 문장, 열린 투구와 붉은 깃털",
         steel="silver", trim="gold", tabard=("#f6efdc", "#cbbd98"), emblem="sun", emblem_color="gold",
         cape=("#3556b0", "#1b2c66", "#7d1f1a"), helm="bascinet", plume="#d8412f",
         skin="tan", beard="full", beard_color="#6f4a2c", eyes="#2b4a7a",
         weapon="longsword", shield="kite", field=("#fbf5e6", "#3f63c2"), charge="cross", shield_emblem="sun"),
    dict(id="templar", name="성전 기사", note="흰 겉옷과 붉은 십자, 닫힌 대투구",
         steel="silver", trim="silver", tabard=("#fbf8ef", "#d8d0bb"), emblem="cross", emblem_color="#c3281e",
         cape=("#f2eee2", "#b9b19a", "#c3281e"), helm="greathelm", plume=None,
         skin="fair", beard="none", eyes="#3a2a1a",
         weapon="longsword", shield="heater", field=("#fbf8ef", "#fbf8ef"), charge="plain", shield_emblem="cross",
         shield_emblem_color="#c3281e"),
    dict(id="black_knight", name="흑기사", note="검게 그을린 강철, 핏빛 안감, 붉게 빛나는 눈구멍",
         steel="blackened", trim="red", tabard=("#5a1714", "#2e0b09"), emblem="none",
         cape=("#1d1b20", "#0b0a0d", "#8d1a14"), helm="greathelm", plume="#231f24", eye_glow="#ff4a2a",
         skin="pale", beard="none", eyes="#000000",
         weapon="greatsword", blade="dark", shield="none"),
    dict(id="golden_paladin", name="황금 성기사", note="금도금 갑옷, 날개 투구, 전투 망치",
         steel="gilded", trim="silver", tabard=("#ffffff", "#d9d4c6"), emblem="star", emblem_color="gold",
         cape=("#fdfbf4", "#cfc6ad", "#e0a93e"), helm="winged", plume=None,
         skin="fair", beard="none", eyes="#2d6b9a",
         weapon="warhammer", shield="round", field=("#fdfbf4", "#e0a93e"), charge="plain", shield_emblem="star"),
    dict(id="moon_knight", name="달빛 기사 (기본)", note="푸른 은빛 판금, 초승달 문장, 곡면 투구",
         steel="moon", trim="silver", tabard=("#233a78", "#12214d"), emblem="moon", emblem_color="#e8eefc",
         cape=("#c8d3ea", "#7b88a6", "#233a78"), helm="sallet", plume="#e8eefc",
         skin="pale", beard="moustache", beard_color="#c9ccd6", eyes="#5d7fb8",
         weapon="longsword", blade="bright", shield="kite", field=("#233a78", "#e8eefc"), charge="chief",
         shield_emblem="moon", shield_emblem_color="#e8eefc"),
    dict(id="crimson_knight", name="진홍 기사", note="붉게 칠한 판금, 뿔 투구, 전투 도끼",
         steel="crimson", trim="gold", tabard=("#1c1b1f", "#0c0b0e"), emblem="flame", emblem_color="#ff8a2a",
         cape=("#2a1a1a", "#120c0c", "#e0a93e"), helm="horned", plume=None,
         skin="brown", beard="full", beard_color="#2a1a12", eyes="#6b3a14",
         weapon="axe", shield="round", field=("#8c2a22", "#1c1b1f"), charge="pale", shield_emblem="flame"),
    dict(id="warden", name="숲의 파수꾼", note="녹슨 청동빛 갑옷, 나무 문장, 창",
         steel="verdigris", trim="brass", tabard=("#3f6a3a", "#223c20"), emblem="tree", emblem_color="#e9d98f",
         cape=("#4d6b2f", "#27381a", "#8a6a3a"), helm="sallet", plume="#6c9a4a",
         skin="dark", beard="none", eyes="#4a7a3a",
         weapon="spear", shield="kite", field=("#3f6a3a", "#e9d98f"), charge="chevron", shield_emblem="none"),
    dict(id="royal_guard", name="왕실 근위대", note="왕관 투구, 파란 망토, 탑 방패",
         steel="silver", trim="gold", tabard=("#2d4fa8", "#18306c"), emblem="tower", emblem_color="gold",
         cape=("#a8231a", "#5c120c", "#e0a93e"), helm="crowned", plume="#ffffff",
         skin="fair", beard="moustache", beard_color="#a5723a", eyes="#3a5a2a",
         weapon="longsword", shield="tower", field=("#2d4fa8", "#e0a93e"), charge="bars", shield_emblem="tower"),
    dict(id="veteran", name="늙은 용병", note="낡은 사슬과 판금, 회색 수염, 철퇴",
         steel="rusted", trim="brass", tabard=("#7a6446", "#4a3b27"), emblem="none",
         cape=("#5b4a36", "#342a1d", "#3a3a3a"), helm="bascinet", plume=None,
         skin="tan", beard="long", beard_color="#b9b3a8", eyes="#4a4a4a", scar=True,
         weapon="mace", shield="round", field=("#6b5a44", "#3a2e20"), charge="plain", shield_emblem="none"),
    dict(id="squire", name="견습 기사", note="투구 없이 금발, 짧은 검과 작은 방패",
         steel="silver", trim="brass", tabard=("#3a7a5a", "#1f4a34"), emblem="chevron", emblem_color="#f6efdc",
         cape=("#7a5a3a", "#4a3422", "#3a7a5a"), helm="none", hair="#e6c46a", plume=None,
         skin="fair", beard="none", eyes="#3a6ab8",
         weapon="shortsword", shield="round", field=("#3a7a5a", "#f6efdc"), charge="pale", shield_emblem="none"),
    dict(id="death_knight", name="망자의 기사", note="녹슨 판금 속 창백한 얼굴과 푸른 눈빛",
         steel="blackened", trim="bone", tabard=("#2a3a36", "#141d1b"), emblem="eye", emblem_color="#9fffcf",
         cape=("#26302e", "#101615", "#3d6b5e"), helm="horned", plume=None, eye_glow="#9fffcf",
         skin="grave", beard="none", eyes="#9fffcf",
         weapon="greatsword", blade="dark", shield="none"),
    dict(id="sun_priest", name="태양의 기사단장", note="금빛 판금과 흰 망토, 긴 흰 깃털, 철퇴",
         steel="gilded", trim="gold", tabard=("#b8321f", "#7a1c10"), emblem="sun", emblem_color="gold",
         cape=("#fbf5e6", "#cfc6ad", "#b8321f"), helm="crowned", plume="#fffaf0",
         skin="dark", beard="full", beard_color="#1e140e", eyes="#3a2414",
         weapon="mace", shield="heater", field=("#b8321f", "#e0a93e"), charge="cross", shield_emblem="sun"),
]


# ---------------------------------------------------------------- helpers
def gradients(k):
    s = STEELS[k["steel"]]
    t = TRIMS[k["trim"]]
    return {
        "steel": f'''<linearGradient id="steel" x1="0" y1="0" x2="1" y2="0.25">
<stop offset="0" stop-color="{s[2]}"/><stop offset="0.38" stop-color="{s[0]}"/>
<stop offset="0.62" stop-color="{s[1]}"/><stop offset="1" stop-color="{s[3]}"/></linearGradient>''',
        "steelv": f'''<linearGradient id="steelv" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{s[0]}"/><stop offset="0.5" stop-color="{s[1]}"/><stop offset="1" stop-color="{s[3]}"/></linearGradient>''',
        "gold": f'''<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{t[0]}"/><stop offset="0.55" stop-color="{t[1]}"/><stop offset="1" stop-color="{t[2]}"/></linearGradient>''',
        "mail": f'''<linearGradient id="mail" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{shade(s[2], 0.6)}"/><stop offset="0.5" stop-color="{shade(s[1], 0.75)}"/><stop offset="1" stop-color="{shade(s[3], 0.7)}"/></linearGradient>''',
        "cloth": f'''<linearGradient id="cloth" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{k["tabard"][1]}"/><stop offset="0.45" stop-color="{k["tabard"][0]}"/><stop offset="1" stop-color="{shade(k["tabard"][1], 0.92)}"/></linearGradient>''',
    }


def shade(color, factor):
    color = color.lstrip("#")
    rgb = [int(color[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join("%02x" % max(0, min(255, int(c * factor))) for c in rgb)


def write(folder, name, w, h, defs, body):
    os.makedirs(folder, exist_ok=True)
    text = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (w, h, w, h, "\n".join(defs), body.strip())
    with open(os.path.join(folder, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(text)


def rivet(x, y, r=0.9):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#gold)" stroke="{INK}" stroke-width="0.5"/>'


def mail_rows(x0, x1, y0, y1, step=2.6):
    out = []
    y = y0
    while y < y1:
        d = "M%.1f %.1f" % (x0, y)
        x = x0
        while x < x1:
            d += " q1.3 1.8 2.6 0"
            x += 2.6
        out.append(f'<path d="{d}" fill="none" stroke="#14161b" stroke-width="0.55" opacity="0.7"/>')
        y += step
    return "\n".join(out)


def paint(color):
    return "url(#gold)" if color == "gold" else color


def emblem(kind, cx, cy, r, color):
    """Small heraldic charges built from plain shapes."""
    fill = paint(color)
    if kind == "sun":
        rays = "".join(
            f'<path d="M{cx + r * 1.1 * math.cos(a):.2f} {cy + r * 1.1 * math.sin(a):.2f} L{cx + r * 1.9 * math.cos(a):.2f} {cy + r * 1.9 * math.sin(a):.2f}" stroke="{fill}" stroke-width="{r * 0.4:.2f}" stroke-linecap="round"/>'
            for a in [i * math.pi / 4 for i in range(8)])
        return rays + f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{INK}" stroke-width="0.7"/>'
    if kind == "cross":
        w = r * 0.55
        return (f'<path d="M{cx - w} {cy - r * 1.8} h{2 * w} v{r * 1.25} h{r * 1.25} v{2 * w} h{-r * 1.25} v{r * 2.1} h{-2 * w} '
                f'v{-r * 2.1} h{-r * 1.25} v{-2 * w} h{r * 1.25} Z" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>')
    if kind == "star":
        pts = []
        for i in range(10):
            rad = r * 1.7 if i % 2 == 0 else r * 0.7
            a = -math.pi / 2 + i * math.pi / 5
            pts.append(f"{cx + rad * math.cos(a):.2f},{cy + rad * math.sin(a):.2f}")
        return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>'
    if kind == "moon":
        return (f'<path d="M{cx + r * 0.4} {cy - r * 1.6} A{r * 1.6} {r * 1.6} 0 1 0 {cx + r * 0.4} {cy + r * 1.6} '
                f'A{r * 1.2} {r * 1.2} 0 1 1 {cx + r * 0.4} {cy - r * 1.6} Z" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>')
    if kind == "chevron":
        return (f'<path d="M{cx - r * 1.7} {cy + r * 0.9} L{cx} {cy - r * 1.0} L{cx + r * 1.7} {cy + r * 0.9} '
                f'L{cx + r * 1.7} {cy + r * 1.8} L{cx} {cy - r * 0.1} L{cx - r * 1.7} {cy + r * 1.8} Z" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>')
    if kind == "tower":
        x0, x1, top, base = cx - r * 1.1, cx + r * 1.1, cy - r * 1.5, cy + r * 1.6
        c = r * 0.44
        return (f'<path d="M{x0} {base} L{x0} {top} h{c} v{c} h{c} v{-c} h{c} v{c} h{c} v{-c} h{c} L{x1} {base} Z" '
                f'fill="{fill}" stroke="{INK}" stroke-width="0.6"/>'
                f'<path d="M{cx - r * 0.35} {base} v{-r * 0.9} q{r * 0.35} {-r * 0.5} {r * 0.7} 0 v{r * 0.9} Z" fill="{INK}"/>')
    if kind == "flame":
        return (f'<path d="M{cx} {cy - r * 1.9} Q{cx + r * 1.6} {cy - r * 0.2} {cx + r * 0.9} {cy + r * 1.3} '
                f'Q{cx} {cy + r * 1.9} {cx - r * 0.9} {cy + r * 1.3} Q{cx - r * 1.5} {cy} {cx - r * 0.2} {cy - r * 0.6} '
                f'Q{cx - r * 0.1} {cy - r * 1.2} {cx} {cy - r * 1.9} Z" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>'
                f'<path d="M{cx} {cy - r * 0.2} Q{cx + r * 0.7} {cy + r * 0.6} {cx} {cy + r * 1.3} Q{cx - r * 0.6} {cy + r * 0.6} {cx} {cy - r * 0.2} Z" fill="#fff3b0"/>')
    if kind == "tree":
        return (f'<rect x="{cx - r * 0.25}" y="{cy}" width="{r * 0.5}" height="{r * 1.7}" fill="{fill}"/>'
                f'<circle cx="{cx}" cy="{cy - r * 0.3}" r="{r * 1.2}" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>'
                f'<circle cx="{cx - r * 0.9}" cy="{cy + r * 0.4}" r="{r * 0.7}" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>'
                f'<circle cx="{cx + r * 0.9}" cy="{cy + r * 0.4}" r="{r * 0.7}" fill="{fill}" stroke="{INK}" stroke-width="0.6"/>')
    if kind == "eye":
        return (f'<path d="M{cx - r * 1.8} {cy} Q{cx} {cy - r * 1.5} {cx + r * 1.8} {cy} Q{cx} {cy + r * 1.5} {cx - r * 1.8} {cy} Z" '
                f'fill="{INK}" stroke="{fill}" stroke-width="0.8"/><circle cx="{cx}" cy="{cy}" r="{r * 0.6}" fill="{fill}"/>')
    return ""


# ---------------------------------------------------------------- parts
def legs(folder, k, g):
    write(folder, "thigh", 22, 36, [g["steel"], g["mail"], g["gold"]], f'''
<rect x="4.5" y="1" width="13" height="31" rx="5" fill="url(#mail)" {SW}/>
{mail_rows(5.5, 16.5, 4, 30)}
<path d="M4 3 Q11 -0.5 18.2 3 L17.4 23 Q11 27.5 4.8 23 Z" fill="url(#steel)" {SW}/>
<path d="M5.5 8 Q11 5.8 16.8 8" fill="none" stroke="url(#gold)" stroke-width="1.6"/>
<path d="M6 17 Q11 15.5 16.2 17" fill="none" stroke="#000000" stroke-opacity="0.35" stroke-width="0.8"/>
<path d="M7 5 L7.4 21" stroke="#ffffff" stroke-width="1" opacity="0.45"/>
{rivet(7.2, 11)}{rivet(14.8, 11)}''')
    write(folder, "shin", 32, 38, [g["steel"], g["steelv"], g["gold"]], f'''
<path d="M6.5 7 Q11 5 15.8 7 L15 27 L7.2 27 Z" fill="url(#steel)" {SW}/>
<path d="M8.4 9 L8.8 25" stroke="#ffffff" stroke-width="1" opacity="0.45"/>
<path d="M5 26.5 Q10 24.5 16.5 25.5 Q24 27 29 31 Q30.5 33.5 29.5 35.5 L5.5 36 Q3.8 31 5 26.5 Z" fill="url(#steelv)" {SW}/>
<path d="M15.5 26.2 Q17 30 16.5 35.8 M20.5 27.8 Q21.8 31 21.2 35.8 M25 29.6 Q26 32 25.6 35.7" fill="none" stroke="#000000" stroke-opacity="0.35" stroke-width="0.8"/>
<path d="M4.8 34.6 L29.8 34.6" stroke="{INK}" stroke-width="1.2"/>
<path d="M3.4 3.5 Q11 -2 18.6 3.5 Q16 8.5 11 9.2 Q6 8.5 3.4 3.5 Z" fill="url(#steelv)" {SW}/>
<circle cx="11" cy="4.6" r="2.6" fill="url(#gold)" stroke="{INK}" stroke-width="0.8"/>
<path d="M2.6 4 Q0.4 7.5 3 10.5 Q4.6 7.6 5.5 6.3 Z" fill="url(#steelv)" {THIN}/>''')


def torso(folder, k, g):
    mark = emblem(k["emblem"], 31, 31, 3.0, k.get("emblem_color", "gold")) if k["emblem"] != "none" else ""
    fold = shade(k["tabard"][1], 0.85)
    write(folder, "torso", 52, 72, [g["steel"], g["steelv"], g["gold"], g["mail"], g["cloth"]], f'''
<path d="M11 47 L39 47 L43 69 Q26 72.5 8 69 Z" fill="url(#mail)" {SW}/>
{mail_rows(10, 41, 49.5, 69)}
<path d="M12.5 21 Q14.5 13.5 24.5 12.5 Q37 12.5 41 20 Q44.5 31 41 45 L39 50 L12 50 Q8.5 36 12.5 21 Z" fill="url(#steel)" {SW}/>
<path d="M15.5 20 Q16.8 30 15.5 44" fill="none" stroke="#ffffff" stroke-width="1.4" opacity="0.45"/>
<path d="M22 18 Q31 16.5 39.5 21 Q42.5 33 39.8 50 L41.5 70.5 Q31 73 21 70.5 L22.5 50 Q20.5 33 22 18 Z" fill="url(#cloth)" {SW}/>
<path d="M23.5 20 Q31 18.6 38.4 22.3 M40.2 68.8 Q31 70.8 22.4 68.8" fill="none" stroke="url(#gold)" stroke-width="1.5"/>
<path d="M27 52 Q27.6 61 26.5 69.5 M34.5 52 Q35.4 61 35.8 69.8" fill="none" stroke="{fold}" stroke-width="0.9"/>
{mark}
<path d="M10.5 45.5 L41.5 45.5 L41.8 50.5 L10.2 50.5 Z" fill="#5a3a22" {THIN}/>
<rect x="28.5" y="44.6" width="6.4" height="6.8" rx="1" fill="url(#gold)" stroke="{INK}" stroke-width="0.8"/>
<rect x="30.3" y="46.4" width="2.8" height="3.2" fill="#5a3a22"/>
<path d="M15.5 11.5 Q25 8 35.5 11.5 L36.5 18.5 Q25 16 14.5 18.5 Z" fill="url(#steelv)" {SW}/>
<path d="M15.2 15.6 Q25 13 36 15.6" fill="none" stroke="url(#gold)" stroke-width="1.1"/>''')


def cape(folder, k, g):
    main, dark, lining = k["cape"]
    write(folder, "cape", 36, 92, [g["gold"], f'''<linearGradient id="cape" x1="1" y1="0" x2="0" y2="0.2">
<stop offset="0" stop-color="{dark}"/><stop offset="0.55" stop-color="{main}"/><stop offset="1" stop-color="{dark}"/></linearGradient>'''], f'''
<path d="M18 2 Q29 -0.4 31 6 L29 40 Q28 64 31.5 89 Q20 91.6 9.6 87.6 Q2 85.4 0.8 81 Q5.8 50 10 20 Q12 6 18 2 Z" fill="url(#cape)" {SW}/>
<path d="M0.8 81 Q5.8 50 10 20 Q9.8 50 5.4 83.8 Z" fill="{lining}"/>
<path d="M20 12 Q18 48 16 86 M25.5 12 Q25 50 25.2 88 M14 26 Q11 55 9.6 85" fill="none" stroke="{shade(dark, 0.8)}" stroke-width="1.2"/>
<path d="M22.5 14 Q21.5 48 20.5 86" fill="none" stroke="#ffffff" stroke-width="0.9" opacity="0.25"/>
<path d="M9.6 87.6 Q20 91.6 31.5 89" fill="none" stroke="url(#gold)" stroke-width="1.4"/>''')


def arms(folder, k, g):
    write(folder, "arm_upper", 30, 30, [g["steel"], g["steelv"], g["gold"]], f'''
<path d="M9.2 8 L19 8 L18.4 27 L9.8 27 Z" fill="url(#steel)" {SW}/>
<path d="M4.6 14.6 Q14 11.4 24 14.4 L23.4 18 Q14 15.4 5.4 18.2 Z" fill="url(#steelv)" {THIN}/>
<path d="M3.2 10.8 Q14 7 26.2 10.6 L25.6 15 Q14 11.8 4 15.2 Z" fill="url(#steelv)" {THIN}/>
<path d="M2.6 11.4 Q3.4 0.6 15 0.4 Q27 0.8 27.2 11 Q20.6 7.8 14.6 8.2 Q8.4 8.4 2.6 11.4 Z" fill="url(#steelv)" {SW}/>
<path d="M5 7.8 Q9 2.6 15.8 2.2" fill="none" stroke="#ffffff" stroke-width="1.3" opacity="0.6"/>
<path d="M3.6 10.2 Q14 6 26.2 9.6" fill="none" stroke="url(#gold)" stroke-width="1.3"/>
{rivet(8.6, 6.2)}{rivet(20.8, 6)}''')
    write(folder, "arm_lower", 18, 30, [g["steel"], g["steelv"], g["gold"]], f'''
<path d="M4.6 4 L13.4 4 L12.2 21 L5.8 21 Z" fill="url(#steel)" {SW}/>
<path d="M3.4 17.4 Q9 15.6 14.6 17.4 L15.4 24 Q9 25.4 2.6 24 Z" fill="url(#steelv)" {SW}/>
<path d="M3.2 18.6 Q9 16.8 14.8 18.6" fill="none" stroke="url(#gold)" stroke-width="1"/>
<circle cx="9" cy="3.6" r="4" fill="url(#steelv)" stroke="{INK}" stroke-width="1.2"/>
<circle cx="9" cy="3.6" r="1.6" fill="url(#gold)" stroke="{INK}" stroke-width="0.6"/>
<path d="M6.8 7 L7.2 16" stroke="#ffffff" stroke-width="0.9" opacity="0.45"/>''')
    write(folder, "hand", 16, 16, [g["steelv"]], f'''
<path d="M2.4 3 Q8 0.8 13.6 3 L14 12.6 Q8 15.6 2.2 12.6 Z" fill="url(#steelv)" {SW}/>
<path d="M3 6.4 L13.4 6.4 M3 9.4 L13.6 9.4" stroke="#000000" stroke-opacity="0.4" stroke-width="0.8"/>
<path d="M12.6 3.4 Q15.6 6.6 13.4 10.2" fill="none" stroke="{INK}" stroke-width="1"/>''')


# ---- head: drawn in the old 46x50 frame, shifted by (6,10) inside a 60x60 canvas
FACE_OPEN = {
    "idle": lambda eye: f'''<path d="M29.6 24.2 Q32.2 22.6 34.8 24.1 Q32.2 25.9 29.6 24.2 Z" fill="#f8f2e6" stroke="{INK}" stroke-width="0.6"/>
<circle cx="33" cy="24.1" r="1.05" fill="{eye}"/><circle cx="33.2" cy="24.1" r="0.5" fill="#0d0a08"/>''',
    "blink": lambda eye: f'<path d="M29.6 24.3 Q32.2 25.4 34.8 24.2" fill="none" stroke="{INK}" stroke-width="0.9"/>',
    "shout": lambda eye: f'''<path d="M29.6 24.2 Q32.2 22.6 34.8 24.1 Q32.2 25.9 29.6 24.2 Z" fill="#f8f2e6" stroke="{INK}" stroke-width="0.6"/>
<circle cx="33" cy="24.1" r="1.05" fill="{eye}"/><circle cx="33.2" cy="24.1" r="0.5" fill="#0d0a08"/>''',
    "hurt": lambda eye: f'<path d="M29.8 23 L33.8 24.4 L29.8 25.6" fill="none" stroke="{INK}" stroke-width="1"/>',
    "down": lambda eye: f'<path d="M29.6 24.6 Q32.2 23.4 34.8 24.6" fill="none" stroke="{INK}" stroke-width="0.9"/>',
}
BROWS = {
    "idle": "M28.6 21.6 Q32 19.8 36 20.9", "blink": "M28.6 21.6 Q32 19.8 36 20.9",
    "shout": "M28.4 20.4 Q32 21.4 36.2 23", "hurt": "M28.6 22.6 Q31.8 20 35.6 19.6",
    "down": "M28.8 21.8 Q32 21 35.8 21.8",
}
MOUTHS = {
    "shout": '<path d="M29 34 Q32.5 33.4 35.2 34.2 Q34.2 38.6 31 38.8 Q29 37 29 34 Z" fill="#3a1410" stroke="#1a0f08" stroke-width="0.7"/>'
             '<path d="M29.6 34.4 L34.6 34.5" stroke="#f3eadb" stroke-width="0.8"/>',
    "hurt": '<path d="M29.4 35.2 Q32 34 34.8 35.4" fill="none" stroke="#3a1410" stroke-width="1.1"/>',
}


def beard_art(style, color):
    light = shade(color, 1.45)
    if style == "full":
        return (f'<path d="M23.5 31.5 Q30 34.8 35.8 33.4 Q36.2 38.8 33.4 42.2 Q28.5 45.8 23.6 43.4 Q21 39 23.5 31.5 Z" fill="{color}" {SW}/>'
                f'<path d="M25 36 Q28.5 38.8 33 38.2 M24.6 40 Q28 42.6 32 41.8" fill="none" stroke="{light}" stroke-width="0.8"/>'
                f'<path d="M29.5 32.4 Q34 30.6 38 31.2 Q36 33.6 32 33.6 Z" fill="{light}" {THIN}/>')
    if style == "long":
        return (f'<path d="M23.5 31.5 Q30 34.8 35.8 33.4 Q37 42 33 48 Q28 50.5 24.5 47 Q20.8 40 23.5 31.5 Z" fill="{color}" {SW}/>'
                f'<path d="M26 37 Q29 42 28 48 M31 37 Q33 42 31.5 48" fill="none" stroke="{shade(color, 0.75)}" stroke-width="0.8"/>'
                f'<path d="M29.5 32.4 Q34 30.6 38 31.2 Q36 33.6 32 33.6 Z" fill="{shade(color, 1.1)}" {THIN}/>')
    if style == "moustache":
        return (f'<path d="M29 32.2 Q34 30.2 38.4 31.4 Q37.8 34 34.6 33.8 Q31.6 33.2 29 34.4 Z" fill="{color}" {THIN}/>'
                f'<path d="M24 36.5 Q28 39 31 38.6" fill="none" stroke="{shade(color, 0.7)}" stroke-width="0.7" opacity="0.6"/>')
    return f'<path d="M30.5 36 Q33 36.8 35 35.6" fill="none" stroke="#6b3a2a" stroke-width="0.8"/>'


def helm_art(kind, k):
    steel = f'fill="url(#steel)" {SW}'
    glint = '<path d="M9 12 Q14 6.2 22 5.4" fill="none" stroke="#ffffff" stroke-width="1.6" opacity="0.55"/>'
    open_shell = (f'<path d="M5.8 27 Q3.8 8.5 20 4 Q34.5 2 40.3 12.5 L38.8 18.8 Q30.5 15.2 23.6 17.2 Q21.4 25.5 23.8 33.8 L14.8 38.2 Q7.6 34.5 5.8 27 Z" {steel}/>'
                  + glint +
                  '<path d="M6.6 19.2 Q20 13.5 39.6 14.8" fill="none" stroke="url(#gold)" stroke-width="2.2"/>'
                  '<path d="M11 5.5 Q22 -0.6 34 5.2" fill="none" stroke="url(#gold)" stroke-width="1.6"/>'
                  '<path d="M23.6 17.2 Q21.4 25.5 23.8 33.8" fill="none" stroke="#000000" stroke-opacity="0.4" stroke-width="0.9"/>'
                  + rivet(10, 24) + rivet(16, 31) + rivet(19, 21))
    nasal = f'<path d="M37.5 13.8 L39.8 13.8 L39.6 24.4 L37.9 25.2 Z" fill="url(#steelv)" {THIN}/>'
    if kind in ("bascinet", "winged", "horned", "crowned"):
        art = open_shell + nasal
        if kind == "winged":
            art = (f'<path d="M10 10 Q-6 0 -4 -8 Q2 -2 6 -4 Q2 0 8 2 Q4 4 12 6 Z" fill="url(#steelv)" {SW}/>'
                   f'<path d="M-2 -5 Q4 1 9 6 M1 -1 Q6 3 10 8" fill="none" stroke="#000000" stroke-opacity="0.35" stroke-width="0.7"/>') + art + \
                  (f'<path d="M14 6 Q4 -6 8 -10 Q11 -4 15 -6 Q12 -2 17 0 Q14 2 18 4 Z" fill="url(#gold)" {SW}/>')
        if kind == "horned":
            art = art + (f'<path d="M8 10 Q-4 6 -5 -6 Q0 2 9 4 Z" fill="#efe6cf" {SW}/>'
                         f'<path d="M-3 -2 Q1 3 7 6" fill="none" stroke="#b8a888" stroke-width="0.8"/>'
                         f'<path d="M30 5 Q38 -3 36 -9 Q42 -2 34 8 Z" fill="#efe6cf" {SW}/>')
        if kind == "crowned":
            art = art + (f'<path d="M9 7 L11 -1 L15 4 L20 -3 L24 3 L29 -1 L31 6 Q20 2 9 7 Z" fill="url(#gold)" {SW}/>'
                         '<circle cx="20" cy="1.5" r="1.3" fill="#d23a3a" stroke="#1a0f08" stroke-width="0.5"/>')
        return art
    if kind == "greathelm":
        slit_glow = k.get("eye_glow")
        slit = (f'<path d="M24 22 L40.5 21 L40.5 23.4 L24 24.4 Z" fill="{INK}"/>'
                + (f'<ellipse cx="34" cy="22.6" rx="2.6" ry="1" fill="{slit_glow}"/>' if slit_glow else ""))
        return (f'<path d="M5.5 28 Q3.5 8 20 3.6 Q35.5 2 41.5 12 L42 36 Q34 41.5 22 41 L14.8 39 Q7.5 35 5.5 28 Z" {steel}/>'
                + glint +
                '<path d="M31 5 Q33 22 32.5 40" fill="none" stroke="url(#gold)" stroke-width="2"/>'
                + slit +
                '<path d="M24.5 29 L41.5 28.5 M24.5 32 L41.5 31.6" stroke="#000000" stroke-opacity="0.45" stroke-width="0.8"/>'
                + "".join(f'<circle cx="{36 + (i % 2) * 3}" cy="{34 + (i // 2) * 2.4}" r="0.6" fill="{INK}"/>' for i in range(4))
                + rivet(10, 24) + rivet(16, 32) + rivet(26, 36))
    if kind == "sallet":
        return (f'<path d="M3.5 30 Q2 9 20 4 Q35 2 42 13 L43.5 21 Q33 20 25 25.2 L20 36 L11 37.5 Q2 36 3.5 30 Z" {steel}/>'
                + glint +
                f'<path d="M24 16.5 L43.4 19.4 L42.6 23.4 L24.4 22 Z" fill="url(#steelv)" {THIN}/>'
                f'<path d="M24.6 19.6 L42.8 21.2" stroke="{INK}" stroke-width="1.2"/>'
                '<path d="M6 21 Q20 14 41 16" fill="none" stroke="url(#gold)" stroke-width="1.8"/>'
                + rivet(9, 25) + rivet(15, 31))
    return ""


def hair_art(color):
    dark = shade(color, 0.7)
    return (f'<path d="M6 27 Q3 7 20 3.5 Q35 2.5 39.5 14 Q34 11.5 28 14.5 Q24.5 20 24 33.5 L15 37.5 Q7 34 6 27 Z" fill="{color}" {SW}/>'
            f'<path d="M12 8 Q20 5 30 7 M9 16 Q15 11 24 11 M8 24 Q12 19 20 18" fill="none" stroke="{dark}" stroke-width="0.9"/>'
            '<path d="M18.5 22 Q16 25 18 29 Q20.5 29 21 26 Z" fill="url(#skin)" stroke="#1a0f08" stroke-width="0.8"/>')


def hood_art(color):
    dark, light = shade(color, 0.55), shade(color, 1.3)
    return (f'<path d="M3 34 Q-0.5 8 19 2.4 Q35.5 0.2 41.6 12.5 Q43.4 18.4 40.6 20.6 Q36 13.6 27 14.6 Q21.6 17.4 21.4 27.6 Q21.6 36.6 24.8 42.4 L27 50 L5 50 Q1.6 43 3 34 Z" fill="url(#hood)" {SW}/>'
            f'<path d="M40.4 20 Q36 14.4 27.2 15.4 Q22.6 18 22.4 27.6 Q22.6 36 25.4 41.8" fill="none" stroke="{dark}" stroke-width="2.4"/>'
            f'<path d="M9 9 Q16 4.4 26 4.2 M6 20 Q9 12 17 8.4 M8 38 Q10 30 14 26" fill="none" stroke="{dark}" stroke-width="0.9"/>'
            f'<path d="M13 6.4 Q20 3.6 28 4" fill="none" stroke="{light}" stroke-width="1.3" opacity="0.7"/>')


def hat_art(color, band):
    dark, light = shade(color, 0.55), shade(color, 1.35)
    return (f'<path d="M7.6 12.4 L35.4 11 Q33 -2 26 -12 Q17 -24 -2 -30 Q9 -18 9.6 -6 Q8.4 4 7.6 12.4 Z" fill="url(#hood)" {SW}/>'
            f'<path d="M-2 -30 Q-5 -27 -4 -24 Q0 -26 1.4 -27.4 Z" fill="url(#hood)" {THIN}/>'
            f'<path d="M13 9 Q15 -4 8 -16 M27 9.4 Q25 -2 17 -12" fill="none" stroke="{dark}" stroke-width="0.9"/>'
            f'<path d="M20 -14 Q24 -8 27 0" fill="none" stroke="{light}" stroke-width="1" opacity="0.5"/>'
            f'<path d="M9.2 10.6 L34 9.4 L34.6 12.6 L9.4 14 Z" fill="{paint(band)}" {THIN}/>'
            f'<path d="M21.8 9.4 l1.1 1.9 2.1 0.2 -1.6 1.4 0.5 2 -2.1 -1.1 -1.9 1.1 0.5 -2.1 -1.6 -1.4 2.1 -0.1 Z" fill="#fff4c4" stroke="{INK}" stroke-width="0.4"/>'
            f'<path d="M-2.6 15.6 Q20 8.6 47 13.4 Q46.6 16.6 41 17 Q20 13.6 -1 18.6 Q-4.6 17.6 -2.6 15.6 Z" fill="url(#hood)" {SW}/>'
            f'<path d="M1 15.6 Q20 10.6 44 13.8" fill="none" stroke="{light}" stroke-width="1" opacity="0.6"/>')


def long_hair_art(color):
    dark = shade(color, 0.72)
    return (f'<path d="M7 12 Q1 30 3.4 47 Q10.6 51 18 48.4 Q15 37 18.4 27 Q21.6 18.6 27 15.4 Z" fill="{color}" {SW}/>'
            f'<path d="M7 22 Q5 34 7.4 46 M11.4 20 Q10 34 12 47 M15.6 24 Q14.6 36 15.6 46" fill="none" stroke="{dark}" stroke-width="0.9"/>')


def mask_art(color):
    return (f'<path d="M22.8 30.6 Q31 29 40.4 30 L38.8 35.6 Q33 43 23.8 42.4 Q21.4 37 22.8 30.6 Z" fill="{color}" {SW}/>'
            f'<path d="M25 34 Q31 33.4 37.4 33.6 M25.4 38 Q30 38.4 34.6 37.6" fill="none" stroke="{shade(color, 0.65)}" stroke-width="0.8"/>')


def heads(folder, k, g, top=10):
    """Five expressions. `top` is the room above the face; the rig's head pivot is
    (26, 46 + top), so tall hats need a matching style entry in HeroPuppet."""
    skin = SKINS[k["skin"]]
    skin_grad = f'''<linearGradient id="skin" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{skin[2]}"/><stop offset="0.6" stop-color="{skin[0]}"/><stop offset="1" stop-color="{skin[1]}"/></linearGradient>'''
    helm = k["helm"]
    for mood in ["idle", "blink", "shout", "hurt", "down"]:
        eye = k.get("eyes", "#2b4a7a")
        if k.get("eye_glow") and helm != "greathelm":
            features = (f'<ellipse cx="32.6" cy="24.1" rx="2.3" ry="1.1" fill="{k["eye_glow"]}"/>'
                        f'<ellipse cx="32.6" cy="24.1" rx="3.8" ry="2" fill="{k["eye_glow"]}" opacity="0.3"/>') if mood not in ("blink", "down") else FACE_OPEN[mood](eye)
        else:
            features = FACE_OPEN[mood](eye)
        brow_color = shade(k.get("beard_color", k.get("hair", "#5a3a22")), 0.8)
        features += f'<path d="{BROWS[mood]}" fill="none" stroke="{brow_color}" stroke-width="1.3" stroke-linecap="round"/>'
        if k.get("scar"):
            features += '<path d="M31 18.6 L35 28.8" stroke="#8a3a2a" stroke-width="0.9"/>'
        face = ""
        if helm in ("none", "wizard_hat"):
            face += '<path d="M22 11 Q34 8.5 38 16 L38 22 Q30 17.5 22 18.5 Z" fill="url(#skin)" stroke="#1a0f08" stroke-width="1.5"/>'
        face += (f'<path d="M22 17 Q33 14.5 37 20.5 L38 25 L40.6 27.6 L37.6 29.6 Q37.8 34.5 34.8 38.2 Q28.5 42.5 22.5 40.5 Z" fill="url(#skin)" {SW}/>'
                 f'<path d="M37.8 25 L40.6 27.6 L37.6 29.4" fill="none" stroke="{skin[2]}" stroke-width="0.8"/>')
        face += beard_art(k.get("beard", "none"), k.get("beard_color", "#6f4a2c"))
        if mood in MOUTHS and not k.get("mask"):
            face += MOUTHS[mood]
        if k.get("mask"):
            face += mask_art(k["mask"])
        face += features
        if helm == "greathelm":
            glow = k.get("eye_glow")
            art = helm_art(helm, dict(k, eye_glow=None if mood in ("blink", "down") else glow))
            if mood == "shout" and glow:
                art += f'<ellipse cx="34" cy="22.6" rx="5" ry="2.2" fill="{glow}" opacity="0.45"/>'
            face = art
        elif helm == "none":
            face += hair_art(k["hair"])
        elif helm == "hood":
            face += hood_art(k["hood"])
        elif helm == "wizard_hat":
            face = long_hair_art(k["hair"]) + face + hat_art(k["hood"], k.get("band", "gold"))
        else:
            face += helm_art(helm, k)
        metal = helm not in ("none", "hood", "wizard_hat")
        collar = k.get("collar", "url(#mail)")
        aventail = "" if not metal else f'<path d="M7.5 29 Q6 43 13 48.5 L31 48.5 Q29 41 27 36 Z" fill="url(#mail)" {SW}/>' + mail_rows(9, 29, 34, 48)
        neck = f'<path d="M16 36 L28 36 L29 48.5 L14 48.5 Z" fill="url(#skin)" {SW}/><path d="M13 44 Q21 40 30 44 L31 48.5 L12 48.5 Z" fill="{collar}" {THIN}/>' if helm in ("none", "wizard_hat") else ""
        name = "head" if mood == "idle" else "head_" + mood
        hood = k.get("hood", "#444444")
        hood_grad = f'''<linearGradient id="hood" x1="0" y1="0" x2="1" y2="0.4">
<stop offset="0" stop-color="{shade(hood, 0.6)}"/><stop offset="0.5" stop-color="{hood}"/><stop offset="1" stop-color="{shade(hood, 0.75)}"/></linearGradient>'''
        write(folder, name, 60, 50 + top, [g["steel"], g["steelv"], g["gold"], g["mail"], skin_grad, hood_grad],
              f'<g transform="translate(6,{top})">{aventail}{neck}{face}</g>')
    plume = k.get("plume")
    if plume:
        write(folder, "plume", 30, 24, [f'''<linearGradient id="plume" x1="1" y1="1" x2="0" y2="0">
<stop offset="0" stop-color="{shade(plume, 0.6)}"/><stop offset="0.5" stop-color="{plume}"/><stop offset="1" stop-color="{shade(plume, 1.25)}"/></linearGradient>'''], f'''
<path d="M24.5 20.5 Q21.5 6.5 9 3.5 Q2.5 4.5 1 11 Q7.5 9.2 12 13.5 Q5 13.2 2.6 19.5 Q13 15.5 24.5 20.5 Z" fill="url(#plume)" {SW}/>
<path d="M22 18 Q18 9 9.5 6.4 M20 18.6 Q14 13.8 7 15" fill="none" stroke="{shade(plume, 0.5)}" stroke-width="0.8"/>''')
    else:
        write(folder, "plume", 30, 24, [], "")


# ---- weapons: 28x110, grip at (14,90), pointing up
BLADES = {
    "steel": ("#8d97a4", "#ffffff", "#c6ced8", "#7b8592"),
    "bright": ("#9fb2d6", "#ffffff", "#dfe8ff", "#8698c0"),
    "dark": ("#2a2c33", "#8a8f9c", "#4a4d57", "#1c1d22"),
}


def weapon(folder, k, g):
    b = BLADES[k.get("blade", "steel")]
    blade = f'''<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{b[0]}"/><stop offset="0.48" stop-color="{b[1]}"/><stop offset="0.52" stop-color="{b[2]}"/><stop offset="1" stop-color="{b[3]}"/></linearGradient>'''
    wood = '''<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#4a2e18"/><stop offset="0.5" stop-color="#8a5a32"/><stop offset="1" stop-color="#3a2412"/></linearGradient>'''
    grip = (f'<rect x="11.8" y="83.6" width="4.4" height="12.4" rx="1" fill="#5a3a22" {THIN}/>'
            '<path d="M11.8 86 L16.2 88 M11.8 89.4 L16.2 91.4 M11.8 92.8 L16.2 94.8" stroke="#2e1d10" stroke-width="0.8"/>'
            f'<circle cx="14" cy="98.6" r="3" fill="url(#gold)" stroke="{INK}" stroke-width="1.1"/>')
    guard = f'<path d="M6.8 80.4 Q14 78.8 21.2 80.4 L21.2 83.6 Q14 82.6 6.8 83.6 Z" fill="url(#gold)" {SW}/>'
    kind = k["weapon"]
    if kind in ("longsword", "shortsword", "greatsword"):
        tip, half = {"longsword": (29, 3.4), "shortsword": (52, 3.9), "greatsword": (6, 4.6)}[kind]
        body = (f'<path d="M14 {tip - 1} L{14 + half} {tip + 7} L{14 + half * 0.9} 81 L{14 - half * 0.9} 81 L{14 - half} {tip + 7} Z" fill="url(#blade)" {SW}/>'
                f'<path d="M14 {tip + 7} L14 78" stroke="#000000" stroke-opacity="0.3" stroke-width="0.9"/>')
        if kind == "greatsword":
            guard = f'<path d="M3 79.6 Q14 77.4 25 79.6 L25 83.6 Q14 82 3 83.6 Z" fill="url(#gold)" {SW}/>'
            grip = grip.replace('y="83.6" width="4.4" height="12.4"', 'y="83.6" width="4.4" height="14.4"').replace('cy="98.6"', 'cy="100.6"')
        return write(folder, "weapon", 28, 110, [blade, g["gold"]], body + guard + grip)
    haft = f'<rect x="12.2" y="{{top}}" width="3.6" height="{{length}}" rx="1.2" fill="url(#wood)" {THIN}/>'
    shaft_grip = (f'<rect x="11.6" y="84" width="4.8" height="10" rx="1" fill="#3a2414" {THIN}/>'
                  f'<circle cx="14" cy="97" r="2.4" fill="url(#steelv)" stroke="{INK}" stroke-width="0.9"/>')
    if kind == "mace":
        body = (haft.format(top=46, length=50) + shaft_grip +
                "".join(f'<path d="M14 36 L{14 + 8.5 * math.cos(a):.2f} {40 + 7 * math.sin(a):.2f} L14 50 Z" fill="url(#steelv)" {THIN}/>' for a in [math.pi * i / 3 for i in range(6)]) +
                f'<ellipse cx="14" cy="43" rx="5.4" ry="7.4" fill="url(#steel)" {SW}/>'
                f'<circle cx="14" cy="34.6" r="2" fill="url(#gold)" stroke="{INK}" stroke-width="0.7"/>'
                f'<rect x="10.5" y="50" width="7" height="2.6" fill="url(#gold)" {THIN}/>')
    elif kind == "warhammer":
        body = (haft.format(top=34, length=62) + shaft_grip +
                f'<path d="M5 34 L23 34 L23 46 L5 46 Z" fill="url(#steel)" {SW}/>'
                f'<path d="M23 36 L27 40 L23 44 Z" fill="url(#steelv)" {THIN}/>'
                f'<path d="M5 36 L1 40 L5 44 Z" fill="url(#steelv)" {THIN}/>'
                f'<path d="M14 34 L14 24 L16 34 Z" fill="url(#steelv)" {THIN}/>'
                f'<rect x="10" y="38" width="8" height="4" fill="url(#gold)" {THIN}/>')
    elif kind == "axe":
        body = (haft.format(top=28, length=68) + shaft_grip +
                f'<path d="M15 32 Q26 28 27 40 Q26 52 15 50 Q18 41 15 32 Z" fill="url(#blade)" {SW}/>'
                f'<path d="M24.6 33 Q26.2 40 24.6 49" fill="none" stroke="#ffffff" stroke-width="0.9" opacity="0.8"/>'
                f'<path d="M12 34 Q6 38 5 44 Q9 42 12 44 Z" fill="url(#steelv)" {THIN}/>'
                f'<circle cx="14" cy="29" r="2" fill="url(#gold)" stroke="{INK}" stroke-width="0.7"/>')
    elif kind == "spear":
        body = (haft.format(top=20, length=76) + shaft_grip +
                f'<path d="M14 1 Q19 10 17.4 20 L14 24 L10.6 20 Q9 10 14 1 Z" fill="url(#blade)" {SW}/>'
                '<path d="M14 4 L14 20" stroke="#000000" stroke-opacity="0.3" stroke-width="0.8"/>'
                f'<rect x="11.4" y="22" width="5.2" height="4" fill="url(#gold)" {THIN}/>'
                f'<path d="M11.4 27 Q8 30 9 34 L12.2 29 Z" fill="{k["cape"][0]}" {THIN}/>')
    write(folder, "weapon", 28, 110, [blade, wood, g["gold"], g["steel"], g["steelv"]], body)


# ---- shields: 40x50, grip at (20,22)
def shield(folder, k, g):
    kind = k["shield"]
    if kind == "none":
        return write(folder, "shield", 40, 50, [], "")
    face, field = k["field"]
    charge = k.get("charge", "plain")
    outline = {
        "kite": "M5 6 Q20 1.4 35 6 L34.2 24 Q30.4 38 20 47.2 Q9.6 38 5.8 24 Z",
        "heater": "M4 5 L36 5 L35.4 22 Q32.4 38 20 47.4 Q7.6 38 4.6 22 Z",
        "round": "M20 5 A17.5 17.5 0 1 1 19.99 5 Z",
        "tower": "M5 3 Q20 0.6 35 3 L35 44 Q20 48.6 5 44 Z",
    }[kind]
    inner = {
        "kite": "M7.6 8.2 Q20 4.6 32.4 8.2 L31.8 23.6 Q28.4 35.6 20 43.6 Q11.6 35.6 8.2 23.6 Z",
        "heater": "M6.6 7.6 L33.4 7.6 L33 21.6 Q30.4 35 20 43.6 Q9.6 35 7 21.6 Z",
        "round": "M20 7.6 A14.9 14.9 0 1 1 19.99 7.6 Z",
        "tower": "M7.6 5.6 Q20 3.6 32.4 5.6 L32.4 42 Q20 45.6 7.6 42 Z",
    }[kind]
    clip = f'<clipPath id="inner"><path d="{inner}"/></clipPath>'
    bands = {
        "cross": f'<rect x="17" y="0" width="6" height="50" fill="{field}"/><rect x="0" y="18.4" width="40" height="5.6" fill="{field}"/>',
        "chief": f'<rect x="0" y="0" width="40" height="17" fill="{field}"/>',
        "pale": f'<rect x="20" y="0" width="20" height="50" fill="{field}"/>',
        "chevron": f'<path d="M0 36 L20 16 L40 36 L40 44 L20 24 L0 44 Z" fill="{field}"/>',
        "bars": "".join(f'<rect x="0" y="{y}" width="40" height="3.4" fill="{field}"/>' for y in (12, 26, 36)),
        "plain": "",
    }[charge]
    light = f'''<linearGradient id="face" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="{shade(face, 1.12)}"/><stop offset="1" stop-color="{shade(face, 0.72)}"/></linearGradient>'''
    mark_kind = k.get("shield_emblem", "none")
    mark = emblem(mark_kind, 20, 22 if kind != "round" else 22.5, 4.2, k.get("shield_emblem_color", "gold")) if mark_kind != "none" else ""
    boss = (f'<circle cx="20" cy="22.5" r="4.6" fill="url(#steelv)" stroke="{INK}" stroke-width="1"/>'
            f'<circle cx="18.8" cy="21.3" r="1.4" fill="#ffffff" opacity="0.6"/>') if kind == "round" and mark_kind == "none" else ""
    rivets = "".join(rivet(x, y) for x, y in {
        "kite": [(9.6, 9), (30.4, 9), (20, 40)], "heater": [(8.6, 9), (31.4, 9), (20, 40)],
        "round": [(20, 9.4), (32.6, 22.5), (20, 35.6), (7.4, 22.5)], "tower": [(9.6, 8), (30.4, 8), (9.6, 40), (30.4, 40)],
    }[kind])
    write(folder, "shield", 40, 50, [g["gold"], g["steelv"], light, clip], f'''
<path d="{outline}" fill="url(#gold)" {SW}/>
<path d="{inner}" fill="url(#face)" {THIN}/>
<g clip-path="url(#inner)">{bands}</g>
{mark}{boss}
<path d="M10 11 Q13 9.4 16 9.2" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.6"/>
{rivets}''')


def glow(folder, colors=("#fffbe6", "#ffd970", "#ff9a2a")):
    write(folder, "glow", 64, 64, [f'''<radialGradient id="g" cx="0.5" cy="0.5" r="0.5">
<stop offset="0" stop-color="{colors[0]}" stop-opacity="1"/><stop offset="0.35" stop-color="{colors[1]}" stop-opacity="0.6"/>
<stop offset="1" stop-color="{colors[2]}" stop-opacity="0"/></radialGradient>'''],
          '<circle cx="32" cy="32" r="32" fill="url(#g)"/>')

# ================================================================ rogues
# Leather and cloth instead of plate; a dagger in each hand (the off-hand one in the
# shield slot, held reverse-grip). Same canvases and pivots as the knight.
ROGUES = [
    dict(id="shade", name="그림자 도적 (기본)", note="보랏빛 두건과 복면, 검은 가죽, 쌍단검",
         leather="#4a3526", trim="silver", steel="silver", cloth="#2c2833", hood="#4b3f6b", mask="#2c2833",
         skin="tan", beard="none", eyes="#6a4a8a", helm="hood", blade="steel"),
    dict(id="scarlet", name="붉은 두건", note="진홍 두건, 밝은 가죽, 맨얼굴의 미소",
         leather="#7a5236", trim="brass", steel="silver", cloth="#3a2e28", hood="#9c2a22",
         skin="fair", beard="none", eyes="#3a6a3a", helm="hood", blade="steel"),
    dict(id="desert", name="사막 자객", note="모래빛 천 두건과 복면, 굽은 단검",
         leather="#8a6a44", trim="gold", steel="silver", cloth="#c9ad7c", hood="#d8c08e", mask="#b8935e",
         skin="brown", beard="none", eyes="#2a1a0a", helm="hood", blade="bright"),
    dict(id="tracker", name="숲 추적자", note="초록 두건, 수염, 사냥용 단검",
         leather="#5e452c", trim="brass", steel="silver", cloth="#3a3a26", hood="#3f6a34",
         skin="tan", beard="moustache", beard_color="#6a4a2a", eyes="#4a3a1a", helm="hood", blade="steel"),
]


def rogue_gradients(k):
    g = gradients(dict(k, tabard=(k["cloth"], shade(k["cloth"], 0.7))))
    lth = k["leather"]
    g["leather"] = f'''<linearGradient id="leather" x1="0" y1="0" x2="1" y2="0.2">
<stop offset="0" stop-color="{shade(lth, 0.62)}"/><stop offset="0.45" stop-color="{shade(lth, 1.25)}"/><stop offset="1" stop-color="{shade(lth, 0.55)}"/></linearGradient>'''
    g["fabric"] = f'''<linearGradient id="fabric" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{shade(k["cloth"], 0.6)}"/><stop offset="0.5" stop-color="{shade(k["cloth"], 1.2)}"/><stop offset="1" stop-color="{shade(k["cloth"], 0.55)}"/></linearGradient>'''
    g["hoodc"] = f'''<linearGradient id="hoodc" x1="1" y1="0" x2="0" y2="0.2">
<stop offset="0" stop-color="{shade(k["hood"], 0.55)}"/><stop offset="0.55" stop-color="{k["hood"]}"/><stop offset="1" stop-color="{shade(k["hood"], 0.5)}"/></linearGradient>'''
    return g


def rogue_parts(k, folder):
    g = rogue_gradients(k)
    dark = shade(k["leather"], 0.45)
    write(folder, "thigh", 22, 36, [g["fabric"], g["leather"]], f'''
<path d="M4.4 1.6 Q11 -0.4 17.6 1.6 L16.6 31.4 Q11 33.4 5.4 31.4 Z" fill="url(#fabric)" {SW}/>
<path d="M8 6 Q9 16 8 28 M13.6 8 Q14.4 18 13.4 29" fill="none" stroke="#000000" stroke-opacity="0.3" stroke-width="0.8"/>
<path d="M4.6 11 L17.4 12.4 L17.2 15.6 L4.8 14.2 Z" fill="url(#leather)" {THIN}/>
<rect x="12.6" y="10.6" width="3" height="5.6" rx="0.8" fill="url(#gold)" stroke="{INK}" stroke-width="0.5"/>''')
    write(folder, "shin", 32, 38, [g["fabric"], g["leather"], g["gold"]], f'''
<path d="M6.4 4 Q11 2.6 15.8 4 L15.4 16 L6.8 16 Z" fill="url(#fabric)" {SW}/>
<path d="M5.8 13 Q11 11 16.6 13 L16 27 Q22.6 27.6 28.8 32.2 Q30.4 34.6 28.8 35.8 L5.8 36 Q4.4 31 5.8 26 Z" fill="url(#leather)" {SW}/>
<path d="M5 12 Q11 9.4 17.2 12 L16.8 16.4 Q11 14.2 5.4 16.4 Z" fill="{shade(k["leather"], 1.3)}" {THIN}/>
<path d="M6.4 21 L15.8 20 M6.6 25 L15.6 24.2" stroke="{dark}" stroke-width="1"/>
<path d="M5.6 34.6 L29 34.6" stroke="{INK}" stroke-width="1.2"/>
<path d="M18 30 Q22 30.6 26 33" fill="none" stroke="#ffffff" stroke-width="0.8" opacity="0.35"/>''')
    write(folder, "torso", 52, 72, [g["fabric"], g["leather"], g["gold"], g["steel"], g["blade"] if "blade" in g else ""], f'''
<path d="M13 46 L24 46 L22 70 Q14 70.6 9.6 68.6 Z" fill="url(#fabric)" {SW}/>
<path d="M26 46 L39.4 46 L42.6 68.4 Q34 70.8 27.4 70 Z" fill="url(#fabric)" {SW}/>
<path d="M12.5 21 Q14.5 13.5 24.5 12.5 Q37 12.5 41 20 Q44.5 31 41 45 L39.6 50 L12 50 Q8.5 36 12.5 21 Z" fill="url(#leather)" {SW}/>
<path d="M31 20 Q34 32 32.6 49" fill="none" stroke="{dark}" stroke-width="1"/>
{"".join(f'<path d="M30.6 {y} L33.8 {y + 1.8} M33.8 {y} L30.6 {y + 1.8}" stroke="#d8c8a0" stroke-width="0.6"/>' for y in (23, 28, 33, 38, 43))}
<path d="M15.5 20 Q16.8 30 15.5 44" fill="none" stroke="#ffffff" stroke-width="1.1" opacity="0.3"/>
<path d="M14 16 L40 42 L38.6 45 L12.6 19.4 Z" fill="{dark}" {THIN}/>
<rect x="21" y="24" width="4.6" height="5.4" rx="1" transform="rotate(45 23.3 26.7)" fill="url(#leather)" stroke="{INK}" stroke-width="0.6"/>
<rect x="28" y="31" width="4.6" height="5.4" rx="1" transform="rotate(45 30.3 33.7)" fill="url(#leather)" stroke="{INK}" stroke-width="0.6"/>
<path d="M10.5 45.5 L41.5 45.5 L41.8 50.5 L10.2 50.5 Z" fill="{dark}" {THIN}/>
<rect x="29" y="44.8" width="5.6" height="6.4" rx="1" fill="url(#gold)" stroke="{INK}" stroke-width="0.8"/>
<path d="M8.4 48 L6 62 L9.6 62.6 L11.6 48.6 Z" fill="{shade(k["leather"], 0.8)}" {THIN}/>
<rect x="14.6" y="49.6" width="7" height="7.6" rx="1.6" fill="url(#leather)" stroke="{INK}" stroke-width="0.8"/>
<path d="M14.6 52 L21.6 52" stroke="{dark}" stroke-width="0.8"/>
<path d="M17 11.6 Q25 9 34.4 11.8 L35.6 18 Q25 15.6 16 18 Z" fill="url(#fabric)" {SW}/>''')
    write(folder, "cape", 36, 92, [g["hoodc"]], f'''
<path d="M18 2 Q29 -0.4 31 6 L29.4 34 Q29 48 31 60 L25 57 L21 63 L16.6 57.6 L11 62.4 L8 56 L2.4 58.6 Q5.8 40 10 20 Q12 6 18 2 Z" fill="url(#hoodc)" {SW}/>
<path d="M20 12 Q18.6 36 17.4 56 M25.6 12 Q25 36 25.6 56 M14 26 Q11.6 42 9.6 55" fill="none" stroke="{shade(k["hood"], 0.45)}" stroke-width="1.1"/>''')
    write(folder, "arm_upper", 30, 30, [g["fabric"], g["leather"]], f'''
<path d="M9 7 L19.2 7 L18.4 27 L9.8 27 Z" fill="url(#fabric)" {SW}/>
<path d="M11.4 12 Q12.6 19 11.6 25" fill="none" stroke="#000000" stroke-opacity="0.3" stroke-width="0.8"/>
<path d="M5.6 11.6 Q6.4 3 14.8 2.6 Q23.2 3 23.6 11 Q18.6 8.8 14.4 9 Q9.6 9.2 5.6 11.6 Z" fill="url(#leather)" {SW}/>
<path d="M8.6 8.4 Q11 5 15.6 4.6" fill="none" stroke="#ffffff" stroke-width="1" opacity="0.35"/>''')
    write(folder, "arm_lower", 18, 30, [g["fabric"], g["leather"], g["gold"]], f'''
<path d="M5 2.4 L13 2.4 L12.4 10 L5.6 10 Z" fill="url(#fabric)" {SW}/>
<path d="M4.2 8.6 Q9 7.4 13.8 8.6 L13.2 22.4 Q9 23.4 4.8 22.4 Z" fill="url(#leather)" {SW}/>
<path d="M4.6 12.6 L13.4 12.6 M4.8 17.2 L13.2 17.2" stroke="{dark}" stroke-width="0.9"/>
{rivet(11.4, 12.6, 0.7)}{rivet(11.4, 17.2, 0.7)}''')
    write(folder, "hand", 16, 16, [g["leather"]], f'''
<path d="M2.6 2.6 Q8 0.8 13.4 2.6 L13.8 12.4 Q8 15.2 2.4 12.4 Z" fill="url(#leather)" {SW}/>
<path d="M3 6.6 L13.4 6.6 M3 9.6 L13.6 9.6" stroke="#000000" stroke-opacity="0.35" stroke-width="0.7"/>''')
    heads(folder, k, g)
    b = BLADES[k.get("blade", "steel")]
    blade = f'''<linearGradient id="blade" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{b[0]}"/><stop offset="0.48" stop-color="{b[1]}"/><stop offset="0.52" stop-color="{b[2]}"/><stop offset="1" stop-color="{b[3]}"/></linearGradient>'''
    curve = k["id"] == "desert"
    edge = "M14 52 Q20.6 62 17.4 81 L10.8 81 Q11.2 66 14 52 Z" if curve else "M14 55 L17.2 61 L16.8 81 L11.2 81 L10.8 61 Z"
    dagger = (f'<path d="{edge}" fill="url(#blade)" {SW}/>'
              '<path d="M14 60 L14 79" stroke="#000000" stroke-opacity="0.3" stroke-width="0.8"/>'
              f'<path d="M8.4 80.6 Q14 79 19.6 80.6 L19.2 83.6 Q14 82.6 8.8 83.6 Z" fill="url(#gold)" {SW}/>'
              f'<rect x="12" y="83.6" width="4" height="10.4" rx="1" fill="{dark}" {THIN}/>'
              '<path d="M12 86 L16 87.8 M12 89.2 L16 91" stroke="#000000" stroke-width="0.7"/>'
              f'<circle cx="14" cy="96" r="2.2" fill="url(#gold)" stroke="{INK}" stroke-width="0.8"/>')
    write(folder, "weapon", 28, 110, [blade, g["gold"]], dagger)
    # Off-hand dagger, reverse grip: blade down and forward from the fist.
    write(folder, "shield", 64, 64, [blade, g["gold"]], f'<g transform="rotate(-42 20 22)"><g transform="translate(6,-68) rotate(180 14 90)">{dagger}</g></g>')
    glow(folder, ("#fff6e8", "#ffd9a0", "#ff9a5a"))


# ================================================================ wizards
# A long robe over trousers and boots, wide sleeves, bare hands, a pointed hat and a
# staff whose orb carries the spell light.
WIZARDS = [
    dict(id="starlight", name="별빛 마법사 (기본)", note="남빛 로브와 별 무늬, 은발, 푸른 구슬 지팡이",
         robe="#2b3f8a", trim="gold", steel="silver", sash="#9c2a22", hood="#23336e", hair="#dfe3ef",
         skin="pale", beard="none", eyes="#4a7ad8", helm="wizard_hat", band="gold", orb=("#e8f4ff", "#8fc4ff", "#3a6aff")),
    dict(id="pyromancer", name="화염술사", note="진홍 로브, 불꽃 구슬, 검은 수염",
         robe="#8c2a1e", trim="gold", steel="silver", sash="#2a1a14", hood="#6a1c14", hair="#2a1a14",
         skin="tan", beard="full", beard_color="#2a1a14", eyes="#8a3a14", helm="wizard_hat", band="#2a1a14",
         orb=("#fff6d0", "#ffb04a", "#ff4a1a")),
    dict(id="necromancer", name="강령술사", note="검은 로브, 창백한 얼굴, 초록 해골빛",
         robe="#1e2226", trim="bone", steel="silver", sash="#3d6b5e", hood="#15181b", hair="#3a3d44",
         skin="grave", beard="none", eyes="#9fffcf", eye_glow="#9fffcf", helm="wizard_hat", band="#3d6b5e",
         orb=("#eafff4", "#8fffc6", "#1a8a5a")),
    dict(id="archmage", name="대마법사", note="흰 로브와 금실, 긴 흰 수염, 수정 지팡이",
         robe="#ece6d6", trim="gold", steel="silver", sash="#2b3f8a", hood="#d8d0bc", hair="#f4f2ec",
         skin="fair", beard="long", beard_color="#f1eee6", eyes="#4a5a8a", helm="wizard_hat", band="#2b3f8a",
         orb=("#ffffff", "#e0d4ff", "#9a7aff")),
]


def wizard_parts(k, folder):
    g = gradients(dict(k, tabard=(k["robe"], shade(k["robe"], 0.7))))
    robe = k["robe"]
    g["robe"] = f'''<linearGradient id="robe" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{shade(robe, 0.6)}"/><stop offset="0.45" stop-color="{shade(robe, 1.2)}"/><stop offset="1" stop-color="{shade(robe, 0.62)}"/></linearGradient>'''
    g["boot"] = '''<linearGradient id="boot" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#6a4a30"/><stop offset="1" stop-color="#2e1e12"/></linearGradient>'''
    skin = SKINS[k["skin"]]
    g["skin"] = f'''<linearGradient id="skin" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{skin[2]}"/><stop offset="0.6" stop-color="{skin[0]}"/><stop offset="1" stop-color="{skin[1]}"/></linearGradient>'''
    fold = shade(robe, 0.5)
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="0.7" fill="#fff4c4" opacity="0.8"/>' for x, y in ((14, 60), (20, 78), (34, 66), (28, 92), (12, 96), (40, 88), (24, 58)))
    write(folder, "thigh", 22, 36, [g["robe"]], f'''
<path d="M5 2 Q11 0 17 2 L16.4 31 Q11 32.6 5.6 31 Z" fill="{shade(robe, 0.45)}" {SW}/>''')
    write(folder, "shin", 32, 38, [g["boot"]], f'''
<path d="M6.4 4 Q11 2.6 15.8 4 L15.6 20 L6.6 20 Z" fill="{shade(robe, 0.45)}" {SW}/>
<path d="M6 17 Q11 15 16.4 17 L16 27 Q23 26.4 29.6 29.6 Q31.6 31.4 29 33 Q30.4 34.8 28.4 35.8 L5.8 36 Q4.4 31 6 26 Z" fill="url(#boot)" {SW}/>
<path d="M6 19.6 Q11 18 16.2 19.6" fill="none" stroke="#a07a50" stroke-width="0.9"/>''')
    write(folder, "torso", 52, 114, [g["robe"], g["gold"]], f'''
<path d="M12 46 Q10 70 2.6 108 Q24 114 49 108 Q42 72 40 46 Z" fill="url(#robe)" {SW}/>
<path d="M28 50 Q31 80 33.4 110" fill="none" stroke="url(#gold)" stroke-width="2"/>
<path d="M18 54 Q15 80 10.6 106 M36 54 Q39 80 42.6 106 M24 60 Q22.6 84 21 110" fill="none" stroke="{fold}" stroke-width="1"/>
{stars}
<path d="M3 104.6 Q24 110.6 48.6 104.6 L49 108 Q24 114 2.6 108 Z" fill="url(#gold)" {THIN}/>
<path d="M12.5 21 Q14.5 13.5 24.5 12.5 Q37 12.5 41 20 Q44.5 31 41 45 L40 50 L12 50 Q8.5 36 12.5 21 Z" fill="url(#robe)" {SW}/>
<path d="M22 14 Q30 24 29 50" fill="none" stroke="url(#gold)" stroke-width="1.8"/>
<path d="M15.5 20 Q16.8 30 15.5 44" fill="none" stroke="#ffffff" stroke-width="1.1" opacity="0.25"/>
<path d="M10.5 44.4 L41.5 44.4 L41.8 50.2 L10.2 50.2 Z" fill="{k["sash"]}" {THIN}/>
<path d="M36 49 Q38 60 36.4 70 L33.4 69.4 Q34.6 60 33 50 Z" fill="{k["sash"]}" {THIN}/>
<circle cx="33.6" cy="31" r="2.6" fill="url(#gold)" stroke="{INK}" stroke-width="0.7"/>
<path d="M33.6 24 L33.6 28.4" stroke="url(#gold)" stroke-width="0.8"/>
<rect x="14" y="48" width="6.6" height="8" rx="1.2" fill="#6a4a30" stroke="{INK}" stroke-width="0.8"/>
<path d="M15.6 11.4 Q25 8 35.4 11.4 L36.4 18 Q25 15.4 14.6 18 Z" fill="url(#robe)" {SW}/>
<path d="M15.2 15.4 Q25 12.6 36 15.4" fill="none" stroke="url(#gold)" stroke-width="1.1"/>''')
    write(folder, "cape", 36, 104, [g["robe"], g["gold"]], f'''
<path d="M18 2 Q29 -0.4 31 6 L29 40 Q28.6 70 32 100 Q18 103 4 98 Q6 60 10 20 Q12 6 18 2 Z" fill="url(#robe)" {SW}/>
<path d="M20 12 Q18.6 54 16 98 M25.6 12 Q25 56 26 100 M13.4 28 Q10.6 62 9 97" fill="none" stroke="{fold}" stroke-width="1.1"/>
<path d="M4 98 Q18 103 32 100" fill="none" stroke="url(#gold)" stroke-width="1.4"/>''')
    write(folder, "arm_upper", 30, 30, [g["robe"], g["gold"]], f'''
<path d="M7.6 4 Q14 0.6 20.6 4 L21.6 27.6 L6.6 27.6 Z" fill="url(#robe)" {SW}/>
<path d="M11 9 Q10.4 18 10.6 26 M16.6 9 Q17.6 18 17.2 26" fill="none" stroke="{fold}" stroke-width="0.9"/>''')
    # Bell sleeve: wider than the 18-unit forearm canvas, so the canvas grows but the elbow
    # pivot stays at (9,3).
    write(folder, "arm_lower", 20, 32, [g["robe"], g["gold"]], f'''<g transform="translate(9,1.6) scale(0.92,1) translate(-13,0)">
<path d="M8.4 1.4 L17.6 1.4 L22.4 20 Q24 23.6 20 24.6 L6 24.6 Q2 23.6 3.6 20 Z" fill="url(#robe)" {SW}/>
<path d="M4 21.6 Q13 19.6 22 21.6 L21.6 24.4 Q13 22.8 4.4 24.4 Z" fill="url(#gold)" {THIN}/>
<path d="M10.6 5 Q9 13 7.4 20 M15.4 5 Q17 13 18.6 20" fill="none" stroke="{fold}" stroke-width="0.9"/></g>''')
    write(folder, "hand", 16, 16, [g["skin"]], f'''
<path d="M3 2.6 Q8 1 13 2.6 L13.6 11.6 Q8 14.4 2.6 11.6 Z" fill="url(#skin)" {SW}/>
<path d="M3.4 7 L13.2 7 M3.6 9.6 L13.4 9.6" stroke="#000000" stroke-opacity="0.25" stroke-width="0.7"/>
<path d="M12.4 3.6 Q15.2 6.4 13.2 9.6" fill="none" stroke="{INK}" stroke-width="0.9"/>''')
    heads(folder, dict(k, collar=shade(robe, 0.8)), g, top=34)
    orb = k["orb"]
    write(folder, "weapon", 28, 110, [g["gold"], f'''<radialGradient id="orb" cx="0.38" cy="0.35" r="0.65">
<stop offset="0" stop-color="{orb[0]}"/><stop offset="0.5" stop-color="{orb[1]}"/><stop offset="1" stop-color="{orb[2]}"/></radialGradient>''', '''<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#3a2412"/><stop offset="0.5" stop-color="#8a5a32"/><stop offset="1" stop-color="#2e1c0e"/></linearGradient>'''], f'''
<path d="M12.4 108 Q11.4 80 12.6 56 Q11 40 12.8 22 L15.6 22 Q16.6 40 15.6 56 Q16.6 80 15.8 108 Z" fill="url(#wood)" {SW}/>
<path d="M13 40 Q15 44 13.6 48 M14.6 70 Q12.6 74 14.2 78" fill="none" stroke="#2a180a" stroke-width="0.8"/>
<path d="M11.6 22 Q6.4 16 8.4 6 Q10.6 12 12.8 14 Z M16.4 22 Q21.6 16 19.6 6 Q17.4 12 15.2 14 Z" fill="url(#wood)" {THIN}/>
<circle cx="14" cy="10" r="6" fill="url(#orb)" stroke="{INK}" stroke-width="1.2"/>
<circle cx="12" cy="8" r="1.6" fill="#ffffff" opacity="0.8"/>
<rect x="11.6" y="84" width="4.8" height="9" rx="1" fill="url(#gold)" {THIN}/>''')
    write(folder, "shield", 40, 50, [], "")
    glow(folder, orb)


def build(k, folder):
    os.makedirs(folder, exist_ok=True)
    g = gradients(k)
    legs(folder, k, g)
    torso(folder, k, g)
    cape(folder, k, g)
    arms(folder, k, g)
    heads(folder, k, g)
    weapon(folder, k, g)
    shield(folder, k, g)
    glow(folder)


## Which example each class wears in battle.
DEFAULTS = {"paladin": "moon_knight", "rogue": "shade", "wizard": "starlight"}
GROUPS = [
    ("knights", "기사", "knight", VARIANTS, build),
    ("rogues", "도적", "rogue", ROGUES, rogue_parts),
    ("wizards", "마법사", "wizard", WIZARDS, wizard_parts),
]


def main():
    gallery = []
    for folder, title, style, variants, make in GROUPS:
        entries = []
        for k in variants:
            make(k, os.path.join(ROOT, "art", folder, k["id"]))
            entries.append({"id": k["id"], "name": k["name"], "note": k["note"], "path": "res://art/%s/%s/" % (folder, k["id"])})
        gallery.append({"title": title, "style": style, "entries": entries})
    for hero, pick in DEFAULTS.items():
        for folder, _title, _style, variants, make in GROUPS:
            for k in variants:
                if k["id"] == pick:
                    make(k, os.path.join(ROOT, "art", "heroes", hero))
    with open(os.path.join(ROOT, "art", "gallery.json"), "w", encoding="utf-8") as f:
        json.dump(gallery, f, ensure_ascii=False, indent=1)
    print(", ".join("%d %s" % (len(v), t) for _f, t, _s, v, _m in GROUPS))


if __name__ == "__main__":
    main()
