class_name HexCoord
extends RefCounted

const SQRT_3 := 1.7320508075688772
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var q: int
var r: int


func _init(p_q: int = 0, p_r: int = 0) -> void:
	q = p_q
	r = p_r


func clone() -> HexCoord:
	return HexCoord.new(q, r)


func add(other: HexCoord) -> HexCoord:
	return HexCoord.new(q + other.q, r + other.r)


func neighbor(direction: int) -> HexCoord:
	var vector: Vector2i = DIRECTIONS[wrapi(direction, 0, DIRECTIONS.size())]
	return HexCoord.new(q + vector.x, r + vector.y)


func neighbors() -> Array:
	var results: Array[HexCoord] = []
	for direction in range(DIRECTIONS.size()):
		results.append(neighbor(direction))
	return results


func distance_to(other: HexCoord) -> int:
	var s: int = -q - r
	var other_s: int = -other.q - other.r
	var dq: int = abs(q - other.q)
	var dr: int = abs(r - other.r)
	var ds: int = abs(s - other_s)
	return maxi(maxi(dq, dr), ds)


func to_vector2i() -> Vector2i:
	return Vector2i(q, r)


func key() -> String:
	return "%s,%s" % [q, r]


func equals(other: HexCoord) -> bool:
	return q == other.q and r == other.r


func to_world_flat(hex_size: float) -> Vector2:
	var x: float = hex_size * 1.5 * float(q)
	var y: float = hex_size * SQRT_3 * (float(r) + float(q) * 0.5)
	return Vector2(x, y)


func raycast(direction: int, max_range: int) -> Array:
	var results: Array[HexCoord] = []
	var current: HexCoord = clone()
	for _step in range(max_range):
		current = current.neighbor(direction)
		results.append(current)
	return results


static func from_world_flat(world_position: Vector2, hex_size: float) -> HexCoord:
	var qf: float = (2.0 / 3.0 * world_position.x) / hex_size
	var rf: float = ((-1.0 / 3.0) * world_position.x + (SQRT_3 / 3.0) * world_position.y) / hex_size
	return HexCoord.round_axial(qf, rf)


static func round_axial(qf: float, rf: float) -> HexCoord:
	var sf: float = -qf - rf
	var rq: int = roundi(qf)
	var rr: int = roundi(rf)
	var rs: int = roundi(sf)

	var q_diff: float = abs(rq - qf)
	var r_diff: float = abs(rr - rf)
	var s_diff: float = abs(rs - sf)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return HexCoord.new(rq, rr)


static func all_within_rings(rings: int) -> Array:
	var results: Array[HexCoord] = []
	for axial_q in range(-rings, rings + 1):
		var min_r: int = maxi(-rings, -axial_q - rings)
		var max_r: int = mini(rings, -axial_q + rings)
		for axial_r in range(min_r, max_r + 1):
			results.append(HexCoord.new(axial_q, axial_r))
	return results


static func from_key(key_value: String) -> HexCoord:
	var parts: PackedStringArray = key_value.split(",")
	if parts.size() != 2:
		return HexCoord.new()
	return HexCoord.new(int(parts[0]), int(parts[1]))


func _to_string() -> String:
	return "HexCoord(%d, %d)" % [q, r]
