extends Node

const AUDIO_PATHS := {
	"ui_click": "res://assets/audio/ui/ui_click.ogg",
	"ui_back": "res://assets/audio/ui/ui_back.ogg",
	"ui_hover": "res://assets/audio/ui/ui_hover.ogg",
	"ui_confirm": "res://assets/audio/ui/ui_confirm.ogg",
	"ui_cancel": "res://assets/audio/ui/ui_cancel.ogg",
	"turn_change": "res://assets/audio/gameplay/turn_change.ogg",
	"move_light": "res://assets/audio/gameplay/move_light.ogg",
	"move_heavy": "res://assets/audio/gameplay/move_heavy.ogg",
	"hit_light": "res://assets/audio/gameplay/hit_light.ogg",
	"hit_heavy": "res://assets/audio/gameplay/hit_heavy.ogg",
	"tank_destroyed": "res://assets/audio/gameplay/tank_destroyed.wav",
	"block_destroyed": "res://assets/audio/gameplay/block_destroyed.ogg",
	"armor_block_hit": "res://assets/audio/gameplay/armor_block_hit.ogg",
	"win_player": "res://assets/audio/gameplay/win_player.wav",
	"lose_player": "res://assets/audio/gameplay/lose_player.wav",
	"draw": "res://assets/audio/gameplay/draw.ogg",
	"extra_action": "res://assets/audio/gameplay/extra_action.ogg",
	"laser_charge": "res://assets/audio/weapons/laser_charge.ogg",
	"laser_fire": "res://assets/audio/weapons/laser_fire.ogg",
	"laser_hit_tank": "res://assets/audio/weapons/laser_hit_tank.ogg",
	"laser_hit_wall": "res://assets/audio/weapons/laser_hit_wall.ogg",
	"blast_charge": "res://assets/audio/weapons/blast_charge.ogg",
	"blast_fire": "res://assets/audio/weapons/blast_fire.ogg",
	"blast_hit": "res://assets/audio/weapons/blast_hit.ogg",
	"explosion_small": "res://assets/audio/weapons/explosion_small.ogg",
	"pickup_attack": "res://assets/audio/powerups/pickup_attack.ogg",
	"pickup_shield": "res://assets/audio/powerups/pickup_shield.ogg",
	"pickup_bonus_move": "res://assets/audio/powerups/pickup_bonus_move.ogg",
	"shield_trigger": "res://assets/audio/powerups/shield_trigger.ogg",
	"menu_loop": "res://assets/audio/music/menu_loop.mp3",
	"match_loop": "res://assets/audio/music/match_loop.wav",
	"victory_sting": "res://assets/audio/music/victory_sting.wav",
	"defeat_sting": "res://assets/audio/music/defeat_sting.mp3",
}
const LOOPING_MUSIC := {
	"menu_loop": true,
	"match_loop": true,
}

var music_volume_db: float = -16.0
var sfx_volume_db: float = -8.0
var ui_volume_db: float = -10.0
var _music_player: AudioStreamPlayer
var _current_music_key: String = ""
var _last_hover_msec: int = 0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = music_volume_db
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)


func set_music_volume_db(value: float) -> void:
	music_volume_db = value
	if _music_player != null:
		_music_player.volume_db = music_volume_db


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = value


func set_ui_volume_db(value: float) -> void:
	ui_volume_db = value


func play_menu_music() -> void:
	_play_music("menu_loop")


func play_match_music() -> void:
	_play_music("match_loop")


func play_ui_click() -> void:
	_play_sfx("ui_click", ui_volume_db)


func play_ui_back() -> void:
	_play_sfx("ui_back", ui_volume_db - 1.0)


func play_ui_hover() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_hover_msec < 75:
		return
	_last_hover_msec = now_msec
	_play_sfx("ui_hover", ui_volume_db - 7.0)


func play_ui_confirm() -> void:
	_play_sfx("ui_confirm", ui_volume_db - 2.0)


func play_ui_cancel() -> void:
	_play_sfx("ui_cancel", ui_volume_db - 2.0)


func play_unit_select() -> void:
	_play_sfx("ui_confirm", ui_volume_db - 3.0, 1.08)


func play_turn_transition() -> void:
	_play_sfx("turn_change", sfx_volume_db - 3.0, 1.0)


func play_objective_feedback() -> void:
	_play_sfx("pickup_bonus_move", sfx_volume_db - 4.0, 1.04)


func play_move_confirm(tank_type: int) -> void:
	var move_key: String = "move_light" if tank_type == GameTypes.TankType.QTANK else "move_heavy"
	var pitch: float = 1.08 if tank_type == GameTypes.TankType.QTANK else 0.96
	_play_sfx(move_key, sfx_volume_db - 4.0, pitch)


func play_move_arrival(tank_type: int, delay: float) -> void:
	var move_key: String = "move_light" if tank_type == GameTypes.TankType.QTANK else "move_heavy"
	var pitch: float = 1.18 if tank_type == GameTypes.TankType.QTANK else 0.9
	_play_sfx_delayed(move_key, sfx_volume_db - 5.0, delay, pitch)
	_play_sfx_delayed("ui_confirm", ui_volume_db - 4.0, delay + 0.02, 1.04)


func play_action_feedback(previous_state: GameState, current_state: GameState, action: ActionData, events: Array[GameEvent]) -> void:
	if previous_state == null or current_state == null:
		return

	match action.action_type:
		GameTypes.ActionType.MOVE:
			var moving_tank: TankData = previous_state.get_tank(action.actor_id)
			if moving_tank != null:
				play_move_confirm(moving_tank.tank_type)
				var travel_seconds: float = clampf(
					moving_tank.position.to_world_flat(34.0).distance_to(action.target_coord.to_world_flat(34.0)) / 220.0,
					0.32,
					0.8
				)
				play_move_arrival(moving_tank.tank_type, travel_seconds * 0.82)
		GameTypes.ActionType.ATTACK:
			var attacking_tank: TankData = previous_state.get_tank(action.actor_id)
			if attacking_tank != null:
				if attacking_tank.tank_type == GameTypes.TankType.QTANK:
					_play_sfx("laser_charge", sfx_volume_db - 6.0)
					_play_sfx_delayed("laser_fire", sfx_volume_db + 0.5, 0.1)
				else:
					_play_sfx("blast_charge", sfx_volume_db - 5.0)
					_play_sfx_delayed("blast_fire", sfx_volume_db + 1.0, 0.1)
		GameTypes.ActionType.PASS:
			play_ui_cancel()
		_:
			pass

	for event_item: GameEvent in events:
		_play_event(previous_state, current_state, action, event_item)

	if not current_state.game_over and previous_state.current_player != current_state.current_player:
		play_turn_transition()


func _play_event(previous_state: GameState, current_state: GameState, action: ActionData, event_item: GameEvent) -> void:
	match event_item.event_name:
		"hit_tank":
			if _is_laser_attack(previous_state, action):
				_play_sfx("laser_hit_tank", sfx_volume_db - 1.0)
				_play_sfx("hit_light", sfx_volume_db)
			else:
				_play_sfx("blast_hit", sfx_volume_db - 1.0)
				_play_sfx("hit_heavy", sfx_volume_db)
		"hit_cell":
			var coord_key: String = str(event_item.payload.get("coord", ""))
			var coord: HexCoord = HexCoord.from_key(coord_key)
			var previous_cell: CellData = previous_state.board.get_cell(coord)
			if previous_cell != null and previous_cell.cell_type == GameTypes.CellType.ARMOR_BLOCK:
				_play_sfx("armor_block_hit", sfx_volume_db - 1.0)
			elif bool(event_item.payload.get("destroyed", false)):
				_play_sfx("block_destroyed", sfx_volume_db)
				_play_sfx("explosion_small", sfx_volume_db - 4.0)
			elif _is_laser_attack(previous_state, action):
				_play_sfx("laser_hit_wall", sfx_volume_db - 2.0)
			elif _is_heavy_attack(previous_state, action):
				_play_sfx("blast_hit", sfx_volume_db - 2.0)
		"power_up":
			var buff_name: String = str(event_item.payload.get("buff", ""))
			play_objective_feedback()
			match buff_name:
				"attack_multiplier":
					_play_sfx("pickup_attack", sfx_volume_db - 1.0)
				"shield_buffer":
					_play_sfx("pickup_shield", sfx_volume_db - 1.0)
				"bonus_move":
					_play_sfx("pickup_bonus_move", sfx_volume_db - 1.0)
		"extra_action_granted":
			_play_sfx("extra_action", sfx_volume_db - 2.0)
		"tank_destroyed":
			_play_sfx("tank_destroyed", sfx_volume_db + 1.0)
			_play_sfx("explosion_small", sfx_volume_db - 2.0, 0.88)
		"win_center", "win_ktank_destroyed":
			play_objective_feedback()
			_play_match_result(int(event_item.payload.get("winner", 0)))
		"draw_turn_limit", "draw_repetition":
			_play_sfx("draw", sfx_volume_db - 1.0)
		_:
			pass

	if event_item.event_name == "hit_tank":
		var target_id: String = str(event_item.payload.get("target", ""))
		var before_tank: TankData = previous_state.get_tank(target_id)
		var after_tank: TankData = current_state.get_tank(target_id)
		if before_tank != null and after_tank != null and before_tank.shield_hits_remaining > after_tank.shield_hits_remaining:
			_play_sfx("shield_trigger", sfx_volume_db - 2.0)


func _play_music(key: String) -> void:
	if _current_music_key == key and _music_player != null and _music_player.playing:
		return
	var stream: AudioStream = _load_stream(key)
	if stream == null or _music_player == null:
		return
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = music_volume_db
	_music_player.play()
	_current_music_key = key


func _on_music_finished() -> void:
	if _current_music_key == "" or not bool(LOOPING_MUSIC.get(_current_music_key, false)):
		return
	if _music_player != null:
		_music_player.play()


func _play_sfx(key: String, base_volume_db: float, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = _load_stream(key)
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = base_volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_sfx_delayed(key: String, base_volume_db: float, delay: float, pitch_scale: float = 1.0) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(delay)
	timer.timeout.connect(func() -> void:
		_play_sfx(key, base_volume_db, pitch_scale)
	)


func _load_stream(key: String) -> AudioStream:
	var path: String = str(AUDIO_PATHS.get(key, ""))
	if path == "":
		return null
	var stream: AudioStream = load(path) as AudioStream
	return stream


func _is_laser_attack(previous_state: GameState, action: ActionData) -> bool:
	if action.action_type != GameTypes.ActionType.ATTACK:
		return false
	var tank: TankData = previous_state.get_tank(action.actor_id)
	return tank != null and tank.tank_type == GameTypes.TankType.QTANK


func _is_heavy_attack(previous_state: GameState, action: ActionData) -> bool:
	if action.action_type != GameTypes.ActionType.ATTACK:
		return false
	var tank: TankData = previous_state.get_tank(action.actor_id)
	return tank != null and tank.tank_type == GameTypes.TankType.KTANK


func _play_match_result(winner_id: int) -> void:
	var human_player_id: int = _human_player_id()
	if human_player_id == 0:
		_play_sfx("win_player", sfx_volume_db - 1.0)
		_play_sfx("victory_sting", sfx_volume_db - 2.0)
		return

	if winner_id == human_player_id:
		_play_sfx("win_player", sfx_volume_db - 1.0)
		_play_sfx("victory_sting", sfx_volume_db - 2.0)
	else:
		_play_sfx("lose_player", sfx_volume_db - 1.0)
		_play_sfx("defeat_sting", sfx_volume_db - 2.0)


func _human_player_id() -> int:
	if AppState.current_match_config.player_one_ai.controller_type == GameTypes.ControllerType.HUMAN:
		return 1
	if AppState.current_match_config.player_two_ai.controller_type == GameTypes.ControllerType.HUMAN:
		return 2
	return 0
