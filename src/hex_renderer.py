"""
Hex Siege Arena — Procedural Hex Renderer (Batch 2: Board Materials & Lighting)

Generates radial-gradient hex textures at runtime using PIL, cached as
Arcade Textures.  Also provides a pulsing glow sprite for special cells
and a full-screen vignette overlay.
"""

from __future__ import annotations

import math
from typing import Dict, Tuple

import arcade
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Texture cache  (cell_type_key → arcade.Texture)
# ---------------------------------------------------------------------------
_TEX_CACHE: Dict[str, arcade.Texture] = {}


def _hex_mask(size: int) -> Image.Image:
    """Return an RGBA image with a filled hexagon on transparent background."""
    img = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size, size
    pts = []
    for i in range(6):
        angle = math.radians(60 * i)
        pts.append((cx + (size - 2) * math.cos(angle),
                     cy + (size - 2) * math.sin(angle)))
    draw.polygon(pts, fill=(255, 255, 255, 255))
    return img


def hex_texture(
    base_color: Tuple[int, ...],
    size: int = 40,
    *,
    key: str = "",
    highlight: float = 0.18,
    darken_edge: float = 0.25,
) -> arcade.Texture:
    """
    Generate a hex-shaped texture with a subtle radial gradient.

    *highlight*  — fraction brighter at centre (0 = flat).
    *darken_edge* — fraction darker at rim (0 = flat).
    """
    cache_key = f"hex_{key}_{size}"
    if cache_key in _TEX_CACHE:
        return _TEX_CACHE[cache_key]

    dim = size * 2
    img = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
    pixels = img.load()
    mask = _hex_mask(size)
    mask_px = mask.load()
    cx, cy = size, size
    max_dist = size * 0.92  # normalise gradient to hex inner radius

    r0, g0, b0 = base_color[0], base_color[1], base_color[2]
    a0 = base_color[3] if len(base_color) > 3 else 255

    for y in range(dim):
        for x in range(dim):
            if mask_px[x, y][3] == 0:
                continue
            dist = math.hypot(x - cx, y - cy)
            t = min(dist / max_dist, 1.0)  # 0 at centre → 1 at edge
            # Radial gradient: brighten centre, darken edge
            factor = 1.0 + highlight * (1.0 - t) - darken_edge * t
            r = max(0, min(255, int(r0 * factor)))
            g = max(0, min(255, int(g0 * factor)))
            b = max(0, min(255, int(b0 * factor)))
            pixels[x, y] = (r, g, b, a0)

    tex = arcade.Texture(img, hit_box_algorithm=None)
    _TEX_CACHE[cache_key] = tex
    return tex


def glow_texture(
    color: Tuple[int, int, int],
    size: int = 60,
    alpha_peak: int = 60,
) -> arcade.Texture:
    """Soft radial glow disc for underlighting special cells."""
    cache_key = f"glow_{color}_{size}_{alpha_peak}"
    if cache_key in _TEX_CACHE:
        return _TEX_CACHE[cache_key]

    dim = size * 2
    img = Image.new("RGBA", (dim, dim), (0, 0, 0, 0))
    pixels = img.load()
    cx, cy = size, size

    for y in range(dim):
        for x in range(dim):
            dist = math.hypot(x - cx, y - cy)
            t = dist / size
            if t > 1.0:
                continue
            # Smooth fall-off
            a = int(alpha_peak * (1.0 - t * t))
            pixels[x, y] = (color[0], color[1], color[2], a)

    tex = arcade.Texture(img, hit_box_algorithm=None)
    _TEX_CACHE[cache_key] = tex
    return tex


def vignette_texture(width: int, height: int, strength: float = 0.45) -> arcade.Texture:
    """Full-screen vignette overlay (darkened corners). Generated at 1/4 res."""
    cache_key = f"vignette_{width}_{height}_{strength}"
    if cache_key in _TEX_CACHE:
        return _TEX_CACHE[cache_key]

    # Generate at quarter resolution for speed, will be scaled up by sprite
    sw, sh = width // 4, height // 4
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    pixels = img.load()
    cx, cy = sw / 2, sh / 2
    max_dist = math.hypot(cx, cy)

    for y in range(sh):
        for x in range(sw):
            dist = math.hypot(x - cx, y - cy)
            t = dist / max_dist
            a = int(255 * strength * t * t)
            pixels[x, y] = (0, 0, 0, min(a, 255))

    # Scale back up with bilinear filtering
    img = img.resize((width, height), Image.BILINEAR)

    tex = arcade.Texture(img, hit_box_algorithm=None)
    _TEX_CACHE[cache_key] = tex
    return tex
