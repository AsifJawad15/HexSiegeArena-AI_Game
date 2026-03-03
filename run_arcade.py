#!/usr/bin/env python
"""
Hex Siege Arena — Arcade Edition Launcher
Run this file to start the game:
    python run_arcade.py
"""

import sys
from pathlib import Path

# Ensure project root is on sys.path so `src` is importable
project_root = str(Path(__file__).resolve().parent)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from src.app import run

if __name__ == "__main__":
    run()
