class_name ActionExplanation
extends Resource

var actor_label: String = ""
var summary: String = ""
var score: float = 0.0
var metrics: Dictionary = {}


func _init(p_actor_label: String = "", p_summary: String = "", p_score: float = 0.0, p_metrics: Dictionary = {}) -> void:
	actor_label = p_actor_label
	summary = p_summary
	score = p_score
	metrics = p_metrics.duplicate(true)
