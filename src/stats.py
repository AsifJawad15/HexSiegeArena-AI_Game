"""
Hex Siege Arena — Persistent Game Statistics
=============================================
Tracks wins, losses, draws and other lifetime stats, persisted to
``assets/stats.json``.  Accessed via ``get_stats()`` singleton.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

# ---------------------------------------------------------------------------
_STATS_PATH = Path(__file__).resolve().parent.parent / "assets" / "stats.json"

_DEFAULTS: Dict[str, Any] = {
    "games_played":       0,
    "p1_wins":            0,
    "p2_wins":            0,
    "draws":              0,
    "total_turns":        0,
    "fastest_win":        0,    # fewest turns to a win (0 = no data)
    "longest_game":       0,
    "current_streak_p1":  0,
    "current_streak_p2":  0,
    "best_streak":        0,
    "last_winner":        0,    # 0 = draw/none, 1 or 2
    "last_played":        "",
}


class GameStats:
    """Lifetime statistics tracker backed by JSON."""

    def __init__(self) -> None:
        self._data: Dict[str, Any] = dict(_DEFAULTS)
        self._load()

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------
    def _load(self) -> None:
        if not _STATS_PATH.exists():
            return
        try:
            with open(_STATS_PATH, encoding="utf-8") as fh:
                saved = json.load(fh)
            for key, val in saved.items():
                if key in _DEFAULTS:
                    self._data[key] = val
        except Exception:
            pass

    def save(self) -> None:
        _STATS_PATH.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(_STATS_PATH, "w", encoding="utf-8") as fh:
                json.dump(self._data, fh, indent=2)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Recording
    # ------------------------------------------------------------------
    def record_game(self, winner: Optional[int], turns: int) -> None:
        """Record the outcome of a completed game."""
        self._data["games_played"] += 1
        self._data["total_turns"] += turns

        if turns > self._data["longest_game"]:
            self._data["longest_game"] = turns

        if winner == 1:
            self._data["p1_wins"] += 1
            self._data["current_streak_p1"] += 1
            self._data["current_streak_p2"] = 0
        elif winner == 2:
            self._data["p2_wins"] += 1
            self._data["current_streak_p2"] += 1
            self._data["current_streak_p1"] = 0
        else:
            self._data["draws"] += 1
            self._data["current_streak_p1"] = 0
            self._data["current_streak_p2"] = 0

        if winner and (self._data["fastest_win"] == 0
                       or turns < self._data["fastest_win"]):
            self._data["fastest_win"] = turns

        best = max(self._data["current_streak_p1"],
                   self._data["current_streak_p2"])
        if best > self._data["best_streak"]:
            self._data["best_streak"] = best

        self._data["last_winner"] = winner or 0
        self._data["last_played"] = datetime.now().isoformat(timespec="seconds")
        self.save()

    # ------------------------------------------------------------------
    # Read helpers
    # ------------------------------------------------------------------
    def get(self, key: str) -> Any:
        return self._data.get(key, 0)

    @property
    def games_played(self) -> int:
        return self._data["games_played"]

    @property
    def p1_wins(self) -> int:
        return self._data["p1_wins"]

    @property
    def p2_wins(self) -> int:
        return self._data["p2_wins"]

    @property
    def draws(self) -> int:
        return self._data["draws"]

    @property
    def avg_turns(self) -> float:
        gp = self._data["games_played"]
        return self._data["total_turns"] / gp if gp > 0 else 0.0

    @property
    def fastest_win(self) -> int:
        return self._data["fastest_win"]

    @property
    def longest_game(self) -> int:
        return self._data["longest_game"]

    @property
    def best_streak(self) -> int:
        return self._data["best_streak"]

    def summary_line(self) -> str:
        """One-line summary for display on the menu."""
        gp = self.games_played
        if gp == 0:
            return "No games played yet"
        return (
            f"Games: {gp}  |  P1 wins: {self.p1_wins}  |  "
            f"P2 wins: {self.p2_wins}  |  Draws: {self.draws}"
        )

    def detail_lines(self) -> list[str]:
        """Multi-line stats for a detail view."""
        gp = self.games_played
        if gp == 0:
            return ["No games played yet"]
        lines = [
            f"Games Played: {gp}",
            f"Player 1 Wins: {self.p1_wins}",
            f"Player 2 Wins: {self.p2_wins}",
            f"Draws: {self.draws}",
            f"Avg Game Length: {self.avg_turns:.1f} turns",
        ]
        if self.fastest_win > 0:
            lines.append(f"Fastest Win: {self.fastest_win} turns")
        if self.longest_game > 0:
            lines.append(f"Longest Game: {self.longest_game} turns")
        if self.best_streak > 0:
            lines.append(f"Best Win Streak: {self.best_streak}")
        return lines


# ===================================================================
#  Singleton
# ===================================================================
_instance: GameStats | None = None


def get_stats() -> GameStats:
    global _instance
    if _instance is None:
        _instance = GameStats()
    return _instance
