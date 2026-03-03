"""
Hex Siege Arena — Visual Effects System  (Phase 5: Effects Polish)
Manages animated effects (explosions, muzzle flashes, impacts, projectiles,
screen-shake, laser beams, flash overlays, particle sparks, power-up glow,
death explosions) using pooled sprites driven by frame-based animation.

Usage:
    effects = EffectsManager()
    effects.spawn_explosion(px, py)
    # in on_update:
    effects.update(delta_time)
    # in on_draw:
    effects.draw()
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import List, Optional, Tuple, Callable

import arcade

from . import assets


# ---------------------------------------------------------------------------
# Single animated effect
# ---------------------------------------------------------------------------
@dataclass
class AnimEffect:
    """One running visual effect."""
    sprite: arcade.Sprite
    frames: List[arcade.Texture]
    frame_duration: float         # seconds per frame
    elapsed: float = 0.0
    current_frame: int = 0
    alive: bool = True
    scale_start: float = 1.0
    scale_end: float = 1.0       # for grow / shrink
    alpha_start: int = 255
    alpha_end: int = 0            # fade out
    total_time: float = 0.0      # auto-computed
    rotation_speed: float = 0.0  # deg / sec
    # Phase 5: optional velocity drift (px/sec)
    vx: float = 0.0
    vy: float = 0.0

    def __post_init__(self):
        self.total_time = len(self.frames) * self.frame_duration

    def tick(self, dt: float):
        if not self.alive:
            return
        self.elapsed += dt

        # Frame advance
        idx = int(self.elapsed / self.frame_duration)
        if idx >= len(self.frames):
            self.alive = False
            return
        if idx != self.current_frame:
            self.current_frame = idx
            self.sprite.texture = self.frames[idx]

        # Interpolated scale
        t = self.elapsed / self.total_time if self.total_time > 0 else 1.0
        t = min(t, 1.0)
        self.sprite.scale = self.scale_start + (self.scale_end - self.scale_start) * t

        # Interpolated alpha
        alpha = int(self.alpha_start + (self.alpha_end - self.alpha_start) * t)
        self.sprite.alpha = max(0, min(255, alpha))

        # Rotation
        if self.rotation_speed:
            self.sprite.angle += self.rotation_speed * dt

        # Drift
        if self.vx or self.vy:
            self.sprite.center_x += self.vx * dt
            self.sprite.center_y += self.vy * dt


# ---------------------------------------------------------------------------
# Projectile (moves from A to B then despawns)
# ---------------------------------------------------------------------------
@dataclass
class Projectile:
    sprite: arcade.Sprite
    start_x: float
    start_y: float
    end_x: float
    end_y: float
    speed: float = 600.0          # px / sec
    elapsed: float = 0.0
    alive: bool = True
    on_hit: Optional[str] = None  # effect name to spawn on arrival
    # Phase 5: animated projectile frames
    frames: Optional[List[arcade.Texture]] = None
    frame_duration: float = 0.06
    _frame_idx: int = 0

    def tick(self, dt: float):
        if not self.alive:
            return
        dx = self.end_x - self.start_x
        dy = self.end_y - self.start_y
        dist = math.hypot(dx, dy)
        if dist == 0:
            self.alive = False
            return
        total_time = dist / self.speed
        self.elapsed += dt
        t = min(self.elapsed / total_time, 1.0)

        self.sprite.center_x = self.start_x + dx * t
        self.sprite.center_y = self.start_y + dy * t

        # Animate projectile frames
        if self.frames and len(self.frames) > 1:
            idx = int(self.elapsed / self.frame_duration) % len(self.frames)
            if idx != self._frame_idx:
                self._frame_idx = idx
                self.sprite.texture = self.frames[idx]

        if t >= 1.0:
            self.alive = False


# ---------------------------------------------------------------------------
# Screen-shake state  (Phase 5)
# ---------------------------------------------------------------------------
@dataclass
class _ScreenShake:
    """Tracks an active screen-shake."""
    intensity: float = 0.0       # current remaining magnitude in px
    decay: float = 60.0          # intensity lost per second
    offset_x: float = 0.0
    offset_y: float = 0.0

    def tick(self, dt: float):
        if self.intensity <= 0:
            self.offset_x = self.offset_y = 0.0
            return
        self.intensity = max(0.0, self.intensity - self.decay * dt)
        ang = random.uniform(0, math.tau)
        self.offset_x = math.cos(ang) * self.intensity
        self.offset_y = math.sin(ang) * self.intensity

    @property
    def active(self) -> bool:
        return self.intensity > 0


# ---------------------------------------------------------------------------
# Laser beam trail  (Phase 5)
# ---------------------------------------------------------------------------
@dataclass
class _LaserBeam:
    """A straight laser beam that fades out."""
    x1: float
    y1: float
    x2: float
    y2: float
    color: Tuple[int, int, int, int] = (120, 220, 255, 220)
    width: float = 4.0
    lifetime: float = 0.30
    elapsed: float = 0.0
    alive: bool = True

    def tick(self, dt: float):
        self.elapsed += dt
        if self.elapsed >= self.lifetime:
            self.alive = False


# ---------------------------------------------------------------------------
# Flash overlay  (Phase 5)
# ---------------------------------------------------------------------------
@dataclass
class _FlashOverlay:
    """Full-screen or localised white flash that fades."""
    alpha_start: int = 120
    lifetime: float = 0.18
    elapsed: float = 0.0
    alive: bool = True
    color: Tuple[int, int, int] = (255, 255, 255)

    def tick(self, dt: float):
        self.elapsed += dt
        if self.elapsed >= self.lifetime:
            self.alive = False

    @property
    def alpha(self) -> int:
        t = min(self.elapsed / self.lifetime, 1.0) if self.lifetime > 0 else 1.0
        return int(self.alpha_start * (1.0 - t))


# ---------------------------------------------------------------------------
# Floating damage number  (Batch 4)
# ---------------------------------------------------------------------------
@dataclass
class _DamageNumber:
    """Floating text showing damage dealt, rising and fading."""
    text: str
    x: float
    y: float
    color: Tuple[int, int, int] = (255, 80, 80)
    lifetime: float = 0.9
    elapsed: float = 0.0
    alive: bool = True
    rise_speed: float = 45.0
    font_size: int = 16

    def tick(self, dt: float):
        self.elapsed += dt
        self.y += self.rise_speed * dt
        # Slow down as it rises
        self.rise_speed = max(10.0, self.rise_speed - 35.0 * dt)
        if self.elapsed >= self.lifetime:
            self.alive = False

    @property
    def alpha(self) -> int:
        t = min(self.elapsed / self.lifetime, 1.0) if self.lifetime > 0 else 1.0
        # Fully opaque first 40%, then fade
        if t < 0.4:
            return 255
        return int(255 * (1.0 - (t - 0.4) / 0.6))

    @property
    def scale(self) -> float:
        """Pop-in scale: quick enlarge then settle."""
        t = min(self.elapsed / self.lifetime, 1.0)
        if t < 0.1:
            return 0.6 + 0.6 * (t / 0.1)   # 0.6 → 1.2
        elif t < 0.2:
            return 1.2 - 0.2 * ((t - 0.1) / 0.1)  # 1.2 → 1.0
        return 1.0


# ---------------------------------------------------------------------------
# Camera nudge  (Batch 4)
# ---------------------------------------------------------------------------
@dataclass
class _CameraNudge:
    """Directional camera impulse that smoothly returns to center."""
    dx: float = 0.0
    dy: float = 0.0
    elapsed: float = 0.0
    duration: float = 0.35
    active: bool = False

    def start(self, dx: float, dy: float, strength: float = 8.0, duration: float = 0.35):
        dist = math.hypot(dx, dy)
        if dist < 0.01:
            return
        self.dx = dx / dist * strength
        self.dy = dy / dist * strength
        self.elapsed = 0.0
        self.duration = max(duration, 0.01)
        self.active = True

    def tick(self, dt: float):
        if not self.active:
            return
        self.elapsed += dt
        if self.elapsed >= self.duration:
            self.active = False

    @property
    def offset(self) -> Tuple[float, float]:
        if not self.active:
            return (0.0, 0.0)
        t = min(self.elapsed / self.duration, 1.0)
        # Quick push out, slow ease back:  sin curve peaks at t≈0.25
        ease = math.sin(t * math.pi)
        return (self.dx * ease, self.dy * ease)


# ---------------------------------------------------------------------------
# Effects Manager
# ---------------------------------------------------------------------------
class EffectsManager:
    """Pool of running effects — update & draw each frame."""

    def __init__(self):
        self._effects: List[AnimEffect] = []
        self._projectiles: List[Projectile] = []
        self._effect_sprites = arcade.SpriteList()
        self._proj_sprites = arcade.SpriteList()
        # Phase 5 extras
        self._shake = _ScreenShake()
        self._beams: List[_LaserBeam] = []
        self._flashes: List[_FlashOverlay] = []
        # Batch 4 extras
        self._damage_numbers: List[_DamageNumber] = []
        self._nudge = _CameraNudge()

    # ------------------------------------------------------------------
    # Screen-shake  (Phase 5)
    # ------------------------------------------------------------------
    @property
    def shake_offset(self) -> Tuple[float, float]:
        """Current camera offset combining screen-shake + directional nudge."""
        nx, ny = self._nudge.offset
        return (self._shake.offset_x + nx, self._shake.offset_y + ny)

    def start_shake(self, intensity: float = 6.0, decay: float = 40.0):
        """Trigger a screen-shake impulse."""
        self._shake.intensity = max(self._shake.intensity, intensity)
        self._shake.decay = decay

    def start_nudge(self, dx: float, dy: float, strength: float = 8.0,
                    duration: float = 0.35):
        """Directional camera nudge toward an attack target."""
        self._nudge.start(dx, dy, strength, duration)

    def spawn_damage_number(
        self, px: float, py: float, amount: int,
        color: Tuple[int, int, int] = (255, 80, 80),
        font_size: int = 16,
    ):
        """Spawn a floating damage number at (px, py)."""
        self._damage_numbers.append(_DamageNumber(
            text=f"-{amount}",
            x=px, y=py + 18,  # start slightly above impact
            color=color,
            font_size=font_size,
        ))

    def spawn_heal_number(
        self, px: float, py: float, text: str,
        color: Tuple[int, int, int] = (100, 255, 120),
    ):
        """Spawn a floating positive text (shield, buff, etc.)."""
        self._damage_numbers.append(_DamageNumber(
            text=text,
            x=px, y=py + 18,
            color=color,
            lifetime=1.0,
            rise_speed=35.0,
            font_size=14,
        ))

    # ------------------------------------------------------------------
    # Spawn helpers  (original — unchanged API)
    # ------------------------------------------------------------------
    def spawn_explosion(self, px: float, py: float, scale: float = 0.35):
        """Big 9-frame explosion centred at (px, py)."""
        frames = assets.get_explosion_frames()
        if not frames:
            return
        sp = arcade.Sprite(frames[0], scale=scale)
        sp.center_x = px
        sp.center_y = py
        sp.angle = random.uniform(0, 360)
        eff = AnimEffect(
            sprite=sp,
            frames=frames,
            frame_duration=0.06,
            scale_start=scale * 0.6,
            scale_end=scale * 1.4,
            alpha_start=255,
            alpha_end=80,
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    def spawn_muzzle_flash(self, px: float, py: float, angle_deg: float = 0, scale: float = 0.22):
        """Quick muzzle flash at barrel tip."""
        frames = assets.get_flame_shot_frames()
        if not frames:
            return
        sp = arcade.Sprite(frames[0], scale=scale)
        sp.center_x = px
        sp.center_y = py
        sp.angle = -angle_deg
        eff = AnimEffect(
            sprite=sp,
            frames=frames,
            frame_duration=0.035,
            alpha_start=255,
            alpha_end=0,
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    def spawn_impact(self, px: float, py: float, scale: float = 0.25):
        """Small impact sparks."""
        variant = random.choice(["A", "B"])
        frames = assets.get_impact_frames(variant)
        if not frames:
            return
        sp = arcade.Sprite(frames[0], scale=scale)
        sp.center_x = px
        sp.center_y = py
        sp.angle = random.uniform(0, 360)
        eff = AnimEffect(
            sprite=sp,
            frames=frames,
            frame_duration=0.05,
            alpha_start=255,
            alpha_end=60,
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    def spawn_exhaust(self, px: float, py: float, angle_deg: float = 0, scale: float = 0.18):
        """Tank movement exhaust puff."""
        variant = random.choice([1, 2])
        frames = assets.get_exhaust_frames(variant)
        if not frames:
            return
        sp = arcade.Sprite(frames[0], scale=scale)
        sp.center_x = px
        sp.center_y = py
        sp.angle = -angle_deg + 180
        eff = AnimEffect(
            sprite=sp,
            frames=frames,
            frame_duration=0.04,
            alpha_start=200,
            alpha_end=0,
            scale_start=scale,
            scale_end=scale * 1.5,
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    def spawn_smoke(self, px: float, py: float, scale: float = 0.2):
        """Static smoke puff that fades."""
        textures = assets.get_smoke_textures()
        if not textures:
            return
        tex = random.choice(textures)
        sp = arcade.Sprite(tex, scale=scale)
        sp.center_x = px + random.uniform(-5, 5)
        sp.center_y = py + random.uniform(-5, 5)
        sp.alpha = 180
        sp.angle = random.uniform(0, 360)
        eff = AnimEffect(
            sprite=sp,
            frames=[tex],
            frame_duration=0.8,
            alpha_start=180,
            alpha_end=0,
            scale_start=scale,
            scale_end=scale * 2.0,
            rotation_speed=random.uniform(-20, 20),
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    # ------------------------------------------------------------------
    # Phase 5: New effect spawners
    # ------------------------------------------------------------------
    def spawn_laser_beam(
        self,
        x1: float, y1: float,
        x2: float, y2: float,
        color: Tuple[int, int, int, int] = (120, 220, 255, 220),
        width: float = 4.0,
        lifetime: float = 0.30,
    ):
        """Spawn a straight laser beam trail that fades out."""
        self._beams.append(_LaserBeam(
            x1=x1, y1=y1, x2=x2, y2=y2,
            color=color, width=width, lifetime=lifetime,
        ))

    def spawn_flash_overlay(
        self,
        alpha: int = 100,
        lifetime: float = 0.15,
        color: Tuple[int, int, int] = (255, 255, 255),
    ):
        """Spawn a full-screen white flash that fades."""
        self._flashes.append(_FlashOverlay(
            alpha_start=alpha, lifetime=lifetime, color=color,
        ))

    def spawn_sparks(self, px: float, py: float, count: int = 5, scale: float = 0.10):
        """Spawn small particle sparks flying outward (for block destruction)."""
        textures = assets.get_flash_textures("A")
        if not textures:
            return
        for _ in range(count):
            tex = random.choice(textures)
            sp = arcade.Sprite(tex, scale=scale)
            sp.center_x = px + random.uniform(-4, 4)
            sp.center_y = py + random.uniform(-4, 4)
            sp.angle = random.uniform(0, 360)
            ang = random.uniform(0, math.tau)
            spd = random.uniform(30, 90)
            eff = AnimEffect(
                sprite=sp,
                frames=[tex],
                frame_duration=0.35,
                alpha_start=255,
                alpha_end=0,
                scale_start=scale,
                scale_end=scale * 0.3,
                rotation_speed=random.uniform(-200, 200),
                vx=math.cos(ang) * spd,
                vy=math.sin(ang) * spd,
            )
            self._effects.append(eff)
            self._effect_sprites.append(sp)

    def spawn_pickup_glow(self, px: float, py: float, color: Tuple[int, int, int] = (100, 255, 120)):
        """Rising glow effect when a power-up is collected."""
        textures = assets.get_flash_textures("B")
        if not textures:
            return
        tex = textures[0]
        sp = arcade.Sprite(tex, scale=0.15)
        sp.center_x = px
        sp.center_y = py
        eff = AnimEffect(
            sprite=sp,
            frames=[tex],
            frame_duration=0.6,
            alpha_start=220,
            alpha_end=0,
            scale_start=0.15,
            scale_end=0.40,
            vy=40.0,  # rises upward
        )
        self._effects.append(eff)
        self._effect_sprites.append(sp)

    def spawn_death_explosion(self, px: float, py: float):
        """Large multi-layered explosion when a tank is destroyed."""
        # Main big explosion
        self.spawn_explosion(px, py, scale=0.55)
        # Secondary explosion ring (staggered)
        for _ in range(3):
            ox = random.uniform(-12, 12)
            oy = random.uniform(-12, 12)
            frames = assets.get_explosion_frames()
            if not frames:
                break
            sp = arcade.Sprite(frames[0], scale=0.30)
            sp.center_x = px + ox
            sp.center_y = py + oy
            sp.angle = random.uniform(0, 360)
            eff = AnimEffect(
                sprite=sp,
                frames=frames,
                frame_duration=0.07,
                scale_start=0.2,
                scale_end=0.45,
                alpha_start=255,
                alpha_end=40,
            )
            self._effects.append(eff)
            self._effect_sprites.append(sp)
        # Smoke lingering
        for _ in range(4):
            self.spawn_smoke(px + random.uniform(-15, 15), py + random.uniform(-15, 15), scale=0.25)
        # Flash + shake
        self.spawn_flash_overlay(alpha=80, lifetime=0.12)
        self.start_shake(intensity=8.0, decay=50.0)

    def spawn_animated_projectile(
        self,
        start_x: float, start_y: float,
        end_x: float, end_y: float,
        projectile_type: str = "shot",
        speed: float = 600.0,
        scale: float = 0.15,
    ):
        """Spawn a projectile that uses animated shot frames."""
        if projectile_type == "shot":
            frames = assets.get_shot_frames(random.choice(["A", "B"]))
        else:
            frames = assets.get_shot_frames("A")
        if not frames:
            # fallback to static
            self.spawn_projectile(start_x, start_y, end_x, end_y,
                                  projectile_type="laser", speed=speed, scale=scale)
            return

        sp = arcade.Sprite(frames[0], scale=scale)
        sp.center_x = start_x
        sp.center_y = start_y
        dx = end_x - start_x
        dy = end_y - start_y
        angle = math.degrees(math.atan2(-dx, dy))
        sp.angle = -angle

        proj = Projectile(
            sprite=sp,
            start_x=start_x, start_y=start_y,
            end_x=end_x, end_y=end_y,
            speed=speed,
            on_hit="impact",
            frames=frames,
            frame_duration=0.05,
        )
        self._projectiles.append(proj)
        self._proj_sprites.append(sp)

    # ------------------------------------------------------------------
    # Projectile spawning  (original)
    # ------------------------------------------------------------------
    def spawn_projectile(
        self,
        start_x: float, start_y: float,
        end_x: float, end_y: float,
        projectile_type: str = "laser",
        speed: float = 600.0,
        scale: float = 0.18,
    ):
        """Spawn a projectile that flies from start to end."""
        if projectile_type == "laser":
            tex = assets.get_static_effect("Laser")
        elif projectile_type == "bomb":
            tex = assets.get_static_effect("Heavy_Shell")
        else:
            tex = assets.get_static_effect("Medium_Shell")

        sp = arcade.Sprite(tex, scale=scale)
        sp.center_x = start_x
        sp.center_y = start_y
        dx = end_x - start_x
        dy = end_y - start_y
        angle = math.degrees(math.atan2(-dx, dy))
        sp.angle = -angle

        proj = Projectile(
            sprite=sp,
            start_x=start_x, start_y=start_y,
            end_x=end_x, end_y=end_y,
            speed=speed,
            on_hit="explosion" if projectile_type == "bomb" else "impact",
        )
        self._projectiles.append(proj)
        self._proj_sprites.append(sp)

    # ------------------------------------------------------------------
    # Update / Draw
    # ------------------------------------------------------------------
    def update(self, dt: float):
        # Screen-shake + nudge
        self._shake.tick(dt)
        self._nudge.tick(dt)

        # Damage numbers
        for dn in self._damage_numbers:
            dn.tick(dt)
        self._damage_numbers = [d for d in self._damage_numbers if d.alive]

        # Effects
        for eff in self._effects:
            eff.tick(dt)
        dead_effects = [e for e in self._effects if not e.alive]
        for e in dead_effects:
            if e.sprite in self._effect_sprites:
                self._effect_sprites.remove(e.sprite)
        self._effects = [e for e in self._effects if e.alive]

        # Projectiles
        newly_dead: List[Projectile] = []
        for proj in self._projectiles:
            proj.tick(dt)
            if not proj.alive:
                newly_dead.append(proj)
        for p in newly_dead:
            if p.sprite in self._proj_sprites:
                self._proj_sprites.remove(p.sprite)
        self._projectiles = [p for p in self._projectiles if p.alive]

        # Spawn hit effects for arrived projectiles
        for proj in newly_dead:
            if proj.on_hit == "explosion":
                self.spawn_explosion(proj.end_x, proj.end_y, scale=0.40)
            elif proj.on_hit == "impact":
                self.spawn_impact(proj.end_x, proj.end_y)

        # Laser beams
        for b in self._beams:
            b.tick(dt)
        self._beams = [b for b in self._beams if b.alive]

        # Flash overlays
        for f in self._flashes:
            f.tick(dt)
        self._flashes = [f for f in self._flashes if f.alive]

    def draw(self):
        """Draw all living effects and projectiles."""
        # Laser beams (under projectiles/effects)
        for b in self._beams:
            t = min(b.elapsed / b.lifetime, 1.0) if b.lifetime > 0 else 1.0
            alpha = int(b.color[3] * (1.0 - t))
            w = b.width * (1.0 + t * 0.5)  # slightly expand
            col = (b.color[0], b.color[1], b.color[2], alpha)
            arcade.draw_line(b.x1, b.y1, b.x2, b.y2, col, w)
            # Inner bright core
            core_alpha = int(alpha * 0.6)
            arcade.draw_line(b.x1, b.y1, b.x2, b.y2,
                             (255, 255, 255, core_alpha), max(1, w * 0.4))

        self._proj_sprites.draw()
        self._effect_sprites.draw()

        # Flash overlays (on top)
        for f in self._flashes:
            a = f.alpha
            if a > 0:
                arcade.draw_lbwh_rectangle_filled(
                    0, 0, 2000, 2000,
                    (f.color[0], f.color[1], f.color[2], a),
                )

        # Floating damage / status numbers (world-space)
        for dn in self._damage_numbers:
            a = dn.alpha
            if a > 0:
                s = dn.scale
                fs = max(8, int(dn.font_size * s))
                arcade.draw_text(
                    dn.text,
                    dn.x, dn.y,
                    (*dn.color, a),
                    fs,
                    anchor_x="center", anchor_y="center",
                    bold=True,
                )

    @property
    def busy(self) -> bool:
        """True when any animation or projectile is still running."""
        return (bool(self._effects) or bool(self._projectiles)
                or bool(self._beams) or bool(self._flashes))
