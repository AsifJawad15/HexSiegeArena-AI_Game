"""
Hex Siege Arena — Game Over View
Shows the winner (or draw), detailed match stats, lifetime record,
then lets the player restart or return to menu.
Decorative animated hex background with styled buttons.
"""

from __future__ import annotations

import arcade
import arcade.gui

from ..app import SCREEN_WIDTH, SCREEN_HEIGHT, FONT_NAME
from ..sounds import get_sound_manager as _sfx
from ..stats import get_stats as _sts
from ..ui import HexBackground, StyledButton


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------
BG_COLOR = (14, 18, 24)
GOLD     = (220, 180, 50)
SILVER   = (180, 180, 200)
RED_TINT = (255, 60, 60)
STAT_COL = (140, 170, 210)
MUTED    = (120, 120, 135)


class GameOverView(arcade.View):
    """Post-game screen with winner display, match stats, and navigation."""

    def __init__(self, winner: int | None = None, reason: str = "",
                 turns: int = 0, stats: dict | None = None,
                 match_stats: dict | None = None):
        super().__init__()
        self.winner = winner
        self.reason = reason
        self.turns = turns
        self.stats = stats or {}
        self.match_stats = match_stats or {}  # per-player game-session stats
        self.ui = arcade.gui.UIManager()
        self._hex_bg = HexBackground(SCREEN_WIDTH, SCREEN_HEIGHT)

        self._build_ui()

    # ------------------------------------------------------------------
    # UI
    # ------------------------------------------------------------------
    def _build_ui(self):
        self.ui.clear()
        vbox = arcade.gui.UIBoxLayout(space_between=16)

        # Main result text
        if self.winner:
            result = f"PLAYER {self.winner} WINS!"
            color = GOLD
        else:
            result = "DRAW"
            color = SILVER

        result_label = arcade.gui.UILabel(
            text=result,
            font_name=FONT_NAME, font_size=44,
            text_color=color, align="center", width=700, bold=True,
        )
        vbox.add(result_label)

        # Reason
        if self.reason:
            reason_label = arcade.gui.UILabel(
                text=self.reason,
                font_name=FONT_NAME, font_size=17,
                text_color=arcade.color.LIGHT_GRAY,
                align="center", width=700,
            )
            vbox.add(reason_label)

        # Turn count
        if self.turns > 0:
            turns_label = arcade.gui.UILabel(
                text=f"Game lasted {self.turns} turns",
                font_name=FONT_NAME, font_size=13,
                text_color=(140, 140, 155), align="center", width=700,
            )
            vbox.add(turns_label)

        # Tank stats summary
        if self.stats:
            stat_lines = []
            for key, info in self.stats.items():
                alive = "Alive" if info.get("alive") else "Destroyed"
                hp = info.get("hp", 0)
                mhp = info.get("max_hp", 0)
                stat_lines.append(f"{key}: {hp}/{mhp} HP ({alive})")
            stat_text = "   |   ".join(stat_lines)
            stat_label = arcade.gui.UILabel(
                text=stat_text,
                font_name=FONT_NAME, font_size=12,
                text_color=(130, 130, 145), align="center", width=800,
            )
            vbox.add(stat_label)

        # ── Match performance stats ──────────────────────────────────
        ms = self.match_stats
        if ms:
            vbox.add(arcade.gui.UISpace(height=6))
            perf_title = arcade.gui.UILabel(
                text="\u2694  MATCH PERFORMANCE",
                font_name=FONT_NAME, font_size=14,
                text_color=GOLD, align="center", width=700,
            )
            vbox.add(perf_title)

            for pl in [1, 2]:
                pk = f"p{pl}"
                pd = ms.get(pk, {})
                dmg = pd.get("damage_dealt", 0)
                moves = pd.get("moves", 0)
                attacks = pd.get("attacks", 0)
                blocks = pd.get("blocks_destroyed", 0)
                pickups = pd.get("pickups", 0)
                line = (
                    f"P{pl}:  {dmg} dmg  |  "
                    f"{moves} moves  |  {attacks} atks  |  "
                    f"{blocks} blocks  |  {pickups} pickups"
                )
                pc = (100, 180, 255) if pl == 1 else (255, 100, 100)
                pl_label = arcade.gui.UILabel(
                    text=line,
                    font_name=FONT_NAME, font_size=12,
                    text_color=pc, align="center", width=700,
                )
                vbox.add(pl_label)

        # ── Lifetime record ──────────────────────────────────────────
        vbox.add(arcade.gui.UISpace(height=6))
        sts = _sts()
        record_text = sts.summary_line()
        record_label = arcade.gui.UILabel(
            text=f"\u2605  {record_text}",
            font_name=FONT_NAME, font_size=12,
            text_color=MUTED, align="center", width=700,
        )
        vbox.add(record_label)

        vbox.add(arcade.gui.UISpace(height=14))

        # ── Buttons ──────────────────────────────────────────────────
        again_btn = StyledButton(text="PLAY AGAIN", width=300, height=50, accent=True)
        again_btn.on_click = self._on_play_again
        vbox.add(again_btn)

        menu_btn = StyledButton(text="MAIN MENU", width=300, height=44)
        menu_btn.on_click = self._on_menu
        vbox.add(menu_btn)

        quit_btn = StyledButton(text="QUIT", width=300, height=40)
        quit_btn.on_click = self._on_quit
        vbox.add(quit_btn)

        anchor = arcade.gui.UIAnchorLayout()
        anchor.add(child=vbox, anchor_x="center_x", anchor_y="center_y")
        self.ui.add(anchor)

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------
    def _on_play_again(self, _event):
        _sfx().play("menu_click")
        self.window.show_game()

    def _on_menu(self, _event):
        _sfx().play("menu_click")
        self.window.show_menu()

    def _on_quit(self, _event):
        arcade.exit()

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def on_show_view(self):
        arcade.set_background_color(BG_COLOR)
        self.ui.enable()
        if self.winner:
            _sfx().play("win")
        else:
            _sfx().play("shield")

    def on_hide_view(self):
        self.ui.disable()

    def on_update(self, delta_time: float):
        self._hex_bg.update(delta_time)

    def on_draw(self):
        self.clear()
        self._hex_bg.draw()
        self.ui.draw()

    def on_key_press(self, key, _modifiers):
        if key == arcade.key.ENTER:
            self._on_play_again(None)
        elif key == arcade.key.ESCAPE:
            self._on_menu(None)
