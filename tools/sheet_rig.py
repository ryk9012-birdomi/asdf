"""Cuts a painted character sheet (tools/sheets/<name>.webp) into puppet parts.

The sheet's "Rig Parts" row is cut out of the parchment by colour distance, cleaned of
stray sprigs, pasted into the pieces the cut-out skeleton needs, and written as PNGs next
to a rig.json that tells HeroPuppet where each part pins on (see HeroPuppet.sheet()).

Lengths are in rig units: half a pixel of the sheet's front turnaround view, so the parts
keep the proportions the artist drew there even though the parts row mixes scales.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "godot")
PARCHMENT = np.array([250, 234, 203.0])


class Sheet:
    def __init__(self, path):
        self.rgb = np.asarray(Image.open(path).convert("RGB")).astype(float)
        self.distance = np.sqrt(((self.rgb - PARCHMENT) ** 2).sum(-1))

    def cut(self, box):
        """The drawing inside box as RGBA, parchment removed and edges un-mixed."""
        x0, y0, x1, y1 = box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3
        far = self.distance[y0:y1, x0:x1]
        ink = nd.binary_closing(far > 40, iterations=2)
        labels, count = nd.label(ink)
        sizes = nd.sum(ink, labels, range(1, count + 1))
        # Keep the drawing itself, not neighbouring sprigs, sparkles or label strokes.
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= 0.15 * sizes.max()])
        solid = nd.binary_fill_holes(keep)
        support = nd.binary_dilation(solid, iterations=2)
        alpha = np.where(solid, 1.0, np.where(support, np.clip((far - 14) / 26, 0, 1), 0))
        alpha = nd.gaussian_filter(alpha, 0.5) * support
        rgb = self.rgb[y0:y1, x0:x1]
        a = np.maximum(alpha, 0.05)[..., None]
        rgb = np.clip((rgb - (1 - a) * PARCHMENT) / a, 0, 255)
        rgb = np.where(alpha[..., None] > 0.97, self.rgb[y0:y1, x0:x1], rgb)
        return trim(Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA"))


def trim(image):
    box = image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return image.crop(box)


def upright(image, shoulder_light=True):
    """Turns a limb drawn at a slant so it hangs straight down, lighter (sleeve) end up."""
    alpha = np.asarray(image.getchannel("A")) > 128
    ys, xs = np.nonzero(alpha)
    points = np.stack([xs - xs.mean(), ys - ys.mean()])
    values, vectors = np.linalg.eigh(np.cov(points))
    axis = vectors[:, np.argmax(values)]
    angle = np.degrees(np.arctan2(axis[0], axis[1]))
    turned = trim(image.rotate(-angle, resample=Image.BICUBIC, expand=True))
    rgb = np.asarray(turned).astype(float)
    half = turned.height // 2
    brightness = [rgb[s][..., :3][rgb[s][..., 3] > 128].mean() for s in (np.s_[:half], np.s_[half:])]
    if (brightness[0] < brightness[1]) == shoulder_light:
        turned = turned.rotate(180)
    return turned


def fit(image, pivot, end, units):
    """Pixels per rig unit so pivot→end spans `units`; pivot/end are fractions of the image."""
    px = (pivot[0] * image.width, pivot[1] * image.height)
    tail = (end[0] * image.width, end[1] * image.height)
    length = np.hypot(tail[0] - px[0], tail[1] - px[1])
    return {"pivot": [round(px[0], 1), round(px[1], 1)], "density": round(length / units, 3)}


def rogue(out=os.path.join(ROOT, "art", "sheets", "rogue")):
    """The example sheet (tools/sheets/rogue.webp). It predates the Art Bible, so its output
    is not used by the game; point RIGS at the folder once a Bible-style sheet replaces it."""
    sheet = Sheet(os.path.join(HERE, "sheets", "rogue.webp"))
    os.makedirs(out, exist_ok=True)
    parts = {}
    rig = {"hip": 55, "parts": parts, "overlays": False, "far_arm_behind": True, "rest": [0.2, -0.3], "raise": [-1.2, -0.6], "joints": {
        "thigh_b": [-7, 0], "thigh_f": [6, 0], "shin": [0, 26], "head": [0, -45], "cape": [0, -40],
        "upper_b": [-17, -31], "upper_f": [17, -31], "lower": [0, 18], "hand": [0, 14],
        "shield": [0, 7], "sword": [0, 8], "plume": [-7, -40]}}

    def save(name, image, spec):
        image.save(os.path.join(out, name + ".png"))
        parts[name] = spec

    # Expressions: the hooded heads, padded onto one canvas so they share a pivot on the
    # neck under the chin. The sheet has no blink or knocked-out face; those reuse others.
    faces = {"head": (1060, 63, 1238, 209), "head_shout": (1248, 63, 1420, 208),
             "head_hurt": (1046, 236, 1227, 389)}
    cuts = {name: sheet.cut(box) for name, box in faces.items()}
    width = max(image.width for image in cuts.values()) + 8
    height = max(image.height for image in cuts.values()) + 8
    pivot = [width * 0.5, height * 0.84]
    density = round(cuts["head"].width / 72, 3)
    for name, image in cuts.items():
        canvas = Image.new("RGBA", (width, height))
        canvas.alpha_composite(image, ((width - image.width) // 2, height - 4 - image.height))
        cuts[name] = canvas
    cuts["head_blink"] = cuts["head"]
    cuts["head_down"] = cuts["head_hurt"]
    for name, image in cuts.items():
        save(name, image, {"pivot": pivot, "density": density})
    torso = sheet.cut((857, 442, 971, 565))
    save("torso", torso, fit(torso, (0.5, 0.86), (0.5, 0.04), 45))
    cloak = sheet.cut((1260, 437, 1426, 576))
    quiver = sheet.cut((1208, 620, 1284, 802)).rotate(28, resample=Image.BICUBIC, expand=True)
    quiver = trim(quiver.resize((int(quiver.width * 0.42), int(quiver.height * 0.42)), Image.LANCZOS))
    # The quiver rides on the back of the cloak, over the left shoulder.
    back = Image.new("RGBA", (cloak.width + 10, cloak.height + 24))
    back.alpha_composite(cloak, (10, 24))
    back.alpha_composite(quiver, (18, 0))
    save("cape", back, fit(back, (0.53, 0.3), (0.53, 1.0), 62))
    upper = upright(sheet.cut((440, 595, 508, 674)))
    upper = upper.crop((0, 0, upper.width, int(upper.height * 0.58)))
    save("arm_upper", upper, fit(upper, (0.5, 0.14), (0.5, 0.92), 19))
    lower = sheet.cut((626, 598, 668, 674))
    save("arm_lower", lower, fit(lower, (0.5, 0.08), (0.5, 0.95), 15))
    hand = sheet.cut((766, 617, 809, 674))
    save("hand", hand, fit(hand, (0.5, 0.12), (0.5, 0.78), 10.5))
    # The legging reaches down into the boot, which bends at the knee as the shin.
    thigh = sheet.cut((464, 719, 500, 796))
    save("thigh", thigh, fit(thigh, (0.5, 0.05), (0.5, 0.97), 31))
    boot = sheet.cut((716, 730, 772, 824))
    save("shin", boot, fit(boot, (0.4, 0.04), (0.4, 0.97), 29))
    dagger = sheet.cut((1067, 626, 1111, 779)).rotate(180)
    save("weapon", dagger, fit(dagger, (0.5, 0.86), (0.5, 0.0), 32))
    save("shield", dagger, fit(dagger, (0.5, 0.86), (0.5, 0.0), 26))
    with open(os.path.join(out, "rig.json"), "w") as handle:
        json.dump(rig, handle, indent=1)


if __name__ == "__main__":
    import sys
    rogue(*sys.argv[1:2])
    print("rogue sheet rig written")
