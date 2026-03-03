"""
Hex Siege Arena — Game View  (Phase 3: Hex Grid Visual Polish)
Core gameplay view: GPU-batched hex grid via ShapeElementList, rich
cell-type colours, mouse hover highlight, persistent arcade.Text HUD.
"""

from __future__ import annotations

import math
import time
import threading
import copy
from typing import Optional, List, Dict, Tuple

import arcade
import arcade.gui
from arcade.shape_list import (
    ShapeElementList,
    create_polygon,
    create_line_loop,
)

from ..app import SCREEN_WIDTH, SCREEN_HEIGHT, PROJECT_ROOT, FONT_NAME
from ..game_state import GameState, Action, ActionType, GameEvent
from ..board import CellType
from ..tank import Tank, TankType, BuffType
from ..hex_coord import HexCoord
from ..ai import create_ai, MinimaxAI
from ..sprites import TankSprite
from ..effects import EffectsManager
from ..sounds import get_sound_manager as _sfx
from ..settings import get_settings as _cfg
from ..ui.combat_log import CombatLog
from ..hex_renderer import hex_texture, glow_texture, vignette_texture


# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------
HEX_SIZE = 38                      # outer radius in px
BOARD_OFFSET_X = SCREEN_WIDTH // 2
BOARD_OFFSET_Y = SCREEN_HEIGHT // 2

# -- Per-cell-type fill colours (RGBA) --
COLOR_BG              = (18, 22, 28)
COLOR_HEX_EMPTY       = (38, 48, 56, 255)
COLOR_HEX_WALL        = (72, 72, 82, 255)
COLOR_HEX_CENTER      = (180, 140, 40, 255)
COLOR_HEX_BLOCK_NORM  = (75, 65, 55, 255)
COLOR_HEX_BLOCK_ARMOR = (90, 80, 70, 255)
COLOR_HEX_BLOCK_POWER = (65, 55, 80, 255)
COLOR_HEX_POWER_ATK   = (120, 45, 45, 255)
COLOR_HEX_POWER_MOV   = (45, 110, 55, 255)
COLOR_HEX_POWER_SHL   = (50, 90, 140, 255)
COLOR_HEX_LINE        = (55, 65, 72, 255)
COLOR_HEX_HOVER       = (255, 255, 255, 35)

# -- UI / overlay --
COLOR_P1          = (80, 160, 255)
COLOR_P2          = (255, 80, 80)
COLOR_SELECT      = (255, 255, 100)
COLOR_MOVE_HINT   = (100, 255, 100, 90)
COLOR_ATK_HINT    = (255, 80, 80, 90)
COLOR_HP_BG       = (40, 40, 40, 180)
COLOR_HP_GREEN    = (80, 220, 80)
COLOR_HP_RED      = (220, 60, 60)

# -- Batch 3: interaction preview colours --
COLOR_GHOST_FILL  = (255, 255, 255, 40)     # faint hex fill for ghost tank
COLOR_PATH_LINE   = (180, 255, 180, 140)    # path line, greenish
COLOR_PATH_DOT    = (180, 255, 180, 200)    # waypoint dots on path
COLOR_LASER_PREV  = (255, 100, 100, 100)    # laser preview beam
COLOR_LASER_CROSS = (255, 120, 120, 180)    # laser crosshair
COLOR_BOMB_FILL   = (255, 60, 30, 45)       # AoE zone fill
COLOR_BOMB_LINE   = (255, 80, 40, 120)      # AoE zone outline

HUD_HEIGHT = 50

# Map CellType → fill colour
_CELL_COLORS: Dict[CellType, Tuple[int, ...]] = {
    CellType.EMPTY:        COLOR_HEX_EMPTY,
    CellType.WALL:         COLOR_HEX_WALL,
    CellType.CENTER:       COLOR_HEX_CENTER,
    CellType.BLOCK_NORMAL: COLOR_HEX_BLOCK_NORM,
    CellType.BLOCK_ARMOR:  COLOR_HEX_BLOCK_ARMOR,
    CellType.BLOCK_POWER:  COLOR_HEX_BLOCK_POWER,
    CellType.POWER_ATTACK: COLOR_HEX_POWER_ATK,
    CellType.POWER_MOVE:   COLOR_HEX_POWER_MOV,
    CellType.POWER_SHIELD: COLOR_HEX_POWER_SHL,
}

# Power-up cell symbols (Unicode)
_CELL_SYMBOL: Dict[CellType, str] = {
    CellType.POWER_ATTACK: "\u2694",   # ⚔
    CellType.POWER_MOVE:   "\u27A4",   # ➤
    CellType.POWER_SHIELD: "\u2764",   # ❤
    CellType.CENTER:       "\u2605",   # ★
}

# Tank role mapping
_ROLE = {TankType.KTANK: "king", TankType.QTANK: "queen"}


class GameView(arcade.View):
    """Main gameplay view with sprite-based tank rendering."""

    def __init__(self):
        super().__init__()

        # Game state (created in on_show_view)
        self.state: Optional[GameState] = None
        self.ai_player1: Optional[MinimaxAI] = None
        self.ai_player2: Optional[MinimaxAI] = None

        # Interaction state
        self.selected_tank: Optional[Tank] = None
        self.action_mode: Optional[str] = None  # "move" | "attack" | None
        self.legal_actions: List[Action] = []
        self.filtered_actions: List[Action] = []

        # Animation / AI timing
        self.last_ai_time: float = 0.0
        self.ai_delay: float = 0.3

        # Threaded AI computation
        self._ai_thinking: bool = False
        self._ai_result: Optional[Action] = None
        self._ai_thread: Optional[threading.Thread] = None

        # Camera
        self.camera = arcade.camera.Camera2D()

        # -- Batch 6: Camera controls (zoom, pan, cinematic) --
        self._zoom_level: float = 1.0
        self._zoom_target: float = 1.0
        self._pan_x: float = 0.0
        self._pan_y: float = 0.0
        self._pan_target_x: float = 0.0
        self._pan_target_y: float = 0.0
        self._mid_drag: bool = False
        # Cinematic camera (brief focus on AI attacks)
        self._cine_active: bool = False
        self._cine_timer: float = 0.0
        self._cine_duration: float = 0.0
        self._cine_saved_pan: Tuple[float, float] = (0.0, 0.0)
        self._cine_saved_zoom: float = 1.0

        # Hex positions  { HexCoord: (px, py) }
        self._hex_pixels: Dict[HexCoord, Tuple[float, float]] = {}

        # Tank sprites  {(player, TankType): TankSprite}
        self._tank_sprites: Dict[Tuple[int, TankType], TankSprite] = {}

        # Effects
        self.effects = EffectsManager()

        # Animation lock — block input while effects are playing
        self._anim_lock: bool = False
        self._pending_game_over: Optional[Tuple[Optional[int], str]] = None

        # -- Phase 3: GPU-batched hex grid --
        self._hex_shapes: Optional[ShapeElementList] = None
        self._board_snapshot: Optional[str] = None   # fast dirty-check

        # -- Batch 2: Board materials & lighting --
        self._hex_gradient_sprites: Optional[arcade.SpriteList] = None
        self._glow_sprites: Optional[arcade.SpriteList] = None
        self._glow_time: float = 0.0   # for pulsing glow animation
        self._vignette_sprite: Optional[arcade.SpriteList] = None
        self._inner_highlight: Optional[ShapeElementList] = None

        # Hover state
        self._hover_hex: Optional[HexCoord] = None

        # -- Phase 3: Persistent HUD Text objects --
        self._txt_turn: Optional[arcade.Text] = None
        self._txt_turn_count: Optional[arcade.Text] = None
        self._txt_mode: Optional[arcade.Text] = None
        self._txt_tanks: List[arcade.Text] = []
        self._txt_help: Optional[arcade.Text] = None
        # Cell label texts (HP numbers, symbols)
        self._cell_labels: List[arcade.Text] = []

        # -- Phase 7: UI/UX enhancements --
        self._ai_think_time: float = 0.0       # elapsed time while AI thinks
        self._txt_ai_think: Optional[arcade.Text] = None

        self._turn_banner_timer: float = 0.0   # countdown for turn banner
        self._turn_banner_text: str = ""
        self._turn_banner_color: Tuple[int, ...] = (255, 255, 255)
        self._banner_slide_x: float = 0.0      # slide-in offset (starts at 300, lerps to 0)
        self._last_player: int = 0             # detect turn changes

        self._txt_select_info: Optional[arcade.Text] = None  # selected tank panel

        # -- Phase 9: Combat log --
        self._combat_log: Optional[CombatLog] = None

        # -- Phase 10: Help overlay & Minimap --
        self._show_help: bool = False
        self._help_texts: List[arcade.Text] = []
        self._minimap_enabled: bool = _cfg()["show_minimap"]

        # -- Batch 7: Hex tooltip --
        self._tooltip_text: Optional[arcade.Text] = None

        # -- Batch 7: Confirm dialog (restart / quit) --
        self._confirm_action: Optional[str] = None   # "restart" | "quit" | None
        self._confirm_texts: List[arcade.Text] = []

        # -- Batch 7: Per-player match performance tracking --
        self._match_stats: Dict[str, Dict[str, int]] = {
            "p1": {"damage_dealt": 0, "moves": 0, "attacks": 0,
                   "blocks_destroyed": 0, "pickups": 0},
            "p2": {"damage_dealt": 0, "moves": 0, "attacks": 0,
                   "blocks_destroyed": 0, "pickups": 0},
        }

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def on_show_view(self):
        arcade.set_background_color(COLOR_BG)
        settings = self.window.game_settings

        # Fresh game state
        self.state = GameState(map_type=settings["map_type"])
        self.legal_actions = self.state.get_legal_actions()

        # AI
        mode = settings["game_mode"]
        diff = settings["ai_difficulty"]
        self.ai_player1 = None
        self.ai_player2 = None
        if mode == "pve":
            self.ai_player2 = create_ai(diff)
        elif mode == "ai_vs_ai":
            self.ai_player1 = create_ai(diff)
            self.ai_player2 = create_ai(diff)

        # Hex pixel positions
        self._hex_pixels = {}
        for hc in self.state.board.cells:
            px, py = hc.to_pixel(HEX_SIZE)
            self._hex_pixels[hc] = (px + BOARD_OFFSET_X, py + BOARD_OFFSET_Y)

        # Build GPU-batched hex grid
        self._rebuild_hex_shapes()

        # Build tank sprites
        self._build_tank_sprites()

        # Create HUD Text objects (only once)
        self._init_hud_texts()

        self.last_ai_time = time.time()
        self._anim_lock = False
        self._pending_game_over = None
        self._hover_hex = None

        # Phase 7: reset UI state
        self._ai_think_time = 0.0
        self._turn_banner_timer = 0.0
        self._last_player = self.state.current_player

        # Phase 9: combat log
        self._combat_log = CombatLog(SCREEN_WIDTH, SCREEN_HEIGHT, HUD_HEIGHT)

        # Batch 7: reset match stats
        self._match_stats = {
            "p1": {"damage_dealt": 0, "moves": 0, "attacks": 0,
                   "blocks_destroyed": 0, "pickups": 0},
            "p2": {"damage_dealt": 0, "moves": 0, "attacks": 0,
                   "blocks_destroyed": 0, "pickups": 0},
        }
        self._confirm_action = None
        self._confirm_texts = []
        self._tooltip_text = None

        # Batch 6: reset camera state
        self._zoom_level = 1.0
        self._zoom_target = 1.0
        self._pan_x = 0.0
        self._pan_y = 0.0
        self._pan_target_x = 0.0
        self._pan_target_y = 0.0
        self._cine_active = False
        self._mid_drag = False

        # Batch 2: vignette overlay (generated once)
        vtex = vignette_texture(SCREEN_WIDTH, SCREEN_HEIGHT, strength=0.40)
        vs = arcade.Sprite(vtex, scale=1.0)
        vs.position = (SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
        self._vignette_sprite = arcade.SpriteList()
        self._vignette_sprite.append(vs)
        self._glow_time = 0.0

    def on_hide_view(self):
        pass

    def on_resize(self, width: int, height: int):
        """Batch 6: Keep camera viewport in sync when window is resized."""
        super().on_resize(width, height)
        self.camera.match_window()

    # ------------------------------------------------------------------
    # GPU-batched hex grid
    # ------------------------------------------------------------------
    def _board_hash(self) -> str:
        """Cheap fingerprint of board state (cell types + hp)."""
        if self.state is None:
            return ""
        parts = []
        for hc in sorted(self._hex_pixels, key=lambda h: (h.q, h.r)):
            cell = self.state.board.get_cell(hc)
            if cell:
                parts.append(f"{hc.q},{hc.r}:{cell.cell_type.value}:{cell.hp}")
        return "|".join(parts)

    def _rebuild_hex_shapes(self):
        """Build (or rebuild) the ShapeElementList + overlay sprites for the hex grid."""
        snap = self._board_hash()
        if self._hex_shapes is not None and snap == self._board_snapshot:
            return  # nothing changed
        self._board_snapshot = snap

        shape_list = ShapeElementList()
        highlight_shapes = ShapeElementList()
        grad_sprites = arcade.SpriteList()
        glow_sprites = arcade.SpriteList()
        self._cell_labels = []

        if self.state is None:
            self._hex_shapes = shape_list
            self._inner_highlight = highlight_shapes
            self._hex_gradient_sprites = grad_sprites
            self._glow_sprites = glow_sprites
            return

        # Glow colour map for special cells
        _GLOW_COLORS = {
            CellType.CENTER:       (220, 180, 50),
            CellType.POWER_ATTACK: (255, 80, 80),
            CellType.POWER_MOVE:   (80, 220, 100),
            CellType.POWER_SHIELD: (80, 160, 255),
        }

        board = self.state.board
        for hc, (px, py) in self._hex_pixels.items():
            cell = board.get_cell(hc)
            if cell is None:
                continue
            ct = cell.cell_type
            fill = _CELL_COLORS.get(ct, COLOR_HEX_EMPTY)

            corners = self._hex_corners(px, py, HEX_SIZE - 2)
            shape_list.append(create_polygon(corners, fill))
            shape_list.append(create_line_loop(corners, COLOR_HEX_LINE, 1))

            # Inner highlight bevel (lighter inner edge for depth)
            inner_corners = self._hex_corners(px, py, HEX_SIZE - 4)
            r, g, b = fill[0], fill[1], fill[2]
            hi_color = (min(255, r + 30), min(255, g + 30), min(255, b + 30), 45)
            highlight_shapes.append(create_line_loop(inner_corners, hi_color, 1))

            # Gradient overlay sprite (radial: brighter center → darker edge)
            tex = hex_texture(fill, size=HEX_SIZE, key=f"{ct.value}",
                              highlight=0.15, darken_edge=0.20)
            gs = arcade.Sprite(tex, scale=1.0)
            gs.position = (px, py)
            gs.alpha = 160  # blend over flat fill
            grad_sprites.append(gs)

            # Glow underlay for special cells
            gcol = _GLOW_COLORS.get(ct)
            if gcol:
                glow_size = HEX_SIZE + 16 if ct == CellType.CENTER else HEX_SIZE + 10
                gtex = glow_texture(gcol, size=glow_size, alpha_peak=50)
                gsp = arcade.Sprite(gtex, scale=1.0)
                gsp.position = (px, py)
                glow_sprites.append(gsp)

            # Block HP indicator
            if ct in (CellType.BLOCK_NORMAL, CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
                hp_text = arcade.Text(
                    str(cell.hp), px, py,
                    color=(200, 200, 200, 160),
                    font_size=11, anchor_x="center", anchor_y="center",
                    bold=True, font_name=FONT_NAME,
                )
                self._cell_labels.append(hp_text)

            # Power-up / center symbol
            sym = _CELL_SYMBOL.get(ct)
            if sym:
                sym_color = {
                    CellType.POWER_ATTACK: (255, 100, 100, 200),
                    CellType.POWER_MOVE:   (100, 255, 120, 200),
                    CellType.POWER_SHIELD: (100, 180, 255, 200),
                    CellType.CENTER:       (255, 220, 80, 220),
                }.get(ct, (200, 200, 200, 200))
                sym_text = arcade.Text(
                    sym, px, py,
                    color=sym_color,
                    font_size=14, anchor_x="center", anchor_y="center",
                    font_name=FONT_NAME,
                )
                self._cell_labels.append(sym_text)

        self._hex_shapes = shape_list
        self._inner_highlight = highlight_shapes
        self._hex_gradient_sprites = grad_sprites
        self._glow_sprites = glow_sprites

    # ------------------------------------------------------------------
    # HUD Text objects (created once, updated each frame)
    # ------------------------------------------------------------------
    def _init_hud_texts(self):
        # -- Top bar (50px) ------------------------------------------------
        bar_mid = SCREEN_HEIGHT - HUD_HEIGHT // 2   # vertical centre of bar

        # Left zone: turn indicator
        self._txt_turn = arcade.Text(
            "", 16, bar_mid + 4,
            COLOR_P1, 18, bold=True, font_name=FONT_NAME,
            anchor_y="center",
        )
        self._txt_turn_count = arcade.Text(
            "", 16, bar_mid - 14,
            arcade.color.LIGHT_GRAY, 11, font_name=FONT_NAME,
            anchor_y="center",
        )

        # Centre zone: mode indicator + king distance
        self._txt_mode = arcade.Text(
            "", SCREEN_WIDTH // 2, bar_mid + 4,
            COLOR_SELECT, 14, anchor_x="center", anchor_y="center",
            bold=True, font_name=FONT_NAME,
        )
        self._txt_kdist = arcade.Text(
            "", SCREEN_WIDTH // 2, bar_mid - 14,
            (160, 160, 170), 11, anchor_x="center", anchor_y="center",
            font_name=FONT_NAME,
        )

        # Right zone: compact tank HP readouts (tighter spacing)
        self._txt_tanks = []
        x_off = SCREEN_WIDTH - 340
        for pl in [1, 2]:
            for tt in [TankType.KTANK, TankType.QTANK]:
                pc = COLOR_P1 if pl == 1 else COLOR_P2
                t = arcade.Text("", x_off, bar_mid, pc, 12,
                                font_name=FONT_NAME, anchor_y="center")
                self._txt_tanks.append(t)
                x_off += 84

        # -- Bottom bar (28px) — hint strip --------------------------------
        self._txt_help = arcade.Text(
            "M=Move  A=Attack  P=Pass  1/2=Queen/King  Scroll=Zoom  Arrows=Pan  Home=Reset  H=Help",
            SCREEN_WIDTH // 2, 14,
            (140, 140, 150), 11, anchor_x="center", font_name=FONT_NAME,
        )

        # -- Floating elements ---------------------------------------------
        self._txt_ai_think = arcade.Text(
            "", SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 200,
            (200, 200, 210, 200), 16, anchor_x="center", bold=True,
            font_name=FONT_NAME,
        )
        self._txt_banner = arcade.Text(
            "", 0, 0,
            (255, 255, 255, 220), 18, anchor_x="center", anchor_y="center",
            bold=True, font_name=FONT_NAME,
        )
        # Left sidebar: selected tank detail
        self._txt_select_info = arcade.Text(
            "", 20, SCREEN_HEIGHT - HUD_HEIGHT - 160,
            (200, 200, 210), 12, multiline=True, width=220, font_name=FONT_NAME,
        )

    # ------------------------------------------------------------------
    # Tank sprite management
    # ------------------------------------------------------------------
    def _build_tank_sprites(self):
        """Create TankSprite objects for every living tank."""
        self._tank_sprites.clear()
        if self.state is None:
            return

        for tank in self.state.get_all_tanks():
            if not tank.is_alive():
                continue
            role = _ROLE[tank.tank_type]
            ts = TankSprite(player=tank.player, role=role, scale=0.26)
            self._tank_sprites[(tank.player, tank.tank_type)] = ts

        self._sync_tank_positions()

    def _sync_tank_positions(self, animate: bool = False):
        """Move every TankSprite to its logical board position.

        *animate*: if True, use smooth lerp instead of instant teleport.
        """
        if self.state is None:
            return
        for (player, tt), ts in list(self._tank_sprites.items()):
            tank = self.state.get_tank(player, tt)
            if not tank.is_alive():
                self._tank_sprites.pop((player, tt), None)
                continue
            if tank.pos in self._hex_pixels:
                px, py = self._hex_pixels[tank.pos]
                if animate:
                    ts.move_to(px, py, duration=0.55)
                else:
                    ts.place(px, py, angle_deg=0)

    # ------------------------------------------------------------------
    # Update
    # ------------------------------------------------------------------
    def on_update(self, delta_time: float):
        if self.state is None:
            return

        # Tick effects
        self.effects.update(delta_time)

        # Batch 2: glow pulse timer
        self._glow_time += delta_time

        # -- Batch 6: Smooth zoom & pan interpolation --
        _lerp = min(1.0, delta_time * 10.0)
        if abs(self._zoom_level - self._zoom_target) > 0.001:
            self._zoom_level += (self._zoom_target - self._zoom_level) * _lerp
        else:
            self._zoom_level = self._zoom_target
        _pan_lerp = min(1.0, delta_time * 8.0)
        self._pan_x += (self._pan_target_x - self._pan_x) * _pan_lerp
        self._pan_y += (self._pan_target_y - self._pan_y) * _pan_lerp

        # Batch 6: Cinematic camera countdown
        if self._cine_active:
            self._cine_timer -= delta_time
            if self._cine_timer <= 0:
                self._cine_active = False
                self._pan_target_x = self._cine_saved_pan[0]
                self._pan_target_y = self._cine_saved_pan[1]
                self._zoom_target = self._cine_saved_zoom

        # Tick tank sprite animations + lerp movement
        any_moving = False
        for ts in self._tank_sprites.values():
            ts.update_animation(delta_time)
            ts.tick(delta_time)
            if ts.is_moving:
                any_moving = True

        # Phase 7: AI thinking timer
        if self._ai_thinking:
            self._ai_think_time += delta_time
        else:
            self._ai_think_time = 0.0

        # Phase 7: Turn banner countdown
        if self._turn_banner_timer > 0:
            self._turn_banner_timer -= delta_time

        # Phase 7: Detect turn change → trigger banner
        if self.state and not self.state.game_over:
            cp = self.state.current_player
            if cp != self._last_player and self._last_player != 0:
                self._turn_banner_text = f"PLAYER {cp}'S TURN"
                self._turn_banner_color = COLOR_P1 if cp == 1 else COLOR_P2
                # Shorter duration; skip entirely in AI-vs-AI mode
                if self.ai_player1 is not None and self.ai_player2 is not None:
                    self._turn_banner_timer = 0.0
                else:
                    self._turn_banner_timer = 0.8
                    self._banner_slide_x = 300.0  # start off-screen right
                # Phase 10: Turn separator in combat log
                if self._combat_log:
                    self._combat_log.add_turn_separator(self.state.turn_count, cp)
            self._last_player = cp

        # Animation lock (effects playing OR tanks still sliding)
        if self._anim_lock:
            if not self.effects.busy and not any_moving:
                self._anim_lock = False
                if self._pending_game_over is not None:
                    w, r, tc, st, ms = self._pending_game_over
                    self.window.show_game_over(w, r, turns=tc, stats=st,
                                               match_stats=ms)
                    return
            else:
                return

        if self.state.game_over:
            return

        # Check game over
        if self.state.winner is not None or self.state.game_over:
            reason = self._determine_reason()
            self.window.show_game_over(self.state.winner, reason,
                                       turns=self.state.turn_count,
                                       stats=self._build_end_stats(),
                                       match_stats=self._match_stats)
            return

        # AI (threaded so the render loop doesn't freeze)
        now = time.time()
        cp = self.state.current_player
        ai = self.ai_player1 if cp == 1 else self.ai_player2

        if ai is not None:
            # Check if a background AI computation has finished
            if self._ai_thinking and self._ai_thread is not None and not self._ai_thread.is_alive():
                self._ai_thinking = False
                action = self._ai_result
                self._ai_result = None
                if action:
                    self._apply_action_with_effects(action)
                    self.last_ai_time = time.time()
            # Start a new AI computation if not already thinking
            elif not self._ai_thinking and (now - self.last_ai_time) >= self.ai_delay:
                self._ai_thinking = True
                state_copy = copy.deepcopy(self.state)
                def _think():
                    result, _score = ai.choose_action(state_copy)
                    self._ai_result = result
                self._ai_thread = threading.Thread(target=_think, daemon=True)
                self._ai_thread.start()

    # ------------------------------------------------------------------
    # Drawing
    # ------------------------------------------------------------------
    def on_draw(self):
        self.clear()

        # Batch 6: Apply zoom + pan + screen-shake to camera
        sx, sy = self.effects.shake_offset
        self.camera.position = (
            SCREEN_WIDTH / 2 + self._pan_x + sx,
            SCREEN_HEIGHT / 2 + self._pan_y + sy,
        )
        self.camera.zoom = self._zoom_level
        self.camera.use()

        # ── Batch 2: layered hex rendering ────────────────────────────
        # Layer 0: Pulsing glow underlay for special cells
        if self._glow_sprites:
            pulse = 0.55 + 0.45 * math.sin(self._glow_time * 2.0)
            for gs in self._glow_sprites:
                gs.alpha = int(255 * pulse * 0.5)
            self._glow_sprites.draw(pixelated=False)

        # Layer 1: Flat-fill hex polygons (GPU-batched shapes)
        if self._hex_shapes is not None:
            self._hex_shapes.draw()

        # Layer 2: Gradient overlay sprites (radial light per hex)
        if self._hex_gradient_sprites:
            self._hex_gradient_sprites.draw(pixelated=False)

        # Layer 3: Inner highlight bevel lines
        if self._inner_highlight is not None:
            self._inner_highlight.draw()

        # Cell labels (HP numbers, power-up symbols) — drawn via Text objects
        for lbl in self._cell_labels:
            lbl.draw()

        # Hover highlight
        if self._hover_hex and self._hover_hex in self._hex_pixels:
            hx, hy = self._hex_pixels[self._hover_hex]
            corners = self._hex_corners(hx, hy, HEX_SIZE - 2)
            arcade.draw_polygon_filled(corners, COLOR_HEX_HOVER)

        self._draw_hints()

        # Batch 3: Interaction previews (drawn above hints, below tanks)
        self._draw_move_preview()
        self._draw_laser_preview()
        self._draw_bomb_preview()

        self._draw_tanks()
        self._draw_hp_bars()
        self.effects.draw()

        # Batch 7: Hex tooltip (drawn in world-space so it follows hex)
        self._draw_hex_tooltip()

        # ── HUD (screen space) ────────────────────────────────────────
        self.window.default_camera.use()

        # Vignette overlay (drawn first so HUD sits on top)
        if self._vignette_sprite:
            self._vignette_sprite.draw(pixelated=False)

        self._draw_hud()
        self._draw_ai_indicator()
        self._draw_turn_banner()
        self._draw_select_panel()
        self._draw_combat_log()
        self._draw_minimap()
        if self._show_help:
            self._draw_help_overlay()
        # Batch 7: Confirm dialog (topmost overlay)
        self._draw_confirm_dialog()

    # (_draw_board removed — hex grid is now GPU-batched via ShapeElementList)

    def _draw_hints(self):
        drawn_atk_hints = set()  # avoid duplicate highlights for King AoE
        for act in self.filtered_actions:
            if act.action_type == ActionType.MOVE:
                if act.target_pos and act.target_pos in self._hex_pixels:
                    px, py = self._hex_pixels[act.target_pos]
                    arcade.draw_circle_filled(px, py, HEX_SIZE * 0.42, COLOR_MOVE_HINT)
            elif act.action_type == ActionType.ATTACK and self.selected_tank:
                is_king = (self.selected_tank.tank_type == TankType.KTANK)
                if is_king:
                    # King: AoE bomb — highlight all 6 neighbors
                    for nbr in self.selected_tank.pos.neighbors():
                        if nbr in drawn_atk_hints:
                            continue
                        if nbr in self._hex_pixels and self.state.board.is_valid(nbr):
                            px, py = self._hex_pixels[nbr]
                            arcade.draw_circle_filled(px, py, HEX_SIZE * 0.35, COLOR_ATK_HINT)
                            drawn_atk_hints.add(nbr)
                else:
                    # Queen: directional laser — highlight ray
                    ray = self.selected_tank.pos.raycast(act.direction, 12)
                    for hc in ray:
                        if hc not in self._hex_pixels:
                            break
                        if not self.state.board.is_valid(hc):
                            break
                        px, py = self._hex_pixels[hc]
                        arcade.draw_circle_filled(px, py, HEX_SIZE * 0.35, COLOR_ATK_HINT)
                        cell = self.state.board.get_cell(hc)
                        if cell and cell.cell_type in (CellType.WALL, CellType.BLOCK_NORMAL,
                                                        CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
                            break
                        t_at = self.state.get_tank_at(hc)
                        if t_at:
                            break

    # ── Batch 3: Interaction previews ──────────────────────────────

    def _draw_move_preview(self):
        """Ghost tank + path line when hovering a valid move target."""
        if not (self.action_mode == "move" and self.selected_tank
                and self._hover_hex and self.state):
            return
        # Is hover hex a valid move target?
        target_action = None
        for act in self.filtered_actions:
            if act.action_type == ActionType.MOVE and act.target_pos == self._hover_hex:
                target_action = act
                break
        if target_action is None:
            return
        src_px = self._hex_pixels.get(self.selected_tank.pos)
        dst_px = self._hex_pixels.get(self._hover_hex)
        if not src_px or not dst_px:
            return

        tc = COLOR_P1 if self.selected_tank.player == 1 else COLOR_P2

        # --- Path line with waypoint dots ---
        # Walk the ray from source to target, collecting intermediate hexes
        ray = self.selected_tank.pos.raycast(target_action.direction,
                                              target_action.distance)
        waypoints = []
        for hc in ray:
            pp = self._hex_pixels.get(hc)
            if pp:
                waypoints.append(pp)

        # Draw dashed path segments
        prev = src_px
        seg_len = 6.0
        for wp in waypoints:
            dx, dy = wp[0] - prev[0], wp[1] - prev[1]
            dist = math.hypot(dx, dy)
            if dist < 1:
                prev = wp
                continue
            nx, ny = dx / dist, dy / dist
            d = 0.0
            on = True
            while d < dist:
                end_d = min(d + seg_len, dist)
                if on:
                    x1 = prev[0] + nx * d
                    y1 = prev[1] + ny * d
                    x2 = prev[0] + nx * end_d
                    y2 = prev[1] + ny * end_d
                    arcade.draw_line(x1, y1, x2, y2, COLOR_PATH_LINE, 2)
                d = end_d
                on = not on
            prev = wp

        # Waypoint dots
        for wp in waypoints[:-1]:
            arcade.draw_circle_filled(wp[0], wp[1], 3, COLOR_PATH_DOT)

        # --- Ghost tank at destination ---
        gx, gy = dst_px
        # Translucent team-coloured hex fill
        corners = self._hex_corners(gx, gy, HEX_SIZE - 2)
        arcade.draw_polygon_filled(corners, (*tc[:3], 45))
        # Pulsing ghost outline
        pulse = 0.5 + 0.5 * math.sin(time.time() * 4.0)
        outline_a = int(80 + 80 * pulse)
        arcade.draw_polygon_outline(corners, (*tc[:3], outline_a), 2)
        # Role letter in center
        role = "K" if self.selected_tank.tank_type == TankType.KTANK else "Q"
        arcade.draw_text(role, gx, gy, (*tc[:3], int(120 + 60 * pulse)),
                         16, anchor_x="center", anchor_y="center",
                         font_name=FONT_NAME, bold=True)

    def _draw_laser_preview(self):
        """Beam preview line + crosshair when hovering a hex along a Queen ray."""
        if not (self.action_mode == "attack" and self.selected_tank
                and self.selected_tank.tank_type == TankType.QTANK
                and self._hover_hex and self.state):
            return
        src_px = self._hex_pixels.get(self.selected_tank.pos)
        if not src_px:
            return

        # Find which ray the hover hex belongs to
        for act in self.filtered_actions:
            if act.action_type != ActionType.ATTACK:
                continue
            ray = self.selected_tank.pos.raycast(act.direction, 12)
            ray_hexes = []
            endpoint = None
            for hc in ray:
                if not self.state.board.is_valid(hc):
                    break
                ray_hexes.append(hc)
                endpoint = hc
                cell = self.state.board.get_cell(hc)
                if cell and cell.cell_type in (CellType.WALL, CellType.BLOCK_NORMAL,
                                                CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
                    break
                t_at = self.state.get_tank_at(hc)
                if t_at:
                    break

            if self._hover_hex not in ray_hexes:
                continue

            # This is the active ray — draw preview
            end_px = self._hex_pixels.get(endpoint)
            if not end_px:
                return

            # Beam line (semi-transparent)
            arcade.draw_line(src_px[0], src_px[1], end_px[0], end_px[1],
                             COLOR_LASER_PREV, 3)
            # Inner bright core
            arcade.draw_line(src_px[0], src_px[1], end_px[0], end_px[1],
                             (255, 200, 200, 40), 6)

            # Crosshair at endpoint
            r = HEX_SIZE * 0.45
            ex, ey = end_px
            arcade.draw_circle_outline(ex, ey, r, COLOR_LASER_CROSS, 2)
            # Cross lines
            arcade.draw_line(ex - r, ey, ex + r, ey, COLOR_LASER_CROSS, 1)
            arcade.draw_line(ex, ey - r, ex, ey + r, COLOR_LASER_CROSS, 1)

            # Highlight each hex in the ray with faint red wash
            for hc in ray_hexes:
                hp = self._hex_pixels.get(hc)
                if hp:
                    corners = self._hex_corners(hp[0], hp[1], HEX_SIZE - 3)
                    arcade.draw_polygon_filled(corners, (255, 80, 80, 25))
            return  # only draw one ray

    def _draw_bomb_preview(self):
        """AoE blast zone overlay when hovering near King in attack mode."""
        if not (self.action_mode == "attack" and self.selected_tank
                and self.selected_tank.tank_type == TankType.KTANK
                and self._hover_hex and self.state):
            return
        king_pos = self.selected_tank.pos
        neighbors = set(king_pos.neighbors())
        if self._hover_hex not in neighbors:
            return

        # Draw blast zone on all valid neighbors
        for nbr in neighbors:
            if nbr not in self._hex_pixels:
                continue
            if not self.state.board.is_valid(nbr):
                continue
            px, py = self._hex_pixels[nbr]
            corners = self._hex_corners(px, py, HEX_SIZE - 2)
            arcade.draw_polygon_filled(corners, COLOR_BOMB_FILL)
            arcade.draw_polygon_outline(corners, COLOR_BOMB_LINE, 2)
            # Impact marker on cells with targets
            t_at = self.state.get_tank_at(nbr)
            cell = self.state.board.get_cell(nbr)
            has_target = (t_at is not None) or (
                cell and cell.cell_type in (CellType.BLOCK_NORMAL,
                                            CellType.BLOCK_ARMOR,
                                            CellType.BLOCK_POWER))
            if has_target:
                arcade.draw_circle_outline(px, py, HEX_SIZE * 0.3,
                                           (255, 200, 60, 140), 2)

        # Pulsing central indicator on King's hex
        kp = self._hex_pixels.get(king_pos)
        if kp:
            pulse = 0.5 + 0.5 * math.sin(time.time() * 5.0)
            arcade.draw_circle_outline(kp[0], kp[1], HEX_SIZE * 0.6,
                                       (255, 120, 40, int(80 + 80 * pulse)), 2)

    def _draw_tanks(self):
        if self.state is None:
            return
        for (player, tt), ts in self._tank_sprites.items():
            tank = self.state.get_tank(player, tt)
            if not tank.is_alive():
                continue
            # Determine buff name for badge
            buff_name = tank.buff.name if tank.buff.name != "NONE" else ""
            ts.draw_layers(
                selected=(self.selected_tank is tank),
                buff_name=buff_name,
                hex_size=HEX_SIZE,
            )

    def _draw_hp_bars(self):
        if self.state is None:
            return
        BAR_W, BAR_H = 42, 6
        BORDER = 1
        for (player, tt), ts in self._tank_sprites.items():
            tank = self.state.get_tank(player, tt)
            if not tank.is_alive():
                continue
            bx, by = ts.hp_bar_pos()
            ratio = max(tank.hp / tank.max_hp, 0.0)
            # Outer border
            arcade.draw_lbwh_rectangle_filled(
                bx - BAR_W / 2 - BORDER, by - BAR_H / 2 - BORDER,
                BAR_W + 2 * BORDER, BAR_H + 2 * BORDER, (0, 0, 0, 200))
            # Background
            arcade.draw_lbwh_rectangle_filled(
                bx - BAR_W / 2, by - BAR_H / 2, BAR_W, BAR_H, COLOR_HP_BG)
            # Fill — colour gradient from green → yellow → red
            if ratio > 0.6:
                fill_color = COLOR_HP_GREEN
            elif ratio > 0.3:
                fill_color = (220, 200, 40)   # yellow
            else:
                fill_color = COLOR_HP_RED
            arcade.draw_lbwh_rectangle_filled(
                bx - BAR_W / 2, by - BAR_H / 2, BAR_W * ratio, BAR_H, fill_color)

    # ------------------------------------------------------------------
    # Drop-shadow helper (draws text with a dark offset behind it)
    # ------------------------------------------------------------------
    @staticmethod
    def _draw_shadow_text(txt: arcade.Text, ox: float = 1, oy: float = -1):
        """Draw *txt* with a subtle drop shadow for readability."""
        orig_color = txt.color
        orig_x, orig_y = txt.x, txt.y
        # Shadow pass
        r, g, b = 0, 0, 0
        a = min(int(orig_color[3] * 0.55), 140) if len(orig_color) > 3 else 90
        txt.color = (r, g, b, a)
        txt.x = orig_x + ox
        txt.y = orig_y + oy
        txt.draw()
        # Normal pass
        txt.color = orig_color
        txt.x = orig_x
        txt.y = orig_y
        txt.draw()

    def _draw_hud(self):
        # ── Top bar (50px) ────────────────────────────────────────────
        bar_y = SCREEN_HEIGHT - HUD_HEIGHT
        arcade.draw_lbwh_rectangle_filled(
            0, bar_y, SCREEN_WIDTH, HUD_HEIGHT, (16, 20, 28, 230),
        )
        # Subtle bottom edge line
        arcade.draw_lbwh_rectangle_filled(
            0, bar_y, SCREEN_WIDTH, 1, (60, 70, 85, 120),
        )

        if self.state is None:
            return

        cp = self.state.current_player
        turn_color = COLOR_P1 if cp == 1 else COLOR_P2

        # Left zone — turn indicator
        self._txt_turn.text = f"\u25C6 Player {cp}'s Turn"
        self._txt_turn.color = turn_color
        self._draw_shadow_text(self._txt_turn)

        self._txt_turn_count.text = f"Turn {self.state.turn_count}"
        self._draw_shadow_text(self._txt_turn_count)

        # Centre zone — mode + king distance
        if self.action_mode:
            self._txt_mode.text = f"[ {self.action_mode.upper()} ]"
            self._draw_shadow_text(self._txt_mode)

        if self._txt_kdist:
            k1 = self.state.get_tank(1, TankType.KTANK)
            k2 = self.state.get_tank(2, TankType.KTANK)
            d1 = k1.pos.distance(HexCoord(0, 0)) if k1.is_alive() else "-"
            d2 = k2.pos.distance(HexCoord(0, 0)) if k2.is_alive() else "-"
            self._txt_kdist.text = f"\u2605 P1={d1}  P2={d2}"
            self._txt_kdist.draw()

        # Right zone — compact tank HP readouts with colour dots
        idx = 0
        for pl in [1, 2]:
            for tt in [TankType.KTANK, TankType.QTANK]:
                tank = self.state.get_tank(pl, tt)
                lbl = "K" if tt == TankType.KTANK else "Q"
                if tank.is_alive():
                    txt = f"P{pl}{lbl} {tank.hp}/{tank.max_hp}"
                else:
                    txt = f"P{pl}{lbl} \u2620"
                col = COLOR_P1 if pl == 1 else COLOR_P2
                self._txt_tanks[idx].text = txt
                self._txt_tanks[idx].color = col if tank.is_alive() else (*col[:3], 100)
                self._draw_shadow_text(self._txt_tanks[idx])
                idx += 1

        # ── Bottom hint bar (28px) ────────────────────────────────────
        arcade.draw_lbwh_rectangle_filled(0, 0, SCREEN_WIDTH, 28, (16, 20, 28, 200))
        arcade.draw_lbwh_rectangle_filled(0, 28, SCREEN_WIDTH, 1, (60, 70, 85, 80))
        self._txt_help.draw()

    # ------------------------------------------------------------------
    # Phase 7: AI thinking indicator
    # ------------------------------------------------------------------
    def _draw_ai_indicator(self):
        if not self._ai_thinking or self._txt_ai_think is None:
            return
        # Pulsing dots animation
        dots = "." * (1 + int(self._ai_think_time * 2.5) % 4)
        self._txt_ai_think.text = f"\u2699  AI Thinking{dots}"
        # Pulsing alpha
        import math as _m
        pulse = int(140 + 115 * (0.5 + 0.5 * _m.sin(self._ai_think_time * 4.0)))
        self._txt_ai_think.color = (200, 200, 210, pulse)
        self._txt_ai_think.draw()

    # ------------------------------------------------------------------
    # Turn-change toast (compact top-right notification)
    # ------------------------------------------------------------------
    def _draw_turn_banner(self):
        if self._turn_banner_timer <= 0:
            return

        # Slide-in: lerp _banner_slide_x toward 0
        spd = 1200.0  # px per second
        if self._banner_slide_x > 0:
            self._banner_slide_x = max(0.0, self._banner_slide_x - spd * (1.0 / 60.0))

        # Fade out in last 0.3s
        alpha = min(1.0, self._turn_banner_timer / 0.3)
        a = int(alpha * 230)

        # Toast dimensions & position
        tw, th = 260, 38
        tx = SCREEN_WIDTH - tw - 14 + self._banner_slide_x
        ty = SCREEN_HEIGHT - HUD_HEIGHT - th - 12

        # Background with team-colour tinted border
        r, g, b = self._turn_banner_color[:3]
        arcade.draw_lbwh_rectangle_filled(tx, ty, tw, th, (16, 20, 28, int(a * 0.85)))
        arcade.draw_lbwh_rectangle_outline(tx, ty, tw, th, (r, g, b, a), 2)
        # Thin accent line on left
        arcade.draw_lbwh_rectangle_filled(tx, ty, 4, th, (r, g, b, a))

        self._txt_banner.x = tx + tw // 2
        self._txt_banner.y = ty + th // 2
        self._txt_banner.text = self._turn_banner_text
        self._txt_banner.color = (r, g, b, a)
        self._txt_banner.draw()

    # ------------------------------------------------------------------
    # Selected tank detail panel (left sidebar, below top bar)
    # ------------------------------------------------------------------
    def _draw_select_panel(self):
        if self.selected_tank is None or self.state is None:
            return
        if self._txt_select_info is None:
            return

        tank = self.selected_tank
        if not tank.is_alive():
            return

        # Build info string
        role = "KING" if tank.tank_type == TankType.KTANK else "QUEEN"
        atk_type = "Bomb (AoE)" if tank.tank_type == TankType.KTANK else "Laser (Line)"
        hp_str = f"{tank.hp}/{tank.max_hp}"
        buff_str = tank.buff.name.replace("_", " ").title() if tank.buff.name != "NONE" else "None"

        info = (
            f"P{tank.player} {role}\n"
            f"HP: {hp_str}\n"
            f"Attack: {atk_type}\n"
            f"Buff: {buff_str}\n"
            f"Mode: {(self.action_mode or 'select').upper()}"
        )

        tc = COLOR_P1 if tank.player == 1 else COLOR_P2

        # Panel geometry
        panel_x = 8
        panel_y = SCREEN_HEIGHT - HUD_HEIGHT - 155
        panel_w = 210
        panel_h = 130
        arcade.draw_lbwh_rectangle_filled(panel_x, panel_y, panel_w, panel_h, (16, 20, 28, 220))
        arcade.draw_lbwh_rectangle_outline(panel_x, panel_y, panel_w, panel_h, (*tc[:3], 120), 1)
        # Team-colour accent line on left edge
        arcade.draw_lbwh_rectangle_filled(panel_x, panel_y, 3, panel_h, tc)

        self._txt_select_info.text = info
        self._txt_select_info.x = panel_x + 12
        self._txt_select_info.y = panel_y + panel_h - 14
        self._txt_select_info.color = tc
        self._txt_select_info.draw()

    # ------------------------------------------------------------------
    # Phase 9: Combat log panel (right sidebar)
    # ------------------------------------------------------------------
    def _draw_combat_log(self):
        if self._combat_log is not None:
            self._combat_log.draw()

    # ------------------------------------------------------------------
    # Phase 10: Minimap (bottom-right overview)
    # ------------------------------------------------------------------
    def _draw_minimap(self):
        if not self._minimap_enabled or not self.state:
            return
        mm_size = 5          # px per hex
        mm_cx = SCREEN_WIDTH - 80
        mm_cy = 100           # above bottom hint bar
        pad = 60

        # Background
        arcade.draw_lbwh_rectangle_filled(
            mm_cx - pad, mm_cy - pad, pad * 2, pad * 2,
            (16, 20, 28, 180),
        )
        arcade.draw_lbwh_rectangle_outline(
            mm_cx - pad, mm_cy - pad, pad * 2, pad * 2,
            (60, 70, 85, 140), 1,
        )

        # Hex dots
        for hc in self._hex_pixels:
            cell = self.state.board.get_cell(hc)
            if cell is None:
                continue
            # Convert hex to tiny pixel coords
            px = mm_cx + hc.q * mm_size * 1.5
            py = mm_cy + (hc.r * mm_size * 1.73 + hc.q * mm_size * 0.866)
            ct = cell.cell_type
            if ct == CellType.WALL:
                col = (72, 72, 82)
            elif ct == CellType.CENTER:
                col = (200, 160, 40)
            elif ct.value >= 10:  # power-ups
                col = (80, 160, 80)
            else:
                col = (45, 55, 65)
            arcade.draw_point(px, py, (*col, 200), mm_size * 1.2)

        # Tank dots
        for (player, tt), _ts in self._tank_sprites.items():
            tank = self.state.get_tank(player, tt)
            if not tank.is_alive():
                continue
            hc = tank.pos
            px = mm_cx + hc.q * mm_size * 1.5
            py = mm_cy + (hc.r * mm_size * 1.73 + hc.q * mm_size * 0.866)
            col = COLOR_P1 if player == 1 else COLOR_P2
            dot_size = mm_size * 2.0 if tt == TankType.KTANK else mm_size * 1.5
            arcade.draw_point(px, py, col, dot_size)

    # ------------------------------------------------------------------
    # Phase 10: Help overlay
    # ------------------------------------------------------------------
    def _draw_help_overlay(self):
        # Full-screen darkened backdrop
        arcade.draw_lbwh_rectangle_filled(
            0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, (0, 0, 0, 170),
        )
        cx = SCREEN_WIDTH // 2
        cy = SCREEN_HEIGHT // 2
        pw, ph = 460, 520

        # Panel
        arcade.draw_lbwh_rectangle_filled(
            cx - pw // 2, cy - ph // 2, pw, ph, (20, 26, 34, 240),
        )
        arcade.draw_lbwh_rectangle_outline(
            cx - pw // 2, cy - ph // 2, pw, ph, (200, 160, 60, 200), 2,
        )

        if not self._help_texts:
            lines = [
                ("\u2694 CONTROLS", 24, (200, 160, 60)),
                ("", 8, (0, 0, 0)),
                ("Click tank \u2192 Select", 15, (200, 200, 210)),
                ("1 / 2 \u2192 Select Queen / King", 15, (200, 200, 210)),
                ("M \u2192 Move mode", 15, (100, 255, 100)),
                ("A \u2192 Attack mode", 15, (255, 100, 100)),
                ("P \u2192 Pass turn", 15, (200, 200, 210)),
                ("Space \u2192 Deselect", 15, (200, 200, 210)),
                ("", 8, (0, 0, 0)),
                ("S \u2192 Toggle sound", 15, (160, 160, 175)),
                ("R \u2192 Restart game (confirm)", 15, (160, 160, 175)),
                ("Tab \u2192 Toggle minimap", 15, (160, 160, 175)),
                ("Esc \u2192 Main menu (confirm)", 15, (160, 160, 175)),
                ("", 8, (0, 0, 0)),
                ("Scroll \u2192 Zoom in / out", 15, (140, 180, 220)),
                ("Arrows \u2192 Pan camera", 15, (140, 180, 220)),
                ("Middle-drag \u2192 Pan camera", 15, (140, 180, 220)),
                ("Home \u2192 Reset camera", 15, (140, 180, 220)),
                ("PgUp/PgDn \u2192 Combat log", 15, (140, 180, 220)),
                ("H / F1 \u2192 Toggle this help", 15, (200, 160, 60)),
            ]
            y = cy + ph // 2 - 30
            for text, size, color in lines:
                if not text:
                    y -= size
                    continue
                t = arcade.Text(
                    text, cx, y, color=color, font_size=size,
                    anchor_x="center", anchor_y="top", bold=(size > 18),
                    font_name=FONT_NAME,
                )
                self._help_texts.append(t)
                y -= size + 8

        for t in self._help_texts:
            t.draw()

    # ------------------------------------------------------------------
    # Batch 7: Hex tooltip on hover
    # ------------------------------------------------------------------
    def _draw_hex_tooltip(self):
        """Draw a small info label near the hovered hex."""
        if self._show_help or self._confirm_action:
            return
        if not self._hover_hex or not self.state:
            return
        cell = self.state.board.get_cell(self._hover_hex)
        if cell is None:
            return

        # Build tooltip text
        _CELL_NAMES = {
            CellType.EMPTY:        "Empty",
            CellType.WALL:         "Wall",
            CellType.CENTER:       "\u2605 Centre (capture to win)",
            CellType.BLOCK_NORMAL: "Block",
            CellType.BLOCK_ARMOR:  "Armored Block",
            CellType.BLOCK_POWER:  "Power Block",
            CellType.POWER_ATTACK: "\u2694 ATK Boost",
            CellType.POWER_MOVE:   "\u27A4 Move Boost",
            CellType.POWER_SHIELD: "\u2764 Shield",
        }
        ct = cell.cell_type
        name = _CELL_NAMES.get(ct, ct.name)

        # Tank on this cell?
        tank_at = self.state.get_tank_at(self._hover_hex)
        if tank_at:
            role = "King" if tank_at.tank_type == TankType.KTANK else "Queen"
            name = f"P{tank_at.player} {role}  {tank_at.hp}/{tank_at.max_hp} HP"
            if tank_at.buff and tank_at.buff.name != "NONE":
                name += f"  [{tank_at.buff.name.replace('_', ' ').title()}]"
        elif ct in (CellType.BLOCK_NORMAL, CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
            name += f"  {cell.hp} HP"

        # Only show for non-trivial cells
        if ct == CellType.EMPTY and not tank_at:
            return

        # Position tooltip near the hex (screen-space)
        hp = self._hex_pixels.get(self._hover_hex)
        if not hp:
            return
        # Project world → screen
        sx = hp[0]
        sy = hp[1] + HEX_SIZE + 14

        if self._tooltip_text is None:
            self._tooltip_text = arcade.Text(
                name, sx, sy, (220, 220, 230, 220), 11,
                anchor_x="center", anchor_y="bottom",
                font_name=FONT_NAME,
            )
        else:
            self._tooltip_text.text = name
            self._tooltip_text.x = sx
            self._tooltip_text.y = sy

        # Background pill
        tw = len(name) * 7 + 16
        th = 20
        arcade.draw_lbwh_rectangle_filled(
            sx - tw / 2, sy - 2, tw, th,
            (16, 20, 28, 210),
        )
        arcade.draw_lbwh_rectangle_outline(
            sx - tw / 2, sy - 2, tw, th,
            (80, 90, 100, 160), 1,
        )
        self._tooltip_text.draw()

    # ------------------------------------------------------------------
    # Batch 7: Confirm dialog (restart / quit mid-game)
    # ------------------------------------------------------------------
    def _draw_confirm_dialog(self):
        if not self._confirm_action:
            return
        # Full-screen dim
        arcade.draw_lbwh_rectangle_filled(
            0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, (0, 0, 0, 160),
        )
        cx, cy = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2
        pw, ph = 380, 160

        # Panel
        arcade.draw_lbwh_rectangle_filled(
            cx - pw // 2, cy - ph // 2, pw, ph, (24, 30, 40, 240),
        )
        arcade.draw_lbwh_rectangle_outline(
            cx - pw // 2, cy - ph // 2, pw, ph, (200, 160, 60, 200), 2,
        )

        if not self._confirm_texts:
            label = "Restart game?" if self._confirm_action == "restart" else "Quit to menu?"
            self._confirm_texts = [
                arcade.Text(
                    label, cx, cy + 30,
                    (220, 220, 230), 20, anchor_x="center", anchor_y="center",
                    bold=True, font_name=FONT_NAME,
                ),
                arcade.Text(
                    "Y = Confirm     N / Esc = Cancel", cx, cy - 20,
                    (160, 160, 175), 14, anchor_x="center", anchor_y="center",
                    font_name=FONT_NAME,
                ),
            ]
        for t in self._confirm_texts:
            t.draw()

    # ------------------------------------------------------------------
    # Input
    # ------------------------------------------------------------------
    def on_mouse_motion(self, x: float, y: float, dx: float, dy: float):
        """Track which hex the mouse is hovering over."""
        # Batch 6: middle-mouse drag pans the camera
        if self._mid_drag:
            scale = 1.0 / self._zoom_level
            self._pan_target_x -= dx * scale
            self._pan_target_y -= dy * scale
            self._pan_x = self._pan_target_x
            self._pan_y = self._pan_target_y
        wx, wy = self._screen_to_world(x, y)
        self._hover_hex = self._pixel_to_hex(wx, wy)

    def on_mouse_scroll(self, x: int, y: int, scroll_x: int, scroll_y: int):
        """Batch 6: Scroll wheel zooms camera. PgUp/PgDn for combat log."""
        zoom_speed = 0.10
        self._zoom_target += scroll_y * zoom_speed
        self._zoom_target = max(0.5, min(2.5, self._zoom_target))

    def on_mouse_press(self, x: float, y: float, button: int, modifiers: int):
        # Batch 6: Middle mouse → start pan drag
        if button == arcade.MOUSE_BUTTON_MIDDLE:
            self._mid_drag = True
            return
        if button != arcade.MOUSE_BUTTON_LEFT:
            return
        # Batch 7: block clicks when confirm dialog is open
        if self._confirm_action:
            return

        if self.state is None or self.state.game_over or self._anim_lock:
            return
        cp = self.state.current_player
        if (cp == 1 and self.ai_player1) or (cp == 2 and self.ai_player2):
            return

        wx, wy = self._screen_to_world(x, y)
        clicked_hex = self._pixel_to_hex(wx, wy)
        if clicked_hex is None:
            return

        if self.selected_tank and self.action_mode:
            if self.action_mode == "attack":
                is_king = (self.selected_tank.tank_type == TankType.KTANK)
                if is_king:
                    # King: AoE — click any neighbor to bomb
                    if clicked_hex in self.selected_tank.pos.neighbors():
                        # Use the first attack action (direction doesn't matter for bomb)
                        for act in self.filtered_actions:
                            if act.action_type == ActionType.ATTACK:
                                self._apply_action_with_effects(act)
                                return
                else:
                    # Queen: directional laser — find which direction the click is in
                    for act in self.filtered_actions:
                        if act.action_type != ActionType.ATTACK:
                            continue
                        ray = self.selected_tank.pos.raycast(act.direction, 12)
                        for hc in ray:
                            if not self.state.board.is_valid(hc):
                                break
                            if hc == clicked_hex:
                                self._apply_action_with_effects(act)
                                return
                            cell = self.state.board.get_cell(hc)
                            if cell and cell.cell_type in (CellType.WALL, CellType.BLOCK_NORMAL,
                                                            CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
                                break
                            t_at = self.state.get_tank_at(hc)
                            if t_at:
                                break
            else:
                # Move mode
                for act in self.filtered_actions:
                    if act.action_type == ActionType.MOVE and act.target_pos == clicked_hex:
                        self._apply_action_with_effects(act)
                        return

        tank = self.state.get_tank_at(clicked_hex)
        if tank and tank.player == cp:
            _sfx().play("select")
            self.selected_tank = tank
            self.action_mode = None
            self.filtered_actions = []

    def on_mouse_release(self, x: float, y: float, button: int, modifiers: int):
        """Batch 6: Release middle mouse to stop pan drag."""
        if button == arcade.MOUSE_BUTTON_MIDDLE:
            self._mid_drag = False

    def on_key_press(self, key, modifiers):
        # -- Batch 6: Camera controls (always available) ---------------
        _PAN = 40.0
        if key == arcade.key.LEFT:
            self._pan_target_x -= _PAN
            return
        if key == arcade.key.RIGHT:
            self._pan_target_x += _PAN
            return
        if key == arcade.key.UP:
            self._pan_target_y += _PAN
            return
        if key == arcade.key.DOWN:
            self._pan_target_y -= _PAN
            return
        if key == arcade.key.HOME:
            self._reset_camera()
            return
        if key in (arcade.key.PAGEUP, arcade.key.PAGEDOWN):
            if self._combat_log is not None:
                self._combat_log.scroll(-3 if key == arcade.key.PAGEUP else 3)
            return

        if self.state is None or self._anim_lock:
            return

        # -- Batch 7: Confirm dialog input intercept --
        if self._confirm_action:
            if key in (arcade.key.Y, arcade.key.ENTER):
                act = self._confirm_action
                self._confirm_action = None
                self._confirm_texts.clear()
                if act == "restart":
                    _sfx().play("select")
                    self.window.show_game()
                elif act == "quit":
                    self.window.show_menu()
            elif key in (arcade.key.N, arcade.key.ESCAPE):
                self._confirm_action = None
                self._confirm_texts.clear()
            return

        if key == arcade.key.ESCAPE:
            if self._show_help:
                self._show_help = False
                return
            # Batch 7: confirm before leaving mid-game
            if not self.state.game_over:
                self._confirm_action = "quit"
                self._confirm_texts.clear()
                return
            self.window.show_menu()
            return

        # Phase 10: help overlay toggle
        if key in (arcade.key.H, arcade.key.F1):
            self._show_help = not self._show_help
            return

        # Phase 10: minimap toggle
        if key == arcade.key.TAB:
            self._minimap_enabled = not self._minimap_enabled
            return

        # Block gameplay input while help is open
        if self._show_help:
            return

        if key == arcade.key.M and self.selected_tank:
            _sfx().play("select")
            self.action_mode = "move"
            self._update_filtered_actions()
        elif key == arcade.key.A and self.selected_tank:
            _sfx().play("select")
            self.action_mode = "attack"
            self._update_filtered_actions()
        elif key == arcade.key.P:
            self._execute_pass()
        elif key == arcade.key.S:
            _sfx().toggle()
        elif key == arcade.key.R:
            # Batch 7: confirm before restarting mid-game
            if not self.state.game_over:
                self._confirm_action = "restart"
                self._confirm_texts.clear()
            else:
                _sfx().play("select")
                self.window.show_game()
        elif key == arcade.key.KEY_1:
            self._select_tank_by_type(TankType.QTANK)
        elif key == arcade.key.KEY_2:
            self._select_tank_by_type(TankType.KTANK)
        elif key == arcade.key.SPACE:
            self.selected_tank = None
            self.action_mode = None
            self.filtered_actions = []

    # ------------------------------------------------------------------
    # Action execution with effects
    # ------------------------------------------------------------------
    def _apply_action_with_effects(self, action: Action):
        """Apply a game action and spawn appropriate visual effects."""
        src_tank = self.state.get_tank(action.player, action.tank_type)
        src_pos = src_tank.pos if src_tank else None
        src_px = src_py = None
        if src_pos and src_pos in self._hex_pixels:
            src_px, src_py = self._hex_pixels[src_pos]

        # Snapshot HP before action (tanks)
        hp_before = {}
        for t in self.state.get_all_tanks():
            hp_before[(t.player, t.tank_type)] = t.hp

        # Snapshot cell HP before action (for block destruction detection)
        cell_hp_before = {}
        for hc in self._hex_pixels:
            cell = self.state.board.get_cell(hc)
            if cell and cell.hp > 0:
                cell_hp_before[hc] = cell.hp

        # -- Batch 6: Cinematic camera for AI attacks --
        _is_ai = (
            (action.player == 1 and self.ai_player1 is not None)
            or (action.player == 2 and self.ai_player2 is not None)
        )
        if _is_ai and action.action_type == ActionType.ATTACK and src_px is not None:
            self._start_cinematic(src_px, src_py, duration=1.5)

        # Apply
        self.state = self.state.apply_action(action)
        self.legal_actions = self.state.get_legal_actions()
        self.selected_tank = None
        self.action_mode = None
        self.filtered_actions = []

        # Rebuild hex grid shapes if board changed (blocks destroyed, power-ups revealed)
        self._rebuild_hex_shapes()

        # --- Phase 9: Feed events to combat log ---
        if self._combat_log and self.state.events:
            self._combat_log.add_events(self.state.events,
                                         current_turn=self.state.turn_count)

        # --- Detect destroyed blocks → sparks (Phase 5) ---
        for hc, old_hp in cell_hp_before.items():
            cell = self.state.board.get_cell(hc)
            if cell and cell.hp <= 0 and old_hp > 0:
                if hc in self._hex_pixels:
                    bpx, bpy = self._hex_pixels[hc]
                    self.effects.spawn_sparks(bpx, bpy, count=6, scale=0.10)

        # --- Batch 7: Track match performance stats ---
        pk = f"p{action.player}"
        if action.action_type == ActionType.MOVE:
            self._match_stats[pk]["moves"] += 1
        elif action.action_type == ActionType.ATTACK:
            self._match_stats[pk]["attacks"] += 1
        # Damage dealt
        for t in self.state.get_all_tanks():
            old_hp = hp_before.get((t.player, t.tank_type), 0)
            if t.hp < old_hp:
                self._match_stats[pk]["damage_dealt"] += (old_hp - t.hp)
        # Blocks destroyed
        for hc, old_hp in cell_hp_before.items():
            cell = self.state.board.get_cell(hc)
            if cell and cell.hp <= 0 and old_hp > 0:
                self._match_stats[pk]["blocks_destroyed"] += 1
        # Pickups
        for ev in self.state.events:
            if ev.event_type in ("buff", "bonus_move"):
                self._match_stats[pk]["pickups"] += 1

        # --- Detect power-up pickup → glow + sound (Phase 5/6) ---
        for ev in self.state.events:
            if ev.event_type in ("buff", "bonus_move"):
                _sfx().play("pickup")
                # The moving tank is at its new position
                moved_tank = self.state.get_tank(action.player, action.tank_type)
                if moved_tank and moved_tank.pos in self._hex_pixels:
                    gpx, gpy = self._hex_pixels[moved_tank.pos]
                    glow_color = (100, 255, 120)
                    if ev.event_type == "buff":
                        buff_type = ev.data.get("buff_type", "")
                        if "ATTACK" in str(buff_type):
                            glow_color = (255, 100, 100)
                        elif "SHIELD" in str(buff_type):
                            glow_color = (100, 180, 255)
                    self.effects.spawn_pickup_glow(gpx, gpy, color=glow_color)

        # Spawn effects
        if action.action_type == ActionType.MOVE:
            # Smooth lerp movement
            _sfx().play("move")
            self._sync_tank_positions(animate=True)
            if src_px is not None:
                self.effects.spawn_exhaust(src_px, src_py)
            key = (action.player, action.tank_type)
            if key in self._tank_sprites:
                self._tank_sprites[key].cycle_tracks()
            self._anim_lock = True   # lock until slide finishes

        else:
            # PASS or other — instant sync
            self._sync_tank_positions(animate=False)

        if action.action_type == ActionType.ATTACK:
            self._sync_tank_positions(animate=False)
            is_bomb = (action.tank_type == TankType.KTANK)

            if is_bomb:
                # King: AoE bomb centered on self — explosion on self, damage to all neighbors
                _sfx().play("bomb")
                if src_px is not None:
                    self.effects.spawn_muzzle_flash(src_px, src_py)
                    key = (action.player, action.tank_type)
                    if key in self._tank_sprites:
                        self._tank_sprites[key].fire()
                    self.effects.spawn_explosion(src_px, src_py, scale=0.50)
                    # Phase 5: screen-shake + flash overlay for bomb
                    self.effects.start_shake(intensity=6.0, decay=40.0)
                    self.effects.spawn_flash_overlay(alpha=80, lifetime=0.12)
                    # Batch 4: camera nudge outward from King's position
                    self.effects.start_nudge(0, 1, strength=6.0, duration=0.30)
                    # Smoke/impact on each neighbor
                    for nbr in src_pos.neighbors():
                        if nbr in self._hex_pixels:
                            nbr_px, nbr_py = self._hex_pixels[nbr]
                            self.effects.spawn_smoke(nbr_px, nbr_py)
                    # Impact effects + damage flash on damaged tanks
                    for t in self.state.get_all_tanks():
                        old_hp = hp_before.get((t.player, t.tank_type), 0)
                        if t.hp < old_hp:
                            tk = (t.player, t.tank_type)
                            if tk in self._tank_sprites:
                                self._tank_sprites[tk].flash_damage()
                            if t.pos in self._hex_pixels:
                                ipx, ipy = self._hex_pixels[t.pos]
                                self.effects.spawn_impact(ipx, ipy)
                                # Batch 4: floating damage number
                                dmg = old_hp - t.hp
                                self.effects.spawn_damage_number(ipx, ipy, dmg)
            else:
                # Queen: directional laser
                tgt_px, tgt_py = src_px, src_py
                if src_pos and action.direction is not None:
                    ray = src_pos.raycast(action.direction, 12)
                    for hc in ray:
                        if hc not in self._hex_pixels:
                            break
                        tgt_px, tgt_py = self._hex_pixels[hc]
                        # Check for tanks that took damage
                        t_at_pos = None
                        for t in self.state.get_all_tanks():
                            if t.pos == hc:
                                t_at_pos = t
                                break
                        if t_at_pos and hp_before.get((t_at_pos.player, t_at_pos.tank_type), 0) > t_at_pos.hp:
                            break
                        cell = self.state.board.get_cell(hc) if self.state.board.is_valid(hc) else None
                        if cell and cell.cell_type in (CellType.WALL, CellType.BLOCK_NORMAL,
                                                        CellType.BLOCK_ARMOR, CellType.BLOCK_POWER):
                            break

                if src_px is not None and tgt_px is not None:
                    _sfx().play("laser")
                    self.effects.spawn_muzzle_flash(src_px, src_py)
                    key = (action.player, action.tank_type)
                    if key in self._tank_sprites:
                        self._tank_sprites[key].fire()
                        self._tank_sprites[key].aim_gun(tgt_px, tgt_py)
                    # Phase 5: laser beam trail + animated projectile
                    self.effects.spawn_laser_beam(src_px, src_py, tgt_px, tgt_py)
                    self.effects.spawn_animated_projectile(
                        src_px, src_py, tgt_px, tgt_py,
                        projectile_type="shot",
                        speed=800.0,
                    )
                    # Phase 5: light screen-shake for laser
                    self.effects.start_shake(intensity=3.0, decay=30.0)
                    # Batch 4: camera nudge along laser direction
                    self.effects.start_nudge(
                        tgt_px - src_px, tgt_py - src_py,
                        strength=5.0, duration=0.30,
                    )
                # Impact effects + damage flash on damaged tanks
                for t in self.state.get_all_tanks():
                    old_hp = hp_before.get((t.player, t.tank_type), 0)
                    if t.hp < old_hp:
                        _sfx().play("hit")
                        tk = (t.player, t.tank_type)
                        if tk in self._tank_sprites:
                            self._tank_sprites[tk].flash_damage()
                        if t.pos in self._hex_pixels:
                            ipx, ipy = self._hex_pixels[t.pos]
                            self.effects.spawn_impact(ipx, ipy)
                            # Batch 4: floating damage number
                            dmg = old_hp - t.hp
                            self.effects.spawn_damage_number(ipx, ipy, dmg)

            self._anim_lock = True

        # --- Detect tank deaths → death explosion (Phase 5) ---
        for t in self.state.get_all_tanks():
            old_hp = hp_before.get((t.player, t.tank_type), 0)
            if old_hp > 0 and t.hp <= 0 and t.pos in self._hex_pixels:
                _sfx().play("death")
                dpx, dpy = self._hex_pixels[t.pos]
                self.effects.spawn_death_explosion(dpx, dpy)
                # Remove dead tank's sprite
                tk = (t.player, t.tank_type)
                if tk in self._tank_sprites:
                    self._tank_sprites.pop(tk, None)
                self._anim_lock = True

        # Check game over
        if self.state.winner is not None or self.state.game_over:
            reason = self._determine_reason()
            if self._anim_lock:
                self._pending_game_over = (self.state.winner, reason,
                                           self.state.turn_count,
                                           self._build_end_stats(),
                                           self._match_stats)
            else:
                self.window.show_game_over(self.state.winner, reason,
                                           turns=self.state.turn_count,
                                           stats=self._build_end_stats(),
                                           match_stats=self._match_stats)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _build_end_stats(self) -> dict:
        """Build a summary dict of tank states for the game-over screen."""
        if self.state is None:
            return {}
        stats = {}
        for pl in [1, 2]:
            for tt in [TankType.KTANK, TankType.QTANK]:
                tank = self.state.get_tank(pl, tt)
                lbl = "K" if tt == TankType.KTANK else "Q"
                stats[f"P{pl}{lbl}"] = {
                    "hp": tank.hp,
                    "max_hp": tank.max_hp,
                    "alive": tank.is_alive(),
                }
        return stats

    def _update_filtered_actions(self):
        if not self.selected_tank or not self.action_mode:
            self.filtered_actions = []
            return
        tt = self.selected_tank.tank_type
        at = ActionType.MOVE if self.action_mode == "move" else ActionType.ATTACK
        self.filtered_actions = [
            a for a in self.legal_actions
            if a.tank_type == tt and a.action_type == at
        ]

    def _select_tank_by_type(self, tt: TankType):
        """Select the current player's tank of the given type (1=Queen, 2=King)."""
        if self.state is None or self.state.game_over or self._anim_lock:
            return
        cp = self.state.current_player
        if (cp == 1 and self.ai_player1) or (cp == 2 and self.ai_player2):
            return
        tank = self.state.get_tank(cp, tt)
        if tank.is_alive():
            _sfx().play("select")
            self.selected_tank = tank
            self.action_mode = None
            self.filtered_actions = []

    def _execute_pass(self):
        cp = self.state.current_player
        for act in self.legal_actions:
            if act.action_type == ActionType.PASS and act.player == cp:
                self._apply_action_with_effects(act)
                return

    def _pixel_to_hex(self, px: float, py: float) -> Optional[HexCoord]:
        best, best_d = None, float("inf")
        for hc, (hx, hy) in self._hex_pixels.items():
            d = math.hypot(px - hx, py - hy)
            if d < HEX_SIZE and d < best_d:
                best, best_d = hc, d
        return best

    # -- Batch 6: Camera helpers ----------------------------------------

    def _screen_to_world(self, sx: float, sy: float) -> Tuple[float, float]:
        """Convert screen (mouse) coordinates to world coordinates."""
        vec = self.camera.unproject((sx, sy))
        return float(vec[0]), float(vec[1])

    def _reset_camera(self):
        """Reset zoom and pan to defaults (Home key)."""
        self._zoom_target = 1.0
        self._pan_target_x = 0.0
        self._pan_target_y = 0.0

    def _start_cinematic(self, world_x: float, world_y: float,
                         duration: float = 1.2):
        """Briefly pan camera toward a world position for cinematic effect."""
        if self._cine_active:
            return  # don't stack cinematics
        self._cine_saved_pan = (self._pan_target_x, self._pan_target_y)
        self._cine_saved_zoom = self._zoom_target
        # Offset from board centre
        self._pan_target_x = world_x - BOARD_OFFSET_X
        self._pan_target_y = world_y - BOARD_OFFSET_Y
        # Subtle zoom-in for dramatic emphasis
        self._zoom_target = min(self._zoom_target + 0.25, 2.5)
        self._cine_active = True
        self._cine_timer = duration
        self._cine_duration = duration

    def _determine_reason(self) -> str:
        """Build a human-readable reason string from the game events."""
        if self.state is None:
            return ""
        # Scan events for specific win / draw causes
        for ev in self.state.events:
            if ev.event_type == "win_center":
                p = ev.data.get("player", self.state.winner)
                return f"Player {p}'s King captured the centre!"
            if ev.event_type == "win_kill":
                p = ev.data.get("player", self.state.winner)
                killed = ev.data.get("killed", 3 - p)
                return f"Player {p} destroyed Player {killed}'s King!"
            if ev.event_type == "draw":
                w = ev.data.get("winner")
                if w:
                    return f"Draw resolved — Player {w} wins on tiebreaker."
                return "Draw — no tiebreaker could decide."
        # Fallback
        if self.state.winner:
            return f"Player {self.state.winner} wins!"
        if self.state.game_over:
            return "Draw!"
        return ""

    @staticmethod
    def _hex_corners(cx: float, cy: float, size: float) -> list[tuple[float, float]]:
        return [
            (cx + size * math.cos(math.radians(60 * i)),
             cy + size * math.sin(math.radians(60 * i)))
            for i in range(6)
        ]
