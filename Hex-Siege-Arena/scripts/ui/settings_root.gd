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

var _scale_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _ui_slider: HSlider
var _scale_value_label: Label
var _music_value_label: Label
var _sfx_value_label: Label
var _ui_value_label: Label
var _reduced_motion_check: CheckBox
var _high_contrast_check: CheckBox
var _onboarding_check: CheckBox
var _transition_overlay: ColorRect


func _ready() -> void:
	AppState.apply_window_preferences(self)
	AudioManager.play_menu_music()
	theme = _build_theme()
	_build_layout()
	_refresh_labels()
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
	shade.color = Color(0.02, 0.03, 0.05, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_top", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(root_margin)

	var root_layout := VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", 20)
	root_margin.add_child(root_layout)

	var hero_panel := _make_panel_card(COLOR_P1, COLOR_SURFACE_ALT)
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
	eyebrow.text = "ACCESSIBILITY AND AUDIO"
	eyebrow.add_theme_font_override("font", FONT_SEMIBOLD)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", COLOR_P1)
	hero_left.add_child(eyebrow)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	hero_left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tune readability, motion, and sound so long AI-vs-AI sessions stay comfortable and clear."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FONT_MEDIUM)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hero_left.add_child(subtitle)

	var hero_note := Label.new()
	hero_note.text = "Changes apply immediately and are saved automatically."
	hero_note.add_theme_font_override("font", FONT_MEDIUM)
	hero_note.add_theme_font_size_override("font_size", 15)
	hero_note.add_theme_color_override("font_color", Color("dbe9fb"))
	hero_left.add_child(hero_note)

	var hero_right := _make_panel_card(COLOR_GOLD, COLOR_SURFACE)
	hero_right.custom_minimum_size = Vector2(300, 0)
	hero_layout.add_child(hero_right)
	var hero_right_margin := _wrap_panel_content(hero_right, 18, 16)
	var hero_right_layout := VBoxContainer.new()
	hero_right_layout.add_theme_constant_override("separation", 8)
	hero_right_margin.add_child(hero_right_layout)
	hero_right_layout.add_child(_make_section_heading("Current Profile"))

	var profile_text := Label.new()
	profile_text.text = "UI Scale %.2fx\nMotion %s\nContrast %s" % [
		AppState.ui_scale,
		"Reduced" if AppState.reduced_motion else "Standard",
		"High" if AppState.high_contrast_mode else "Standard",
	]
	profile_text.add_theme_font_override("font", FONT_MEDIUM)
	profile_text.add_theme_font_size_override("font_size", 15)
	profile_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_right_layout.add_child(profile_text)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 18)
	root_layout.add_child(content_row)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 18)
	content_row.add_child(left_column)

	var visual_panel := _make_panel_card(COLOR_P1, COLOR_SURFACE)
	left_column.add_child(visual_panel)
	var visual_margin := _wrap_panel_content(visual_panel, 22, 20)
	var visual_layout := VBoxContainer.new()
	visual_layout.add_theme_constant_override("separation", 16)
	visual_margin.add_child(visual_layout)
	visual_layout.add_child(_make_section_heading("Visual Comfort"))
	visual_layout.add_child(_slider_row("UI Scale", AppState.ui_scale, "_on_scale_changed", 0.85, 1.35, 0.05))
	visual_layout.add_child(_toggle_row("Reduced Motion", AppState.reduced_motion, "_on_reduced_motion_toggled", "Disables board shake and tones down motion-heavy battlefield presentation."))
	visual_layout.add_child(_toggle_row("High Contrast Highlights", AppState.high_contrast_mode, "_on_high_contrast_toggled", "Strengthens move, attack, and team color separation for clearer tactical reading."))
	visual_layout.add_child(_toggle_row("Show Match Briefing", AppState.show_onboarding_hints, "_on_onboarding_toggled", "Shows the lightweight pre-battle onboarding card at match start until you turn it off."))

	var audio_panel := _make_panel_card(COLOR_GREEN, COLOR_SURFACE)
	left_column.add_child(audio_panel)
	var audio_margin := _wrap_panel_content(audio_panel, 22, 20)
	var audio_layout := VBoxContainer.new()
	audio_layout.add_theme_constant_override("separation", 16)
	audio_margin.add_child(audio_layout)
	audio_layout.add_child(_make_section_heading("Audio Mix"))
	audio_layout.add_child(_slider_row("Music Volume", AudioManager.music_volume_db, "_on_music_changed"))
	audio_layout.add_child(_slider_row("SFX Volume", AudioManager.sfx_volume_db, "_on_sfx_changed"))
	audio_layout.add_child(_slider_row("UI Volume", AudioManager.ui_volume_db, "_on_ui_changed"))

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(340, 0)
	right_column.add_theme_constant_override("separation", 18)
	content_row.add_child(right_column)

	var guidance_panel := _make_panel_card(COLOR_BORDER.lightened(0.12), COLOR_SURFACE_ALT)
	right_column.add_child(guidance_panel)
	var guidance_margin := _wrap_panel_content(guidance_panel, 22, 20)
	var guidance_layout := VBoxContainer.new()
	guidance_layout.add_theme_constant_override("separation", 10)
	guidance_margin.add_child(guidance_layout)
	guidance_layout.add_child(_make_section_heading("Recommended Defaults"))

	var guidance_text := Label.new()
	guidance_text.text = "For the cleanest spectator experience, keep UI Scale near 1.0x, reduce motion only when needed, and use high contrast on dense maps like Labyrinth."
	guidance_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_text.add_theme_font_override("font", FONT_REGULAR)
	guidance_text.add_theme_font_size_override("font_size", 15)
	guidance_layout.add_child(guidance_text)

	var button_panel := _make_panel_card(COLOR_BORDER, COLOR_SURFACE)
	right_column.add_child(button_panel)
	var button_margin := _wrap_panel_content(button_panel, 22, 20)
	var button_layout := VBoxContainer.new()
	button_layout.add_theme_constant_override("separation", 12)
	button_margin.add_child(button_layout)
	button_layout.add_child(_make_section_heading("Actions"))
	button_layout.add_child(_make_button("Restore Defaults", _on_restore_defaults_pressed, COLOR_GOLD))
	button_layout.add_child(_make_button("Back To Menu", _on_back_pressed, COLOR_P2, true))

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
	theme_data.set_font("font", "CheckBox", FONT_MEDIUM)
	theme_data.set_font("font", "HSlider", FONT_MEDIUM)
	theme_data.set_color("font_color", "Label", COLOR_TEXT)
	theme_data.set_color("font_color", "Button", COLOR_TEXT)
	theme_data.set_color("font_color", "CheckBox", COLOR_TEXT)
	theme_data.set_color("font_hover_color", "Button", Color.WHITE)
	theme_data.set_color("font_pressed_color", "Button", Color.WHITE)
	theme_data.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	return theme_data


func _slider_row(label_text: String, initial_value: float, callback_name: String, min_value: float = -30.0, max_value: float = 0.0, step: float = 1.0) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	row.add_child(top)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 15)
	top.add_child(label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_override("font", FONT_MEDIUM)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	top.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(Callable(self, callback_name))
	row.add_child(slider)

	match label_text:
		"UI Scale":
			_scale_slider = slider
			_scale_value_label = value_label
		"Music Volume":
			_music_slider = slider
			_music_value_label = value_label
		"SFX Volume":
			_sfx_slider = slider
			_sfx_value_label = value_label
		"UI Volume":
			_ui_slider = slider
			_ui_value_label = value_label

	return row


func _toggle_row(label_text: String, initial_value: bool, callback_name: String, description_text: String) -> Control:
	var panel := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	var margin := _wrap_panel_content(panel, 16, 14)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = initial_value
	check.toggled.connect(Callable(self, callback_name))
	row.add_child(check)

	var description := Label.new()
	description.text = description_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", FONT_REGULAR)
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	row.add_child(description)

	match label_text:
		"Reduced Motion":
			_reduced_motion_check = check
		"High Contrast Highlights":
			_high_contrast_check = check
		"Show Match Briefing":
			_onboarding_check = check

	return panel


func _make_button(text: String, callback: Callable, accent_color: Color, use_back_sound: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
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
	style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	style.shadow_size = 14
	return style


func _button_style(accent_color: Color, fill_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, maxf(fill_alpha, 0.26))
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


func _load_home_background() -> Texture2D:
	return ResourceLoader.load(HOME_BG_PATH, "Texture2D") as Texture2D


func _make_section_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _refresh_labels() -> void:
	if _scale_value_label != null:
		_scale_value_label.text = "%.2fx" % _scale_slider.value
	if _music_value_label != null:
		_music_value_label.text = "%.0f dB" % _music_slider.value
	if _sfx_value_label != null:
		_sfx_value_label.text = "%.0f dB" % _sfx_slider.value
	if _ui_value_label != null:
		_ui_value_label.text = "%.0f dB" % _ui_slider.value


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


func _on_scale_changed(value: float) -> void:
	AppState.ui_scale = value
	AppState.apply_window_preferences(self)
	AppState.save_preferences()
	_refresh_labels()
	AudioManager.play_ui_confirm()


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume_db(value)
	AppState.save_preferences()
	_refresh_labels()


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume_db(value)
	AppState.save_preferences()
	_refresh_labels()
	AudioManager.play_ui_confirm()


func _on_ui_changed(value: float) -> void:
	AudioManager.set_ui_volume_db(value)
	AppState.save_preferences()
	_refresh_labels()
	AudioManager.play_ui_confirm()


func _on_reduced_motion_toggled(enabled: bool) -> void:
	AppState.reduced_motion = enabled
	AppState.save_preferences()
	AudioManager.play_ui_confirm()


func _on_high_contrast_toggled(enabled: bool) -> void:
	AppState.high_contrast_mode = enabled
	AppState.save_preferences()
	AudioManager.play_ui_confirm()


func _on_onboarding_toggled(enabled: bool) -> void:
	AppState.show_onboarding_hints = enabled
	AppState.save_preferences()
	AudioManager.play_ui_confirm()


func _on_restore_defaults_pressed() -> void:
	_scale_slider.value = 1.0
	_music_slider.value = -16.0
	_sfx_slider.value = -8.0
	_ui_slider.value = -10.0
	if _reduced_motion_check != null:
		_reduced_motion_check.button_pressed = false
	if _high_contrast_check != null:
		_high_contrast_check.button_pressed = false
	if _onboarding_check != null:
		_onboarding_check.button_pressed = true
	AppState.ui_scale = _scale_slider.value
	AppState.reduced_motion = false
	AppState.high_contrast_mode = false
	AppState.show_onboarding_hints = true
	AppState.apply_window_preferences(self)
	AudioManager.set_music_volume_db(_music_slider.value)
	AudioManager.set_sfx_volume_db(_sfx_slider.value)
	AudioManager.set_ui_volume_db(_ui_slider.value)
	AppState.save_preferences()
	_refresh_labels()
	AudioManager.play_ui_confirm()


func _on_back_pressed() -> void:
	_transition_to(MENU_SCENE)
