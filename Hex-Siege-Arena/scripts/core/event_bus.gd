extends Node

signal scene_requested(scene_path: String)
signal phase_changed(new_phase: int)
signal match_config_changed(config: MatchConfig)
signal action_explanation_updated(explanation: ActionExplanation)
signal status_message_requested(message: String)


func request_scene(scene_path: String) -> void:
	scene_requested.emit(scene_path)


func publish_status(message: String) -> void:
	status_message_requested.emit(message)
