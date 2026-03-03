"""
Board representation for Hex Siege Arena.
Manages the hex grid, cells, blocks, and power tiles.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional, Set, Tuple
import random

from .hex_coord import HexCoord, generate_hex_board


class CellType(Enum):
    """Types of cells on the board"""
    EMPTY = auto()
    WALL = auto()
    BLOCK_NORMAL = auto()
    BLOCK_ARMOR = auto()
    BLOCK_POWER = auto()
    POWER_ATTACK = auto()
    POWER_MOVE = auto()
    POWER_SHIELD = auto()
    CENTER = auto()


# Cell properties
CELL_PROPERTIES = {
    CellType.EMPTY: {"walkable": True, "destructible": False, "blocks_attack": False},
    CellType.WALL: {"walkable": False, "destructible": False, "blocks_attack": True},
    CellType.BLOCK_NORMAL: {"walkable": False, "destructible": True, "blocks_attack": True, "hp": 2},
    CellType.BLOCK_ARMOR: {"walkable": False, "destructible": True, "blocks_attack": True, "hp": 3},
    CellType.BLOCK_POWER: {"walkable": False, "destructible": True, "blocks_attack": True, "hp": 2},
    CellType.POWER_ATTACK: {"walkable": True, "destructible": False, "blocks_attack": False},
    CellType.POWER_MOVE: {"walkable": True, "destructible": False, "blocks_attack": False},
    CellType.POWER_SHIELD: {"walkable": True, "destructible": False, "blocks_attack": False},
    CellType.CENTER: {"walkable": True, "destructible": False, "blocks_attack": False},
}


@dataclass
class Cell:
    """Represents a single cell on the board"""
    coord: HexCoord
    cell_type: CellType = CellType.EMPTY
    hp: int = 0
    
    def __post_init__(self):
        if self.hp == 0 and self.cell_type in CELL_PROPERTIES:
            self.hp = CELL_PROPERTIES[self.cell_type].get("hp", 0)
    
    @property
    def is_walkable(self) -> bool:
        return CELL_PROPERTIES[self.cell_type]["walkable"]
    
    @property
    def is_destructible(self) -> bool:
        return CELL_PROPERTIES[self.cell_type]["destructible"]
    
    @property
    def blocks_attack(self) -> bool:
        return CELL_PROPERTIES[self.cell_type]["blocks_attack"]
    
    def take_damage(self, damage: int) -> Tuple[bool, Optional[CellType]]:
        """
        Apply damage to cell. Returns (destroyed, revealed_type).
        revealed_type is only set for power blocks.
        """
        if not self.is_destructible:
            return False, None
        
        self.hp -= damage
        
        if self.hp <= 0:
            # Check if it was a power block
            revealed = None
            if self.cell_type == CellType.BLOCK_POWER:
                # Reveal a random power tile
                revealed = random.choice([
                    CellType.POWER_ATTACK,
                    CellType.POWER_MOVE,
                    CellType.POWER_SHIELD
                ])
            
            self.cell_type = CellType.EMPTY
            self.hp = 0
            return True, revealed
        
        return False, None


class HexBoard:
    """
    The main game board using a 5-ring hexagonal grid (91 cells).
    """
    
    def __init__(self, rings: int = 5):
        self.rings = rings
        self.center = HexCoord(0, 0)
        self.cells: Dict[HexCoord, Cell] = {}
        self._generate_empty_board()
    
    def _generate_empty_board(self):
        """Create empty hex board"""
        coords = generate_hex_board(self.rings, self.center)
        for coord in coords:
            cell_type = CellType.CENTER if coord == self.center else CellType.EMPTY
            self.cells[coord] = Cell(coord, cell_type)
    
    def is_valid(self, pos: HexCoord) -> bool:
        """Check if position is on the board"""
        return pos in self.cells
    
    def is_walkable(self, pos: HexCoord) -> bool:
        """Check if a tank can move to this position"""
        if not self.is_valid(pos):
            return False
        return self.cells[pos].is_walkable
    
    def get_cell(self, pos: HexCoord) -> Optional[Cell]:
        """Get cell at position"""
        return self.cells.get(pos)
    
    def set_cell(self, pos: HexCoord, cell_type: CellType, hp: int = 0):
        """Set cell type at position"""
        if pos in self.cells:
            self.cells[pos] = Cell(pos, cell_type, hp)
    
    def apply_damage(self, pos: HexCoord, damage: int) -> Tuple[bool, Optional[CellType]]:
        """Apply damage to a cell, returns (destroyed, revealed_power)"""
        cell = self.get_cell(pos)
        if cell and cell.is_destructible:
            destroyed, revealed = cell.take_damage(damage)
            if destroyed and revealed:
                # Place the revealed power tile
                self.cells[pos] = Cell(pos, revealed)
            return destroyed, revealed
        return False, None
    
    def get_power_tile(self, pos: HexCoord) -> Optional[CellType]:
        """Get power tile type at position (if any)"""
        cell = self.get_cell(pos)
        if cell and cell.cell_type in {CellType.POWER_ATTACK, CellType.POWER_MOVE, CellType.POWER_SHIELD}:
            return cell.cell_type
        return None
    
    def consume_power_tile(self, pos: HexCoord):
        """Remove power tile after pickup"""
        if self.get_power_tile(pos):
            self.cells[pos] = Cell(pos, CellType.EMPTY)
    
    def copy(self) -> HexBoard:
        """Create a deep copy of the board"""
        new_board = HexBoard(self.rings)
        for pos, cell in self.cells.items():
            new_board.cells[pos] = Cell(pos, cell.cell_type, cell.hp)
        return new_board
    
    def get_all_coords(self) -> List[HexCoord]:
        """Get all valid coordinates on the board"""
        return list(self.cells.keys())
    
    def count_cells_by_type(self, cell_type: CellType) -> int:
        """Count cells of a specific type"""
        return sum(1 for cell in self.cells.values() if cell.cell_type == cell_type)


class MapGenerator:
    """
    Generates pre-designed maps for the game.
    All maps are symmetric for fair play.
    """
    
    @staticmethod
    def create_standard_map(board: HexBoard) -> HexBoard:
        """
        Create a simple balanced map with minimal obstacles.
        - Few strategic blocks
        - Symmetric for fair play (point symmetry around center)
        """
        
        # === WALLS (Indestructible) - 4 walls ===
        walls = [
            # Block direct vertical path to center
            HexCoord(0, 2), HexCoord(0, -2),
            # Side chokepoints
            HexCoord(2, -1), HexCoord(-2, 1),
        ]
        
        # === NORMAL BLOCKS (HP 2) - 3 blocks ===
        normal_blocks = [
            # Near center
            HexCoord(1, 1), HexCoord(-1, -1),
            HexCoord(0, 3), HexCoord(0, -3),
        ]
        
        # === ARMOR BLOCKS (HP 3) - 2 blocks ===
        armor_blocks = [
            # Guard flanks
            HexCoord(2, 1), HexCoord(-2, -1),
        ]
        
        # === POWER BLOCKS (HP 2, reveal power tile) - 2 blocks ===
        power_blocks = [
            HexCoord(3, 0), HexCoord(-3, 0),
        ]
        
        # === POWER TILES (Direct placement) - 4 tiles ===
        power_tiles = [
            # Attack buff
            (HexCoord(2, -2), CellType.POWER_ATTACK),
            (HexCoord(-2, 2), CellType.POWER_ATTACK),
            
            # Shield buff
            (HexCoord(-3, 4), CellType.POWER_SHIELD),
            (HexCoord(3, -4), CellType.POWER_SHIELD),
        ]
        
        # Apply to board
        for pos in walls:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.WALL)
        
        for pos in normal_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_NORMAL)
        
        for pos in armor_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_ARMOR)
        
        for pos in power_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_POWER)
        
        for pos, tile_type in power_tiles:
            if board.is_valid(pos):
                board.set_cell(pos, tile_type)
        
        return board
    
    @staticmethod
    def create_open_map(board: HexBoard) -> HexBoard:
        """Create a more open map with fewer obstacles"""
        
        walls = [
            HexCoord(3, -2), HexCoord(-3, 2),
            HexCoord(2, 2), HexCoord(-2, -2),
        ]
        
        normal_blocks = [
            HexCoord(1, 0), HexCoord(-1, 0),
            HexCoord(0, 1), HexCoord(0, -1),
        ]
        
        power_tiles = [
            (HexCoord(2, -1), CellType.POWER_MOVE),
            (HexCoord(-2, 1), CellType.POWER_MOVE),
            (HexCoord(1, 2), CellType.POWER_ATTACK),
            (HexCoord(-1, -2), CellType.POWER_ATTACK),
        ]
        
        for pos in walls:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.WALL)
        
        for pos in normal_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_NORMAL)
        
        for pos, tile_type in power_tiles:
            if board.is_valid(pos):
                board.set_cell(pos, tile_type)
        
        return board
    
    @staticmethod
    def create_fortress_map(board: HexBoard) -> HexBoard:
        """Create a map with more defensive positions"""
        
        walls = [
            HexCoord(1, -2), HexCoord(-1, 2),
            HexCoord(2, 1), HexCoord(-2, -1),
            HexCoord(-1, -1), HexCoord(1, 1),
        ]
        
        armor_blocks = [
            HexCoord(2, 0), HexCoord(-2, 0),
            HexCoord(0, 2), HexCoord(0, -2),
            HexCoord(1, 0), HexCoord(-1, 0),
            HexCoord(0, 1), HexCoord(0, -1),
        ]
        
        power_blocks = [
            HexCoord(3, 0), HexCoord(-3, 0),
            HexCoord(0, 3), HexCoord(0, -3),
        ]
        
        power_tiles = [
            (HexCoord(4, -2), CellType.POWER_SHIELD),
            (HexCoord(-4, 2), CellType.POWER_SHIELD),
        ]
        
        for pos in walls:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.WALL)
        
        for pos in armor_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_ARMOR)
        
        for pos in power_blocks:
            if board.is_valid(pos):
                board.set_cell(pos, CellType.BLOCK_POWER)
        
        for pos, tile_type in power_tiles:
            if board.is_valid(pos):
                board.set_cell(pos, tile_type)
        
        return board


def create_game_board(map_type: str = "standard") -> HexBoard:
    """Factory function to create a game board with a specific map"""
    board = HexBoard(rings=5)
    
    if map_type == "standard":
        return MapGenerator.create_standard_map(board)
    elif map_type == "open":
        return MapGenerator.create_open_map(board)
    elif map_type == "fortress":
        return MapGenerator.create_fortress_map(board)
    else:
        return board  # Empty board
