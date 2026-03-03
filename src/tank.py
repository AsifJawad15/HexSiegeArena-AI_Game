"""
Tank classes for Hex Siege Arena.
Implements Qtank (Queen) and Ktank (King) with their unique abilities.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional, List

from .hex_coord import HexCoord


class BuffType(Enum):
    """Power-up buff types"""
    NONE = auto()
    ATTACK_X2 = auto()   # Double damage on next attack
    SHIELD = auto()       # Block next 2 damage instances


class TankType(Enum):
    """Tank types"""
    QTANK = auto()  # Queen - long range, laser attack
    KTANK = auto()  # King - area control, bomb attack


@dataclass
class Tank:
    """Base tank class with common functionality"""
    pos: HexCoord
    hp: int
    max_hp: int
    tank_type: TankType
    player: int  # 1 or 2
    buff: BuffType = BuffType.NONE
    shield_charges: int = 0
    
    def take_damage(self, damage: int) -> int:
        """
        Apply damage to tank. Returns actual damage dealt.
        Shield blocks damage instances.
        """
        if self.shield_charges > 0:
            self.shield_charges -= 1
            if self.shield_charges == 0:
                self.buff = BuffType.NONE
            return 0  # Damage blocked
        
        actual_damage = min(damage, self.hp)
        self.hp -= actual_damage
        return actual_damage
    
    def heal(self, amount: int):
        """Heal the tank (capped at max HP)"""
        self.hp = min(self.hp + amount, self.max_hp)
    
    def is_alive(self) -> bool:
        """Check if tank is still alive"""
        return self.hp > 0
    
    def apply_buff(self, buff: BuffType):
        """Apply a buff, replacing any existing buff"""
        self.buff = buff
        if buff == BuffType.SHIELD:
            self.shield_charges = 2
        else:
            self.shield_charges = 0
    
    def consume_attack_buff(self):
        """Consume attack buff after use"""
        if self.buff == BuffType.ATTACK_X2:
            self.buff = BuffType.NONE
    
    def get_base_damage(self) -> int:
        """Get base attack damage (before buffs)"""
        raise NotImplementedError
    
    def get_attack_damage(self) -> int:
        """Get attack damage with buffs applied"""
        base = self.get_base_damage()
        if self.buff == BuffType.ATTACK_X2:
            return base * 2
        return base
    
    def get_move_range(self) -> int:
        """Get maximum move distance"""
        raise NotImplementedError
    
    def copy(self) -> Tank:
        """Create a copy of this tank"""
        raise NotImplementedError


@dataclass
class Qtank(Tank):
    """
    Queen Tank - Long-range control & precision damage
    - HP: 8
    - Movement: Unlimited in straight line (like chess queen on hex)
    - Attack: Laser - 2 damage, travels until first collision
    """
    
    def __init__(self, pos: HexCoord, player: int):
        super().__init__(
            pos=pos,
            hp=8,
            max_hp=8,
            tank_type=TankType.QTANK,
            player=player
        )
    
    def get_base_damage(self) -> int:
        return 2
    
    def get_move_range(self) -> int:
        return 50  # Effectively unlimited
    
    def copy(self) -> Qtank:
        new_tank = Qtank(self.pos, self.player)
        new_tank.hp = self.hp
        new_tank.buff = self.buff
        new_tank.shield_charges = self.shield_charges
        return new_tank


@dataclass
class Ktank(Tank):
    """
    King Tank - Area control & objective unit
    - HP: 10
    - Movement: Up to 2 cells in straight line
    - Attack: Bomb - 3 damage to all 6 adjacent cells
    - Win condition: Reach center to win
    """
    
    def __init__(self, pos: HexCoord, player: int):
        super().__init__(
            pos=pos,
            hp=10,
            max_hp=10,
            tank_type=TankType.KTANK,
            player=player
        )
    
    def get_base_damage(self) -> int:
        return 3
    
    def get_move_range(self) -> int:
        return 2
    
    def copy(self) -> Ktank:
        new_tank = Ktank(self.pos, self.player)
        new_tank.hp = self.hp
        new_tank.buff = self.buff
        new_tank.shield_charges = self.shield_charges
        return new_tank


def create_tank(tank_type: TankType, pos: HexCoord, player: int) -> Tank:
    """Factory function to create tanks"""
    if tank_type == TankType.QTANK:
        return Qtank(pos, player)
    elif tank_type == TankType.KTANK:
        return Ktank(pos, player)
    else:
        raise ValueError(f"Unknown tank type: {tank_type}")


# Starting positions for each player - at hexagon vertex corners
# 5-ring hex vertices: (0,-5), (5,-5), (5,0), (0,5), (-5,5), (-5,0)
# Player 1 (Red): Bottom side - King at bottom vertex
# Player 2 (Blue): Top side - King at top vertex
STARTING_POSITIONS = {
    1: {
        TankType.QTANK: HexCoord(-5, 5),   # Bottom-left vertex
        TankType.KTANK: HexCoord(0, 5),    # Bottom vertex (center-bottom)
    },
    2: {
        TankType.QTANK: HexCoord(5, -5),   # Top-right vertex
        TankType.KTANK: HexCoord(0, -5),   # Top vertex (center-top)
    }
}


def get_starting_positions(player: int) -> dict:
    """Get starting positions for a player's tanks"""
    return STARTING_POSITIONS[player]
