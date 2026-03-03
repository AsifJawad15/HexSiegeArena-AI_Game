"""
Hex Coordinate System using Axial Coordinates
Provides all hex-related calculations and utilities.
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import List, Tuple
import math


# Six directions in axial coordinates (clockwise from East)
HEX_DIRECTIONS = [
    (1, 0),   # East
    (1, -1),  # Northeast
    (0, -1),  # Northwest
    (-1, 0),  # West
    (-1, 1),  # Southwest
    (0, 1),   # Southeast
]

DIRECTION_NAMES = ["E", "NE", "NW", "W", "SW", "SE"]


@dataclass(frozen=True, slots=True)
class HexCoord:
    """
    Axial coordinate system for hexagonal grids.
    q = column, r = row
    """
    q: int
    r: int
    
    def __add__(self, other: HexCoord) -> HexCoord:
        return HexCoord(self.q + other.q, self.r + other.r)
    
    def __sub__(self, other: HexCoord) -> HexCoord:
        return HexCoord(self.q - other.q, self.r - other.r)
    
    def __mul__(self, scalar: int) -> HexCoord:
        return HexCoord(self.q * scalar, self.r * scalar)
    
    def __hash__(self) -> int:
        return hash((self.q, self.r))
    
    @property
    def s(self) -> int:
        """Third cube coordinate (q + r + s = 0)"""
        return -self.q - self.r
    
    def distance(self, other: HexCoord) -> int:
        """Calculate hex distance between two coordinates"""
        dq = abs(self.q - other.q)
        dr = abs(self.r - other.r)
        ds = abs(self.s - other.s)
        return max(dq, dr, ds)
    
    def neighbors(self) -> List[HexCoord]:
        """Get all 6 adjacent hex cells"""
        return [self.neighbor(i) for i in range(6)]
    
    def neighbor(self, direction: int) -> HexCoord:
        """Get neighbor in specific direction (0-5)"""
        dq, dr = HEX_DIRECTIONS[direction % 6]
        return HexCoord(self.q + dq, self.r + dr)
    
    def direction_to(self, other: HexCoord) -> int:
        """Find direction index toward another hex (approximate)"""
        dq = other.q - self.q
        dr = other.r - self.r
        
        # Normalize to find closest direction
        angle = math.atan2(dr - dq * 0.5, dq * math.sqrt(3) / 2)
        direction = int(round(-angle / (math.pi / 3))) % 6
        return direction
    
    def raycast(self, direction: int, max_range: int = 50) -> List[HexCoord]:
        """
        Get all cells in a straight line from this position.
        Used for Qtank movement and laser attacks.
        """
        dq, dr = HEX_DIRECTIONS[direction % 6]
        path = []
        current = self
        
        for _ in range(max_range):
            current = HexCoord(current.q + dq, current.r + dr)
            path.append(current)
        
        return path
    
    def line_to(self, other: HexCoord) -> List[HexCoord]:
        """Get all cells in a line from this to other (inclusive)"""
        n = self.distance(other)
        if n == 0:
            return [self]
        
        results = []
        for i in range(n + 1):
            t = i / n
            q = round(self.q + (other.q - self.q) * t)
            r = round(self.r + (other.r - self.r) * t)
            results.append(HexCoord(q, r))
        
        return results
    
    def to_pixel(self, size: float, offset: Tuple[float, float] = (0, 0)) -> Tuple[float, float]:
        """Convert hex coordinates to pixel coordinates (pointy-top)"""
        x = size * (math.sqrt(3) * self.q + math.sqrt(3) / 2 * self.r)
        y = size * (3 / 2 * self.r)
        return (x + offset[0], y + offset[1])
    
    @staticmethod
    def from_pixel(x: float, y: float, size: float, 
                   offset: Tuple[float, float] = (0, 0)) -> HexCoord:
        """Convert pixel coordinates to hex coordinates"""
        x -= offset[0]
        y -= offset[1]
        
        q = (math.sqrt(3) / 3 * x - 1 / 3 * y) / size
        r = (2 / 3 * y) / size
        
        return HexCoord.round_hex(q, r)
    
    @staticmethod
    def round_hex(q: float, r: float) -> HexCoord:
        """Round fractional hex coordinates to nearest hex"""
        s = -q - r
        
        rq = round(q)
        rr = round(r)
        rs = round(s)
        
        q_diff = abs(rq - q)
        r_diff = abs(rr - r)
        s_diff = abs(rs - s)
        
        if q_diff > r_diff and q_diff > s_diff:
            rq = -rr - rs
        elif r_diff > s_diff:
            rr = -rq - rs
        
        return HexCoord(int(rq), int(rr))
    
    def get_ring(self, radius: int) -> List[HexCoord]:
        """Get all hexes at exactly 'radius' distance"""
        if radius == 0:
            return [self]
        
        results = []
        current = HexCoord(self.q - radius, self.r + radius)
        
        for direction in range(6):
            for _ in range(radius):
                results.append(current)
                current = current.neighbor(direction)
        
        return results
    
    def get_spiral(self, radius: int) -> List[HexCoord]:
        """Get all hexes within radius (including center)"""
        results = [self]
        for r in range(1, radius + 1):
            results.extend(self.get_ring(r))
        return results


def generate_hex_board(rings: int, center: HexCoord = HexCoord(0, 0)) -> List[HexCoord]:
    """Generate all coordinates for a hex board with given number of rings"""
    return center.get_spiral(rings)


def hex_corner(center: Tuple[float, float], size: float, i: int) -> Tuple[float, float]:
    """Get the pixel position of a hex corner (pointy-top orientation)"""
    angle_deg = 60 * i - 30
    angle_rad = math.pi / 180 * angle_deg
    return (
        center[0] + size * math.cos(angle_rad),
        center[1] + size * math.sin(angle_rad)
    )


def get_hex_vertices(center: Tuple[float, float], size: float) -> List[Tuple[float, float]]:
    """Get all 6 vertices of a hexagon for drawing"""
    return [hex_corner(center, size, i) for i in range(6)]
