"""
Hex Siege Arena — Custom Styled UI Widgets
Replaces bland UIFlatButton with military-themed styled buttons.
"""

from __future__ import annotations

from typing import Tuple

import arcade
import arcade.gui
from arcade.gui.widgets.buttons import UIFlatButtonStyle


# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
GOLD        = (200, 160, 60, 255)
GOLD_DIM    = (140, 110, 40, 255)
DARK_BG     = (25, 32, 42, 255)
HOVER_BG    = (40, 52, 68, 255)
PRESS_BG    = (55, 70, 90, 255)
ACCENT_BLUE = (80, 160, 255, 255)
BORDER      = (80, 90, 100, 255)
BORDER_GOLD = (200, 160, 60, 255)
TEXT_WHITE   = (230, 230, 235, 255)
DISABLED_FG = (120, 120, 130, 255)
DISABLED_BG = (35, 40, 50, 255)

_FONT = ("Orbitron", "Kenney Future", "arial", "calibri")


class StyledButton(arcade.gui.UIFlatButton):
    """A flat button with custom military-theme colours and a gold border."""

    def __init__(
        self,
        text: str = "",
        *,
        width: float = 300,
        height: float = 50,
        accent: bool = False,
        font_size: int = 18,
    ):
        fc = GOLD if accent else TEXT_WHITE
        bc = BORDER_GOLD if accent else BORDER
        bw = 2 if accent else 1
        style = {
            "normal": UIFlatButtonStyle(
                font_size=font_size, font_name=_FONT,
                font_color=fc, bg=DARK_BG, border=bc, border_width=bw,
            ),
            "hover": UIFlatButtonStyle(
                font_size=font_size, font_name=_FONT,
                font_color=arcade.color.WHITE, bg=HOVER_BG,
                border=GOLD if accent else (120, 130, 140, 255),
                border_width=bw,
            ),
            "press": UIFlatButtonStyle(
                font_size=font_size, font_name=_FONT,
                font_color=arcade.color.WHITE, bg=PRESS_BG,
                border=GOLD, border_width=bw,
            ),
            "disabled": UIFlatButtonStyle(
                font_size=font_size, font_name=_FONT,
                font_color=DISABLED_FG, bg=DISABLED_BG,
                border=None, border_width=0,
            ),
        }
        super().__init__(text=text, width=width, height=height, style=style)


class StyledCycleButton(arcade.gui.UIFlatButton):
    """A cycle-selector button (click to advance through options)."""

    def __init__(
        self,
        text: str = "",
        *,
        width: float = 200,
        height: float = 44,
    ):
        style = {
            "normal": UIFlatButtonStyle(
                font_size=16, font_name=_FONT,
                font_color=ACCENT_BLUE,
                bg=(30, 40, 55, 255),
                border=(70, 100, 140, 255), border_width=1,
            ),
            "hover": UIFlatButtonStyle(
                font_size=16, font_name=_FONT,
                font_color=(120, 200, 255, 255),
                bg=(40, 55, 75, 255),
                border=ACCENT_BLUE, border_width=1,
            ),
            "press": UIFlatButtonStyle(
                font_size=16, font_name=_FONT,
                font_color=arcade.color.WHITE,
                bg=(50, 65, 85, 255),
                border=ACCENT_BLUE, border_width=1,
            ),
            "disabled": UIFlatButtonStyle(
                font_size=16, font_name=_FONT,
                font_color=DISABLED_FG, bg=DISABLED_BG,
                border=None, border_width=0,
            ),
        }
        super().__init__(text=text, width=width, height=height, style=style)


class TooltipLabel(arcade.gui.UILabel):
    """A small info label with a slightly tinted background."""

    def __init__(self, text: str = "", *, width: float = 280, font_size: int = 13):
        super().__init__(
            text=text,
            font_size=font_size,
            text_color=(180, 180, 190),
            width=width,
            align="center",
        )
