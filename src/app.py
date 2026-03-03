"""
Hex Siege Arena — Arcade Application
Main window and entry point for the Arcade-based game.
"""

import arcade
from pathlib import Path
from .settings import get_settings
from .stats import get_stats

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCREEN_WIDTH = 1400
SCREEN_HEIGHT = 900
SCREEN_TITLE = "Hex Siege Arena"

# Root of the project (one level up from src/)
PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Font — Orbitron sci-fi typeface (bundled TTF, variable weight)
_FONT_PATH = PROJECT_ROOT / "assets" / "fonts" / "Orbitron-Variable.ttf"
FONT_NAME = ("Orbitron", "Kenney Future", "arial", "calibri")


class HexSiegeWindow(arcade.Window):
    """
    The single arcade.Window for Hex Siege Arena.
    Manages global resources (textures, sounds) and view transitions.
    """

    def __init__(self):
        super().__init__(
            width=SCREEN_WIDTH,
            height=SCREEN_HEIGHT,
            title=SCREEN_TITLE,
            resizable=True,   # Batch 6: allow window resize
        )
        arcade.set_background_color(arcade.color.BLACK)

        # Register bundled Orbitron font
        if _FONT_PATH.exists():
            arcade.load_font(str(_FONT_PATH))

        # Shared state that persists across views
        self.game_settings = {
            "game_mode": "pve",       # "pvp" | "pve" | "ai_vs_ai"
            "ai_difficulty": "medium", # "easy" | "medium" | "hard"
            "map_type": "standard",    # "standard" | "open" | "fortress"
        }

        # Pre-load all textures so there's no hitch during gameplay
        from .assets import preload_all
        preload_all()

        # Pre-generate & load sound effects
        from .sounds import get_sound_manager
        get_sound_manager()

        # Load persistent settings & apply volume preferences
        self._settings = get_settings()
        self._settings.apply_volumes()
        self._stats = get_stats()

        # Restore last-used game options
        for k, sk in [("game_mode", "last_game_mode"),
                       ("ai_difficulty", "last_difficulty"),
                       ("map_type", "last_map")]:
            saved = self._settings.get(sk)
            if saved:
                self.game_settings[k] = saved

    # ------------------------------------------------------------------
    # View helpers
    # ------------------------------------------------------------------
    def show_menu(self):
        """Switch to the main-menu view."""
        from .views.menu_view import MenuView
        menu = MenuView()
        self.show_view(menu)

    def show_game(self):
        """Switch to the game-play view."""
        from .views.game_view import GameView
        game = GameView()
        self.show_view(game)

    def show_settings(self):
        """Switch to the settings view."""
        from .views.settings_view import SettingsView
        self.show_view(SettingsView())

    def show_game_over(self, winner: int | None, reason: str = "",
                       turns: int = 0, stats: dict | None = None,
                       match_stats: dict | None = None):
        """Switch to the game-over view."""
        # Record into lifetime stats
        self._stats.record_game(winner, turns)
        # Save last-used game options
        for k, sk in [("game_mode", "last_game_mode"),
                       ("ai_difficulty", "last_difficulty"),
                       ("map_type", "last_map")]:
            self._settings.set(sk, self.game_settings[k])
        self._settings.save()

        from .views.game_over_view import GameOverView
        over = GameOverView(winner=winner, reason=reason, turns=turns,
                            stats=stats, match_stats=match_stats)
        self.show_view(over)


# ---------------------------------------------------------------------------
# Entry-point helper
# ---------------------------------------------------------------------------
def run():
    """Create the window, show the menu, and start the Arcade event loop."""
    window = HexSiegeWindow()
    window.show_menu()
    arcade.run()
