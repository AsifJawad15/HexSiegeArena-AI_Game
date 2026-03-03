"""
Sound system for Hex Siege Arena  (Phase 6 + Batch 5 polish)
==============================================================
Generates procedural WAV sound-effects on first run, caches them to
``assets/sounds/``, then loads them via ``arcade.load_sound()``.

Batch 5 additions:
  • **Pitch randomization** — slight random speed variation per play
  • **Volume categories** — separate master, sfx, ui, combat sliders
  • **Cooldown gating** — minimum interval between same-sound replays

Public API
----------
``get_sound_manager()`` → singleton ``SoundManager``
``play(name)``          → convenience fire-and-forget

Sound catalogue:  laser, bomb, hit, move, pickup, select, win,
                  shield, death, menu_click, exhaust
"""

from __future__ import annotations

import io
import math
import os
import random as _rng
import struct
import time as _time
import wave
from pathlib import Path
from typing import Dict, Optional, Tuple

import arcade

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
_SOUNDS_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"
_CUSTOM_DIR = Path(__file__).resolve().parent.parent / "assets" / "custom sounds"


# ---------------------------------------------------------------------------
# Custom sound mapping: game name → relative path under _CUSTOM_DIR
# Higher-quality real audio files take priority over procedural generation.
# ---------------------------------------------------------------------------
_CUSTOM_MAP: Dict[str, str] = {
    "laser":      "mixkit-laser-cannon-shot-1678.wav",
    "bomb":       "mixkit-bomb-drop-exploding-2805.wav",
    "hit":        "mixkit-metallic-sword-strike-2160.wav",
    "death":      "mixkit-car-explosion-debris-1562.wav",
    "pickup":     "Digital_SFX_Set/powerUp4.mp3",
    "select":     "UI_SFX_Set/click2.wav",
    "menu_click": "UI_SFX_Set/mouseclick1.wav",
    "shield":     "Digital_SFX_Set/phaserUp3.mp3",
    "win":        "Digital_SFX_Set/threeTone1.mp3",
    "exhaust":    "Digital_SFX_Set/lowDown.mp3",
}


# ===================================================================
#  Procedural WAV generation (no numpy dependency)
# ===================================================================
_SAMPLE_RATE = 44100


def _pack_wav(samples: list[float], sample_rate: int = _SAMPLE_RATE) -> bytes:
    """Pack a list of float samples (-1..1) into a 16-bit mono WAV."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        raw = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        wf.writeframes(raw)
    return buf.getvalue()


def _sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def _noise() -> float:
    return _rng.uniform(-1.0, 1.0)


def _envelope_exp(t: float, decay: float) -> float:
    return math.exp(-t * decay)


# --- Individual generators ---------------------------------------------------

def _gen_laser(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.28
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        freq = 2000 - 1500 * (t / dur)
        s = _sine(freq, t) * 0.6 + _noise() * 0.15
        s *= _envelope_exp(t, 6.0)
        samples.append(s * 0.35)
    return _pack_wav(samples, sr)


def _gen_bomb(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.40
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        rumble = _sine(55, t) * 0.5 + _sine(80, t) * 0.3
        noise = _noise() * 0.4
        env = _envelope_exp(t, 7.0) * min(1.0, t * 120)
        samples.append((rumble + noise) * env * 0.50)
    return _pack_wav(samples, sr)


def _gen_hit(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.14
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        s = _sine(200, t) * 0.4 + _sine(420, t) * 0.3 + _noise() * 0.2
        s *= _envelope_exp(t, 32.0)
        samples.append(s * 0.40)
    return _pack_wav(samples, sr)


def _gen_move(sr: int = _SAMPLE_RATE) -> bytes:
    """Tank-tread rumble: low engine hum + mechanical clatter."""
    dur = 0.50
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        # Low engine rumble
        engine = _sine(60, t) * 0.30 + _sine(90, t) * 0.20
        # Mechanical clatter (higher freq pulsing)
        clatter = _sine(320, t) * 0.12 * (0.5 + 0.5 * _sine(18, t))
        # Tread noise
        tread = _noise() * 0.10 * (0.5 + 0.5 * _sine(12, t))
        # Fade-in + fade-out envelope
        env = min(1.0, t * 12.0) * max(0.0, 1.0 - (t - dur + 0.12) * 10.0)
        env = max(0.0, min(1.0, env))
        s = (engine + clatter + tread) * env
        samples.append(s * 0.40)
    return _pack_wav(samples, sr)


def _gen_pickup(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.22
    n = int(sr * dur)
    samples = []
    cum_phase = 0.0
    for i in range(n):
        t = i / sr
        freq = 400 + 700 * (t / dur)
        cum_phase += freq / sr
        s = math.sin(2 * math.pi * cum_phase)
        s += 0.25 * math.sin(4 * math.pi * cum_phase)
        env = math.sin(math.pi * t / dur)
        samples.append(s * env * 0.30)
    return _pack_wav(samples, sr)


def _gen_select(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.07
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        s = _sine(1100, t) * (1.0 - t / dur)
        samples.append(s * 0.15)
    return _pack_wav(samples, sr)


def _gen_win(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 1.0
    n = int(sr * dur)
    notes = [261.63, 329.63, 392.00, 523.25]  # C E G C'
    samples = [0.0] * n
    for k, freq in enumerate(notes):
        delay = k * 0.20
        for i in range(n):
            t = i / sr
            if t < delay:
                continue
            nt = t - delay
            samples[i] += _sine(freq, nt) * _envelope_exp(nt, 2.5) * 0.28
    mx = max(abs(s) for s in samples) or 1.0
    samples = [s / mx * 0.45 for s in samples]
    return _pack_wav(samples, sr)


def _gen_shield(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.22
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        s = _sine(1500, t) + 0.45 * _sine(2250, t)
        s *= _envelope_exp(t, 16.0)
        samples.append(s * 0.22)
    return _pack_wav(samples, sr)


def _gen_death(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.55
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        rumble = _sine(45, t) * 0.5 + _sine(70, t) * 0.3
        crackle = _noise() * 0.5
        env1 = _envelope_exp(t, 5.0) * min(1.0, t * 80)
        env2 = max(0.0, _envelope_exp(t - 0.15, 8.0)) if t > 0.15 else 0.0
        s = (rumble + crackle) * env1 + _sine(100, t) * env2 * 0.3
        samples.append(s * 0.45)
    return _pack_wav(samples, sr)


def _gen_menu_click(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.06
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        s = _sine(900, t) * _envelope_exp(t, 55.0)
        samples.append(s * 0.12)
    return _pack_wav(samples, sr)


def _gen_exhaust(sr: int = _SAMPLE_RATE) -> bytes:
    dur = 0.12
    n = int(sr * dur)
    samples = []
    for i in range(n):
        t = i / sr
        s = _noise() * 0.4 + _sine(120, t) * 0.2
        s *= _envelope_exp(t, 25.0)
        samples.append(s * 0.18)
    return _pack_wav(samples, sr)


# Registry: name → generator function
_GENERATORS: Dict[str, callable] = {
    "laser":      _gen_laser,
    "bomb":       _gen_bomb,
    "hit":        _gen_hit,
    "move":       _gen_move,
    "pickup":     _gen_pickup,
    "select":     _gen_select,
    "win":        _gen_win,
    "shield":     _gen_shield,
    "death":      _gen_death,
    "menu_click": _gen_menu_click,
    "exhaust":    _gen_exhaust,
}


# ===================================================================
#  Batch 5: Sound metadata — category, pitch range, cooldown
# ===================================================================
# Categories:  "combat"  = weapons / impacts
#              "ui"      = menu clicks, selection beeps
#              "ambient" = movement, exhaust, environment
#              "music"   = victory jingles

# (category, pitch_lo, pitch_hi, cooldown_seconds)
_SOUND_META: Dict[str, Tuple[str, float, float, float]] = {
    "laser":      ("combat",  0.92, 1.08, 0.08),
    "bomb":       ("combat",  0.90, 1.05, 0.10),
    "hit":        ("combat",  0.88, 1.12, 0.05),
    "death":      ("combat",  0.95, 1.05, 0.30),
    "move":       ("ambient", 0.93, 1.07, 0.05),
    "exhaust":    ("ambient", 0.85, 1.15, 0.02),
    "pickup":     ("ui",      0.95, 1.05, 0.10),
    "select":     ("ui",      0.96, 1.04, 0.04),
    "menu_click": ("ui",      0.97, 1.03, 0.04),
    "shield":     ("ui",      0.95, 1.05, 0.15),
    "win":        ("music",   1.00, 1.00, 1.00),
}


# ===================================================================
#  SoundManager
# ===================================================================

class SoundManager:
    """Loads / generates all game sounds and plays them via Arcade's audio."""

    def __init__(self, enabled: bool = True):
        self.enabled = enabled
        # Volume per category (0.0 – 1.0)
        self._volumes: Dict[str, float] = {
            "master":  0.60,
            "combat":  1.0,
            "ui":      0.8,
            "ambient": 0.7,
            "music":   0.9,
        }
        self._sounds: Dict[str, arcade.Sound] = {}
        self._last_play: Dict[str, float] = {}   # cooldown timestamps

        if enabled:
            self._ensure_wavs()
            self._load_all()

    # --- legacy property for backward compat ---
    @property
    def sfx_volume(self) -> float:
        return self._volumes["master"]

    @sfx_volume.setter
    def sfx_volume(self, v: float):
        self._volumes["master"] = max(0.0, min(1.0, v))

    # ------------------------------------------------------------------
    def _ensure_wavs(self):
        """Generate missing WAV files into assets/sounds/."""
        _SOUNDS_DIR.mkdir(parents=True, exist_ok=True)
        for name, gen_fn in _GENERATORS.items():
            path = _SOUNDS_DIR / f"{name}.wav"
            if not path.exists():
                wav_bytes = gen_fn()
                path.write_bytes(wav_bytes)

    def _load_all(self):
        """Load sounds: prefer custom audio files, fall back to procedural WAVs."""
        for name in _GENERATORS:
            loaded = False
            # Try custom sound first
            if name in _CUSTOM_MAP:
                custom_path = _CUSTOM_DIR / _CUSTOM_MAP[name]
                if custom_path.exists():
                    try:
                        self._sounds[name] = arcade.load_sound(str(custom_path))
                        loaded = True
                    except Exception:
                        pass
            # Fall back to procedural
            if not loaded:
                path = _SOUNDS_DIR / f"{name}.wav"
                if path.exists():
                    try:
                        self._sounds[name] = arcade.load_sound(str(path))
                    except Exception:
                        pass

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def play(self, name: str, volume: Optional[float] = None, *,
             pitch: Optional[float] = None):
        """Play a named sound effect with pitch randomization & cooldown.

        *volume* overrides the computed category volume.
        *pitch* overrides the random pitch range (1.0 = normal).
        """
        if not self.enabled:
            return
        snd = self._sounds.get(name)
        if snd is None:
            return

        # Cooldown gating
        meta = _SOUND_META.get(name, ("combat", 0.95, 1.05, 0.0))
        cat, p_lo, p_hi, cooldown = meta
        now = _time.monotonic()
        if cooldown > 0:
            last = self._last_play.get(name, 0.0)
            if now - last < cooldown:
                return
        self._last_play[name] = now

        # Volume: master × category (or explicit override)
        if volume is not None:
            vol = volume
        else:
            master = self._volumes.get("master", 0.6)
            cat_vol = self._volumes.get(cat, 1.0)
            vol = master * cat_vol

        # Pitch randomization
        spd = pitch if pitch is not None else _rng.uniform(p_lo, p_hi)

        try:
            arcade.play_sound(snd, vol, speed=spd)
        except Exception:
            pass  # audio back-end hiccup — never crash the game

    def play_layered(self, *names: str, volume: Optional[float] = None):
        """Play multiple sounds simultaneously (e.g. explosion + debris)."""
        for name in names:
            self.play(name, volume=volume)

    def set_volume(self, volume: float):
        """Set master volume (backward-compatible)."""
        self._volumes["master"] = max(0.0, min(1.0, volume))

    def set_category_volume(self, category: str, volume: float):
        """Set a specific category volume (combat, ui, ambient, music)."""
        self._volumes[category] = max(0.0, min(1.0, volume))

    def get_category_volume(self, category: str) -> float:
        return self._volumes.get(category, 1.0)

    def toggle(self) -> bool:
        """Toggle enabled state.  Returns the new state."""
        self.enabled = not self.enabled
        return self.enabled


# ===================================================================
#  Singleton
# ===================================================================
_instance: Optional[SoundManager] = None


def get_sound_manager() -> SoundManager:
    global _instance
    if _instance is None:
        _instance = SoundManager()
    return _instance


def play(name: str, volume: Optional[float] = None):
    """Convenience — fire-and-forget a sound by name."""
    get_sound_manager().play(name, volume)
