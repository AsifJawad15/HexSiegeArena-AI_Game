# Prompt for NotebookLLM to Generate a PowerPoint Presentation

**Role**: You are an expert presentation designer and technical communicator.
**Task**: Create a detailed outline and content structure for a 15-slide PowerPoint presentation about the game "Hex Siege Arena".
**Goal**: The presentation should explain the game's mechanics, rules, AI implementation, and technical workflow to a technical audience.

Please generate the content for each slide following the structure below. For each slide, provide:
1.  **Title**
2.  **Key Bullet Points** (What to write on the slide)
3.  **Speaker Notes / Detailed Explanation** (Elaborating on the points)
4.  **Visual Suggestion** (What image/diagram would fit best)

---

## Slide 1: Title Slide
- **Title**: Hex Siege Arena: a Tactical Strategy Game
- **Subtitle**: A Fusion of Chess & Bomberman mechanics on a Hexagonal Grid
- **Content**:
    - Presenters Name
    - Date
- **Visual**: A high-quality screenshot of the game board with tanks stationed.

## Slide 2: Introduction & Concept
- **Title**: What is Hex Siege Arena?
- **Key Points**:
    - **Genre**: Deterministic, turn-based strategy game.
    - **Inspiration**: Combines the tactical positioning of Chess with the area-control mechanics of Bomberman.
    - **Format**: 1v1 Zero-Sum game.
    - **Platform**: Built with Python and Pygame.
- **Details**: Explain that the game removes luck (dice rolls) in favor of pure strategy. It uses a unique hexagonal grid which offers 6 degrees of movement freedom compared to the 4/8 on square grids.

## Slide 3: The Battlefield (The Board)
- **Title**: The Hexagonal Grid
- **Key Points**:
    - **Structure**: 5-ring hexagonal board (91 total cells).
    - **Terrain Types**:
        - **Empty**: Walkable.
        - **Walls**: Indestructible obstacles.
        - **Blocks**: Destructible obstacles (Normal, Armor, Power).
        - **Center**: The objective tile.
    - **Effects**: Obstacles block movement and laser lines of sight.
- **Visual**: A diagram labeling the clear paths, walls, and the central objective.

## Slide 4: The Units - Part 1 (Queen Tank)
- **Title**: Queen Tank (The Sniper)
- **Key Points**:
    - **Role**: High mobility, long-range striker.
    - **HP**: 8 Hit Points.
    - **Movement**: Unlimited distance in a straight line (like a Rook/Queen in Chess).
    - **Attack**: **Laser Cannon**.
        - Instant hit in a straight line.
        - Damage: 2 HP.
        - Stopped by the first obstacle or unit hit.
- **Visual**: Diagram showing the 6 directional rays of movement/attack for the Queen.

## Slide 5: The Units - Part 2 (King Tank)
- **Title**: King Tank (The VIP)
- **Key Points**:
    - **Role**: The Objective leader and Area controller.
    - **HP**: 10 Hit Points.
    - **Movement**: Limited range (up to 2 tiles per turn).
    - **Attack**: **Mortar Bomb**.
        - Damage: 3 HP.
        - **Area of Effect (AOE)**: Hits the target tile AND all 6 surrounding neighbors.
        - Can destroy multiple blocks or damage multiple units at once.
- **Visual**: Diagram highlighting the King's movement range and the Bomb's explosion radius (flower shape).

## Slide 6: Player Actions
- **Title**: Turn-Based Actions
- **Key Points**:
    - **One Action Per Turn** (unless buffed).
    - Available Actions:
        1.  **Move**: Reposition a tank.
        2.  **Attack**: Fire Laser (Queen) or Launch Bomb (King).
        3.  **Pass**: Skip turn (rarely used strategically).
    - **Cooldowns**: Attacks consume current buffs but have no innate cooldown in the base rules (check specific implementation).
- **Details**: Explain the trade-off between moving to safety vs. attacking to apply pressure.

## Slide 7: Power-Ups & Buffs
- **Title**: Strategic Power Tiles
- **Key Points**:
    - Hidden inside **Power Blocks**. Revealed when destroyed.
    - **Types**:
        - **Double Damage (Red)**: Next attack deals 2x damage.
        - **Shield (Blue)**: Blocks the next 2 damage instances.
        - **Bonus Move (Green)**: Grants extra tactical options.
    - **Mechanic**: Picked up automatically by moving onto the tile.
- **Visual**: Icons of the three power-ups next to destroyed blocks.

## Slide 8: Win Conditions
- **Title**: How to Win
- **Key Points**:
    - **Condition 1: Checkmate (Elimination)**
        - Destroy the opponent's **King Tank**.
        - Queen death does not end the game (but is a huge disadvantage).
    - **Condition 2: Capture the Flag (Domination)**
        - Move your **King Tank** to the exact **Center Tile** of the board.
    - **Draw Conditions**:
        - Max turn limit reached.
        - Threefold repetition of the board state.
- **Details**: This dual-win condition forces players to balance offense (hunting the enemy King) with defense (protecting the center).

## Slide 9: AI Agent Overview
- **Title**: The Artificial Intelligence
- **Key Points**:
    - **Type**: Minimax Algorithm.
    - **Optimization**: Alpha-Beta Pruning.
        - Eliminates branches that cannot influence the final decision.
    - **Performance**:
        - Uses **Iterative Deepening** to find the best move within a time limit (e.g., 5 seconds).
        - Uses **Transposition Tables** to cache and reuse previous board evaluations.
- **Visual**: A simple decision tree diagram showing pruning (cutting off branches).

## Slide 10: AI Decision Making (Heuristics)
- **Title**: Evaluation Function
- **Key Points**:
    - How the AI values a board state (Score calculation).
    - **Positive Weights (+)**:
        - Destroying enemy King (+1000).
        - Keeping own King/Queen alive.
        - High HP.
        - Acquiring Buffs (+25).
    - **Negative Weights (-)**:
        - Distance to Center (AI wants to be close uses negative distance).
        - Danger to own King.
- **Details**: The AI calculates a single number representing "How good is this position for me?".

## Slide 11: AI Search Enhancements
- **Title**: Advanced Search Techniques
- **Key Points**:
    - **Move Ordering**:
        - The AI doesn't check moves randomly.
        - Validates "promising" moves first (e.g., attacks, winning moves).
        - drastically improves Alpha-Beta pruning efficiency.
    - **Zobrist Hashing**:
        - Unique hash for every board configuration.
        - Used for fast lookups in the Transposition Table.
    - **Quiescence Search** (Optional/Advanced):
        - Mitigates the "Horizon Effect" by searching deeper during volatile positions (e.g., midst of combat).

## Slide 12: Technical Architecture
- **Title**: Code Structure
- **Key Points**:
    - **Logic Separation**: MVC-inspired pattern.
        - `game_state.py`: The Source of Truth. Handles rules, state updates, validation.
        - `renderer.py`: Handles Pygame drawing, animations, assets.
        - `ai.py`: Pure logic agent, stateless between turns.
    - **Coordinate System**:
        - Uses **Axial Coordinates (q, r)** instead of Cartesian (x, y).
        - Makes adjacency math on hex grids simple `(dist = (|dq| + |dr| + |dq+dr|)/2)`.
- **Visual**: Class collaboration diagram or file structure tree.

## Slide 13: Game Loop Workflow
- **Title**: The Game Loop
- **Key Points**:
    1.  **Input Phase**: Player clicks or AI chooses move.
    2.  **Validation**: `get_legal_actions()` checks if move is valid.
    3.  **Update Phase**: `apply_action()` creates new state, checks collisions/damage.
    4.  **Event Handling**: Triggers animations (explosions, lasers) and sounds.
    5.  **Render**: Draws the frame (60 FPS).
    6.  **Win Check**: Checks `is_terminal()`.

## Slide 14: Future Improvements
- **Title**: Future Work
- **Key Points**:
    - **Networking**: Multiplayer over LAN/Internet.
    - **Advanced AI**: Neural Networks / Reinforcement Learning integration.
    - **More Units**: Adding "Knight" or "Pawn" tank variants.
    - **Dynamic Maps**: Procedural map generation for infinite replayability.

## Slide 15: Q&A / Thank You
- **Title**: Thank You
- **Content**:
    - "Strategy is buying a bottle of fine wine. Tactics is getting someone to drink it with you." - X. Tartakover
    - Questions?
- **Visual**: Game Logo or Credits.
