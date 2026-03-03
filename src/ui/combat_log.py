"""
Hex Siege Arena — Combat Log Panel  (Phase 9)
A scrolling event feed that displays game actions as they happen.
Rendered as a translucent right-side panel with coloured text lines.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import List, Tuple

import arcade

from ..app import FONT_NAME


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
LOG_WIDTH = 265
LOG_LINE_H = 18
MAX_LINES = 40          # keep in memory
VISIBLE_LINES = 18      # drawn at once
PANEL_ALPHA = 190
FADE_DURATION = 4.0     # seconds before old entries start dimming
BG_COLOR = (16, 20, 28, PANEL_ALPHA)
BORDER_COLOR = (60, 70, 85, 160)

# Player colours
_P_COLORS = {
    1: (100, 180, 255),
    2: (255, 100, 100),
}
_NEUTRAL = (180, 180, 190)
_BUFF_COL = (100, 255, 140)
_DMG_COL = (255, 180, 60)
_KILL_COL = (255, 60, 60)
_WIN_COL = (255, 220, 60)


@dataclass
class LogEntry:
    """One line in the combat log."""
    text: str
    color: Tuple[int, int, int]
    timestamp: float = field(default_factory=time.time)
    _text_obj: arcade.Text | None = field(default=None, repr=False)


class CombatLog:
    """
    Scrolling combat-log panel drawn on the right side of the screen.

    Usage::

        log = CombatLog(screen_w, screen_h, hud_h)
        log.add("P1 Queen moved NE", color=(100, 180, 255))
        # in on_draw (screen-space):
        log.draw()
    """

    def __init__(self, screen_w: int, screen_h: int, hud_h: int = 80):
        self._entries: List[LogEntry] = []
        self._screen_w = screen_w
        self._screen_h = screen_h
        self._hud_h = hud_h
        self._scroll_offset: int = 0   # how many entries to skip (scrolled up)
        # Panel position (top-right, below HUD)
        self._panel_x = screen_w - LOG_WIDTH - 10
        self._panel_top = screen_h - hud_h - 8
        self._panel_h = VISIBLE_LINES * LOG_LINE_H + 12

        # Title text
        self._title = arcade.Text(
            "\u2694 Combat Log",
            self._panel_x + LOG_WIDTH // 2,
            self._panel_top - 4,
            color=(200, 180, 100),
            font_size=12,
            anchor_x="center",
            anchor_y="top",
            bold=True,
            font_name=FONT_NAME,
        )
        # Scroll indicator texts (persistent to avoid PerformanceWarning)
        self._txt_scroll_up = arcade.Text(
            "\u25B2 newer", self._panel_x + LOG_WIDTH // 2, self._panel_top - 18,
            color=(120, 120, 130, 160), font_size=9, anchor_x="center", font_name=FONT_NAME,
        )
        self._txt_scroll_dn = arcade.Text(
            "\u25BC older", self._panel_x + LOG_WIDTH // 2, 0,
            color=(120, 120, 130, 160), font_size=9, anchor_x="center", font_name=FONT_NAME,
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def add(self, text: str, color: Tuple[int, int, int] = _NEUTRAL):
        """Append a new log entry (newest at top)."""
        entry = LogEntry(text=text, color=color)
        self._entries.insert(0, entry)  # newest first
        if len(self._entries) > MAX_LINES:
            self._entries.pop()
        # Invalidate cached Text objects (positions shift)
        for e in self._entries:
            e._text_obj = None
        # Auto-scroll back to newest when new entries arrive
        self._scroll_offset = 0

    def clear(self):
        self._entries.clear()
        self._scroll_offset = 0

    def scroll(self, direction: int):
        """Scroll the log. direction > 0 scrolls up (older), < 0 scrolls down (newer)."""
        self._scroll_offset = max(0, min(
            self._scroll_offset + direction,
            max(0, len(self._entries) - VISIBLE_LINES),
        ))
        # Invalidate text object positions
        for e in self._entries:
            e._text_obj = None

    def add_turn_separator(self, turn: int, player: int):
        """Insert a subtle separator line marking a new turn."""
        col = (80, 80, 90)
        self.add(f"\u2500\u2500 Turn {turn}  P{player} \u2500\u2500", col)

    def add_events(self, events: list, current_turn: int = 0):
        """
        Parse a list of GameEvent objects into readable log messages.
        Called after each action is applied.
        """
        for ev in events:
            t = ev.event_type
            d = ev.data

            if t == "move":
                pl = d.get("player", "?")
                tank = d.get("tank", "?")
                name = "King" if "KTANK" in str(tank) else "Queen"
                col = _P_COLORS.get(pl, _NEUTRAL)
                self.add(f"P{pl} {name} moved", col)

            elif t == "pass":
                pl = d.get("player", "?")
                col = _P_COLORS.get(pl, _NEUTRAL)
                self.add(f"P{pl} passed turn", col)

            elif t == "laser_hit_tank":
                tp = d.get("target_player", "?")
                tn = d.get("target", "?")
                name = "King" if "KTANK" in str(tn) else "Queen"
                dmg = d.get("damage", 0)
                blocked = d.get("blocked", False)
                if blocked:
                    self.add(f"  \u2192 P{tp} {name} blocked!", _BUFF_COL)
                else:
                    self.add(f"  \u2192 P{tp} {name} hit! -{dmg} HP", _DMG_COL)

            elif t == "laser_hit_block":
                destroyed = d.get("destroyed", False)
                revealed = d.get("revealed")
                if destroyed:
                    msg = "  \u2192 Block destroyed"
                    if revealed:
                        msg += f" [{revealed}]"
                    self.add(msg, _NEUTRAL)

            elif t == "bomb_hit_tank":
                tp = d.get("target_player", "?")
                tn = d.get("target", "?")
                name = "King" if "KTANK" in str(tn) else "Queen"
                dmg = d.get("damage", 0)
                blocked = d.get("blocked", False)
                if blocked:
                    self.add(f"  \u2192 P{tp} {name} blocked!", _BUFF_COL)
                else:
                    self.add(f"  \u2192 P{tp} {name} hit! -{dmg} HP", _DMG_COL)

            elif t == "bomb_hit_block":
                destroyed = d.get("destroyed", False)
                revealed = d.get("revealed")
                if destroyed:
                    msg = "  \u2192 Block destroyed"
                    if revealed:
                        msg += f" [{revealed}]"
                    self.add(msg, _NEUTRAL)

            elif t == "laser_start":
                pl = d.get("player", "?")
                col = _P_COLORS.get(pl, _NEUTRAL)
                self.add(f"P{pl} Queen fires laser!", col)

            elif t == "bomb_start":
                pl = d.get("player", "?")
                col = _P_COLORS.get(pl, _NEUTRAL)
                self.add(f"P{pl} King drops bomb!", col)

            elif t == "buff":
                tn = d.get("tank", "?")
                name = "King" if "KTANK" in str(tn) else "Queen"
                buff = d.get("buff", "?")
                label = buff.replace("_", " ").title()
                self.add(f"  \u2605 {name} got {label}", _BUFF_COL)

            elif t == "bonus_move":
                tn = d.get("tank", "?")
                name = "King" if "KTANK" in str(tn) else "Queen"
                self.add(f"  \u2605 {name} got Bonus Move!", _BUFF_COL)

            elif t == "win_kill":
                pl = d.get("player", "?")
                killed = d.get("killed", "?")
                self.add(f"\u2620 P{pl} destroyed P{killed}'s King!", _KILL_COL)

            elif t == "win_center":
                pl = d.get("player", "?")
                self.add(f"\u2605 P{pl} King captured the centre!", _WIN_COL)

            elif t == "draw":
                self.add("Game ended in a draw", _NEUTRAL)

    # ------------------------------------------------------------------
    # Drawing
    # ------------------------------------------------------------------
    def draw(self):
        """Draw the log panel (call in screen-space, after default_camera.use())."""
        px = self._panel_x
        py = self._panel_top - self._panel_h

        # Background
        arcade.draw_lbwh_rectangle_filled(px, py, LOG_WIDTH, self._panel_h, BG_COLOR)
        arcade.draw_lbwh_rectangle_outline(px, py, LOG_WIDTH, self._panel_h, BORDER_COLOR, 1)

        # Title
        self._title.draw()

        # Log entries (newest at top, with scroll offset)
        now = time.time()
        y = self._panel_top - 24  # below title
        start = self._scroll_offset
        visible = self._entries[start:start + VISIBLE_LINES]
        for i, entry in enumerate(visible):
            age = now - entry.timestamp
            # Fade old entries
            alpha = 255
            if age > FADE_DURATION:
                alpha = max(60, int(255 - (age - FADE_DURATION) * 30))

            if entry._text_obj is None:
                entry._text_obj = arcade.Text(
                    entry.text,
                    px + 8, y,
                    color=(*entry.color, alpha),
                    font_size=11,
                    anchor_y="top",
                    font_name=FONT_NAME,
                )
            else:
                entry._text_obj.y = y
                entry._text_obj.color = (*entry.color, alpha)

            entry._text_obj.draw()
            y -= LOG_LINE_H

        # Scroll indicators
        if self._scroll_offset > 0:
            self._txt_scroll_up.draw()
        if start + VISIBLE_LINES < len(self._entries):
            self._txt_scroll_dn.y = py + 4
            self._txt_scroll_dn.draw()
