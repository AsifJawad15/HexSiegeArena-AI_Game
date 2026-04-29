class_name MapLibrary
extends RefCounted


static func get_preset(map_id: String) -> MapPreset:
	match map_id:
		"labyrinth":
			return _build_labyrinth_preset()
		"open":
			return _build_open_preset()
		"fortress":
			return _build_fortress_preset()
		_:
			return _build_standard_preset()


static func _build_standard_preset() -> MapPreset:
	var spawns: Dictionary = {
		1: {
			GameTypes.TankType.QTANK: "-5,5",
			GameTypes.TankType.KTANK: "0,5",
		},
		2: {
			GameTypes.TankType.QTANK: "5,-5",
			GameTypes.TankType.KTANK: "0,-5",
		},
	}
	var terrain_entries: Array[Dictionary] = _build_random_buried_terrain(spawns, 6)
	return MapPreset.new(
		"standard",
		"Buried Front",
		"Randomly distributes 70-75 destructible objects while always burying every spawn and sealing the center objective.",
		6,
		terrain_entries,
		spawns
	)


static func _build_open_preset() -> MapPreset:
	var terrain_entries: Array[Dictionary] = [
		_entry("-1,1", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_ATTACK),
		_entry("1,-1", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_SHIELD),
		_entry("0,2", GameTypes.CellType.POWER_BONUS_MOVE),
		_entry("0,-2", GameTypes.CellType.POWER_BONUS_MOVE),
	]
	var spawns: Dictionary = {
		1: {
			GameTypes.TankType.QTANK: "-5,5",
			GameTypes.TankType.KTANK: "-1,5",
		},
		2: {
			GameTypes.TankType.QTANK: "5,-5",
			GameTypes.TankType.KTANK: "1,-5",
		},
	}
	return MapPreset.new(
		"open",
		"Open Arena",
		"Low-obstacle test map for AI benchmarking and movement-heavy matches.",
		5,
		terrain_entries,
		spawns
	)


static func _build_fortress_preset() -> MapPreset:
	var terrain_entries: Array[Dictionary] = [
		_entry("-2,0", GameTypes.CellType.WALL),
		_entry("-1,0", GameTypes.CellType.BLOCK),
		_entry("-1,1", GameTypes.CellType.ARMOR_BLOCK),
		_entry("1,-1", GameTypes.CellType.ARMOR_BLOCK),
		_entry("1,0", GameTypes.CellType.BLOCK),
		_entry("2,0", GameTypes.CellType.WALL),
		_entry("0,2", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_ATTACK),
		_entry("0,-2", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_SHIELD),
	]
	var spawns: Dictionary = {
		1: {
			GameTypes.TankType.QTANK: "-4,5",
			GameTypes.TankType.KTANK: "0,5",
		},
		2: {
			GameTypes.TankType.QTANK: "4,-5",
			GameTypes.TankType.KTANK: "0,-5",
		},
	}
	return MapPreset.new(
		"fortress",
		"Fortress Arena",
		"Obstacle-heavy map with tighter central approach lanes and delayed power reveals.",
		5,
		terrain_entries,
		spawns
	)


static func _build_labyrinth_preset() -> MapPreset:
	var terrain_entries: Array[Dictionary] = []
	var wall_coords: Array[String] = [
		"-4,1", "4,-1",
		"-3,-1", "3,1",
		"-1,4", "1,-4",
		"1,3", "-1,-3",
		"-4,3", "4,-3",
		"-3,4", "3,-4",
	]
	var block_coords: Array[String] = [
		"-2,0", "2,0",
		"-2,2", "2,-2",
		"0,2", "0,-2",
		"-1,2", "1,-2",
		"-2,1", "2,-1",
		"-3,2", "3,-2",
		"-2,3", "2,-3",
		"-5,1", "5,-1",
		"-1,5", "1,-5",
	]
	var armor_coords: Array[String] = [
		"-1,1", "1,-1",
		"-3,1", "3,-1",
		"-1,3", "1,-3",
		"0,4", "0,-4",
	]
	for coord_key: String in wall_coords:
		terrain_entries.append(_entry(coord_key, GameTypes.CellType.WALL))
	for coord_key: String in block_coords:
		terrain_entries.append(_entry(coord_key, GameTypes.CellType.BLOCK))
	for coord_key: String in armor_coords:
		terrain_entries.append(_entry(coord_key, GameTypes.CellType.ARMOR_BLOCK))
	terrain_entries.append_array([
		_entry("0,1", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_ATTACK),
		_entry("0,-1", GameTypes.CellType.POWER_BLOCK, GameTypes.CellType.POWER_SHIELD),
		_entry("-4,0", GameTypes.CellType.POWER_ATTACK),
		_entry("4,0", GameTypes.CellType.POWER_SHIELD),
		_entry("-2,4", GameTypes.CellType.POWER_BONUS_MOVE),
		_entry("2,-4", GameTypes.CellType.POWER_BONUS_MOVE),
	])
	var spawns: Dictionary = {
		1: {
			GameTypes.TankType.QTANK: "-6,6",
			GameTypes.TankType.KTANK: "0,6",
		},
		2: {
			GameTypes.TankType.QTANK: "6,-6",
			GameTypes.TankType.KTANK: "0,-6",
		},
	}
	return MapPreset.new(
		"labyrinth",
		"Labyrinth Arena",
		"Larger tactical map with denser obstacles, layered approaches, and more meaningful path optimization.",
		6,
		terrain_entries,
		spawns
	)


static func _entry(coord_key: String, cell_type: int, reveal_type: int = -1) -> Dictionary:
	return {
		"coord": coord_key,
		"type": cell_type,
		"reveal_type": reveal_type,
	}


static func _build_random_buried_terrain(spawns: Dictionary, rings: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var reserved: Dictionary = {"0,0": true}
	for player_id: Variant in spawns.keys():
		var player_spawns: Dictionary = spawns[player_id]
		for tank_type: Variant in player_spawns.keys():
			reserved[str(player_spawns[tank_type])] = true

	var blocked_keys: Dictionary = {}
	_add_required_neighbors(blocked_keys, HexCoord.new(), rings, reserved)
	for player_id: Variant in spawns.keys():
		var player_spawns: Dictionary = spawns[player_id]
		for tank_type: Variant in player_spawns.keys():
			_add_required_neighbors(blocked_keys, HexCoord.from_key(str(player_spawns[tank_type])), rings, reserved)

	var terrain_by_key: Dictionary = {}
	for coord_key: String in blocked_keys.keys():
		terrain_by_key[coord_key] = _random_block_entry(coord_key, rng, true)

	var target_count: int = rng.randi_range(70, 75)
	var ring_buckets: Dictionary = {}
	for coord: HexCoord in HexCoord.all_within_rings(rings):
		var coord_key: String = coord.key()
		if reserved.has(coord_key) or terrain_by_key.has(coord_key):
			continue
		var ring_index: int = coord.distance_to(HexCoord.new())
		if ring_index <= 0:
			continue
		if not ring_buckets.has(ring_index):
			var new_bucket: Array = []
			ring_buckets[ring_index] = new_bucket
		var bucket: Array = ring_buckets[ring_index]
		bucket.append(coord_key)

	for ring_index: int in ring_buckets.keys():
		_shuffle_strings(ring_buckets[ring_index], rng)

	while terrain_by_key.size() < target_count:
		var added_this_pass: bool = false
		var ring_order: Array = [1, 2, 3, 4, 5, 6]
		_shuffle_ints(ring_order, rng)
		for ring_index: int in ring_order:
			if terrain_by_key.size() >= target_count:
				break
			if not ring_buckets.has(ring_index):
				continue
			var candidate_bucket: Array = ring_buckets[ring_index]
			if candidate_bucket.is_empty():
				continue
			var coord_key: String = candidate_bucket.pop_back()
			terrain_by_key[coord_key] = _random_block_entry(coord_key, rng)
			added_this_pass = true
		if not added_this_pass:
			break

	var terrain_entries: Array[Dictionary] = []
	var sorted_keys: Array[String] = []
	for coord_key: String in terrain_by_key.keys():
		sorted_keys.append(coord_key)
	sorted_keys.sort_custom(func(a: String, b: String) -> bool:
		var ac: HexCoord = HexCoord.from_key(a)
		var bc: HexCoord = HexCoord.from_key(b)
		var ad: int = ac.distance_to(HexCoord.new())
		var bd: int = bc.distance_to(HexCoord.new())
		if ad != bd:
			return ad < bd
		if ac.q != bc.q:
			return ac.q < bc.q
		return ac.r < bc.r
	)
	for coord_key: String in sorted_keys:
		terrain_entries.append(terrain_by_key[coord_key])
	return terrain_entries


static func _add_required_neighbors(blocked_keys: Dictionary, coord: HexCoord, rings: int, reserved: Dictionary) -> void:
	for neighbor: HexCoord in coord.neighbors():
		var coord_key: String = neighbor.key()
		if reserved.has(coord_key):
			continue
		if neighbor.distance_to(HexCoord.new()) > rings:
			continue
		blocked_keys[coord_key] = true


static func _random_block_entry(coord_key: String, rng: RandomNumberGenerator, is_required: bool = false) -> Dictionary:
	var roll: int = rng.randi_range(0, 99)
	if is_required:
		if roll < 25:
			return _entry(coord_key, GameTypes.CellType.ARMOR_BLOCK)
		if roll < 55:
			return _entry(coord_key, GameTypes.CellType.POWER_BLOCK, _random_reveal_type(rng))
		return _entry(coord_key, GameTypes.CellType.BLOCK)
	if roll < 18:
		return _entry(coord_key, GameTypes.CellType.ARMOR_BLOCK)
	if roll < 42:
		return _entry(coord_key, GameTypes.CellType.POWER_BLOCK, _random_reveal_type(rng))
	return _entry(coord_key, GameTypes.CellType.BLOCK)


static func _random_reveal_type(rng: RandomNumberGenerator) -> int:
	match rng.randi_range(0, 2):
		0:
			return GameTypes.CellType.POWER_ATTACK
		1:
			return GameTypes.CellType.POWER_SHIELD
		_:
			return GameTypes.CellType.POWER_BONUS_MOVE


static func _shuffle_strings(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: String = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp


static func _shuffle_ints(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: int = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp
