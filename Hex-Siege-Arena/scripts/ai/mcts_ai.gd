class_name MctsAI
extends RefCounted

const WIN_SCORE := 100000.0
const ROLLOUT_DEPTH_LIMIT := 6


class SearchNode:
	extends RefCounted

	var state: GameState
	var parent: SearchNode
	var children: Array[SearchNode] = []
	var untried_actions: Array[ActionData] = []
	var incoming_action: ActionData
	var visits: int = 0
	var total_value: float = 0.0

	func _init(p_state: GameState, p_parent: SearchNode = null, p_action: ActionData = null) -> void:
		state = p_state
		parent = p_parent
		incoming_action = p_action
		untried_actions = _clone_actions(p_state.get_legal_actions())

	func has_untried_actions() -> bool:
		return not untried_actions.is_empty()

	func pop_untried_action(rng: RandomNumberGenerator) -> ActionData:
		var index: int = rng.randi_range(0, untried_actions.size() - 1)
		var action: ActionData = untried_actions[index]
		untried_actions.remove_at(index)
		return action

	static func _clone_actions(actions: Array[ActionData]) -> Array[ActionData]:
		var duplicates: Array[ActionData] = []
		for action: ActionData in actions:
			duplicates.append(action.clone())
		return duplicates


var _root_player: int = 1
var _time_deadline_ms: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _iterations: int = 0
var _rollouts: int = 0


func choose_action(state: GameState, config: AIConfig) -> Dictionary:
	_root_player = state.current_player
	_time_deadline_ms = Time.get_ticks_msec() + maxi(config.time_budget_ms, 1)
	_iterations = 0
	_rollouts = 0
	_rng.randomize()

	var root: SearchNode = SearchNode.new(state.clone())
	var root_actions: Array[ActionData] = root.untried_actions
	if root_actions.is_empty():
		var fallback_action: ActionData = ActionData.new(GameTypes.ActionType.PASS)
		return {
			"action": fallback_action,
			"explanation": _build_explanation(state, fallback_action, 0.0, 0.0, 0),
		}

	while _iterations < maxi(config.rollout_limit, 1) and not _time_exceeded():
		var leaf: SearchNode = _select(root)
		var expanded: SearchNode = _expand(leaf)
		var rollout_value: float = _simulate(expanded.state.clone())
		_backpropagate(expanded, rollout_value)
		_iterations += 1
		_rollouts += 1

	var best_child: SearchNode = _best_root_child(root)
	var chosen_action: ActionData = best_child.incoming_action.clone() if best_child != null else root_actions[0].clone()
	var average_score: float = 0.0
	var visits: int = 0
	if best_child != null and best_child.visits > 0:
		average_score = best_child.total_value / float(best_child.visits)
		visits = best_child.visits

	return {
		"action": chosen_action,
		"explanation": _build_explanation(state, chosen_action, average_score, float(maxi(config.time_budget_ms, 1) - maxi(_time_deadline_ms - Time.get_ticks_msec(), 0)), visits),
		"stats": {
			"iterations": _iterations,
			"rollouts": _rollouts,
			"selected_child_visits": visits,
			"average_score": average_score,
		},
	}


func _select(node: SearchNode) -> SearchNode:
	var current: SearchNode = node
	while not current.state.game_over and not current.has_untried_actions() and not current.children.is_empty():
		current = _best_uct_child(current)
	return current


func _expand(node: SearchNode) -> SearchNode:
	if node.state.game_over or not node.has_untried_actions():
		return node

	var action: ActionData = node.pop_untried_action(_rng)
	var child_state: GameState = node.state.simulate_action(action)
	var child: SearchNode = SearchNode.new(child_state, node, action.clone())
	node.children.append(child)
	return child


func _simulate(state: GameState) -> float:
	var rollout_depth: int = 0
	while not state.game_over and rollout_depth < ROLLOUT_DEPTH_LIMIT and not _time_exceeded():
		var actions: Array[ActionData] = state.get_legal_actions()
		if actions.is_empty():
			break
		var chosen_action: ActionData = _choose_rollout_action(state, actions)
		state.apply_action(chosen_action)
		rollout_depth += 1
	return _evaluate_rollout_state(state, rollout_depth)


func _backpropagate(node: SearchNode, rollout_value: float) -> void:
	var current: SearchNode = node
	while current != null:
		current.visits += 1
		current.total_value += rollout_value
		current = current.parent


func _best_uct_child(node: SearchNode) -> SearchNode:
	var best_child: SearchNode = node.children[0]
	var best_score: float = -INF
	for child: SearchNode in node.children:
		var exploitation: float = child.total_value / float(maxi(child.visits, 1))
		var exploration: float = sqrt(log(float(maxi(node.visits, 1))) / float(maxi(child.visits, 1)))
		var score: float = exploitation + 1.414 * exploration
		if score > best_score:
			best_score = score
			best_child = child
	return best_child


func _best_root_child(root: SearchNode) -> SearchNode:
	if root.children.is_empty():
		return null

	var best_child: SearchNode = root.children[0]
	var best_visits: int = -1
	var best_value: float = -INF
	for child: SearchNode in root.children:
		var value: float = child.total_value / float(maxi(child.visits, 1))
		if child.visits > best_visits or (child.visits == best_visits and value > best_value):
			best_visits = child.visits
			best_value = value
			best_child = child
	return best_child


func _choose_rollout_action(state: GameState, actions: Array[ActionData]) -> ActionData:
	var best_action: ActionData = actions[0]
	var best_score: float = -INF
	for action: ActionData in actions:
		var score: float = _rollout_action_score(state, action) + _rng.randf_range(0.0, 0.65)
		if score > best_score:
			best_score = score
			best_action = action
	return best_action.clone()


func _rollout_action_score(state: GameState, action: ActionData) -> float:
	if action.action_type == GameTypes.ActionType.PASS:
		return -20.0

	var tank: TankData = state.get_tank(action.actor_id)
	if tank == null:
		return -10.0

	var score: float = 0.0
	match action.action_type:
		GameTypes.ActionType.MOVE:
			if tank.tank_type == GameTypes.TankType.KTANK:
				score += 12.0 - float(action.target_coord.distance_to(HexCoord.new())) * 4.0
				if action.target_coord.q == 0 and action.target_coord.r == 0:
					score += 70.0
			else:
				score += 8.0 - float(action.target_coord.distance_to(HexCoord.new()))
			var cell: CellData = state.board.get_cell(action.target_coord)
			if cell != null:
				match cell.cell_type:
					GameTypes.CellType.POWER_ATTACK, GameTypes.CellType.POWER_SHIELD, GameTypes.CellType.POWER_BONUS_MOVE:
						score += 8.0
		GameTypes.ActionType.ATTACK:
			score += _attack_rollout_score(state, tank, action)
	return score


func _attack_rollout_score(state: GameState, tank: TankData, action: ActionData) -> float:
	var score: float = 6.0
	if tank.tank_type == GameTypes.TankType.QTANK:
		for step_coord: HexCoord in tank.position.raycast(action.direction, state.board.rings * 3):
			if not state.board.has_cell(step_coord):
				break

			var target_tank: TankData = state.get_tank_at(step_coord)
			if target_tank != null:
				if target_tank.owner_id != tank.owner_id:
					score += 40.0 if target_tank.tank_type == GameTypes.TankType.KTANK else 18.0
				else:
					score -= 18.0
				break

			if state.board.blocks_attack(step_coord):
				var cell: CellData = state.board.get_cell(step_coord)
				if cell != null and cell.cell_type == GameTypes.CellType.POWER_BLOCK:
					score += 10.0
				elif cell != null and cell.is_destructible():
					score += 4.0
				break
	else:
		for neighbor_coord: HexCoord in tank.position.neighbors():
			if not state.board.has_cell(neighbor_coord):
				continue
			var target_tank: TankData = state.get_tank_at(neighbor_coord)
			if target_tank == null:
				continue
			if target_tank.owner_id != tank.owner_id:
				score += 35.0 if target_tank.tank_type == GameTypes.TankType.KTANK else 15.0
			else:
				score -= 16.0
	return score


func _evaluate_rollout_state(state: GameState, rollout_depth: int) -> float:
	if state.game_over:
		if state.winner == _root_player:
			return WIN_SCORE - rollout_depth
		if state.winner == 0:
			return 0.0
		return -WIN_SCORE + rollout_depth

	var player_score: float = _position_score(state, _root_player)
	var enemy_score: float = _position_score(state, 2 if _root_player == 1 else 1)
	return player_score - enemy_score


func _position_score(state: GameState, player_id: int) -> float:
	var score: float = 0.0
	for tank: TankData in state.get_player_tanks(player_id):
		if tank.tank_type == GameTypes.TankType.KTANK:
			score += float(tank.hp) * 18.0
			score += maxf(0.0, 9.0 - float(tank.position.distance_to(HexCoord.new()))) * 3.5
		else:
			score += float(tank.hp) * 11.0

		match tank.active_buff:
			GameTypes.BuffType.ATTACK_MULTIPLIER:
				score += 6.0
			GameTypes.BuffType.SHIELD_BUFFER:
				score += 6.0 + float(tank.shield_hits_remaining)
			GameTypes.BuffType.BONUS_MOVE:
				score += 4.0
	return score


func _build_explanation(state: GameState, action: ActionData, score: float, elapsed_ms: float, visits: int) -> ActionExplanation:
	var actor_label: String = _actor_label(state, action.actor_id)
	var summary: String = "MCTS chose %s after %d iterations." % [_action_label(state, action), _iterations]
	var metrics: Dictionary = {
		"iterations": _iterations,
		"rollouts": _rollouts,
		"elapsed_ms": elapsed_ms,
		"selected_visits": visits,
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
