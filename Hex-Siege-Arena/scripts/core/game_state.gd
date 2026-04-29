class_name GameState
extends Resource

var board: BoardState
var tanks: Dictionary = {}
var current_player: int = 1
var winner: int = 0
var game_over: bool = false
var turn_count: int = 1
var actions_remaining_in_turn: int = 1
var max_turns: int = 80
var last_events: Array[GameEvent] = []
var repetition_counts: Dictionary = {}
var map_preset: MapPreset


func _init(config: MatchConfig = null) -> void:
	var match_config: MatchConfig = config if config != null else MatchConfig.new()
	map_preset = MapLibrary.get_preset(match_config.map_id)
	board = BoardState.new(map_preset.rings)
	board.load_map_preset(map_preset)
	max_turns = match_config.max_turns
	_setup_tanks_from_preset()
	_register_state_hash()


func _setup_tanks_from_preset() -> void:
	tanks.clear()
	_add_tank(TankData.create_default_qtank(1, _spawn_coord_for(1, GameTypes.TankType.QTANK)))
	_add_tank(TankData.create_default_ktank(1, _spawn_coord_for(1, GameTypes.TankType.KTANK)))
	_add_tank(TankData.create_default_qtank(2, _spawn_coord_for(2, GameTypes.TankType.QTANK)))
	_add_tank(TankData.create_default_ktank(2, _spawn_coord_for(2, GameTypes.TankType.KTANK)))


func _add_tank(tank: TankData) -> void:
	tanks[tank.actor_id()] = tank


func _spawn_coord_for(player_id: int, tank_type: int) -> HexCoord:
	var spawn_coord: HexCoord = map_preset.get_spawn_coord(player_id, tank_type)
	if spawn_coord != null:
		return spawn_coord
	if player_id == 1:
		return HexCoord.new(-5, 5) if tank_type == GameTypes.TankType.QTANK else HexCoord.new(0, 5)
	return HexCoord.new(5, -5) if tank_type == GameTypes.TankType.QTANK else HexCoord.new(0, -5)


func clone() -> GameState:
	var duplicate: GameState = GameState.new()
	duplicate.board = board.clone()
	duplicate.map_preset = map_preset
	duplicate.tanks.clear()
	for actor_id: String in tanks.keys():
		duplicate.tanks[actor_id] = (tanks[actor_id] as TankData).clone()
	duplicate.current_player = current_player
	duplicate.winner = winner
	duplicate.game_over = game_over
	duplicate.turn_count = turn_count
	duplicate.actions_remaining_in_turn = actions_remaining_in_turn
	duplicate.max_turns = max_turns
	duplicate.last_events = []
	for event_item: GameEvent in last_events:
		duplicate.last_events.append(GameEvent.new(event_item.event_name, event_item.payload))
	duplicate.repetition_counts = repetition_counts.duplicate(true)
	return duplicate


func to_snapshot() -> Dictionary:
	var tank_entries: Array[Dictionary] = []
	for tank: TankData in get_all_tanks():
		tank_entries.append(tank.to_snapshot())
	return {
		"board": board.to_snapshot(),
		"map_id": board.map_id,
		"current_player": current_player,
		"winner": winner,
		"game_over": game_over,
		"turn_count": turn_count,
		"actions_remaining_in_turn": actions_remaining_in_turn,
		"max_turns": max_turns,
		"repetition_counts": repetition_counts.duplicate(true),
		"tanks": tank_entries,
	}


static func from_snapshot(snapshot: Dictionary) -> GameState:
	var restored := GameState.new()
	restored.board = BoardState.from_snapshot(snapshot.get("board", {}))
	restored.map_preset = MapLibrary.get_preset(str(snapshot.get("map_id", restored.board.map_id)))
	restored.tanks.clear()
	for tank_snapshot: Variant in snapshot.get("tanks", []):
		if tank_snapshot is Dictionary:
			var restored_tank: TankData = TankData.from_snapshot(tank_snapshot)
			restored.tanks[restored_tank.actor_id()] = restored_tank
	restored.current_player = int(snapshot.get("current_player", 1))
	restored.winner = int(snapshot.get("winner", 0))
	restored.game_over = bool(snapshot.get("game_over", false))
	restored.turn_count = int(snapshot.get("turn_count", 1))
	restored.actions_remaining_in_turn = int(snapshot.get("actions_remaining_in_turn", 1))
	restored.max_turns = int(snapshot.get("max_turns", 80))
	restored.last_events = []
	restored.repetition_counts = (snapshot.get("repetition_counts", {}) as Dictionary).duplicate(true)
	return restored


func get_tank(actor_id: String) -> TankData:
	return tanks.get(actor_id)


func get_all_tanks() -> Array[TankData]:
	var results: Array[TankData] = []
	for tank: TankData in tanks.values():
		results.append(tank)
	return results


func get_player_tanks(player_id: int) -> Array[TankData]:
	var results: Array[TankData] = []
	for tank: TankData in get_all_tanks():
		if tank.owner_id == player_id and tank.is_alive():
			results.append(tank)
	return results


func get_tank_at(coord: HexCoord) -> TankData:
	for tank: TankData in get_all_tanks():
		if tank.is_alive() and tank.position.equals(coord):
			return tank
	return null


func is_cell_occupied(coord: HexCoord) -> bool:
	return get_tank_at(coord) != null


func get_legal_move_targets(actor_id: String) -> Array[HexCoord]:
	var tank: TankData = get_tank(actor_id)
	var results: Array[HexCoord] = []
	if tank == null or not tank.is_alive() or tank.owner_id != current_player or game_over:
		return results

	for direction in range(HexCoord.DIRECTIONS.size()):
		var path: Array[HexCoord] = tank.position.raycast(direction, tank.get_move_range())
		for step_coord: HexCoord in path:
			if not board.has_cell(step_coord):
				break
			if not board.is_walkable(step_coord):
				break
			if is_cell_occupied(step_coord):
				break
			results.append(step_coord)
			if tank.tank_type == GameTypes.TankType.KTANK and tank.position.distance_to(step_coord) >= tank.get_move_range():
				break
	return results


func get_legal_attack_targets(actor_id: String) -> Array[HexCoord]:
	var tank: TankData = get_tank(actor_id)
	var results: Array[HexCoord] = []
	if tank == null or not tank.is_alive() or tank.owner_id != current_player or game_over:
		return results

	if tank.tank_type == GameTypes.TankType.QTANK:
		for direction in range(HexCoord.DIRECTIONS.size()):
			for step_coord: HexCoord in tank.position.raycast(direction, board.rings * 3):
				if not board.has_cell(step_coord):
					break
				var occupant: TankData = get_tank_at(step_coord)
				if occupant != null:
					if occupant.owner_id != tank.owner_id:
						results.append(step_coord)  # valid enemy target
					break  # always stop ray at any occupied cell
				if board.blocks_attack(step_coord):
					results.append(step_coord)
					break
				results.append(step_coord)
	else:
		for neighbor_coord: HexCoord in tank.position.neighbors():
			if board.has_cell(neighbor_coord):
				var occupant: TankData = get_tank_at(neighbor_coord)
				if occupant == null or occupant.owner_id != tank.owner_id:
					results.append(neighbor_coord)  # empty or enemy cell only
	return results


func get_legal_actions(player_id: int = -1) -> Array[ActionData]:
	var actor_player: int = current_player if player_id == -1 else player_id
	var actions: Array[ActionData] = []
	if game_over:
		return actions

	for tank: TankData in get_player_tanks(actor_player):
		for target: HexCoord in get_legal_move_targets(tank.actor_id()):
			actions.append(ActionData.new(GameTypes.ActionType.MOVE, tank.actor_id(), target))

		if tank.tank_type == GameTypes.TankType.QTANK:
			for direction in range(HexCoord.DIRECTIONS.size()):
				actions.append(ActionData.new(GameTypes.ActionType.ATTACK, tank.actor_id(), tank.position.clone(), direction))
		else:
			actions.append(ActionData.new(GameTypes.ActionType.ATTACK, tank.actor_id(), tank.position.clone()))

	actions.append(ActionData.new(GameTypes.ActionType.PASS, ""))
	return actions


func get_state_hash() -> String:
	return _state_hash()


func get_ai_config_for_player(player_id: int) -> AIConfig:
	if player_id == 1:
		return AppState.current_match_config.player_one_ai
	return AppState.current_match_config.player_two_ai


func simulate_action(action: ActionData) -> GameState:
	var duplicate: GameState = clone()
	duplicate.apply_action(action.clone())
	return duplicate


func build_attack_action(actor_id: String, clicked_coord: HexCoord) -> ActionData:
	var tank: TankData = get_tank(actor_id)
	if tank == null:
		return null

	if tank.tank_type == GameTypes.TankType.KTANK:
		if tank.position.distance_to(clicked_coord) == 1:
			return ActionData.new(GameTypes.ActionType.ATTACK, actor_id, clicked_coord.clone())
		return null

	for direction in range(HexCoord.DIRECTIONS.size()):
		for step_coord: HexCoord in tank.position.raycast(direction, board.rings * 3):
			if not board.has_cell(step_coord):
				break
			if step_coord.equals(clicked_coord):
				return ActionData.new(GameTypes.ActionType.ATTACK, actor_id, clicked_coord.clone(), direction)
			if is_cell_occupied(step_coord) or board.blocks_attack(step_coord):
				break
	return null


func apply_action(action: ActionData) -> Array[GameEvent]:
	last_events.clear()
	if game_over:
		return last_events

	if action.action_type == GameTypes.ActionType.PASS:
		_add_event("pass", {"player": current_player})
		_consume_action_and_progress(false)
		return last_events

	var tank: TankData = get_tank(action.actor_id)
	if tank == null or not tank.is_alive() or tank.owner_id != current_player:
		_add_event("invalid_action", {"reason": "invalid actor", "actor_id": action.actor_id})
		return last_events

	var gained_bonus_action: bool = false
	match action.action_type:
		GameTypes.ActionType.MOVE:
			gained_bonus_action = _apply_move(tank, action)
		GameTypes.ActionType.ATTACK:
			_apply_attack(tank, action)
		_:
			_add_event("invalid_action", {"reason": "unsupported action"})
			return last_events

	_consume_action_and_progress(gained_bonus_action)
	return last_events


func _apply_move(tank: TankData, action: ActionData) -> bool:
	var valid: bool = false
	for target: HexCoord in get_legal_move_targets(tank.actor_id()):
		if target.equals(action.target_coord):
			valid = true
			break
	if not valid:
		_add_event("invalid_action", {"reason": "illegal move", "actor_id": tank.actor_id()})
		return false

	var move_vector: Vector2 = action.target_coord.to_world_flat(1.0) - tank.position.to_world_flat(1.0)
	if move_vector.length() > 0.001:
		tank.facing_angle = move_vector.angle()
	var from_key: String = tank.position.key()
	tank.position = action.target_coord.clone()
	_add_event("move", {"actor_id": tank.actor_id(), "from": from_key, "to": tank.position.key()})

	var cell: CellData = board.get_cell(tank.position)
	var gained_bonus: bool = false
	if cell != null:
		match cell.cell_type:
			GameTypes.CellType.POWER_ATTACK:
				tank.apply_buff(GameTypes.BuffType.ATTACK_MULTIPLIER)
				board.set_cell_type(tank.position, GameTypes.CellType.EMPTY)
				_add_event("power_up", {"actor_id": tank.actor_id(), "buff": "attack_multiplier"})
			GameTypes.CellType.POWER_SHIELD:
				tank.apply_buff(GameTypes.BuffType.SHIELD_BUFFER)
				board.set_cell_type(tank.position, GameTypes.CellType.EMPTY)
				_add_event("power_up", {"actor_id": tank.actor_id(), "buff": "shield_buffer"})
			GameTypes.CellType.POWER_BONUS_MOVE:
				tank.apply_buff(GameTypes.BuffType.BONUS_MOVE)
				board.set_cell_type(tank.position, GameTypes.CellType.EMPTY)
				gained_bonus = true
				_add_event("power_up", {"actor_id": tank.actor_id(), "buff": "bonus_move"})

	if tank.tank_type == GameTypes.TankType.KTANK and tank.position.q == 0 and tank.position.r == 0:
		winner = tank.owner_id
		game_over = true
		_add_event("win_center", {"winner": winner})

	return gained_bonus


func _apply_attack(tank: TankData, action: ActionData) -> void:
	match tank.tank_type:
		GameTypes.TankType.QTANK:
			_apply_qtank_attack(tank, action.direction)
		GameTypes.TankType.KTANK:
			_apply_ktank_attack(tank)
	tank.consume_attack_buff_if_needed()
	if tank.active_buff == GameTypes.BuffType.BONUS_MOVE:
		tank.active_buff = GameTypes.BuffType.NONE


func _apply_qtank_attack(tank: TankData, direction: int) -> void:
	if direction < 0:
		_add_event("invalid_action", {"reason": "missing direction", "actor_id": tank.actor_id()})
		return

	var aim_target: HexCoord = tank.position.neighbor(direction)
	var aim_vector: Vector2 = aim_target.to_world_flat(1.0) - tank.position.to_world_flat(1.0)
	if aim_vector.length() > 0.001:
		tank.facing_angle = aim_vector.angle()
	var damage: int = tank.get_attack_damage()
	_add_event("attack", {"actor_id": tank.actor_id(), "mode": "laser", "direction": direction, "damage": damage})
	for step_coord: HexCoord in tank.position.raycast(direction, board.rings * 3):
		if not board.has_cell(step_coord):
			break
		var target_tank: TankData = get_tank_at(step_coord)
		if target_tank != null:
			if target_tank.owner_id == tank.owner_id:
				break  # stop ray at allied unit without dealing damage
			var applied: int = target_tank.take_damage(damage)
			_add_event("hit_tank", {"target": target_tank.actor_id(), "damage": applied, "coord": step_coord.key()})
			_check_tank_elimination(target_tank, tank.owner_id)
			break

		if board.blocks_attack(step_coord):
			var result: Dictionary = board.apply_damage(step_coord, damage)
			_add_event("hit_cell", {"coord": step_coord.key(), "damage": damage, "destroyed": result["destroyed"], "revealed_type": result["revealed_type"]})
			break

	_add_event("attack_resolved", {"actor_id": tank.actor_id()})


func _apply_ktank_attack(tank: TankData) -> void:
	var damage: int = tank.get_attack_damage()
	_add_event("attack", {"actor_id": tank.actor_id(), "mode": "blast", "damage": damage})
	for neighbor_coord: HexCoord in tank.position.neighbors():
		if not board.has_cell(neighbor_coord):
			continue
		var target_tank: TankData = get_tank_at(neighbor_coord)
		if target_tank != null:
			if target_tank.owner_id == tank.owner_id:
				continue  # skip allied tanks
			var applied: int = target_tank.take_damage(damage)
			_add_event("hit_tank", {"target": target_tank.actor_id(), "damage": applied, "coord": neighbor_coord.key()})
			_check_tank_elimination(target_tank, tank.owner_id)

		var cell: CellData = board.get_cell(neighbor_coord)
		if cell != null and cell.is_destructible():
			var result: Dictionary = board.apply_damage(neighbor_coord, damage)
			_add_event("hit_cell", {"coord": neighbor_coord.key(), "damage": damage, "destroyed": result["destroyed"], "revealed_type": result["revealed_type"]})

	_add_event("attack_resolved", {"actor_id": tank.actor_id()})


func _check_tank_elimination(tank: TankData, attacking_player: int) -> void:
	if tank.hp > 0:
		return
	_add_event("tank_destroyed", {"target": tank.actor_id()})
	if tank.tank_type == GameTypes.TankType.KTANK:
		winner = attacking_player
		game_over = true
		_add_event("win_ktank_destroyed", {"winner": winner})


func _consume_action_and_progress(gained_bonus_action: bool) -> void:
	actions_remaining_in_turn -= 1
	if gained_bonus_action:
		actions_remaining_in_turn += 1
		_clear_bonus_move_buffs_for_player(current_player)

	if game_over:
		return

	if actions_remaining_in_turn > 0:
		_add_event("extra_action_granted", {"player": current_player, "remaining": actions_remaining_in_turn})
		return

	_end_turn()


func _end_turn() -> void:
	_clear_bonus_move_buffs_for_player(current_player)
	current_player = 2 if current_player == 1 else 1
	turn_count += 1
	actions_remaining_in_turn = 1
	_register_state_hash()

	if turn_count > max_turns:
		game_over = true
		winner = 0
		_add_event("draw_turn_limit", {"turn_count": turn_count})
		return

	var hash_key: String = _state_hash()
	if repetition_counts.get(hash_key, 0) >= 3:
		game_over = true
		winner = 0
		_add_event("draw_repetition", {"state_hash": hash_key})


func _register_state_hash() -> void:
	var hash_key: String = _state_hash()
	repetition_counts[hash_key] = repetition_counts.get(hash_key, 0) + 1


func _state_hash() -> String:
	var tank_parts: Array[String] = []
	var tank_ids: Array[String] = []
	for actor_id: String in tanks.keys():
		tank_ids.append(actor_id)
	tank_ids.sort()
	for actor_id: String in tank_ids:
		var tank: TankData = tanks[actor_id] as TankData
		tank_parts.append("%s:%s:%d:%d:%d" % [actor_id, tank.position.key(), tank.hp, tank.active_buff, tank.shield_hits_remaining])

	var cell_parts: Array[String] = []
	for cell: CellData in board.all_cells():
		if cell.cell_type != GameTypes.CellType.EMPTY:
			cell_parts.append("%s:%d:%d" % [cell.coord.key(), cell.cell_type, cell.hp])
	cell_parts.sort()

	return "%d|%d|%s|%s" % [current_player, actions_remaining_in_turn, ",".join(tank_parts), ",".join(cell_parts)]


func _add_event(event_name: String, payload: Dictionary) -> void:
	last_events.append(GameEvent.new(event_name, payload))


func _clear_bonus_move_buffs_for_player(player_id: int) -> void:
	for tank: TankData in get_player_tanks(player_id):
		if tank.active_buff == GameTypes.BuffType.BONUS_MOVE:
			tank.active_buff = GameTypes.BuffType.NONE
