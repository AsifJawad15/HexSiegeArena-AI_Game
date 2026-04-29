class_name GameEvent
extends Resource

var event_name: String = ""
var payload: Dictionary = {}


func _init(p_event_name: String = "", p_payload: Dictionary = {}) -> void:
	event_name = p_event_name
	payload = p_payload.duplicate(true)
