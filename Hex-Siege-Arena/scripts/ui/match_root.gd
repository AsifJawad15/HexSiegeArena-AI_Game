extends Control

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_root.tscn"
const HELP_SCENE := "res://scenes/help/help_root.tscn"
const AUTOPLAY_SPEED_LABELS := ["Slow", "Normal", "Fast", "Turbo", "Instant"]
const AUTOPLAY_SPEED_SECONDS := [0.9, 0.45, 0.16, 0.05, 0.01]
const PLAYBACK_SPEED_SCALES := [0.75, 1.0, 1.8, 3.5, 7.0]
const FONT_REGULAR  := preload("res://fonts/Inter/static/Inter_18pt-Regular.ttf")
const FONT_MEDIUM   := preload("res://fonts/Inter/static/Inter_18pt-Medium.ttf")
const FONT_SEMIBOLD := preload("res://fonts/Rajdhani/Rajdhani-SemiBold.ttf")
const FONT_BOLD     := preload("res://fonts/Rajdhani/Rajdhani-Bold.ttf")
const BOARD_BG      := preload("res://PNG/bg.png")
const WORLD_LIGHT_CIRCLE := preload("res://assets/world/masks/light_circle.png")
const WORLD_LIGHT_CONE := preload("res://assets/world/masks/light_cone.png")
const WORLD_EDGE_SMOKE := preload("res://assets/world/smoke/edge_smoke.png")
const WORLD_WINDOW_CORNER := preload("res://assets/world/silhouettes/window_corner.png")
const WORLD_CORRIDOR_CROSS := preload("res://assets/world/silhouettes/corridor_cross.png")
const WORLD_CHIMNEY := preload("res://assets/world/silhouettes/chimney.png")
const COLOR_BG := Color("0b1220")
const COLOR_SURFACE := Color("141c2b")
const COLOR_SURFACE_ALT := Color("1a2436")
const COLOR_SURFACE_DEEP := Color("0f1725")
const COLOR_BORDER := Color("334766")
const COLOR_TEXT := Color("eaf2ff")
const COLOR_TEXT_MUTED := Color("9db0cc")
const COLOR_ACCENT := Color("6bc7ff")
const COLOR_GOLD := Color("f0c94a")
const COLOR_GREEN := Color("6bc7ff")
const COLOR_ATTACK := Color("ff9a66")
const COLOR_P1 := Color("6bc7ff")
const COLOR_P2 := Color("ff8a76")
var _game_state: GameState
var _board_view: BoardDebugView
var _board_holder: Control
var _selected_model_name_label: Label
var _selected_model_role_label: Label
var _hover_label: Label
var _selected_label: Label
var _turn_label: RichTextLabel
var _objective_label: Label
var _score_label: Label
var _hp_summary_label: Label
var _units_label: Label
var _control_strip_label: Label
var _status_label: RichTextLabel
var _selected_accent_strip: ColorRect
var _mode_label: Label
var _selected_actor_label: Label
var _map_label: Label
var _ai_label: Label
var _explanation_label: Label
var _preview_label: RichTextLabel
var _stats_label: Label
var _post_match_label: Label
var _player_one_label: Label
var _player_two_label: Label
var _event_log: RichTextLabel
var _guide_label: Label
var _sidebar_scroll: ScrollContainer
var _board_meta_label: Label
var _board_hint_label: Label
var _move_button: Button
var _attack_button: Button
var _pass_button: Button
var _reset_button: Button
var _ai_move_button: Button
var _autoplay_button: Button
var _speed_button: Button
var _history_list: ItemList
var _history_detail_label: Label
var _autoplay_timer: Timer
var _mini_board_holder: Control
var _mini_board_view: BoardDebugView
var _ability_button: Button
var _debug_panel: PanelContainer
var _debug_label: Label
var _action_mode: String = ""
var _selected_actor_id: String = ""
var _autoplay_enabled: bool = false
var _autoplay_speed_index: int = 1
var _auto_ai_pending: bool = false
var _guide_visible: bool = false
var _presentation_locked: bool = false
var _debug_visible: bool = false
var _activity_text: String = "Ready"
var _active_actor_id: String = ""
var _top_panel: PanelContainer
var _selected_unit_panel: PanelContainer
var _red_team_panel: PanelContainer
var _blue_team_panel: PanelContainer
var _red_king_label: Label
var _red_queen_label: Label
var _blue_king_label: Label
var _blue_queen_label: Label
var _phase_chip_panel: PanelContainer
var _phase_chip_label: Label
var _actor_chip_panel: PanelContainer
var _actor_chip_label: Label
var _command_panel: PanelContainer
var _phase_banner_panel: PanelContainer
var _phase_banner_label: Label
var _pause_overlay: Control
var _result_overlay: Control
var _onboarding_overlay: Control
var _transition_overlay: ColorRect
var _result_title_label: Label
var _result_summary_label: RichTextLabel
var _pause_visible: bool = false
var _result_visible: bool = false
var _result_dismissed: bool = false
var _onboarding_dismissed: bool = false
var _startup_hint_panel: PanelContainer
var _faction_strip: ColorRect
var _p1_stat_label: Label
var _p2_stat_label: Label
var _p1_units_label: Label
var _p2_units_label: Label


func _ready() -> void:
	AppState.apply_window_preferences(self)
	_reset_match()
	AudioManager.play_match_music()
	theme = _build_match_theme()
	_build_layout()
	_refresh_view()
	call_deferred("_play_intro_transition")
	call_deferred("_show_phase_banner", "MATCH START")
	call_deferred("_show_startup_hint")


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var world_backdrop := Control.new()
	world_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_backdrop)
	_build_world_backdrop(world_backdrop)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 0)
	root_margin.add_theme_constant_override("margin_top", 0)
	root_margin.add_theme_constant_override("margin_right", 0)
	root_margin.add_theme_constant_override("margin_bottom", 0)
	add_child(root_margin)

	var root_layout := VBoxContainer.new()
	root_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_theme_constant_override("separation", 0)
	root_margin.add_child(root_layout)

	_top_panel = _make_panel_card(COLOR_BORDER, COLOR_SURFACE)
	_top_panel.custom_minimum_size = Vector2(0, 72)
	root_layout.add_child(_top_panel)
	var top_margin := _wrap_panel_content(_top_panel, 18, 10)
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_margin.add_child(top_bar)

	# Left — turn label + phase subtitle + faction color strip
	var top_left := VBoxContainer.new()
	top_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_left.add_theme_constant_override("separation", 2)
	top_bar.add_child(top_left)

	_turn_label = RichTextLabel.new()
	_turn_label.bbcode_enabled = true
	_turn_label.fit_content = true
	_turn_label.scroll_active = false
	_turn_label.add_theme_font_override("normal_font", FONT_BOLD)
	_turn_label.add_theme_font_size_override("normal_font_size", 30)
	_turn_label.add_theme_color_override("default_color", COLOR_TEXT)
	top_left.add_child(_turn_label)

	_objective_label = Label.new()
	_objective_label.add_theme_font_override("font", FONT_SEMIBOLD)
	_objective_label.add_theme_font_size_override("font_size", 11)
	_objective_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	top_left.add_child(_objective_label)

	_faction_strip = ColorRect.new()
	_faction_strip.custom_minimum_size = Vector2(0, 2)
	_faction_strip.color = COLOR_P1
	top_left.add_child(_faction_strip)

	# Center — score eyebrow + large score
	var score_col := VBoxContainer.new()
	score_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	score_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	score_col.custom_minimum_size = Vector2(200, 0)
	score_col.add_theme_constant_override("separation", 0)
	score_col.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(score_col)

	var score_eyebrow := Label.new()
	score_eyebrow.text = "SCORE"
	score_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_eyebrow.add_theme_font_override("font", FONT_SEMIBOLD)
	score_eyebrow.add_theme_font_size_override("font_size", 11)
	score_eyebrow.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	score_col.add_child(score_eyebrow)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_override("font", FONT_BOLD)
	_score_label.add_theme_font_size_override("font_size", 34)
	_score_label.add_theme_color_override("font_color", COLOR_GOLD)
	score_col.add_child(_score_label)

	# Right — faction stat boxes (P1  VS  P2)
	var top_right_row := HBoxContainer.new()
	top_right_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_right_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_right_row.alignment = BoxContainer.ALIGNMENT_END
	top_right_row.add_theme_constant_override("separation", 8)
	top_bar.add_child(top_right_row)

	var p1_box := _make_faction_stat_box(COLOR_P1)
	top_right_row.add_child(p1_box)
	_p1_stat_label = p1_box.get_meta("hp_label") as Label
	_p1_units_label = p1_box.get_meta("units_label") as Label

	var vs_lbl := Label.new()
	vs_lbl.text = "VS"
	vs_lbl.add_theme_font_override("font", FONT_BOLD)
	vs_lbl.add_theme_font_size_override("font_size", 13)
	vs_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	vs_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_right_row.add_child(vs_lbl)

	var p2_box := _make_faction_stat_box(COLOR_P2)
	top_right_row.add_child(p2_box)
	_p2_stat_label = p2_box.get_meta("hp_label") as Label
	_p2_units_label = p2_box.get_meta("units_label") as Label

	# Legacy labels kept hidden (still written by _refresh_view for debug purposes)
	_hp_summary_label = Label.new()
	_hp_summary_label.visible = false
	top_right_row.add_child(_hp_summary_label)

	_units_label = Label.new()
	_units_label.visible = false
	top_right_row.add_child(_units_label)
	_top_panel.visible = false

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	root_layout.add_child(content)

	var board_frame := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_DEEP)
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board_frame)
	# Transparent board frame — bg.png provides the visual background
	var bf_style := StyleBoxFlat.new()
	bf_style.bg_color = Color(0, 0, 0, 0)
	bf_style.border_width_left = 0
	bf_style.border_width_top = 0
	bf_style.border_width_right = 0
	bf_style.border_width_bottom = 0
	board_frame.add_theme_stylebox_override("panel", bf_style)
	var board_margin := _wrap_panel_content(board_frame, 0, 0)
	var board_surface := Control.new()
	board_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_surface.clip_contents = false
	board_margin.add_child(board_surface)
	_build_board_world_layer(board_surface)

	_board_holder = Control.new()
	_board_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_holder.clip_contents = false
	_board_holder.resized.connect(_on_board_holder_resized)
	board_surface.add_child(_board_holder)

	_board_view = BoardDebugView.new()
	_board_view.set_game_state(_game_state)
	_board_view.playback_speed_scale = _current_playback_speed_scale()
	_board_view.hovered_cell_changed.connect(_on_hover_summary_changed)
	_board_view.selected_cell_changed.connect(_on_selected_summary_changed)
	_board_view.cell_clicked.connect(_on_board_cell_clicked)
	_board_holder.add_child(_board_view)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(270, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(side_scroll)
	_sidebar_scroll = side_scroll

	var side_rail := VBoxContainer.new()
	side_rail.custom_minimum_size = Vector2(262, 0)
	side_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_rail.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side_rail)

	_selected_unit_panel = _make_panel_card(COLOR_BORDER, Color(0.05, 0.08, 0.13, 0.92))
	side_rail.add_child(_selected_unit_panel)
	var info_margin := _wrap_panel_content(_selected_unit_panel, 12, 12)
	var info_layout := VBoxContainer.new()
	info_layout.add_theme_constant_override("separation", 8)
	info_margin.add_child(info_layout)

	var selected_title := _make_section_title("Selected Unit")
	info_layout.add_child(selected_title)
	info_layout.add_child(_make_section_divider())

	_selected_model_name_label = Label.new()
	_selected_model_name_label.add_theme_font_override("font", FONT_BOLD)
	_selected_model_name_label.add_theme_font_size_override("font_size", 20)
	info_layout.add_child(_selected_model_name_label)

	_selected_model_role_label = Label.new()
	_selected_model_role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_model_role_label.add_theme_font_override("font", FONT_MEDIUM)
	_selected_model_role_label.add_theme_font_size_override("font_size", 12)
	_selected_model_role_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	info_layout.add_child(_selected_model_role_label)

	_selected_accent_strip = ColorRect.new()
	_selected_accent_strip.custom_minimum_size = Vector2(0, 3)
	_selected_accent_strip.color = COLOR_BORDER
	info_layout.add_child(_selected_accent_strip)

	_status_label = _make_rich_body_label()
	info_layout.add_child(_status_label)

	var objective_panel := _make_panel_card(COLOR_GOLD, Color(0.05, 0.08, 0.13, 0.92))
	side_rail.add_child(objective_panel)
	var objective_margin := _wrap_panel_content(objective_panel, 12, 10)
	var objective_layout := VBoxContainer.new()
	objective_layout.add_theme_constant_override("separation", 8)
	objective_margin.add_child(objective_layout)
	objective_layout.add_child(_make_section_title("Battle Status"))
	objective_layout.add_child(_make_section_divider())
	_preview_label = _make_rich_body_label()
	objective_layout.add_child(_preview_label)

	var log_panel := _make_panel_card(COLOR_P1, Color(0.04, 0.07, 0.12, 0.90))
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_rail.add_child(log_panel)
	var log_margin := _wrap_panel_content(log_panel, 12, 10)
	var log_layout := VBoxContainer.new()
	log_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_layout.add_theme_constant_override("separation", 8)
	log_margin.add_child(log_layout)
	log_layout.add_child(_make_section_title("Recent Events"))
	log_layout.add_child(_make_section_divider())

	_event_log = RichTextLabel.new()
	_event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_log.fit_content = false
	_event_log.scroll_following = true
	_event_log.bbcode_enabled = true
	_event_log.add_theme_font_override("normal_font", FONT_REGULAR)
	_event_log.add_theme_font_size_override("normal_font_size", 13)
	log_layout.add_child(_event_log)

	var overlay_layer := Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.z_index = 20
	root_margin.add_child(overlay_layer)

	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_margin.add_theme_constant_override("margin_top", 78)
	overlay_margin.add_theme_constant_override("margin_right", 0)
	overlay_margin.add_theme_constant_override("margin_bottom", 74)
	overlay_layer.add_child(overlay_margin)

	var overlay_row := HBoxContainer.new()
	overlay_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_margin.add_child(overlay_row)

	var overlay_spacer := Control.new()
	overlay_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_row.add_child(overlay_spacer)

	_debug_panel = _make_panel_card(COLOR_GOLD.darkened(0.28), COLOR_SURFACE_ALT)
	_debug_panel.visible = false
	_debug_panel.custom_minimum_size = Vector2(320, 0)
	_debug_panel.z_index = 40
	overlay_row.add_child(_debug_panel)
	var debug_scroll := ScrollContainer.new()
	debug_scroll.custom_minimum_size = Vector2(0, 360)
	debug_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_panel.add_child(debug_scroll)
	var debug_margin := MarginContainer.new()
	debug_margin.add_theme_constant_override("margin_left", 16)
	debug_margin.add_theme_constant_override("margin_top", 14)
	debug_margin.add_theme_constant_override("margin_right", 16)
	debug_margin.add_theme_constant_override("margin_bottom", 14)
	debug_scroll.add_child(debug_margin)
	var debug_layout := VBoxContainer.new()
	debug_layout.add_theme_constant_override("separation", 8)
	debug_margin.add_child(debug_layout)
	debug_layout.add_child(_make_section_title("Debug Panel (F3)"))

	_debug_label = _make_body_label()
	debug_layout.add_child(_debug_label)

	_hover_label = _make_body_label()
	debug_layout.add_child(_hover_label)
	_selected_label = _make_body_label()
	debug_layout.add_child(_selected_label)

	_map_label = _make_body_label()
	debug_layout.add_child(_map_label)

	var debug_controls := HBoxContainer.new()
	debug_controls.add_theme_constant_override("separation", 8)
	debug_layout.add_child(debug_controls)

	_ai_move_button = _make_action_button("Step AI", COLOR_GOLD)
	_ai_move_button.custom_minimum_size = Vector2(92, 40)
	_ai_move_button.pressed.connect(_on_ai_move_pressed)
	_wire_button_audio(_ai_move_button)
	debug_controls.add_child(_ai_move_button)

	_autoplay_button = _make_action_button("Auto", COLOR_P1)
	_autoplay_button.custom_minimum_size = Vector2(82, 40)
	_autoplay_button.pressed.connect(_on_autoplay_pressed)
	_wire_button_audio(_autoplay_button)
	debug_controls.add_child(_autoplay_button)

	_speed_button = _make_action_button("Speed", COLOR_P2)
	_speed_button.custom_minimum_size = Vector2(82, 40)
	_speed_button.pressed.connect(_on_speed_pressed)
	_wire_button_audio(_speed_button)
	debug_controls.add_child(_speed_button)

	var debug_controls_bottom := HBoxContainer.new()
	debug_controls_bottom.add_theme_constant_override("separation", 8)
	debug_layout.add_child(debug_controls_bottom)

	_reset_button = _make_action_button("Reset", COLOR_BORDER.lightened(0.18))
	_reset_button.custom_minimum_size = Vector2(82, 40)
	_reset_button.pressed.connect(_on_reset_pressed)
	_wire_button_audio(_reset_button)
	debug_controls_bottom.add_child(_reset_button)

	var back_button := _make_action_button("Back", COLOR_BORDER.lightened(0.12))
	back_button.custom_minimum_size = Vector2(82, 40)
	back_button.pressed.connect(_on_back_pressed)
	_wire_button_audio(back_button, true)
	debug_controls_bottom.add_child(back_button)

	var quit_button := _make_action_button("Quit", COLOR_P2.darkened(0.18))
	quit_button.custom_minimum_size = Vector2(82, 40)
	quit_button.pressed.connect(_on_quit_pressed)
	_wire_button_audio(quit_button, true)
	debug_controls_bottom.add_child(quit_button)

	_mini_board_holder = Control.new()
	_mini_board_holder.custom_minimum_size = Vector2(120, 120)
	_mini_board_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mini_board_holder.resized.connect(_recenter_mini_board)
	debug_layout.add_child(_mini_board_holder)

	_mini_board_view = BoardDebugView.new()
	_mini_board_view.hex_size = 8.0
	_mini_board_view.interaction_enabled = false
	_mini_board_view.playback_speed_scale = _current_playback_speed_scale()
	_mini_board_view.set_game_state(_game_state)
	_mini_board_holder.add_child(_mini_board_view)

	var bottom_panel := _make_panel_card(COLOR_BORDER, COLOR_SURFACE)
	bottom_panel.visible = false
	bottom_panel.custom_minimum_size = Vector2(0, 78)
	root_layout.add_child(bottom_panel)
	var bottom_margin := _wrap_panel_content(bottom_panel, 16, 8)
	var bottom_col := VBoxContainer.new()
	bottom_col.add_theme_constant_override("separation", 6)
	bottom_margin.add_child(bottom_col)

	# Permanent hint strip
	var hint_strip := Label.new()
	hint_strip.visible = false
	hint_strip.text = "◆  Select a unit  ·  [M] Move   [A] Attack  ·  [ESC] Pause"
	hint_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_strip.add_theme_font_override("font", FONT_MEDIUM)
	hint_strip.add_theme_font_size_override("font_size", 12)
	hint_strip.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hint_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_col.add_child(hint_strip)

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	controls_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_col.add_child(controls_row)

	_move_button = _make_action_button("⬆  MOVE", COLOR_GREEN)
	_move_button.custom_minimum_size = Vector2(0, 50)
	_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_button.add_theme_font_override("font", FONT_BOLD)
	_move_button.add_theme_font_size_override("font_size", 18)
	_move_button.pressed.connect(_on_move_mode_pressed)
	_wire_button_audio(_move_button)
	controls_row.add_child(_move_button)

	_attack_button = _make_action_button("⊕  ATTACK", COLOR_ATTACK)
	_attack_button.custom_minimum_size = Vector2(0, 50)
	_attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_button.add_theme_font_override("font", FONT_BOLD)
	_attack_button.add_theme_font_size_override("font_size", 18)
	_attack_button.pressed.connect(_on_attack_mode_pressed)
	_wire_button_audio(_attack_button)
	controls_row.add_child(_attack_button)

	_ability_button = _make_action_button("⚡  ABILITY", Color("9a89ff"))
	_ability_button.custom_minimum_size = Vector2(0, 50)
	_ability_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_button.add_theme_font_override("font", FONT_BOLD)
	_ability_button.add_theme_font_size_override("font_size", 18)
	_ability_button.disabled = true
	controls_row.add_child(_ability_button)

	_pass_button = _make_action_button("»  END TURN", COLOR_GOLD)
	_pass_button.custom_minimum_size = Vector2(0, 50)
	_pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_button.add_theme_font_override("font", FONT_BOLD)
	_pass_button.add_theme_font_size_override("font_size", 18)
	_pass_button.pressed.connect(_on_pass_pressed)
	_wire_button_audio(_pass_button)
	controls_row.add_child(_pass_button)

	_control_strip_label = null

	_command_panel = _make_panel_card(COLOR_GOLD, Color(0.05, 0.08, 0.13, 0.92))
	side_rail.add_child(_command_panel)
	var command_margin := _wrap_panel_content(_command_panel, 12, 10)
	var command_layout := VBoxContainer.new()
	command_layout.add_theme_constant_override("separation", 8)
	command_margin.add_child(command_layout)
	command_layout.add_child(_make_section_title("Commands"))
	command_layout.add_child(_make_section_divider())

	var command_grid := GridContainer.new()
	command_grid.columns = 2
	command_grid.add_theme_constant_override("h_separation", 8)
	command_grid.add_theme_constant_override("v_separation", 8)
	command_layout.add_child(command_grid)

	_move_button = _make_action_button("MOVE", COLOR_GREEN)
	_move_button.custom_minimum_size = Vector2(0, 44)
	_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_button.pressed.connect(_on_move_mode_pressed)
	_wire_button_audio(_move_button)
	command_grid.add_child(_move_button)

	_attack_button = _make_action_button("FIRE", COLOR_ATTACK)
	_attack_button.custom_minimum_size = Vector2(0, 44)
	_attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_button.pressed.connect(_on_attack_mode_pressed)
	_wire_button_audio(_attack_button)
	command_grid.add_child(_attack_button)

	_ability_button = _make_action_button("SKILL", Color("9a89ff"))
	_ability_button.custom_minimum_size = Vector2(0, 44)
	_ability_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_button.disabled = true
	command_grid.add_child(_ability_button)

	_pass_button = _make_action_button("END", COLOR_GOLD)
	_pass_button.custom_minimum_size = Vector2(0, 44)
	_pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_button.pressed.connect(_on_pass_pressed)
	_wire_button_audio(_pass_button)
	command_grid.add_child(_pass_button)

	var modal_layer := Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_margin.add_child(modal_layer)
	_build_spectator_hud(modal_layer)

	_phase_banner_panel = _make_panel_card(COLOR_GOLD, COLOR_SURFACE_ALT)
	_phase_banner_panel.visible = false
	_phase_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_banner_panel.anchor_left = 0.5
	_phase_banner_panel.anchor_top = 0.04
	_phase_banner_panel.anchor_right = 0.5
	_phase_banner_panel.anchor_bottom = 0.04
	_phase_banner_panel.offset_left = -160
	_phase_banner_panel.offset_top = 0
	_phase_banner_panel.offset_right = 160
	_phase_banner_panel.offset_bottom = 64
	modal_layer.add_child(_phase_banner_panel)
	var banner_margin := _wrap_panel_content(_phase_banner_panel, 18, 12)
	_phase_banner_label = Label.new()
	_phase_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_banner_label.add_theme_font_override("font", FONT_BOLD)
	_phase_banner_label.add_theme_font_size_override("font_size", 24)
	banner_margin.add_child(_phase_banner_label)

	_pause_overlay = _make_modal_overlay(modal_layer, "Paused", COLOR_P1, "Take a breath, adjust settings, or jump back into the arena.")
	var pause_layout := _pause_overlay.get_meta("content_layout") as VBoxContainer
	pause_layout.add_child(_make_overlay_button("Resume", _toggle_pause_overlay.bind(false), COLOR_GREEN))
	pause_layout.add_child(_make_overlay_button("Restart Match", _on_reset_pressed, COLOR_GOLD))
	pause_layout.add_child(_make_overlay_button("Settings", _open_settings_from_match, COLOR_P1))
	pause_layout.add_child(_make_overlay_button("Main Menu", _on_back_pressed, COLOR_BORDER.lightened(0.15), true))
	pause_layout.add_child(_make_overlay_button("Quit", _on_quit_pressed, COLOR_P2, true))

	_result_overlay = _make_modal_overlay(modal_layer, "Victory", COLOR_GOLD, "")
	var result_layout := _result_overlay.get_meta("content_layout") as VBoxContainer
	_result_title_label = result_layout.get_node("TitleLabel") as Label
	_result_summary_label = RichTextLabel.new()
	_result_summary_label.bbcode_enabled = true
	_result_summary_label.fit_content = true
	_result_summary_label.scroll_active = false
	_result_summary_label.add_theme_font_override("normal_font", FONT_REGULAR)
	_result_summary_label.add_theme_font_size_override("normal_font_size", 15)
	result_layout.add_child(_result_summary_label)
	result_layout.add_child(_make_overlay_button("Rematch", _on_reset_pressed, COLOR_GOLD))
	result_layout.add_child(_make_overlay_button("Review Battlefield", _hide_result_overlay, COLOR_P1))
	result_layout.add_child(_make_overlay_button("Main Menu", _on_back_pressed, COLOR_BORDER.lightened(0.15), true))

	_onboarding_overlay = _make_modal_overlay(modal_layer, "Match Briefing", COLOR_P1, "Destroy blocking objects to open lanes, then pressure the center or the enemy King. Blue tiles show movement and red tiles show fire lines.")
	var onboarding_layout := _onboarding_overlay.get_meta("content_layout") as VBoxContainer
	onboarding_layout.add_child(_make_overlay_button("Got It", _dismiss_onboarding.bind(false), COLOR_GREEN))
	onboarding_layout.add_child(_make_overlay_button("Don't Show Again", _dismiss_onboarding.bind(true), COLOR_GOLD))

	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.03, 0.05, 0.09, 1.0)
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(_transition_overlay)

	# Startup hint overlay — non-interactive, fades out after a few seconds
	_startup_hint_panel = _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	_startup_hint_panel.visible = false
	_startup_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_hint_panel.anchor_left = 0.5
	_startup_hint_panel.anchor_top = 1.0
	_startup_hint_panel.anchor_right = 0.5
	_startup_hint_panel.anchor_bottom = 1.0
	_startup_hint_panel.offset_left = -280
	_startup_hint_panel.offset_top = -104
	_startup_hint_panel.offset_right = 280
	_startup_hint_panel.offset_bottom = -68
	_startup_hint_panel.z_index = 12
	var hint_margin := _wrap_panel_content(_startup_hint_panel, 18, 8)
	var hint_label := Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_override("font", FONT_MEDIUM)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hint_label.text = "Select a unit  |  M Move  A Attack  Z Auto  X Speed  Esc Pause"
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_margin.add_child(hint_label)
	modal_layer.add_child(_startup_hint_panel)

	_autoplay_timer = Timer.new()
	_autoplay_timer.one_shot = true
	_autoplay_timer.timeout.connect(_on_autoplay_timer_timeout)
	add_child(_autoplay_timer)

	call_deferred("_recenter_board_view")
	call_deferred("_recenter_mini_board")
	call_deferred("_reset_sidebar_scroll")


func _build_world_backdrop(_parent: Control) -> void:
	pass # bg.png provides the environment; no overlay decorations needed


func _build_board_world_layer(parent: Control) -> void:
	var bg_tex := TextureRect.new()
	bg_tex.texture = BOARD_BG
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.modulate = Color(1.0, 1.0, 1.0, 0.9)
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg_tex)


func _make_world_rib(anchor_left_value: float, anchor_top_value: float, width_value: float, height_value: float, alpha_value: float) -> Control:
	var rib := Control.new()
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.anchor_left = anchor_left_value
	rib.anchor_top = anchor_top_value
	rib.anchor_right = anchor_left_value + width_value
	rib.anchor_bottom = anchor_top_value + height_value

	var body := ColorRect.new()
	body.color = Color(0.24, 0.32, 0.44, alpha_value)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.add_child(body)

	var edge := ColorRect.new()
	edge.color = Color(0.56, 0.72, 0.94, alpha_value * 0.55)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.anchor_left = 0.0
	edge.anchor_top = 0.0
	edge.anchor_right = 0.08
	edge.anchor_bottom = 1.0
	rib.add_child(edge)

	return rib


func _build_match_theme() -> Theme:
	var match_theme := Theme.new()
	match_theme.default_font = FONT_REGULAR
	match_theme.default_font_size = 16
	match_theme.set_font("font", "Label", FONT_REGULAR)
	match_theme.set_font("font", "Button", FONT_SEMIBOLD)
	match_theme.set_font("font", "ItemList", FONT_MEDIUM)
	match_theme.set_font("font", "RichTextLabel", FONT_REGULAR)
	match_theme.set_color("font_color", "Label", COLOR_TEXT)
	match_theme.set_color("font_color", "Button", COLOR_TEXT)
	match_theme.set_color("font_hover_color", "Button", Color.WHITE)
	match_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	match_theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	match_theme.set_color("font_placeholder_color", "Label", COLOR_TEXT_MUTED)
	match_theme.set_color("font_color", "ItemList", COLOR_TEXT)
	match_theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	match_theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	match_theme.set_color("guide_color", "RichTextLabel", COLOR_TEXT_MUTED)
	match_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	match_theme.set_color("font_color", "RichTextLabel", COLOR_TEXT)

	var item_list_style := _panel_style(COLOR_BORDER, COLOR_SURFACE)
	item_list_style.content_margin_left = 10.0
	item_list_style.content_margin_top = 8.0
	item_list_style.content_margin_right = 10.0
	item_list_style.content_margin_bottom = 8.0
	match_theme.set_stylebox("panel", "ItemList", item_list_style)

	var item_focus: StyleBoxFlat = item_list_style.duplicate() as StyleBoxFlat
	item_focus.border_color = COLOR_ACCENT
	match_theme.set_stylebox("focus", "ItemList", item_focus)

	return match_theme


func _make_panel_card(accent_color: Color, fill_color: Color = COLOR_SURFACE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(accent_color, fill_color))
	return panel


func _wrap_panel_content(panel: PanelContainer, horizontal_margin: int, vertical_margin: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_top", vertical_margin)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_bottom", vertical_margin)
	panel.add_child(margin)
	return margin


func _panel_style(accent_color: Color, fill_color: Color = COLOR_SURFACE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	return style


func _bar_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _make_section_title(title_text: String) -> Label:
	var label := Label.new()
	label.text = title_text.to_upper()
	label.add_theme_font_override("font", FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _make_section_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.9)
	divider.custom_minimum_size = Vector2(0, 2)
	return divider


func _make_faction_stat_box(accent: Color) -> PanelContainer:
	var panel := _make_panel_card(accent.darkened(0.35), COLOR_SURFACE_ALT)
	var margin := _wrap_panel_content(panel, 10, 6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	margin.add_child(col)
	var hp_lbl := Label.new()
	hp_lbl.add_theme_font_override("font", FONT_SEMIBOLD)
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(hp_lbl)
	var units_lbl := Label.new()
	units_lbl.add_theme_font_override("font", FONT_REGULAR)
	units_lbl.add_theme_font_size_override("font_size", 10)
	units_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	col.add_child(units_lbl)
	panel.set_meta("hp_label", hp_lbl)
	panel.set_meta("units_label", units_lbl)
	return panel


func _build_spectator_hud(parent: Control) -> void:
	_red_team_panel = _make_team_hud(2, "RED COMMAND", COLOR_P2)
	_red_team_panel.anchor_left = 0.0
	_red_team_panel.anchor_top = 0.0
	_red_team_panel.anchor_right = 0.0
	_red_team_panel.anchor_bottom = 0.0
	_red_team_panel.offset_left = 14
	_red_team_panel.offset_top = 14
	_red_team_panel.offset_right = 356
	_red_team_panel.offset_bottom = 154
	parent.add_child(_red_team_panel)
	_red_king_label = _red_team_panel.get_meta("king_label") as Label
	_red_queen_label = _red_team_panel.get_meta("queen_label") as Label

	_blue_team_panel = _make_team_hud(1, "BLUE COMMAND", COLOR_P1)
	_blue_team_panel.anchor_left = 1.0
	_blue_team_panel.anchor_top = 0.0
	_blue_team_panel.anchor_right = 1.0
	_blue_team_panel.anchor_bottom = 0.0
	_blue_team_panel.offset_left = -356
	_blue_team_panel.offset_top = 14
	_blue_team_panel.offset_right = -14
	_blue_team_panel.offset_bottom = 154
	parent.add_child(_blue_team_panel)
	_blue_king_label = _blue_team_panel.get_meta("king_label") as Label
	_blue_queen_label = _blue_team_panel.get_meta("queen_label") as Label

	_phase_chip_panel = _make_corner_chip(COLOR_GOLD)
	_phase_chip_panel.anchor_left = 0.0
	_phase_chip_panel.anchor_top = 1.0
	_phase_chip_panel.anchor_right = 0.0
	_phase_chip_panel.anchor_bottom = 1.0
	_phase_chip_panel.offset_left = 14
	_phase_chip_panel.offset_top = -70
	_phase_chip_panel.offset_right = 420
	_phase_chip_panel.offset_bottom = -14
	parent.add_child(_phase_chip_panel)
	_phase_chip_label = _phase_chip_panel.get_meta("label") as Label

	_actor_chip_panel = _make_corner_chip(COLOR_P1)
	_actor_chip_panel.anchor_left = 1.0
	_actor_chip_panel.anchor_top = 1.0
	_actor_chip_panel.anchor_right = 1.0
	_actor_chip_panel.anchor_bottom = 1.0
	_actor_chip_panel.offset_left = -360
	_actor_chip_panel.offset_top = -70
	_actor_chip_panel.offset_right = -14
	_actor_chip_panel.offset_bottom = -14
	parent.add_child(_actor_chip_panel)
	_actor_chip_label = _actor_chip_panel.get_meta("label") as Label


func _make_team_hud(_player_id: int, title_text: String, accent: Color) -> PanelContainer:
	var panel := _make_panel_card(accent, Color(0.04, 0.07, 0.12, 0.92))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _wrap_panel_content(panel, 14, 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.32))
	col.add_child(title)

	var king_label := _make_hud_line_label()
	col.add_child(king_label)
	var king_bar := _make_hud_health_bar(accent)
	col.add_child(king_bar)
	var queen_label := _make_hud_line_label()
	col.add_child(queen_label)
	var queen_bar := _make_hud_health_bar(accent)
	col.add_child(queen_bar)

	panel.set_meta("king_label", king_label)
	panel.set_meta("queen_label", queen_label)
	panel.set_meta("king_bar", king_bar)
	panel.set_meta("queen_bar", queen_bar)
	return panel


func _make_corner_chip(accent: Color) -> PanelContainer:
	var panel := _make_panel_card(accent, Color(0.04, 0.07, 0.12, 0.92))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _wrap_panel_content(panel, 14, 8)
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_BOLD)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.32))
	margin.add_child(label)
	panel.set_meta("label", label)
	return panel


func _make_hud_line_label() -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT_MEDIUM)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_hud_health_bar(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.step = 0.01
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.02, 0.03, 0.05, 0.78)))
	bar.add_theme_stylebox_override("fill", _bar_style(accent.lerp(Color("75df86"), 0.18)))
	return bar


func _make_body_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT_REGULAR)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _make_rich_body_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("normal_font", FONT_REGULAR)
	label.add_theme_font_size_override("normal_font_size", 15)
	label.add_theme_font_override("bold_font", FONT_MEDIUM)
	label.add_theme_font_size_override("bold_font_size", 15)
	label.add_theme_color_override("default_color", COLOR_TEXT)
	return label


func _make_action_button(text_value: String, accent_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value.to_upper()
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("accent_color", accent_color)
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_override("font_pressed", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)
	_apply_button_visual_state(button, accent_color, false)
	return button


func _make_modal_overlay(parent: Control, title_text: String, accent_color: Color, body_text: String) -> Control:
	var overlay := Control.new()
	overlay.visible = false
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.06, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := _make_panel_card(accent_color, COLOR_SURFACE_ALT)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	overlay.set_meta("panel", panel)
	overlay.set_meta("scrim", scrim)

	var margin := _wrap_panel_content(panel, 22, 20)
	var layout := VBoxContainer.new()
	layout.name = "ContentLayout"
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.2))
	layout.add_child(title)

	if body_text != "":
		var body := Label.new()
		body.text = body_text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_theme_font_override("font", FONT_MEDIUM)
		body.add_theme_font_size_override("font_size", 15)
		body.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		layout.add_child(body)

	overlay.set_meta("content_layout", layout)
	return overlay


func _make_overlay_button(text_value: String, callback: Callable, accent_color: Color, use_back_sound: bool = false) -> Button:
	var button := _make_action_button(text_value, accent_color)
	button.custom_minimum_size = Vector2(240, 48)
	button.pressed.connect(callback)
	_wire_button_audio(button, use_back_sound)
	return button


func _button_style(accent_color: Color, fill_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SURFACE_ALT.r, COLOR_SURFACE_ALT.g, COLOR_SURFACE_ALT.b, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color.lerp(COLOR_BORDER, 0.35)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 20.0
	style.content_margin_top = 10.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 10.0
	if fill_alpha > 0.0:
		style.bg_color = Color(
			lerpf(COLOR_SURFACE_ALT.r, accent_color.r, fill_alpha),
			lerpf(COLOR_SURFACE_ALT.g, accent_color.g, fill_alpha),
			lerpf(COLOR_SURFACE_ALT.b, accent_color.b, fill_alpha),
			1.0
		)
	return style


func _apply_button_visual_state(button: Button, accent_color: Color, active: bool) -> void:
	var normal_fill: float = 0.26 if not active else 0.40
	var hover_fill: float = 0.36 if not active else 0.48
	var pressed_fill: float = 0.44 if not active else 0.56
	var normal_style := _button_style(accent_color, normal_fill)
	var hover_style := _button_style(accent_color, hover_fill)
	var pressed_style := _button_style(accent_color, pressed_fill)
	normal_style.border_color = accent_color.lerp(Color.WHITE, 0.14)
	hover_style.border_color = accent_color.lerp(Color.WHITE, 0.24)
	pressed_style.border_color = accent_color.lerp(Color.WHITE, 0.32)
	normal_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	hover_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.24)
	pressed_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	if active:
		normal_style.border_color = accent_color
		hover_style.border_color = accent_color.lightened(0.08)
		pressed_style.border_color = accent_color.lightened(0.12)
		normal_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
		hover_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.26)
		pressed_style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
	button.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.28))
	button.add_theme_color_override("font_hover_color", accent_color.lerp(Color.WHITE, 0.6))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	if active:
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
	var disabled_style := _button_style(COLOR_BORDER, 0.04)
	disabled_style.border_color = COLOR_BORDER.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _refresh_view_legacy() -> void:
	_turn_label.text = "[b]Player %d's Turn[/b]" % [_game_state.current_player]
	_objective_label.text = "Turn %d" % _game_state.turn_count
	_score_label.text = "★ P1=%d  P2=%d" % [_control_score_for_player(1), _control_score_for_player(2)]
	_hp_summary_label.text = _hp_summary_text()
	_control_strip_label.text = "M=Move  A=Attack  P=Pass  Space=Step AI  Z=Auto  R=Reset  H=Guide"
	_map_label.text = _game_state.board.map_display_name
	_board_meta_label = null
	_board_hint_label = null
	_player_one_label = null
	_player_two_label = null
	_ai_label = null
	_explanation_label = null
	_preview_label = null
	_stats_label = null
	_post_match_label = null
	_guide_label = null
	_history_list = null
	_history_detail_label = null

	if _game_state.game_over:
		_status_label.text = "Game Over: %s" % _winner_label()
	elif _autoplay_enabled:
		_status_label.text = "Autoplay running at %s." % _speed_label()
	else:
		if _presentation_locked:
			_status_label.text = "Resolving action..."
		else:
			_status_label.text = "Selected: %s | Mode: %s" % [
				_actor_label(_selected_actor_id) if _selected_actor_id != "" else "None",
				_action_mode.capitalize() if _action_mode != "" else "None",
			]

	_board_view.set_game_state(_game_state)
	_board_view.set_selected_actor(_selected_actor_id)
	_board_view.set_action_mode(_action_mode)
	_board_view.set_highlighted_cells(_build_highlight_map())
	_mini_board_view.set_game_state(_game_state)
	_mini_board_view.set_selected_actor(_selected_actor_id)
	_mini_board_view.set_action_mode("")
	_mini_board_view.set_highlighted_cells({})
	_refresh_selected_unit_panel()
	_recenter_board_view()
	_recenter_mini_board()
	_refresh_event_log()
	_update_button_state()
	_autoplay_button.text = "Auto %s" % ("On" if _autoplay_enabled else "Off")
	_speed_button.text = _speed_button_label()


func _refresh_view() -> void:
	_sync_human_selection()
	_turn_label.text = "[b]TURN %d[/b]  [color=#334766]|[/color]  [b][color=#%s]%s[/color][/b]" % [
		_game_state.turn_count,
		"6bc7ff" if _game_state.current_player == 1 else "ff8a76",
		"BLUE COMMAND" if _game_state.current_player == 1 else "RED COMMAND",
	]
	_objective_label.text = _phase_text().to_upper()
	_faction_strip.color = COLOR_P1 if _game_state.current_player == 1 else COLOR_P2
	_score_label.text = "%d  :  %d" % [_control_score_for_player(1), _control_score_for_player(2)]
	_hp_summary_label.text = _hp_summary_text()
	_units_label.text = _remaining_units_text()
	_p1_stat_label.text = _player_stat_text(1)
	_p2_stat_label.text = _player_stat_text(2)
	if _p1_units_label != null:
		_p1_units_label.text = "UNITS  P1  %d/2" % _game_state.get_player_tanks(1).size()
	if _p2_units_label != null:
		_p2_units_label.text = "UNITS  P2  %d/2" % _game_state.get_player_tanks(2).size()
	_map_label.text = "Map: %s\nController: P1 %s | P2 %s\nAI turns play automatically." % [
		_game_state.board.map_display_name,
		_controller_label(AppState.current_match_config.player_one_ai.controller_type),
		_controller_label(AppState.current_match_config.player_two_ai.controller_type),
	]
	if _debug_panel != null:
		_debug_panel.visible = _debug_visible and not _pause_visible and not _result_visible
	var spectator_mode: bool = _both_players_are_ai()
	if _sidebar_scroll != null:
		_sidebar_scroll.visible = not spectator_mode
	if _command_panel != null:
		_command_panel.visible = not spectator_mode

	_preview_label.text = _battle_status_text()

	_board_view.set_game_state(_game_state)
	_board_view.set_selected_actor(_selected_actor_id)
	_board_view.set_action_mode(_action_mode)
	_board_view.set_highlighted_cells(_build_highlight_map())
	_mini_board_view.set_game_state(_game_state)
	_mini_board_view.set_selected_actor(_selected_actor_id)
	_mini_board_view.set_action_mode("")
	_mini_board_view.set_highlighted_cells({})
	_refresh_selected_unit_panel()
	_recenter_board_view()
	_recenter_mini_board()
	_refresh_event_log()
	_refresh_spectator_hud()
	_refresh_debug_panel()
	_refresh_result_overlay()
	_refresh_pause_overlay()
	_refresh_onboarding_overlay()
	_update_button_state()
	_autoplay_button.text = "Auto %s" % ("On" if _autoplay_enabled else "Off")
	_speed_button.text = _speed_button_label()
	_apply_playback_speed()
	_maybe_schedule_current_ai_turn()


func _sync_human_selection() -> void:
	if _game_state == null:
		return
	if _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		return
	if _selected_actor_id != "":
		var selected_tank: TankData = _game_state.get_tank(_selected_actor_id)
		if selected_tank != null and selected_tank.is_alive() and selected_tank.owner_id == _game_state.current_player:
			return
	for tank: TankData in _game_state.get_player_tanks(_game_state.current_player):
		if tank.is_alive():
			_selected_actor_id = tank.actor_id()
			return
	_selected_actor_id = ""


func _control_score_for_player(player_id: int) -> int:
	var center := HexCoord.new()
	var score: int = 0
	for tank: TankData in _game_state.get_player_tanks(player_id):
		if not tank.is_alive():
			continue
		score += maxi(0, 6 - tank.position.distance_to(center))
		if tank.tank_type == GameTypes.TankType.KTANK:
			score += 1
	return score


func _hp_summary_text() -> String:
	var p1k: TankData = _find_tank(1, GameTypes.TankType.KTANK)
	var p1q: TankData = _find_tank(1, GameTypes.TankType.QTANK)
	var p2k: TankData = _find_tank(2, GameTypes.TankType.KTANK)
	var p2q: TankData = _find_tank(2, GameTypes.TankType.QTANK)
	return "P1K %s/%s   P1Q %s/%s      P2K %s/%s   P2Q %s/%s" % [
		p1k.hp if p1k != null else 0,
		p1k.max_hp if p1k != null else 0,
		p1q.hp if p1q != null else 0,
		p1q.max_hp if p1q != null else 0,
		p2k.hp if p2k != null else 0,
		p2k.max_hp if p2k != null else 0,
		p2q.hp if p2q != null else 0,
		p2q.max_hp if p2q != null else 0,
	]


func _remaining_units_text() -> String:
	return "Units  P1 %d/2   P2 %d/2" % [_game_state.get_player_tanks(1).size(), _game_state.get_player_tanks(2).size()]


func _player_stat_text(player_id: int) -> String:
	var pk: TankData = _find_tank(player_id, GameTypes.TankType.KTANK)
	var pq: TankData = _find_tank(player_id, GameTypes.TankType.QTANK)
	return "P%dK %s/%s  P%dQ %s/%s" % [
		player_id, pk.hp if pk != null else "-", pk.max_hp if pk != null else "-",
		player_id, pq.hp if pq != null else "-", pq.max_hp if pq != null else "-",
	]


func _phase_text() -> String:
	var total_units: int = _game_state.get_player_tanks(1).size() + _game_state.get_player_tanks(2).size()
	if total_units <= 2:
		return "Endgame Phase"
	if _game_state.turn_count <= 5:
		return "Opening Phase"
	return "Midgame Phase"


func _battle_status_text() -> String:
	if _game_state == null:
		return "[b]READY[/b]\nLoading arena."
	if _game_state.game_over:
		return "[font_size=18][b]MATCH OVER[/b][/font_size]\n%s" % _winner_label()

	var side_name: String = "BLUE COMMAND" if _game_state.current_player == 1 else "RED COMMAND"
	var side_color: String = "6bc7ff" if _game_state.current_player == 1 else "ff8a76"
	var controller_name: String = _controller_label(_current_player_controller_type())
	var action_line: String = _activity_text
	if _presentation_locked:
		action_line = "Resolving action"
	elif _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		action_line = "%s is thinking" % controller_name
	elif _action_mode == "move":
		action_line = "Moving: choose a glowing hex"
	elif _action_mode == "attack":
		action_line = "Firing: choose a target lane"
	elif _selected_actor_id != "":
		action_line = "Waiting for command"

	return "[color=#%s][font_size=18][b]%s TURN[/b][/font_size][/color]\n%s\n[color=#9db0cc]%s[/color]" % [
		side_color,
		side_name,
		action_line,
		_phase_text(),
	]


func _refresh_spectator_hud() -> void:
	if _red_king_label == null:
		return
	_red_king_label.text = _team_unit_line(2, GameTypes.TankType.KTANK)
	_red_queen_label.text = _team_unit_line(2, GameTypes.TankType.QTANK)
	_blue_king_label.text = _team_unit_line(1, GameTypes.TankType.KTANK)
	_blue_queen_label.text = _team_unit_line(1, GameTypes.TankType.QTANK)
	_update_hud_health_bar(_red_team_panel, "king_bar", _find_tank(2, GameTypes.TankType.KTANK), COLOR_P2)
	_update_hud_health_bar(_red_team_panel, "queen_bar", _find_tank(2, GameTypes.TankType.QTANK), COLOR_P2)
	_update_hud_health_bar(_blue_team_panel, "king_bar", _find_tank(1, GameTypes.TankType.KTANK), COLOR_P1)
	_update_hud_health_bar(_blue_team_panel, "queen_bar", _find_tank(1, GameTypes.TankType.QTANK), COLOR_P1)

	if _phase_chip_label != null:
		_phase_chip_label.text = "%s | %s" % [_phase_text().to_upper(), _speed_label()]
	if _actor_chip_label != null:
		_actor_chip_label.text = _turn_actor_chip_text()
		var accent: Color = COLOR_P1 if _game_state.current_player == 1 else COLOR_P2
		_actor_chip_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.3))
		if _actor_chip_panel != null:
			_actor_chip_panel.add_theme_stylebox_override("panel", _panel_style(accent, Color(0.04, 0.07, 0.12, 0.92)))


func _update_hud_health_bar(panel: PanelContainer, meta_key: String, tank: TankData, accent: Color) -> void:
	if panel == null or not panel.has_meta(meta_key):
		return
	var bar: ProgressBar = panel.get_meta(meta_key) as ProgressBar
	if bar == null:
		return
	if tank == null:
		bar.max_value = 1.0
		bar.value = 0.0
		bar.modulate = Color(1.0, 1.0, 1.0, 0.38)
		bar.add_theme_stylebox_override("fill", _bar_style(Color(0.25, 0.3, 0.38, 0.42)))
		return
	var ratio: float = clampf(float(tank.hp) / maxf(float(tank.max_hp), 1.0), 0.0, 1.0)
	bar.max_value = maxf(float(tank.max_hp), 1.0)
	bar.value = maxf(float(tank.hp), 0.0)
	bar.modulate = Color.WHITE
	bar.add_theme_stylebox_override("fill", _bar_style(_hud_health_color(ratio, accent)))


func _hud_health_color(ratio: float, accent: Color) -> Color:
	if ratio <= 0.3:
		return Color("ff6673")
	if ratio <= 0.6:
		return Color("f0c94a")
	return accent.lerp(Color("75df86"), 0.28)


func _team_unit_line(player_id: int, tank_type: int) -> String:
	var role: String = "KING" if tank_type == GameTypes.TankType.KTANK else "QUEEN"
	var tank: TankData = _find_tank(player_id, tank_type)
	if tank == null:
		return "%s  DESTROYED" % role
	var buff_note := ""
	if tank.active_buff != GameTypes.BuffType.NONE:
		buff_note = "  BUFF %s" % _buff_label(tank.active_buff).to_upper()
	return "%s  %d/%d  %s%s" % [
		role,
		tank.hp,
		tank.max_hp,
		_tank_ability_label(tank_type),
		buff_note,
	]


func _tank_ability_label(tank_type: int) -> String:
	if tank_type == GameTypes.TankType.KTANK:
		return "CENTER BLAST"
	return "LANE LASER"


func _turn_actor_chip_text() -> String:
	if _game_state == null:
		return "READY"
	if _game_state.game_over:
		return "%s WINS" % _winner_label().to_upper()

	var tank: TankData = _game_state.get_tank(_active_actor_id)
	if tank == null and _selected_actor_id != "":
		tank = _game_state.get_tank(_selected_actor_id)

	var side: String = "BLUE" if _game_state.current_player == 1 else "RED"
	if tank == null:
		return "%s THINKING" % side if _current_player_controller_type() != GameTypes.ControllerType.HUMAN else "%s TURN" % side

	var role: String = "QUEEN" if tank.tank_type == GameTypes.TankType.QTANK else "KING"
	if _presentation_locked:
		if _activity_text.to_lower().contains("firing"):
			return "%s %s FIRING" % [side, role]
		if _activity_text.to_lower().contains("moving"):
			return "%s %s MOVING" % [side, role]
	return "%s %s READY" % [side, role]


func _build_highlight_map() -> Dictionary:
	var highlights: Dictionary = {}
	var selected_color: Color = Color("7bdcff") if AppState.high_contrast_mode else Color("69d2ff")
	var move_color: Color = Color("95ff5f") if AppState.high_contrast_mode else Color("57d477")
	var attack_color: Color = Color("ffb347") if AppState.high_contrast_mode else Color("ff6978")
	if _selected_actor_id == "":
		for tank: TankData in _game_state.get_player_tanks(_game_state.current_player):
			highlights[tank.position.key()] = selected_color
		return highlights

	var selected_tank: TankData = _game_state.get_tank(_selected_actor_id)
	if selected_tank != null:
		highlights[selected_tank.position.key()] = selected_color

	match _action_mode:
		"move":
			for coord: HexCoord in _game_state.get_legal_move_targets(_selected_actor_id):
				highlights[coord.key()] = move_color
		"attack":
			for coord: HexCoord in _game_state.get_legal_attack_targets(_selected_actor_id):
				highlights[coord.key()] = attack_color

	return highlights


func _refresh_event_log() -> void:
	var lines: Array[String] = []
	var turns: Array = AppState.current_replay.turns
	if turns.is_empty():
		_event_log.text = "[color=#8ea3bf]No actions taken yet.[/color]"
		return

	var start_index: int = maxi(0, turns.size() - 6)
	for turn_index in range(turns.size() - 1, start_index - 1, -1):
		var turn_data: Dictionary = turns[turn_index]
		var player_id: int = int(turn_data.get("player", 0))
		var player_color: String = "77b8ff" if player_id == 1 else "ff8a76"
		var events: Array = turn_data.get("events", [])
		for event_line: Variant in events:
			var clean_line: String = str(event_line).strip_edges()
			if clean_line == "":
				continue
			lines.append("[color=#%s]%s[/color]" % [player_color, clean_line])
	if lines.size() > 5:
		lines = lines.slice(lines.size() - 5, lines.size())

	_event_log.text = "\n".join(lines)


func _refresh_selected_unit_panel() -> void:
	var focus_tank: TankData = _current_focus_tank()
	if focus_tank == null:
		_selected_unit_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_BORDER, COLOR_SURFACE_ALT))
		_selected_model_name_label.text = "No active selection"
		_selected_model_name_label.add_theme_color_override("font_color", COLOR_TEXT)
		_selected_model_role_label.text = "Select a unit to inspect battlefield status."
		_selected_model_role_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		_selected_accent_strip.color = COLOR_BORDER
		_status_label.text = "[color=#9db0cc][font_size=11]Faction[/font_size][/color] [font_size=17][b]-[/b][/font_size]\n[color=#9db0cc][font_size=11]Integrity[/font_size][/color] [font_size=18][b]-[/b][/font_size]\n[color=#9db0cc][font_size=11]Mobility[/font_size][/color] [font_size=17][b]-[/b][/font_size]\n[color=#9db0cc][font_size=11]Strike[/font_size][/color] [font_size=17][b]-[/b][/font_size]\n[color=#9db0cc][font_size=11]Range[/font_size][/color] [font_size=17][b]-[/b][/font_size]\n[color=#9db0cc][font_size=11]Status[/font_size][/color] [font_size=17][b]-[/b][/font_size]"
		return

	var faction_color: Color = _faction_color(focus_tank.owner_id)
	var panel_fill: Color = COLOR_SURFACE_ALT.lerp(faction_color, 0.08)
	_selected_unit_panel.add_theme_stylebox_override("panel", _panel_style(faction_color, panel_fill))
	_selected_model_name_label.add_theme_color_override("font_color", faction_color.lerp(Color.WHITE, 0.28))
	_selected_model_role_label.add_theme_color_override("font_color", faction_color.lerp(COLOR_TEXT_MUTED, 0.42))
	_selected_model_name_label.text = _unit_card_name(focus_tank)
	_selected_model_role_label.text = _unit_role_text(focus_tank)
	_selected_accent_strip.color = faction_color
	_status_label.text = "[color=#9db0cc][font_size=11]Faction[/font_size][/color] [font_size=18][b]%s[/b][/font_size]\n[color=#9db0cc][font_size=11]Integrity[/font_size][/color] [font_size=19][b]%d / %d[/b][/font_size]\n[color=#9db0cc][font_size=11]Mobility[/font_size][/color] [font_size=18][b]%d hexes[/b][/font_size]\n[color=#9db0cc][font_size=11]Strike[/font_size][/color] [font_size=18][b]%d damage[/b][/font_size]\n[color=#9db0cc][font_size=11]Range[/font_size][/color] [font_size=18][b]%s[/b][/font_size]\n[color=#9db0cc][font_size=11]Status[/font_size][/color] [font_size=18][b]%s[/b][/font_size]" % [
		_faction_label(focus_tank.owner_id),
		focus_tank.hp,
		focus_tank.max_hp,
		focus_tank.get_move_range(),
		focus_tank.get_attack_damage(),
		_unit_range_text(focus_tank),
		_buff_label(focus_tank.active_buff),
	]


func _refresh_debug_panel() -> void:
	if _debug_label == null:
		return
	_debug_label.text = "Current Player: P%d\nAction Mode: %s\nDebug Auto: %s\nPresentation Locked: %s" % [
		_game_state.current_player,
		_action_mode if _action_mode != "" else "none",
		"On" if _autoplay_enabled else "Off",
		"Yes" if _presentation_locked else "No",
	]


func _format_event(event_item: GameEvent) -> String:
	match event_item.event_name:
		"move":
			return "%s moved to cover" % _actor_short_label(str(event_item.payload.get("actor_id", "")))
		"attack":
			return "%s opened fire" % _actor_short_label(str(event_item.payload.get("actor_id", "")))
		"hit_tank":
			return "%s took %s damage" % [_actor_short_label(str(event_item.payload.get("target", ""))), event_item.payload.get("damage", 0)]
		"hit_cell":
			if bool(event_item.payload.get("destroyed", false)):
				var revealed_type: int = int(event_item.payload.get("revealed_type", -1))
				if revealed_type != -1:
					return "%s revealed" % _cell_type_label(revealed_type).capitalize()
				return "A block broke apart"
			return ""
		"power_up":
			var buff_name: String = str(event_item.payload.get("buff", ""))
			var actor_label: String = _actor_short_label(str(event_item.payload.get("actor_id", "")))
			match buff_name:
				"attack_multiplier":
					return "%s secured the attack core" % actor_label
				"shield_buffer":
					return "%s secured the shield core" % actor_label
				"bonus_move":
					return "%s triggered the mobility core" % actor_label
				_:
					return "%s claimed an objective" % actor_label
		"extra_action_granted":
			return "%s gained a bonus action" % ("Blue" if int(event_item.payload.get("player", 0)) == 1 else "Red")
		"tank_destroyed":
			return "%s was destroyed" % _actor_short_label(str(event_item.payload.get("target", "")))
		"win_center":
			return "%s seized the center hex" % ("Blue" if int(event_item.payload.get("winner", 0)) == 1 else "Red")
		"win_ktank_destroyed":
			return "%s eliminated the enemy Ktank" % ("Blue" if int(event_item.payload.get("winner", 0)) == 1 else "Red")
		"draw_turn_limit":
			return "Turn limit reached"
		"draw_repetition":
			return "Repeated state detected"
		"pass":
			return "%s turn ended" % ("Blue" if int(event_item.payload.get("player", 0)) == 1 else "Red")
		"invalid_action":
			return ""
		_:
			return ""


func _update_button_state() -> void:
	var onboarding_blocking: bool = _onboarding_overlay != null and _onboarding_overlay.visible
	var is_human_turn: bool = _current_player_controller_type() == GameTypes.ControllerType.HUMAN
	var can_act: bool = is_human_turn and not _game_state.game_over and not _autoplay_enabled and not _presentation_locked and not _pause_visible and not _result_visible and not onboarding_blocking and _selected_actor_id != ""
	_move_button.disabled = not can_act
	_attack_button.disabled = not can_act
	_ability_button.disabled = true
	_pass_button.disabled = not is_human_turn or _game_state.game_over or _autoplay_enabled or _presentation_locked or _pause_visible or _result_visible or onboarding_blocking
	_reset_button.disabled = _presentation_locked or _pause_visible
	_ai_move_button.disabled = _game_state.game_over or _autoplay_enabled or _presentation_locked or _pause_visible or _result_visible or _current_player_controller_type() == GameTypes.ControllerType.HUMAN
	_autoplay_button.disabled = _game_state.game_over or _presentation_locked or _pause_visible or _result_visible or not _both_players_are_ai()
	_apply_button_visual_state(_move_button, _move_button.get_meta("accent_color"), _action_mode == "move" and not _move_button.disabled)
	_apply_button_visual_state(_attack_button, _attack_button.get_meta("accent_color"), _action_mode == "attack" and not _attack_button.disabled)
	_apply_button_visual_state(_ability_button, _ability_button.get_meta("accent_color"), false)
	_apply_button_visual_state(_pass_button, _pass_button.get_meta("accent_color"), false)
	_set_button_feedback_state(_move_button, false, false)
	_set_button_feedback_state(_attack_button, false, false)
	_set_button_feedback_state(_ability_button, false, false)
	_set_button_feedback_state(_pass_button, false, false)


func _on_board_cell_clicked(coord_key: String) -> void:
	if _presentation_locked:
		return
	if _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		return
	var coord: HexCoord = HexCoord.from_key(coord_key)
	var clicked_tank: TankData = _game_state.get_tank_at(coord)

	if clicked_tank != null and clicked_tank.owner_id == _game_state.current_player:
		var selection_changed: bool = _selected_actor_id != clicked_tank.actor_id()
		_selected_actor_id = clicked_tank.actor_id()
		_action_mode = ""
		if selection_changed:
			AudioManager.play_unit_select()
			if _board_view != null:
				_board_view.play_selection_feedback(_selected_actor_id)
			_pulse_control(_selected_unit_panel, 1.02, 0.16)
		_refresh_view()
		return

	if _selected_actor_id == "" or _action_mode == "" or _game_state.game_over:
		return

	match _action_mode:
		"move":
			_try_execute_move(coord)
		"attack":
			_try_execute_attack(coord)


func _try_execute_move(coord: HexCoord) -> void:
	for target: HexCoord in _game_state.get_legal_move_targets(_selected_actor_id):
		if target.equals(coord):
			var action: ActionData = ActionData.new(GameTypes.ActionType.MOVE, _selected_actor_id, coord.clone())
			_execute_action(action, "Human", _manual_explanation(action))
			return


func _try_execute_attack(coord: HexCoord) -> void:
	var action: ActionData = _game_state.build_attack_action(_selected_actor_id, coord)
	if action == null:
		return
	_execute_action(action, "Human", _manual_explanation(action))


func _after_action() -> void:
	_action_mode = ""
	if _selected_actor_id != "":
		var selected_tank: TankData = _game_state.get_tank(_selected_actor_id)
		if selected_tank == null or not selected_tank.is_alive() or selected_tank.owner_id != _game_state.current_player:
			_selected_actor_id = ""
	_refresh_view()


func _on_move_mode_pressed() -> void:
	if _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		return
	_sync_human_selection()
	if _selected_actor_id == "":
		return
	_debug_visible = false
	_action_mode = "move"
	_refresh_view()


func _on_attack_mode_pressed() -> void:
	if _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		return
	_sync_human_selection()
	if _selected_actor_id == "":
		return
	_debug_visible = false
	_action_mode = "attack"
	_refresh_view()


func _on_pass_pressed() -> void:
	if _current_player_controller_type() != GameTypes.ControllerType.HUMAN:
		return
	_debug_visible = false
	var action: ActionData = ActionData.new(GameTypes.ActionType.PASS)
	_execute_action(action, "Human", _manual_explanation(action))


func _on_reset_pressed() -> void:
	if _presentation_locked:
		return
	_debug_visible = false
	_disable_autoplay()
	_reset_match()
	_refresh_view()
	_show_phase_banner("MATCH RESET")


func _on_ai_move_pressed() -> void:
	_debug_visible = false
	_step_current_ai_turn()


func _on_autoplay_pressed() -> void:
	_debug_visible = false
	if _autoplay_enabled:
		_disable_autoplay()
	else:
		_enable_autoplay()
	_refresh_view()


func _on_speed_pressed() -> void:
	_change_autoplay_speed(1)


func _on_guide_pressed() -> void:
	_guide_visible = not _guide_visible
	_refresh_view()


func _on_autoplay_timer_timeout() -> void:
	if not _autoplay_enabled or _game_state.game_over:
		return
	if _current_player_controller_type() == GameTypes.ControllerType.HUMAN:
		_disable_autoplay()
		_refresh_view()
		return
	_step_current_ai_turn()
	if _autoplay_enabled and not _game_state.game_over:
		_schedule_autoplay()


func _step_current_ai_turn() -> void:
	if _presentation_locked:
		return
	_debug_visible = false
	var controller_type: int = _current_player_controller_type()
	if controller_type == GameTypes.ControllerType.HUMAN:
		return

	var config: AIConfig = _speed_adjusted_ai_config(_game_state.get_ai_config_for_player(_game_state.current_player))
	var result: Dictionary = _choose_ai_action(controller_type, config)
	var action: ActionData = result.get("action", ActionData.new(GameTypes.ActionType.PASS))
	var explanation: ActionExplanation = result.get("explanation", ActionExplanation.new())
	_execute_action(action, _controller_label(controller_type), explanation)


func _reset_match() -> void:
	_game_state = GameState.new(AppState.current_match_config.clone())
	_action_mode = ""
	_selected_actor_id = ""
	_active_actor_id = ""
	_activity_text = "Ready"
	_presentation_locked = false
	_debug_visible = false
	_pause_visible = false
	_result_visible = false
	_result_dismissed = false
	_onboarding_dismissed = false
	_auto_ai_pending = false
	if _startup_hint_panel != null:
		_startup_hint_panel.visible = false
		_startup_hint_panel.modulate = Color.WHITE
	if _board_view != null:
		_board_view.clear_transient_effects()
	AppState.last_action_explanation = ActionExplanation.new()
	AppState.current_replay.clear()
	AppState.current_replay.metadata = {
		"map_id": _game_state.board.map_id,
		"map_name": _game_state.board.map_display_name,
		"player_one_controller": _controller_label(AppState.current_match_config.player_one_ai.controller_type),
		"player_two_controller": _controller_label(AppState.current_match_config.player_two_ai.controller_type),
		"initial_state": _game_state.to_snapshot(),
	}
	call_deferred("_recenter_board_view")
	call_deferred("_show_startup_hint")


func _winner_label() -> String:
	if _game_state.winner == 0:
		return "Draw"
	return "Player %d" % _game_state.winner


func _actor_label(actor_id: String) -> String:
	if actor_id == "":
		return "None"
	var tank: TankData = _game_state.get_tank(actor_id)
	if tank == null:
		return actor_id
	var tank_name: String = "Qtank" if tank.tank_type == GameTypes.TankType.QTANK else "Ktank"
	return "P%d %s (%s HP)" % [tank.owner_id, tank_name, tank.hp]


func _actor_short_label(actor_id: String) -> String:
	if actor_id == "":
		return "Unit"
	var tank: TankData = _game_state.get_tank(actor_id)
	if tank == null:
		return actor_id
	var side_name: String = "Blue" if tank.owner_id == 1 else "Red"
	var tank_name: String = "Qtank" if tank.tank_type == GameTypes.TankType.QTANK else "Ktank"
	return "%s %s" % [side_name, tank_name]


func _on_back_pressed() -> void:
	_disable_autoplay()
	_transition_to(MENU_SCENE)


func _on_quit_pressed() -> void:
	_disable_autoplay()
	get_tree().quit()


func _on_board_holder_resized() -> void:
	_recenter_board_view()


func _recenter_mini_board() -> void:
	if _mini_board_view == null or _mini_board_holder == null:
		return

	var holder_size: Vector2 = _mini_board_holder.size
	if holder_size.x <= 0.0 or holder_size.y <= 0.0:
		return

	var visual_size: Vector2 = _mini_board_view.get_board_visual_size()
	var width_scale: float = holder_size.x / maxf(visual_size.x, 1.0)
	var height_scale: float = holder_size.y / maxf(visual_size.y, 1.0)
	var scale_factor: float = clampf(minf(width_scale, height_scale), 0.12, 0.24)
	_mini_board_view.scale = Vector2.ONE * scale_factor
	_mini_board_view.position = holder_size * 0.5


func _on_hover_summary_changed(summary: String) -> void:
	_hover_label.text = "Hover: %s" % summary


func _on_selected_summary_changed(summary: String) -> void:
	_selected_label.text = "Selected Tile: %s" % summary


func _play_turn_transition_feedback(next_player: int) -> void:
	if _top_panel == null:
		return
	_pulse_control(_top_panel, 1.012, 0.18)
	_pulse_label_color(_turn_label, COLOR_P1 if next_player == 1 else COLOR_P2)
	_show_phase_banner("%s TURN" % ("BLUE" if next_player == 1 else "RED"))


func _show_startup_hint() -> void:
	if _startup_hint_panel == null:
		return
	_startup_hint_panel.modulate = Color(1, 1, 1, 0)
	_startup_hint_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_startup_hint_panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.5)
	tween.tween_property(_startup_hint_panel, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if _startup_hint_panel != null:
			_startup_hint_panel.visible = false
	)


func _show_phase_banner(text_value: String) -> void:
	if _phase_banner_panel == null or _phase_banner_label == null:
		return
	_phase_banner_label.text = text_value
	_phase_banner_panel.visible = true
	_phase_banner_panel.modulate = Color(1, 1, 1, 0)
	_phase_banner_panel.scale = Vector2.ONE * 0.96
	var tween := create_tween()
	tween.tween_property(_phase_banner_panel, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_phase_banner_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.42)
	tween.tween_property(_phase_banner_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if _phase_banner_panel != null:
			_phase_banner_panel.visible = false
	)


func _refresh_pause_overlay() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = _pause_visible


func _toggle_pause_overlay(force_visible: bool = true) -> void:
	_pause_visible = force_visible
	if _pause_visible:
		_disable_autoplay()
		_debug_visible = false
	_refresh_pause_overlay()
	_refresh_view()


func _refresh_onboarding_overlay() -> void:
	if _onboarding_overlay == null:
		return
	var is_human_turn: bool = _game_state != null and _current_player_controller_type() == GameTypes.ControllerType.HUMAN
	_onboarding_overlay.visible = AppState.show_onboarding_hints and is_human_turn and not _onboarding_dismissed and not _game_state.game_over and AppState.current_replay.turns.is_empty() and not _pause_visible and not _result_visible


func _dismiss_onboarding(disable_forever: bool) -> void:
	_onboarding_dismissed = true
	if disable_forever:
		AppState.show_onboarding_hints = false
		AppState.save_preferences()
	if _onboarding_overlay != null:
		_onboarding_overlay.visible = false
	_refresh_view()


func _refresh_result_overlay() -> void:
	_result_visible = _game_state.game_over and not _result_dismissed
	if _result_overlay == null:
		return
	_result_overlay.visible = _result_visible
	if not _result_visible:
		return
	var winner_id: int = _game_state.winner
	var accent_color: Color = COLOR_GOLD if winner_id == 0 else (COLOR_P1 if winner_id == 1 else COLOR_P2)
	var winner_name: String = "Draw" if winner_id == 0 else ("Blue Command" if winner_id == 1 else "Red Command")
	var title_text: String = "TACTICAL DRAW" if winner_id == 0 else ("%s VICTORY" % winner_name.to_upper())
	var result_panel: PanelContainer = _result_overlay.get_meta("panel", null) as PanelContainer
	if result_panel != null:
		result_panel.custom_minimum_size = Vector2(520, 0)
		result_panel.add_theme_stylebox_override("panel", _panel_style(accent_color, Color(0.04, 0.07, 0.12, 0.96)))
	_result_title_label.text = title_text
	_result_title_label.add_theme_font_size_override("font_size", 40)
	_result_title_label.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.18))
	_result_title_label.add_theme_color_override("font_outline_color", Color(accent_color.r, accent_color.g, accent_color.b, 0.72))
	_result_title_label.add_theme_constant_override("outline_size", 2)
	_result_summary_label.text = "[center][color=#f0c94a][font_size=22][b]BATTLE REPORT[/b][/font_size][/color][/center]\n\n[color=#9db0cc]Winner[/color]\n[b]%s[/b]\n\n[color=#9db0cc]Turns Recorded[/color]\n[b]%d[/b]\n\n[color=#9db0cc]Map[/color]\n[b]%s[/b]\n\n%s" % [
		winner_name,
		AppState.current_replay.turns.size(),
		_game_state.board.map_display_name,
		ReplayAnalytics.format_summary_text(ReplayAnalytics.build_summary(AppState.current_replay)),
	]


func _hide_result_overlay() -> void:
	_result_dismissed = true
	_result_visible = false
	if _result_overlay != null:
		_result_overlay.visible = false


func _play_intro_transition() -> void:
	if _transition_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _transition_overlay != null:
			_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func _transition_to(scene_path: String) -> void:
	if _transition_overlay == null:
		get_tree().change_scene_to_file(scene_path)
		return
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)


func _open_settings_from_match() -> void:
	_disable_autoplay()
	_transition_to(SETTINGS_SCENE)


func _pulse_control(control: Control, peak_scale: float, duration: float) -> void:
	if control == null:
		return
	control.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * peak_scale, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _pulse_label_color(label: Control, accent_color: Color) -> void:
	if label == null:
		return
	label.modulate = accent_color.lerp(Color.WHITE, 0.32)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _cell_type_label(cell_type: int) -> String:
	match cell_type:
		GameTypes.CellType.EMPTY:
			return "Empty"
		GameTypes.CellType.CENTER:
			return "Center"
		GameTypes.CellType.WALL:
			return "Wall"
		GameTypes.CellType.BLOCK:
			return "Block"
		GameTypes.CellType.ARMOR_BLOCK:
			return "Armor Block"
		GameTypes.CellType.POWER_BLOCK:
			return "Power Block"
		GameTypes.CellType.POWER_ATTACK:
			return "Power Attack"
		GameTypes.CellType.POWER_SHIELD:
			return "Power Shield"
		GameTypes.CellType.POWER_BONUS_MOVE:
			return "Power Bonus Move"
		_:
			return "Unknown"


func _current_player_controller_type() -> int:
	return _game_state.get_ai_config_for_player(_game_state.current_player).controller_type


func _choose_ai_action(controller_type: int, config: AIConfig) -> Dictionary:
	match controller_type:
		GameTypes.ControllerType.MINIMAX:
			var minimax: MinimaxAI = MinimaxAI.new()
			return minimax.choose_action(_game_state, config)
		GameTypes.ControllerType.MCTS:
			var mcts: MctsAI = MctsAI.new()
			return mcts.choose_action(_game_state, config)
		_:
			return {
				"action": ActionData.new(GameTypes.ActionType.PASS),
				"explanation": ActionExplanation.new("", "No AI controller available for this player.", 0.0),
			}


func _execute_action(action: ActionData, source_label: String, explanation: ActionExplanation) -> void:
	if _presentation_locked:
		return
	_presentation_locked = true
	_activity_text = _action_activity_text(action, source_label)
	_active_actor_id = action.actor_id
	var acting_turn: int = _game_state.turn_count
	var acting_player: int = _game_state.current_player
	var previous_state: GameState = _game_state.clone()
	_game_state.apply_action(action)
	AudioManager.play_action_feedback(previous_state, _game_state, action, _game_state.last_events)
	_board_view.play_action_feedback(previous_state, _game_state, action, _game_state.last_events)
	if previous_state.current_player != _game_state.current_player:
		_play_turn_transition_feedback(_game_state.current_player)
	var feedback_hold: float = _board_view.get_feedback_hold_seconds(action, previous_state)
	if _game_state.game_over:
		_result_dismissed = false
		_disable_autoplay()
		AppState.current_replay.winner_label = _winner_label()
		AppState.current_replay.metadata["winner_label"] = AppState.current_replay.winner_label
		_show_phase_banner("MATCH RESOLVED")
	AppState.last_action_explanation = explanation
	EventBus.action_explanation_updated.emit(explanation)
	_record_turn_snapshot(acting_turn, acting_player, source_label, action, explanation)
	_refresh_view()
	await get_tree().create_timer(feedback_hold).timeout
	_presentation_locked = false
	_activity_text = "Ready"
	_after_action()


func _record_turn_snapshot(acting_turn: int, acting_player: int, source_label: String, action: ActionData, explanation: ActionExplanation) -> void:
	var event_lines: Array[String] = []
	var event_data: Array[Dictionary] = []
	for event_item: GameEvent in _game_state.last_events:
		event_lines.append(_format_event(event_item))
		event_data.append({
			"event_name": event_item.event_name,
			"payload": event_item.payload.duplicate(true),
		})

	var snapshot: Dictionary = {
		"turn": acting_turn,
		"player": acting_player,
		"source": source_label,
		"action_type": action.action_type,
		"actor_id": action.actor_id,
		"target": action.target_coord.key(),
		"summary": explanation.summary if explanation.summary != "" else _manual_summary(action),
		"score": explanation.score,
		"metrics": explanation.metrics.duplicate(true),
		"events": event_lines,
		"event_data": event_data,
		"state_hash": _game_state.get_state_hash(),
		"state_snapshot": _game_state.to_snapshot(),
	}
	AppState.current_replay.add_turn(snapshot)


func _refresh_history_panel() -> void:
	if _history_list == null:
		return

	var selected_items: PackedInt32Array = _history_list.get_selected_items()
	var previous_selected: int = selected_items[0] if selected_items.size() > 0 else -1
	_history_list.clear()
	for index in range(AppState.current_replay.turns.size()):
		var turn_data: Dictionary = AppState.current_replay.turns[index]
		var label: String = "T%d P%d %s" % [turn_data.get("turn", 0), turn_data.get("player", 0), turn_data.get("source", "Unknown")]
		_history_list.add_item(label)

	if AppState.current_replay.turns.is_empty():
		_history_detail_label.text = "History Detail: no turns recorded yet."
		return

	var selected_index: int = previous_selected
	if selected_index < 0 or selected_index >= AppState.current_replay.turns.size():
		selected_index = AppState.current_replay.turns.size() - 1
	_history_list.select(selected_index)
	_history_detail_label.text = _history_detail_text(selected_index)


func _on_history_item_selected(index: int) -> void:
	_history_detail_label.text = _history_detail_text(index)


func _history_detail_text(index: int) -> String:
	if index < 0 or index >= AppState.current_replay.turns.size():
		return "History Detail: no turn selected."

	var turn_data: Dictionary = AppState.current_replay.turns[index]
	var event_lines: Array[String] = []
	for event_line: Variant in turn_data.get("events", []):
		event_lines.append(str(event_line))
	var metrics_summary: String = "Score %.2f" % float(turn_data.get("score", 0.0))

	var events_text: String = "\n".join(event_lines)
	return "History Detail:\n%s\n%s\n%s" % [turn_data.get("summary", ""), metrics_summary, events_text]


func _manual_explanation(action: ActionData) -> ActionExplanation:
	return ActionExplanation.new(_actor_label(action.actor_id), _manual_summary(action), 0.0, {"source": "manual"})


func _manual_summary(action: ActionData) -> String:
	match action.action_type:
		GameTypes.ActionType.MOVE:
			return "Human moved %s to %s." % [_actor_label(action.actor_id), action.target_coord.key()]
		GameTypes.ActionType.ATTACK:
			return "Human attacked with %s." % _actor_label(action.actor_id)
		GameTypes.ActionType.PASS:
			return "Human passed the turn."
		_:
			return "Human action resolved."


func _action_activity_text(action: ActionData, source_label: String) -> String:
	var actor_text: String = _actor_label(action.actor_id)
	var source_text: String = source_label if source_label != "" else "Player"
	match action.action_type:
		GameTypes.ActionType.MOVE:
			return "%s moving %s" % [source_text, actor_text]
		GameTypes.ActionType.ATTACK:
			return "%s firing with %s" % [source_text, actor_text]
		GameTypes.ActionType.PASS:
			return "%s ending turn" % source_text
		_:
			return "%s resolving action" % source_text


func _enable_autoplay() -> void:
	if not _both_players_are_ai():
		return
	_autoplay_enabled = true
	_schedule_autoplay()


func _disable_autoplay() -> void:
	_autoplay_enabled = false
	if _autoplay_timer != null:
		_autoplay_timer.stop()


func _schedule_autoplay() -> void:
	if _autoplay_timer == null:
		return
	_autoplay_timer.stop()
	_autoplay_timer.wait_time = AUTOPLAY_SPEED_SECONDS[_autoplay_speed_index]
	_autoplay_timer.start()


func _maybe_schedule_current_ai_turn() -> void:
	if _auto_ai_pending:
		return
	if not _should_auto_play_current_turn():
		return
	_auto_ai_pending = true
	var think_delay: float = 0.22 / _current_playback_speed_scale()
	get_tree().create_timer(maxf(0.02, think_delay)).timeout.connect(_on_auto_ai_turn_timeout)


func _on_auto_ai_turn_timeout() -> void:
	_auto_ai_pending = false
	if _should_auto_play_current_turn():
		_step_current_ai_turn()


func _should_auto_play_current_turn() -> bool:
	if _game_state == null or _game_state.game_over:
		return false
	if _autoplay_enabled or _presentation_locked or _pause_visible or _result_visible:
		return false
	if _onboarding_overlay != null and _onboarding_overlay.visible:
		return false
	return _current_player_controller_type() != GameTypes.ControllerType.HUMAN


func _change_autoplay_speed(direction: int) -> void:
	_autoplay_speed_index = wrapi(_autoplay_speed_index + direction, 0, AUTOPLAY_SPEED_LABELS.size())
	_apply_playback_speed()
	if _autoplay_enabled:
		_schedule_autoplay()
	_show_phase_banner(_speed_label())
	_refresh_view()


func _speed_label() -> String:
	return "Speed %s x%.1f" % [AUTOPLAY_SPEED_LABELS[_autoplay_speed_index], _current_playback_speed_scale()]


func _speed_button_label() -> String:
	return "%s x%.1f" % [AUTOPLAY_SPEED_LABELS[_autoplay_speed_index], _current_playback_speed_scale()]


func _current_playback_speed_scale() -> float:
	return float(PLAYBACK_SPEED_SCALES[_autoplay_speed_index])


func _apply_playback_speed() -> void:
	var scale_value: float = _current_playback_speed_scale()
	if _board_view != null:
		_board_view.playback_speed_scale = scale_value
	if _mini_board_view != null:
		_mini_board_view.playback_speed_scale = scale_value


func _speed_adjusted_ai_config(config: AIConfig) -> AIConfig:
	var adjusted: AIConfig = config.clone()
	var scale_value: float = _current_playback_speed_scale()
	if scale_value <= 1.0:
		return adjusted

	adjusted.time_budget_ms = maxi(80, int(ceil(float(adjusted.time_budget_ms) / scale_value)))
	adjusted.rollout_limit = maxi(8, int(ceil(float(adjusted.rollout_limit) / scale_value)))
	if scale_value >= 3.5:
		adjusted.search_depth = maxi(2, int(ceil(float(adjusted.search_depth) / minf(scale_value, 4.0))))
	elif scale_value >= 1.8:
		adjusted.search_depth = maxi(3, adjusted.search_depth - 1)
	return adjusted


func _both_players_are_ai() -> bool:
	return AppState.current_match_config.player_one_ai.controller_type != GameTypes.ControllerType.HUMAN and AppState.current_match_config.player_two_ai.controller_type != GameTypes.ControllerType.HUMAN


func _ai_status_text() -> String:
	var p1_type: String = _controller_label(AppState.current_match_config.player_one_ai.controller_type)
	var p2_type: String = _controller_label(AppState.current_match_config.player_two_ai.controller_type)
	var current_type: String = _controller_label(_game_state.get_ai_config_for_player(_game_state.current_player).controller_type)
	return "Controllers: P1 %s | P2 %s\nCurrent Turn: %s\nAuto AI: Z toggles autoplay | X changes speed | %s\nHigher speeds shorten animation holds and AI thinking budgets." % [p1_type, p2_type, current_type, _speed_label()]


func _explanation_text() -> String:
	if AppState.last_action_explanation.summary == "":
		match _current_player_controller_type():
			GameTypes.ControllerType.MINIMAX:
				return "AI Explanation: Minimax is ready for the current player."
			GameTypes.ControllerType.MCTS:
				return "AI Explanation: MCTS is ready for the current player."
			_:
				return "AI Explanation: Current player is human-controlled."

	if str(AppState.last_action_explanation.summary).begins_with("MCTS"):
		return "AI Explanation: %s\nScore %.2f" % [
			AppState.last_action_explanation.summary,
			AppState.last_action_explanation.score,
		]

	return "AI Explanation: %s\nScore %.2f" % [
		AppState.last_action_explanation.summary,
		AppState.last_action_explanation.score,
	]


func _stats_text() -> String:
	var total_turns: int = AppState.current_replay.turns.size()
	if total_turns == 0:
		return "Arena Stats: no recorded turns yet.\nAlgorithm turns begin automatically.\nAccessibility: UI %.2fx | Motion %s | Contrast %s" % [
			AppState.ui_scale,
			"Reduced" if AppState.reduced_motion else "Standard",
			"High" if AppState.high_contrast_mode else "Standard",
		]

	var latest: Dictionary = AppState.current_replay.turns[total_turns - 1]
	var analytics: Dictionary = ReplayAnalytics.build_summary(AppState.current_replay)
	var damage_bucket: Dictionary = analytics.get("player_damage", {})
	return "Arena Stats: %d recorded turns\nLatest: T%d P%d via %s\nState Hash: %s\nDamage P1/P2: %d / %d\nAccessibility: UI %.2fx | Motion %s | Contrast %s" % [
		total_turns,
		latest.get("turn", 0),
		latest.get("player", 0),
		latest.get("source", "Unknown"),
		latest.get("state_hash", ""),
		int(damage_bucket.get(1, 0)),
		int(damage_bucket.get(2, 0)),
		AppState.ui_scale,
		"Reduced" if AppState.reduced_motion else "Standard",
		"High" if AppState.high_contrast_mode else "Standard",
	]


func _post_match_text() -> String:
	if not _game_state.game_over:
		return ""
	return "Post-Match Summary:\n%s" % ReplayAnalytics.format_summary_text(ReplayAnalytics.build_summary(AppState.current_replay))


func _objective_text() -> String:
	return "[color=#9db0cc]Primary Goal[/color]\n[b]Destroy the enemy Ktank or occupy the center hex.[/b]"


func _player_summary_text(player_id: int) -> String:
	var controller_type: int = _game_state.get_ai_config_for_player(player_id).controller_type
	var summary_lines: Array[String] = []
	summary_lines.append("%s pilot stack" % _controller_label(controller_type))

	var ktank: TankData = _find_tank(player_id, GameTypes.TankType.KTANK)
	var qtank: TankData = _find_tank(player_id, GameTypes.TankType.QTANK)
	if ktank != null:
		summary_lines.append("Ktank %s HP | Center %d | %s" % [ktank.hp, ktank.position.distance_to(HexCoord.new()), _buff_label(ktank.active_buff)])
	if qtank != null:
		summary_lines.append("Qtank %s HP | %s" % [qtank.hp, _buff_label(qtank.active_buff)])

	var total_hp: int = 0
	for tank: TankData in _game_state.get_player_tanks(player_id):
		total_hp += tank.hp
	summary_lines.append("Total %d HP%s" % [total_hp, " | Initiative" if _game_state.current_player == player_id else ""])
	return "\n".join(summary_lines)


func _preview_text() -> String:
	if _autoplay_enabled:
		return "Spectator mode is active at %s. Press X to cycle speed while the AIs play." % _speed_label()

	if _selected_actor_id == "":
		return "Select a tank to bring up tactical options. Qtanks dominate lines. Ktanks crack adjacent hexes and convert center pressure into instant wins."

	var tank: TankData = _game_state.get_tank(_selected_actor_id)
	if tank == null:
		return "Preview: Selected tank is no longer available."

	var tank_name: String = "Qtank" if tank.tank_type == GameTypes.TankType.QTANK else "Ktank"
	var move_count: int = _game_state.get_legal_move_targets(_selected_actor_id).size()
	var attack_count: int = _game_state.get_legal_attack_targets(_selected_actor_id).size()
	var base_text: String = "%s | %s HP | %s | %d moves | %d attack targets." % [tank_name, tank.hp, _buff_label(tank.active_buff), move_count, attack_count]

	match _action_mode:
		"move":
			var can_reach_center: bool = false
			for coord: HexCoord in _game_state.get_legal_move_targets(_selected_actor_id):
				if coord.q == 0 and coord.r == 0:
					can_reach_center = true
					break
			return "%s Move mode engaged.%s" % [base_text, " Center is reachable this turn." if can_reach_center else ""]
		"attack":
			return "%s Attack mode engaged. Highlighted hexes show the live threat lane." % base_text
		_:
			return "%s Choose Move, Attack, or Pass." % base_text


func _guide_text() -> String:
	return "Quick Guide:\n- Center wins instantly for a Ktank, so mid-board tempo matters from turn one.\n- Qtank lasers stop at the first tank or blocking cell, making line control the core spacing puzzle.\n- Ktank attacks every adjacent hex, including allies, so heavy pressure can backfire.\n- Z toggles AI-vs-AI autoplay. X cycles playback speed from Slow through Instant.\n- Standard flow is one action per turn. Bonus Move is the main exception.\n- Minimax usually excels in sharp tactical fights. MCTS becomes more dangerous on larger, noisier maps."


func _current_focus_tank() -> TankData:
	if _selected_actor_id != "":
		var selected_tank: TankData = _game_state.get_tank(_selected_actor_id)
		if selected_tank != null and selected_tank.is_alive():
			return selected_tank

	for tank: TankData in _game_state.get_player_tanks(_game_state.current_player):
		if tank.is_alive():
			return tank
	return null


func _unit_card_name(tank: TankData) -> String:
	var unit_symbol: String = "[Q]" if tank.tank_type == GameTypes.TankType.QTANK else "[K]"
	var unit_name: String = "Qtank" if tank.tank_type == GameTypes.TankType.QTANK else "Ktank"
	return "%s %s %s" % [_faction_label(tank.owner_id), unit_symbol, unit_name]


func _unit_role_text(tank: TankData) -> String:
	if tank.tank_type == GameTypes.TankType.QTANK:
		return "Control Chassis  |  Long-lane striker"
	return "Siege Vanguard  |  Armored center breaker"


func _faction_color(player_id: int) -> Color:
	return COLOR_P1 if player_id == 1 else COLOR_P2


func _faction_label(player_id: int) -> String:
	return "Blue Command" if player_id == 1 else "Red Command"


func _unit_range_text(tank: TankData) -> String:
	if tank.tank_type == GameTypes.TankType.QTANK:
		return "Long lane"
	return "Blast radius 1"


func _find_tank(player_id: int, tank_type: int) -> TankData:
	for tank: TankData in _game_state.get_all_tanks():
		if tank.owner_id == player_id and tank.tank_type == tank_type and tank.is_alive():
			return tank
	return null


func _buff_label(buff_type: int) -> String:
	match buff_type:
		GameTypes.BuffType.ATTACK_MULTIPLIER:
			return "Attack Buff"
		GameTypes.BuffType.SHIELD_BUFFER:
			return "Shield Buff"
		GameTypes.BuffType.BONUS_MOVE:
			return "Bonus Move"
		_:
			return "No Buff"


func _controller_label(controller_type: int) -> String:
	match controller_type:
		GameTypes.ControllerType.HUMAN:
			return "Human"
		GameTypes.ControllerType.MINIMAX:
			return "Minimax"
		GameTypes.ControllerType.MCTS:
			return "MCTS"
		_:
			return "Unknown"


func _recenter_board_view() -> void:
	if _board_view == null or _board_holder == null:
		return

	var holder_size: Vector2 = _board_holder.size
	if holder_size.x <= 0.0 or holder_size.y <= 0.0:
		return

	var visual_size: Vector2 = _board_view.get_board_visual_size()
	var width_scale: float = holder_size.x / maxf(visual_size.x, 1.0)
	var height_scale: float = holder_size.y / maxf(visual_size.y, 1.0)
	var scale_factor: float = clampf(minf(width_scale, height_scale) * 1.22, 0.1, 2.7)
	_board_view.scale = Vector2.ONE * scale_factor
	_board_view.position = Vector2(holder_size.x * 0.5, holder_size.y * 0.492)


func _reset_sidebar_scroll() -> void:
	if _sidebar_scroll != null:
		_sidebar_scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if _onboarding_overlay != null and _onboarding_overlay.visible:
		if event.keycode == KEY_ESCAPE:
			_dismiss_onboarding(false)
			accept_event()
		return
	if _result_visible:
		if event.keycode == KEY_ESCAPE:
			_hide_result_overlay()
			accept_event()
		return

	match event.keycode:
		KEY_ESCAPE:
			_toggle_pause_overlay(not _pause_visible)
			accept_event()
		KEY_M:
			if not _pause_visible and not _move_button.disabled:
				_on_move_mode_pressed()
				accept_event()
		KEY_A:
			if not _pause_visible and not _attack_button.disabled:
				_on_attack_mode_pressed()
				accept_event()
		KEY_P:
			if not _pause_visible and not _pass_button.disabled:
				_on_pass_pressed()
				accept_event()
		KEY_SPACE:
			if not _pause_visible and not _ai_move_button.disabled:
				_on_ai_move_pressed()
				accept_event()
		KEY_Z:
			if not _pause_visible and not _autoplay_button.disabled:
				_on_autoplay_pressed()
				accept_event()
		KEY_X:
			if not _pause_visible and not _game_state.game_over:
				_change_autoplay_speed(1)
				accept_event()
		KEY_R:
			if not _pause_visible and not _presentation_locked:
				_on_reset_pressed()
				accept_event()
		KEY_H:
			_transition_to(HELP_SCENE)
			accept_event()


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var is_f3: bool = key_event.keycode == KEY_F3 or key_event.physical_keycode == KEY_F3
	if not is_f3:
		return
	_debug_visible = false
	_refresh_view()
	accept_event()


func _wire_button_audio(button: Button, use_back_sound: bool = false) -> void:
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
	)
	button.mouse_entered.connect(func() -> void:
		AudioManager.play_ui_hover()
		_set_button_feedback_state(button, true, false)
	)
	button.mouse_exited.connect(func() -> void:
		_set_button_feedback_state(button, false, false)
	)
	button.button_down.connect(func() -> void:
		_set_button_feedback_state(button, true, true)
	)
	button.button_up.connect(func() -> void:
		_set_button_feedback_state(button, true, false)
	)
	if use_back_sound:
		button.pressed.connect(AudioManager.play_ui_back)
	else:
		button.pressed.connect(AudioManager.play_ui_click)


func _set_button_feedback_state(button: Button, hovered: bool, pressed: bool) -> void:
	if button == null:
		return
	if button.disabled:
		button.scale = Vector2.ONE
		button.modulate = Color(0.72, 0.78, 0.88, 0.9)
		return
	var target_scale: Vector2 = Vector2.ONE
	var target_modulate: Color = Color.WHITE
	if hovered:
		target_scale = Vector2.ONE * 1.015
		target_modulate = Color(1.06, 1.06, 1.06, 1.0)
	if pressed:
		target_scale = Vector2.ONE * 0.992
		target_modulate = Color(0.92, 0.92, 0.92, 1.0)
	button.scale = target_scale
	button.modulate = target_modulate
