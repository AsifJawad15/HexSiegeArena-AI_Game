"""
Hex Siege Arena — Asset Pipeline
Centralised loading and caching for all textures and animations.

All paths are relative to PROJECT_ROOT / "PNG".
Textures are loaded once and cached for the lifetime of the process.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import arcade

from .app import PROJECT_ROOT

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------
PNG_ROOT = PROJECT_ROOT / "PNG"
HULLS_DIR = {
    "A": PNG_ROOT / "Hulls_Color_A",
    "B": PNG_ROOT / "Hulls_Color_B",
    "C": PNG_ROOT / "Hulls_Color_C",
    "D": PNG_ROOT / "Hulls_Color_D",
}
WEAPONS_DIR = {
    "A": PNG_ROOT / "Weapon_Color_A_256X256",
    "B": PNG_ROOT / "Weapon_Color_B_256X256",
    "C": PNG_ROOT / "Weapon_Color_C_256X256",
    "D": PNG_ROOT / "Weapon_Color_D_256X256",
}
TRACKS_DIR = PNG_ROOT / "Tracks"
EFFECTS_DIR = PNG_ROOT / "Effects"
SPRITES_DIR = EFFECTS_DIR / "Sprites"

# ---------------------------------------------------------------------------
# Tank configuration (decided in Phase 0 planning)
# ---------------------------------------------------------------------------
# Each of the four tanks gets its own colour variant.
# P1 King = A (green), P1 Queen = C (camo/dark),
# P2 King = B (desert), P2 Queen = D (blue-grey).
TANK_COLOR = {
    (1, "king"):  "A",
    (1, "queen"): "C",
    (2, "king"):  "B",
    (2, "queen"): "D",
}

# King = Hull_06 + Gun_05, Queen = Hull_01 + Gun_08
TANK_CONFIG = {
    "king":  {"hull": "Hull_06", "gun": "Gun_05", "track": "Track_2"},
    "queen": {"hull": "Hull_01", "gun": "Gun_08", "track": "Track_1"},
}

# ---------------------------------------------------------------------------
# Global texture cache  (populated lazily)
# ---------------------------------------------------------------------------
_texture_cache: Dict[str, arcade.Texture] = {}
_animation_cache: Dict[str, List[arcade.Texture]] = {}


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------
def _load_texture(path: Path, key: str | None = None) -> arcade.Texture:
    """Load a single texture and cache it by *key* (defaults to path)."""
    k = key or str(path)
    if k not in _texture_cache:
        _texture_cache[k] = arcade.load_texture(str(path))
    return _texture_cache[k]


def _load_animation_frames(
    directory: Path,
    prefix: str,
    count: int,
    cache_key: str | None = None,
) -> List[arcade.Texture]:
    """
    Load a numbered sequence of PNGs as a list of textures.
    Files are expected to be named ``{prefix}_{NNN}.png`` with zero-padded
    frame numbers starting at 000.
    """
    k = cache_key or f"{directory}/{prefix}"
    if k not in _animation_cache:
        frames: List[arcade.Texture] = []
        for i in range(count):
            fname = f"{prefix}_{i:03d}.png"
            fpath = directory / fname
            if fpath.exists():
                frames.append(arcade.load_texture(str(fpath)))
        _animation_cache[k] = frames
    return _animation_cache[k]


# ---------------------------------------------------------------------------
# Public API — Tank textures
# ---------------------------------------------------------------------------
def get_hull_texture(player: int, role: str) -> arcade.Texture:
    """
    Load the hull texture for *player* (1 or 2) and *role* ("king" | "queen").
    """
    colour = TANK_COLOR[(player, role)]
    hull_name = TANK_CONFIG[role]["hull"]
    path = HULLS_DIR[colour] / f"{hull_name}.png"
    return _load_texture(path, key=f"hull_{colour}_{hull_name}")


def get_gun_texture(player: int, role: str, variant: str = "") -> arcade.Texture:
    """
    Load the gun/weapon texture.
    *variant*: "" (default), "_A" (fired-A), "_B" (fired-B).
    Uses the 256×256 version for consistency.
    """
    colour = TANK_COLOR[(player, role)]
    gun_name = TANK_CONFIG[role]["gun"]
    fname = f"{gun_name}{variant}.png"
    path = WEAPONS_DIR[colour] / fname
    return _load_texture(path, key=f"gun_{colour}_{gun_name}{variant}")


def get_track_texture(role: str, frame: str = "A") -> arcade.Texture:
    """
    Load a track texture.  *frame* is "A" or "B" for the two animation frames.
    Tracks are colourless (shared by both players).
    """
    track_name = TANK_CONFIG[role]["track"]
    fname = f"{track_name}_{frame}.png"
    path = TRACKS_DIR / fname
    return _load_texture(path, key=f"track_{track_name}_{frame}")


# ---------------------------------------------------------------------------
# Public API — Effect textures & animations
# ---------------------------------------------------------------------------
def get_explosion_frames() -> List[arcade.Texture]:
    """9-frame explosion sprite animation."""
    return _load_animation_frames(SPRITES_DIR, "Sprite_Effects_Explosion", 9)


def get_exhaust_frames(variant: int = 1) -> List[arcade.Texture]:
    """10-frame exhaust animation (variant 1 or 2)."""
    prefix = f"Sprite_Effects_Exhaust_{variant:02d}"
    return _load_animation_frames(SPRITES_DIR, prefix, 10)


def get_flame_shot_frames() -> List[arcade.Texture]:
    """10-frame muzzle-flame animation."""
    return _load_animation_frames(SPRITES_DIR, "Sprite_Fire_Shots_Flame", 10)


def get_shot_frames(variant: str = "A") -> List[arcade.Texture]:
    """4-frame projectile-shot animation (variant A or B)."""
    prefix = f"Sprite_Fire_Shots_Shot_{variant}"
    return _load_animation_frames(SPRITES_DIR, prefix, 4)


def get_impact_frames(variant: str = "A") -> List[arcade.Texture]:
    """4-frame impact animation (variant A or B)."""
    prefix = f"Sprite_Fire_Shots_Impact_{variant}"
    return _load_animation_frames(SPRITES_DIR, prefix, 4)


def get_static_effect(name: str) -> arcade.Texture:
    """
    Load a single static effect PNG from Effects/.
    *name* examples: "Laser", "Heavy_Shell", "Explosion_A", "Smoke_A".
    """
    path = EFFECTS_DIR / f"{name}.png"
    return _load_texture(path, key=f"fx_{name}")


# ---------------------------------------------------------------------------
# Public API — Static explosion letters (A-H) for variety
# ---------------------------------------------------------------------------
def get_explosion_static_textures() -> List[arcade.Texture]:
    """Load Explosion_A.png … Explosion_H.png as a list."""
    textures: List[arcade.Texture] = []
    for letter in "ABCDEFGH":
        p = EFFECTS_DIR / f"Explosion_{letter}.png"
        if p.exists():
            textures.append(_load_texture(p, key=f"explosion_static_{letter}"))
    return textures


def get_smoke_textures() -> List[arcade.Texture]:
    """Load Smoke_A.png … Smoke_C.png."""
    textures: List[arcade.Texture] = []
    for letter in "ABC":
        p = EFFECTS_DIR / f"Smoke_{letter}.png"
        if p.exists():
            textures.append(_load_texture(p, key=f"smoke_{letter}"))
    return textures


def get_flash_textures(variant: str = "A") -> List[arcade.Texture]:
    """Load Flash_{variant}_01 … _05."""
    textures: List[arcade.Texture] = []
    for i in range(1, 6):
        p = EFFECTS_DIR / f"Flash_{variant}_{i:02d}.png"
        if p.exists():
            textures.append(_load_texture(p, key=f"flash_{variant}_{i:02d}"))
    return textures


# ---------------------------------------------------------------------------
# Preload (call once at window init to avoid in-game hitches)
# ---------------------------------------------------------------------------
def preload_all():
    """
    Eagerly load every texture that will be needed during gameplay.
    Call this from code that runs before the first frame is drawn.
    """
    # Tank parts for both players, both roles
    for player in (1, 2):
        for role in ("king", "queen"):
            get_hull_texture(player, role)
            get_gun_texture(player, role, "")
            get_gun_texture(player, role, "_A")
            get_gun_texture(player, role, "_B")
            for frame in ("A", "B"):
                get_track_texture(role, frame)

    # Effects
    get_explosion_frames()
    get_exhaust_frames(1)
    get_exhaust_frames(2)
    get_flame_shot_frames()
    get_shot_frames("A")
    get_shot_frames("B")
    get_impact_frames("A")
    get_impact_frames("B")
    get_explosion_static_textures()
    get_smoke_textures()
    get_flash_textures("A")
    get_flash_textures("B")
    get_static_effect("Laser")
    get_static_effect("Heavy_Shell")
