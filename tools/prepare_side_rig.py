"""Prepare transparent runtime parts from the original generated atlas.

Requires Pillow and NumPy. Run from any directory; output stays beside source.
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ART_DIR = Path(__file__).resolve().parents[1] / "assets/art/side_rig"
PARTS = [
    "head", "torso", "torso_turn", "pelvis",
    "upper_arm", "forearm", "far_upper_arm", "far_forearm",
    "thigh", "shin", "shoe", "palm",
]
GARMENTS = {"torso", "torso_turn", "pelvis", "upper_arm", "far_upper_arm", "thigh"}


def remove_checker(pixels):
    """Remove only bright neutral pixels connected to the cell boundary."""
    height, width = pixels.shape[:2]
    eligible = (pixels.min(axis=2) > 205) & (
        pixels.max(axis=2).astype(int) - pixels.min(axis=2) < 16
    )
    background = np.zeros((height, width), dtype=bool)
    queue = deque()
    boundary = [(y, x) for y in (0, height - 1) for x in range(width)]
    boundary += [(y, x) for x in (0, width - 1) for y in range(height)]
    for y, x in boundary:
        if eligible[y, x] and not background[y, x]:
            background[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if (0 <= yy < height and 0 <= xx < width
                    and eligible[yy, xx] and not background[yy, xx]):
                background[yy, xx] = True
                queue.append((yy, xx))
    alpha = np.where(background, 0, 255).astype("uint8")
    # Remove the one-pixel matte left by the generated checker background.
    alpha = np.array(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))
    result = Image.fromarray(np.dstack([pixels, alpha]))
    return result.crop(result.getbbox())


def south_palette(image, name):
    result = np.array(image)
    if name in GARMENTS:
        rgb = result[:, :, :3].astype(float)
        garment = ((rgb[:, :, 2] > rgb[:, :, 0] * 1.22)
                   & (rgb[:, :, 2] > rgb[:, :, 1] * 1.07)
                   & (result[:, :, 3] > 0))
        rgb[garment] = rgb[garment][:, [2, 1, 0]] * np.array([1.18, .88, .86])
        result[:, :, :3] = rgb.clip(0, 255).astype("uint8")
    return Image.fromarray(result)


def main():
    atlas = Image.open(ART_DIR / "source-atlas.png").convert("RGB")
    assert atlas.width % 4 == 0 and atlas.height % 3 == 0
    cell_width, cell_height = atlas.width // 4, atlas.height // 3
    for index, name in enumerate(PARTS):
        x, y = index % 4 * cell_width, index // 4 * cell_height
        pixels = np.array(atlas.crop((x, y, x + cell_width, y + cell_height)))
        part = remove_checker(pixels)
        part.save(ART_DIR / f"{name}.png")
        south_palette(part, name).save(ART_DIR / f"{name}-south.png")
        print(name, part.size)


if __name__ == "__main__":
    main()
