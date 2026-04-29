class_name ActionData
extends Resource

var action_type: int = GameTypes.ActionType.PASS
var actor_id: String = ""
var target_coord: HexCoord = HexCoord.new()
var direction: int = -1
var metadata: Dictionary = {}


func _init(
	p_action_type: int = GameTypes.ActionType.PASS,
	p_actor_id: String = "",
	p_target_coord: HexCoord = null,
	p_direction: int = -1,
	p_metadata: Dictionary = {}
) -> void:
	action_type = p_action_type
	actor_id = p_actor_id
	target_coord = p_target_coord if p_target_coord != null else HexCoord.new()
	direction = p_direction
	metadata = p_metadata.duplicate(true)


func clone() -> ActionData:
	return ActionData.new(action_type, actor_id, target_coord.clone(), direction, metadata)
