"""
Hex Siege Arena — Decorative Hex-Grid Background
Draws an animated, slowly drifting hex-grid pattern behind menus.
Uses a single ShapeElementList (GPU-batched) that scrolls via camera offset.
"""

from __future__ import annotations

import math
from typing import List, Tuple

import arcade
from arcade.shape_list import ShapeElementList, create_line_loop


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
HEX_SIZE = 30                     # small decorative hexes
LINE_COLOR = (45, 55, 65, 80)    # subtle grid lines
GLOW_COLORS: List[Tuple[int, ...]] = [
    (80, 160, 255, 18),   # blue
    (200, 160, 60, 18),   # gold
    (255, 80, 80, 18),    # red
]
DRIFT_SPEED_X = 8.0              # px / sec
DRIFT_SPEED_Y = 5.0


def _hex_corners(cx: float, cy: float, size: float) -> list[tuple[float, float]]:
    return [
        (cx + size * math.cos(math.radians(60 * i + 30)),
         cy + size * math.sin(math.radians(60 * i + 30)))
        for i in range(6)
    ]


class HexBackground:
    """Draws a large tiled hex grid that drifts slowly behind a view."""

    def __init__(self, width: int, height: int):
        self._w = width
        self._h = height
        self._offset_x = 0.0
        self._offset_y = 0.0
        self._time = 0.0

        # Pre-build a shape list covering screen + 2 * HEX_SIZE margin
        # so the drift can wrap seamlessly.
        self._shapes = ShapeElementList()
        self._glow_cells: List[Tuple[float, float, int]] = []
        self._build(width + HEX_SIZE * 4, height + HEX_SIZE * 4)

    def _build(self, w: float, h: float):
        """Fill a region with hex outlines."""
        dx = HEX_SIZE * math.sqrt(3)
        dy = HEX_SIZE * 1.5
        cols = int(w / dx) + 2
        rows = int(h / dy) + 2

        idx = 0
        for row in range(rows):
            for col in range(cols):
                cx = col * dx + (dy * 0.5 if row % 2 else 0)
                cy = row * dy
                corners = _hex_corners(cx, cy, HEX_SIZE - 1)
                self._shapes.append(create_line_loop(corners, LINE_COLOR, 1))
                # Every ~7th cell gets a subtle glow highlight
                if idx % 7 == 0:
                    self._glow_cells.append((cx, cy, idx % len(GLOW_COLORS)))
                idx += 1

    def update(self, dt: float):
        self._time += dt
        self._offset_x += DRIFT_SPEED_X * dt
        self._offset_y += DRIFT_SPEED_Y * dt
        # Wrap around
        tile_w = HEX_SIZE * math.sqrt(3)
        tile_h = HEX_SIZE * 1.5
        if self._offset_x > tile_w * 2:
            self._offset_x -= tile_w * 2
        if self._offset_y > tile_h * 2:
            self._offset_y -= tile_h * 2

    def draw(self):
        """Draw the hex grid offset by the current drift."""
        ox = -self._offset_x - HEX_SIZE * 2
        oy = -self._offset_y - HEX_SIZE * 2

        # Use position offset via the shape list (translate)
        self._shapes.position = (ox, oy)
        self._shapes.draw()

        # Pulsing glow highlights
        pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(self._time * 1.2))
        for (cx, cy, ci) in self._glow_cells:
            r, g, b, a = GLOW_COLORS[ci]
            alpha = int(a * pulse)
            corners = _hex_corners(cx + ox, cy + oy, HEX_SIZE - 4)
            arcade.draw_polygon_filled(corners, (r, g, b, alpha))
