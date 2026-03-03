"""
Game State management for Hex Siege Arena.
Handles all game logic, actions, and win conditions.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional, Tuple, Set
import copy

from .hex_coord import HexCoord
from .board import HexBoard, CellType, create_game_board
from .tank import Tank, Qtank, Ktank, TankType, BuffType, STARTING_POSITIONS


class ActionType(Enum):
    """Types of actions a tank can perform"""
    MOVE = auto()
    ATTACK = auto()
    PASS = auto()


@dataclass
class Action:
    """Represents a single game action"""
    tank_type: TankType
    player: int
    action_type: ActionType
    direction: Optional[int] = None  # 0-5 for hex directions
    distance: Optional[int] = None   # For movement (1 or 2 for Ktank, any for Qtank)
    target_pos: Optional[HexCoord] = None  # Computed destination
    
    def __str__(self) -> str:
        tank_name = "Q" if self.tank_type == TankType.QTANK else "K"
        if self.action_type == ActionType.PASS:
            return f"P{self.player} {tank_name}: Pass"
        elif self.action_type == ActionType.MOVE:
            return f"P{self.player} {tank_name}: Move dir={self.direction} dist={self.distance}"
        else:
            return f"P{self.player} {tank_name}: Attack dir={self.direction}"


@dataclass
class GameEvent:
    """Represents an event that occurred during action resolution"""
    event_type: str
    data: dict = field(default_factory=dict)


class GameState:
    """
    Complete game state including board, tanks, and game progress.
    Supports copying for AI search.
    """
    
    def __init__(self, map_type: str = "standard"):
        self.board = create_game_board(map_type)
        self.center = HexCoord(0, 0)
        
        # Initialize tanks
        self.tanks: Dict[Tuple[int, TankType], Tank] = {}
        self._init_tanks()
        
        # Game state
        self.current_player = 1
        self.turn_count = 0
        self.winner: Optional[int] = None
        self.game_over = False
        self.events: List[GameEvent] = []
        
        # For draw detection
        self.turns_without_action = 0
        self.max_turns = 100
        self.state_history: List[int] = []
    
    def _init_tanks(self):
        """Initialize tanks at starting positions"""
        for player in [1, 2]:
            positions = STARTING_POSITIONS[player]
            self.tanks[(player, TankType.QTANK)] = Qtank(positions[TankType.QTANK], player)
            self.tanks[(player, TankType.KTANK)] = Ktank(positions[TankType.KTANK], player)
    
    def get_tank(self, player: int, tank_type: TankType) -> Tank:
        """Get a specific tank"""
        return self.tanks[(player, tank_type)]
    
    def get_all_tanks(self) -> List[Tank]:
        """Get all tanks"""
        return list(self.tanks.values())
    
    def get_player_tanks(self, player: int) -> List[Tank]:
        """Get all tanks belonging to a player"""
        return [t for t in self.tanks.values() if t.player == player]
    
    def get_tank_at(self, pos: HexCoord) -> Optional[Tank]:
        """Get tank at position (if any)"""
        for tank in self.tanks.values():
            if tank.is_alive() and tank.pos == pos:
                return tank
        return None
    
    def is_cell_occupied(self, pos: HexCoord) -> bool:
        """Check if a cell is occupied by a tank"""
        return self.get_tank_at(pos) is not None
    
    def get_legal_actions(self, player: Optional[int] = None) -> List[Action]:
        """Generate all legal actions for the current player"""
        if player is None:
            player = self.current_player
        
        actions = []
        
        for tank_type in [TankType.QTANK, TankType.KTANK]:
            tank = self.get_tank(player, tank_type)
            
            if not tank.is_alive():
                continue
            
            # MOVE actions
            move_actions = self._get_move_actions(tank)
            actions.extend(move_actions)
            
            # ATTACK actions
            attack_actions = self._get_attack_actions(tank)
            actions.extend(attack_actions)
            
            # PASS action (always legal)
            actions.append(Action(
                tank_type=tank_type,
                player=player,
                action_type=ActionType.PASS
            ))
        
        return actions
    
    def _get_move_actions(self, tank: Tank) -> List[Action]:
        """Get all legal move actions for a tank"""
        actions = []
        max_range = tank.get_move_range()
        
        for direction in range(6):
            path = tank.pos.raycast(direction, max_range)
            
            for dist, pos in enumerate(path, 1):
                # Check if position is valid and walkable
                if not self.board.is_valid(pos):
                    break
                
                if not self.board.is_walkable(pos):
                    break
                
                # Check if occupied by another tank
                if self.is_cell_occupied(pos):
                    break
                
                # Valid move
                actions.append(Action(
                    tank_type=tank.tank_type,
                    player=tank.player,
                    action_type=ActionType.MOVE,
                    direction=direction,
                    distance=dist,
                    target_pos=pos
                ))
                
                # Ktank can only move up to 2 cells
                if tank.tank_type == TankType.KTANK and dist >= 2:
                    break
        
        return actions
    
    def _get_attack_actions(self, tank: Tank) -> List[Action]:
        """Get all legal attack actions for a tank"""
        actions = []
        
        # Attack in all 6 directions
        for direction in range(6):
            actions.append(Action(
                tank_type=tank.tank_type,
                player=tank.player,
                action_type=ActionType.ATTACK,
                direction=direction
            ))
        
        return actions
    
    def apply_action(self, action: Action) -> GameState:
        """Apply an action and return the new game state"""
        new_state = self.copy()
        new_state.events = []
        
        if action.action_type == ActionType.PASS:
            new_state.events.append(GameEvent("pass", {"player": action.player}))
            new_state._end_turn()
            return new_state
        
        tank = new_state.get_tank(action.player, action.tank_type)
        
        if action.action_type == ActionType.MOVE:
            new_state._resolve_move(tank, action)
        elif action.action_type == ActionType.ATTACK:
            new_state._resolve_attack(tank, action)
        
        new_state._end_turn()
        return new_state
    
    def _resolve_move(self, tank: Tank, action: Action):
        """Resolve a move action"""
        old_pos = tank.pos
        new_pos = action.target_pos
        
        if new_pos is None:
            # Calculate target position
            path = tank.pos.raycast(action.direction, action.distance)
            new_pos = path[action.distance - 1] if path else tank.pos
        
        tank.pos = new_pos
        
        self.events.append(GameEvent("move", {
            "tank": tank.tank_type.name,
            "player": tank.player,
            "from": old_pos,
            "to": new_pos
        }))
        
        # Check power tile pickup
        power_tile = self.board.get_power_tile(new_pos)
        if power_tile:
            self._pickup_power_tile(tank, power_tile)
            self.board.consume_power_tile(new_pos)
        
        # Check instant win (Ktank on center)
        if tank.tank_type == TankType.KTANK and new_pos == self.center:
            self.winner = tank.player
            self.game_over = True
            self.events.append(GameEvent("win_center", {"player": tank.player}))
        
        self.turns_without_action = 0
    
    def _pickup_power_tile(self, tank: Tank, tile_type: CellType):
        """Handle power tile pickup"""
        if tile_type == CellType.POWER_ATTACK:
            tank.apply_buff(BuffType.ATTACK_X2)
            self.events.append(GameEvent("buff", {
                "tank": tank.tank_type.name,
                "buff": "ATTACK_X2"
            }))
        elif tile_type == CellType.POWER_SHIELD:
            tank.apply_buff(BuffType.SHIELD)
            self.events.append(GameEvent("buff", {
                "tank": tank.tank_type.name,
                "buff": "SHIELD"
            }))
        elif tile_type == CellType.POWER_MOVE:
            # Bonus move - tank gets an extra move next
            self.events.append(GameEvent("bonus_move", {
                "tank": tank.tank_type.name
            }))
    
    def _resolve_attack(self, tank: Tank, action: Action):
        """Resolve an attack action"""
        if tank.tank_type == TankType.QTANK:
            self._resolve_laser(tank, action.direction)
        else:
            self._resolve_bomb(tank)
        
        tank.consume_attack_buff()
        self.turns_without_action = 0
    
    def _resolve_laser(self, tank: Tank, direction: int):
        """Resolve Qtank laser attack"""
        damage = tank.get_attack_damage()
        path = tank.pos.raycast(direction, 50)
        
        self.events.append(GameEvent("laser_start", {
            "tank": tank.tank_type.name,
            "player": tank.player,
            "from": tank.pos,
            "direction": direction,
            "damage": damage
        }))
        
        hit_pos = None
        
        for pos in path:
            if not self.board.is_valid(pos):
                break
            
            cell = self.board.get_cell(pos)
            
            # Check for tank hit
            hit_tank = self.get_tank_at(pos)
            if hit_tank:
                actual_damage = hit_tank.take_damage(damage)
                hit_pos = pos
                
                self.events.append(GameEvent("laser_hit_tank", {
                    "target": hit_tank.tank_type.name,
                    "target_player": hit_tank.player,
                    "damage": actual_damage,
                    "pos": pos,
                    "blocked": actual_damage == 0
                }))
                
                # Check for Ktank kill
                if hit_tank.tank_type == TankType.KTANK and not hit_tank.is_alive():
                    self.winner = tank.player
                    self.game_over = True
                    self.events.append(GameEvent("win_kill", {
                        "player": tank.player,
                        "killed": hit_tank.player
                    }))
                break
            
            # Check for block/wall hit
            if cell and cell.blocks_attack:
                hit_pos = pos
                
                if cell.is_destructible:
                    destroyed, revealed = self.board.apply_damage(pos, damage)
                    self.events.append(GameEvent("laser_hit_block", {
                        "pos": pos,
                        "damage": damage,
                        "destroyed": destroyed,
                        "revealed": revealed.name if revealed else None
                    }))
                else:
                    self.events.append(GameEvent("laser_hit_wall", {"pos": pos}))
                break
        
        self.events.append(GameEvent("laser_end", {
            "hit_pos": hit_pos,
            "path": path[:path.index(hit_pos) + 1] if hit_pos and hit_pos in path else path
        }))
    
    def _resolve_bomb(self, tank: Tank):
        """Resolve Ktank bomb attack"""
        damage = tank.get_attack_damage()
        affected_cells = tank.pos.neighbors()
        
        self.events.append(GameEvent("bomb_start", {
            "tank": tank.tank_type.name,
            "player": tank.player,
            "pos": tank.pos,
            "damage": damage,
            "affected": affected_cells
        }))
        
        for pos in affected_cells:
            if not self.board.is_valid(pos):
                continue
            
            # Hit tanks
            hit_tank = self.get_tank_at(pos)
            if hit_tank:
                actual_damage = hit_tank.take_damage(damage)
                
                self.events.append(GameEvent("bomb_hit_tank", {
                    "target": hit_tank.tank_type.name,
                    "target_player": hit_tank.player,
                    "damage": actual_damage,
                    "pos": pos,
                    "blocked": actual_damage == 0
                }))
                
                # Check for Ktank kill
                if hit_tank.tank_type == TankType.KTANK and not hit_tank.is_alive():
                    self.winner = tank.player
                    self.game_over = True
                    self.events.append(GameEvent("win_kill", {
                        "player": tank.player,
                        "killed": hit_tank.player
                    }))
            
            # Hit blocks
            cell = self.board.get_cell(pos)
            if cell and cell.is_destructible:
                destroyed, revealed = self.board.apply_damage(pos, damage)
                self.events.append(GameEvent("bomb_hit_block", {
                    "pos": pos,
                    "damage": damage,
                    "destroyed": destroyed,
                    "revealed": revealed.name if revealed else None
                }))
        
        self.events.append(GameEvent("bomb_end", {}))
    
    def _end_turn(self):
        """End the current turn"""
        self.current_player = 3 - self.current_player  # Toggle 1 ↔ 2
        self.turn_count += 1
        
        # Check for draw conditions
        if self.turn_count >= self.max_turns:
            self._resolve_draw()
        
        # Store state hash for repetition detection
        state_hash = self._compute_state_hash()
        self.state_history.append(state_hash)
        
        # Check for threefold repetition
        if self.state_history.count(state_hash) >= 3:
            self._resolve_draw()
    
    def _resolve_draw(self):
        """Resolve a draw condition"""
        self.game_over = True
        
        # Tiebreakers
        p1_ktank = self.get_tank(1, TankType.KTANK)
        p2_ktank = self.get_tank(2, TankType.KTANK)
        
        # 1. Alive Ktank wins
        if p1_ktank.is_alive() and not p2_ktank.is_alive():
            self.winner = 1
        elif p2_ktank.is_alive() and not p1_ktank.is_alive():
            self.winner = 2
        # 2. Higher Ktank HP
        elif p1_ktank.hp > p2_ktank.hp:
            self.winner = 1
        elif p2_ktank.hp > p1_ktank.hp:
            self.winner = 2
        # 3. Closer to center
        elif p1_ktank.is_alive() and p2_ktank.is_alive():
            p1_dist = p1_ktank.pos.distance(self.center)
            p2_dist = p2_ktank.pos.distance(self.center)
            if p1_dist < p2_dist:
                self.winner = 1
            elif p2_dist < p1_dist:
                self.winner = 2
            # else: true draw (winner stays None)
        
        self.events.append(GameEvent("draw", {"winner": self.winner}))
    
    def _compute_state_hash(self) -> int:
        """Compute a hash of the current game state for repetition detection"""
        state_tuple = (
            self.current_player,
            tuple(
                (t.pos.q, t.pos.r, t.hp, t.buff.value, t.shield_charges)
                for t in sorted(self.tanks.values(), key=lambda t: (t.player, t.tank_type.value))
            ),
            tuple(
                (pos.q, pos.r, cell.cell_type.value, cell.hp)
                for pos, cell in sorted(self.board.cells.items(), key=lambda x: (x[0].q, x[0].r))
                if cell.cell_type != CellType.EMPTY
            )
        )
        return hash(state_tuple)
    
    def is_terminal(self) -> bool:
        """Check if the game is over"""
        return self.game_over
    
    def copy(self) -> GameState:
        """Create a deep copy of the game state"""
        new_state = GameState.__new__(GameState)
        new_state.board = self.board.copy()
        new_state.center = self.center
        new_state.tanks = {
            key: tank.copy() for key, tank in self.tanks.items()
        }
        new_state.current_player = self.current_player
        new_state.turn_count = self.turn_count
        new_state.winner = self.winner
        new_state.game_over = self.game_over
        new_state.events = []
        new_state.turns_without_action = self.turns_without_action
        new_state.max_turns = self.max_turns
        new_state.state_history = self.state_history.copy()
        return new_state
    
    def get_game_info(self) -> dict:
        """Get current game information for display"""
        return {
            "turn": self.turn_count,
            "current_player": self.current_player,
            "winner": self.winner,
            "game_over": self.game_over,
            "tanks": {
                f"P{t.player}_{t.tank_type.name}": {
                    "hp": t.hp,
                    "max_hp": t.max_hp,
                    "pos": (t.pos.q, t.pos.r),
                    "buff": t.buff.name,
                    "shield": t.shield_charges,
                    "alive": t.is_alive()
                }
                for t in self.tanks.values()
            }
        }
