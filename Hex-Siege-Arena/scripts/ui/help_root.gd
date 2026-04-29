extends Control

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const MATCH_SCENE := "res://scenes/match/match_root.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_root.tscn"
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
const COLOR_GREEN := Color("69dd8e")
const COLOR_P2 := Color("ff8a76")
var _transition_overlay: ColorRect


func _ready() -> void:
	AppState.apply_window_preferences(self)
	AudioManager.play_menu_music()
	theme = _build_theme()
	_build_layout()
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
	shade.color = Color(0.02, 0.03, 0.05, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

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

	var hero_panel := _make_panel_card(COLOR_GREEN, COLOR_SURFACE_ALT)
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
	eyebrow.text = "QUICK START GUIDE"
	eyebrow.add_theme_font_override("font", FONT_SEMIBOLD)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", COLOR_GREEN)
	hero_left.add_child(eyebrow)

	var title := Label.new()
	title.text = "Learn The Arena Fast"
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	hero_left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Everything you need to understand the win conditions, tank roles, and best first checks before you launch a match."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FONT_MEDIUM)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hero_left.add_child(subtitle)

	var hero_right := _make_panel_card(COLOR_GOLD, COLOR_SURFACE)
	hero_right.custom_minimum_size = Vector2(320, 0)
	hero_layout.add_child(hero_right)
	var hero_right_margin := _wrap_panel_content(hero_right, 18, 16)
	var hero_right_layout := VBoxContainer.new()
	hero_right_layout.add_theme_constant_override("separation", 8)
	hero_right_margin.add_child(hero_right_layout)
	hero_right_layout.add_child(_make_section_heading("Recommended First Match"))

	var first_match_text := Label.new()
	first_match_text.text = "Buried Front\nP1 Minimax vs P2 MCTS\nAI starts automatically\nReplay review after finish"
	first_match_text.add_theme_font_override("font", FONT_MEDIUM)
	first_match_text.add_theme_font_size_override("font_size", 15)
	first_match_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_right_layout.add_child(first_match_text)

	var content_grid := GridContainer.new()
	content_grid.columns = 2
	content_grid.add_theme_constant_override("h_separation", 18)
	content_grid.add_theme_constant_override("v_separation", 18)
	root_layout.add_child(content_grid)

	content_grid.add_child(_section("Objective", "You win by either destroying the enemy Ktank or moving your own Ktank onto the center hex.", COLOR_GOLD))
	content_grid.add_child(_section("Turn Structure", "Each turn usually gives one action: Move, Attack, or End Turn. Bonus Move is the main exception and grants one extra action.", COLOR_P1))
	content_grid.add_child(_section("Qtank", "Controls long straight lanes with laser fire, repositions quickly, and is strongest on clean boards or open pressure lines.", COLOR_GREEN))
	content_grid.add_child(_section("Ktank", "Heavier objective tank with adjacent blast pressure. It is tougher, more valuable, and can win instantly by reaching center.", COLOR_P2))
	content_grid.add_child(_section("Minimax", "Searches deeply through tactical futures and usually feels strongest in direct calculation-heavy positions.", COLOR_P1))
	content_grid.add_child(_section("MCTS", "Explores many simulated futures and becomes more dangerous when the map is larger or noisier.", COLOR_GOLD))

	var footer_panel := _make_panel_card(COLOR_BORDER.lightened(0.12), COLOR_SURFACE)
	root_layout.add_child(footer_panel)
	var footer_margin := _wrap_panel_content(footer_panel, 24, 20)
	var footer_layout := VBoxContainer.new()
	footer_layout.add_theme_constant_override("separation", 12)
	footer_margin.add_child(footer_layout)
	footer_layout.add_child(_make_section_heading("Suggested First Checks"))

	var checklist := Label.new()
	checklist.text = "1. Start a Standard match and watch center pressure.\n2. Switch to Labyrinth to feel the heavier tactical optimization.\n3. Open Replay Viewer after the match and review damage, control, and AI timing.\n4. Use Settings if you want bigger UI, reduced motion, or stronger contrast."
	checklist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checklist.add_theme_font_override("font", FONT_MEDIUM)
	checklist.add_theme_font_size_override("font_size", 15)
	footer_layout.add_child(checklist)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root_layout.add_child(button_row)
	button_row.add_child(_make_button("Start Match", _on_start_match_pressed, COLOR_GOLD))
	button_row.add_child(_make_button("Open Settings", _on_settings_pressed, COLOR_P1))
	button_row.add_child(_make_button("Back To Menu", _on_back_pressed, COLOR_P2, true))

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
	theme_data.set_color("font_color", "Label", COLOR_TEXT)
	theme_data.set_color("font_color", "Button", COLOR_TEXT)
	theme_data.set_color("font_hover_color", "Button", Color.WHITE)
	theme_data.set_color("font_pressed_color", "Button", Color.WHITE)
	theme_data.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	return theme_data


func _section(title_text: String, body_text: String, accent_color: Color) -> Control:
	var panel := _make_panel_card(accent_color, COLOR_SURFACE)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _wrap_panel_content(panel, 18, 16)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", FONT_MEDIUM)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	layout.add_child(body)

	return panel


func _make_button(text: String, callback: Callable, accent_color: Color, use_back_sound: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_style(accent_color, 0.10))
	button.add_theme_stylebox_override("hover", _button_style(accent_color, 0.18))
	button.add_theme_stylebox_override("pressed", _button_style(accent_color, 0.24))
	button.add_theme_stylebox_override("disabled", _button_style(COLOR_BORDER, 0.04))
	button.add_theme_font_override("font", FONT_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color.WHITE)
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


func _on_start_match_pressed() -> void:
	_transition_to(MATCH_SCENE)


func _on_settings_pressed() -> void:
	_transition_to(SETTINGS_SCENE)


func _on_back_pressed() -> void:
	_transition_to(MENU_SCENE)
