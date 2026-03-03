"""
Hex Siege Arena — Settings View
================================
Full-screen settings panel with volume controls, display options,
and lifetime statistics.  Accessible from the main menu.
"""

from __future__ import annotations

import arcade
import arcade.gui

from ..app import SCREEN_WIDTH, SCREEN_HEIGHT, FONT_NAME
from ..sounds import get_sound_manager as _sfx
from ..settings import get_settings
from ..stats import get_stats
from ..ui import HexBackground, StyledButton, StyledCycleButton


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------
BG_COLOR      = (18, 22, 28)
PANEL_COLOR   = (30, 38, 48, 220)
ACCENT        = (200, 160, 60)
TEXT_COLOR     = arcade.color.WHITE
SUBTITLE_COLOR = (160, 160, 175)
STAT_COLOR    = (140, 180, 220)

# Volume presets: label → float
_VOL_PRESETS = [
    ("Mute", 0.0),
    ("Low",  0.25),
    ("Med",  0.55),
    ("High", 0.80),
    ("Max",  1.00),
]

_SPEED_PRESETS = [
    ("Normal", 1.0),
    ("Fast",   1.5),
    ("Turbo",  2.0),
]


def _vol_label(val: float) -> str:
    """Map a volume float to the closest preset label."""
    best, best_d = "Med", 999.0
    for label, v in _VOL_PRESETS:
        d = abs(v - val)
        if d < best_d:
            best, best_d = label, d
    return best


def _speed_label(val: float) -> str:
    best, best_d = "Normal", 999.0
    for label, v in _SPEED_PRESETS:
        d = abs(v - val)
        if d < best_d:
            best, best_d = label, d
    return best


class SettingsView(arcade.View):
    """Settings screen with audio, display options and session stats."""

    def __init__(self) -> None:
        super().__init__()
        self.ui = arcade.gui.UIManager()
        self._hex_bg = HexBackground(SCREEN_WIDTH, SCREEN_HEIGHT)
        self._time: float = 0.0
        self._settings = get_settings()
        self._stats = get_stats()
        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------
    def _build_ui(self) -> None:
        self.ui.clear()
        vbox = arcade.gui.UIBoxLayout(space_between=14)

        # Title
        title = arcade.gui.UILabel(
            text="\u2699  SETTINGS",
            font_name=FONT_NAME, font_size=36,
            text_color=ACCENT, align="center", width=600,
        )
        vbox.add(title)
        vbox.add(arcade.gui.UISpace(height=8))

        # ── Audio section ─────────────────────────────────────────────
        audio_lbl = arcade.gui.UILabel(
            text="\u266B  AUDIO",
            font_name=FONT_NAME, font_size=16,
            text_color=ACCENT, width=500, align="center",
        )
        vbox.add(audio_lbl)

        self._vol_btns: dict[str, StyledCycleButton] = {}
        for key, label in [
            ("master_volume",  "Master"),
            ("combat_volume",  "Combat"),
            ("ui_volume",      "UI"),
            ("music_volume",   "Music"),
        ]:
            row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
            row_label = arcade.gui.UILabel(
                text=f"{label}:", font_size=15,
                text_color=TEXT_COLOR, width=140,
            )
            row.add(row_label)
            btn = StyledCycleButton(
                text=_vol_label(self._settings[key]),
                width=140, height=38,
            )
            btn.on_click = self._make_vol_cycler(key)
            row.add(btn)
            self._vol_btns[key] = btn
            vbox.add(row)

        vbox.add(arcade.gui.UISpace(height=8))

        # ── Display section ───────────────────────────────────────────
        disp_lbl = arcade.gui.UILabel(
            text="\u2726  DISPLAY",
            font_name=FONT_NAME, font_size=16,
            text_color=ACCENT, width=500, align="center",
        )
        vbox.add(disp_lbl)

        # Minimap toggle
        mm_row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
        mm_label = arcade.gui.UILabel(
            text="Minimap:", font_size=15,
            text_color=TEXT_COLOR, width=140,
        )
        mm_row.add(mm_label)
        self._mm_btn = StyledCycleButton(
            text="On" if self._settings["show_minimap"] else "Off",
            width=140, height=38,
        )
        self._mm_btn.on_click = self._toggle_minimap
        mm_row.add(self._mm_btn)
        vbox.add(mm_row)

        # Animation speed
        spd_row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
        spd_label = arcade.gui.UILabel(
            text="Anim Speed:", font_size=15,
            text_color=TEXT_COLOR, width=140,
        )
        spd_row.add(spd_label)
        self._spd_btn = StyledCycleButton(
            text=_speed_label(self._settings["anim_speed"]),
            width=140, height=38,
        )
        self._spd_btn.on_click = self._cycle_speed
        spd_row.add(self._spd_btn)
        vbox.add(spd_row)

        vbox.add(arcade.gui.UISpace(height=12))

        # ── Stats section ─────────────────────────────────────────────
        stat_lbl = arcade.gui.UILabel(
            text="\u2605  LIFETIME STATS",
            font_name=FONT_NAME, font_size=16,
            text_color=ACCENT, width=500, align="center",
        )
        vbox.add(stat_lbl)

        for line in self._stats.detail_lines():
            sl = arcade.gui.UILabel(
                text=line, font_size=13,
                text_color=STAT_COLOR, width=420, align="center",
            )
            vbox.add(sl)

        vbox.add(arcade.gui.UISpace(height=16))

        # ── Back button ───────────────────────────────────────────────
        back_btn = StyledButton(text="BACK", width=260, height=48)
        back_btn.on_click = self._on_back
        vbox.add(back_btn)

        anchor = arcade.gui.UIAnchorLayout()
        anchor.add(child=vbox, anchor_x="center_x", anchor_y="center_y")
        self.ui.add(anchor)

    # ------------------------------------------------------------------
    # Volume cycling
    # ------------------------------------------------------------------
    def _make_vol_cycler(self, key: str):
        """Return a callback that cycles the given volume key."""
        def _cycler(_event):
            _sfx().play("menu_click")
            cur = self._settings[key]
            # Find current index, advance
            idx = 0
            for i, (_, v) in enumerate(_VOL_PRESETS):
                if abs(v - cur) < 0.05:
                    idx = i
                    break
            idx = (idx + 1) % len(_VOL_PRESETS)
            new_label, new_val = _VOL_PRESETS[idx]
            self._settings[key] = new_val
            self._vol_btns[key].text = new_label
            self._settings.apply_volumes()
        return _cycler

    def _toggle_minimap(self, _event):
        _sfx().play("menu_click")
        cur = self._settings["show_minimap"]
        self._settings["show_minimap"] = not cur
        self._mm_btn.text = "On" if not cur else "Off"

    def _cycle_speed(self, _event):
        _sfx().play("menu_click")
        cur = self._settings["anim_speed"]
        idx = 0
        for i, (_, v) in enumerate(_SPEED_PRESETS):
            if abs(v - cur) < 0.05:
                idx = i
                break
        idx = (idx + 1) % len(_SPEED_PRESETS)
        new_label, new_val = _SPEED_PRESETS[idx]
        self._settings["anim_speed"] = new_val
        self._spd_btn.text = new_label

    def _on_back(self, _event):
        _sfx().play("menu_click")
        self._settings.save()
        self.window.show_menu()

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def on_show_view(self):
        arcade.set_background_color(BG_COLOR)
        self.ui.enable()

    def on_hide_view(self):
        self.ui.disable()

    def on_update(self, delta_time: float):
        self._hex_bg.update(delta_time)
        self._time += delta_time

    def on_draw(self):
        self.clear()
        self._hex_bg.draw()
        self.ui.draw()

    def on_key_press(self, key, _modifiers):
        if key == arcade.key.ESCAPE:
            self._on_back(None)
