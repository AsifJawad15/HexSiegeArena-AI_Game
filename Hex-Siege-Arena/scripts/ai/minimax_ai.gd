class_name MinimaxAI
extends RefCounted

const WIN_SCORE := 100000.0
const WEIGHT_KTANK_HP := 32.0
const WEIGHT_QTANK_HP := 17.0
const WEIGHT_KTANK_DISTANCE := 7.5
const WEIGHT_QTANK_DISTANCE := 1.0
const WEIGHT_ATTACK_BUFF := 8.0
const WEIGHT_SHIELD := 7.0
const WEIGHT_BONUS_MOVE := 5.0
const WEIGHT_MOBILITY := 1.7
const WEIGHT_KTANK_DANGER := 28.0
const WEIGHT_QTANK_DANGER := 9.0
const WEIGHT_OBJECTIVE_PRESSURE := 16.0

var _root_player: int = 1
var _time_deadline_ms: int = 0
var _nodes_searched: int = 0
var _transposition: Dictionary = {}


func choose_action(state: GameState, config: AIConfig) -> Dictionary:
	_root_player = state.current_player
	_nodes_searched = 0
	_transposition.clear()
	_time_deadline_ms = Time.get_ticks_msec() + maxi(config.time_budget_ms, 1)

	var legal_actions: Array[ActionData] = state.get_legal_actions()
	if legal_actions.is_empty():
		var fallback_action: ActionData = ActionData.new(GameTypes.ActionType.PASS)
		return {
			"action": fallback_action,
			"explanation": _build_explanation(state, fallback_action, 0.0, 0, 0.0, legal_actions.size()),
		}

	var best_action: ActionData = legal_actions[0].clone()
	var best_score: float = -INF
	var best_depth: int = 0
	var completed_depth: int = 0

	for depth: int in range(1, maxi(config.search_depth, 1) + 1):
		if _time_exceeded():
			break

		var search_result: Dictionary = _search_root(state, depth)
		if search_result.get("timed_out", false):
			break

		var depth_action: ActionData = search_result.get("action", best_action)
		if depth_action != null:
			best_action = (depth_action as ActionData).clone()
		best_score = search_result.get("score", best_score)
		best_depth = depth
		completed_depth = depth

	var elapsed_ms: float = float(maxi(config.time_budget_ms, 1) - maxi(_time_deadline_ms - Time.get_ticks_msec(), 0))
	return {
		"action": best_action,
		"explanation": _build_explanation(state, best_action, best_score, best_depth, elapsed_ms, legal_actions.size()),
		"stats": {
			"nodes": _nodes_searched,
			"depth_completed": completed_depth,
			"score": best_score,
			"candidate_count": legal_actions.size(),
		},
	}


func _search_root(state: GameState, depth: int) -> Dictionary:
	var ordered_actions: Array[ActionData] = _ordered_actions(state, state.get_legal_actions())
	var best_action: ActionData = ordered_actions[0]
	var best_score: float = -INF
	var alpha: float = -INF
	var beta: float = INF

	for action: ActionData in ordered_actions:
		if _time_exceeded():
			return {"timed_out": true}

		var next_state: GameState = state.simulate_action(action)
		var score: float = _minimax(next_state, depth - 1, alpha, beta)
		if score > best_score:
			best_score = score
			best_action = action
		alpha = maxf(alpha, best_score)

	return {
		"timed_out": false,
		"action": best_action,
		"score": best_score,
	}


func _minimax(state: GameState, depth: int, alpha: float, beta: float) -> float:
	_nodes_searched += 1
	if _time_exceeded():
		return _evaluate_state(state, depth)

	if state.game_over or depth <= 0:
		return _evaluate_state(state, depth)

	var state_key: String = "%s|%d" % [state.get_state_hash(), depth]
	if _transposition.has(state_key):
		return _transposition[state_key]

	var maximizing: bool = state.current_player == _root_player
	var ordered_actions: Array[ActionData] = _ordered_actions(state, state.get_legal_actions())
	if ordered_actions.is_empty():
		return _evaluate_state(state, depth)

	var best_score: float = -INF if maximizing else INF
	for action: ActionData in ordered_actions:
		var next_state: GameState = state.simulate_action(action)
		var score: float = _minimax(next_state, depth - 1, alpha, beta)

		if maximizing:
			best_score = maxf(best_score, score)
			alpha = maxf(alpha, best_score)
		else:
			best_score = minf(best_score, score)
			beta = minf(beta, best_score)

		if beta <= alpha:
			break

	_transposition[state_key] = best_score
	return best_score


func _evaluate_state(state: GameState, depth_remaining: int) -> float:
	if state.game_over:
		if state.winner == _root_player:
			return WIN_SCORE + depth_remaining
		if state.winner == 0:
			return 0.0
		return -WIN_SCORE - depth_remaining

	var player_tanks: Array[TankData] = state.get_player_tanks(_root_player)
	var enemy_player: int = 2 if _root_player == 1 else 1
	var enemy_tanks: Array[TankData] = state.get_player_tanks(enemy_player)

	var score: float = 0.0
	score += _evaluate_tank_group(player_tanks, true)
	score -= _evaluate_tank_group(enemy_tanks, false)
	score += _center_control_bonus(state, _root_player)
	score -= _center_control_bonus(state, enemy_player)
	score += _threat_bonus(state, _root_player)
	score -= _threat_bonus(state, enemy_player)
	score += _mobility_bonus(state, _root_player)
	score -= _mobility_bonus(state, enemy_player)
	score -= _danger_penalty(state, _root_player)
	score += _danger_penalty(state, enemy_player)
	return score


func _evaluate_tank_group(tanks: Array[TankData], prefer_center: bool) -> float:
	var score: float = 0.0
	for tank: TankData in tanks:
		if not tank.is_alive():
			continue

		if tank.tank_type == GameTypes.TankType.KTANK:
			score += tank.hp * WEIGHT_KTANK_HP
			score -= tank.position.distance_to(HexCoord.new()) * WEIGHT_KTANK_DISTANCE
		else:
			score += tank.hp * WEIGHT_QTANK_HP
			score -= tank.position.distance_to(HexCoord.new()) * WEIGHT_QTANK_DISTANCE

		match tank.active_buff:
			GameTypes.BuffType.ATTACK_MULTIPLIER:
				score += WEIGHT_ATTACK_BUFF
			GameTypes.BuffType.SHIELD_BUFFER:
				score += WEIGHT_SHIELD + float(tank.shield_hits_remaining)
			GameTypes.BuffType.BONUS_MOVE:
				score += WEIGHT_BONUS_MOVE

		if prefer_center and tank.tank_type == GameTypes.TankType.KTANK and tank.position.q == 0 and tank.position.r == 0:
			score += 45.0

	return score


func _center_control_bonus(state: GameState, player_id: int) -> float:
	var score: float = 0.0
	for tank: TankData in state.get_player_tanks(player_id):
		if tank.tank_type != GameTypes.TankType.KTANK:
			continue
		score += maxf(0.0, 10.0 - float(tank.position.distance_to(HexCoord.new()))) * 4.0
	return score


func _threat_bonus(state: GameState, player_id: int) -> float:
	var score: float = 0.0
	for tank: TankData in state.get_player_tanks(player_id):
		var actions: Array[HexCoord] = _attack_targets_for_tank(state, tank)
		for target_coord: HexCoord in actions:
			var target_tank: TankData = state.get_tank_at(target_coord)
			if target_tank == null or target_tank.owner_id == player_id:
				continue
			score += 14.0 if target_tank.tank_type == GameTypes.TankType.KTANK else 5.0
	return score


func _mobility_bonus(state: GameState, player_id: int) -> float:
	var score: float = 0.0
	var previous_player: int = state.current_player
	state.current_player = player_id
	for tank: TankData in state.get_player_tanks(player_id):
		var mobility: int = state.get_legal_move_targets(tank.actor_id()).size()
		score += float(mobility) * WEIGHT_MOBILITY
		if tank.tank_type == GameTypes.TankType.KTANK:
			score += maxf(0.0, 10.0 - float(tank.position.distance_to(HexCoord.new()))) * WEIGHT_OBJECTIVE_PRESSURE
	state.current_player = previous_player
	return score


func _danger_penalty(state: GameState, player_id: int) -> float:
	var enemy_player: int = 2 if player_id == 1 else 1
	var penalty: float = 0.0
	for enemy_tank: TankData in state.get_player_tanks(enemy_player):
		for target_coord: HexCoord in _attack_targets_for_tank(state, enemy_tank):
			var target_tank: TankData = state.get_tank_at(target_coord)
			if target_tank == null or target_tank.owner_id != player_id:
				continue
			if target_tank.tank_type == GameTypes.TankType.KTANK:
				penalty += WEIGHT_KTANK_DANGER
			else:
				penalty += WEIGHT_QTANK_DANGER
	return penalty


func _attack_targets_for_tank(state: GameState, tank: TankData) -> Array[HexCoord]:
	var results: Array[HexCoord] = []
	if tank.tank_type == GameTypes.TankType.QTANK:
		for direction in range(HexCoord.DIRECTIONS.size()):
			for step_coord: HexCoord in tank.position.raycast(direction, state.board.rings * 3):
				if not state.board.has_cell(step_coord):
					break
				results.append(step_coord)
				if state.is_cell_occupied(step_coord) or state.board.blocks_attack(step_coord):
					break
	else:
		for neighbor_coord: HexCoord in tank.position.neighbors():
			if state.board.has_cell(neighbor_coord):
				results.append(neighbor_coord)
	return results


func _ordered_actions(state: GameState, actions: Array[ActionData]) -> Array[ActionData]:
	var scored_entries: Array[Dictionary] = []
	for action: ActionData in actions:
		scored_entries.append({
			"action": action,
			"score": _action_priority(state, action),
		})

	scored_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	var ordered: Array[ActionData] = []
	for entry: Dictionary in scored_entries:
		ordered.append(entry["action"] as ActionData)
	return ordered


func _action_priority(state: GameState, action: ActionData) -> float:
	if action.action_type == GameTypes.ActionType.PASS:
		return -100.0

	var tank: TankData = state.get_tank(action.actor_id)
	if tank == null:
		return -50.0

	var score: float = 0.0
	match action.action_type:
		GameTypes.ActionType.MOVE:
			if tank.tank_type == GameTypes.TankType.KTANK:
				score += 18.0 - float(action.target_coord.distance_to(HexCoord.new())) * 5.0
				if action.target_coord.q == 0 and action.target_coord.r == 0:
					score += 200.0
			else:
				score += 10.0 - float(action.target_coord.distance_to(HexCoord.new()))

			var target_cell: CellData = state.board.get_cell(action.target_coord)
			if target_cell != null:
				match target_cell.cell_type:
					GameTypes.CellType.POWER_ATTACK, GameTypes.CellType.POWER_SHIELD, GameTypes.CellType.POWER_BONUS_MOVE:
						score += 24.0
		GameTypes.ActionType.ATTACK:
			score += 28.0
			score += _attack_priority_bonus(state, tank, action)

	return score


func _attack_priority_bonus(state: GameState, tank: TankData, action: ActionData) -> float:
	var score: float = 0.0
	if tank.tank_type == GameTypes.TankType.QTANK:
		for step_coord: HexCoord in tank.position.raycast(action.direction, state.board.rings * 3):
			if not state.board.has_cell(step_coord):
				break

			var target_tank: TankData = state.get_tank_at(step_coord)
			if target_tank != null:
				score += 40.0 if target_tank.owner_id != tank.owner_id and target_tank.tank_type == GameTypes.TankType.KTANK else 18.0
				if target_tank.owner_id == tank.owner_id:
					score -= 35.0
				break

			if state.board.blocks_attack(step_coord):
				var cell: CellData = state.board.get_cell(step_coord)
				if cell != null and cell.cell_type == GameTypes.CellType.POWER_BLOCK:
					score += 8.0
				elif cell != null and cell.is_destructible():
					score += 4.0
				break
	else:
		for neighbor_coord: HexCoord in tank.position.neighbors():
			if not state.board.has_cell(neighbor_coord):
				continue
			var target_tank: TankData = state.get_tank_at(neighbor_coord)
			if target_tank != null:
				if target_tank.owner_id != tank.owner_id:
					score += 36.0 if target_tank.tank_type == GameTypes.TankType.KTANK else 18.0
				else:
					score -= 20.0
	return score


func _build_explanation(state: GameState, action: ActionData, score: float, depth: int, elapsed_ms: float, candidate_count: int) -> ActionExplanation:
	var actor_label: String = _actor_label(state, action.actor_id)
	var summary: String = "Minimax chose %s after depth %d search." % [_action_label(state, action), depth]
	var metrics: Dictionary = {
		"depth_completed": depth,
		"nodes_searched": _nodes_searched,
		"elapsed_ms": elapsed_ms,
		"candidate_count": candidate_count,
		"current_player": _root_player,
	}
	return ActionExplanation.new(actor_label, summary, score, metrics)


func _actor_label(state: GameState, actor_id: String) -> String:
	var tank: TankData = state.get_tank(actor_id)
	if tank == null:
		return actor_id
	var tank_name: String = "Qtank" if tank.tank_type == GameTypes.TankType.QTANK else "Ktank"
	return "P%d %s" % [tank.owner_id, tank_name]


func _action_label(state: GameState, action: ActionData) -> String:
	match action.action_type:
		GameTypes.ActionType.PASS:
			return "Pass"
		GameTypes.ActionType.MOVE:
			return "%s to %s" % [_actor_label(state, action.actor_id), action.target_coord.key()]
		GameTypes.ActionType.ATTACK:
			return "%s attack" % _actor_label(state, action.actor_id)
		_:
			return "Unknown action"


func _time_exceeded() -> bool:
	return Time.get_ticks_msec() >= _time_deadline_ms
