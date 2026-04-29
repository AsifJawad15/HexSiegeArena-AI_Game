class_name ReplayRecord
extends Resource

var turns: Array[Dictionary] = []
var winner_label: String = ""
var metadata: Dictionary = {}


func add_turn(snapshot: Dictionary) -> void:
	turns.append(snapshot.duplicate(true))


func clear() -> void:
	turns.clear()
	winner_label = ""
	metadata.clear()
