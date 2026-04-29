class_name ReplayAnalytics
extends RefCounted


static func build_summary(replay: ReplayRecord) -> Dictionary:
	var summary: Dictionary = {
		"winner_label": replay.winner_label if replay.winner_label != "" else "Pending",
		"map_name": str(replay.metadata.get("map_name", "Unknown Map")),
		"total_turns": replay.turns.size(),
		"player_damage": {1: 0, 2: 0},
		"pickups": {1: 0, 2: 0},
		"extra_actions": {1: 0, 2: 0},
		"tank_kills": {1: 0, 2: 0},
		"attack_actions": {1: 0, 2: 0},
		"move_actions": {1: 0, 2: 0},
		"pass_actions": {1: 0, 2: 0},
		"ai_time_ms": {1: [], 2: []},
		"win_reason": "Unfinished",
	}

	for turn_data: Dictionary in replay.turns:
		var player_id: int = int(turn_data.get("player", 0))
		var action_type: int = int(turn_data.get("action_type", -1))
		var metrics: Dictionary = turn_data.get("metrics", {})
		var events: Array = turn_data.get("event_data", [])

		match action_type:
			GameTypes.ActionType.MOVE:
				_increment_bucket(summary["move_actions"], player_id)
			GameTypes.ActionType.ATTACK:
				_increment_bucket(summary["attack_actions"], player_id)
			GameTypes.ActionType.PASS:
				_increment_bucket(summary["pass_actions"], player_id)
			_:
				pass

		if metrics.has("elapsed_ms"):
			var timing_bucket: Dictionary = summary["ai_time_ms"]
			var times: Array = timing_bucket.get(player_id, [])
			times.append(float(metrics.get("elapsed_ms", 0.0)))
			timing_bucket[player_id] = times

		for event_item: Dictionary in events:
			var event_name: String = str(event_item.get("event_name", ""))
			var payload: Dictionary = event_item.get("payload", {})
			match event_name:
				"hit_tank":
					_increment_bucket(summary["player_damage"], player_id, int(payload.get("damage", 0)))
				"power_up":
					_increment_bucket(summary["pickups"], player_id)
				"extra_action_granted":
					_increment_bucket(summary["extra_actions"], int(payload.get("player", player_id)))
				"tank_destroyed":
					_increment_bucket(summary["tank_kills"], player_id)
				"win_center":
					summary["win_reason"] = "Center Capture"
				"win_ktank_destroyed":
					summary["win_reason"] = "Enemy Ktank Destroyed"
				"draw_turn_limit":
					summary["win_reason"] = "Turn Limit Draw"
				"draw_repetition":
					summary["win_reason"] = "Repetition Draw"
				_:
					pass

	summary["avg_ai_time_ms"] = {
		1: _average_time(summary["ai_time_ms"].get(1, [])),
		2: _average_time(summary["ai_time_ms"].get(2, [])),
	}
	return summary


static func format_summary_text(summary: Dictionary) -> String:
	var damage_bucket: Dictionary = summary.get("player_damage", {})
	var pickup_bucket: Dictionary = summary.get("pickups", {})
	var extra_bucket: Dictionary = summary.get("extra_actions", {})
	var kill_bucket: Dictionary = summary.get("tank_kills", {})
	var avg_bucket: Dictionary = summary.get("avg_ai_time_ms", {})
	return "Winner: %s\nMap: %s\nWin Condition: %s\nTurns Recorded: %d\n\nP1 Damage: %d | Pickups: %d | Extra Actions: %d | Kills: %d\nP2 Damage: %d | Pickups: %d | Extra Actions: %d | Kills: %d\n\nP1 Avg Think Time: %.0f ms\nP2 Avg Think Time: %.0f ms" % [
		str(summary.get("winner_label", "Pending")),
		str(summary.get("map_name", "Unknown Map")),
		str(summary.get("win_reason", "Unfinished")),
		int(summary.get("total_turns", 0)),
		int(damage_bucket.get(1, 0)),
		int(pickup_bucket.get(1, 0)),
		int(extra_bucket.get(1, 0)),
		int(kill_bucket.get(1, 0)),
		int(damage_bucket.get(2, 0)),
		int(pickup_bucket.get(2, 0)),
		int(extra_bucket.get(2, 0)),
		int(kill_bucket.get(2, 0)),
		float(avg_bucket.get(1, 0.0)),
		float(avg_bucket.get(2, 0.0)),
	]


static func _increment_bucket(bucket: Dictionary, key: int, amount: int = 1) -> void:
	bucket[key] = int(bucket.get(key, 0)) + amount


static func _average_time(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: Variant in values:
		total += float(value)
	return total / float(values.size())
