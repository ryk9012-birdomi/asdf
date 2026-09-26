"""Cuts a painted key-pose sheet (tools/sheets/<name>_poses.webp) into animation frames.

A pose sheet shows the whole character in a few key poses (ready, wind-up, strike, ...)
on a plain painted ground, three to a row, feet on a shared dusty ground line. Each pose is
cut out of its cell by colour distance from the ground; the painted dust around the feet
is dropped (it is paler than boots), the rim is un-mixed from the ground, and the frame is
saved as a PNG with its anchor: the point between the feet on the ground.

poses.json then tells PosePuppet (scripts/battle/PosePuppet.gd) which frame is which, how
many pixels make a rig unit, and whether the frames still need the painterly shader.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "godot")
LUMA = np.array([0.299, 0.587, 0.114])


class PoseSheet:
    def __init__(self, path):
        self.rgb = np.asarray(Image.open(path).convert("RGB")).astype(float)
        edges = np.concatenate([self.rgb[:8].reshape(-1, 3), self.rgb[-8:].reshape(-1, 3), self.rgb[:, :8].reshape(-1, 3)])
        self.ground = np.median(edges, axis=0)
        self.distance = np.sqrt(((self.rgb - self.ground) ** 2).sum(-1))

    def frame(self, box, dust=70, dark=110, drop_glow=False, paper=False):
        """Cuts the pose in `box`. Within `dust` pixels above the soles only pixels darker than
        `dark` (boots, not dust) survive. `drop_glow` removes blue-violet spell light; `paper`
        opens pale grey ground showing through torn cloth (off for polished steel)."""
        x0, y0, x1, y1 = box
        rgb = self.rgb[y0:y1, x0:x1]
        far = self.distance[y0:y1, x0:x1]
        luma = rgb @ LUMA
        ink = far > 42
        if drop_glow:
            glow = (rgb[..., 2] > rgb[..., 0] + 25) & (rgb[..., 2] > rgb[..., 1] + 15)
            ink &= ~nd.binary_dilation(glow, iterations=2)
        # The soles: the lowest rows that still hold dark boot leather.
        rows = np.nonzero((luma < 80).sum(1) > 6)[0]
        sole = rows.max() + 3 if len(rows) else ink.shape[0]
        band = np.zeros_like(ink)
        band[max(0, sole - dust):, :] = True
        ink &= ~band | (luma < dark)
        ink[sole:, :] = False
        ink = nd.binary_closing(ink, iterations=2)
        labels, count = nd.label(ink)
        sizes = nd.sum(ink, labels, range(1, count + 1))
        keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s >= 0.04 * sizes.max()])
        solid = nd.binary_fill_holes(keep)
        # Filling can close a pocket of dust between the feet; the dust rule wins there.
        solid &= ~band | (luma < dark + 10)
        solid = nd.binary_opening(solid, iterations=1) | (solid & ~band)
        support = nd.binary_dilation(solid, iterations=2)
        solid = nd.binary_erosion(solid, iterations=1)
        alpha = np.where(solid, 1.0, np.where(support, np.clip((far - 14) / 70, 0, 1), 0))
        # Ground showing through rips stays open.
        holes = solid & (far < 22)
        if paper:
            holes |= (luma > self.ground @ LUMA + 10) & (rgb.max(-1) - rgb.min(-1) < 40)
        alpha = np.where(holes, np.minimum(alpha, (far / 22) ** 2), alpha)
        alpha = nd.gaussian_filter(alpha, 0.5) * support
        a = np.maximum(alpha, 0.05)[..., None]
        clean = np.clip((rgb - (1 - a) * self.ground) / a, 0, 255)
        clean = np.where(alpha[..., None] > 0.97, rgb, clean)
        image = Image.fromarray(np.dstack([clean, alpha * 255]).astype(np.uint8), "RGBA")
        # Anchor: between the feet, on the soles (the lowest rows wide enough to be boots,
        # not a stray line of dust).
        wide = np.nonzero(solid.sum(1) >= 24)[0]
        sole = wide.max() + 1 if len(wide) else sole
        feet = np.nonzero(solid[max(0, sole - 40):sole].any(0))[0]
        anchor_x = (feet.min() + feet.max()) / 2.0 if len(feet) else image.width / 2.0
        crop = image.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        image = image.crop(crop)
        return image, [round(float(anchor_x - crop[0]), 1), round(float(sole - crop[1]), 1)]


def build(name, sheet_file, frames, density, paint, out=None):
    """Cuts every frame and writes art/heroes/<name>/poses.json. `frames` maps a pose name
    to its box and options; `density` is sheet pixels per rig unit."""
    sheet = PoseSheet(os.path.join(HERE, "sheets", sheet_file))
    out = out or os.path.join(ROOT, "art", "heroes", name)
    os.makedirs(out, exist_ok=True)
    listing = {}
    for pose, (box, options) in frames.items():
        image, anchor = sheet.frame(box, **options)
        image.save(os.path.join(out, "pose_%s.png" % pose))
        listing[pose] = {"anchor": anchor}
    with open(os.path.join(out, "poses.json"), "w") as handle:
        json.dump({"density": density, "paint": paint, "frames": listing}, handle, indent=1)


# Three columns of 483 px; row one stands on y ~490, row two on y ~980 (labels below).
def cell(column, row, top=None, bottom=None, left=None, right=None):
    x0 = left if left is not None else column * 483
    x1 = right if right is not None else min(1448, (column + 1) * 483)
    y0 = top if top is not None else (0 if row == 0 else 545)
    y1 = bottom if bottom is not None else (505 if row == 0 else 1000)
    return (x0, y0, x1, y1)


def knight():
    frames = {
        "ready": (cell(0, 0), {}), "anticipation": (cell(1, 0), {}), "lunge": (cell(2, 0), {}),
        "strike": (cell(0, 1), {}), "follow": (cell(1, 1), {}), "recovery": (cell(2, 1), {}),
    }
    build("paladin", "knight_poses.webp", frames, 3.1, False)


def mage():
    frames = {
        "ready": (cell(0, 0, right=440), {}), "anticipation": (cell(1, 0, left=440, right=975), {}),
        "channel": (cell(2, 0, left=975), {}), "cast": (cell(0, 1, right=560), {}),
        "release": (cell(1, 1, left=590, right=1140), {}),
        "recovery": (cell(2, 1, left=1140), {"drop_glow": True}),
    }
    build("wizard", "mage_poses.webp", frames, 3.0, True)


if __name__ == "__main__":
    knight()
    mage()
    print("pose frames written")
