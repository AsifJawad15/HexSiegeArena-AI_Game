# Audio Layout In Use

This file documents the actual audio files selected for the current build and where they now live inside `assets/audio`.

The source packs reviewed were:
- `kenney_ui-audio`
- `kenney_digital-audio`
- `kenney_sci-fi-sounds`
- `custom`

The selected files have been copied into `assets/audio/...` with stable names so the game can use them directly.

## Music Picks

These are the main music choices currently used:

- `assets/audio/music/menu_loop.mp3`
  - Source: `custom/Menu Music.mp3`
  - Used in: main menu and settings scene
  - Reason: best fit for a calm menu atmosphere

- `assets/audio/music/match_loop.wav`
  - Source: `custom/game bg2.wav`
  - Used in: match scene
  - Reason: strongest fit for continuous tactical gameplay background

- `assets/audio/music/victory_sting.wav`
  - Source: `custom/soundscrate-videogamebundle-success.wav`
  - Used in: victory accent layer

- `assets/audio/music/defeat_sting.mp3`
  - Source: `custom/game over.mp3`
  - Used in: defeat accent layer

## UI Audio

- `assets/audio/ui/ui_click.ogg`
  - Source: `kenney_ui-audio/Audio/click5.ogg`
  - Use: default button press

- `assets/audio/ui/ui_back.ogg`
  - Source: `kenney_digital-audio/Audio/lowDown.ogg`
  - Use: back navigation

- `assets/audio/ui/ui_hover.ogg`
  - Source: `kenney_ui-audio/Audio/rollover4.ogg`
  - Use: button hover

- `assets/audio/ui/ui_confirm.ogg`
  - Source: `kenney_digital-audio/Audio/highUp.ogg`
  - Use: positive confirmation tone

- `assets/audio/ui/ui_cancel.ogg`
  - Source: `kenney_digital-audio/Audio/highDown.ogg`
  - Use: cancel / negative UI tone

## Gameplay Audio

- `assets/audio/gameplay/turn_change.ogg`
  - Source: `kenney_digital-audio/Audio/twoTone1.ogg`
  - Use: turn handoff

- `assets/audio/gameplay/move_light.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/thrusterFire_002.ogg`
  - Use: Qtank movement

- `assets/audio/gameplay/move_heavy.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/spaceEngineLow_002.ogg`
  - Use: Ktank movement

- `assets/audio/gameplay/hit_light.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/impactMetal_001.ogg`
  - Use: lighter hit feedback

- `assets/audio/gameplay/hit_heavy.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/impactMetal_004.ogg`
  - Use: heavy hit feedback

- `assets/audio/gameplay/tank_destroyed.wav`
  - Source: `custom/soundscrate-videogamebundle-explosion.wav`
  - Use: unit destruction

- `assets/audio/gameplay/block_destroyed.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/explosionCrunch_001.ogg`
  - Use: destructible block break

- `assets/audio/gameplay/armor_block_hit.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/impactMetal_003.ogg`
  - Use: armor block impact

- `assets/audio/gameplay/win_player.wav`
  - Source: `custom/soundscrate-videogamebundle-victory.wav`
  - Use: win result

- `assets/audio/gameplay/lose_player.wav`
  - Source: `custom/palyer loose.wav`
  - Use: lose result

- `assets/audio/gameplay/draw.ogg`
  - Source: `kenney_digital-audio/Audio/lowThreeTone.ogg`
  - Use: draw result

- `assets/audio/gameplay/extra_action.ogg`
  - Source: `kenney_digital-audio/Audio/powerUp10.ogg`
  - Use: extra action granted

## Weapon Audio

- `assets/audio/weapons/laser_charge.ogg`
  - Source: `kenney_digital-audio/Audio/phaserUp5.ogg`
  - Use: Qtank attack wind-up

- `assets/audio/weapons/laser_fire.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/laserLarge_002.ogg`
  - Use: Qtank main firing sound

- `assets/audio/weapons/laser_hit_tank.ogg`
  - Source: `kenney_digital-audio/Audio/zap2.ogg`
  - Use: Qtank hit on tank

- `assets/audio/weapons/laser_hit_wall.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/impactMetal_002.ogg`
  - Use: Qtank hit on wall / obstacle

- `assets/audio/weapons/blast_charge.ogg`
  - Source: `custom/sndfx/Guns/gun2HeavyLoad.ogg`
  - Use: Ktank blast wind-up

- `assets/audio/weapons/blast_fire.ogg`
  - Source: `custom/sndfx/Guns/gun2Heavy.ogg`
  - Use: Ktank main blast trigger

- `assets/audio/weapons/blast_hit.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/explosionCrunch_003.ogg`
  - Use: Ktank blast impact

- `assets/audio/weapons/explosion_small.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg`
  - Use: extra explosion support layer

## Power-Up Audio

- `assets/audio/powerups/pickup_attack.ogg`
  - Source: `kenney_digital-audio/Audio/powerUp5.ogg`
  - Use: attack buff pickup

- `assets/audio/powerups/pickup_shield.ogg`
  - Source: `kenney_digital-audio/Audio/powerUp2.ogg`
  - Use: shield buff pickup

- `assets/audio/powerups/pickup_bonus_move.ogg`
  - Source: `kenney_digital-audio/Audio/powerUp11.ogg`
  - Use: bonus move pickup

- `assets/audio/powerups/shield_trigger.ogg`
  - Source: `kenney_sci-fi-sounds/Audio/forceField_003.ogg`
  - Use: shield absorbing a hit

## Notes

- The current build now has enough audio to implement real-time music and action feedback.
- If any one sound feels weak in-game, it can be swapped later without changing code, as long as the destination filename stays the same.
- The `custom` folder still contains extra sounds, but only the files listed above are part of the active runtime set.
