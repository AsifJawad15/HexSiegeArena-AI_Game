"""
Hex Siege Arena — Tank Sprite  (Phase 4: Tank Rendering Polish)
Composite arcade.Sprite that layers tracks + hull + gun into a single
drawable unit.  Features: smooth lerp movement, facing rotation,
pulsing selection ring, team-coloured base, role labels, buff badges,
damage flash.

Usage:
    tank_sprite = TankSprite(player=1, role="king", scale=0.28)
    tank_sprite.place(px, py, angle_deg=0)
    tank_sprite.draw_layers()
"""

from __future__ import annotations

import math
from typing import Optional, Tuple

import arcade

from . import assets


# ---------------------------------------------------------------------------
# Sizing
# ---------------------------------------------------------------------------
DEFAULT_SCALE = 0.26
TRACK_SCALE_FACTOR = 256 / 246  # ≈ 1.04

# -- Team / role colours (unique per tank) --
TEAM_COLORS = {
    (1, "king"):  (80, 160, 255, 50),    # P1 King  — blue
    (1, "queen"): (50, 200, 120, 50),    # P1 Queen — teal / green
    (2, "king"):  (255, 180, 60, 50),    # P2 King  — amber / sand
    (2, "queen"): (255, 80, 80, 50),     # P2 Queen — red
}
TEAM_RING_COLORS = {
    (1, "king"):  (80, 160, 255, 120),
    (1, "queen"): (50, 200, 120, 120),
    (2, "king"):  (255, 180, 60, 120),
    (2, "queen"): (255, 80, 80, 120),
}
ROLE_LABEL_COLORS = {
    (1, "king"):  (130, 190, 255),
    (1, "queen"): (100, 220, 160),
    (2, "king"):  (255, 200, 110),
    (2, "queen"): (255, 130, 130),
}
SELECT_COLOR = (255, 255, 100, 255)

# -- Buff badge colours --
BUFF_COLORS = {
    "ATTACK_X2": (255, 50, 50, 200),
    "SHIELD":    (60, 180, 255, 200),
}


class TankSprite(arcade.Sprite):
    """
    A composite sprite representing one tank on the board.

    The parent sprite carries the *hull* texture.
    Two child sprites (left track, right track) are added at fixed offsets.
    A child sprite for the *gun* sits on top.

    Phase 4 additions:
    - Smooth lerp movement via ``move_to()`` + ``tick()``
    - Facing rotation toward last movement direction
    - Damage flash overlay
    - Team base circle, role label, buff badges drawn in ``draw_layers()``
    """

    def __init__(
        self,
        player: int,
        role: str,            # "king" | "queen"
        scale: float = DEFAULT_SCALE,
    ):
        # Hull as the base sprite
        hull_tex = assets.get_hull_texture(player, role)
        super().__init__(hull_tex, scale=scale)

        self.player = player
        self.role = role
        self._base_angle: float = 0.0  # degrees, 0 = pointing up (north)

        # --- Tracks (left & right) -----------------------------------
        track_sc = scale * TRACK_SCALE_FACTOR
        track_tex_a = assets.get_track_texture(role, "A")
        track_tex_b = assets.get_track_texture(role, "B")

        self._track_frames = (track_tex_a, track_tex_b)
        self._track_frame_idx = 0

        self.track_left = arcade.Sprite(track_tex_a, scale=track_sc)
        self.track_right = arcade.Sprite(track_tex_a, scale=track_sc)

        self._track_offset_x = 75 * scale

        # --- Gun / Turret --------------------------------------------
        gun_tex = assets.get_gun_texture(player, role, "")
        self.gun = arcade.Sprite(gun_tex, scale=scale)
        self._gun_angle: float = 0.0

        self._gun_tex_default = gun_tex
        self._gun_tex_fired_a = assets.get_gun_texture(player, role, "_A")
        self._gun_tex_fired_b = assets.get_gun_texture(player, role, "_B")
        self._gun_fired_timer: float = 0.0

        self._gun_offset_y = 20 * scale

        # SpriteList for batched layer drawing (tracks → hull → gun)
        self._draw_list = arcade.SpriteList()
        self._draw_list.append(self.track_left)
        self._draw_list.append(self.track_right)
        self._draw_list.append(self)  # hull
        self._draw_list.append(self.gun)

        # -- Phase 4: Smooth movement lerp -----------------------------
        self._lerp_active: bool = False
        self._lerp_src: Tuple[float, float] = (0.0, 0.0)
        self._lerp_dst: Tuple[float, float] = (0.0, 0.0)
        self._lerp_elapsed: float = 0.0
        self._lerp_duration: float = 0.55    # seconds per move (slower for visual feedback)

        # -- Phase 4: Damage flash ------------------------------------
        self._flash_timer: float = 0.0
        self._flash_duration: float = 0.18

        # -- Phase 4: Pulsing selection --------------------------------
        self._select_pulse_t: float = 0.0

        # -- Phase 4: Persistent role label Text -----------------------
        rl = "K" if role == "king" else "Q"
        rc = ROLE_LABEL_COLORS.get((player, role), (200, 200, 200))
        from .app import FONT_NAME as _FN
        self._role_text = arcade.Text(
            rl, 0, 0, color=rc,
            font_size=10, anchor_x="center", anchor_y="center",
            bold=True, font_name=_FN,
        )

        # -- Phase 4: Persistent buff text ----------------------------
        self._buff_text = arcade.Text(
            "", 0, 0, color=(255, 255, 255, 200),
            font_size=9, anchor_x="center", anchor_y="center",
            bold=True, font_name=_FN,
        )

    # ------------------------------------------------------------------
    # Placement (immediate)
    # ------------------------------------------------------------------
    def place(self, px: float, py: float, angle_deg: float = 0.0):
        """
        Move the whole assembly to *(px, py)* and set the base rotation.
        *angle_deg*: 0 = north, 90 = east, etc. (clockwise).
        """
        self._base_angle = angle_deg
        self._position_assembly(px, py, angle_deg)

    def _position_assembly(self, px: float, py: float, angle_deg: float):
        """Internal: set all child positions for a given centre + angle."""
        # Parent (hull)
        self.center_x = px
        self.center_y = py
        self.angle = -angle_deg  # arcade uses counter-clockwise

        # Compute rotated offsets for tracks
        rad = math.radians(angle_deg)
        cos_a, sin_a = math.cos(rad), math.sin(rad)

        lx, ly = -self._track_offset_x, 0.0
        self.track_left.center_x = px + lx * cos_a - ly * sin_a
        self.track_left.center_y = py - (lx * sin_a + ly * cos_a)
        self.track_left.angle = -angle_deg

        rx, ry = self._track_offset_x, 0.0
        self.track_right.center_x = px + rx * cos_a - ry * sin_a
        self.track_right.center_y = py - (rx * sin_a + ry * cos_a)
        self.track_right.angle = -angle_deg

        gx, gy = 0.0, self._gun_offset_y
        self.gun.center_x = px + gx * cos_a - gy * sin_a
        self.gun.center_y = py - (gx * sin_a + gy * cos_a)
        self.gun.angle = -(angle_deg + self._gun_angle)

    # ------------------------------------------------------------------
    # Smooth movement  (Phase 4)
    # ------------------------------------------------------------------
    def move_to(self, px: float, py: float, duration: float = 0.20):
        """
        Start a lerp from current position to *(px, py)*.
        While active, call ``tick(dt)`` every frame.
        """
        self._lerp_src = (self.center_x, self.center_y)
        self._lerp_dst = (px, py)
        self._lerp_elapsed = 0.0
        self._lerp_duration = max(duration, 0.01)
        self._lerp_active = True

        # Face the movement direction
        dx = px - self.center_x
        dy = py - self.center_y
        if abs(dx) > 0.5 or abs(dy) > 0.5:
            face_angle = math.degrees(math.atan2(-dx, dy))  # 0=north CW
            self._base_angle = face_angle

    @property
    def is_moving(self) -> bool:
        return self._lerp_active

    @staticmethod
    def _ease_in_out_back(t: float, overshoot: float = 1.30) -> float:
        """Ease-in-out-back: slight pull-back on start, overshoot on land."""
        s = overshoot
        if t < 0.5:
            p = 2.0 * t
            return 0.5 * (p * p * ((s + 1.0) * p - s))
        else:
            p = 2.0 * t - 2.0
            return 0.5 * (p * p * ((s + 1.0) * p + s) + 2.0)

    def tick(self, dt: float):
        """Advance lerp + flash timers.  Call every frame."""
        # Lerp movement
        if self._lerp_active:
            self._lerp_elapsed += dt
            t = min(self._lerp_elapsed / self._lerp_duration, 1.0)
            # Ease-in-out-back for juicy "pull-back → overshoot → settle"
            t = self._ease_in_out_back(t)
            sx, sy = self._lerp_src
            ex, ey = self._lerp_dst
            px = sx + (ex - sx) * t
            py = sy + (ey - sy) * t
            self._position_assembly(px, py, self._base_angle)
            if self._lerp_elapsed >= self._lerp_duration:
                self._position_assembly(ex, ey, self._base_angle)
                self._lerp_active = False

        # Damage flash countdown
        if self._flash_timer > 0:
            self._flash_timer -= dt
            if self._flash_timer < 0:
                self._flash_timer = 0.0

        # Selection pulse
        self._select_pulse_t += dt

    # ------------------------------------------------------------------
    # Damage flash  (Phase 4)
    # ------------------------------------------------------------------
    def flash_damage(self):
        """Trigger a brief white flash on the hull."""
        self._flash_timer = self._flash_duration

    # ------------------------------------------------------------------
    # Turret aiming
    # ------------------------------------------------------------------
    def aim_gun(self, target_x: float, target_y: float):
        dx = target_x - self.gun.center_x
        dy = target_y - self.gun.center_y
        target_angle = math.degrees(math.atan2(-dx, dy))
        self._gun_angle = target_angle - self._base_angle
        self.gun.angle = -target_angle

    def set_gun_angle(self, angle_deg: float):
        self._gun_angle = angle_deg - self._base_angle
        self.gun.angle = -angle_deg

    # ------------------------------------------------------------------
    # Firing animation
    # ------------------------------------------------------------------
    def fire(self):
        self.gun.texture = self._gun_tex_fired_a
        self._gun_fired_timer = 0.25

    def update_animation(self, delta_time: float = 1 / 60):
        if self._gun_fired_timer > 0:
            self._gun_fired_timer -= delta_time
            if self._gun_fired_timer <= 0:
                self.gun.texture = self._gun_tex_default

    def cycle_tracks(self):
        self._track_frame_idx = 1 - self._track_frame_idx
        tex = self._track_frames[self._track_frame_idx]
        self.track_left.texture = tex
        self.track_right.texture = tex

    # ------------------------------------------------------------------
    # Health-bar helper
    # ------------------------------------------------------------------
    def hp_bar_pos(self) -> tuple[float, float]:
        return self.center_x, self.center_y - self.height / 2 - 8

    # ------------------------------------------------------------------
    # Draw  (Phase 4: extended with team base, role label, buffs, flash)
    # ------------------------------------------------------------------
    def draw_layers(
        self,
        selected: bool = False,
        buff_name: str = "",
        hex_size: float = 38.0,
    ):
        """
        Draw the full tank in correct layer order, with overlays.

        *selected*: draw pulsing selection ring.
        *buff_name*: "ATTACK_X2" | "SHIELD" | "" — draws a small badge.
        *hex_size*: used for sizing the base circle and ring.
        """
        cx, cy = self.center_x, self.center_y

        # 1) Team-coloured base circle (below everything)
        tk = (self.player, self.role)
        base_col = TEAM_COLORS.get(tk, (128, 128, 128, 40))
        arcade.draw_circle_filled(cx, cy, hex_size * 0.52, base_col)
        ring_col = TEAM_RING_COLORS.get(tk, (128, 128, 128, 80))
        arcade.draw_circle_outline(cx, cy, hex_size * 0.52, ring_col, 1.5)

        # 2) Sprite layers  (tracks → hull → gun)
        self._draw_list.draw()

        # 3) Damage flash overlay (white additive-ish)
        if self._flash_timer > 0:
            ratio = self._flash_timer / self._flash_duration
            alpha = int(180 * ratio)
            arcade.draw_circle_filled(cx, cy, hex_size * 0.42, (255, 255, 255, alpha))

        # 4) Pulsing selection ring
        if selected:
            pulse = 0.5 + 0.5 * math.sin(self._select_pulse_t * 5.0)
            alpha = int(140 + 115 * pulse)
            lw = 2.0 + 1.5 * pulse
            arcade.draw_circle_outline(
                cx, cy, hex_size * 0.60,
                (SELECT_COLOR[0], SELECT_COLOR[1], SELECT_COLOR[2], alpha),
                lw,
            )

        # 5) Role label (K or Q) — top-left corner
        label_x = cx - hex_size * 0.38
        label_y = cy + hex_size * 0.38
        self._role_text.x = label_x
        self._role_text.y = label_y
        self._role_text.draw()

        # 6) Buff badge — bottom-right corner
        if buff_name and buff_name in BUFF_COLORS:
            badge_x = cx + hex_size * 0.35
            badge_y = cy - hex_size * 0.35
            bc = BUFF_COLORS[buff_name]
            arcade.draw_circle_filled(badge_x, badge_y, 7, bc)
            sym = "\u2694" if buff_name == "ATTACK_X2" else "\u2764"
            self._buff_text.text = sym
            self._buff_text.x = badge_x
            self._buff_text.y = badge_y
            self._buff_text.draw()
