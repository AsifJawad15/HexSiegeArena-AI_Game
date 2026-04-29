extends Control

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const HOME_BG_PATH := "res://assets/ui/home_background.png"
const FONT_REGULAR := preload("res://assets/fonts/space_grotesk/SpaceGrotesk-Regular.ttf")
const FONT_MEDIUM := preload("res://assets/fonts/space_grotesk/SpaceGrotesk-Medium.ttf")
const FONT_SEMIBOLD := preload("res://assets/fonts/space_grotesk/SpaceGrotesk-SemiBold.ttf")
const FONT_BOLD := preload("res://assets/fonts/space_grotesk/SpaceGrotesk-Bold.ttf")
const COLOR_BG := Color("09111c")
const COLOR_SURFACE := Color("111c2b")
const COLOR_SURFACE_ALT := Color("162335")
const COLOR_BORDER := Color("2c3f59")
const COLOR_TEXT := Color("edf4ff")
const COLOR_TEXT_MUTED := Color("98adc7")
const COLOR_GOLD := Color("f0c05e")
const COLOR_P1 := Color("77b8ff")
const COLOR_P2 := Color("ff8a76")
const COLOR_GREEN := Color("69dd8e")

var _play_button: Button
var _step_button: Button
var _restart_button: Button
var _turn_list: ItemList
var _summary_label: Label
var _analytics_label: Label
var _detail_label: Label
var _board_view: BoardDebugView
var _board_holder: Control
var _timer: Timer
var _current_index: int = -1
var _autoplay_enabled: bool = false
var _transition_overlay: ColorRect


func _ready() -> void:
	AppState.apply_window_preferences(self)
	AudioManager.play_menu_music()
	theme = _build_theme()
	_build_layout()
	_refresh_replay()
	call_deferred("_play_intro_transition")


func _build_layout() -> void:
	var background := TextureRect.new()
	background.texture = _load_home_background()
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.44)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 22)
	root_margin.add_theme_constant_override("margin_top", 18)
	root_margin.add_theme_constant_override("margin_right", 22)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(center)

	var shell := VBoxContainer.new()
	shell.custom_minimum_size = Vector2(1080, 0)
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_theme_constant_override("separation", 12)
	center.add_child(shell)

	var title := Label.new()
	title.text = "REPLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	shell.add_child(title)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_override("font", FONT_MEDIUM)
	_summary_label.add_theme_font_size_override("font_size", 15)
	_summary_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	shell.add_child(_summary_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	shell.add_child(controls)

	_play_button = _make_button("Play", _on_play_pressed, COLOR_GOLD)
	controls.add_child(_play_button)
	_step_button = _make_button("Step", _on_step_pressed, COLOR_P1)
	controls.add_child(_step_button)
	_restart_button = _make_button("Restart", _on_restart_pressed, COLOR_GREEN)
	controls.add_child(_restart_button)
	controls.add_child(_make_button("Menu", _on_back_pressed, COLOR_P2, true))

	var board_panel := _make_panel_card(COLOR_P1, Color(0.04, 0.07, 0.12, 0.82))
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(board_panel)
	var board_margin := _wrap_panel_content(board_panel, 10, 10)

	_board_holder = Control.new()
	_board_holder.custom_minimum_size = Vector2(0, 520)
	_board_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_holder.clip_contents = false
	_board_holder.resized.connect(_on_board_holder_resized)
	board_margin.add_child(_board_holder)

	_board_view = BoardDebugView.new()
	_board_view.hex_size = 46.0
	_board_view.set_interaction_enabled(false)
	_board_holder.add_child(_board_view)

	var bottom_row := HBoxContainer.new()
	bottom_row.custom_minimum_size = Vector2(0, 170)
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 12)
	shell.add_child(bottom_row)

	_turn_list = ItemList.new()
	_turn_list.custom_minimum_size = Vector2(340, 0)
	_turn_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_turn_list.item_selected.connect(_on_turn_selected)
	bottom_row.add_child(_turn_list)

	var detail_panel := _make_panel_card(COLOR_BORDER, Color(0.05, 0.08, 0.13, 0.80))
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(detail_panel)
	var detail_margin := _wrap_panel_content(detail_panel, 14, 12)
	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_override("font", FONT_MEDIUM)
	_detail_label.add_theme_font_size_override("font_size", 14)
	detail_margin.add_child(_detail_label)

	_analytics_label = Label.new()
	_analytics_label.visible = false
	add_child(_analytics_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.03, 0.05, 0.09, 1.0)
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_overlay)


func _build_legacy_layout() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_top", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(root_margin)

	var root_layout := VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 20)
	root_margin.add_child(root_layout)

	var hero_panel := _make_panel_card(COLOR_GOLD, COLOR_SURFACE_ALT)
	root_layout.add_child(hero_panel)
	var hero_margin := _wrap_panel_content(hero_panel, 28, 24)
	var hero_layout := HBoxContainer.new()
	hero_layout.add_theme_constant_override("separation", 24)
	hero_margin.add_child(hero_layout)

	var hero_left := VBoxContainer.new()
	hero_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_left.add_theme_constant_override("separation", 8)
	hero_layout.add_child(hero_left)

	var eyebrow := Label.new()
	eyebrow.text = "REPLAY AND ANALYTICS"
	eyebrow.add_theme_font_override("font", FONT_SEMIBOLD)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", COLOR_GOLD)
	hero_left.add_child(eyebrow)

	var title := Label.new()
	title.text = "Replay Viewer"
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	hero_left.add_child(title)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_override("font", FONT_MEDIUM)
	_summary_label.add_theme_font_size_override("font_size", 16)
	_summary_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hero_left.add_child(_summary_label)

	var hero_right := _make_panel_card(COLOR_P1, COLOR_SURFACE)
	hero_right.custom_minimum_size = Vector2(380, 0)
	hero_layout.add_child(hero_right)
	var hero_right_margin := _wrap_panel_content(hero_right, 20, 18)
	var hero_right_layout := VBoxContainer.new()
	hero_right_layout.add_theme_constant_override("separation", 8)
	hero_right_margin.add_child(hero_right_layout)
	hero_right_layout.add_child(_make_section_heading("Analytics Snapshot"))

	_analytics_label = Label.new()
	_analytics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_analytics_label.add_theme_font_override("font", FONT_MEDIUM)
	_analytics_label.add_theme_font_size_override("font_size", 15)
	hero_right_layout.add_child(_analytics_label)

	var controls_panel := _make_panel_card(COLOR_BORDER.lightened(0.1), COLOR_SURFACE)
	root_layout.add_child(controls_panel)
	var controls_margin := _wrap_panel_content(controls_panel, 20, 18)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	controls_margin.add_child(controls)

	_play_button = _make_button("Play", _on_play_pressed, COLOR_GOLD)
	controls.add_child(_play_button)
	_step_button = _make_button("Step", _on_step_pressed, COLOR_P1)
	controls.add_child(_step_button)
	_restart_button = _make_button("Restart", _on_restart_pressed, COLOR_GREEN)
	controls.add_child(_restart_button)
	controls.add_child(_make_button("Back To Menu", _on_back_pressed, COLOR_P2, true))

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	root_layout.add_child(content)

	var left_panel := _make_panel_card(COLOR_P1, COLOR_SURFACE)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(left_panel)

	var left_margin := _wrap_panel_content(left_panel, 18, 18)
	var left_layout := VBoxContainer.new()
	left_layout.add_theme_constant_override("separation", 12)
	left_margin.add_child(left_layout)

	left_layout.add_child(_make_section_heading("Board Replay"))

	_board_holder = Control.new()
	_board_holder.custom_minimum_size = Vector2(0, 420)
	_board_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_holder.clip_contents = true
	_board_holder.resized.connect(_on_board_holder_resized)
	left_layout.add_child(_board_holder)

	_board_view = BoardDebugView.new()
	_board_view.set_interaction_enabled(false)
	_board_holder.add_child(_board_view)

	left_layout.add_child(_make_section_heading("Replay Timeline"))

	_turn_list = ItemList.new()
	_turn_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_turn_list.custom_minimum_size = Vector2(0, 280)
	_turn_list.item_selected.connect(_on_turn_selected)
	left_layout.add_child(_turn_list)

	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(430, 0)
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(right_scroll)

	var right_panel := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	right_panel.custom_minimum_size = Vector2(410, 0)
	right_scroll.add_child(right_panel)

	var right_margin := _wrap_panel_content(right_panel, 18, 18)
	var right_layout := VBoxContainer.new()
	right_layout.add_theme_constant_override("separation", 10)
	right_margin.add_child(right_layout)
	right_layout.add_child(_make_section_heading("Turn Detail"))

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_override("font", FONT_MEDIUM)
	_detail_label.add_theme_font_size_override("font_size", 15)
	right_layout.add_child(_detail_label)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.03, 0.05, 0.09, 1.0)
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_overlay)


func _build_theme() -> Theme:
	var theme_data := Theme.new()
	theme_data.default_font = FONT_REGULAR
	theme_data.default_font_size = 16
	theme_data.set_font("font", "Label", FONT_REGULAR)
	theme_data.set_font("font", "Button", FONT_SEMIBOLD)
	theme_data.set_font("font", "ItemList", FONT_MEDIUM)
	theme_data.set_color("font_color", "Label", COLOR_TEXT)
	theme_data.set_color("font_color", "Button", COLOR_TEXT)
	theme_data.set_color("font_color", "ItemList", COLOR_TEXT)
	theme_data.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme_data.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme_data.set_color("font_hover_color", "Button", Color.WHITE)
	theme_data.set_color("font_pressed_color", "Button", Color.WHITE)
	theme_data.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)

	var item_list_style := StyleBoxFlat.new()
	item_list_style.bg_color = COLOR_SURFACE
	item_list_style.corner_radius_top_left = 12
	item_list_style.corner_radius_top_right = 12
	item_list_style.corner_radius_bottom_left = 12
	item_list_style.corner_radius_bottom_right = 12
	item_list_style.border_width_left = 1
	item_list_style.border_width_top = 1
	item_list_style.border_width_right = 1
	item_list_style.border_width_bottom = 1
	item_list_style.border_color = COLOR_BORDER
	item_list_style.content_margin_left = 10.0
	item_list_style.content_margin_top = 8.0
	item_list_style.content_margin_right = 10.0
	item_list_style.content_margin_bottom = 8.0
	theme_data.set_stylebox("panel", "ItemList", item_list_style)
	theme_data.set_stylebox("focus", "ItemList", item_list_style)

	return theme_data


func _make_button(text: String, callback: Callable, accent_color: Color, use_back_sound: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_style(accent_color, 0.10))
	button.add_theme_stylebox_override("hover", _button_style(accent_color, 0.18))
	button.add_theme_stylebox_override("pressed", _button_style(accent_color, 0.24))
	button.add_theme_stylebox_override("disabled", _button_style(COLOR_BORDER, 0.04))
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_MUTED)
	button.mouse_entered.connect(AudioManager.play_ui_hover)
	button.pressed.connect(func() -> void:
		if use_back_sound:
			AudioManager.play_ui_back()
		else:
			AudioManager.play_ui_click()
		callback.call()
	)
	return button


func _load_home_background() -> Texture2D:
	return ResourceLoader.load(HOME_BG_PATH, "Texture2D") as Texture2D


func _make_panel_card(accent_color: Color, fill_color: Color) -> PanelContainer:
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


func _panel_style(accent_color: Color, fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color.lerp(COLOR_BORDER, 0.58)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 10
	return style


func _button_style(accent_color: Color, fill_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, fill_alpha)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 5
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style


func _make_section_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _refresh_replay() -> void:
	var replay: ReplayRecord = AppState.current_replay
	var map_name: String = str(replay.metadata.get("map_name", "Unknown Map"))
	var p1_label: String = str(replay.metadata.get("player_one_controller", "Unknown"))
	var p2_label: String = str(replay.metadata.get("player_two_controller", "Unknown"))
	_summary_label.text = "Map %s  |  P1 %s  |  P2 %s  |  Turns %d  |  Winner %s" % [
		map_name,
		p1_label,
		p2_label,
		replay.turns.size(),
		replay.winner_label if replay.winner_label != "" else "Pending",
	]
	_analytics_label.text = ReplayAnalytics.format_summary_text(ReplayAnalytics.build_summary(replay))

	_turn_list.clear()
	if replay.turns.is_empty() and not replay.metadata.has("initial_state"):
		_detail_label.text = "No replay data yet. Finish a match first, then come back here to review the timeline and analytics."
		_analytics_label.text = ""
		_play_button.disabled = true
		_step_button.disabled = true
		_restart_button.disabled = true
		return

	_play_button.disabled = false
	_step_button.disabled = false
	_restart_button.disabled = false
	_turn_list.add_item("Start State")
	for index in range(replay.turns.size()):
		var turn_data: Dictionary = replay.turns[index]
		_turn_list.add_item("T%d P%d %s" % [int(turn_data.get("turn", 0)), int(turn_data.get("player", 0)), str(turn_data.get("source", "Unknown"))])
	_select_index(clampi(_current_index, 0, replay.turns.size()) if _current_index >= 0 else 0)


func _select_index(index: int) -> void:
	var replay: ReplayRecord = AppState.current_replay
	if replay.turns.is_empty() and not replay.metadata.has("initial_state"):
		return
	_current_index = clampi(index, 0, replay.turns.size())
	_turn_list.select(_current_index)
	var timeline_position: String = "Replay Position %d / %d" % [_current_index + 1, replay.turns.size() + 1]
	if _current_index == 0:
		_apply_replay_state(replay.metadata.get("initial_state", {}))
		_detail_label.text = "%s\n\nStart State\nMap: %s\nInitial arena setup before any actions are taken." % [
			timeline_position,
			str(replay.metadata.get("map_name", "Unknown Map")),
		]
		return

	var turn_data: Dictionary = replay.turns[_current_index - 1]
	_apply_replay_state(turn_data.get("state_snapshot", {}))
	_detail_label.text = "%s\n\nTurn %d | Player %d\nSource: %s\n%s\n\n%s" % [
		timeline_position,
		int(turn_data.get("turn", 0)),
		int(turn_data.get("player", 0)),
		str(turn_data.get("source", "Unknown")),
		str(turn_data.get("summary", "")),
		"\n".join(_string_array(turn_data.get("events", []))),
	]


func _string_array(values: Array) -> Array[String]:
	var results: Array[String] = []
	for item: Variant in values:
		results.append(str(item))
	return results


func _on_turn_selected(index: int) -> void:
	_autoplay_enabled = false
	_timer.stop()
	_select_index(index)


func _on_play_pressed() -> void:
	if AppState.current_replay.turns.is_empty():
		return
	_autoplay_enabled = not _autoplay_enabled
	_play_button.text = "Pause" if _autoplay_enabled else "Play"
	if _autoplay_enabled:
		_schedule_next()
	else:
		_timer.stop()


func _on_step_pressed() -> void:
	if AppState.current_replay.turns.is_empty():
		return
	_autoplay_enabled = false
	_play_button.text = "Play"
	_timer.stop()
	_select_index(mini(_current_index + 1, AppState.current_replay.turns.size()))


func _on_restart_pressed() -> void:
	_autoplay_enabled = false
	_play_button.text = "Play"
	_timer.stop()
	_select_index(0)


func _on_timer_timeout() -> void:
	if not _autoplay_enabled:
		return
	var next_index: int = _current_index + 1
	if next_index > AppState.current_replay.turns.size():
		_autoplay_enabled = false
		_play_button.text = "Play"
		return
	_select_index(next_index)
	_schedule_next()


func _schedule_next() -> void:
	_timer.stop()
	_timer.wait_time = 0.65
	_timer.start()


func _apply_replay_state(snapshot: Dictionary) -> void:
	if _board_view == null or not (snapshot is Dictionary) or snapshot.is_empty():
		return
	var replay_state: GameState = GameState.from_snapshot(snapshot)
	_board_view.clear_transient_effects()
	_board_view.set_selected_actor("")
	_board_view.set_action_mode("")
	_board_view.set_highlighted_cells({})
	_board_view.set_game_state(replay_state)
	call_deferred("_recenter_board_view")


func _on_board_holder_resized() -> void:
	_recenter_board_view()


func _recenter_board_view() -> void:
	if _board_view == null or _board_holder == null:
		return
	var holder_size: Vector2 = _board_holder.size
	if holder_size.x <= 0.0 or holder_size.y <= 0.0:
		return
	var visual_size: Vector2 = _board_view.get_board_visual_size()
	var width_scale: float = holder_size.x / maxf(visual_size.x, 1.0)
	var height_scale: float = holder_size.y / maxf(visual_size.y, 1.0)
	var scale_factor: float = clampf(minf(width_scale, height_scale) * 1.14, 0.58, 1.42)
	_board_view.scale = Vector2.ONE * scale_factor
	_board_view.position = Vector2(holder_size.x * 0.5, holder_size.y * 0.5)


func _play_intro_transition() -> void:
	if _transition_overlay == null:
		return
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	tween.tween_property(_transition_overlay, "color:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)


func _on_back_pressed() -> void:
	_transition_to(MENU_SCENE)
