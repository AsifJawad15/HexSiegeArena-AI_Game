"""
AI implementation for Hex Siege Arena.
Implements Minimax with Alpha-Beta pruning and heuristic evaluation.
"""

from __future__ import annotations
import math
import random
from typing import List, Optional, Tuple, Dict
from dataclasses import dataclass
import time

from .game_state import GameState, Action, ActionType
from .tank import TankType, BuffType
from .hex_coord import HexCoord


@dataclass
class EvaluationWeights:
    """Weights for heuristic evaluation function"""
    ktank_alive: float = 1000.0
    qtank_alive: float = 500.0
    ktank_hp: float = 50.0
    qtank_hp: float = 30.0
    center_distance: float = -40.0
    buff_value: float = 25.0
    shield_charge: float = 30.0
    board_control: float = 10.0
    attack_threat: float = 15.0
    king_safety: float = 20.0


class TranspositionTable:
    """
    Zobrist hashing based transposition table for caching evaluated positions.
    Avoids redundant calculations in the search tree.
    """
    
    def __init__(self, max_size: int = 100000):
        self.table: Dict[int, Tuple[float, int, Optional[Action]]] = {}
        self.max_size = max_size
        self.hits = 0
        self.misses = 0
    
    def get(self, state_hash: int, depth: int) -> Optional[Tuple[float, Optional[Action]]]:
        """Get cached evaluation if available and at sufficient depth"""
        if state_hash in self.table:
            cached_score, cached_depth, cached_action = self.table[state_hash]
            if cached_depth >= depth:
                self.hits += 1
                return cached_score, cached_action
        self.misses += 1
        return None
    
    def put(self, state_hash: int, score: float, depth: int, action: Optional[Action]):
        """Cache an evaluation"""
        if len(self.table) >= self.max_size:
            # Simple eviction: remove random entries
            keys_to_remove = random.sample(list(self.table.keys()), 
                                          min(1000, len(self.table) // 10))
            for key in keys_to_remove:
                del self.table[key]
        
        self.table[state_hash] = (score, depth, action)
    
    def clear(self):
        """Clear the table"""
        self.table.clear()
        self.hits = 0
        self.misses = 0


class MinimaxAI:
    """
    Minimax AI with Alpha-Beta pruning for Hex Siege Arena.
    Uses iterative deepening for time-limited search.
    """
    
    def __init__(self, 
                 max_depth: int = 4,
                 time_limit: float = 5.0,
                 weights: Optional[EvaluationWeights] = None,
                 use_transposition: bool = True):
        self.max_depth = max_depth
        self.time_limit = time_limit
        self.weights = weights or EvaluationWeights()
        self.use_transposition = use_transposition
        self.transposition_table = TranspositionTable() if use_transposition else None
        
        # Statistics
        self.nodes_evaluated = 0
        self.search_start_time = 0
        self.time_expired = False
    
    def choose_action(self, state: GameState, 
                      player: Optional[int] = None) -> Tuple[Action, float]:
        """
        Choose the best action using iterative deepening minimax.
        Returns (best_action, evaluation_score).
        """
        if player is None:
            player = state.current_player
        
        self.nodes_evaluated = 0
        self.time_expired = False
        self.search_start_time = time.time()
        
        if self.transposition_table:
            self.transposition_table.clear()
        
        legal_actions = state.get_legal_actions(player)
        
        if not legal_actions:
            return None, 0.0
        
        if len(legal_actions) == 1:
            return legal_actions[0], self._evaluate(state, player)
        
        best_action = legal_actions[0]
        best_score = -math.inf
        
        # Iterative deepening
        for depth in range(1, self.max_depth + 1):
            if self._is_time_expired():
                break
            
            try:
                action, score = self._search_root(state, depth, player)
                if action is not None:
                    best_action = action
                    best_score = score
            except TimeoutError:
                break
        
        return best_action, best_score
    
    def _search_root(self, state: GameState, depth: int, 
                     player: int) -> Tuple[Optional[Action], float]:
        """Search from root with move ordering"""
        legal_actions = state.get_legal_actions(player)
        
        # Move ordering: prioritize attacks and forward moves
        legal_actions = self._order_moves(state, legal_actions, player)
        
        best_action = None
        best_score = -math.inf
        alpha = -math.inf
        beta = math.inf
        
        for action in legal_actions:
            if self._is_time_expired():
                raise TimeoutError()
            
            new_state = state.apply_action(action)
            
            # Maximizing for current player
            is_maximizing = (new_state.current_player == player)
            score = self._minimax(new_state, depth - 1, alpha, beta, 
                                 is_maximizing, player)
            
            if score > best_score:
                best_score = score
                best_action = action
            
            alpha = max(alpha, score)
        
        return best_action, best_score
    
    def _minimax(self, state: GameState, depth: int, 
                 alpha: float, beta: float, 
                 maximizing: bool, perspective_player: int) -> float:
        """
        Minimax with alpha-beta pruning.
        perspective_player: The player we're maximizing for.
        """
        self.nodes_evaluated += 1
        
        if self._is_time_expired():
            raise TimeoutError()
        
        # Terminal state check
        if state.is_terminal():
            return self._evaluate_terminal(state, perspective_player)
        
        if depth == 0:
            return self._evaluate(state, perspective_player)
        
        # Transposition table lookup
        if self.transposition_table:
            state_hash = state._compute_state_hash()
            cached = self.transposition_table.get(state_hash, depth)
            if cached is not None:
                return cached[0]
        
        legal_actions = state.get_legal_actions()
        
        if not legal_actions:
            return self._evaluate(state, perspective_player)
        
        # Move ordering
        legal_actions = self._order_moves(state, legal_actions, state.current_player)
        
        if maximizing:
            max_eval = -math.inf
            for action in legal_actions:
                new_state = state.apply_action(action)
                is_max = (new_state.current_player == perspective_player)
                eval_score = self._minimax(new_state, depth - 1, 
                                          alpha, beta, is_max, perspective_player)
                max_eval = max(max_eval, eval_score)
                alpha = max(alpha, eval_score)
                if beta <= alpha:
                    break  # Beta cutoff
            
            # Cache result
            if self.transposition_table:
                self.transposition_table.put(state_hash, max_eval, depth, None)
            
            return max_eval
        else:
            min_eval = math.inf
            for action in legal_actions:
                new_state = state.apply_action(action)
                is_max = (new_state.current_player == perspective_player)
                eval_score = self._minimax(new_state, depth - 1,
                                          alpha, beta, is_max, perspective_player)
                min_eval = min(min_eval, eval_score)
                beta = min(beta, eval_score)
                if beta <= alpha:
                    break  # Alpha cutoff
            
            # Cache result
            if self.transposition_table:
                self.transposition_table.put(state_hash, min_eval, depth, None)
            
            return min_eval
    
    def _evaluate_terminal(self, state: GameState, perspective_player: int) -> float:
        """Evaluate terminal game state"""
        if state.winner == perspective_player:
            return 10000.0 + (state.max_turns - state.turn_count)  # Win sooner is better
        elif state.winner is not None:
            return -10000.0 - (state.max_turns - state.turn_count)  # Lose later is better
        else:
            return 0.0  # Draw
    
    def _evaluate(self, state: GameState, perspective_player: int) -> float:
        """
        Heuristic evaluation function.
        Positive scores favor perspective_player.
        """
        w = self.weights
        opponent = 3 - perspective_player
        
        score = 0.0
        
        # Tank survival
        my_ktank = state.get_tank(perspective_player, TankType.KTANK)
        my_qtank = state.get_tank(perspective_player, TankType.QTANK)
        opp_ktank = state.get_tank(opponent, TankType.KTANK)
        opp_qtank = state.get_tank(opponent, TankType.QTANK)
        
        # Alive bonus
        if my_ktank.is_alive():
            score += w.ktank_alive
        if my_qtank.is_alive():
            score += w.qtank_alive
        if opp_ktank.is_alive():
            score -= w.ktank_alive
        if opp_qtank.is_alive():
            score -= w.qtank_alive
        
        # HP difference
        my_k_hp = my_ktank.hp if my_ktank.is_alive() else 0
        my_q_hp = my_qtank.hp if my_qtank.is_alive() else 0
        opp_k_hp = opp_ktank.hp if opp_ktank.is_alive() else 0
        opp_q_hp = opp_qtank.hp if opp_qtank.is_alive() else 0
        
        score += (my_k_hp - opp_k_hp) * w.ktank_hp
        score += (my_q_hp - opp_q_hp) * w.qtank_hp
        
        # Center distance (lower is better for Ktank)
        if my_ktank.is_alive():
            my_dist = my_ktank.pos.distance(state.center)
            score += my_dist * w.center_distance  # Negative weight
        
        if opp_ktank.is_alive():
            opp_dist = opp_ktank.pos.distance(state.center)
            score -= opp_dist * w.center_distance  # Subtract negative = add
        
        # Buff advantage
        for tank in [my_ktank, my_qtank]:
            if tank.buff != BuffType.NONE:
                score += w.buff_value
            score += tank.shield_charges * w.shield_charge
        
        for tank in [opp_ktank, opp_qtank]:
            if tank.buff != BuffType.NONE:
                score -= w.buff_value
            score -= tank.shield_charges * w.shield_charge
        
        # King safety (distance from enemy Qtank)
        if my_ktank.is_alive() and opp_qtank.is_alive():
            # Being closer to enemy queen is dangerous
            danger_dist = my_ktank.pos.distance(opp_qtank.pos)
            if danger_dist <= 3:
                score -= w.king_safety * (4 - danger_dist)
        
        if opp_ktank.is_alive() and my_qtank.is_alive():
            threat_dist = opp_ktank.pos.distance(my_qtank.pos)
            if threat_dist <= 3:
                score += w.king_safety * (4 - threat_dist)
        
        # Attack threat (can we attack enemy Ktank?)
        if my_qtank.is_alive() and opp_ktank.is_alive():
            if self._can_laser_hit(state, my_qtank.pos, opp_ktank.pos):
                score += w.attack_threat * 2
        
        if my_ktank.is_alive() and opp_ktank.is_alive():
            if my_ktank.pos.distance(opp_ktank.pos) == 1:
                score += w.attack_threat * 3  # Can bomb enemy king!
        
        return score
    
    def _can_laser_hit(self, state: GameState, from_pos: HexCoord, 
                       target_pos: HexCoord) -> bool:
        """Check if a laser from from_pos can hit target_pos"""
        # Check if target is in any straight line
        for direction in range(6):
            path = from_pos.raycast(direction, 10)
            for pos in path:
                if pos == target_pos:
                    return True
                if not state.board.is_valid(pos):
                    break
                if state.is_cell_occupied(pos):
                    break
                cell = state.board.get_cell(pos)
                if cell and cell.blocks_attack:
                    break
        return False
    
    def _order_moves(self, state: GameState, actions: List[Action], 
                     player: int) -> List[Action]:
        """Order moves for better alpha-beta pruning"""
        opponent = 3 - player
        opp_ktank = state.get_tank(opponent, TankType.KTANK)
        
        def score_action(action: Action) -> float:
            score = 0.0
            
            # Prioritize attacks
            if action.action_type == ActionType.ATTACK:
                score += 100
                # Extra priority for Ktank attacks (can hit multiple)
                if action.tank_type == TankType.KTANK:
                    score += 50
            
            # Prioritize Ktank moves toward center
            if action.action_type == ActionType.MOVE and action.tank_type == TankType.KTANK:
                tank = state.get_tank(player, TankType.KTANK)
                if action.target_pos:
                    old_dist = tank.pos.distance(state.center)
                    new_dist = action.target_pos.distance(state.center)
                    score += (old_dist - new_dist) * 30
            
            # Penalize pass
            if action.action_type == ActionType.PASS:
                score -= 200
            
            return score
        
        return sorted(actions, key=score_action, reverse=True)
    
    def _is_time_expired(self) -> bool:
        """Check if search time limit has been exceeded"""
        if self.time_expired:
            return True
        if time.time() - self.search_start_time > self.time_limit:
            self.time_expired = True
            return True
        return False
    
    def get_stats(self) -> dict:
        """Get search statistics"""
        stats = {
            "nodes_evaluated": self.nodes_evaluated,
            "search_time": time.time() - self.search_start_time,
        }
        if self.transposition_table:
            stats["tt_hits"] = self.transposition_table.hits
            stats["tt_misses"] = self.transposition_table.misses
        return stats


class RandomAI:
    """Simple random AI for testing"""
    
    def choose_action(self, state: GameState, 
                      player: Optional[int] = None) -> Tuple[Action, float]:
        if player is None:
            player = state.current_player
        
        legal_actions = state.get_legal_actions(player)
        
        # Filter out pass if other actions available
        non_pass = [a for a in legal_actions if a.action_type != ActionType.PASS]
        if non_pass:
            return random.choice(non_pass), 0.0
        
        return random.choice(legal_actions), 0.0


class AggressiveAI:
    """AI that prioritizes attacking"""
    
    def __init__(self, base_ai: Optional[MinimaxAI] = None):
        self.base_ai = base_ai or MinimaxAI(max_depth=2, time_limit=2.0)
        self.base_ai.weights.attack_threat = 50.0
        self.base_ai.weights.center_distance = -20.0
    
    def choose_action(self, state: GameState, 
                      player: Optional[int] = None) -> Tuple[Action, float]:
        return self.base_ai.choose_action(state, player)


class DefensiveAI:
    """AI that prioritizes king safety and center control"""
    
    def __init__(self, base_ai: Optional[MinimaxAI] = None):
        self.base_ai = base_ai or MinimaxAI(max_depth=2, time_limit=2.0)
        self.base_ai.weights.king_safety = 50.0
        self.base_ai.weights.center_distance = -60.0
    
    def choose_action(self, state: GameState, 
                      player: Optional[int] = None) -> Tuple[Action, float]:
        return self.base_ai.choose_action(state, player)


def create_ai(difficulty: str = "medium") -> MinimaxAI:
    """Factory function to create AI with different difficulty levels"""
    if difficulty == "easy":
        return MinimaxAI(max_depth=2, time_limit=1.0)
    elif difficulty == "medium":
        return MinimaxAI(max_depth=4, time_limit=3.0)
    elif difficulty == "hard":
        return MinimaxAI(max_depth=6, time_limit=5.0)
    else:
        return MinimaxAI()
