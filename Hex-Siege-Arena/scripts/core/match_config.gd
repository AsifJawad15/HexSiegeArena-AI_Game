class_name MatchConfig
extends Resource

var board_rings: int = 5
var player_one_ai: AIConfig = AIConfig.new()
var player_two_ai: AIConfig = AIConfig.new()
var map_id: String = "standard"
var max_turns: int = 85
var ai_vs_ai_mode: bool = true


func _init() -> void:
	player_one_ai.controller_type = GameTypes.ControllerType.MINIMAX
	player_one_ai.search_depth = 6
	player_one_ai.rollout_limit = 80
	player_one_ai.time_budget_ms = 3800

	player_two_ai.controller_type = GameTypes.ControllerType.MCTS
	player_two_ai.search_depth = 6
	player_two_ai.rollout_limit = 80
	player_two_ai.time_budget_ms = 650


func clone() -> MatchConfig:
	var duplicate := MatchConfig.new()
	duplicate.board_rings = board_rings
	duplicate.player_one_ai = player_one_ai.clone()
	duplicate.player_two_ai = player_two_ai.clone()
	duplicate.map_id = map_id
	duplicate.max_turns = max_turns
	duplicate.ai_vs_ai_mode = ai_vs_ai_mode
	return duplicate


func to_snapshot() -> Dictionary:
	return {
		"board_rings": board_rings,
		"player_one_ai": player_one_ai.to_snapshot(),
		"player_two_ai": player_two_ai.to_snapshot(),
		"map_id": map_id,
		"max_turns": max_turns,
		"ai_vs_ai_mode": ai_vs_ai_mode,
	}


static func from_snapshot(snapshot: Dictionary) -> MatchConfig:
	var config := MatchConfig.new()
	config.board_rings = int(snapshot.get("board_rings", 5))
	config.player_one_ai = AIConfig.from_snapshot(snapshot.get("player_one_ai", {}))
	config.player_two_ai = AIConfig.from_snapshot(snapshot.get("player_two_ai", {}))
	config.map_id = str(snapshot.get("map_id", "standard"))
	config.max_turns = int(snapshot.get("max_turns", 85))
	config.ai_vs_ai_mode = bool(snapshot.get("ai_vs_ai_mode", true))
	return config
