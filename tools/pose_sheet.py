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


def cut_all(sheet_file, frames, out):
    """Cuts the named frames of one sheet into out/pose_<name>.png; returns their anchors
    and heights (for matching the scale of another sheet)."""
    sheet = PoseSheet(os.path.join(HERE, "sheets", sheet_file))
    listing = {}
    for pose, (box, options) in frames.items():
        image, anchor = sheet.frame(box, **options)
        image.save(os.path.join(out, "pose_%s.png" % pose))
        listing[pose] = {"anchor": anchor, "height": anchor[1]}
    return listing


def cut_transparent(sheet_file, prefix, out):
    """Frames of a sheet already on a transparent ground (tools/sheets/<name>.webp with
    alpha): every figure is one opaque blob, numbered in reading order. Returns anchors and
    heights like cut_all."""
    image = Image.open(os.path.join(HERE, "sheets", sheet_file)).convert("RGBA")
    alpha = np.asarray(image)[..., 3]
    labels, count = nd.label(alpha > 20)
    boxes = [box for index, box in enumerate(nd.find_objects(labels)) if (labels[box] == index + 1).sum() > 2000]
    boxes.sort(key=lambda box: (box[0].start + box[0].stop) / 2)
    rows = []
    for box in boxes:
        middle = (box[0].start + box[0].stop) / 2
        if rows and abs(middle - rows[-1][0]) < 120:
            rows[-1][1].append(box)
        else:
            rows.append([middle, [box]])
    ordered = [box for _middle, row in rows for box in sorted(row, key=lambda box: box[1].start)]
    listing = {}
    for index, box in enumerate(ordered):
        crop = (max(0, box[1].start - 6), max(0, box[0].start - 6), min(image.width, box[1].stop + 6), min(image.height, box[0].stop + 6))
        frame = image.crop(crop)
        solid = np.asarray(frame)[..., 3] > 128
        sole = np.nonzero(solid.sum(1) >= 24)[0].max() + 1
        feet = np.nonzero(solid[max(0, sole - 30):sole].any(0))[0]
        name = "%s_%02d" % (prefix, index + 1)
        frame.save(os.path.join(out, "pose_%s.png" % name))
        listing[name] = {"anchor": [round(float(feet.min() + feet.max()) / 2.0, 1), float(sole)], "height": float(sole)}
    return listing


def match_colours(out, names, reference):
    """Shifts each channel of the named frames to the mean and spread of the reference
    frame (opaque pixels only): a simple colour transfer between two painted sheets."""
    def stats(image):
        pixels = np.asarray(image).astype(float)
        solid = pixels[..., 3] > 200
        return pixels[..., :3][solid].mean(0), pixels[..., :3][solid].std(0)
    ref_mean, ref_std = stats(Image.open(os.path.join(out, "pose_%s.png" % reference)))
    images = {name: Image.open(os.path.join(out, "pose_%s.png" % name)).convert("RGBA") for name in names}
    stacked = np.concatenate([np.asarray(image).reshape(-1, 4) for image in images.values()])
    solid = stacked[:, 3] > 200
    mean, std = stacked[solid, :3].astype(float).mean(0), stacked[solid, :3].astype(float).std(0)
    for name, image in images.items():
        pixels = np.asarray(image).astype(float)
        pixels[..., :3] = np.clip((pixels[..., :3] - mean) / np.maximum(std, 1) * ref_std + ref_mean, 0, 255)
        Image.fromarray(pixels.astype(np.uint8), "RGBA").save(os.path.join(out, "pose_%s.png" % name))


def build(name, sheet_file, frames, density, paint, idle=None, attack=None):
    """Cuts every frame and writes art/heroes/<name>/poses.json. `frames` maps a pose name
    to its box and options; `density` is sheet pixels per rig unit. `idle` optionally names
    a looping idle sheet (file, frames in order, frames per second); its frames are scaled
    so the first stands as tall as the ready pose. `attack` optionally names a transparent
    frame-by-frame attack sheet: (file, frame prefix, the old pose its last frame matches in
    height, clips, plan overrides)."""
    out = os.path.join(ROOT, "art", "heroes", name)
    os.makedirs(out, exist_ok=True)
    listing = cut_all(sheet_file, frames, out)
    data = {"density": density, "paint": paint, "frames": listing}
    if idle and os.path.exists(os.path.join(HERE, "sheets", idle[0])):
        loop = cut_all(idle[0], idle[1], out)
        first = next(iter(loop.values()))
        idle_density = round(density * first["height"] / listing["ready"]["height"], 3)
        for entry in loop.values():
            entry["density"] = idle_density
        listing.update(loop)
        data["idle"] = list(idle[1].keys())
        data["idle_fps"] = idle[2]
    if attack and os.path.exists(os.path.join(HERE, "sheets", attack[0])):
        sheet_file, prefix, match, clips, plan = attack
        frames = cut_transparent(sheet_file, prefix, out)
        last = list(frames.values())[-1]
        attack_density = round(density * last["height"] / listing[match]["height"], 3)
        # Paint the new frames in the old sheet's colours so poses don't flicker in tone.
        match_colours(out, list(frames), match)
        for entry in frames.values():
            entry["density"] = attack_density
        listing.update(frames)
        data["clips"] = clips
        data["plan"] = plan
    for entry in listing.values():
        entry.pop("height")
    with open(os.path.join(out, "poses.json"), "w") as handle:
        json.dump(data, handle, indent=1)


# Three columns of 483 px; row one stands on y ~490, row two on y ~980 (labels below).
def cell(column, row, top=None, bottom=None, left=None, right=None):
    x0 = left if left is not None else column * 483
    x1 = right if right is not None else min(1448, (column + 1) * 483)
    y0 = top if top is not None else (0 if row == 0 else 545)
    y1 = bottom if bottom is not None else (505 if row == 0 else 1000)
    return (x0, y0, x1, y1)


def grid(columns, index, tops, bottoms, width=1448):
    """Box of cell `index` in a sheet of `columns` equal columns and the given row bands."""
    row, column = divmod(index, columns)
    step = width / columns
    return (int(column * step), tops[row], int(min(width, (column + 1) * step)), bottoms[row])


# The idle loop: ten frames, five to a row (idle, breathe, weight shift, prepare, lift,
# guard high, hold, settle, lower, return), played round and round while waiting.
KNIGHT_IDLE = ("knight_idle.webp",
               {"idle_%02d" % (index + 1): (grid(5, index, (0, 555), (515, 1000)), {}) for index in range(10)}, 5.0)


# The attack, frame by frame (tools/sheets/knight_attack.webp, 16 frames on transparency):
# frames 1-7 raise and cock the sword, 8-16 bring it down and across into a low guard.
KNIGHT_ATTACK = ("knight_attack.webp", "atk", "recovery",
                 {"windup": {"frames": ["atk_%02d" % n for n in range(1, 8)], "fps": 30},
                  "swing": {"frames": ["atk_%02d" % n for n in range(8, 17)], "fps": 30, "commit": True}},
                 {"wind": "windup", "dash": "windup", "hit": "swing", "through": "swing", "back": "atk_16",
                  "raise": "atk_01", "cheer": "atk_01", "guard": "recovery"})


def knight():
    # From the first key-pose sheet only the stance at rest and the shield guard remain;
    # the attack itself comes frame by frame from KNIGHT_ATTACK.
    frames = {"ready": (cell(0, 0), {}), "recovery": (cell(2, 1), {})}
    build("paladin", "knight_poses.webp", frames, 3.1, False, KNIGHT_IDLE, KNIGHT_ATTACK)


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
