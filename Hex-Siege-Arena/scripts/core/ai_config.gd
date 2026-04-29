class_name AIConfig
extends Resource

var controller_type: int = GameTypes.ControllerType.HUMAN
var time_budget_ms: int = 650
var search_depth: int = 6
var rollout_limit: int = 80
var debug_enabled: bool = true


func clone() -> AIConfig:
	var duplicate := AIConfig.new()
	duplicate.controller_type = controller_type
	duplicate.time_budget_ms = time_budget_ms
	duplicate.search_depth = search_depth
	duplicate.rollout_limit = rollout_limit
	duplicate.debug_enabled = debug_enabled
	return duplicate


func to_snapshot() -> Dictionary:
	return {
		"controller_type": controller_type,
		"time_budget_ms": time_budget_ms,
		"search_depth": search_depth,
		"rollout_limit": rollout_limit,
		"debug_enabled": debug_enabled,
	}


static func from_snapshot(snapshot: Dictionary) -> AIConfig:
	var config := AIConfig.new()
	config.controller_type = int(snapshot.get("controller_type", GameTypes.ControllerType.HUMAN))
	config.time_budget_ms = int(snapshot.get("time_budget_ms", 650))
	config.search_depth = int(snapshot.get("search_depth", 6))
	config.rollout_limit = int(snapshot.get("rollout_limit", 80))
	config.debug_enabled = bool(snapshot.get("debug_enabled", true))
	return config
