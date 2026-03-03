# Hex Siege Arena 🎮

A turn-based tactical strategy game inspired by **Chess × Bomberman**.

![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)
![Pygame](https://img.shields.io/badge/Pygame-2.5+-green.svg)

## 🎯 Overview

Hex Siege Arena is a deterministic, two-player strategy game played on a hexagonal grid. Each player controls two asymmetric tanks and competes to either reach the center of the board with their King tank or destroy the opponent's King tank.

## ✨ Features

- **Hexagonal Grid**: 5-ring board (91 cells) with strategic terrain
- **Asymmetric Units**: Queen Tank (laser) and King Tank (bomb)
- **Power Tiles**: Attack boost, Shield, and Bonus Move
- **AI Opponent**: Minimax with Alpha-Beta pruning
- **Professional UI**: 3D effects, animations, and particles
- **Sound Effects**: Procedurally generated audio

## 🚀 Quick Start

### Installation

```bash
# Clone or download the project
cd "Hex siege arena"

# Install dependencies
pip install -r requirements.txt
```

### Running the Game

```bash
# Option 1: Run directly
python run_game.py

# Option 2: Run as module
python -m src
```

## 🎮 Controls

| Key | Action |
|-----|--------|
| **Click** | Select tank / Choose target |
| **1** | Select Queen Tank |
| **2** | Select King Tank |
| **M** | Move mode |
| **A** | Attack mode |
| **P** | Pass turn |
| **R** | Restart game |
| **SPACE** | Toggle sound |
| **ESC** | Quit |

## 🏆 Win Conditions

1. **Center Control**: Move your King Tank to the center cell
2. **King Kill**: Destroy the opponent's King Tank

## 🎖️ Units

### Queen Tank (Q)
- **HP**: 8
- **Movement**: Unlimited in straight line (like chess queen)
- **Attack**: Laser - 2 damage, travels until first collision

### King Tank (K)
- **HP**: 10
- **Movement**: Up to 2 cells in straight line
- **Attack**: Bomb - 3 damage to all 6 adjacent cells
- **Special**: Reaching center wins the game!

## ⚡ Power Tiles

| Tile | Effect |
|------|--------|
| ⚔️ **Attack ×2** | Next attack deals double damage |
| 🛡️ **Shield** | Blocks next 2 damage instances |
| ➤ **Bonus Move** | Grants immediate extra move |

## 🤖 AI System

The game features a Minimax AI with:
- Alpha-Beta pruning for efficiency
- Transposition table for caching
- Iterative deepening for time management
- Heuristic evaluation considering:
  - Tank HP differences
  - Distance to center
  - Power tile advantages
  - Attack threats

### AI Difficulty Levels
- **Easy**: Depth 2, 1s time limit
- **Medium**: Depth 4, 3s time limit  
- **Hard**: Depth 6, 5s time limit

## 📁 Project Structure

```
Hex siege arena/
├── src/
│   ├── __init__.py      # Package initialization
│   ├── __main__.py      # Module runner
│   ├── hex_coord.py     # Hex coordinate system
│   ├── board.py         # Board representation
│   ├── tank.py          # Tank classes
│   ├── game_state.py    # Game logic
│   ├── ai.py            # Minimax AI
│   ├── renderer.py      # Pygame UI
│   ├── sounds.py        # Sound system
│   └── main.py          # Main entry point
├── run_game.py          # Quick start script
├── requirements.txt     # Dependencies
└── README.md            # This file
```

## 🎨 Design Philosophy

- **Deterministic**: No randomness - pure strategy
- **Asymmetric**: Each tank has unique strengths
- **Tactical Depth**: Positioning and timing matter
- **Chess-like**: One tank, one action per turn
- **AI-Ready**: Perfect for Minimax research

## 📝 Game Rules

### Turn Structure
1. Select one of your tanks
2. Choose ONE action:
   - **Move**: Reposition the tank
   - **Attack**: Fire laser or bomb
   - **Pass**: End turn without action

### Combat
- Friendly fire is ON
- Damage applies immediately
- Destroyed units are removed instantly
- Shield blocks damage instances (not amounts)

### Board Elements
- **Walls**: Indestructible, block movement and attacks
- **Blocks**: Destructible (2-3 HP), block movement
- **Power Blocks**: Drop power tiles when destroyed
- **Center**: Golden cell - King reaching here wins!

## 🔧 Customization

Edit `src/main.py` to change:
```python
self.game_mode = GameMode.PVE  # PVP, PVE, or AI_VS_AI
self.ai_difficulty = "medium"   # easy, medium, hard
self.map_type = "standard"      # standard, open, fortress
```

## 📄 License

MIT License - Feel free to use for learning and research!

---

**Enjoy the game! May the best strategist win! ⬡**
