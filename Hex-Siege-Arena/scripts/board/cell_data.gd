class_name CellData
extends Resource

const TYPE_HP := {
	GameTypes.CellType.EMPTY: 0,
	GameTypes.CellType.CENTER: 0,
	GameTypes.CellType.WALL: 0,
	GameTypes.CellType.BLOCK: 2,
	GameTypes.CellType.ARMOR_BLOCK: 3,
	GameTypes.CellType.POWER_BLOCK: 2,
	GameTypes.CellType.POWER_ATTACK: 0,
	GameTypes.CellType.POWER_SHIELD: 0,
	GameTypes.CellType.POWER_BONUS_MOVE: 0,
}

const WALKABLE_TYPES := {
	GameTypes.CellType.EMPTY: true,
	GameTypes.CellType.CENTER: true,
	GameTypes.CellType.POWER_ATTACK: true,
	GameTypes.CellType.POWER_SHIELD: true,
	GameTypes.CellType.POWER_BONUS_MOVE: true,
}

const DESTRUCTIBLE_TYPES := {
	GameTypes.CellType.BLOCK: true,
	GameTypes.CellType.ARMOR_BLOCK: true,
	GameTypes.CellType.POWER_BLOCK: true,
}

const BLOCKS_ATTACK_TYPES := {
	GameTypes.CellType.WALL: true,
	GameTypes.CellType.BLOCK: true,
	GameTypes.CellType.ARMOR_BLOCK: true,
	GameTypes.CellType.POWER_BLOCK: true,
}

var coord: HexCoord
var cell_type: int = GameTypes.CellType.EMPTY
var hp: int = 0


func _init(p_coord: HexCoord = null, p_cell_type: int = GameTypes.CellType.EMPTY, p_hp: int = 0) -> void:
	coord = p_coord if p_coord != null else HexCoord.new()
	cell_type = p_cell_type
	hp = p_hp if p_hp > 0 else get_default_hp_for_type(p_cell_type)


func clone() -> CellData:
	return CellData.new(coord.clone(), cell_type, hp)


func to_snapshot() -> Dictionary:
	return {
		"coord": coord.key(),
		"type": cell_type,
		"hp": hp,
	}


static func from_snapshot(snapshot: Dictionary) -> CellData:
	return CellData.new(
		HexCoord.from_key(str(snapshot.get("coord", "0,0"))),
		int(snapshot.get("type", GameTypes.CellType.EMPTY)),
		int(snapshot.get("hp", 0))
	)


func set_type(new_type: int) -> void:
	cell_type = new_type
	hp = get_default_hp_for_type(new_type)


static func get_default_hp_for_type(query_type: int) -> int:
	return TYPE_HP.get(query_type, 0)


func is_walkable() -> bool:
	return WALKABLE_TYPES.get(cell_type, false)


func is_destructible() -> bool:
	return DESTRUCTIBLE_TYPES.get(cell_type, false)


func blocks_attack() -> bool:
	return BLOCKS_ATTACK_TYPES.get(cell_type, false)
