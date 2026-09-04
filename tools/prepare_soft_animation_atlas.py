#!/usr/bin/env python3
"""Extract and compose SIDEOUT's soft faceless athlete animation atlas.

Run with the bundled workspace Python, which provides Pillow and NumPy.  The
four source studies use a chroma-green background.  This script keys it out,
isolates complete connected figures, normalizes their scale and baseline, and
builds matching north/south 8x4 runtime atlases.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art" / "animation"
SOURCE = ART / "source"
CELL = 384
COLS = 8
ROWS = 4
BASELINE = 360


@dataclass
class Figure:
    rgba: np.ndarray
    labels: np.ndarray
    label: int
    area: int
    box: tuple[int, int, int, int]

    @property
    def center(self) -> tuple[float, float]:
        left, top, right, bottom = self.box
        return ((left + right) * 0.5, (top + bottom) * 0.5)


def keyed_rgba(path: Path) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.asarray(Image.open(path).convert("RGB")).copy()
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    green_score = green - np.maximum(red, blue)
    # Fully opaque before the green dominates; feather only the antialiased rim.
    alpha = np.clip((70 - green_score) * (255.0 / 35.0), 0, 255).astype(np.uint8)
    fringe = (alpha > 0) & (alpha < 255)
    rgb[:, :, 1][fringe] = np.minimum(
        rgb[:, :, 1][fringe],
        np.maximum(rgb[:, :, 0][fringe], rgb[:, :, 2][fringe]) + 12,
    )
    rgba = np.dstack((rgb, alpha))
    return rgba, alpha >= 96


def find_figures(path: Path, minimum_area: int = 2500) -> list[Figure]:
    rgba, foreground = keyed_rgba(path)
    height, width = foreground.shape
    labels = np.zeros((height, width), dtype=np.int16)
    figures: list[Figure] = []
    next_label = 0
    for y in range(height):
        for x in range(width):
            if not foreground[y, x] or labels[y, x] != 0:
                continue
            next_label += 1
            queue = deque([(y, x)])
            labels[y, x] = next_label
            area = 0
            left = right = x
            top = bottom = y
            while queue:
                at_y, at_x = queue.popleft()
                area += 1
                left = min(left, at_x)
                right = max(right, at_x)
                top = min(top, at_y)
                bottom = max(bottom, at_y)
                for next_y, next_x in (
                    (at_y - 1, at_x), (at_y + 1, at_x),
                    (at_y, at_x - 1), (at_y, at_x + 1),
                ):
                    if 0 <= next_y < height and 0 <= next_x < width:
                        if foreground[next_y, next_x] and labels[next_y, next_x] == 0:
                            labels[next_y, next_x] = next_label
                            queue.append((next_y, next_x))
            if area >= minimum_area:
                figures.append(Figure(rgba, labels, next_label, area, (left, top, right + 1, bottom + 1)))
    return figures


def ordered_base() -> list[Figure]:
    figures = find_figures(SOURCE / "wing-spiker-base.png")
    rows = [[], [], [], []]
    for figure in figures:
        y = figure.center[1]
        row = 0 if y < 300 else (1 if y < 600 else (2 if y < 900 else 3))
        rows[row].append(figure)
    for row in rows:
        row.sort(key=lambda figure: figure.center[0])
    assert [len(row) for row in rows] == [4, 4, 4, 5], [len(row) for row in rows]
    return [figure for row in rows for figure in row]


def ordered_strip(name: str, count: int) -> list[Figure]:
    figures = find_figures(SOURCE / f"wing-spiker-{name}.png")
    figures.sort(key=lambda figure: figure.center[0])
    assert len(figures) == count, (name, len(figures))
    return figures


def dilate(mask: np.ndarray, iterations: int = 2) -> np.ndarray:
    result = mask.copy()
    for _ in range(iterations):
        padded = np.pad(result, 1)
        expanded = result.copy()
        for offset_y in range(3):
            for offset_x in range(3):
                expanded |= padded[offset_y:offset_y + result.shape[0], offset_x:offset_x + result.shape[1]]
        result = expanded
    return result


def render_figure(figure: Figure, scale: float) -> Image.Image:
    left, top, right, bottom = figure.box
    rgba = figure.rgba[top:bottom, left:right].copy()
    body = figure.labels[top:bottom, left:right] == figure.label
    keep = dilate(body)
    rgba[:, :, 3][~keep] = 0
    image = Image.fromarray(rgba, "RGBA")
    target = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(target, Image.Resampling.LANCZOS)


def paste_frame(atlas: Image.Image, index: int, figure: Figure, scale: float) -> None:
    image = render_figure(figure, scale)
    # Keep exceptional long contact poses inside the common cell without
    # changing the size of ordinary poses in the same sequence.
    fit = min(1.0, (CELL - 8) / image.width, (BASELINE - 4) / image.height)
    if fit < 1.0:
        image = image.resize((round(image.width * fit), round(image.height * fit)), Image.Resampling.LANCZOS)
    column = index % COLS
    row = index // COLS
    x = column * CELL + (CELL - image.width) // 2
    y = row * CELL + BASELINE - image.height
    atlas.alpha_composite(image, (x, y))


def opponent_palette(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image).copy()
    rgb = rgba[:, :, :3].astype(np.float32)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    cyan = (
        (rgba[:, :, 3] > 0)
        & (blue > red * 1.08)
        & (green > red * 1.08)
        & (blue > 95)
    )
    strength = np.clip((np.minimum(green, blue) - red) / 105.0, 0.0, 1.0)
    orange = np.stack((np.full_like(red, 231), np.full_like(red, 119), np.full_like(red, 53)), axis=2)
    mix = (strength * cyan)[:, :, None]
    rgba[:, :, :3] = np.clip(rgb * (1.0 - mix) + orange * mix, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    base = ordered_base()
    run = ordered_strip("run", 6)
    spike = ordered_strip("spike", 8)
    serve = ordered_strip("serve", 8)
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))

    # Row 1: quiet upright breathing and a complete six-frame sprint.
    paste_frame(atlas, 0, base[0], 1.20)
    paste_frame(atlas, 1, base[1], 1.20)
    for index, figure in enumerate(run, 2):
        paste_frame(atlas, index, figure, 0.95)

    # Rows 2 and 3: separately authored spike and jump-serve sequences.
    for index, figure in enumerate(spike, 8):
        paste_frame(atlas, index, figure, 0.86)
    for index, figure in enumerate(serve, 16):
        paste_frame(atlas, index, figure, 0.98)

    # Row 4: receive, set, block, dive, and recovery.  Duplicate contact poses
    # provide a short readable hold without freezing the whole match.
    utilities = [base[13], base[13], base[14], base[14], base[15], base[15], base[16], base[9]]
    for index, figure in enumerate(utilities, 24):
        paste_frame(atlas, index, figure, 1.20)

    atlas.save(ART / "wing-spiker-north.png", optimize=True)
    opponent_palette(atlas).save(ART / "wing-spiker-south.png", optimize=True)
    print(f"Prepared {COLS}x{ROWS} atlas at {CELL}px per frame")


if __name__ == "__main__":
    main()
