"""
Hex Siege Arena — Main Menu View
Provides game-mode selection, difficulty, and map-type settings.
Decorative animated hex background with styled military buttons.
"""

from __future__ import annotations

import math
import arcade
import arcade.gui

from ..app import SCREEN_WIDTH, SCREEN_HEIGHT, FONT_NAME
from ..sounds import get_sound_manager as _sfx
from ..settings import get_settings as _cfg
from ..stats import get_stats as _sts
from ..ui import HexBackground, StyledButton, StyledCycleButton


# ---------------------------------------------------------------------------
# Colour palette (military / dark theme)
# ---------------------------------------------------------------------------
BG_COLOR = (18, 22, 28)          # near-black
PANEL_COLOR = (30, 38, 48, 220)  # translucent dark-blue
ACCENT = (200, 160, 60)          # gold
TEXT_COLOR = arcade.color.WHITE
SUBTITLE_COLOR = (160, 160, 175)


class MenuView(arcade.View):
    """Full-screen main menu with Start / Settings / Quit."""

    def __init__(self):
        super().__init__()
        self.ui = arcade.gui.UIManager()
        self._hex_bg = HexBackground(SCREEN_WIDTH, SCREEN_HEIGHT)
        self._time: float = 0.0   # for animations
        # Phase 10: persistent Text for version label
        self._txt_version = arcade.Text(
            "v2.0  \u2022  Arcade Edition",
            SCREEN_WIDTH // 2, 0,  # y updated per-frame
            (120, 120, 130, 160), 10, anchor_x="center", font_name=FONT_NAME,
        )

        # ---- state shown on the menu ----------------------------------
        self._mode_options = ["PvP", "PvE", "AI vs AI"]
        self._diff_options = ["Easy", "Medium", "Hard"]
        self._map_options  = ["Standard", "Open", "Fortress"]

        # Restore last-used settings
        _mode_map = {"pvp": 0, "pve": 1, "ai_vs_ai": 2}
        _diff_map = {"easy": 0, "medium": 1, "hard": 2}
        _map_map  = {"standard": 0, "open": 1, "fortress": 2}
        cfg = _cfg()
        self._mode_idx = _mode_map.get(cfg["last_game_mode"], 1)
        self._diff_idx = _diff_map.get(cfg["last_difficulty"], 1)
        self._map_idx  = _map_map.get(cfg["last_map"], 0)

        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------
    def _build_ui(self):
        """Create all UI widgets and arrange them."""
        self.ui.clear()

        # Vertical box centered on screen
        vbox = arcade.gui.UIBoxLayout(space_between=18)

        # Title
        title = arcade.gui.UILabel(
            text="HEX SIEGE ARENA",
            font_name=FONT_NAME,
            font_size=42,
            text_color=ACCENT,
            align="center",
            width=600,
        )
        vbox.add(title)

        # Subtitle
        sub = arcade.gui.UILabel(
            text="Chess \u00d7 Bomberman on a Hex Grid",
            font_name=FONT_NAME,
            font_size=16,
            text_color=SUBTITLE_COLOR,
            align="center",
            width=600,
        )
        vbox.add(sub)

        # Spacer
        vbox.add(arcade.gui.UISpace(height=20))

        # ---- Mode selector -------------------------------------------
        mode_row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
        mode_label = arcade.gui.UILabel(
            text="Mode:", font_size=18, text_color=TEXT_COLOR, width=120,
        )
        mode_row.add(mode_label)

        self._mode_btn = StyledCycleButton(
            text=self._mode_options[self._mode_idx], width=200, height=44,
        )
        self._mode_btn.on_click = self._cycle_mode
        mode_row.add(self._mode_btn)
        vbox.add(mode_row)

        # ---- Difficulty selector --------------------------------------
        diff_row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
        diff_label = arcade.gui.UILabel(
            text="Difficulty:", font_size=18, text_color=TEXT_COLOR, width=120,
        )
        diff_row.add(diff_label)

        self._diff_btn = StyledCycleButton(
            text=self._diff_options[self._diff_idx], width=200, height=44,
        )
        self._diff_btn.on_click = self._cycle_diff
        diff_row.add(self._diff_btn)
        vbox.add(diff_row)

        # ---- Map selector ---------------------------------------------
        map_row = arcade.gui.UIBoxLayout(vertical=False, space_between=12)
        map_label = arcade.gui.UILabel(
            text="Map:", font_size=18, text_color=TEXT_COLOR, width=120,
        )
        map_row.add(map_label)

        self._map_btn = StyledCycleButton(
            text=self._map_options[self._map_idx], width=200, height=44,
        )
        self._map_btn.on_click = self._cycle_map
        map_row.add(self._map_btn)
        vbox.add(map_row)

        # Spacer
        vbox.add(arcade.gui.UISpace(height=20))

        # ---- Start button --------------------------------------------
        start_btn = StyledButton(text="START GAME", width=300, height=56, accent=True, font_size=20)
        start_btn.on_click = self._on_start
        vbox.add(start_btn)

        # ---- Settings button -----------------------------------------
        settings_btn = StyledButton(text="SETTINGS", width=300, height=46)
        settings_btn.on_click = self._on_settings
        vbox.add(settings_btn)

        # ---- Quit button ---------------------------------------------
        quit_btn = StyledButton(text="QUIT", width=300, height=46)
        quit_btn.on_click = self._on_quit
        vbox.add(quit_btn)

        # ---- Stats summary -------------------------------------------
        stats_text = _sts().summary_line()
        stats_label = arcade.gui.UILabel(
            text=stats_text,
            font_name=FONT_NAME, font_size=11,
            text_color=(120, 130, 150), align="center", width=600,
        )
        vbox.add(stats_label)

        # Anchor everything in the centre
        anchor = arcade.gui.UIAnchorLayout()
        anchor.add(child=vbox, anchor_x="center_x", anchor_y="center_y")
        self.ui.add(anchor)

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------
    def _cycle_mode(self, _event):
        _sfx().play("menu_click")
        self._mode_idx = (self._mode_idx + 1) % len(self._mode_options)
        self._mode_btn.text = self._mode_options[self._mode_idx]

    def _cycle_diff(self, _event):
        _sfx().play("menu_click")
        self._diff_idx = (self._diff_idx + 1) % len(self._diff_options)
        self._diff_btn.text = self._diff_options[self._diff_idx]

    def _cycle_map(self, _event):
        _sfx().play("menu_click")
        self._map_idx = (self._map_idx + 1) % len(self._map_options)
        self._map_btn.text = self._map_options[self._map_idx]

    def _on_start(self, _event):
        """Write chosen settings into the window and switch to GameView."""
        _sfx().play("select")
        win: arcade.Window = self.window
        mode_map = {0: "pvp", 1: "pve", 2: "ai_vs_ai"}
        diff_map = {0: "easy", 1: "medium", 2: "hard"}
        map_map  = {0: "standard", 1: "open", 2: "fortress"}

        win.game_settings["game_mode"]     = mode_map[self._mode_idx]
        win.game_settings["ai_difficulty"] = diff_map[self._diff_idx]
        win.game_settings["map_type"]      = map_map[self._map_idx]

        win.show_game()

    def _on_settings(self, _event):
        _sfx().play("menu_click")
        self.window.show_settings()

    def _on_quit(self, _event):
        arcade.exit()

    # ------------------------------------------------------------------
    # View lifecycle
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
        # Phase 10: Animated glow title drawn ON TOP of UI
        self._draw_title_glow()

    def _draw_title_glow(self):
        """Draw a pulsing gold glow behind the title text."""
        cx = SCREEN_WIDTH // 2
        cy = SCREEN_HEIGHT // 2 + 188  # approximate vertical center of title label
        pulse = 0.5 + 0.5 * math.sin(self._time * 2.0)
        alpha = int(30 + 35 * pulse)
        # Outer glow halo
        arcade.draw_lbwh_rectangle_filled(
            cx - 310, cy - 30, 620, 56,
            (200, 160, 40, alpha),
        )
        # Version label (persistent Text)
        self._txt_version.y = cy - 38
        self._txt_version.color = (120, 120, 130, int(100 + 60 * pulse))
        self._txt_version.draw()

    def on_key_press(self, key, _modifiers):
        if key == arcade.key.ESCAPE:
            arcade.exit()
        elif key == arcade.key.ENTER:
            self._on_start(None)
