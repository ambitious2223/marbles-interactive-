class_name SettingsMenu
extends CanvasLayer
## In-game settings overlay — a backup for the Tikora hub's Game Settings when
## the streamer is sitting in the game window. Everything the hub can change is
## editable here too; changes apply live and persist to user://.
##
## Open with ESC in hub mode (the hub keeps its own copy in sync via report_state).

const CAM_ACTIONS := [
	["cycle", "Cycle camera"],
	["next", "Next viewer"],
	["top1", "Follow 1st"],
	["top2", "Follow 2nd"],
	["top3", "Follow 3rd"],
	["overview", "Overview"],
	["auto", "Auto"],
]

const CONTROL_ACTIONS := [
	["start", "Start match"],
	["restart", "Restart match"],
]

var main: Main

var _open := false
var _cap_slider: HSlider
var _round_slider: HSlider
var _level_slider: HSlider
var _cap_val: Label
var _round_val: Label
var _level_val: Label
var _alerts: CheckButton
var _feed: CheckButton
var _shake: CheckButton
var _hud_toggle: CheckButton
var _rank_toggle: CheckButton
var _scale_slider: HSlider
var _scale_val: Label
var _key_fields := {}       # camera cfg key -> LineEdit
var _control_fields := {}   # controls cfg key -> LineEdit
var _fullscreen: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


# --- public API -------------------------------------------------------------

func open() -> void:
	_sync_from_cfg()
	_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	_open = false
	visible = false


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func is_open() -> bool:
	return _open


# --- UI construction --------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	sb.border_color = Color(0.30, 0.80, 0.75, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Applies live · saved automatically · also synced to the hub"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	# --- Gameplay ---
	list.add_child(_section("Gameplay"))

	_cap_val = Label.new()
	_cap_slider = _slider_row(list, "Marbles (capacity)", 4, 40, 1, _cap_val, func(v: float) -> void:
		_commit("capacity", int(v))
	)
	_round_val = Label.new()
	_round_slider = _slider_row(list, "Round length (seconds)", 20, 300, 5, _round_val, func(v: float) -> void:
		_commit("round_seconds", float(v))
	)
	_level_val = Label.new()
	_level_slider = _slider_row(list, "Starting level", 1, max(1, Levels.LEVELS.size()), 1, _level_val, func(v: float) -> void:
		_commit("level", int(v))
		_level_val.text = _level_label(int(v))
	)

	# --- Overlays ---
	list.add_child(_section("Stream overlays"))
	_alerts = _check_row(list, "Gift alerts", func(on: bool) -> void: _commit("alerts", on))
	_feed = _check_row(list, "Event feed", func(on: bool) -> void: _commit("feed", on))
	_shake = _check_row(list, "Screen shake", func(on: bool) -> void: _commit("shake", on))

	# --- Interface (live overlay controls) ---
	list.add_child(_section("Interface"))
	_hud_toggle = _check_row(list, "Show HUD", func(on: bool) -> void: _commit("hud", on))
	_rank_toggle = _check_row(list, "Show rankings", func(on: bool) -> void: _commit("ranking", on))
	_scale_val = Label.new()
	_scale_slider = _slider_row(list, "UI scale", 0.6, 1.5, 0.05, _scale_val, func(v: float) -> void:
		_commit("hud_scale", v)
	)

	# --- Camera keys ---
	list.add_child(_section("Camera keys"))
	var cam: Dictionary = main.cfg.get("camera", {}) if main != null else {}
	for pair in CAM_ACTIONS:
		var cfg_key := str(pair[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lbl := Label.new()
		lbl.text = str(pair[1])
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		row.add_child(lbl)
		var le := LineEdit.new()
		le.text = str(cam.get(cfg_key, ""))
		le.max_length = 12
		le.custom_minimum_size = Vector2(120, 0)
		le.placeholder_text = "key"
		le.text_changed.connect(func(t: String) -> void: _commit_camera(cfg_key, t))
		row.add_child(le)
		_key_fields[cfg_key] = le
		list.add_child(row)

	# --- Match controls (configurable start / restart keys) ---
	list.add_child(_section("Match controls"))
	var ctl: Dictionary = main.cfg.get("controls", {}) if main != null else {}
	for pair in CONTROL_ACTIONS:
		var ckey := str(pair[0])
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 10)
		var clbl := Label.new()
		clbl.text = str(pair[1])
		clbl.custom_minimum_size = Vector2(180, 0)
		clbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		crow.add_child(clbl)
		var cle := LineEdit.new()
		cle.text = str(ctl.get(ckey, ""))
		cle.max_length = 12
		cle.custom_minimum_size = Vector2(120, 0)
		cle.placeholder_text = "key"
		cle.text_changed.connect(func(t: String) -> void: _commit_control(ckey, t))
		crow.add_child(cle)
		_control_fields[ckey] = cle
		list.add_child(crow)

	# --- Footer ---
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	_fullscreen = _button(footer, "Fullscreen")
	_fullscreen.pressed.connect(func() -> void: main.toggle_fullscreen())
	var restart_btn := _button(footer, "Restart race")
	restart_btn.pressed.connect(func() -> void:
		close()
		main.restart_current_race()
	)
	var quit_btn := _button(footer, "Quit to Desktop")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	var close_btn := _button(footer, "Close")
	close_btn.pressed.connect(close)


func _section(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.30, 0.85, 0.80))
	return lbl


func _slider_row(parent: VBoxContainer, label: String, min_v: float, max_v: float, step: float, val_label: Label, on_change: Callable) -> HSlider:
	var head := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	head.add_child(lbl)
	val_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.85))
	head.add_child(val_label)
	parent.add_child(head)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
	return slider


func _check_row(parent: VBoxContainer, label: String, on_toggle: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = label
	cb.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	cb.toggled.connect(func(on: bool) -> void: on_toggle.call(on))
	parent.add_child(cb)
	return cb


func _button(parent: HBoxContainer, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	parent.add_child(b)
	return b


# --- state sync / commit ----------------------------------------------------

func _sync_from_cfg() -> void:
	if main == null:
		return
	var c: Dictionary = main.cfg
	_cap_slider.set_value_no_signal(float(c.get("capacity", 24)))
	_round_slider.set_value_no_signal(float(c.get("round_seconds", 75.0)))
	_level_slider.set_value_no_signal(float(c.get("level", 1)))
	_alerts.set_pressed_no_signal(_to_bool(c.get("alerts", true)))
	_feed.set_pressed_no_signal(_to_bool(c.get("feed", true)))
	_shake.set_pressed_no_signal(_to_bool(c.get("shake", true)))
	_hud_toggle.set_pressed_no_signal(_to_bool(c.get("hud", true)))
	_rank_toggle.set_pressed_no_signal(_to_bool(c.get("ranking", true)))
	_scale_slider.set_value_no_signal(float(c.get("hud_scale", 1.0)))
	_scale_val.text = "%d%%" % int(round(float(c.get("hud_scale", 1.0)) * 100.0))
	_cap_val.text = str(int(c.get("capacity", 24)))
	_round_val.text = "%ds" % int(c.get("round_seconds", 75.0))
	_level_val.text = _level_label(int(c.get("level", 1)))
	var cam: Dictionary = c.get("camera", {})
	for k in _key_fields.keys():
		_key_fields[k].text = str(cam.get(k, ""))
	var ctl: Dictionary = c.get("controls", {})
	for k in _control_fields.keys():
		_control_fields[k].text = str(ctl.get(k, ""))
	if _fullscreen:
		var fs := get_window().mode == Window.MODE_FULLSCREEN
		_fullscreen.text = "Windowed" if fs else "Fullscreen"


func _commit(key: String, value) -> void:
	if main == null:
		return
	if key == "capacity":
		_cap_val.text = str(int(value))
	elif key == "round_seconds":
		_round_val.text = "%ds" % int(value)
	elif key == "hud_scale":
		_scale_val.text = "%d%%" % int(round(float(value) * 100.0))
	main.apply_settings_payload({ key: value })


func _commit_camera(cfg_key: String, text: String) -> void:
	if main == null:
		return
	var cam: Dictionary = main.cfg.get("camera", {}).duplicate()
	cam[cfg_key] = text.strip_edges()
	main.apply_settings_payload({ "camera": cam })


func _commit_control(cfg_key: String, text: String) -> void:
	if main == null:
		return
	var ctl: Dictionary = main.cfg.get("controls", {}).duplicate()
	ctl[cfg_key] = text.strip_edges()
	main.apply_settings_payload({ "controls": ctl })


func _level_label(n: int) -> String:
	var i := clampi(n - 1, 0, max(0, Levels.LEVELS.size() - 1))
	if Levels.LEVELS.is_empty():
		return str(n)
	return "%d · %s" % [n, str(Levels.LEVELS[i].get("name", ""))]


func _to_bool(v) -> bool:
	if typeof(v) == TYPE_STRING:
		return v.strip_edges().to_lower() in ["1", "true", "yes", "on"]
	return bool(v)
