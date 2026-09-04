#!/usr/bin/env python3
"""Extract the approved faceless athlete concept into runtime pose textures.

The source sheet intentionally remains in assets/art as the visual reference.
This helper removes its preview checkerboard, isolates each connected athlete,
and creates the orange team palette. Pillow and NumPy are only build-time tools;
the exported game loads the resulting PNG files directly.
"""

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/athlete-style-guide.png"
OUTPUT = ROOT / "assets/art/athletes"
BOXES = {
    "receive": (55, 75, 385, 435),
    "run": (385, 20, 850, 435),
    "crouch": (875, 80, 1215, 440),
    "jump": (1210, 10, 1610, 440),
    "windup": (45, 425, 440, 910),
    "spike": (410, 420, 900, 915),
    "block": (845, 410, 1185, 915),
    "dive": (1170, 600, 1717, 900),
}


def flood_background(rgb: np.ndarray) -> np.ndarray:
    high = rgb.min(axis=2) >= 232
    nearly_neutral = rgb.max(axis=2) - rgb.min(axis=2) <= 16
    eligible = high & nearly_neutral
    height, width = eligible.shape
    background = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            if eligible[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if eligible[y, x] and not background[y, x]:
                background[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= next_y < height and 0 <= next_x < width:
                if eligible[next_y, next_x] and not background[next_y, next_x]:
                    background[next_y, next_x] = True
                    queue.append((next_y, next_x))
    return background


def largest_component(foreground: np.ndarray) -> np.ndarray:
    height, width = foreground.shape
    seen = np.zeros_like(foreground)
    largest: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if not foreground[y, x] or seen[y, x]:
                continue
            component: list[tuple[int, int]] = []
            queue = deque([(y, x)])
            seen[y, x] = True
            while queue:
                at_y, at_x = queue.popleft()
                component.append((at_y, at_x))
                for next_y, next_x in ((at_y - 1, at_x), (at_y + 1, at_x), (at_y, at_x - 1), (at_y, at_x + 1)):
                    if 0 <= next_y < height and 0 <= next_x < width:
                        if foreground[next_y, next_x] and not seen[next_y, next_x]:
                            seen[next_y, next_x] = True
                            queue.append((next_y, next_x))
            if len(component) > len(largest):
                largest = component
    result = np.zeros_like(foreground)
    for y, x in largest:
        result[y, x] = True
    return result


def orange_palette(rgba: np.ndarray) -> np.ndarray:
    result = rgba.copy()
    rgb = result[:, :, :3].astype(np.float32)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    uniform = (blue > red * 1.16) & (blue > green * 0.80) & (blue > 55)
    value = np.maximum.reduce([red, green, blue]) / 255.0
    result[:, :, 0][uniform] = np.clip(238 * value[uniform] + 18, 0, 255)
    result[:, :, 1][uniform] = np.clip(112 * value[uniform] + 7, 0, 255)
    result[:, :, 2][uniform] = np.clip(42 * value[uniform] + 5, 0, 255)
    return result


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGB")
    for name, box in BOXES.items():
        rgb = np.array(source.crop(box))
        foreground = largest_component(~flood_background(rgb))
        alpha = np.where(foreground, 255, 0).astype(np.uint8)
        y_values, x_values = np.where(alpha > 0)
        padding = 4
        left = max(0, int(x_values.min()) - padding)
        top = max(0, int(y_values.min()) - padding)
        right = min(rgb.shape[1], int(x_values.max()) + padding + 1)
        bottom = min(rgb.shape[0], int(y_values.max()) + padding + 1)
        rgba = np.dstack((rgb, alpha))[top:bottom, left:right]
        Image.fromarray(rgba, "RGBA").save(OUTPUT / f"north_{name}.png")
        Image.fromarray(orange_palette(rgba), "RGBA").save(OUTPUT / f"south_{name}.png")


if __name__ == "__main__":
    main()
