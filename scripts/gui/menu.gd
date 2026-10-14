class_name Menu

extends Control

enum State { MODE_OFF, MODE_START, MODE_PAUSE }
enum Action { ACTION_NOOP, ACTION_START, ACTION_RESUME, ACTION_QUIT }

var _mode: int = State.MODE_START
var _last_action: int = Action.ACTION_NOOP
var _is_web_export := false
var _level := 0

@onready var _open_sound := get_node(^"%OpenSound") as AudioStreamPlayer
@onready var _input := get_node(^"%Input") as LineEdit
@onready var _start_button := get_node(^"%StartMenu") as Control
@onready var _pause_menu := get_node(^"%PauseMenu") as Control
@onready var _quit_button := _start_button.get_node(^"VBoxContainer/QuitButton") as Button
@onready var _collision_toggle := get_node(^"%CollisionToggle") as CheckButton
@onready var _explosion_toggle := get_node(^"%ExplosionToggle") as CheckButton
@onready var _level_label := get_node_or_null(^"%LevelLabel") as Label


func _ready() -> void:
	_input.set_text(SettingsManager.get_value(&"marbles", &"marble_names"))
	# Enter in the name field starts the match (the field swallows the key otherwise).
	_input.text_submitted.connect(func(_t: String) -> void: _on_StartButton_pressed())
	_collision_toggle.button_pressed = SettingsManager.get_value(&"marbles", &"collision_enabled")
	_explosion_toggle.button_pressed = SettingsManager.get_value(&"marbles", &"explosion_enabled")
	_level = clampi(int(SettingsManager.get_value(&"marbles", &"level")), 0, max(0, Levels.LEVELS.size() - 1))
	_refresh_level()

	_is_web_export = OS.get_name() == "HTML5"
	set_mode(_mode)


# --- Level selector (solo / level tester) -----------------------------------

func get_level() -> int:
	return _level


func set_level(idx: int) -> void:
	_level = clampi(idx, 0, max(0, Levels.LEVELS.size() - 1))
	_refresh_level()


func _refresh_level() -> void:
	if _level_label == null:
		return
	if Levels.LEVELS.is_empty():
		_level_label.text = "—"
		return
	_level_label.text = "Level %d · %s" % [_level + 1, str(Levels.LEVELS[_level].get("name", ""))]


func _on_PrevLevel_pressed() -> void:
	set_level(_level - 1)
	_persist_level()


func _on_NextLevel_pressed() -> void:
	set_level(_level + 1)
	_persist_level()


func _persist_level() -> void:
	SettingsManager.set_value(&"marbles", &"level", _level)


func _on_StartButton_pressed() -> void:
	_last_action = Action.ACTION_START
	set_mode(State.MODE_OFF)


func _on_ResumeButton_pressed() -> void:
	_last_action = Action.ACTION_RESUME
	set_mode(State.MODE_OFF)


func _on_QuitButton_pressed() -> void:
	_last_action = Action.ACTION_QUIT
	if _mode == State.MODE_START:
		get_tree().quit()
	elif _mode == State.MODE_PAUSE:
		set_mode(State.MODE_START)


func _on_CollisionToggle_toggled(pressed: bool):
	_collision_toggle.button_pressed = pressed
	SettingsManager.set_value(&"marbles", &"collision_enabled", pressed)


func _on_ExplosionToggle_toggled(pressed: bool):
	_explosion_toggle.button_pressed = pressed
	SettingsManager.set_value(&"marbles", &"explosion_enabled", pressed)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible and _open_sound:
				_open_sound.play()


func get_names() -> PackedStringArray:
	var input_text = _input.get_text()
	if input_text:
		return input_text.split(",")
	return PackedStringArray()


func set_mode(mode: int) -> void:
	_mode = mode

	if _mode == State.MODE_START:
		_start_button.show()
		_pause_menu.hide()

		if _is_web_export:
			_quit_button.disabled = true
	elif _mode == State.MODE_PAUSE:
		_start_button.hide()
		_pause_menu.show()

		if _is_web_export:
			_quit_button.disabled = false

	if _mode == State.MODE_OFF:
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func open_start_menu() -> void:
	set_mode(State.MODE_START)


func open_pause_menu() -> void:
	set_mode(State.MODE_PAUSE)


func close() -> void:
	set_mode(State.MODE_OFF)


func is_start() -> bool:
	return _last_action == Action.ACTION_START


func is_resume() -> bool:
	return _last_action == Action.ACTION_RESUME


func is_quit() -> bool:
	return _last_action == Action.ACTION_QUIT


func _on_Input_text_changed(new_text):
	SettingsManager.set_value(&"marbles", &"marble_names", new_text)
