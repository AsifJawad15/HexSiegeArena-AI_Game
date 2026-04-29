class_name MapPreset
extends Resource

var map_id: String = "standard"
var display_name: String = "Standard"
var description: String = ""
var rings: int = 5
var terrain_entries: Array[Dictionary] = []
var spawn_points: Dictionary = {}


func _init(
	p_map_id: String = "standard",
	p_display_name: String = "Standard",
	p_description: String = "",
	p_rings: int = 5,
	p_terrain_entries: Array[Dictionary] = [],
	p_spawn_points: Dictionary = {}
) -> void:
	map_id = p_map_id
	display_name = p_display_name
	description = p_description
	rings = p_rings
	terrain_entries = p_terrain_entries.duplicate(true)
	spawn_points = p_spawn_points.duplicate(true)


func get_spawn_coord(player_id: int, tank_type: int) -> HexCoord:
	var player_spawns: Dictionary = spawn_points.get(player_id, {})
	var coord_key: String = player_spawns.get(tank_type, "")
	if coord_key == "":
		return null
	return HexCoord.from_key(coord_key)
