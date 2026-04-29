class_name BoardDebugView
extends Node2D

signal hovered_cell_changed(summary: String)
signal selected_cell_changed(summary: String)
signal cell_clicked(coord_key: String)

const BOARD_FONT := preload("res://assets/fonts/space_grotesk/SpaceGrotesk-SemiBold.ttf")
const EFFECT_MUZZLE := preload("res://assets/effects/muzzle_03.png")
const EFFECT_SPARK := preload("res://assets/effects/spark_06.png")
const EFFECT_SMOKE := preload("res://assets/effects/smoke_03.png")
const EFFECT_TRACE := preload("res://assets/effects/trace_04.png")
const WORLD_LIGHT_CIRCLE := preload("res://assets/world/masks/light_circle.png")
const WORLD_LIGHT_CONE := preload("res://assets/world/masks/light_cone.png")
const WORLD_EDGE_SMOKE := preload("res://assets/world/smoke/edge_smoke.png")
const WORLD_WHITE_PUFF := preload("res://assets/world/smoke/white_puff.png")
const WORLD_WINDOW_CORNER := preload("res://assets/world/silhouettes/window_corner.png")
const WORLD_CORRIDOR_CROSS := preload("res://assets/world/silhouettes/corridor_cross.png")
const WORLD_CHIMNEY := preload("res://assets/world/silhouettes/chimney.png")
const TANK_SPRITES := {
	"1_0": {
		"track": preload("res://assets/art/tanks2d/p1_qtrack.png"),
		"hull": preload("res://assets/art/tanks2d/p1_qhull.png"),
		"gun": preload("res://assets/art/tanks2d/p1_qgun.png"),
		"scale": 0.36,
	},
	"1_1": {
		"track": preload("res://assets/art/tanks2d/p1_ktrack.png"),
		"hull": preload("res://assets/art/tanks2d/p1_khull.png"),
		"gun": preload("res://assets/art/tanks2d/p1_kgun.png"),
		"scale": 0.39,
	},
	"2_0": {
		"track": preload("res://assets/art/tanks2d/p2_qtrack.png"),
		"hull": preload("res://assets/art/tanks2d/p2_qhull.png"),
		"gun": preload("res://assets/art/tanks2d/p2_qgun.png"),
		"scale": 0.36,
	},
	"2_1": {
		"track": preload("res://assets/art/tanks2d/p2_ktrack.png"),
		"hull": preload("res://assets/art/tanks2d/p2_khull.png"),
		"gun": preload("res://assets/art/tanks2d/p2_kgun.png"),
		"scale": 0.39,
	},
}

const COLOR_BY_TYPE := {
	GameTypes.CellType.EMPTY: Color("2a323e"),
	GameTypes.CellType.CENTER: Color("d6a92f"),
	GameTypes.CellType.WALL: Color("4a5360"),
	GameTypes.CellType.BLOCK: Color("8a6138"),
	GameTypes.CellType.ARMOR_BLOCK: Color("8f9ba8"),
	GameTypes.CellType.POWER_BLOCK: Color("8250bb"),
	GameTypes.CellType.POWER_ATTACK: Color("e64f67"),
	GameTypes.CellType.POWER_SHIELD: Color("5fa8ff"),
	GameTypes.CellType.POWER_BONUS_MOVE: Color("57d477"),
}
const PLAYER_PRIMARY := {
	1: Color("72a7ff"),
	2: Color("ff6978"),
}
const PLAYER_ACCENT := {
	1: Color("d7ebff"),
	2: Color("ffe1d7"),
}
const WORLD_LIGHT_DIR := Vector2(-0.68, -1.0)
const MOVE_PIXELS_PER_SECOND := 150.0
const MOVE_MIN_SECONDS := 0.5
const MOVE_MAX_SECONDS := 1.12

var hex_size: float = 50.0
var playback_speed_scale: float:
	get:
		return _playback_speed_scale
	set(value):
		_playback_speed_scale = clampf(value, 0.5, 8.0)
var board_state: BoardState = BoardState.new()
var game_state: GameState
var hovered_key: String = ""
var selected_key: String = ""
var selected_actor_id: String = ""
var highlighted_keys: Dictionary = {}
var current_action_mode: String = ""
var interaction_enabled: bool = true
var _pulse_time: float = 0.0
var _beam_effects: Array[Dictionary] = []
var _ring_effects: Array[Dictionary] = []
var _flash_effects: Array[Dictionary] = []
var _sprite_effects: Array[Dictionary] = []
var _floating_texts: Array[Dictionary] = []
var _tank_motion_overrides: Dictionary = {}
var _tank_hit_reactions: Dictionary = {}
var _tank_fadeouts: Dictionary = {}
var _objective_tile_reactions: Dictionary = {}
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _playback_speed_scale: float = 1.0


func _ready() -> void:
	if game_state == null:
		board_state.load_map_preset(MapLibrary.get_preset("standard"))
	set_process_input(true)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta * (0.35 if AppState.reduced_motion else 1.0)
	_process_effects(delta * playback_speed_scale)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseMotion:
		_update_hover(to_local(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_hex(to_local(event.position))


func _draw() -> void:
	var active_board: BoardState = _active_board()
	_draw_board_backdrop(active_board)
	for cell: CellData in _sorted_cells(active_board):
		var center: Vector2 = _tile_center(cell)
		var fill: Color = _tile_fill_color(cell)

		var points: PackedVector2Array = _hex_points(center)
		var depth: float = _tile_depth(cell)
		var shadow_points: PackedVector2Array = _offset_points(points, Vector2(0, 11 + depth))
		draw_colored_polygon(shadow_points, Color(0.03, 0.05, 0.08, 0.55))
		var side_face: PackedVector2Array = _side_face_points(points, depth)
		if not side_face.is_empty():
			draw_colored_polygon(side_face, _tile_side_color(cell, fill))
			draw_polyline(_closed_polyline(side_face), Color(0.02, 0.03, 0.05, 0.36), 1.1, true)

		var glow_color: Color = _tile_glow_color(cell)
		if glow_color.a > 0.0:
			draw_circle(center + Vector2(0, 8), hex_size * 0.82, glow_color)

		draw_colored_polygon(points, fill)
		var inset_points: PackedVector2Array = _scaled_points(points, center, 0.9)
		draw_colored_polygon(inset_points, fill.lightened(0.05))
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color("0f131a").lerp(fill, 0.15), 1.8, true)
		var top_highlight: PackedVector2Array = PackedVector2Array([points[4], points[5], points[0], points[1]])
		draw_polyline(top_highlight, Color.WHITE.lerp(fill, 0.58), 1.5, true)
		var lower_shadow: PackedVector2Array = PackedVector2Array([points[2], points[3], points[4]])
		draw_polyline(lower_shadow, fill.darkened(0.32), 1.3, true)
		_draw_tile_material(cell, center, points, fill)
		_draw_objective_tile_effects(cell, center, points)
		_draw_objective_state_reaction(cell, center, points)

	_draw_range_overlays(active_board)
	_draw_path_preview(active_board)

	if game_state != null:
		_draw_tanks()
	_draw_hover_and_selection_overlays(active_board)
	_draw_effects()


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(6):
		var angle: float = deg_to_rad(60.0 * index)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return points


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var offset_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		offset_points.append(point + offset)
	return offset_points


func _side_face_points(points: PackedVector2Array, depth: float) -> PackedVector2Array:
	if points.size() < 6:
		return PackedVector2Array()
	return PackedVector2Array([
		points[1],
		points[2],
		points[2] + Vector2(0, depth),
		points[1] + Vector2(0, depth),
		points[0] + Vector2(0, depth),
		points[5] + Vector2(0, depth),
		points[5],
		points[0],
	])


func _update_hover(local_position: Vector2) -> void:
	var coord: HexCoord = HexCoord.from_world_flat(local_position, hex_size)
	var active_board: BoardState = _active_board()
	var new_key: String = coord.key() if active_board.has_cell(coord) else ""
	if new_key == hovered_key:
		return
	hovered_key = new_key
	hovered_cell_changed.emit(_build_summary(coord, active_board.get_cell(coord)) if new_key != "" else "Hover: outside board")
	queue_redraw()


func _select_hex(local_position: Vector2) -> void:
	var coord: HexCoord = HexCoord.from_world_flat(local_position, hex_size)
	var active_board: BoardState = _active_board()
	if not active_board.has_cell(coord):
		return
	selected_key = coord.key()
	selected_cell_changed.emit(_build_summary(coord, active_board.get_cell(coord)))
	cell_clicked.emit(selected_key)
	queue_redraw()


func _build_summary(coord: HexCoord, cell: CellData) -> String:
	if cell == null:
		return "No cell"
	return "Hex %s | %s | HP %d" % [coord.key(), _type_label(cell.cell_type), cell.hp]


func _type_label(cell_type: int) -> String:
	match cell_type:
		GameTypes.CellType.EMPTY:
			return "Empty"
		GameTypes.CellType.CENTER:
			return "Center"
		GameTypes.CellType.WALL:
			return "Wall"
		GameTypes.CellType.BLOCK:
			return "Block"
		GameTypes.CellType.ARMOR_BLOCK:
			return "Armor Block"
		GameTypes.CellType.POWER_BLOCK:
			return "Power Block"
		GameTypes.CellType.POWER_ATTACK:
			return "Power Attack"
		GameTypes.CellType.POWER_SHIELD:
			return "Power Shield"
		GameTypes.CellType.POWER_BONUS_MOVE:
			return "Power Bonus Move"
		_:
			return "Unknown"


func set_game_state(new_game_state: GameState) -> void:
	game_state = new_game_state
	board_state = game_state.board
	queue_redraw()


func set_selected_actor(actor_id: String) -> void:
	selected_actor_id = actor_id
	queue_redraw()


func set_highlighted_cells(keys: Dictionary) -> void:
	highlighted_keys = keys.duplicate(true)
	queue_redraw()


func set_action_mode(action_mode: String) -> void:
	current_action_mode = action_mode
	queue_redraw()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled


func play_selection_feedback(actor_id: String) -> void:
	if game_state == null:
		return
	var tank: TankData = game_state.get_tank(actor_id)
	if tank == null or not tank.is_alive():
		return
	var center: Vector2 = tank.position.to_world_flat(hex_size)
	var player_color: Color = _player_primary_color(tank.owner_id)
	_ring_effects.append({
		"center": center,
		"color": player_color.lerp(Color.WHITE, 0.18),
		"radius": 18.0,
		"time_left": 0.34,
		"duration": 0.34,
		"filled": false,
	})
	_ring_effects.append({
		"center": center,
		"color": Color(player_color.r, player_color.g, player_color.b, 0.22),
		"radius": 24.0,
		"time_left": 0.42,
		"duration": 0.42,
		"filled": true,
	})
	_flash_effects.append({
		"center": center,
		"color": player_color.lerp(Color.WHITE, 0.32),
		"radius": 14.0,
		"time_left": 0.22,
		"duration": 0.22,
	})
	queue_redraw()


func play_action_feedback(previous_state: GameState, current_state: GameState, action: ActionData, events: Array[GameEvent]) -> void:
	if previous_state == null or current_state == null:
		return

	match action.action_type:
		GameTypes.ActionType.MOVE:
			var moved_tank: TankData = previous_state.get_tank(action.actor_id)
			var current_tank: TankData = current_state.get_tank(action.actor_id)
			if moved_tank != null:
				var start_center: Vector2 = moved_tank.position.to_world_flat(hex_size)
				var end_center: Vector2 = action.target_coord.to_world_flat(hex_size)
				var travel_duration: float = _movement_travel_seconds(start_center, end_center)
				_tank_motion_overrides[action.actor_id] = {
					"start": start_center,
					"end": end_center,
					"start_angle": moved_tank.facing_angle,
					"end_angle": current_tank.facing_angle if current_tank != null else moved_tank.facing_angle,
					"time_left": travel_duration,
					"duration": travel_duration,
				}
		GameTypes.ActionType.ATTACK:
			_play_attack_effect(previous_state, action)
		GameTypes.ActionType.PASS:
			_ring_effects.append({
				"center": HexCoord.new().to_world_flat(hex_size),
				"color": Color("aebdd3"),
				"radius": 20.0,
				"time_left": 0.22,
				"duration": 0.22,
				"filled": false,
			})
		_:
			pass

	if action.action_type != GameTypes.ActionType.MOVE:
		for event_item: GameEvent in events:
			_apply_event_feedback(previous_state, current_state, action, event_item)

	queue_redraw()


func get_feedback_hold_seconds(action: ActionData, previous_state: GameState = null) -> float:
	var hold_seconds: float = 0.22
	match action.action_type:
		GameTypes.ActionType.MOVE:
			if previous_state != null:
				var moved_tank: TankData = previous_state.get_tank(action.actor_id)
				if moved_tank != null:
					var start_center: Vector2 = moved_tank.position.to_world_flat(hex_size)
					var end_center: Vector2 = action.target_coord.to_world_flat(hex_size)
					hold_seconds = _movement_travel_seconds(start_center, end_center) + 0.04
				else:
					hold_seconds = MOVE_MIN_SECONDS
			else:
				hold_seconds = MOVE_MIN_SECONDS
		GameTypes.ActionType.ATTACK:
			if previous_state != null:
				var attacker: TankData = previous_state.get_tank(action.actor_id)
				if attacker != null and attacker.tank_type == GameTypes.TankType.KTANK:
					hold_seconds = 0.96
				else:
					hold_seconds = 0.84
			else:
				hold_seconds = 0.84
		GameTypes.ActionType.PASS:
			hold_seconds = 0.2
		_:
			hold_seconds = 0.22
	return maxf(0.04, hold_seconds / playback_speed_scale)


func get_board_visual_size() -> Vector2:
	var active_board: BoardState = _active_board()
	if active_board.cells.is_empty():
		return Vector2(820, 760)

	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for cell: CellData in active_board.cells.values():
		var center: Vector2 = cell.coord.to_world_flat(hex_size)
		min_x = minf(min_x, center.x)
		min_y = minf(min_y, center.y)
		max_x = maxf(max_x, center.x)
		max_y = maxf(max_y, center.y)

	return Vector2((max_x - min_x) + hex_size * 1.7, (max_y - min_y) + hex_size * 2.3)


func _movement_travel_seconds(start_center: Vector2, end_center: Vector2) -> float:
	return clampf(start_center.distance_to(end_center) / MOVE_PIXELS_PER_SECOND, MOVE_MIN_SECONDS, MOVE_MAX_SECONDS)


func _active_board() -> BoardState:
	return game_state.board if game_state != null else board_state


func _sorted_cells(active_board: BoardState) -> Array[CellData]:
	var cells: Array[CellData] = active_board.all_cells()
	cells.sort_custom(func(a: CellData, b: CellData) -> bool:
		var a_center: Vector2 = a.coord.to_world_flat(hex_size)
		var b_center: Vector2 = b.coord.to_world_flat(hex_size)
		return a_center.y < b_center.y
	)
	return cells


func _tile_center(cell: CellData) -> Vector2:
	var center: Vector2 = cell.coord.to_world_flat(hex_size)
	if cell.coord.key() == hovered_key:
		center.y -= 5.0
	if cell.coord.key() == selected_key:
		center.y -= 6.0
	return center + _shake_offset


func _tile_depth(cell: CellData) -> float:
	if cell.cell_type == GameTypes.CellType.CENTER:
		return 10.0
	if cell.cell_type == GameTypes.CellType.WALL or cell.cell_type == GameTypes.CellType.ARMOR_BLOCK:
		return 8.0
	if cell.cell_type == GameTypes.CellType.BLOCK or cell.cell_type == GameTypes.CellType.POWER_BLOCK:
		return 7.0
	if cell.coord.key() == hovered_key or cell.coord.key() == selected_key:
		return 5.0
	return 3.0


func _tile_side_color(cell: CellData, fill: Color) -> Color:
	var side_color: Color = fill.darkened(0.33)
	match cell.cell_type:
		GameTypes.CellType.CENTER:
			side_color = Color("856315")
		GameTypes.CellType.WALL:
			side_color = Color("28303a")
		GameTypes.CellType.BLOCK:
			side_color = Color("4e3825")
		GameTypes.CellType.ARMOR_BLOCK:
			side_color = Color("4b5664")
		GameTypes.CellType.POWER_BLOCK:
			side_color = Color("3c2459")
		_:
			pass
	side_color.a = 0.96
	return side_color


func _tile_glow_color(cell: CellData) -> Color:
	match cell.cell_type:
		GameTypes.CellType.CENTER:
			return Color(1.0, 0.9, 0.35, 0.08 + 0.03 * sin(_pulse_time * 2.0))
		GameTypes.CellType.POWER_ATTACK:
			return Color(0.93, 0.42, 0.45, 0.09)
		GameTypes.CellType.POWER_SHIELD:
			return Color(0.39, 0.7, 1.0, 0.09)
		GameTypes.CellType.POWER_BONUS_MOVE:
			return Color(0.42, 0.89, 0.63, 0.09)
		GameTypes.CellType.POWER_BLOCK:
			return Color(0.66, 0.42, 0.95, 0.07)
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


func _player_primary_color(player_id: int) -> Color:
	if not AppState.high_contrast_mode:
		return PLAYER_PRIMARY.get(player_id, Color.WHITE)
	return Color("5fd0ff") if player_id == 1 else Color("ff8d4d")


func _player_accent_color(player_id: int) -> Color:
	if not AppState.high_contrast_mode:
		return PLAYER_ACCENT.get(player_id, Color.WHITE)
	return Color("f2fbff") if player_id == 1 else Color("fff1d9")


func _selected_outline_color() -> Color:
	return Color("86fff1") if AppState.high_contrast_mode else Color("67f0ff")


func _move_preview_color() -> Color:
	return Color("95ff5f") if AppState.high_contrast_mode else Color("63e38f")


func _attack_preview_color() -> Color:
	return Color("ffb347") if AppState.high_contrast_mode else Color("ff7a86")


func _draw_backdrop_texture(
	texture: Texture2D,
	center: Vector2,
	scale_value: Vector2,
	modulate_color: Color,
	rotation_value: float = 0.0
) -> void:
	if texture == null:
		return
	draw_set_transform(center, rotation_value, scale_value)
	draw_texture(texture, -texture.get_size() * 0.5, modulate_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_board_backdrop(_active_board: BoardState) -> void:
	if hex_size < 18.0:
		return
	_draw_board_backdrop_legacy(_active_board)


func _draw_board_backdrop_legacy(active_board: BoardState) -> void:
	var used_rect: Rect2 = Rect2(Vector2(-420, -320), Vector2(840, 700))
	if not active_board.cells.is_empty():
		var min_x: float = INF
		var min_y: float = INF
		var max_x: float = -INF
		var max_y: float = -INF
		for cell: CellData in active_board.cells.values():
			var center: Vector2 = cell.coord.to_world_flat(hex_size)
			min_x = minf(min_x, center.x)
			min_y = minf(min_y, center.y)
			max_x = maxf(max_x, center.x)
			max_y = maxf(max_y, center.y)
		used_rect = Rect2(Vector2(min_x - 28.0, min_y - 28.0), Vector2((max_x - min_x) + 56.0, (max_y - min_y) + 72.0))

	var backdrop_rect: Rect2 = used_rect.grow_individual(56.0, 48.0, 56.0, 54.0)
	var board_center: Vector2 = used_rect.position + used_rect.size * 0.5 + _shake_offset
	var center_glow_alpha: float = 0.08 + 0.02 * sin(_pulse_time * 1.7)
	draw_rect(backdrop_rect, Color("0c1320"))
	draw_rect(used_rect, Color("111927"))
	draw_circle(board_center + Vector2(-used_rect.size.x * 0.12, -used_rect.size.y * 0.16), used_rect.size.x * 0.42, Color(0.32, 0.46, 0.68, 0.05))
	draw_circle(board_center + Vector2(used_rect.size.x * 0.18, used_rect.size.y * 0.12), used_rect.size.x * 0.34, Color(0.18, 0.16, 0.12, 0.07))
	_draw_backdrop_texture(
		WORLD_LIGHT_CONE,
		used_rect.position + Vector2(used_rect.size.x * 0.22, used_rect.size.y * 0.18) + _shake_offset,
		Vector2(2.0, 1.55),
		Color(0.46, 0.73, 1.0, 0.09),
		deg_to_rad(18.0)
	)
	_draw_backdrop_texture(
		WORLD_LIGHT_CIRCLE,
		board_center,
		Vector2(1.25, 1.25),
		Color(1.0, 0.9, 0.48, center_glow_alpha)
	)
	_draw_backdrop_texture(
		WORLD_WHITE_PUFF,
		board_center + Vector2(0, 8),
		Vector2(1.55, 1.2),
		Color(1.0, 0.84, 0.42, 0.07 + 0.02 * sin(_pulse_time * 2.2))
	)
	_draw_backdrop_texture(
		WORLD_WINDOW_CORNER,
		used_rect.position + Vector2(70, 72) + _shake_offset,
		Vector2(0.9, 0.9),
		Color(0.45, 0.6, 0.78, 0.08),
		deg_to_rad(-6.0)
	)
	_draw_backdrop_texture(
		WORLD_CORRIDOR_CROSS,
		used_rect.position + Vector2(used_rect.size.x - 82, 88) + _shake_offset,
		Vector2(0.92, 0.92),
		Color(0.42, 0.54, 0.7, 0.07),
		deg_to_rad(6.0)
	)
	_draw_backdrop_texture(
		WORLD_CHIMNEY,
		used_rect.position + Vector2(used_rect.size.x * 0.12, used_rect.size.y - 74) + _shake_offset,
		Vector2(0.9, 0.9),
		Color(0.36, 0.46, 0.6, 0.06),
		deg_to_rad(-4.0)
	)
	_draw_backdrop_texture(
		WORLD_EDGE_SMOKE,
		used_rect.position + Vector2(58, used_rect.size.y * 0.58) + _shake_offset,
		Vector2(1.1, 1.35),
		Color(0.46, 0.58, 0.78, 0.045),
		deg_to_rad(90.0)
	)
	_draw_backdrop_texture(
		WORLD_EDGE_SMOKE,
		used_rect.position + Vector2(used_rect.size.x - 56, used_rect.size.y * 0.64) + _shake_offset,
		Vector2(1.05, 1.25),
		Color(0.62, 0.56, 0.42, 0.04),
		deg_to_rad(-88.0)
	)
	_draw_backdrop_texture(
		WORLD_EDGE_SMOKE,
		used_rect.position + Vector2(used_rect.size.x * 0.5, used_rect.size.y - 28) + _shake_offset,
		Vector2(1.55, 0.82),
		Color(0.38, 0.46, 0.58, 0.032)
	)
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.3, used_rect.size.y * 0.28) + _shake_offset, 180.0, Color(0.2, 0.32, 0.48, 0.08))
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.72, used_rect.size.y * 0.62) + _shake_offset, 210.0, Color(0.66, 0.55, 0.2, 0.05))
	draw_circle(board_center, 290.0, Color(0.08, 0.12, 0.2, 0.24))
	draw_circle(board_center, minf(used_rect.size.x, used_rect.size.y) * 0.28, Color(0.92, 0.81, 0.28, 0.035))
	draw_arc(board_center, 212.0, 0.0, TAU, 72, Color(0.84, 0.94, 1.0, 0.06), 2.0, true)
	draw_arc(board_center, 134.0, 0.0, TAU, 72, Color(1.0, 0.9, 0.56, 0.05), 1.4, true)
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.08, used_rect.size.y * 0.12) + _shake_offset, 140.0, Color(0.02, 0.03, 0.06, 0.32))
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.95, used_rect.size.y * 0.12) + _shake_offset, 132.0, Color(0.02, 0.03, 0.06, 0.28))
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.06, used_rect.size.y * 0.9) + _shake_offset, 170.0, Color(0.02, 0.03, 0.06, 0.24))
	draw_circle(used_rect.position + Vector2(used_rect.size.x * 0.95, used_rect.size.y * 0.9) + _shake_offset, 190.0, Color(0.02, 0.03, 0.06, 0.26))


func _draw_tanks() -> void:
	var font: Font = BOARD_FONT if BOARD_FONT != null else ThemeDB.fallback_font
	_draw_tank_fadeouts(font)
	for tank: TankData in game_state.get_all_tanks():
		if not tank.is_alive():
			continue
		var tank_cell: CellData = game_state.board.get_cell(tank.position)
		var center: Vector2 = _tile_center(tank_cell) if tank_cell != null else tank.position.to_world_flat(hex_size)
		var is_moving: bool = _tank_motion_overrides.has(tank.actor_id())
		if is_moving:
			center = _motion_override_center(tank.actor_id(), center)
		var tank_rotation: float = _tank_draw_rotation(tank)
		var player_color: Color = _player_primary_color(tank.owner_id)
		var accent_color: Color = _player_accent_color(tank.owner_id)
		var is_selected: bool = tank.actor_id() == selected_actor_id and not is_moving
		var hit_flash_alpha: float = _tank_hit_flash_alpha(tank.actor_id())
		var fade_alpha: float = _tank_fade_alpha(tank.actor_id())
		var render_alpha: float = 1.0 - fade_alpha
		var health_ratio: float = float(tank.hp) / maxf(float(tank.max_hp), 1.0)
		var ring_color: Color = player_color.lerp(Color("ff6d72"), clampf((0.52 - health_ratio) * 1.95, 0.0, 0.82))
		if is_moving:
			_draw_tank_motion_trail(tank.actor_id(), center, render_alpha)
		var shadow_size: Vector2 = Vector2(22, 8.5) if not is_selected else Vector2(25, 9.5)
		var shadow_center: Vector2 = center + (-WORLD_LIGHT_DIR.normalized() * 13.5) + Vector2(0, 8.5)
		draw_colored_polygon(_ellipse_points(shadow_center, shadow_size, 20), Color(0.03, 0.05, 0.08, (0.56 if not is_selected else 0.78) * render_alpha))
		draw_colored_polygon(_ellipse_points(center + Vector2(2, 13), Vector2(17, 6.4), 18), Color(0.12, 0.18, 0.26, (0.18 if not is_selected else 0.28) * render_alpha))
		if not is_moving:
			draw_circle(center + Vector2(0, 7), 14.0, Color(ring_color.r, ring_color.g, ring_color.b, (0.08 if not is_selected else 0.18) * render_alpha))
			draw_arc(center + Vector2(0, 7), 18.0, 0.0, TAU, 40, Color(ring_color.r, ring_color.g, ring_color.b, 0.54 * render_alpha), 2.2, true)
		if tank.owner_id == game_state.current_player and not is_moving:
			draw_arc(center + Vector2(0, 7), 22.0, 0.0, TAU, 40, Color(ring_color.r, ring_color.g, ring_color.b, 0.78 * render_alpha), 2.5, true)
		if health_ratio <= 0.45 and not is_moving:
			draw_arc(center + Vector2(0, 7), 13.0, -PI * 0.75, PI * 0.15, 18, Color(1.0, 0.74, 0.32, 0.98 * render_alpha), 2.1, true)
			draw_arc(center + Vector2(0, 7), 19.5, -PI * 0.75, PI * 0.15, 18, Color(1.0, 0.48, 0.36, 0.72 * render_alpha), 1.2, true)
		if hit_flash_alpha > 0.0:
			draw_circle(center + Vector2(0, 5), 18.0, Color(1.0, 1.0, 1.0, hit_flash_alpha * render_alpha))
			draw_arc(center + Vector2(0, 5), 21.0, 0.0, TAU, 36, Color(1.0, 0.92, 0.82, hit_flash_alpha * 0.95 * render_alpha), 2.4, true)
		_draw_tank_sprite(center, tank, tank_rotation, render_alpha)
		if is_selected:
			var pulse_radius: float = 25.0 + (1.8 if AppState.reduced_motion else 3.8 * (0.5 + 0.5 * sin(_pulse_time * 2.2)))
			draw_circle(center + Vector2(0, 5), 18.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.16))
			draw_arc(center + Vector2(0, 5), pulse_radius, 0.0, TAU, 48, ring_color.lerp(Color.WHITE, 0.52), 4.0, true)
			draw_arc(center + Vector2(0, 5), pulse_radius + 5.0, 0.0, TAU, 48, Color(ring_color.r, ring_color.g, ring_color.b, 0.28), 1.8, true)
			draw_arc(center + Vector2(0, 5), 16.5, 0.0, TAU, 32, Color(ring_color.r, ring_color.g, ring_color.b, 0.98), 2.6, true)
			draw_circle(center + Vector2(0, 5), 28.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.07))
		elif current_action_mode == "attack" and _is_tank_targeted(tank):
			draw_circle(center + Vector2(0, 5), 16.0, Color(_attack_preview_color().r, _attack_preview_color().g, _attack_preview_color().b, 0.08))
			draw_arc(center + Vector2(0, 5), 24.0, 0.0, TAU, 40, Color(_attack_preview_color().r, _attack_preview_color().g, _attack_preview_color().b, 0.94), 2.8, true)
			draw_arc(center + Vector2(0, 5), 18.0, 0.0, TAU, 40, Color(_attack_preview_color().r, _attack_preview_color().g, _attack_preview_color().b, 0.42), 1.6, true)

		if font != null:
			draw_string(font, center + Vector2(-10, -27), "%d" % tank.hp, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("f5f7fb"))
			draw_string(font, center + Vector2(-10, 29), "P%d" % tank.owner_id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, accent_color)

		if tank.active_buff != GameTypes.BuffType.NONE and not is_moving:
			var buff_color: Color = _buff_color(tank.active_buff)
			draw_circle(center + Vector2(13, -13), 5.0, buff_color)
			draw_circle(center + Vector2(13, -13), 2.0, Color("10141c"))

		var bar_width: float = 34.0
		var bar_origin: Vector2 = center + Vector2(-bar_width * 0.5, 24)
		draw_rect(Rect2(bar_origin, Vector2(bar_width, 5)), Color(0.05, 0.08, 0.12, 0.85))
		draw_rect(Rect2(bar_origin + Vector2.ONE, Vector2((bar_width - 2.0) * health_ratio, 3)), _health_display_color(health_ratio))
		if health_ratio <= 0.45 and not is_moving:
			var smoke_alpha: float = clampf((0.52 - health_ratio) * 1.8, 0.0, 0.28) * render_alpha
			_draw_backdrop_texture(
				EFFECT_SMOKE,
				center + _rotated_offset(Vector2(0, -15), tank_rotation),
				Vector2(0.34, 0.34),
				Color(0.84, 0.86, 0.9, smoke_alpha),
				tank_rotation * 0.35
			)
			if health_ratio <= 0.25:
				draw_circle(center + _rotated_offset(Vector2(8, -6), tank_rotation), 2.6, Color(1.0, 0.76, 0.45, 0.88 * render_alpha))
				draw_circle(center + _rotated_offset(Vector2(-7, -4), tank_rotation), 1.9, Color(1.0, 0.56, 0.42, 0.76 * render_alpha))


func _draw_tank_motion_trail(actor_id: String, center: Vector2, alpha: float) -> void:
	var motion: Dictionary = _tank_motion_overrides.get(actor_id, {})
	if motion.is_empty():
		return
	var start_center: Vector2 = _effect_vec2(motion, "start", center)
	var end_center: Vector2 = _effect_vec2(motion, "end", center)
	var travel_vector: Vector2 = end_center - start_center
	if travel_vector.length() < 1.0:
		return
	var forward: Vector2 = travel_vector.normalized()
	var lateral: Vector2 = Vector2(-forward.y, forward.x)
	var duration: float = maxf(_effect_float(motion, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(motion, "time_left", 0.0), 0.0, duration)
	var progress: float = 1.0 - (time_left / duration)
	var trail_alpha: float = (0.2 + 0.36 * sin(progress * PI)) * alpha
	var trail_end: Vector2 = center - forward * 18.0
	var trail_start: Vector2 = start_center.lerp(trail_end, clampf(progress * 0.55, 0.0, 1.0))
	for side in [-1.0, 1.0]:
		var offset: Vector2 = lateral * side * 8.0
		draw_line(trail_start + offset, trail_end + offset, Color(0.6, 0.7, 0.78, trail_alpha * 0.32), 3.1)
		draw_line(trail_start + offset + forward * 5.0, trail_end + offset, Color(0.05, 0.07, 0.1, trail_alpha * 0.42), 1.4)


func _draw_tank_fadeouts(font: Font) -> void:
	for actor_id: String in _tank_fadeouts.keys():
		var fade_data: Dictionary = _tank_fadeouts.get(actor_id, {})
		if fade_data.is_empty():
			continue
		var tank: TankData = fade_data.get("tank", null) as TankData
		if tank == null:
			continue
		var center: Vector2 = _effect_vec2(fade_data, "center", tank.position.to_world_flat(hex_size))
		var start_center: Vector2 = _effect_vec2(fade_data, "start_center", center)
		var duration: float = maxf(_effect_float(fade_data, "duration", 0.52), 0.001)
		var time_left: float = clampf(_effect_float(fade_data, "time_left", 0.0), 0.0, duration)
		var progress: float = 1.0 - (time_left / duration)
		var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
		var collapse_offset: Vector2 = _effect_vec2(fade_data, "collapse_offset", Vector2(0, 18))
		var collapse_center: Vector2 = start_center.lerp(center + collapse_offset, progress) + _shake_offset
		var ring_color: Color = _player_primary_color(tank.owner_id)
		draw_colored_polygon(_ellipse_points(collapse_center + Vector2(0, 17), Vector2(22, 8), 20), Color(0.02, 0.04, 0.08, 0.35 * alpha))
		draw_circle(collapse_center + Vector2(0, 7), 15.5, Color(ring_color.r, ring_color.g, ring_color.b, 0.08 * alpha))
		draw_arc(collapse_center + Vector2(0, 7), 19.0, 0.0, TAU, 40, Color(ring_color.r, ring_color.g, ring_color.b, 0.48 * alpha), 1.8, true)
		_draw_tank_sprite(collapse_center, tank, _tank_draw_rotation(tank) + progress * 0.18, alpha)
		if font != null:
			draw_string(font, collapse_center + Vector2(-10, -27), "%d" % tank.hp, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.96, 0.98, 1.0, alpha))
			draw_string(font, collapse_center + Vector2(-10, 29), "P%d" % tank.owner_id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(_player_accent_color(tank.owner_id).r, _player_accent_color(tank.owner_id).g, _player_accent_color(tank.owner_id).b, alpha))


func _draw_effects() -> void:
	var font: Font = BOARD_FONT if BOARD_FONT != null else ThemeDB.fallback_font
	for beam: Dictionary in _beam_effects:
		if _effect_float(beam, "delay", 0.0) > 0.0:
			continue
		var ratio: float = _effect_float(beam, "time_left", 0.0) / maxf(_effect_float(beam, "duration", 1.0), 0.001)
		var beam_color: Color = _effect_color(beam, "color", Color.WHITE)
		beam_color.a = 0.15 + 0.85 * ratio
		var beam_width: float = _effect_float(beam, "width", 3.0) * (0.8 + 0.35 * ratio)
		var beam_start: Vector2 = _effect_vec2(beam, "start", Vector2.ZERO)
		var beam_end: Vector2 = _effect_vec2(beam, "end", Vector2.ZERO)
		draw_line(beam_start + _shake_offset, beam_end + _shake_offset, beam_color, beam_width)
		draw_circle(beam_end + _shake_offset, 4.0 + 6.0 * ratio, beam_color)

	for ring: Dictionary in _ring_effects:
		if _effect_float(ring, "delay", 0.0) > 0.0:
			continue
		var ratio: float = _effect_float(ring, "time_left", 0.0) / maxf(_effect_float(ring, "duration", 1.0), 0.001)
		var ring_color: Color = _effect_color(ring, "color", Color.WHITE)
		ring_color.a = 0.1 + 0.7 * ratio
		var radius: float = _effect_float(ring, "radius", 18.0) * (1.0 + (1.0 - ratio) * 0.55)
		var ring_center: Vector2 = _effect_vec2(ring, "center", Vector2.ZERO) + _shake_offset
		if _effect_bool(ring, "filled", false):
			draw_circle(ring_center, radius, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.18))
		draw_arc(ring_center, radius, 0.0, TAU, 42, ring_color, 2.4, true)

	for flash: Dictionary in _flash_effects:
		if _effect_float(flash, "delay", 0.0) > 0.0:
			continue
		var ratio: float = _effect_float(flash, "time_left", 0.0) / maxf(_effect_float(flash, "duration", 1.0), 0.001)
		var flash_color: Color = _effect_color(flash, "color", Color.WHITE)
		flash_color.a = 0.08 + 0.45 * ratio
		draw_circle(_effect_vec2(flash, "center", Vector2.ZERO) + _shake_offset, _effect_float(flash, "radius", 16.0) * (1.0 + 0.25 * (1.0 - ratio)), flash_color)

	for sprite_fx: Dictionary in _sprite_effects:
		if _effect_float(sprite_fx, "delay", 0.0) > 0.0:
			continue
		var ratio: float = _effect_float(sprite_fx, "time_left", 0.0) / maxf(_effect_float(sprite_fx, "duration", 1.0), 0.001)
		var texture: Texture2D = sprite_fx.get("texture", null) as Texture2D
		if texture == null:
			continue
		var center: Vector2 = _effect_vec2(sprite_fx, "center", Vector2.ZERO) + _shake_offset
		var drift: Vector2 = _effect_vec2(sprite_fx, "drift", Vector2.ZERO) * (1.0 - ratio)
		var draw_color: Color = _effect_color(sprite_fx, "color", Color.WHITE)
		draw_color.a *= ratio
		var scale_start: float = _effect_float(sprite_fx, "scale_start", 1.0)
		var scale_end: float = _effect_float(sprite_fx, "scale_end", scale_start)
		var scale_value: float = lerpf(scale_start, scale_end, 1.0 - ratio)
		var rotation_value: float = _effect_float(sprite_fx, "rotation", 0.0)
		draw_set_transform(center + drift, rotation_value, Vector2.ONE * scale_value)
		draw_texture(texture, -texture.get_size() * 0.5, draw_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if font != null:
		for floater: Dictionary in _floating_texts:
			if _effect_float(floater, "delay", 0.0) > 0.0:
				continue
			var ratio: float = _effect_float(floater, "time_left", 0.0) / maxf(_effect_float(floater, "duration", 1.0), 0.001)
			var text_color: Color = _effect_color(floater, "color", Color.WHITE)
			text_color.a = 0.15 + 0.85 * ratio
			var drift: float = (1.0 - ratio) * _effect_float(floater, "drift_distance", 22.0)
			var font_size: int = int(_effect_float(floater, "font_size", 16.0))
			var text_value: String = _effect_string(floater, "text", "")
			var text_size: Vector2 = font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var position: Vector2 = _effect_vec2(floater, "center", Vector2.ZERO) + Vector2(-text_size.x * 0.5, -20 - drift) + _shake_offset
			var shadow_color: Color = Color(0.04, 0.06, 0.1, text_color.a * 0.9)
			var backdrop_center: Vector2 = position + Vector2(text_size.x * 0.5, -font_size * 0.15)
			var backdrop_radius: float = maxf(text_size.x * 0.46, 14.0)
			draw_circle(backdrop_center, backdrop_radius, Color(0.03, 0.05, 0.09, text_color.a * 0.18))
			draw_circle(backdrop_center, backdrop_radius * 0.72, Color(1.0, 0.95, 0.82, text_color.a * 0.07))
			draw_string(font, position + Vector2(2, 3), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
			draw_string(font, position + Vector2(-1, 1), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
			draw_string(font, position + Vector2(1, -1), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
			draw_string(font, position, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)


func _draw_tile_material(cell: CellData, center: Vector2, points: PackedVector2Array, fill: Color) -> void:
	var inset: PackedVector2Array = _scaled_points(points, center, 0.72)
	match cell.cell_type:
		GameTypes.CellType.EMPTY:
			var panel_line: Color = Color(0.74, 0.84, 0.96, 0.12)
			var groove_line: Color = Color(0.02, 0.03, 0.05, 0.34)
			draw_polyline(PackedVector2Array([inset[5], inset[0], inset[1]]), panel_line, 1.15, true)
			draw_line(center + Vector2(-15, -5), center + Vector2(15, -5), groove_line, 1.2)
			draw_line(center + Vector2(-10, 10), center + Vector2(10, 10), Color(0.76, 0.86, 0.96, 0.08), 1.0)
			for rivet_index in [0, 2, 4]:
				draw_circle(points[rivet_index].lerp(center, 0.36), 1.55, Color(0.76, 0.86, 0.96, 0.16))
		GameTypes.CellType.CENTER:
			draw_circle(center, hex_size * 0.36, Color(1.0, 0.91, 0.42, 0.2))
			draw_circle(center, hex_size * 0.24, Color("fff4ba"))
			draw_arc(center, hex_size * 0.46, 0.0, TAU, 42, Color("8c6317"), 2.6, true)
			draw_arc(center, hex_size * 0.31, 0.0, TAU, 36, Color(1.0, 0.96, 0.68, 0.72), 1.5, true)
			draw_polyline(PackedVector2Array([
				center + Vector2(-8, 0),
				center + Vector2(0, -8),
				center + Vector2(8, 0),
				center + Vector2(0, 8),
				center + Vector2(-8, 0),
			]), Color("8c6317"), 2.0, true)
		GameTypes.CellType.WALL:
			var wall_inset: PackedVector2Array = _scaled_points(points, center, 0.66)
			draw_colored_polygon(wall_inset, fill.darkened(0.1))
			for offset_x in [-12.0, 0.0, 12.0]:
				draw_line(center + Vector2(offset_x, -13), center + Vector2(offset_x, 13), Color(0.82, 0.89, 0.98, 0.18), 2.0)
			draw_line(center + Vector2(-17, -7), center + Vector2(17, -7), fill.darkened(0.24), 1.6)
			draw_line(center + Vector2(-15, 8), center + Vector2(15, 8), Color(0.02, 0.03, 0.05, 0.28), 2.0)
		GameTypes.CellType.BLOCK:
			var crate: PackedVector2Array = _scaled_points(points, center, 0.64)
			draw_colored_polygon(crate, fill.lightened(0.05))
			draw_polyline(_closed_polyline(crate), Color("3c2a1d"), 1.7, true)
			draw_line(center + Vector2(-14, -7), center + Vector2(14, 7), Color("d6b07b"), 1.5)
			draw_line(center + Vector2(-14, 7), center + Vector2(14, -7), Color("5c3d24"), 1.4)
			draw_polyline(PackedVector2Array([
				center + Vector2(-10, -6),
				center + Vector2(-2, 0),
				center + Vector2(-6, 10),
				center + Vector2(3, 4),
				center + Vector2(10, 12),
			]), Color("f2c98d"), 1.4, true)
			_draw_block_hp_pips(center, cell, Color("ffd48f"))
		GameTypes.CellType.ARMOR_BLOCK:
			draw_colored_polygon(inset, fill.lightened(0.06))
			draw_polyline(_closed_polyline(inset), Color("5a6470"), 1.6, true)
			draw_line(center + Vector2(-17, -1), center + Vector2(17, -1), Color(0.93, 0.97, 1.0, 0.22), 2.0)
			draw_line(center + Vector2(-13, 10), center + Vector2(13, 10), Color(0.03, 0.04, 0.06, 0.28), 1.7)
			var armor_points: PackedVector2Array = PackedVector2Array([inset[0], inset[2], inset[4]])
			for point: Vector2 in armor_points:
				draw_circle(point.lerp(center, 0.22), 2.3, Color("6d7684"))
			_draw_block_hp_pips(center, cell, Color("dbe7f5"))
		GameTypes.CellType.POWER_BLOCK:
			var crystal: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -14),
				center + Vector2(10, -1),
				center + Vector2(5, 13),
				center + Vector2(-5, 13),
				center + Vector2(-10, -1),
			])
			draw_circle(center, hex_size * 0.32, Color(0.78, 0.5, 1.0, 0.12 + 0.04 * sin(_pulse_time * 2.4)))
			draw_colored_polygon(crystal, Color("e7c6ff"))
			draw_polyline(_closed_polyline(crystal), Color("5d2d83"), 1.8, true)
			draw_line(center + Vector2(-4, -7), center + Vector2(4, 8), Color(1.0, 1.0, 1.0, 0.38), 1.3)
			_draw_block_hp_pips(center, cell, Color("f4d6ff"))
		GameTypes.CellType.POWER_ATTACK:
			draw_circle(center, hex_size * 0.25, Color(1.0, 0.74, 0.5, 0.16))
			draw_polyline(PackedVector2Array([
				center + Vector2(-9, 11),
				center + Vector2(-2, -10),
				center + Vector2(3, -2),
				center + Vector2(10, -12),
			]), Color("fff1d6"), 3.2, true)
		GameTypes.CellType.POWER_SHIELD:
			var shield: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -12),
				center + Vector2(12, -5),
				center + Vector2(8, 11),
				center + Vector2(0, 16),
				center + Vector2(-8, 11),
				center + Vector2(-12, -5),
			])
			draw_colored_polygon(shield, Color(1.0, 1.0, 1.0, 0.3))
			draw_polyline(_closed_polyline(shield), Color("d6efff"), 1.8, true)
		GameTypes.CellType.POWER_BONUS_MOVE:
			draw_circle(center, hex_size * 0.25, Color(0.56, 1.0, 0.7, 0.14))
			draw_polyline(PackedVector2Array([
				center + Vector2(-10, 4),
				center + Vector2(0, -10),
				center + Vector2(10, 4),
			]), Color("f0fff5"), 2.2, true)
			draw_polyline(PackedVector2Array([
				center + Vector2(-10, 10),
				center + Vector2(0, -4),
				center + Vector2(10, 10),
			]), Color("c6ffdb"), 2.2, true)
		_:
			pass


func _draw_block_hp_pips(center: Vector2, cell: CellData, pip_color: Color) -> void:
	var hp_value: int = maxi(cell.hp, 0)
	var max_hp: int = maxi(CellData.get_default_hp_for_type(cell.cell_type), 1)
	var pip_start: float = -float(max_hp - 1) * 3.0
	for index in range(max_hp):
		var active_alpha: float = 0.92 if index < hp_value else 0.18
		draw_circle(center + Vector2(pip_start + float(index) * 6.0, 15), 1.8, Color(pip_color.r, pip_color.g, pip_color.b, active_alpha))


func _tile_fill_color(cell: CellData) -> Color:
	var fill: Color = COLOR_BY_TYPE.get(cell.cell_type, Color.DIM_GRAY)
	var variation: float = _coord_variation(cell.coord)
	if variation > 0.5:
		fill = fill.lightened((variation - 0.5) * 0.1)
	else:
		fill = fill.darkened((0.5 - variation) * 0.09)
	var center_bias: float = clampf(1.0 - float(cell.coord.distance_to(HexCoord.new())) / maxf(float(_active_board().rings), 1.0), 0.0, 1.0)
	var world_center: Vector2 = cell.coord.to_world_flat(hex_size)
	var light_bias: float = clampf(((world_center.normalized().dot(-WORLD_LIGHT_DIR.normalized())) + 1.0) * 0.5, 0.0, 1.0)
	fill = fill.lerp(Color("7fbaff"), 0.014)
	fill = fill.lerp(Color("d8ebff"), 0.02 + light_bias * 0.022)
	fill = fill.lerp(Color.WHITE, 0.024 + center_bias * 0.042)
	if cell.coord.key() == hovered_key:
		var hover_mix: Color = Color("d7ebff")
		if current_action_mode == "move":
			hover_mix = _move_preview_color().lerp(Color.WHITE, 0.45)
		elif current_action_mode == "attack":
			hover_mix = _attack_preview_color().lerp(Color.WHITE, 0.2)
		fill = fill.lerp(hover_mix, 0.18)
	if cell.coord.key() == selected_key:
		fill = fill.lerp(_selected_outline_color(), 0.22)
	fill.a = 0.86 if cell.cell_type != GameTypes.CellType.CENTER else 0.92
	return fill


func _coord_variation(coord: HexCoord) -> float:
	var hash_value: int = absi(coord.q * 928371 + coord.r * 364479 + coord.q * coord.r * 95761 + 19349663)
	return float(hash_value % 1000) / 1000.0


func _draw_objective_tile_effects(cell: CellData, center: Vector2, points: PackedVector2Array) -> void:
	if cell.cell_type != GameTypes.CellType.CENTER:
		return
	var pulse_amplitude: float = 0.03 if AppState.reduced_motion else 0.08
	var pulse_radius: float = hex_size * (0.52 + pulse_amplitude * sin(_pulse_time * 2.2))
	var reaction_strength: float = _objective_reaction_strength(cell.coord.key())
	draw_circle(center, pulse_radius + 6.0, Color(1.0, 0.92, 0.47, 0.08))
	draw_circle(center, pulse_radius + 14.0, Color(1.0, 0.9, 0.56, 0.045))
	draw_arc(center, pulse_radius, 0.0, TAU, 48, Color(1.0, 0.95, 0.66, 0.82 + reaction_strength * 0.18), 2.0 + reaction_strength * 0.7, true)
	var objective_outline: PackedVector2Array = points.duplicate()
	objective_outline.append(points[0])
	draw_polyline(objective_outline, Color(0.96, 0.85, 0.42, 0.82 + reaction_strength * 0.18), 2.0 + reaction_strength * 1.0, true)


func _draw_objective_state_reaction(cell: CellData, center: Vector2, points: PackedVector2Array) -> void:
	var strength: float = _objective_reaction_strength(cell.coord.key())
	if strength <= 0.0:
		return
	var reaction: Dictionary = _objective_tile_reactions.get(cell.coord.key(), {})
	var reaction_color: Color = _effect_color(reaction, "color", Color("fff1a9"))
	var inset_points: PackedVector2Array = _scaled_points(points, center, 0.84)
	var overlay_color := Color(reaction_color.r, reaction_color.g, reaction_color.b, 0.08 + strength * 0.12)
	draw_colored_polygon(inset_points, overlay_color)
	var outline: PackedVector2Array = inset_points.duplicate()
	outline.append(inset_points[0])
	draw_polyline(outline, Color(reaction_color.r, reaction_color.g, reaction_color.b, 0.38 + strength * 0.4), 2.0 + strength * 1.2, true)
	draw_circle(center, hex_size * (0.22 + strength * 0.08), Color(reaction_color.r, reaction_color.g, reaction_color.b, 0.1 + strength * 0.08))


func _draw_range_overlays(active_board: BoardState) -> void:
	for key: String in highlighted_keys.keys():
		var cell: CellData = active_board.cells.get(key)
		if cell == null:
			continue
		var center: Vector2 = _tile_center(cell)
		var points: PackedVector2Array = _scaled_points(_hex_points(center), center, 0.89 if current_action_mode == "move" else 0.86)
		var overlay_color: Color = highlighted_keys[key]
		var alpha_scale: float = 0.34 if current_action_mode == "move" else 0.24
		var border_alpha: float = 0.95 if current_action_mode == "move" else 0.88
		var line_width: float = 2.6 if current_action_mode == "move" else 2.2
		var center_alpha: float = 0.12 if current_action_mode == "move" else 0.18
		var ring_radius: float = hex_size * (0.16 if current_action_mode == "move" else 0.19)
		if key == hovered_key:
			alpha_scale += 0.12 if current_action_mode == "move" else 0.08
			line_width += 0.8
			center_alpha += 0.14
		draw_colored_polygon(points, Color(overlay_color.r, overlay_color.g, overlay_color.b, alpha_scale))
		draw_colored_polygon(_scaled_points(points, center, 0.78), Color(overlay_color.r, overlay_color.g, overlay_color.b, center_alpha))
		var outline: PackedVector2Array = _closed_polyline(points)
		draw_polyline(outline, Color(overlay_color.r, overlay_color.g, overlay_color.b, border_alpha), line_width, true)
		if current_action_mode == "attack":
			draw_circle(center, hex_size * 0.14, Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.3))
			draw_arc(center, ring_radius, 0.0, TAU, 24, Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.72), 1.8, true)
			var target_tank: TankData = game_state.get_tank_at(cell.coord) if game_state != null else null
			if target_tank != null and target_tank.owner_id != game_state.current_player:
				draw_arc(center, hex_size * 0.28, 0.0, TAU, 32, Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.96), 2.2, true)
				draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.65), 1.6)
				draw_line(center + Vector2(-8, 8), center + Vector2(8, -8), Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.65), 1.6)
		else:
			draw_arc(center, ring_radius, 0.0, TAU, 24, Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.66), 1.6, true)


func _draw_path_preview(active_board: BoardState) -> void:
	var path: Array[HexCoord] = _current_hover_path()
	if path.is_empty():
		return
	var path_color: Color = _move_preview_color()
	var centers: PackedVector2Array = PackedVector2Array()
	for coord: HexCoord in path:
		var cell: CellData = active_board.get_cell(coord)
		if cell == null:
			continue
		var center: Vector2 = _tile_center(cell)
		centers.append(center)
		var path_points: PackedVector2Array = _scaled_points(_hex_points(center), center, 0.62)
		draw_colored_polygon(path_points, Color(path_color.r, path_color.g, path_color.b, 0.24))
		draw_polyline(_closed_polyline(path_points), Color(path_color.r, path_color.g, path_color.b, 0.9), 2.0, true)
	if centers.size() >= 2:
		draw_polyline(centers, Color(path_color.r, path_color.g, path_color.b, 0.98), 3.4, false)
		var last_center: Vector2 = centers[centers.size() - 1]
		draw_circle(last_center, hex_size * 0.2, Color(path_color.r, path_color.g, path_color.b, 0.72))
		draw_arc(last_center, hex_size * 0.28, 0.0, TAU, 28, Color(path_color.r, path_color.g, path_color.b, 0.95), 2.0, true)


func _draw_hover_and_selection_overlays(active_board: BoardState) -> void:
	if hovered_key != "" and active_board.cells.has(hovered_key):
		var hovered_cell: CellData = active_board.cells[hovered_key]
		var center: Vector2 = _tile_center(hovered_cell)
		var points: PackedVector2Array = _hex_points(center)
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		var hover_color: Color = Color("d8efff")
		if current_action_mode == "attack" and not highlighted_keys.has(hovered_key):
			hover_color = Color(_attack_preview_color().r, _attack_preview_color().g, _attack_preview_color().b, 0.65)
		var hover_points: PackedVector2Array = _scaled_points(points, center, 0.96)
		draw_colored_polygon(hover_points, Color(hover_color.r, hover_color.g, hover_color.b, 0.08 if current_action_mode == "" else 0.12))
		draw_polyline(_closed_polyline(hover_points), hover_color, 3.0, true)
		draw_arc(center + Vector2(0, 2), hex_size * 0.33, 0.0, TAU, 28, Color(hover_color.r, hover_color.g, hover_color.b, 0.52), 1.8, true)
		draw_circle(center + Vector2(0, 2), hex_size * 0.33, Color(hover_color.r, hover_color.g, hover_color.b, 0.09))
	if selected_key != "" and active_board.cells.has(selected_key):
		var selected_cell: CellData = active_board.cells[selected_key]
		var selected_center: Vector2 = _tile_center(selected_cell)
		var selected_points: PackedVector2Array = _scaled_points(_hex_points(selected_center), selected_center, 1.02)
		draw_colored_polygon(_scaled_points(selected_points, selected_center, 0.88), Color(_selected_outline_color().r, _selected_outline_color().g, _selected_outline_color().b, 0.08))
		draw_polyline(_closed_polyline(_scaled_points(selected_points, selected_center, 1.02)), _selected_outline_color(), 3.4, true)
		draw_polyline(_closed_polyline(_scaled_points(selected_points, selected_center, 0.93)), Color(_selected_outline_color().r, _selected_outline_color().g, _selected_outline_color().b, 0.5), 2.0, true)
	if current_action_mode == "attack":
		_draw_attack_preview_line(active_board)


func _draw_attack_preview_line(active_board: BoardState) -> void:
	if hovered_key == "" or selected_actor_id == "":
		return
	var attacker: TankData = game_state.get_tank(selected_actor_id) if game_state != null else null
	var hovered_cell: CellData = active_board.cells.get(hovered_key)
	if attacker == null or hovered_cell == null:
		return
	var from_cell: CellData = active_board.get_cell(attacker.position)
	if from_cell == null:
		return
	var from_center: Vector2 = _tile_center(from_cell)
	var to_center: Vector2 = _tile_center(hovered_cell)
	var line_color: Color = _attack_preview_color()
	if highlighted_keys.has(hovered_key):
		draw_line(from_center, to_center, Color(line_color.r, line_color.g, line_color.b, 0.92), 3.0)
		draw_arc(to_center, hex_size * 0.22, 0.0, TAU, 28, Color(line_color.r, line_color.g, line_color.b, 0.95), 2.2, true)
		draw_circle(to_center, hex_size * 0.2, Color(line_color.r, line_color.g, line_color.b, 0.2))
	else:
		_draw_dashed_line(from_center, to_center, Color(line_color.r, line_color.g, line_color.b, 0.5), 2.2, 10.0, 7.0)
		draw_arc(to_center, hex_size * 0.2, 0.0, TAU, 24, Color(line_color.r, line_color.g, line_color.b, 0.38), 1.8, true)


func _draw_dashed_line(from_point: Vector2, to_point: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var total_length: float = from_point.distance_to(to_point)
	if total_length <= 0.001:
		return
	var direction: Vector2 = (to_point - from_point).normalized()
	var cursor: float = 0.0
	while cursor < total_length:
		var dash_start: Vector2 = from_point + direction * cursor
		var dash_end: Vector2 = from_point + direction * minf(cursor + dash_length, total_length)
		draw_line(dash_start, dash_end, color, width)
		cursor += dash_length + gap_length


func _current_hover_path() -> Array[HexCoord]:
	var path: Array[HexCoord] = []
	if current_action_mode != "move" or selected_actor_id == "" or hovered_key == "":
		return path
	if not highlighted_keys.has(hovered_key):
		return path
	var tank: TankData = game_state.get_tank(selected_actor_id) if game_state != null else null
	var hovered_coord: HexCoord = HexCoord.from_key(hovered_key)
	if tank == null:
		return path
	for direction in range(HexCoord.DIRECTIONS.size()):
		var ray: Array[HexCoord] = tank.position.raycast(direction, tank.get_move_range())
		var candidate_path: Array[HexCoord] = []
		for step_coord: HexCoord in ray:
			if not _active_board().has_cell(step_coord):
				break
			if not _active_board().is_walkable(step_coord):
				break
			if game_state.is_cell_occupied(step_coord):
				break
			candidate_path.append(step_coord)
			if step_coord.equals(hovered_coord):
				return candidate_path
			if tank.tank_type == GameTypes.TankType.KTANK and tank.position.distance_to(step_coord) >= tank.get_move_range():
				break
	return path


func _movement_preview_path(tank: TankData, target_coord: HexCoord) -> Array[HexCoord]:
	var path: Array[HexCoord] = []
	if tank == null:
		return path
	for direction in range(HexCoord.DIRECTIONS.size()):
		var ray: Array[HexCoord] = tank.position.raycast(direction, tank.get_move_range())
		var candidate_path: Array[HexCoord] = []
		for step_coord: HexCoord in ray:
			if not _active_board().has_cell(step_coord):
				break
			if not _active_board().is_walkable(step_coord):
				break
			if game_state != null and game_state.is_cell_occupied(step_coord):
				break
			candidate_path.append(step_coord)
			if step_coord.equals(target_coord):
				return candidate_path
			if tank.tank_type == GameTypes.TankType.KTANK and tank.position.distance_to(step_coord) >= tank.get_move_range():
				break
	return path


func _is_tank_targeted(tank: TankData) -> bool:
	if highlighted_keys.is_empty():
		return false
	return highlighted_keys.has(tank.position.key()) and tank.owner_id != game_state.current_player


func _health_display_color(health_ratio: float) -> Color:
	if health_ratio <= 0.3:
		return Color("ff6673")
	if health_ratio <= 0.6:
		return Color("ffcb62")
	return Color("70df6e")


func _rotated_offset(offset: Vector2, rotation_value: float) -> Vector2:
	return offset.rotated(rotation_value)


func _draw_tank_sprite(center: Vector2, tank: TankData, rotation_value: float = 0.0, alpha: float = 1.0) -> void:
	var sprite_set: Dictionary = TANK_SPRITES.get(tank.actor_id(), {})
	if sprite_set.is_empty():
		var player_color: Color = _player_primary_color(tank.owner_id)
		var accent_color: Color = _player_accent_color(tank.owner_id)
		if tank.tank_type == GameTypes.TankType.QTANK:
			_draw_qtank(center, Color(player_color.r, player_color.g, player_color.b, alpha), Color(accent_color.r, accent_color.g, accent_color.b, alpha))
		else:
			_draw_ktank(center, Color(player_color.r, player_color.g, player_color.b, alpha), Color(accent_color.r, accent_color.g, accent_color.b, alpha))
		return

	var scale_value: float = float(sprite_set.get("scale", 0.34))
	var track_texture: Texture2D = sprite_set.get("track", null) as Texture2D
	var hull_texture: Texture2D = sprite_set.get("hull", null) as Texture2D
	var gun_texture: Texture2D = sprite_set.get("gun", null) as Texture2D
	var primary_color: Color = _player_primary_color(tank.owner_id)
	var accent_color: Color = _player_accent_color(tank.owner_id)
	var track_modulate: Color = Color(0.28, 0.31, 0.38, alpha)
	var hull_modulate: Color = (Color(0.7, 0.8, 0.9, alpha) if tank.owner_id == 1 else Color(0.7, 0.6, 0.56, alpha))
	var gun_modulate: Color = accent_color.lerp(Color.WHITE, 0.26)
	gun_modulate.a = alpha
	var faction_shade: Color = primary_color.darkened(0.18)
	faction_shade.a = alpha * 0.48
	var is_qtank: bool = tank.tank_type == GameTypes.TankType.QTANK
	var front_offset: Vector2 = _rotated_offset(Vector2(0, (-17.0 if is_qtank else -15.0)), rotation_value)
	var side_offset: Vector2 = _rotated_offset(Vector2((9.0 if is_qtank else 11.0), 0), rotation_value)
	var rear_shadow_offset: Vector2 = _rotated_offset(Vector2(0, (9 if is_qtank else 11)), rotation_value)
	var top_panel_center: Vector2 = center + _rotated_offset(Vector2(0, -6), rotation_value)
	var chassis_panel_center: Vector2 = center + _rotated_offset(Vector2(0, 5), rotation_value)
	var rear_center: Vector2 = center + _rotated_offset(Vector2(0, 11), rotation_value)
	var hull_center: Vector2 = center + Vector2(0, 1)
	var gun_center: Vector2 = center + Vector2(0, (-3 if is_qtank else -2))
	var front_chevron_color: Color = Color(primary_color.r, primary_color.g, primary_color.b, 0.86 * alpha)
	var armor_edge_color: Color = Color(0.92, 0.96, 1.0, (0.38 if is_qtank else 0.28) * alpha)
	var recess_color: Color = Color(0.03, 0.05, 0.09, 0.42 * alpha)
	var plate_color: Color = Color(primary_color.r, primary_color.g, primary_color.b, (0.14 if is_qtank else 0.26) * alpha)
	var front_edge_color: Color = Color(accent_color.r, accent_color.g, accent_color.b, (0.76 if is_qtank else 0.88) * alpha)
	var rear_quiet_color: Color = Color(0.02, 0.03, 0.06, 0.24 * alpha)

	if track_texture != null:
		_draw_centered_texture(track_texture, center + Vector2(0, 4), (scale_value * (0.96 if is_qtank else 1.08)), rotation_value, track_modulate)
	if hull_texture != null:
		_draw_centered_texture(hull_texture, hull_center, (scale_value * (0.95 if is_qtank else 1.07)), rotation_value, hull_modulate)
	if gun_texture != null:
		_draw_centered_texture(gun_texture, gun_center, (scale_value * (0.9 if is_qtank else 1.14)), rotation_value, gun_modulate)

	draw_circle(center + rear_shadow_offset + Vector2(0, 1), (7.0 if is_qtank else 10.2), Color(0.04, 0.05, 0.08, 0.22 * alpha))
	draw_circle(rear_center, (4.8 if is_qtank else 6.4), Color(0.03, 0.04, 0.07, 0.22 * alpha))
	draw_line(center + _rotated_offset(Vector2(-9, -1), rotation_value), center + _rotated_offset(Vector2(9, -1), rotation_value), faction_shade, 3.0)
	draw_line(center + _rotated_offset(Vector2(-7, -8), rotation_value), center + _rotated_offset(Vector2(7, -8), rotation_value), Color(primary_color.r, primary_color.g, primary_color.b, 0.72 * alpha), 1.9)
	draw_line(center + _rotated_offset(Vector2(-6, 8), rotation_value), center + _rotated_offset(Vector2(6, 8), rotation_value), recess_color, 2.2)
	draw_colored_polygon(PackedVector2Array([
		center + _rotated_offset(Vector2((-6 if is_qtank else -8), 7), rotation_value),
		center + _rotated_offset(Vector2((6 if is_qtank else 8), 7), rotation_value),
		center + _rotated_offset(Vector2((4 if is_qtank else 6), 12), rotation_value),
		center + _rotated_offset(Vector2((-4 if is_qtank else -6), 12), rotation_value),
	]), rear_quiet_color)
	draw_colored_polygon(PackedVector2Array([
		center + _rotated_offset(Vector2((-7 if is_qtank else -9), -3), rotation_value),
		center + _rotated_offset(Vector2((7 if is_qtank else 9), -3), rotation_value),
		center + _rotated_offset(Vector2((6 if is_qtank else 8), 6), rotation_value),
		center + _rotated_offset(Vector2((-6 if is_qtank else -8), 6), rotation_value),
	]), plate_color)
	if is_qtank:
		draw_line(center + _rotated_offset(Vector2(-2, -10), rotation_value), center + _rotated_offset(Vector2(-2, -25), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.82 * alpha), 1.2)
		draw_line(center + _rotated_offset(Vector2(2, -10), rotation_value), center + _rotated_offset(Vector2(2, -25), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.72 * alpha), 1.0)
		draw_polyline(PackedVector2Array([
			center + _rotated_offset(Vector2(-7, -10), rotation_value),
			center + _rotated_offset(Vector2(0, -16), rotation_value),
			center + _rotated_offset(Vector2(7, -10), rotation_value),
		]), front_chevron_color, 2.2, false)
		draw_line(center + _rotated_offset(Vector2(0, -13), rotation_value), center + _rotated_offset(Vector2(0, -25), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.95 * alpha), 1.7)
		draw_line(center + _rotated_offset(Vector2(-10, 4), rotation_value), center + _rotated_offset(Vector2(10, 4), rotation_value), armor_edge_color, 1.9)
		draw_line(center + _rotated_offset(Vector2(-6, -13), rotation_value), center + _rotated_offset(Vector2(6, -13), rotation_value), front_edge_color, 1.5)
		draw_line(center + _rotated_offset(Vector2(-5, -16), rotation_value), center + _rotated_offset(Vector2(5, -16), rotation_value), Color(1.0, 1.0, 1.0, 0.22 * alpha), 1.0)
		draw_polyline(PackedVector2Array([
			center + _rotated_offset(Vector2(-10, 7), rotation_value),
			center + _rotated_offset(Vector2(0, 2), rotation_value),
			center + _rotated_offset(Vector2(10, 7), rotation_value),
		]), Color(primary_color.r, primary_color.g, primary_color.b, 0.54 * alpha), 1.5, false)
	else:
		draw_colored_polygon(PackedVector2Array([
			center + _rotated_offset(Vector2(-12, -8), rotation_value),
			center + _rotated_offset(Vector2(12, -8), rotation_value),
			center + _rotated_offset(Vector2(9, 2), rotation_value),
			center + _rotated_offset(Vector2(-9, 2), rotation_value),
		]), Color(primary_color.r, primary_color.g, primary_color.b, 0.24 * alpha))
		draw_polyline(PackedVector2Array([
			center + _rotated_offset(Vector2(-8, -10), rotation_value),
			center + _rotated_offset(Vector2(0, -16), rotation_value),
			center + _rotated_offset(Vector2(8, -10), rotation_value),
		]), front_chevron_color, 2.5, false)
		draw_line(center + _rotated_offset(Vector2(-12, 3), rotation_value), center + _rotated_offset(Vector2(12, 3), rotation_value), Color(0.76, 0.8, 0.88, 0.2 * alpha), 2.6)
		draw_line(center + _rotated_offset(Vector2(0, -10), rotation_value), center + _rotated_offset(Vector2(0, -22), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.94 * alpha), 2.4)
		draw_line(center + _rotated_offset(Vector2(-4, -9), rotation_value), center + _rotated_offset(Vector2(-4, -21), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.58 * alpha), 1.2)
		draw_line(center + _rotated_offset(Vector2(4, -9), rotation_value), center + _rotated_offset(Vector2(4, -21), rotation_value), Color(accent_color.r, accent_color.g, accent_color.b, 0.58 * alpha), 1.2)
		draw_line(center + _rotated_offset(Vector2(-8, -14), rotation_value), center + _rotated_offset(Vector2(8, -14), rotation_value), front_edge_color, 1.9)
		draw_line(center + _rotated_offset(Vector2(-6, -17), rotation_value), center + _rotated_offset(Vector2(6, -17), rotation_value), Color(1.0, 1.0, 1.0, 0.2 * alpha), 1.2)
	draw_circle(center + front_offset, (3.0 if is_qtank else 3.6), Color(accent_color.r, accent_color.g, accent_color.b, 0.97 * alpha))
	draw_circle(center + front_offset, 1.7, Color.WHITE.lerp(accent_color, 0.24))
	draw_circle(top_panel_center, 2.8, Color(0.07, 0.1, 0.14, 0.42 * alpha))
	draw_circle(top_panel_center, 1.4, Color(primary_color.r, primary_color.g, primary_color.b, 0.7 * alpha))
	if tank.owner_id == 1:
		draw_line(center + _rotated_offset(Vector2(-8, 7), rotation_value), center + _rotated_offset(Vector2(8, 7), rotation_value), Color(primary_color.r, primary_color.g, primary_color.b, 0.68 * alpha), 1.9)
		draw_line(chassis_panel_center + _rotated_offset(Vector2(-8, 2), rotation_value), chassis_panel_center + _rotated_offset(Vector2(8, 2), rotation_value), Color(0.84, 0.94, 1.0, 0.34 * alpha), 1.4)
		draw_line(top_panel_center + _rotated_offset(Vector2(-4, 0), rotation_value), top_panel_center + _rotated_offset(Vector2(4, 0), rotation_value), Color(0.84, 0.94, 1.0, 0.26 * alpha), 1.2)
	else:
		draw_polyline(PackedVector2Array([
			center + _rotated_offset(Vector2(-7, 6), rotation_value),
			center + _rotated_offset(Vector2(-1, 2), rotation_value),
			center + _rotated_offset(Vector2(5, 6), rotation_value),
		]), Color(primary_color.r, primary_color.g, primary_color.b, 0.7 * alpha), 1.8, false)
		draw_line(top_panel_center + _rotated_offset(Vector2(-4, -1), rotation_value), top_panel_center + _rotated_offset(Vector2(4, 2), rotation_value), Color(1.0, 0.86, 0.76, 0.22 * alpha), 1.1)
		draw_polyline(PackedVector2Array([
			chassis_panel_center + _rotated_offset(Vector2(-6, 2), rotation_value),
			chassis_panel_center + _rotated_offset(Vector2(0, -2), rotation_value),
			chassis_panel_center + _rotated_offset(Vector2(6, 2), rotation_value),
		]), Color(1.0, 0.84, 0.74, 0.24 * alpha), 1.4, false)
	draw_circle(center + side_offset, 2.4, Color(primary_color.r, primary_color.g, primary_color.b, 0.52 * alpha))
	if BOARD_FONT != null:
		var decal_text: String = "Q" if is_qtank else "K"
		draw_string(BOARD_FONT, chassis_panel_center + _rotated_offset(Vector2(-4, 5), rotation_value), decal_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.92, 0.96, 1.0, 0.72 * alpha))


func _draw_centered_texture(texture: Texture2D, center: Vector2, scale_value: float, rotation_value: float = 0.0, modulate_color: Color = Color.WHITE) -> void:
	var texture_size: Vector2 = texture.get_size()
	draw_set_transform(center, rotation_value, Vector2.ONE * scale_value)
	draw_texture(texture, -texture_size * 0.5, modulate_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_qtank(center: Vector2, player_color: Color, accent_color: Color) -> void:
	var chassis: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -16),
		center + Vector2(13, -4),
		center + Vector2(11, 11),
		center + Vector2(0, 15),
		center + Vector2(-11, 11),
		center + Vector2(-13, -4),
	])
	var canopy: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -10),
		center + Vector2(8, -1),
		center + Vector2(0, 8),
		center + Vector2(-8, -1),
	])
	var stabilizer_left: PackedVector2Array = PackedVector2Array([
		center + Vector2(-15, -2),
		center + Vector2(-10, 8),
		center + Vector2(-5, 5),
		center + Vector2(-8, -4),
	])
	var stabilizer_right: PackedVector2Array = PackedVector2Array([
		center + Vector2(15, -2),
		center + Vector2(10, 8),
		center + Vector2(5, 5),
		center + Vector2(8, -4),
	])
	draw_colored_polygon(chassis, player_color.darkened(0.15))
	draw_colored_polygon(stabilizer_left, player_color.darkened(0.3))
	draw_colored_polygon(stabilizer_right, player_color.darkened(0.3))
	draw_line(center + Vector2(0, -15), center + Vector2(0, -27), accent_color, 3.0)
	draw_circle(center + Vector2(0, -28), 2.8, accent_color)
	draw_colored_polygon(canopy, Color("101722"))
	draw_polyline(_closed_polyline(chassis), Color("eff7ff"), 1.5, true)
	draw_line(center + Vector2(-7, 6), center + Vector2(7, 6), accent_color, 1.6)


func _draw_ktank(center: Vector2, player_color: Color, accent_color: Color) -> void:
	var treads: PackedVector2Array = PackedVector2Array([
		center + Vector2(-16, -8),
		center + Vector2(16, -8),
		center + Vector2(16, 10),
		center + Vector2(-16, 10),
	])
	var hull: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -14),
		center + Vector2(14, -7),
		center + Vector2(15, 5),
		center + Vector2(0, 13),
		center + Vector2(-15, 5),
		center + Vector2(-14, -7),
	])
	draw_colored_polygon(treads, Color("141922"))
	draw_colored_polygon(hull, player_color.darkened(0.08))
	draw_circle(center + Vector2(0, -1), 7.5, Color("0f141d"))
	draw_circle(center + Vector2(0, -1), 4.2, accent_color)
	draw_line(center + Vector2(0, -1), center + Vector2(0, -21), Color("0f141d"), 5.0)
	draw_line(center + Vector2(0, -1), center + Vector2(0, -21), accent_color, 2.2)
	draw_line(center + Vector2(-11, 2), center + Vector2(11, 2), accent_color.darkened(0.25), 1.8)
	draw_polyline(_closed_polyline(hull), Color("eff7ff"), 1.6, true)
	for track_x in [-10.0, -3.0, 4.0, 11.0]:
		draw_circle(center + Vector2(track_x, 11), 1.5, Color("445061"))


func _scaled_points(points: PackedVector2Array, center: Vector2, amount: float) -> PackedVector2Array:
	var scaled: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(center + (point - center) * amount)
	return scaled


func _closed_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var outline: PackedVector2Array = points.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
	return outline


func _ellipse_points(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * float(index) / float(maxi(segments, 3))
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _process_effects(delta: float) -> void:
	_tick_effect_array(_beam_effects, delta)
	_tick_effect_array(_ring_effects, delta)
	_tick_effect_array(_flash_effects, delta)
	_tick_effect_array(_sprite_effects, delta)
	_tick_effect_array(_floating_texts, delta)
	_tick_motion_overrides(delta)
	_tick_hit_reactions(delta)
	_tick_fadeouts(delta)
	_tick_objective_tile_reactions(delta)
	if AppState.reduced_motion:
		_shake_timer = 0.0
		_shake_strength = 0.0
		_shake_offset = Vector2.ZERO
		return
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var shake_ratio: float = _shake_timer / maxf(_shake_strength, 0.001)
		var offset_scale: float = 5.0 * shake_ratio
		_shake_offset = Vector2(randf_range(-offset_scale, offset_scale), randf_range(-offset_scale * 0.7, offset_scale * 0.7))
	else:
		_shake_offset = Vector2.ZERO


func _tick_effect_array(effect_array: Array[Dictionary], delta: float) -> void:
	for index in range(effect_array.size() - 1, -1, -1):
		var effect: Dictionary = effect_array[index]
		var delay_remaining: float = _effect_float(effect, "delay", 0.0)
		if delay_remaining > 0.0:
			delay_remaining -= delta
			effect["delay"] = delay_remaining
			if delay_remaining > 0.0:
				effect_array[index] = effect
				continue
		effect["time_left"] = _effect_float(effect, "time_left", 0.0) - delta
		if _effect_float(effect, "time_left", 0.0) <= 0.0:
			effect_array.remove_at(index)
		else:
			effect_array[index] = effect


func _tick_motion_overrides(delta: float) -> void:
	for actor_id: String in _tank_motion_overrides.keys():
		var motion: Dictionary = _tank_motion_overrides[actor_id]
		motion["time_left"] = _effect_float(motion, "time_left", 0.0) - delta
		if _effect_float(motion, "time_left", 0.0) <= 0.0:
			_tank_motion_overrides.erase(actor_id)
		else:
			_tank_motion_overrides[actor_id] = motion


func _tick_hit_reactions(delta: float) -> void:
	for actor_id: String in _tank_hit_reactions.keys():
		var reaction: Dictionary = _tank_hit_reactions[actor_id]
		reaction["time_left"] = _effect_float(reaction, "time_left", 0.0) - delta
		if _effect_float(reaction, "time_left", 0.0) <= 0.0:
			_tank_hit_reactions.erase(actor_id)
		else:
			_tank_hit_reactions[actor_id] = reaction


func _tick_fadeouts(delta: float) -> void:
	for actor_id: String in _tank_fadeouts.keys():
		var fadeout: Dictionary = _tank_fadeouts[actor_id]
		fadeout["time_left"] = _effect_float(fadeout, "time_left", 0.0) - delta
		if _effect_float(fadeout, "time_left", 0.0) <= 0.0:
			_tank_fadeouts.erase(actor_id)
		else:
			_tank_fadeouts[actor_id] = fadeout


func _tick_objective_tile_reactions(delta: float) -> void:
	for coord_key: String in _objective_tile_reactions.keys():
		var reaction: Dictionary = _objective_tile_reactions[coord_key]
		reaction["time_left"] = _effect_float(reaction, "time_left", 0.0) - delta
		if _effect_float(reaction, "time_left", 0.0) <= 0.0:
			_objective_tile_reactions.erase(coord_key)
		else:
			_objective_tile_reactions[coord_key] = reaction


func _motion_override_center(actor_id: String, fallback_center: Vector2) -> Vector2:
	var motion: Dictionary = _tank_motion_overrides.get(actor_id, {})
	if motion.is_empty():
		return fallback_center
	var duration: float = maxf(_effect_float(motion, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(motion, "time_left", 0.0), 0.0, duration)
	var progress: float = 1.0 - (time_left / duration)
	var start_center: Vector2 = _effect_vec2(motion, "start", fallback_center)
	var end_center: Vector2 = _effect_vec2(motion, "end", fallback_center)
	var eased_progress: float = _smooth_motion_progress(progress)
	return start_center.lerp(end_center, eased_progress)


func _motion_override_angle(actor_id: String, fallback_angle: float) -> float:
	var motion: Dictionary = _tank_motion_overrides.get(actor_id, {})
	if motion.is_empty():
		return fallback_angle
	var duration: float = maxf(_effect_float(motion, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(motion, "time_left", 0.0), 0.0, duration)
	var progress: float = 1.0 - (time_left / duration)
	var eased_progress: float = _smooth_motion_progress(progress)
	var fallback_facing: float = fallback_angle - PI * 0.5
	var start_angle: float = _tank_visual_rotation_from_facing(_effect_float(motion, "start_angle", fallback_facing))
	var end_angle: float = _tank_visual_rotation_from_facing(_effect_float(motion, "end_angle", fallback_facing))
	return lerp_angle(start_angle, end_angle, eased_progress)


func _smooth_motion_progress(progress: float) -> float:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	return 0.5 - cos(clamped_progress * PI) * 0.5


func _tank_hit_flash_alpha(actor_id: String) -> float:
	var reaction: Dictionary = _tank_hit_reactions.get(actor_id, {})
	if reaction.is_empty():
		return 0.0
	var duration: float = maxf(_effect_float(reaction, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(reaction, "time_left", 0.0), 0.0, duration)
	var progress: float = 1.0 - (time_left / duration)
	return sin(progress * PI) * 0.32


func _tank_fade_alpha(actor_id: String) -> float:
	var fadeout: Dictionary = _tank_fadeouts.get(actor_id, {})
	if fadeout.is_empty():
		return 0.0
	var duration: float = maxf(_effect_float(fadeout, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(fadeout, "time_left", 0.0), 0.0, duration)
	return clampf(1.0 - (time_left / duration), 0.0, 1.0)


func _objective_reaction_strength(coord_key: String) -> float:
	var reaction: Dictionary = _objective_tile_reactions.get(coord_key, {})
	if reaction.is_empty():
		return 0.0
	var duration: float = maxf(_effect_float(reaction, "duration", 1.0), 0.001)
	var time_left: float = clampf(_effect_float(reaction, "time_left", 0.0), 0.0, duration)
	var progress: float = 1.0 - (time_left / duration)
	return sin(progress * PI)


func _tank_draw_rotation(tank: TankData) -> float:
	var base_angle: float = _tank_visual_rotation_from_facing(tank.facing_angle)
	if _tank_motion_overrides.has(tank.actor_id()):
		return _motion_override_angle(tank.actor_id(), base_angle)
	return base_angle


func _tank_visual_rotation_from_facing(facing_angle: float) -> float:
	return facing_angle + PI * 0.5


func _apply_event_feedback(previous_state: GameState, current_state: GameState, action: ActionData, event_item: GameEvent) -> void:
	match event_item.event_name:
		"hit_tank":
			var hit_coord: HexCoord = HexCoord.from_key(str(event_item.payload.get("coord", "")))
			var hit_center: Vector2 = hit_coord.to_world_flat(hex_size)
			var damage: int = int(event_item.payload.get("damage", 0))
			var target_id: String = str(event_item.payload.get("target", ""))
			_flash_effects.append({
				"center": hit_center,
				"color": Color("fff5ef"),
				"radius": 28.0,
				"time_left": 0.46,
				"duration": 0.46,
			})
			_sprite_effects.append({
				"texture": EFFECT_SPARK,
				"center": hit_center,
				"color": Color(1.0, 0.9, 0.76, 0.9),
				"scale_start": 0.28,
				"scale_end": 0.52,
				"time_left": 0.32,
				"duration": 0.32,
				"drift": Vector2(0, -10),
			})
			_ring_effects.append({
				"center": hit_center,
				"color": Color("fff2c6"),
				"radius": 22.0,
				"time_left": 0.24,
				"duration": 0.24,
				"filled": false,
			})
			_floating_texts.append({
				"center": hit_center,
				"text": "-%d" % damage,
				"color": Color("fff7e6"),
				"time_left": 0.66,
				"duration": 0.66,
				"font_size": 36,
				"delay": 0.02,
				"drift_distance": 30.0,
			})
			var target_tank: TankData = current_state.get_tank(target_id)
			if target_tank != null:
				var attacker: TankData = previous_state.get_tank(str(action.actor_id))
				var recoil_dir: Vector2 = Vector2.ZERO
				if attacker != null:
					recoil_dir = (hit_center - attacker.position.to_world_flat(hex_size)).normalized()
				if recoil_dir == Vector2.ZERO:
					recoil_dir = Vector2(0, -1)
				_tank_hit_reactions[target_id] = {
					"time_left": 0.22,
					"duration": 0.22,
				}
				_tank_motion_overrides[target_id] = {
					"start": hit_center + recoil_dir * 12.0,
					"end": hit_center,
					"start_angle": target_tank.facing_angle + 0.07,
					"end_angle": target_tank.facing_angle,
					"time_left": 0.22,
					"duration": 0.22,
				}
			_trigger_shake(0.3)
		"hit_cell":
			var cell_coord: HexCoord = HexCoord.from_key(str(event_item.payload.get("coord", "")))
			var cell_center: Vector2 = cell_coord.to_world_flat(hex_size)
			_flash_effects.append({
				"center": cell_center,
				"color": Color("ffd59e"),
				"radius": 15.0,
				"time_left": 0.32,
				"duration": 0.32,
			})
			if bool(event_item.payload.get("destroyed", false)):
				_ring_effects.append({
					"center": cell_center,
					"color": Color("ffcf7a"),
					"radius": 24.0,
					"time_left": 0.5,
					"duration": 0.5,
					"filled": true,
				})
			_trigger_shake(0.2)
		"power_up":
			var actor_id: String = str(event_item.payload.get("actor_id", ""))
			var buff_tank: TankData = current_state.get_tank(actor_id)
			if buff_tank != null:
				var buff_center: Vector2 = buff_tank.position.to_world_flat(hex_size)
				_objective_tile_reactions[buff_tank.position.key()] = {
					"color": _buff_color(buff_tank.active_buff),
					"time_left": 0.56,
					"duration": 0.56,
				}
				_ring_effects.append({
					"center": buff_center,
					"color": _buff_color(buff_tank.active_buff),
					"radius": 22.0,
					"time_left": 0.6,
					"duration": 0.6,
					"filled": true,
				})
				_sprite_effects.append({
					"texture": EFFECT_SPARK,
					"center": buff_center,
					"color": Color(_buff_color(buff_tank.active_buff).r, _buff_color(buff_tank.active_buff).g, _buff_color(buff_tank.active_buff).b, 0.54),
					"scale_start": 0.16,
					"scale_end": 0.3,
					"time_left": 0.34,
					"duration": 0.34,
					"drift": Vector2(0, -6),
				})
				_flash_effects.append({
					"center": buff_center,
					"color": Color(_buff_color(buff_tank.active_buff).r, _buff_color(buff_tank.active_buff).g, _buff_color(buff_tank.active_buff).b, 0.2),
					"radius": 24.0,
					"time_left": 0.26,
					"duration": 0.26,
				})
		"tank_destroyed":
			var destroyed_id: String = str(event_item.payload.get("target", ""))
			var destroyed_tank: TankData = previous_state.get_tank(destroyed_id)
			if destroyed_tank != null:
				var destroyed_center: Vector2 = destroyed_tank.position.to_world_flat(hex_size)
				_tank_fadeouts[destroyed_id] = {
					"tank": destroyed_tank.clone(),
					"center": destroyed_center,
					"start_center": destroyed_center,
					"collapse_offset": Vector2(0, 20),
					"time_left": 0.72,
					"duration": 0.72,
				}
				_flash_effects.append({
					"center": destroyed_center,
					"color": Color("fff0dd"),
					"radius": 48.0,
					"time_left": 0.42,
					"duration": 0.42,
				})
				_ring_effects.append({
					"center": destroyed_center,
					"color": Color("ffd09b"),
					"radius": 44.0,
					"time_left": 0.86,
					"duration": 0.86,
					"filled": true,
				})
				_ring_effects.append({
					"center": destroyed_center,
					"color": Color("ffefbc"),
					"radius": 34.0,
					"time_left": 0.38,
					"duration": 0.38,
					"filled": false,
				})
				_sprite_effects.append({
					"texture": EFFECT_SMOKE,
					"center": destroyed_center,
					"color": Color(1.0, 0.84, 0.62, 0.8),
					"scale_start": 0.32,
					"scale_end": 0.64,
					"time_left": 0.96,
					"duration": 0.96,
					"drift": Vector2(0, -22),
				})
				_sprite_effects.append({
					"texture": EFFECT_SPARK,
					"center": destroyed_center,
					"color": Color(1.0, 0.75, 0.52, 0.78),
					"scale_start": 0.3,
					"scale_end": 0.5,
					"time_left": 0.4,
					"duration": 0.4,
				})
				_sprite_effects.append({
					"texture": EFFECT_SPARK,
					"center": destroyed_center,
					"color": Color(1.0, 0.92, 0.78, 0.72),
					"scale_start": 0.2,
					"scale_end": 0.46,
					"time_left": 0.46,
					"duration": 0.46,
					"drift": Vector2(0, -10),
				})
				_floating_texts.append({
					"center": destroyed_center,
					"text": "DESTROYED",
					"color": Color("ffd8a3"),
					"time_left": 0.72,
					"duration": 0.72,
					"font_size": 18,
					"drift_distance": 18.0,
				})
			_trigger_shake(0.42)
		"win_center":
			_objective_tile_reactions[HexCoord.new().key()] = {
				"color": Color("fff0a9"),
				"time_left": 0.84,
				"duration": 0.84,
			}
			_flash_effects.append({
				"center": HexCoord.new().to_world_flat(hex_size),
				"color": Color("fff4c6"),
				"radius": 34.0,
				"time_left": 0.38,
				"duration": 0.38,
			})
			_ring_effects.append({
				"center": HexCoord.new().to_world_flat(hex_size),
				"color": Color("fff1a9"),
				"radius": 38.0,
				"time_left": 0.78,
				"duration": 0.78,
				"filled": true,
			})
			_sprite_effects.append({
				"texture": EFFECT_SPARK,
				"center": HexCoord.new().to_world_flat(hex_size),
				"color": Color(1.0, 0.93, 0.58, 0.72),
				"scale_start": 0.24,
				"scale_end": 0.46,
				"time_left": 0.42,
				"duration": 0.42,
				"drift": Vector2(0, -10),
			})


func _play_attack_effect(previous_state: GameState, action: ActionData) -> void:
	var attacker: TankData = previous_state.get_tank(action.actor_id)
	if attacker == null:
		return
	var source_center: Vector2 = attacker.position.to_world_flat(hex_size)
	var attack_dir: Vector2 = Vector2.UP
	if action.direction >= 0 and action.direction < HexCoord.DIRECTIONS.size():
		var neighbor_center: Vector2 = attacker.position.neighbor(action.direction).to_world_flat(hex_size)
		attack_dir = (neighbor_center - source_center).normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2.UP
	_tank_motion_overrides[action.actor_id] = {
		"start": source_center - attack_dir * 6.0,
		"end": source_center,
		"start_angle": attacker.facing_angle - 0.03,
		"end_angle": attacker.facing_angle,
		"time_left": 0.14,
		"duration": 0.14,
	}
	_ring_effects.append({
		"center": source_center,
		"color": Color(1.0, 1.0, 1.0, 0.18) if attacker.tank_type == GameTypes.TankType.QTANK else Color(1.0, 0.78, 0.48, 0.2),
		"radius": 18.0,
		"time_left": 0.12,
		"duration": 0.12,
		"filled": true,
	})
	_flash_effects.append({
		"center": source_center + attack_dir * 10.0,
		"color": Color("c5f9ff") if attacker.tank_type == GameTypes.TankType.QTANK else Color("ffc285"),
		"radius": 16.0,
		"time_left": 0.16,
		"duration": 0.16,
		"delay": 0.06,
	})
	if attacker.tank_type == GameTypes.TankType.QTANK:
		var target_center: Vector2 = source_center
		for step_coord: HexCoord in attacker.position.raycast(action.direction, previous_state.board.rings * 3):
			if not previous_state.board.has_cell(step_coord):
				break
			target_center = step_coord.to_world_flat(hex_size)
			if previous_state.get_tank_at(step_coord) != null or previous_state.board.blocks_attack(step_coord):
				break
		_beam_effects.append({
			"start": source_center,
			"end": target_center,
			"color": Color("7ef3ff"),
			"width": 6.8,
			"time_left": 0.22,
			"duration": 0.22,
			"delay": 0.1,
		})
		_sprite_effects.append({
			"texture": EFFECT_MUZZLE,
			"center": source_center,
			"color": Color(0.72, 0.98, 1.0, 0.82),
			"scale_start": 0.3,
			"scale_end": 0.5,
			"rotation": _tank_visual_rotation_from_facing(attacker.facing_angle),
			"time_left": 0.2,
			"duration": 0.2,
			"delay": 0.08,
		})
		_sprite_effects.append({
			"texture": EFFECT_TRACE,
			"center": source_center + attack_dir * 18.0,
			"color": Color(0.62, 0.95, 1.0, 0.48),
			"scale_start": 0.18,
			"scale_end": 0.3,
			"rotation": _tank_visual_rotation_from_facing(attacker.facing_angle),
			"time_left": 0.18,
			"duration": 0.18,
			"delay": 0.08,
			"drift": attack_dir * 16.0,
		})
		_sprite_effects.append({
			"texture": EFFECT_SPARK,
			"center": target_center,
			"color": Color(0.84, 1.0, 1.0, 0.74),
			"scale_start": 0.26,
			"scale_end": 0.46,
			"time_left": 0.24,
			"duration": 0.24,
			"delay": 0.11,
			"drift": Vector2(0, -6),
		})
		_ring_effects.append({
			"center": target_center,
			"color": Color("b7ffff"),
			"radius": 22.0,
			"time_left": 0.28,
			"duration": 0.28,
			"delay": 0.11,
			"filled": false,
		})
		_trigger_shake(0.22)
	else:
		_ring_effects.append({
			"center": source_center,
			"color": Color("ffb46f"),
			"radius": 26.0,
			"time_left": 0.46,
			"duration": 0.46,
			"delay": 0.08,
			"filled": true,
		})
		_sprite_effects.append({
			"texture": EFFECT_MUZZLE,
			"center": source_center,
			"color": Color(1.0, 0.78, 0.48, 0.82),
			"scale_start": 0.3,
			"scale_end": 0.46,
			"rotation": _tank_visual_rotation_from_facing(attacker.facing_angle),
			"time_left": 0.22,
			"duration": 0.22,
			"delay": 0.08,
		})
		for neighbor_coord: HexCoord in attacker.position.neighbors():
			if previous_state.board.has_cell(neighbor_coord):
				var neighbor_center: Vector2 = neighbor_coord.to_world_flat(hex_size)
				_flash_effects.append({
					"center": neighbor_center,
					"color": Color("ff936d"),
					"radius": 16.0,
					"time_left": 0.28,
					"duration": 0.28,
					"delay": 0.11,
				})
				_sprite_effects.append({
					"texture": EFFECT_SPARK,
					"center": neighbor_center,
					"color": Color(1.0, 0.66, 0.48, 0.7),
					"scale_start": 0.24,
					"scale_end": 0.42,
					"time_left": 0.24,
					"duration": 0.24,
					"delay": 0.11,
					"drift": Vector2(0, -4),
				})
		_trigger_shake(0.34)


func _trigger_shake(duration: float) -> void:
	if AppState.reduced_motion:
		return
	_shake_timer = maxf(_shake_timer, duration)
	_shake_strength = _shake_timer  # always sync so each shake starts at full intensity


func clear_transient_effects() -> void:
	_beam_effects.clear()
	_ring_effects.clear()
	_flash_effects.clear()
	_sprite_effects.clear()
	_floating_texts.clear()
	_tank_motion_overrides.clear()
	_tank_hit_reactions.clear()
	_tank_fadeouts.clear()
	_objective_tile_reactions.clear()
	_shake_timer = 0.0
	_shake_strength = 0.0
	_shake_offset = Vector2.ZERO
	queue_redraw()


func _effect_vec2(effect: Dictionary, key: String, default_value: Vector2) -> Vector2:
	var value: Variant = effect.get(key, default_value)
	if value is Vector2:
		return value
	return default_value


func _effect_color(effect: Dictionary, key: String, default_value: Color) -> Color:
	var value: Variant = effect.get(key, default_value)
	if value is Color:
		return value
	return default_value


func _effect_float(effect: Dictionary, key: String, default_value: float) -> float:
	var value: Variant = effect.get(key, default_value)
	return float(value)


func _effect_bool(effect: Dictionary, key: String, default_value: bool) -> bool:
	var value: Variant = effect.get(key, default_value)
	return bool(value)


func _effect_string(effect: Dictionary, key: String, default_value: String) -> String:
	var value: Variant = effect.get(key, default_value)
	return str(value)


func _buff_color(buff_type: int) -> Color:
	match buff_type:
		GameTypes.BuffType.ATTACK_MULTIPLIER:
			return Color("ff8c69")
		GameTypes.BuffType.SHIELD_BUFFER:
			return Color("7cc3ff")
		GameTypes.BuffType.BONUS_MOVE:
			return Color("69e59d")
		_:
			return Color.WHITE
