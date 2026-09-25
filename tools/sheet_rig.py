"""Cuts a painted parts sheet (tools/sheets/<name>.webp) into puppet parts.

Each part is cut out of the sheet's plain ground by colour distance (the rim un-mixed from
the ground, stray marks dropped, rips in the cloth left open), pasted into the pieces the
cut-out skeleton needs, and written as PNGs next to a rig.json that tells HeroPuppet where
each part pins on, how many pixels make a rig unit, and where the joints sit.

Lengths come from the sheet's assembled reference, so the parts keep the proportions the
artist drew there even when the parts themselves are drawn at other scales. What a sheet
needs is listed in the Notion Rogue guide, section 18 (docs/ART_BIBLE.md links it).
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "godot")


class Sheet:
    def __init__(self, path, background=None):
        self.rgb = np.asarray(Image.open(path).convert("RGB")).astype(float)
        if background is None:
            # The sheet's ground colour: the median of its top and bottom edges.
            edges = np.concatenate([self.rgb[:8].reshape(-1, 3), self.rgb[-8:].reshape(-1, 3)])
            background = np.median(edges, axis=0)
        self.ground = np.asarray(background, dtype=float)
        self.distance = np.sqrt(((self.rgb - self.ground) ** 2).sum(-1))

    def cut(self, box, ramp=(14, 26), erode=0, holes=0, bright=0):
        """The drawing inside box as RGBA, the ground removed and edges un-mixed. `ramp` is the
        colour distance over which the rim fades in; `erode` pulls the solid core in by that
        many pixels so a pale, ground-mixed rim fades out instead of haloing; `holes` opens
        pixels inside the drawing that are within that distance of the ground, and `bright`
        those paler than the ground by that much (paper showing between torn strands)."""
        x0, y0, x1, y1 = box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3
        far = self.distance[y0:y1, x0:x1]
        ink = nd.binary_closing(far > 40, iterations=2)
        labels, count = nd.label(ink)
        sizes = nd.sum(ink, labels, range(1, count + 1))
        # Keep the drawing itself, not neighbouring sprigs, sparkles or label strokes.
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= 0.15 * sizes.max()])
        solid = nd.binary_fill_holes(keep)
        support = nd.binary_dilation(solid, iterations=2)
        if erode:
            solid = nd.binary_erosion(solid, iterations=erode)
        alpha = np.where(solid, 1.0, np.where(support, np.clip((far - ramp[0]) / ramp[1], 0, 1), 0))
        if holes:
            # Rips painted as bare ground inside the drawing (a tattered cloak) stay open.
            alpha = np.where(solid & (far < holes), np.clip(far / holes, 0, 1) ** 2, alpha)
        if bright:
            patch = self.rgb[y0:y1, x0:x1]
            luma = patch @ np.array([0.299, 0.587, 0.114])
            ground = self.ground @ np.array([0.299, 0.587, 0.114])
            grey = patch.max(-1) - patch.min(-1) < 40
            paper = nd.binary_dilation((luma > ground + bright) & grey, iterations=1)
            alpha = np.where(paper, 0.0, alpha)
        alpha = nd.gaussian_filter(alpha, 0.5) * support
        rgb = self.rgb[y0:y1, x0:x1]
        a = np.maximum(alpha, 0.05)[..., None]
        rgb = np.clip((rgb - (1 - a) * self.ground) / a, 0, 255)
        rgb = np.where(alpha[..., None] > 0.97, self.rgb[y0:y1, x0:x1], rgb)
        return trim(Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA"))


def trim(image):
    box = image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return image.crop(box)


def fit(image, pivot, end, units):
    """Pixels per rig unit so pivot→end spans `units`; pivot/end are fractions of the image."""
    px = (pivot[0] * image.width, pivot[1] * image.height)
    tail = (end[0] * image.width, end[1] * image.height)
    length = np.hypot(tail[0] - px[0], tail[1] - px[1])
    return {"pivot": [round(px[0], 1), round(px[1], 1)], "density": round(length / units, 3)}


def scaled(image, factor):
    return image.resize((max(1, int(image.width * factor)), max(1, int(image.height * factor))), Image.LANCZOS)


def rogue_painterly(out=os.path.join(ROOT, "art", "heroes", "rogue")):
    """The Art Bible rogue (tools/sheets/rogue_painterly.webp): a front-view parts sheet with
    an assembled reference. Lengths are rig units of 0.175 reference pixels."""
    sheet = Sheet(os.path.join(HERE, "sheets", "rogue_painterly.webp"))
    os.makedirs(out, exist_ok=True)
    parts = {}
    rig = {"hip": 72, "parts": parts, "overlays": False, "far_arm_behind": True,
           "rest": [0.15, -0.35], "raise": [-1.2, -0.6], "joints": {
               "thigh_b": [-8, 0], "thigh_f": [8, 0], "shin": [0, 35], "head": [1, -63], "cape": [0, -56],
               "mantle": [0, -56], "upper_b": [-16, -49], "upper_f": [16, -49], "lower": [0, 17], "hand": [0, 19],
               "shield": [0, 7], "sword": [0, 7], "plume": [-7, -40]}}

    def cut(box, bright=12):
        return sheet.cut(box, (12, 80), 2, 20, bright)

    def save(name, image, spec):
        image.save(os.path.join(out, name + ".png"))
        parts[name] = spec

    # Head: the hood seen from the front, the face set into its opening.
    hood = cut((819, 17, 1005, 221))
    face = scaled(cut((385, 30, 514, 194)), 0.8)
    head = Image.new("RGBA", (hood.width, hood.height))
    head.alpha_composite(hood, (0, 0))
    head.alpha_composite(face, (43, 40))
    spec = {"pivot": [43 + face.width * 0.5, 40 + face.height * 0.9], "density": round(hood.width / 36, 3)}
    for name in ("head", "head_blink", "head_shout", "head_hurt", "head_down"):
        save(name, head, spec)
    # Torso: the outer shirt over the belted skirt and sash, a pouch on the near hip.
    tunic = cut((559, 257, 773, 470))
    pelvis = scaled(cut((337, 748, 484, 961)), 1.12)
    pouch = scaled(cut((1228, 329, 1304, 407)), 0.8)
    torso = Image.new("RGBA", (tunic.width, tunic.height + pelvis.height - 44))
    torso.alpha_composite(pelvis, ((tunic.width - pelvis.width) // 2, tunic.height - 44))
    torso.alpha_composite(tunic, (0, 0))
    torso.alpha_composite(pouch, (tunic.width - pouch.width - 30, tunic.height - 40))
    save("torso", torso, fit(torso, (0.5, 0.93), (0.5, 0.05), 63))
    # The torn capelet over both shoulders, drawn above the upper arms.
    left = cut((772, 268, 888, 400))
    right = cut((912, 269, 1016, 400))
    mantle = Image.new("RGBA", (left.width + right.width - 10, max(left.height, right.height)))
    mantle.alpha_composite(left, (0, 0))
    mantle.alpha_composite(right, (left.width - 10, 0))
    save("mantle", mantle, {"pivot": [left.width - 5, 14], "density": round(mantle.width / 36, 3)})
    # Cloak: the main back panel with its two tails, hanging behind.
    main = cut((1109, 715, 1300, 1019))
    tail_l = cut((1001, 756, 1107, 1004))
    tail_r = cut((1300, 745, 1412, 1003))
    cloak = Image.new("RGBA", (main.width + 80, main.height))
    cloak.alpha_composite(tail_l, (0, 30))
    cloak.alpha_composite(tail_r, (cloak.width - tail_r.width, 30))
    cloak.alpha_composite(main, (40, 0))
    save("cape", cloak, fit(cloak, (0.5, 0.16), (0.5, 1.0), 76))
    upper = cut((409, 531, 494, 672))
    save("arm_upper", upper, fit(upper, (0.5, 0.08), (0.5, 0.9), 18))
    lower = cut((661, 528, 740, 673))
    save("arm_lower", lower, fit(lower, (0.5, 0.06), (0.5, 0.94), 20))
    hand = cut((908, 549, 979, 678))
    save("hand", hand, fit(hand, (0.5, 0.1), (0.5, 0.75), 9))
    thigh = cut((487, 742, 563, 990))
    thigh = thigh.resize((int(thigh.width * 1.3), thigh.height), Image.LANCZOS)  # baggy, as in the reference
    save("thigh", thigh, fit(thigh, (0.5, 0.03), (0.5, 0.97), 42))
    boot = cut((806, 809, 897, 990))
    save("shin", boot, fit(boot, (0.42, 0.05), (0.42, 0.97), 37))
    dagger = cut((1211, 471, 1294, 706), bright=0).rotate(180)
    save("weapon", dagger, fit(dagger, (0.5, 0.82), (0.5, 0.0), 30))
    save("shield", dagger, fit(dagger, (0.5, 0.82), (0.5, 0.0), 24))
    with open(os.path.join(out, "rig.json"), "w") as handle:
        json.dump(rig, handle, indent=1)


if __name__ == "__main__":
    rogue_painterly()
    print("rogue sheet rig written")
