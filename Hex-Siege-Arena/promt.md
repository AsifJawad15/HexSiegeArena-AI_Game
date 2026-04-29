# Hex Siege Arena Godot Build Brief

This document is a detailed implementation brief for rebuilding **Hex Siege Arena** in **Godot 4** with a polished, professional feel.

It is written so another developer or AI can use it as a clear roadmap.

## 1. Project Goal

Build a Godot version of **Hex Siege Arena**, a turn-based tactical game on a hex grid where:

- Each side controls a `Qtank` and a `Ktank`
- The `Ktank` can win by reaching the center
- A player can also win by destroying the opponent's `Ktank`
- The game supports **AI vs AI** as the main showcase mode
- Each side can still be set to:
  - Human
  - Minimax AI
  - MCTS AI

The project should feel clean, modern, readable, and polished enough to present to others as a strong game/AI project.

## 2. Main Design Decisions

### Engine

- Use **Godot 4 latest stable**
- Use **GDScript** unless there is a strong reason to use C#

### Main Visual Direction

- Use **2D + fake 3D**, not full 3D

### Why 2D + fake 3D is the better choice

- It keeps tactical readability high
- It is much easier to build and polish than full 3D
- It needs fewer art resources
- It is easier to debug AI and board logic
- It still allows a strong professional look with:
  - raised tiles
  - shadows
  - highlights
  - lighting
  - particles
  - camera motion
  - layered VFX

### AI Decision Rule

There must be **two main AI strategy families**:

- **Minimax AI**
  - Main strategy: adversarial search
  - Allowed optimizations: alpha-beta pruning, iterative deepening, transposition table, move ordering
- **MCTS AI**
  - Main strategy: Monte Carlo Tree Search
  - Allowed optimizations: UCT/UCB1, rollout tuning, tree reuse, pruning, caching

Important rule:

- Minimax must remain the main identity of one AI
- MCTS must remain the main identity of the other AI
- Extra optimization algorithms are allowed, but they are helpers, not the main strategy

## 3. Rules Baseline

This section locks the default rules so implementation does not drift between older notes, slides, and future ideas.

### Board Baseline

- Use a **91-cell flat-topped hex board**
- Center coordinate is `(0, 0)`
- Movement and attacks operate on **6-neighbor adjacency**
- Terrain classes:
  - empty tile
  - center tile
  - indestructible wall
  - destructible block HP 2
  - destructible armor block HP 3
  - power block HP 2 that reveals a power-up when destroyed

### Default Turn Economy

- A normal turn allows **one action only**
- Valid default actions:
  - `Move`
  - `Attack`
  - `Pass`
- A unit normally cannot move and attack in the same turn
- `Bonus Move` is the special exception that temporarily breaks this rule and grants an additional action

### Unit Rules Baseline

- `Qtank`
  - Role: sniper / spatial control
  - HP: `8`
  - Mobility: high
  - Attack: long straight-line raycast
  - Attack stops on the **first collision** with wall, block, or unit
  - Base damage: `2`
- `Ktank`
  - Role: juggernaut / high-value target
  - HP: `10`
  - Mobility: up to `2` hexes
  - Attack: area-of-effect blast centered on nearby hex pattern
  - Base damage: `3`
  - Friendly fire must be supported and evaluated by the AI

### Power-Up Baseline

- `Attack Multiplier`
  - doubles outgoing damage for the empowered attack
- `Shield Buffer`
  - blocks exactly `2` incoming hit instances
- `Bonus Move`
  - grants one extra action and breaks the one-action rule for that turn sequence

### Victory and Loop Termination Baseline

- Win condition A: destroy the enemy `Ktank`
- Win condition B: `Ktank` reaches the center for an **instant win**
- Add loop protections from the start:
  - maximum turn cap
  - repetition detection
  - clear draw handling

## 4. Recommended Project Structure

Suggested Godot structure:

- `scenes/`
  - `boot/`
  - `menu/`
  - `match/`
  - `hud/`
  - `replay/`
  - `settings/`
- `scripts/`
  - `core/`
  - `board/`
  - `units/`
  - `ai/`
  - `ui/`
  - `effects/`
  - `replay/`
- `assets/`
  - `art/`
  - `audio/`
  - `fonts/`
  - `icons/`
  - `vfx/`
- `data/`
  - `maps/`
  - `configs/`
  - `balance/`

## 5. Core Systems to Build

The game should be separated into these layers:

### Gameplay Simulation Layer

- Hex coordinate system
- Board state
- Cell types
- Tank state
- Buff state
- Turn system
- Legal action generation
- Attack resolution
- Win/draw resolution
- Replay-safe event generation
- One-action economy enforcement
- Friendly-fire handling
- Loop termination rules

This layer should work without fancy visuals.

### AI Layer

- Common AI interface
- Minimax AI module
- MCTS AI module
- AI configuration system
- AI debug/stat output
- Decision explanation hooks
- Intermediate-state inspection hooks

### Presentation Layer

- Match board rendering
- Tank visuals
- HUD
- Animation system
- Effects
- Sound
- Menus
- Spectator controls
- Replay state browser
- Legend and rules explanation panel

## 6. Interface Vision

The game interface should feel like a professional tactics game, not just a prototype.

### Main Match Screen

The screen should include:

- Main hex battlefield in the center
- Left player panel
- Right player panel
- Top-right game info panel for:
  - turn count
  - current side
  - game mode
  - active AI type
- Right-side legend/rules panel
- Bottom action bar with:
  - `Move`
  - `Attack`
  - `Pass`
- Side or bottom info panel
- Combat log panel
- AI decision panel

### What the player or spectator should always see clearly

- Which side is active
- Which tank is selected
- Available move targets
- Available attack targets
- Current HP of all tanks
- Buff status
- Center objective importance
- Last action taken
- AI thinking state
- Search depth or rollout count
- Why the chosen action was favored
- Whether the current state is dangerous for either king

### Important UI Features

- Hover highlight on hexes
- Selected tank glow
- Move path preview
- Laser path preview
- Bomb area preview
- Turn banner
- Match state banner
- Endgame summary panel
- Replay controls
- Speed controls for AI vs AI
- Intermediate state inspector
- Toggleable debug overlays for:
  - legal move radius
  - laser line
  - bomb danger zone
  - threatened king tiles

## 7. Visual Style Guide

### Board Style

- Hex tiles should look raised above the background
- Use shadow under each tile or board layer
- Use beveled highlights on tile tops
- Special tiles should glow lightly
- Center tile should feel visually important and prestigious
- The overall scene should use a dark sci-fi UI language:
  - navy/charcoal background
  - neon edge accents
  - bright center objective color
  - clean panel framing inspired by tactical dashboards

### Tank Style

- Each tank should have a strong silhouette
- `Qtank` should look precise, angular, and ranged
- `Ktank` should look heavy, durable, and objective-focused
- Team color should be clear without reducing readability

### Fake 3D Techniques to Use

- Drop shadows under tanks
- Vertical offset for hover/selection
- Layered tile edges
- Light rim on top faces
- Strong impact flashes
- Slight camera zoom during attacks
- Mild camera shake on bombs
- Additive laser beam effects
- High-contrast AOE warning overlays
- Panel glow and objective pulse around the center tile

## 8. Resource Planning Rules

Every phase must list what is needed before that phase starts.

For each phase, separate needs into:

- Design inputs
- Placeholder assets
- Final assets
- Technical dependencies

Early phases should use placeholders whenever possible.
Final-quality assets should only become required when polish phases begin.

## 9. Development Phases

## Phase 1 - Preproduction and Foundation

### Goal

Lock the game's architecture so the whole project has a clean direction before heavy implementation starts.

### Implement

- Final project folder structure
- Scene breakdown
- Naming rules
- Data flow rules
- Core script responsibilities
- Common data models
- Initial config files
- Locked baseline rules note
- Flat-topped board convention note
- Action-economy rule note

### Define in this phase

- `HexCoord`
- `CellData`
- `BoardState`
- `TankData`
- `ActionData`
- `GameEvent`
- `MatchConfig`
- `AIConfig`
- `MatchStats`
- `ReplayRecord`
- `ActionExplanation`
- `DebugSnapshot`

### Requirements Before Phase 1

#### Design inputs

- Confirmed game rules
- Confirmed unit list
- Confirmed board cell types
- Confirmed AI requirement: Minimax + MCTS
- Confirmed one-action-per-turn baseline
- Confirmed center win is instant

#### Placeholder assets

- None required

#### Final assets

- None required

#### Technical dependencies

- Godot 4 installed
- Version control ready

### Deliverables

- Base Godot project
- Folder structure
- Scene architecture note
- System responsibility note
- Short rules baseline summary

### Acceptance Criteria

- Another developer can understand where every major system belongs
- No major architecture decisions remain ambiguous

## Phase 2 - Hex Grid and Board Core

### Goal

Create the board foundation and accurate hex-grid interaction.

### Implement

- Axial hex coordinate system
- Flat-topped orientation support
- Distance function
- Neighbor lookup
- Raycast in six directions
- Hex-to-world conversion
- World-to-hex conversion
- Board generation for 5-ring map
- Cell lookup and validation
- Tile selection/highlight test
- Terrain classification support
- Cell HP display support for debug mode

### Requirements Before Phase 2

#### Design inputs

- Confirmed board size
- Confirmed tile types
- Confirmed flat-topped rendering direction

#### Placeholder assets

- Simple colored hex tiles
- Placeholder hover marker

#### Final assets

- Not required

#### Technical dependencies

- Phase 1 data model complete

### Deliverables

- Working board scene
- Correct clickable hex interaction
- Debug view showing hex coordinates if needed

### Acceptance Criteria

- Tile selection is accurate
- Ray and neighbor logic are reliable
- Board supports future gameplay systems cleanly
- Flat-topped layout stays consistent between math, input, and rendering

## Phase 3 - Units and Rules Engine

### Goal

Implement the real game rules in a simulation-safe way.

### Implement

- `Qtank` rules
- `Ktank` rules
- HP system
- Movement rules
- Attack rules
- Buff rules
- Shield logic
- Power tile pickup logic
- Turn switching
- One-action economy enforcement
- Bonus Move chaining exception
- Friendly fire resolution
- Win conditions
- Draw detection
- Event generation for every important action

### Requirements Before Phase 3

#### Design inputs

- Exact unit stats
- Exact buff behavior
- Exact action list
- Exact friendly-fire behavior
- Exact draw and repetition behavior

#### Placeholder assets

- Basic tank markers
- Simple attack markers

#### Final assets

- Not required

#### Technical dependencies

- Stable board system from Phase 2

### Deliverables

- Full gameplay logic that can run without polish
- Action application and state copy support

### Acceptance Criteria

- A full match can be simulated from start to finish
- Win and draw conditions trigger correctly
- Ktank center entry causes instant win
- Bonus Move grants extra action without changing the default turn rule

## Phase 4 - Map Content System

### Goal

Support standard map content and future map expansion.

### Implement

- Standard map preset
- Map loading system
- Support for open and fortress map presets later
- Destructible blocks
- Power blocks
- Power tile placement
- Map validation
- Default legend metadata for spectator UI

### Requirements Before Phase 4

#### Design inputs

- Approved standard map
- Future map design notes

#### Placeholder assets

- Colored tile variants
- Basic block visuals

#### Final assets

- Not required

#### Technical dependencies

- Phase 3 rule system complete

### Deliverables

- Data-driven map setup
- Working destructible terrain and power tile flow

### Acceptance Criteria

- Maps load correctly
- Symmetry and gameplay balance are preserved

## Phase 5 - Minimax AI

### Goal

Implement the first main AI family using Minimax.

### Implement

- Legal action search
- Minimax tree search
- Alpha-beta pruning
- Heuristic evaluation
- Iterative deepening
- Move ordering
- Optional transposition table
- Time/depth budget controls
- Win-sooner scoring
- Repetition-aware evaluation safeguards

### Heuristic should consider

- Ktank alive status
- Qtank alive status
- Ktank HP
- Qtank HP
- Distance to center
- Buff advantage
- Shield value
- Attack threats
- King safety
- Tactical pressure
- Immediate win or loss threats
- Friendly-fire risk for Ktank decisions
- Action-economy opportunity cost

### Requirements Before Phase 5

#### Design inputs

- Evaluation priorities agreed
- AI difficulty plan agreed

#### Placeholder assets

- AI debug text overlay

#### Final assets

- Not required

#### Technical dependencies

- Simulation-safe rules engine from Phase 3
- State cloning or reversible action support

### Deliverables

- Working Minimax AI
- Debug stats output
- Chosen-action explanation output

### Acceptance Criteria

- AI always returns legal moves
- Search respects time/depth limits
- AI behaves tactically and consistently
- AI prefers immediate winning lines over delayed wins when possible

## Phase 6 - MCTS AI

### Goal

Implement the second main AI family using Monte Carlo Tree Search.

### Implement

- Node structure
- Selection
- Expansion
- Simulation
- Backpropagation
- UCT/UCB1 scoring
- Iteration/time budgeting
- Rollout policy
- Optional tree reuse between turns
- Loop-avoidance bias

### Rollout policy idea

Start simple, then improve:

- Initial rollout can be mostly random legal play
- Later bias rollout toward:
  - center pressure
  - king survival
  - obvious tactical damage
  - avoiding useless pass actions
  - avoiding trivial repetition loops
  - respecting friendly-fire risk

### Requirements Before Phase 6

#### Design inputs

- Rollout stopping rules
- AI comparison goals

#### Placeholder assets

- Same debug overlay style as Minimax

#### Final assets

- Not required

#### Technical dependencies

- Stable simulation loop
- Good action generator performance

### Deliverables

- Working MCTS AI
- Iteration/time stats
- Chosen-action explanation output

### Acceptance Criteria

- MCTS returns legal moves
- MCTS can complete games reliably
- MCTS can be compared directly with Minimax
- MCTS does not fall into obvious repeat loops under standard conditions

## Phase 7 - AI Battle and Comparison Framework

### Goal

Make AI vs AI the flagship mode of the game.

### Implement

- Match setup where each side can be:
  - Human
  - Minimax
  - MCTS
- AI vs AI autoplay
- Pause/play/step controls
- Match speed controls
- AI identity display per side
- Search stats display
- Match logging
- Intermediate-state browser
- Per-turn decision explanation panel

### Requirements Before Phase 7

#### Design inputs

- Match mode list
- AI stat display list

#### Placeholder assets

- Simple spectator control buttons

#### Final assets

- Not required

#### Technical dependencies

- Both AI systems complete

### Deliverables

- AI arena mode
- Configurable side setup
- Spectator-friendly AI compare mode

### Acceptance Criteria

- Minimax vs MCTS matches can be run and observed cleanly
- A viewer can understand what happened each turn without reading raw logs

## Phase 8 - Main Game Interface

### Goal

Build the actual interface people will use.

### Implement

- Main battlefield layout
- Player info panels
- Game info panel
- Legend panel
- Turn bar
- Selected tank panel
- Action hints
- Combat log
- AI info panel
- Tooltip system
- End-turn and match-state banners
- Action buttons matching the one-action economy

### Requirements Before Phase 8

#### Design inputs

- UI wireframes
- Font direction
- Panel layout decisions

#### Placeholder assets

- Placeholder icons
- Placeholder panel frames

#### Final assets

- Preferred font if available

#### Technical dependencies

- Stable gameplay flow
- Stable AI outputs

### Deliverables

- Complete usable interface
- Spectator-ready match screen

### Acceptance Criteria

- A new viewer can understand the match without reading debug text
- The UI clearly shows the difference between move range, attack range, and power-up state

## Phase 9 - Visual Pass: 2D + Fake 3D

### Goal

Upgrade the battlefield into a visually strong tactical scene.

### Implement

- Raised tile look
- Tile bevel highlight
- Tile shadows
- Background depth layers
- Tank drop shadows
- Hover lift
- Selection glow
- Special tile glow
- Camera pan/zoom polish
- Clear green move overlays
- Clear red danger or attack overlays

### Requirements Before Phase 9

#### Design inputs

- Approved visual mood
- Approved color palette

#### Placeholder assets

- Temporary tile textures
- Temporary background art

#### Final assets

- Style-approved tile set preferred

#### Technical dependencies

- Match interface working

### Deliverables

- Board that feels dimensional and professional

### Acceptance Criteria

- The game looks like a polished strategy title without using full 3D

## Phase 10 - Tanks, Materials, and Visual Asset Set

### Goal

Replace prototype visuals with better unit and material presentation.

### Implement

- Tank sprite kits
- Team variants
- Damage flash
- Hover/selection states
- Tile material visuals
- Center tile special art
- Block destruction art
- Qtank sniper identity visuals
- Ktank juggernaut identity visuals

### Resources Needed Before Phase 10

#### Design inputs

- Unit concept direction
- Team color rules

#### Placeholder assets

- Basic tank silhouettes
- Basic material textures

#### Final assets

- Tank base art
- Tile material set
- Icons for powers and buffs

#### Technical dependencies

- Phase 9 style locked

### Deliverables

- Strong and readable unit presentation

### Acceptance Criteria

- Tanks are instantly distinguishable
- Battlefield materials feel consistent

## Phase 11 - Combat VFX and Feedback

### Goal

Make combat satisfying and easy to read.

### Implement

- Laser beam effect
- Bomb blast effect
- Shield hit effect
- Power pickup glow
- Tile reveal burst
- Sparks and debris
- Damage numbers
- Camera shake for heavy hits
- Impact flash
- First-collision laser stop feedback
- Clear AOE warning telegraph before Ktank blast

### Resources Needed Before Phase 11

#### Design inputs

- Effect color language
- Intensity rules

#### Placeholder assets

- Temporary particle sprites
- Temporary flash textures

#### Final assets

- Final VFX textures or particle setups preferred

#### Technical dependencies

- Stable attack events from gameplay logic

### Deliverables

- Action feedback package

### Acceptance Criteria

- Attacks feel impactful
- Players can read hit results instantly

## Phase 12 - Audio and Match Feel

### Goal

Add professional-feeling sound and pacing.

### Implement

- Menu sounds
- Select sounds
- Move sounds
- Laser sound
- Bomb sound
- Hit sound
- Pickup sound
- Win sound
- Audio bus setup
- Volume categories

### Resources Needed Before Phase 12

#### Design inputs

- Sound style direction
- Music/no-music decision

#### Placeholder assets

- Temporary SFX pack

#### Final assets

- Clean SFX set
- Optional soundtrack loops

#### Technical dependencies

- Event-based action feedback complete

### Deliverables

- SFX and audio settings system

### Acceptance Criteria

- Every major action has satisfying audio feedback

## Phase 13 - Menus, Settings, and Replay Controls

### Goal

Wrap the game in a complete usable shell.

### Implement

- Main menu
- Match setup
- AI setup
- Difficulty setup
- Map setup
- Replay viewer controls
- Settings menu
- Accessibility basics

### Resources Needed Before Phase 13

#### Design inputs

- Menu navigation map
- Settings list

#### Placeholder assets

- Basic menu backgrounds
- Button styles

#### Final assets

- Final UI skins preferred

#### Technical dependencies

- Match scene stable

### Deliverables

- Complete game shell

### Acceptance Criteria

- A user can launch, configure, watch, replay, and exit matches cleanly

## Phase 14 - Replay, Analytics, and Post-Match Summary

### Goal

Make the game feel professional and useful for AI comparison.

### Implement

- Replay recording
- Replay loading
- Step controls
- Intermediate state snapshots
- Match summary screen
- Turn count summary
- Damage summary
- Pickup summary
- AI timing summary
- Winner reason summary
- Action explanation timeline

### Resources Needed Before Phase 14

#### Design inputs

- Replay data format
- Match metric list

#### Placeholder assets

- Simple stat charts or panels

#### Final assets

- Final summary panel assets preferred

#### Technical dependencies

- Reliable event logging

### Deliverables

- Replay system
- Match analytics

### Acceptance Criteria

- A finished match can be reviewed clearly and shared for analysis
- Replay lets the viewer inspect why a specific move was chosen

## Phase 15 - Tutorial, Accessibility, and Final Polish

### Goal

Bring the project to a portfolio-ready or demo-ready state.

### Implement

- Interactive tutorial or guided help
- Game glossary
- Colorblind-safe option
- Reduced motion option
- UI scale options
- Final balancing pass
- Final performance pass
- Final bug pass

### Resources Needed Before Phase 15

#### Design inputs

- Tutorial script
- Accessibility option list
- Balance targets

#### Placeholder assets

- Tutorial overlays

#### Final assets

- Final tutorial and UI art

#### Technical dependencies

- All major systems complete

### Deliverables

- Polished near-release build

### Acceptance Criteria

- The game feels complete, presentable, and easy to understand

## 9. Asset and Resource Master List

This is the main resource checklist for the whole project.

### Art

- Hex tile textures or painted tile set
- Tile edge/shadow layers
- Tank body art
- Tank turret art
- Team color variants
- Block art
- Power tile icons
- Center tile art
- UI icons
- Panel backgrounds
- Button art
- Background art

### VFX

- Laser beam effect assets
- Explosion effect assets
- Shield effect assets
- Sparks/debris assets
- Glow overlays
- Selection markers
- Hit flashes

### Audio

- Move
- Select
- Laser
- Bomb
- Hit
- Pickup
- Menu click
- Win
- Optional music

### UI

- Fonts
- HUD icon set
- Replay buttons
- Match summary panels
- AI comparison labels
- Legend icons for terrain and power-ups
- Debug overlay symbols for move/attack state

### Design Documents

- Rules doc
- AI behavior doc
- Map layouts
- Balance sheet
- UI wireframes
- Style references

## 10. Suggested Milestone Order

If the team wants a clean practical order, use this:

1. Phase 1 to 4 for core game foundation
2. Phase 5 Minimax
3. Phase 6 MCTS
4. Phase 7 AI battle setup
5. Phase 8 interface
6. Phase 9 to 12 visual/audio polish
7. Phase 13 to 15 complete-game polish and replay/onboarding

## 11. Success Criteria for the Whole Project

The final game should achieve these goals:

- Rules are stable and complete
- Both AI families are implemented correctly
- AI vs AI is exciting to watch
- Human interaction is still supported
- Board is readable at a glance
- Combat feels impactful
- Menus and settings feel complete
- Replay and analytics support AI comparison
- The one-action economy is visible and understandable
- Spectators can follow intermediate states and AI reasoning
- The game looks polished enough to share proudly

## 12. Final Note

This project should be built like a serious tactical game with AI as a major identity, not just a classroom prototype.

The best target is:

- strong gameplay readability
- impressive AI comparison
- polished presentation
- manageable production scope

That is why **Godot 4 + 2D with fake 3D** is the recommended path.
