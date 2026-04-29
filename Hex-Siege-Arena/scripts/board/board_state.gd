class_name BoardState
extends Resource

const DEFAULT_RINGS := 5

var rings: int = DEFAULT_RINGS
var cells: Dictionary = {}
var map_id: String = "standard"
var map_display_name: String = "Buried Front"
var map_description: String = ""
var power_block_reveals: Dictionary = {}


func _init(p_rings: int = DEFAULT_RINGS) -> void:
	rings = p_rings
	generate_empty_board()


func generate_empty_board() -> void:
	cells.clear()
	power_block_reveals.clear()
	for coord: HexCoord in HexCoord.all_within_rings(rings):
		var cell_type: int = GameTypes.CellType.CENTER if coord.q == 0 and coord.r == 0 else GameTypes.CellType.EMPTY
		set_cell(CellData.new(coord, cell_type))


func set_cell(cell: CellData) -> void:
	cells[cell.coord.key()] = cell


func get_cell(coord: HexCoord) -> CellData:
	return cells.get(coord.key())


func has_cell(coord: HexCoord) -> bool:
	return cells.has(coord.key())


func is_walkable(coord: HexCoord) -> bool:
	var cell: CellData = get_cell(coord)
	return cell != null and cell.is_walkable()


func blocks_attack(coord: HexCoord) -> bool:
	var cell: CellData = get_cell(coord)
	return cell != null and cell.blocks_attack()


func all_cells() -> Array[CellData]:
	var results: Array[CellData] = []
	for cell: CellData in cells.values():
		results.append(cell)
	return results


func set_cell_type(coord: HexCoord, cell_type: int) -> void:
	var cell: CellData = get_cell(coord)
	if cell == null:
		cell = CellData.new(coord, cell_type)
		set_cell(cell)
	else:
		cell.set_type(cell_type)


func load_map_preset(preset: MapPreset) -> void:
	rings = preset.rings
	map_id = preset.map_id
	map_display_name = preset.display_name
	map_description = preset.description
	generate_empty_board()

	for entry: Dictionary in preset.terrain_entries:
		var coord: HexCoord = HexCoord.from_key(entry.get("coord", "0,0"))
		var cell_type: int = entry.get("type", GameTypes.CellType.EMPTY)
		set_cell_type(coord, cell_type)
		if cell_type == GameTypes.CellType.POWER_BLOCK:
			power_block_reveals[coord.key()] = entry.get("reveal_type", GameTypes.CellType.POWER_ATTACK)


func apply_damage(coord: HexCoord, amount: int) -> Dictionary:
	var cell: CellData = get_cell(coord)
	if cell == null or not cell.is_destructible():
		return {"destroyed": false, "revealed_type": -1}

	cell.hp = maxi(0, cell.hp - amount)
	if cell.hp > 0:
		return {"destroyed": false, "revealed_type": -1}

	var revealed_type: int = -1
	if cell.cell_type == GameTypes.CellType.POWER_BLOCK:
		revealed_type = power_block_reveals.get(coord.key(), GameTypes.CellType.POWER_ATTACK)
		cell.set_type(revealed_type)
		power_block_reveals.erase(coord.key())
	else:
		cell.set_type(GameTypes.CellType.EMPTY)

	return {"destroyed": true, "revealed_type": revealed_type}


func clone() -> BoardState:
	var duplicate: BoardState = BoardState.new(rings)
	duplicate.cells.clear()
	for key: String in cells.keys():
		duplicate.cells[key] = (cells[key] as CellData).clone()
	duplicate.map_id = map_id
	duplicate.map_display_name = map_display_name
	duplicate.map_description = map_description
	duplicate.power_block_reveals = power_block_reveals.duplicate(true)
	return duplicate


func to_snapshot() -> Dictionary:
	var cell_entries: Array[Dictionary] = []
	for key: String in cells.keys():
		cell_entries.append((cells[key] as CellData).to_snapshot())
	return {
		"rings": rings,
		"map_id": map_id,
		"map_display_name": map_display_name,
		"map_description": map_description,
		"power_block_reveals": power_block_reveals.duplicate(true),
		"cells": cell_entries,
	}


static func from_snapshot(snapshot: Dictionary) -> BoardState:
	var restored: BoardState = BoardState.new(int(snapshot.get("rings", DEFAULT_RINGS)))
	restored.cells.clear()
	restored.map_id = str(snapshot.get("map_id", "standard"))
	restored.map_display_name = str(snapshot.get("map_display_name", "Buried Front"))
	restored.map_description = str(snapshot.get("map_description", ""))
	restored.power_block_reveals = (snapshot.get("power_block_reveals", {}) as Dictionary).duplicate(true)
	for cell_snapshot: Variant in snapshot.get("cells", []):
		if cell_snapshot is Dictionary:
			var restored_cell: CellData = CellData.from_snapshot(cell_snapshot)
			restored.set_cell(restored_cell)
	return restored
