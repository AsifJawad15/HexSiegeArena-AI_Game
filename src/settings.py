"""
Hex Siege Arena — Persistent Settings
======================================
Stores user preferences to ``assets/settings.json`` so they survive
between sessions.  Accessed via the ``get_settings()`` singleton.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
_SETTINGS_PATH = Path(__file__).resolve().parent.parent / "assets" / "settings.json"

# ---------------------------------------------------------------------------
# Default values
# ---------------------------------------------------------------------------
_DEFAULTS: Dict[str, Any] = {
    # Audio (0.0 – 1.0)
    "master_volume":  0.60,
    "combat_volume":  1.00,
    "ui_volume":      0.80,
    "ambient_volume": 0.70,
    "music_volume":   0.90,
    # Display
    "show_minimap":   True,
    "anim_speed":     1.0,       # 1.0 = normal, 1.5 = fast, 2.0 = turbo
    # Last-used game options (restored on next launch)
    "last_game_mode":   "pve",
    "last_difficulty":  "medium",
    "last_map":         "standard",
}


# ===================================================================
#  Settings class
# ===================================================================

class Settings:
    """Read / write user preferences backed by a JSON file."""

    def __init__(self) -> None:
        self._data: Dict[str, Any] = dict(_DEFAULTS)
        self._load()

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------
    def _load(self) -> None:
        if not _SETTINGS_PATH.exists():
            return
        try:
            with open(_SETTINGS_PATH, encoding="utf-8") as fh:
                saved = json.load(fh)
            for key, val in saved.items():
                if key in _DEFAULTS:
                    self._data[key] = val
        except Exception:
            pass  # corrupt file – use defaults

    def save(self) -> None:
        """Flush current settings to disk."""
        _SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(_SETTINGS_PATH, "w", encoding="utf-8") as fh:
                json.dump(self._data, fh, indent=2)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Access helpers
    # ------------------------------------------------------------------
    def get(self, key: str) -> Any:
        return self._data.get(key, _DEFAULTS.get(key))

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value

    def __getitem__(self, key: str) -> Any:
        return self.get(key)

    def __setitem__(self, key: str, value: Any) -> None:
        self.set(key, value)

    # Convenience – volume helpers
    def apply_volumes(self) -> None:
        """Push current volume settings into the SoundManager."""
        from .sounds import get_sound_manager
        sm = get_sound_manager()
        sm.set_volume(self._data["master_volume"])
        sm.set_category_volume("combat",  self._data["combat_volume"])
        sm.set_category_volume("ui",      self._data["ui_volume"])
        sm.set_category_volume("ambient", self._data["ambient_volume"])
        sm.set_category_volume("music",   self._data["music_volume"])


# ===================================================================
#  Singleton
# ===================================================================
_instance: Settings | None = None


def get_settings() -> Settings:
    """Return the global Settings instance (created on first call)."""
    global _instance
    if _instance is None:
        _instance = Settings()
    return _instance
