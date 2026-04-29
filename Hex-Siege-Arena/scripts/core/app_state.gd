extends Node

const DEFAULT_MATCH_SCENE := "res://scenes/match/match_root.tscn"
const DEFAULT_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const DEFAULT_REPLAY_SCENE := "res://scenes/replay/replay_shell.tscn"
const DEFAULT_SETTINGS_SCENE := "res://scenes/settings/settings_root.tscn"
const DEFAULT_HELP_SCENE := "res://scenes/help/help_root.tscn"
const PREFERENCES_PATH := "user://hex_siege_prefs.cfg"

var project_phase: int = 18
var build_label: String = "step7-complete-product-flow"
var current_match_config: MatchConfig = MatchConfig.new()
var current_replay: ReplayRecord = ReplayRecord.new()
var last_action_explanation: ActionExplanation = ActionExplanation.new()
var game_version: String = "v0.7"
var ui_scale: float = 1.0
var reduced_motion: bool = false
var high_contrast_mode: bool = false
var show_onboarding_hints: bool = true
var _pending_music_volume_db: float = -16.0
var _pending_sfx_volume_db: float = -8.0
var _pending_ui_volume_db: float = -10.0


func _ready() -> void:
	load_preferences()
	call_deferred("_apply_loaded_preferences")


func apply_window_preferences(node: Node) -> void:
	if node == null:
		return
	var window: Window = node.get_window()
	if window != null:
		window.mode = Window.MODE_FULLSCREEN
		window.borderless = false
		window.content_scale_factor = ui_scale


func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "ui_scale", ui_scale)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "high_contrast_mode", high_contrast_mode)
	config.set_value("accessibility", "show_onboarding_hints", show_onboarding_hints)
	config.set_value("match", "config", current_match_config.to_snapshot())
	config.set_value("audio", "music_volume_db", AudioManager.music_volume_db if AudioManager != null else -16.0)
	config.set_value("audio", "sfx_volume_db", AudioManager.sfx_volume_db if AudioManager != null else -8.0)
	config.set_value("audio", "ui_volume_db", AudioManager.ui_volume_db if AudioManager != null else -10.0)
	config.save(PREFERENCES_PATH)


func load_preferences() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(PREFERENCES_PATH)
	if err != OK:
		return

	ui_scale = float(config.get_value("accessibility", "ui_scale", 1.0))
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
	high_contrast_mode = bool(config.get_value("accessibility", "high_contrast_mode", false))
	show_onboarding_hints = bool(config.get_value("accessibility", "show_onboarding_hints", true))
	current_match_config = MatchConfig.from_snapshot(config.get_value("match", "config", {}))
	_pending_music_volume_db = float(config.get_value("audio", "music_volume_db", -16.0))
	_pending_sfx_volume_db = float(config.get_value("audio", "sfx_volume_db", -8.0))
	_pending_ui_volume_db = float(config.get_value("audio", "ui_volume_db", -10.0))

	if AudioManager != null:
		AudioManager.set_music_volume_db(_pending_music_volume_db)
		AudioManager.set_sfx_volume_db(_pending_sfx_volume_db)
		AudioManager.set_ui_volume_db(_pending_ui_volume_db)


func _apply_loaded_preferences() -> void:
	if AudioManager == null:
		return
	AudioManager.set_music_volume_db(_pending_music_volume_db)
	AudioManager.set_sfx_volume_db(_pending_sfx_volume_db)
	AudioManager.set_ui_volume_db(_pending_ui_volume_db)


func reset_runtime_state() -> void:
	current_match_config = MatchConfig.new()
	current_replay = ReplayRecord.new()
	last_action_explanation = ActionExplanation.new()
	save_preferences()
