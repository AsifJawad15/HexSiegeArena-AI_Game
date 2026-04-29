extends Control

const MATCH_SCENE := "res://scenes/match/match_root.tscn"
const REPLAY_SCENE := "res://scenes/replay/replay_shell.tscn"
const SETTINGS_SCENE := "res://scenes/settings/settings_root.tscn"
const HELP_SCENE := "res://scenes/help/help_root.tscn"
const HOME_BG_PATH := "res://assets/ui/home_background.png"
const FONT_HEADING  := preload("res://fonts/Rajdhani/Rajdhani-Bold.ttf")
const FONT_LABEL    := preload("res://fonts/Rajdhani/Rajdhani-SemiBold.ttf")
const FONT_UI_BOLD  := preload("res://fonts/Inter/static/Inter_18pt-Bold.ttf")
const FONT_SEMIBOLD := preload("res://fonts/Inter/static/Inter_18pt-SemiBold.ttf")
const FONT_BODY     := preload("res://fonts/Inter/static/Inter_18pt-Medium.ttf")
const FONT_SMALL    := preload("res://fonts/Inter/static/Inter_18pt-Regular.ttf")
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
const DEFAULT_TURN_LIMIT := 85
const DEFAULT_MINIMAX_DEPTH := 6
const DEFAULT_MINIMAX_TIME_MS := 3800
const DEFAULT_MCTS_ROLLOUTS := 80
const DEFAULT_MCTS_TIME_MS := 650

var _p1_controller: OptionButton
var _p2_controller: OptionButton
var _map_select: OptionButton
# Stepper state (replace SpinBox)
var _turns_value: int = DEFAULT_TURN_LIMIT
var _depth_value: int = DEFAULT_MINIMAX_DEPTH
var _rollouts_value: int = DEFAULT_MCTS_ROLLOUTS
var _turns_value_label: Label
var _depth_value_label: Label
var _rollouts_value_label: Label
# Session snapshot labels
var _snap_build_val: Label
var _snap_ctrl_val: RichTextLabel
var _snap_map_val: Label
var _snap_replay_val: Label
var _snap_scale_val: Label
var _snap_motion_val: Label
# Arena preview
var _arena_preview_title_label: Label
var _arena_preview_label: Label
# Match rules
var _rules_p1_val: Label
var _rules_p2_val: Label
var _rules_turns_val: Label
var _rules_mode_val: Label
# Other
var _replay_button: Button
var _version_label: Label
var _transition_overlay: ColorRect
var _neon_title_label: Label


func _ready() -> void:
	AppState.apply_window_preferences(self)
	AudioManager.play_menu_music()
	theme = _build_menu_theme()
	_build_layout()
	_refresh_summary()
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
	shade.color = Color(0.02, 0.03, 0.05, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.custom_minimum_size = Vector2(500, 0)
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 16)
	center.add_child(menu_vbox)

	_neon_title_label = Label.new()
	_neon_title_label.text = "Hex Siege Arena"
	_neon_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_neon_title_label.add_theme_font_override("font", _title_font())
	_neon_title_label.add_theme_font_size_override("font_size", 96)
	_neon_title_label.add_theme_color_override("font_color", Color("dff8ff"))
	_neon_title_label.add_theme_color_override("font_outline_color", Color(0.15, 0.78, 1.0, 0.82))
	_neon_title_label.add_theme_constant_override("outline_size", 3)
	_neon_title_label.add_theme_color_override("font_shadow_color", Color(0.95, 0.36, 0.18, 0.82))
	_neon_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_neon_title_label.add_theme_constant_override("shadow_offset_y", 0)
	menu_vbox.add_child(_neon_title_label)

	_p1_controller = _controller_option()
	menu_vbox.add_child(_make_field_row("P1", COLOR_P1, "PLAYER 1", _p1_controller))

	_p2_controller = _controller_option()
	menu_vbox.add_child(_make_field_row("P2", COLOR_P2, "PLAYER 2", _p2_controller))

	_map_select = OptionButton.new()
	for map_id: String in ["standard", "open", "fortress", "labyrinth"]:
		_map_select.add_item(_map_display_name(map_id))
		_map_select.set_item_metadata(_map_select.item_count - 1, map_id)
	_map_select.item_selected.connect(_on_setup_changed)
	_style_option_button(_map_select)

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_grid.add_theme_constant_override("h_separation", 12)
	button_grid.add_theme_constant_override("v_separation", 12)
	menu_vbox.add_child(button_grid)

	button_grid.add_child(_make_button("START", _on_open_match_pressed, COLOR_GOLD, 58))
	_replay_button = _make_button("REPLAY", _on_open_replay_pressed, COLOR_P1, 58)
	button_grid.add_child(_replay_button)
	button_grid.add_child(_make_button("GUIDE", _on_open_help_pressed, COLOR_GREEN, 50))
	button_grid.add_child(_make_button("SETTINGS", _on_open_settings_pressed, COLOR_BORDER.lightened(0.18), 50))
	button_grid.add_child(_make_button("RESET", _on_reset_state_pressed, COLOR_BORDER.lightened(0.10), 48))
	button_grid.add_child(_make_button("QUIT", _on_exit_game_pressed, COLOR_P2, 48, true))

	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.03, 0.05, 0.09, 1.0)
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_overlay)

	_apply_config_to_controls()
	call_deferred("_animate_neon_title")


func _build_legacy_layout() -> void:
	# ── Background ────────────────────────────────────────────────────────────
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# ── Root scroll ───────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 14)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_right", 14)
	root_margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(root_margin)

	var root_row := HBoxContainer.new()
	root_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_row.add_theme_constant_override("separation", 14)
	root_margin.add_child(root_row)

	# ══ LEFT CARD ═════════════════════════════════════════════════════════════
	var left_card := _make_panel_card(COLOR_P1, COLOR_SURFACE)
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_row.add_child(left_card)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 0)
	left_card.add_child(left_vbox)

	# ── Hero section ──────────────────────────────────────────────────────────
	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 28)
	hero_margin.add_theme_constant_override("margin_top", 24)
	hero_margin.add_theme_constant_override("margin_right", 28)
	hero_margin.add_theme_constant_override("margin_bottom", 20)
	left_vbox.add_child(hero_margin)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 20)
	hero_margin.add_child(hero_row)

	hero_row.add_child(_make_icon_box("⬡", COLOR_P1.darkened(0.55), 64))

	var hero_text := VBoxContainer.new()
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_text.add_theme_constant_override("separation", 6)
	hero_row.add_child(hero_text)

	var eyebrow := Label.new()
	eyebrow.text = "TACTICAL AI ARENA"
	eyebrow.add_theme_font_override("font", FONT_SEMIBOLD)
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", COLOR_GOLD)
	hero_text.add_child(eyebrow)

	var title := Label.new()
	title.text = "HEX SIEGE ARENA"
	title.add_theme_font_override("font", FONT_HEADING)
	title.add_theme_font_size_override("font_size", 64)
	hero_text.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose Human, Minimax, or MCTS. Algorithms play automatically."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FONT_SMALL)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hero_text.add_child(subtitle)

	_version_label = Label.new()
	_version_label.add_theme_font_override("font", FONT_SMALL)
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hero_text.add_child(_version_label)

	# Divider
	var div1 := ColorRect.new()
	div1.custom_minimum_size = Vector2(0, 1)
	div1.color = COLOR_BORDER
	left_vbox.add_child(div1)

	# ── Setup section ─────────────────────────────────────────────────────────
	var setup_margin := MarginContainer.new()
	setup_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_margin.add_theme_constant_override("margin_left", 22)
	setup_margin.add_theme_constant_override("margin_top", 18)
	setup_margin.add_theme_constant_override("margin_right", 22)
	setup_margin.add_theme_constant_override("margin_bottom", 18)
	left_vbox.add_child(setup_margin)

	var setup_vbox := VBoxContainer.new()
	setup_vbox.add_theme_constant_override("separation", 14)
	setup_margin.add_child(setup_vbox)

	# Setup header
	var setup_header := HBoxContainer.new()
	setup_header.add_theme_constant_override("separation", 14)
	setup_vbox.add_child(setup_header)

	var setup_title_block := VBoxContainer.new()
	setup_title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_title_block.add_theme_constant_override("separation", 4)
	setup_header.add_child(setup_title_block)

	var setup_label := Label.new()
	setup_label.text = "MATCH SETUP"
	setup_label.add_theme_font_override("font", FONT_HEADING)
	setup_label.add_theme_font_size_override("font_size", 24)
	setup_title_block.add_child(setup_label)

	var setup_subtitle := Label.new()
	setup_subtitle.text = "Pick controllers and arena, then start."
	setup_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_subtitle.add_theme_font_override("font", FONT_BODY)
	setup_subtitle.add_theme_font_size_override("font_size", 14)
	setup_subtitle.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	setup_title_block.add_child(setup_subtitle)

	setup_header.add_child(_make_chip("AUTO AI READY", COLOR_GOLD))

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = COLOR_BORDER
	setup_vbox.add_child(div2)

	# 6 field rows
	_p1_controller = _controller_option()
	setup_vbox.add_child(_make_field_row("P1", COLOR_P1, "PLAYER 1", _p1_controller))

	_p2_controller = _controller_option()
	setup_vbox.add_child(_make_field_row("P2", COLOR_P2, "PLAYER 2", _p2_controller))

	_map_select = OptionButton.new()
	for map_id: String in ["standard", "open", "fortress", "labyrinth"]:
		_map_select.add_item(_map_display_name(map_id))
		_map_select.set_item_metadata(_map_select.item_count - 1, map_id)
	_map_select.item_selected.connect(_on_setup_changed)
	_style_option_button(_map_select)
	setup_vbox.add_child(_make_field_row("MAP", COLOR_BORDER.lightened(0.3), "ARENA", _map_select))

	var turns_stepper := _make_stepper(_turns_value, 20, 200, 5)
	_turns_value_label = turns_stepper["value_label"]
	setup_vbox.add_child(_make_field_row("T", COLOR_GOLD, "TURNS", turns_stepper["hbox"]))

	var depth_stepper := _make_stepper(_depth_value, 1, 6, 1)
	_depth_value_label = depth_stepper["value_label"]
	setup_vbox.add_child(_make_field_row("MM", COLOR_P1.darkened(0.3), "MINIMAX", depth_stepper["hbox"]))

	var rollouts_stepper := _make_stepper(_rollouts_value, 50, 2000, 50)
	_rollouts_value_label = rollouts_stepper["value_label"]
	setup_vbox.add_child(_make_field_row("MC", COLOR_P2.darkened(0.3), "MCTS", rollouts_stepper["hbox"]))

	var div3 := ColorRect.new()
	div3.custom_minimum_size = Vector2(0, 1)
	div3.color = COLOR_BORDER
	setup_vbox.add_child(div3)

	# Action buttons
	var primary_row := HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 12)
	setup_vbox.add_child(primary_row)
	primary_row.add_child(_make_button("START MATCH", _on_open_match_pressed, COLOR_GOLD, 58))
	_replay_button = _make_button("REPLAY", _on_open_replay_pressed, COLOR_P1, 56)
	primary_row.add_child(_replay_button)

	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 12)
	setup_vbox.add_child(secondary_row)
	secondary_row.add_child(_make_button("GUIDE", _on_open_help_pressed, COLOR_GREEN, 46))
	secondary_row.add_child(_make_button("SETTINGS", _on_open_settings_pressed, COLOR_BORDER.lightened(0.18), 46))

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 12)
	setup_vbox.add_child(utility_row)
	utility_row.add_child(_make_button("RESET", _on_reset_state_pressed, COLOR_BORDER.lightened(0.10), 44))
	utility_row.add_child(_make_button("QUIT", _on_exit_game_pressed, COLOR_P2, 44, true))

	# ══ RIGHT COLUMN ══════════════════════════════════════════════════════════
	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(360, 0)
	right_column.add_theme_constant_override("separation", 12)
	right_column.size_flags_horizontal = Control.SIZE_SHRINK_END
	root_row.add_child(right_column)

	# ── Card 1: Session Snapshot ──────────────────────────────────────────────
	var snap_card := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	right_column.add_child(snap_card)
	var snap_content := _wrap_panel_content(snap_card, 16, 14)
	var snap_vbox := VBoxContainer.new()
	snap_vbox.add_theme_constant_override("separation", 10)
	snap_content.add_child(snap_vbox)

	var snap_heading := Label.new()
	snap_heading.text = "SESSION SNAPSHOT"
	snap_heading.add_theme_font_override("font", FONT_SEMIBOLD)
	snap_heading.add_theme_font_size_override("font_size", 11)
	snap_heading.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	snap_vbox.add_child(snap_heading)

	var snap_div := ColorRect.new()
	snap_div.custom_minimum_size = Vector2(0, 1)
	snap_div.color = COLOR_BORDER
	snap_vbox.add_child(snap_div)

	var srow2 := _make_snapshot_row("AI", COLOR_P1, "Controllers")
	# Swap plain label for RichTextLabel to colour player names
	srow2["hbox"].remove_child(srow2["value_label"])
	srow2["value_label"].queue_free()
	_snap_ctrl_val = RichTextLabel.new()
	_snap_ctrl_val.bbcode_enabled = true
	_snap_ctrl_val.fit_content = true
	_snap_ctrl_val.scroll_active = false
	_snap_ctrl_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snap_ctrl_val.add_theme_font_override("normal_font", FONT_BODY)
	_snap_ctrl_val.add_theme_font_size_override("normal_font_size", 13)
	srow2["hbox"].add_child(_snap_ctrl_val)
	snap_vbox.add_child(srow2["hbox"])

	var srow3 := _make_snapshot_row("MAP", COLOR_GOLD, "Arena")
	_snap_map_val = srow3["value_label"]
	_snap_map_val.add_theme_color_override("font_color", Color("5bc8d4"))
	snap_vbox.add_child(srow3["hbox"])

	var srow4 := _make_snapshot_row("R", COLOR_TEXT_MUTED, "Replay")
	_snap_replay_val = srow4["value_label"]
	snap_vbox.add_child(srow4["hbox"])

	# ── Card 2: Arena Preview ─────────────────────────────────────────────────
	var arena_card := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	arena_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(arena_card)

	var arena_outer := HBoxContainer.new()
	arena_outer.add_theme_constant_override("separation", 0)
	arena_card.add_child(arena_outer)

	var arena_content := MarginContainer.new()
	arena_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_content.add_theme_constant_override("margin_left", 16)
	arena_content.add_theme_constant_override("margin_top", 14)
	arena_content.add_theme_constant_override("margin_right", 16)
	arena_content.add_theme_constant_override("margin_bottom", 14)
	arena_outer.add_child(arena_content)

	var arena_vbox := VBoxContainer.new()
	arena_vbox.add_theme_constant_override("separation", 8)
	arena_content.add_child(arena_vbox)

	var arena_head_row := HBoxContainer.new()
	arena_head_row.add_theme_constant_override("separation", 12)
	arena_vbox.add_child(arena_head_row)
	arena_head_row.add_child(_make_icon_box("M", Color(0.94, 0.75, 0.28, 0.20), 42))
	var arena_head_text := VBoxContainer.new()
	arena_head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arena_head_text.add_theme_constant_override("separation", 2)
	arena_head_row.add_child(arena_head_text)

	var arena_heading := Label.new()
	arena_heading.text = "ARENA PREVIEW"
	arena_heading.add_theme_font_override("font", FONT_SEMIBOLD)
	arena_heading.add_theme_font_size_override("font_size", 11)
	arena_heading.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	arena_head_text.add_child(arena_heading)

	_arena_preview_title_label = Label.new()
	_arena_preview_title_label.add_theme_font_override("font", FONT_HEADING)
	_arena_preview_title_label.add_theme_font_size_override("font_size", 22)
	arena_head_text.add_child(_arena_preview_title_label)

	_arena_preview_label = Label.new()
	_arena_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arena_preview_label.add_theme_font_override("font", FONT_BODY)
	_arena_preview_label.add_theme_font_size_override("font_size", 14)
	_arena_preview_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	arena_vbox.add_child(_arena_preview_label)

	arena_vbox.add_child(_make_step_badge(1, "Pick setup."))
	arena_vbox.add_child(_make_step_badge(2, "Start match."))

	# ── Card 3: Match Rules ───────────────────────────────────────────────────
	var rules_card := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	right_column.add_child(rules_card)

	var rules_outer := HBoxContainer.new()
	rules_outer.add_theme_constant_override("separation", 0)
	rules_card.add_child(rules_outer)

	var rules_content := MarginContainer.new()
	rules_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_content.add_theme_constant_override("margin_left", 16)
	rules_content.add_theme_constant_override("margin_top", 14)
	rules_content.add_theme_constant_override("margin_right", 16)
	rules_content.add_theme_constant_override("margin_bottom", 14)
	rules_outer.add_child(rules_content)

	var rules_vbox := VBoxContainer.new()
	rules_vbox.add_theme_constant_override("separation", 8)
	rules_content.add_child(rules_vbox)

	var rules_head_row := HBoxContainer.new()
	rules_head_row.add_theme_constant_override("separation", 12)
	rules_vbox.add_child(rules_head_row)
	rules_head_row.add_child(_make_icon_box("W", COLOR_P1.darkened(0.4), 42))
	var rules_head_text := VBoxContainer.new()
	rules_head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rules_head_text.add_theme_constant_override("separation", 2)
	rules_head_row.add_child(rules_head_text)

	var rules_heading := Label.new()
	rules_heading.text = "MATCH RULES"
	rules_heading.add_theme_font_override("font", FONT_SEMIBOLD)
	rules_heading.add_theme_font_size_override("font_size", 11)
	rules_heading.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	rules_head_text.add_child(rules_heading)

	var rules_win_cond := Label.new()
	rules_win_cond.text = "Destroy the enemy Ktank or hold the center."
	rules_win_cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_win_cond.add_theme_font_override("font", FONT_SMALL)
	rules_win_cond.add_theme_font_size_override("font_size", 12)
	rules_win_cond.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	rules_vbox.add_child(rules_win_cond)

	var rrow3 := _make_rules_row("Turns")
	_rules_turns_val = rrow3["value_label"]
	rules_vbox.add_child(rrow3["hbox"])

	var rrow4 := _make_rules_row("Mode")
	_rules_mode_val = rrow4["value_label"]
	rules_vbox.add_child(rrow4["hbox"])

	# ── Card 4: Build Focus ───────────────────────────────────────────────────
	var build_card := _make_panel_card(COLOR_BORDER, COLOR_SURFACE_ALT)
	right_column.add_child(build_card)

	var build_outer := HBoxContainer.new()
	build_outer.add_theme_constant_override("separation", 0)
	build_card.add_child(build_outer)

	var build_content := MarginContainer.new()
	build_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_content.add_theme_constant_override("margin_left", 16)
	build_content.add_theme_constant_override("margin_top", 14)
	build_content.add_theme_constant_override("margin_right", 16)
	build_content.add_theme_constant_override("margin_bottom", 14)
	build_outer.add_child(build_content)

	var build_vbox := VBoxContainer.new()
	build_vbox.add_theme_constant_override("separation", 8)
	build_content.add_child(build_vbox)

	var build_head_row := HBoxContainer.new()
	build_head_row.add_theme_constant_override("separation", 12)
	build_vbox.add_child(build_head_row)
	build_head_row.add_child(_make_icon_box("A", COLOR_GREEN.darkened(0.4), 42))
	var build_head_text := VBoxContainer.new()
	build_head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_head_text.add_theme_constant_override("separation", 2)
	build_head_row.add_child(build_head_text)

	var build_heading := Label.new()
	build_heading.text = "FLOW"
	build_heading.add_theme_font_override("font", FONT_SEMIBOLD)
	build_heading.add_theme_font_size_override("font_size", 11)
	build_heading.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	build_head_text.add_child(build_heading)

	var build_body := Label.new()
	build_body.text = "Algorithm controllers move on their own. Human controllers wait for player input."
	build_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_body.add_theme_font_override("font", FONT_BODY)
	build_body.add_theme_font_size_override("font_size", 14)
	build_body.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	build_vbox.add_child(build_body)

	# ── Transition overlay (top of z-order) ───────────────────────────────────
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color(0.03, 0.05, 0.09, 1.0)
	_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_overlay)

	_apply_config_to_controls()


func _animate_neon_title() -> void:
	if _neon_title_label == null:
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_neon_title_label, "modulate", Color(0.72, 0.92, 1.0, 0.86), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_neon_title_label, "modulate", Color(1.0, 0.72, 0.42, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.05)
	tween.tween_property(_neon_title_label, "modulate", Color(0.92, 0.98, 1.0, 1.0), 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _load_home_background() -> Texture2D:
	return ResourceLoader.load(HOME_BG_PATH, "Texture2D") as Texture2D


func _title_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Gabriola", "Segoe Script", "Brush Script MT"])
	return font


func _build_menu_theme() -> Theme:
	var menu_theme := Theme.new()
	menu_theme.default_font = FONT_SMALL
	menu_theme.default_font_size = 14
	menu_theme.set_font("font", "Label", FONT_SMALL)
	menu_theme.set_font("font", "Button", FONT_UI_BOLD)
	menu_theme.set_font("font", "OptionButton", FONT_BODY)
	menu_theme.set_font("font", "RichTextLabel", FONT_SMALL)
	menu_theme.set_color("font_color", "Label", COLOR_TEXT)
	menu_theme.set_color("font_color", "Button", COLOR_TEXT)
	menu_theme.set_color("font_hover_color", "Button", Color.WHITE)
	menu_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	menu_theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	menu_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	menu_theme.set_color("font_color", "RichTextLabel", COLOR_TEXT)
	menu_theme.set_color("font_color", "OptionButton", COLOR_TEXT)
	return menu_theme


func _make_field_row(icon_char: String, icon_color: Color, label_text: String, control: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(icon_color.r, icon_color.g, icon_color.b, 0.30)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_color = Color(icon_color.r, icon_color.g, icon_color.b, 0.30)
	style.content_margin_left = 10.0
	style.content_margin_top = 6.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_char
	icon_lbl.add_theme_font_override("font", FONT_BODY)
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.add_theme_color_override("font_color", icon_color)
	icon_lbl.custom_minimum_size = Vector2(34, 0)
	row.add_child(icon_lbl)

	var field_lbl := Label.new()
	field_lbl.text = label_text
	field_lbl.add_theme_font_override("font", FONT_SEMIBOLD)
	field_lbl.add_theme_font_size_override("font_size", 11)
	field_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	field_lbl.custom_minimum_size = Vector2(98, 0)
	row.add_child(field_lbl)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return panel


func _make_stepper(initial: int, min_v: int, max_v: int, step_v: int) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var val_lbl := Label.new()
	val_lbl.text = str(initial)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_override("font", FONT_HEADING)
	val_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(val_lbl)

	var btn_minus := Button.new()
	btn_minus.text = "◀"
	btn_minus.custom_minimum_size = Vector2(32, 32)
	btn_minus.focus_mode = Control.FOCUS_NONE
	btn_minus.add_theme_stylebox_override("normal", _button_style(COLOR_BORDER, 0.08))
	btn_minus.add_theme_stylebox_override("hover", _button_style(COLOR_P1, 0.16))
	btn_minus.add_theme_stylebox_override("pressed", _button_style(COLOR_P1, 0.24))
	btn_minus.add_theme_font_override("font", FONT_BODY)
	btn_minus.add_theme_font_size_override("font_size", 11)
	hbox.add_child(btn_minus)

	var btn_plus := Button.new()
	btn_plus.text = "▶"
	btn_plus.custom_minimum_size = Vector2(32, 32)
	btn_plus.focus_mode = Control.FOCUS_NONE
	btn_plus.add_theme_stylebox_override("normal", _button_style(COLOR_BORDER, 0.08))
	btn_plus.add_theme_stylebox_override("hover", _button_style(COLOR_P1, 0.16))
	btn_plus.add_theme_stylebox_override("pressed", _button_style(COLOR_P1, 0.24))
	btn_plus.add_theme_font_override("font", FONT_BODY)
	btn_plus.add_theme_font_size_override("font_size", 11)
	hbox.add_child(btn_plus)

	# Closure over val_lbl reference to update display and propagate
	var current: int = initial
	btn_minus.pressed.connect(func() -> void:
		current = max(min_v, current - step_v)
		val_lbl.text = str(current)
		_on_stepper_changed(val_lbl, current)
	)
	btn_plus.pressed.connect(func() -> void:
		current = min(max_v, current + step_v)
		val_lbl.text = str(current)
		_on_stepper_changed(val_lbl, current)
	)
	return {"hbox": hbox, "value_label": val_lbl}


func _on_stepper_changed(val_lbl: Label, current: int) -> void:
	if val_lbl == _turns_value_label:
		_turns_value = current
	elif val_lbl == _depth_value_label:
		_depth_value = current
	elif val_lbl == _rollouts_value_label:
		_rollouts_value = current
	_on_setup_changed()


func _make_snapshot_row(icon_char: String, icon_color: Color, label_text: String) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_char
	icon_lbl.add_theme_font_override("font", FONT_BODY)
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", icon_color)
	icon_lbl.custom_minimum_size = Vector2(34, 0)
	hbox.add_child(icon_lbl)

	var key_lbl := Label.new()
	key_lbl.text = label_text
	key_lbl.add_theme_font_override("font", FONT_SMALL)
	key_lbl.add_theme_font_size_override("font_size", 13)
	key_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	key_lbl.custom_minimum_size = Vector2(96, 0)
	hbox.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", FONT_BODY)
	val_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(val_lbl)

	return {"hbox": hbox, "value_label": val_lbl}


func _make_rules_row(label_text: String) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var key_lbl := Label.new()
	key_lbl.text = label_text
	key_lbl.add_theme_font_override("font", FONT_BODY)
	key_lbl.add_theme_font_size_override("font_size", 13)
	key_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	key_lbl.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", FONT_BODY)
	val_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(val_lbl)

	return {"hbox": hbox, "value_label": val_lbl}


func _make_step_badge(n: int, text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var num_panel := PanelContainer.new()
	var num_style := StyleBoxFlat.new()
	num_style.bg_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.15)
	num_style.border_color = COLOR_GOLD
	num_style.border_width_left = 1
	num_style.border_width_top = 1
	num_style.border_width_right = 1
	num_style.border_width_bottom = 1
	num_style.corner_radius_top_left = 4
	num_style.corner_radius_top_right = 4
	num_style.corner_radius_bottom_left = 4
	num_style.corner_radius_bottom_right = 4
	num_style.content_margin_left = 6.0
	num_style.content_margin_top = 2.0
	num_style.content_margin_right = 6.0
	num_style.content_margin_bottom = 2.0
	num_panel.add_theme_stylebox_override("panel", num_style)
	hbox.add_child(num_panel)

	var num_lbl := Label.new()
	num_lbl.text = str(n)
	num_lbl.add_theme_font_override("font", FONT_LABEL)
	num_lbl.add_theme_font_size_override("font_size", 12)
	num_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	num_panel.add_child(num_lbl)

	var text_lbl := Label.new()
	text_lbl.text = text
	text_lbl.add_theme_font_override("font", FONT_BODY)
	text_lbl.add_theme_font_size_override("font_size", 13)
	text_lbl.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	hbox.add_child(text_lbl)

	return hbox


func _make_hex_decoration() -> Control:
	var script := load("res://scripts/ui/hex_decoration.gd")
	var deco: Control = script.new()
	deco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return deco


func _make_icon_box(char: String, bg_color: Color, box_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(box_size, box_size)

	var lbl := Label.new()
	lbl.text = char
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT_HEADING)
	lbl.add_theme_font_size_override("font_size", int(box_size * 0.52))
	lbl.add_theme_color_override("font_color", COLOR_GOLD)
	panel.add_child(lbl)
	return panel


func _controller_option() -> OptionButton:
	var option := OptionButton.new()
	option.add_item("Human")
	option.set_item_metadata(0, GameTypes.ControllerType.HUMAN)
	option.add_item("Minimax")
	option.set_item_metadata(1, GameTypes.ControllerType.MINIMAX)
	option.add_item("MCTS")
	option.set_item_metadata(2, GameTypes.ControllerType.MCTS)
	option.item_selected.connect(_on_setup_changed)
	_style_option_button(option)
	return option


func _style_option_button(option: OptionButton) -> void:
	option.custom_minimum_size = Vector2(0, 40)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.focus_mode = Control.FOCUS_NONE
	var normal := _button_style(COLOR_BORDER.lightened(0.08), 0.08)
	var hover := _button_style(COLOR_P1, 0.14)
	var pressed := _button_style(COLOR_P1, 0.20)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", pressed)
	option.add_theme_stylebox_override("focus", hover)
	option.add_theme_stylebox_override("disabled", _button_style(COLOR_BORDER, 0.04))
	option.add_theme_font_override("font", FONT_BODY)
	option.add_theme_font_size_override("font_size", 14)


func _make_button(text: String, callback: Callable, accent_color: Color, min_height: int = 46, use_back_sound: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, min_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_style(accent_color, 0.10))
	button.add_theme_stylebox_override("hover", _button_style(accent_color, 0.18))
	button.add_theme_stylebox_override("pressed", _button_style(accent_color, 0.24))
	button.add_theme_stylebox_override("disabled", _button_style(COLOR_BORDER, 0.04))
	button.add_theme_font_override("font", FONT_HEADING)
	button.add_theme_font_size_override("font_size", 18 if min_height >= 52 else 15)
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
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color.lerp(COLOR_BORDER, 0.58)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	return style


func _button_style(accent_color: Color, fill_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var alpha: float = maxf(fill_alpha, 0.30)
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 4
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style


func _make_section_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_LABEL)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	return label


func _make_chip(text: String, accent_color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.10)
	style.border_color = accent_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	chip.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	chip.add_child(margin)

	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", accent_color)
	margin.add_child(label)
	return chip


func _configure_ai_defaults(ai_config: AIConfig) -> void:
	ai_config.search_depth = DEFAULT_MINIMAX_DEPTH
	ai_config.rollout_limit = DEFAULT_MCTS_ROLLOUTS
	match ai_config.controller_type:
		GameTypes.ControllerType.MINIMAX:
			ai_config.time_budget_ms = DEFAULT_MINIMAX_TIME_MS
		GameTypes.ControllerType.MCTS:
			ai_config.time_budget_ms = DEFAULT_MCTS_TIME_MS
		_:
			ai_config.time_budget_ms = DEFAULT_MCTS_TIME_MS


func _apply_config_to_controls() -> void:
	var config: MatchConfig = AppState.current_match_config
	_select_controller(_p1_controller, config.player_one_ai.controller_type)
	_select_controller(_p2_controller, config.player_two_ai.controller_type)
	_select_map(config.map_id)
	config.max_turns = DEFAULT_TURN_LIMIT
	_configure_ai_defaults(config.player_one_ai)
	_configure_ai_defaults(config.player_two_ai)
	_turns_value = DEFAULT_TURN_LIMIT
	_depth_value = DEFAULT_MINIMAX_DEPTH
	_rollouts_value = DEFAULT_MCTS_ROLLOUTS
	if _turns_value_label != null:
		_turns_value_label.text = str(_turns_value)
	if _depth_value_label != null:
		_depth_value_label.text = str(_depth_value)
	if _rollouts_value_label != null:
		_rollouts_value_label.text = str(_rollouts_value)


func _select_controller(option: OptionButton, controller_type: int) -> void:
	for index in range(option.item_count):
		if int(option.get_item_metadata(index)) == controller_type:
			option.select(index)
			return


func _select_map(map_id: String) -> void:
	for index in range(_map_select.item_count):
		if str(_map_select.get_item_metadata(index)) == map_id:
			_map_select.select(index)
			return


func _on_setup_changed(_value: Variant = null) -> void:
	var config: MatchConfig = AppState.current_match_config
	config.player_one_ai.controller_type = int(_p1_controller.get_item_metadata(_p1_controller.selected))
	config.player_two_ai.controller_type = int(_p2_controller.get_item_metadata(_p2_controller.selected))
	config.map_id = str(_map_select.get_item_metadata(_map_select.selected))
	_turns_value = DEFAULT_TURN_LIMIT
	_depth_value = DEFAULT_MINIMAX_DEPTH
	_rollouts_value = DEFAULT_MCTS_ROLLOUTS
	config.max_turns = DEFAULT_TURN_LIMIT
	_configure_ai_defaults(config.player_one_ai)
	_configure_ai_defaults(config.player_two_ai)
	config.ai_vs_ai_mode = config.player_one_ai.controller_type != GameTypes.ControllerType.HUMAN and config.player_two_ai.controller_type != GameTypes.ControllerType.HUMAN
	AppState.save_preferences()
	_refresh_summary()


func _refresh_summary() -> void:
	var config: MatchConfig = AppState.current_match_config
	var replay_ready: String = "Ready" if not AppState.current_replay.turns.is_empty() else "Empty"
	if _replay_button != null:
		_replay_button.disabled = AppState.current_replay.turns.is_empty()

	# Version label
	if _version_label != null:
		_version_label.text = "%s  |  %s" % [AppState.game_version, AppState.build_label.replace("-", " ")]

	# Session snapshot values
	if _snap_build_val != null:
		_snap_build_val.text = AppState.build_label.replace("-", " ")
	if _snap_ctrl_val != null:
		_snap_ctrl_val.text = "[color=#77b8ff]P1 %s[/color]  |  [color=#ff8a76]P2 %s[/color]" % [
			_controller_label(config.player_one_ai.controller_type),
			_controller_label(config.player_two_ai.controller_type),
		]
	if _snap_map_val != null:
		_snap_map_val.text = _map_display_name(config.map_id)
	if _snap_replay_val != null:
		_snap_replay_val.text = replay_ready
	if _snap_scale_val != null:
		_snap_scale_val.text = "%.2fx" % AppState.ui_scale
	if _snap_motion_val != null:
		_snap_motion_val.text = "%s  |  %s" % [
			"Reduced" if AppState.reduced_motion else "Standard",
			"High" if AppState.high_contrast_mode else "Standard",
		]

	# Arena preview
	if _arena_preview_title_label != null:
		_arena_preview_title_label.text = _map_display_name(config.map_id)
	if _arena_preview_label != null:
		_arena_preview_label.text = _map_preview_text(config.map_id)

	# Match rules
	if _rules_p1_val != null:
		_rules_p1_val.text = _controller_label(config.player_one_ai.controller_type)
	if _rules_p2_val != null:
		_rules_p2_val.text = _controller_label(config.player_two_ai.controller_type)
	if _rules_turns_val != null:
		_rules_turns_val.text = str(config.max_turns)
	if _rules_mode_val != null:
		_rules_mode_val.text = "Auto AI" if config.ai_vs_ai_mode else "Human Ready"


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


func _map_display_name(map_id: String) -> String:
	match map_id:
		"standard":
			return "Buried Front"
		"open":
			return "Open Arena"
		"fortress":
			return "Fortress Arena"
		"labyrinth":
			return "Labyrinth Arena"
		_:
			return map_id.capitalize()


func _map_preview_text(map_id: String) -> String:
	match map_id:
		"labyrinth":
			return "Dense lanes and risky center routes."
		"fortress":
			return "Tighter corridors and defensive pressure."
		"open":
			return "Open lanes and faster flanks."
		_:
			return "Random 70-75 destructible objects bury the spawns and seal the center until routes are blasted open."


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


func _on_open_match_pressed() -> void:
	_on_setup_changed()
	_transition_to(MATCH_SCENE)


func _on_open_replay_pressed() -> void:
	_transition_to(REPLAY_SCENE)


func _on_open_help_pressed() -> void:
	_transition_to(HELP_SCENE)


func _on_open_settings_pressed() -> void:
	_transition_to(SETTINGS_SCENE)


func _on_reset_state_pressed() -> void:
	AppState.reset_runtime_state()
	_apply_config_to_controls()
	_refresh_summary()


func _on_exit_game_pressed() -> void:
	get_tree().quit()
