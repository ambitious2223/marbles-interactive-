class_name Main
extends Node

enum State { MODE_START, MODE_PAUSE, MODE_MARBLE }

const RotationCameraScene := preload("res://scenes/camera/rotation_camera.tscn")
const MarbleCameraScene := preload("res://scenes/camera/marble_camera.tscn")
const Group := preload("res://scripts/constants/groups.gd")
const NameGenerator := preload("res://scripts/utils/name_generator.gd")
const TikoraControllerScript := preload("res://scripts/tikora/tikora_controller.gd")
const MarbleScene := preload("res://scenes/marble.tscn")
const StreamHudScript := preload("res://scripts/ui/stream_hud.gd")

const CONFIG_PATH := "user://marble_royale.cfg"
const PLAYERS_PATH := "user://marble_royale_players.json"
const START_COLS := 3
# Defaults — overridable from the hub via the `configure` effect (persisted).
const DEFAULT_CFG := {
	"capacity": 24,
	"round_seconds": 75.0,
	"alerts": true,
	"feed": true,
	"shake": true,
	"level": 1,
	"camera": {
		"cycle": "C", "next": "X",
		"top1": "1", "top2": "2", "top3": "3",
		"overview": "O", "auto": "A",
	},
}
var cfg := DEFAULT_CFG.duplicate(true)
var _grid_rows := 8
var _round_max := 75.0
var _track_no := 0
var _level_index := 0        # level used for the NEXT round (0-based)
var _level_applied := 0      # level currently running (for the HUD)
var _world_env: WorldEnvironment

const TIME_PERIOD := 5  # 500ms

var _rotation_camera = null
var _marble_camera = null
var _mode: int = State.MODE_START
var _current_marble_index := 0
var _time := 0.0
var _explosion_enabled := false
var _race_has_started := false
var _lower_boundary = null

# Variables used in explosion mode to check
# if we need to generate another chunk of the race
var _max_checkpoint_count := -1
var _old_lap_count := 0

# There are limited places to ensure equality among the marbles.
# TODO : remove this limit
var _positions := []

# --- Tikora hub mode ---
var hub_mode := false
var _hub_names := {}            # lower(username) -> Marble (current round)
var _hub_tiers := {}            # lower(username) -> tier (persists across rounds)
var _hub_roster: Array = []     # persistent viewer keys (one marble per viewer)
var _hub_display := {}          # key -> display name
var _hub_avatars := {}          # key -> profile photo URL
var _downed := {}               # key -> true while their marble has fallen
var _respawn_at := {}           # key -> seconds timestamp for a free respawn
var _profiles := {}             # key -> { name, races, wins, top3, streak, coins }
var _camera_mode := "auto"      # auto | follow | overview
var _camera_follow = null
var _hub_pending: Array = []    # (legacy, unused in hub mode)
var _hub_restart_in := -1.0
var _hub_round_time := 0.0
var _hud: StreamHud

@onready var _pause_menu := get_node(^"%Menu") as Menu
@onready var _race := get_node(^"%Race") as Race
@onready var _overlay := get_node(^"%Overlay") as Overlay
@onready var _marble_pool := get_node(^"%MarblePool") as Node3D
@onready var _timer := get_node(^"%Timer") as Timer
@onready var _ranking := get_tree().get_nodes_in_group(&"Ranking")[0] as Ranking
@onready var _explosion := get_node(^"%Explosion") as GPUParticles3D
@onready var _marbles = _marble_pool.get_children()
@onready var _panel_timer := _overlay.get_node(^"Panel2") as ColorRect
@onready var _label_timer = _overlay.get_node(^"Panel2/CenterContainer3/VBoxContainer/LabelTimer")
@onready var _countdown := get_node(^"%Countdown")
@onready var _podium := get_node(^"%Podium")


func _ready() -> void:
	_load_config()
	_load_profiles()
	_level_index = clamp(int(cfg.get("level", 1)) - 1, 0, max(0, Levels.LEVELS.size() - 1))
	_rotation_camera = RotationCameraScene.instantiate()
	_marble_camera = MarbleCameraScene.instantiate()
	reset_position()
	set_mode(_mode)
	add_child(TikoraControllerScript.new())
	_add_hud()
	_add_world_env()
	_apply_config()
	_setup_camera_input()


## Stream-facing HUD: round status, gift alerts, event feed.
func _add_hud() -> void:
	_hud = StreamHudScript.new()
	add_child(_hud)


func hud_alert(username: String, gift_name: String, avatar: String, tier: String) -> void:
	if _hud:
		_hud.show_alert(username, gift_name, avatar, tier)


func hud_feed(text: String, color: Color = Color.WHITE) -> void:
	if _hud:
		_hud.push_feed(text, color)


func hud_status(text: String) -> void:
	if _hud:
		_hud.set_status(text)


func hud_celebrate(username: String, avatar: String) -> void:
	if _hud:
		_hud.celebrate(username, avatar)


## Remember a viewer's profile photo so alerts/celebration can show it.
func hub_set_avatar(username: String, url: String) -> void:
	if url != "":
		_hub_avatars[username.to_lower()] = url


## Finish a hub round: crown the winner, celebrate, and schedule the restart.
func _end_hub_round(winner) -> void:
	_hub_restart_in = 8.0
	if winner == null:
		hud_status("Round over — new race shortly…")
		return
	var wname := str(winner.get_marble_name())
	print("[MarbleRoyale] round over — winner: ", wname)
	hud_status("🥇 %s wins!  New race shortly…" % wname)
	hud_feed("🥇 %s took 1st place" % wname, Color(1, 0.85, 0.3))
	hud_celebrate(wname, str(_hub_avatars.get(wname.to_lower(), "")))
	# Journey: record the result and refresh the all-time board.
	var wp := _profile(wname.to_lower(), wname)
	wp.wins = int(wp.wins) + 1
	wp.streak = int(wp.streak) + 1
	for m in [_ranking._second_marble, _ranking._third_marble]:
		if m != null and is_instance_valid(m):
			var nm := str(m.get_marble_name())
			var pp := _profile(nm.to_lower(), nm)
			pp.top3 = int(pp.top3) + 1
	_save_profiles()
	_update_leaderboard()


# --- Falls + respawn --------------------------------------------------------

func hub_mark_down(key: String, display: String) -> void:
	if key == "":
		return
	_downed[key] = true
	hud_feed("💫 @%s fell out!" % display, Color(1.0, 0.7, 0.6))


## Free respawn via comment/like (after a short delay); instant via gift.
func hub_request_respawn(username: String, instant: bool) -> void:
	var key := username.strip_edges().to_lower()
	if key == "" or not _downed.has(key):
		return
	if instant:
		_do_respawn(key)
	elif not _respawn_at.has(key):
		_respawn_at[key] = Time.get_ticks_msec() / 1000.0 + 3.0
		hud_feed("♻ @%s is spawning again…" % username, Color(0.8, 0.9, 1.0))


func _do_respawn(key: String) -> void:
	_respawn_at.erase(key)
	_downed.erase(key)
	var marble = _hub_names.get(key)
	if marble == null or not is_instance_valid(marble):
		return
	var ref = _trailing_marble()
	if ref != null and ref != marble:
		marble.global_position = ref.global_position + Vector3.UP * 2.0 + Vector3.BACK * 2.0
	else:
		var piece = get_highest_piece()
		if piece != null:
			marble.global_position = piece.position + Vector3.UP * 5
	marble.roll()
	hud_feed("♻ @%s is back in the race" % str(_hub_display.get(key, key)), Color(0.7, 1.0, 0.8))


func _trailing_marble():
	var best = null
	for m in _marbles:
		if m.visible and m.in_race():
			if best == null or m.get_checkpoint_count() < best.get_checkpoint_count():
				best = m
	return best


# --- Camera (streamer controls; keys configurable via hub settings) ---------

func _setup_camera_input() -> void:
	var cam: Dictionary = cfg.get("camera", {})
	var actions := {
		"cam_cycle": "cycle", "cam_next": "next",
		"cam_top1": "top1", "cam_top2": "top2", "cam_top3": "top3",
		"cam_overview": "overview", "cam_auto": "auto",
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		var key_name := str(cam.get(actions[action], ""))
		var kc := OS.find_keycode_from_string(key_name) if key_name != "" else 0
		if kc != 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			InputMap.action_add_event(action, ev)


func _camera_target_marble():
	if _camera_mode == "follow" and _camera_follow != null and is_instance_valid(_camera_follow) and _camera_follow.visible:
		return _camera_follow
	return _ranking._first_marble


func _update_camera() -> void:
	if _camera_mode == "overview":
		if not _rotation_camera.is_inside_tree():
			replace_camera(_rotation_camera, [_marble_camera])
		_rotation_camera.target = Vector3.ZERO
		_rotation_camera.distance_to_target = 50.0
		return
	var target = _camera_target_marble()
	if target != null and is_instance_valid(target) and target.visible:
		if _marble_camera.get_target() != target:
			_marble_camera.set_target(target)
		if not _marble_camera.is_inside_tree():
			replace_camera(_marble_camera, [_rotation_camera])


func _set_camera_mode(mode: String, follow = null) -> void:
	_camera_mode = mode
	_camera_follow = follow
	var who := ""
	if mode == "follow" and follow != null and is_instance_valid(follow):
		who = " — @%s" % str(follow.get_marble_name())
	hud_feed("🎥 Camera: %s%s" % [mode, who], Color(0.8, 0.85, 1.0))


func _cam_cycle() -> void:
	if _camera_mode == "auto":
		_set_camera_mode("follow", _ranking._first_marble)
	elif _camera_mode == "follow":
		_set_camera_mode("overview")
	else:
		_set_camera_mode("auto")


func _cam_next() -> void:
	var vis := []
	for m in _marbles:
		if m.visible and m.in_race():
			vis.append(m)
	if vis.is_empty():
		_set_camera_mode("auto")
		return
	var i := vis.find(_camera_follow)
	_set_camera_mode("follow", vis[(i + 1) % vis.size()])


func _cam_follow_rank(n: int) -> void:
	var m = null
	if n == 1:
		m = _ranking._first_marble
	elif n == 2:
		m = _ranking._second_marble
	else:
		m = _ranking._third_marble
	if m != null:
		_set_camera_mode("follow", m)


# --- Settings (hub-driven, persisted to user://) ----------------------------

func _load_config() -> void:
	var f := ConfigFile.new()
	if f.load(CONFIG_PATH) != OK:
		return
	for k in cfg.keys():
		if f.has_section_key("settings", str(k)):
			cfg[k] = f.get_value("settings", str(k))


func _save_config() -> void:
	var f := ConfigFile.new()
	for k in cfg.keys():
		f.set_value("settings", str(k), cfg[k])
	f.save(CONFIG_PATH)


func _apply_config() -> void:
	cfg.capacity = clamp(int(cfg.capacity), 4, 40)
	cfg.round_seconds = clamp(float(cfg.round_seconds), 20.0, 300.0)
	cfg.alerts = _to_bool(cfg.alerts)
	cfg.feed = _to_bool(cfg.feed)
	cfg.shake = _to_bool(cfg.shake)
	cfg.level = clamp(int(cfg.get("level", 1)), 1, max(1, Levels.LEVELS.size()))
	_grid_rows = int(ceil(float(cfg.capacity) / float(START_COLS)))
	_round_max = float(cfg.round_seconds)
	if _hud != null:
		_hud.set_alerts_enabled(cfg.alerts)
		_hud.set_feed_enabled(cfg.feed)
	if hub_mode:
		_ensure_marble_capacity(int(cfg.capacity))


## The hub can change any setting by sending the `configure` effect with a payload.
func _hub_configure(payload: Dictionary) -> void:
	for k in ["capacity", "round_seconds", "alerts", "feed", "shake", "level"]:
		if payload.has(k):
			cfg[k] = payload[k]
	_apply_config()
	if payload.has("level"):
		_level_index = clamp(int(cfg.level) - 1, 0, max(0, Levels.LEVELS.size() - 1))
		_apply_level(_level_index)
	if payload.has("camera") and typeof(payload["camera"]) == TYPE_DICTIONARY:
		var cam: Dictionary = cfg.get("camera", {}).duplicate()
		cam.merge(payload["camera"], true)
		cfg["camera"] = cam
		_setup_camera_input()
	_save_config()
	print("[MarbleRoyale] configure: ", cfg)
	hud_feed("⚙ settings: cap %d · round %ds · alerts %s · shake %s" % [
		int(cfg.capacity), int(cfg.round_seconds), str(cfg.alerts), str(cfg.shake)
	], Color(0.8, 0.9, 1.0))
	report_config()


## Push current settings back to the hub UI.
func report_config() -> void:
	TikoraHub.report_state({ "config": cfg, "track": _track_no })


func _do_shake(intensity: float, dur: float) -> void:
	if cfg.shake:
		Shake.shake(intensity, dur)


func _to_bool(v) -> bool:
	if typeof(v) == TYPE_STRING:
		return v.strip_edges().to_lower() in ["1", "true", "yes", "on"]
	return bool(v)


# --- Viewer journey (per-player profiles) -----------------------------------

func _load_profiles() -> void:
	if not FileAccess.file_exists(PLAYERS_PATH):
		return
	var f := FileAccess.open(PLAYERS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_profiles = data


func _save_profiles() -> void:
	var f := FileAccess.open(PLAYERS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_profiles))


func _profile(key: String, display: String) -> Dictionary:
	if key == "":
		key = display.to_lower()
	if not _profiles.has(key):
		_profiles[key] = { "name": display, "races": 0, "wins": 0, "top3": 0, "streak": 0, "coins": 0 }
	else:
		_profiles[key]["name"] = display
	return _profiles[key]


func hub_add_coins(username: String, coins: int) -> void:
	var p := _profile(username.to_lower(), username)
	p.coins = int(p.coins) + coins


func hub_show_stats(username: String) -> void:
	var key := username.to_lower()
	if not _profiles.has(key):
		hud_feed("📊 @%s — no races yet" % username, Color(0.9, 0.95, 1.0))
		return
	var p: Dictionary = _profiles[key]
	hud_feed("📊 @%s — %d races · %d wins · %d top-3 · streak %d · %d coins" % [
		username, int(p.races), int(p.wins), int(p.top3), int(p.streak), int(p.coins)
	], Color(0.9, 0.95, 1.0))


func _alltime_top(n: int) -> Array:
	var arr := []
	for k in _profiles.keys():
		var p: Dictionary = _profiles[k]
		arr.append({ "name": str(p.get("name", k)), "wins": int(p.get("wins", 0)) })
	arr.sort_custom(func(a, b): return int(a.wins) > int(b.wins))
	return arr.slice(0, n)


func _update_leaderboard() -> void:
	if _hud:
		_hud.set_leaderboard(_alltime_top(5))


# --- Levels ----------------------------------------------------------------

func _add_world_env() -> void:
	var base = load("res://resources/default_env.tres")
	if base == null:
		return
	var env: Environment = base.duplicate(true)
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)


func _level_name() -> String:
	if Levels.LEVELS.is_empty():
		return "Level"
	return str(Levels.LEVELS[_level_applied].get("name", "Level"))


func _apply_level(idx: int) -> void:
	var n := Levels.LEVELS.size()
	if n == 0:
		return
	_level_applied = ((idx % n) + n) % n
	var lv: Dictionary = Levels.LEVELS[_level_applied]
	_race._step_count = int(lv.get("steps", 10))
	_race.piece_pool = lv.get("pool", [])
	_apply_sky(lv.get("sky", Levels.SKY_DAY))
	print("[MarbleRoyale] level %d · %s" % [_level_applied + 1, _level_name()])


func _apply_sky(cols: Array) -> void:
	if _world_env == null or cols.size() < 3:
		return
	var env: Environment = _world_env.environment
	if env == null:
		return
	env.ambient_light_color = Color(1, 1, 1).lerp(cols[2], 0.4)
	if env.sky and env.sky.sky_material is ShaderMaterial:
		var mat: ShaderMaterial = env.sky.sky_material
		for p in ["day_top_color", "sunset_top_color", "night_top_color"]:
			mat.set_shader_parameter(p, cols[0])
		for p in ["day_bottom_color", "sunset_bottom_color", "night_bottom_color"]:
			mat.set_shader_parameter(p, cols[1])
		mat.set_shader_parameter("horizon_color", cols[2])


func _exit_tree():
	if not _rotation_camera.is_inside_tree():
		_rotation_camera.free()
	if not _marble_camera.is_inside_tree():
		_marble_camera.free()


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if hub_mode:
				if event.is_action_pressed("cam_cycle"):
					_cam_cycle()
				elif event.is_action_pressed("cam_next"):
					_cam_next()
				elif event.is_action_pressed("cam_overview"):
					_set_camera_mode("overview")
				elif event.is_action_pressed("cam_auto"):
					_set_camera_mode("auto")
				elif event.is_action_pressed("cam_top1"):
					_cam_follow_rank(1)
				elif event.is_action_pressed("cam_top2"):
					_cam_follow_rank(2)
				elif event.is_action_pressed("cam_top3"):
					_cam_follow_rank(3)
			match event.keycode:
				KEY_F11:
					var win := get_window()
					win.mode = Window.MODE_WINDOWED if win.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
				KEY_TAB:
					if _mode == State.MODE_MARBLE:
						var visible_marbles := []
						for marble in _marbles:
							if marble.visible:
								visible_marbles.append(marble)

						var marble_count = len(visible_marbles)
						if marble_count != 0:
							if _current_marble_index >= marble_count:
								_current_marble_index = 0
							else:
								_current_marble_index += 1
							_marble_camera.set_target(
								visible_marbles[_current_marble_index % marble_count]
							)

						else:
							printerr("No marble to focus on!")

				KEY_ESCAPE:
					if _mode != State.MODE_START and _mode != State.MODE_PAUSE:
						set_mode(State.MODE_PAUSE)

				# Debug command to spawn a new marble
				KEY_T:
					if _mode == State.MODE_MARBLE:
						var all_marble_has_finish = true
						for marble in _marbles:
							all_marble_has_finish = marble.has_finish()
							if not all_marble_has_finish:
								break

						if all_marble_has_finish:
							_overlay.reset()
							reset_position()

						var marble = try_place_start_marble()
						if marble != null:
							marble.set_marble_name(NameGenerator.generate())
							_overlay.add_marble_rank(marble)

				# Debug command to generate a new race
				KEY_R:
					if _mode == State.MODE_MARBLE:
						_race.generate_race(!_explosion_enabled)
						_lower_boundary = get_lowest_piece(_race, true).global_transform.origin.y

				KEY_SPACE:
					for marble in _marbles:
						var marble_name = marble.get_marble_name().to_lower()
						if marble_name == &"maxime" or marble_name == &"max":
							marble.set_linear_velocity(-marble.linear_velocity * 2)
							break


# Reset marble positions
func reset_position() -> void:
	_positions = []
	for i in range(_grid_rows):
		for j in range(START_COLS):
			_positions.append([i, j])


# Try placing a new marble on the start line
func try_place_start_marble() -> Marble:
	var piece = get_highest_piece()
	if piece == null:
		return null
	if len(_positions) == 0:
		printerr("There are limited places to ensure equality among the marbles.")
		return null
	randomize()
	var position = _positions.pop_at(randi() % len(_positions))

	var new_marble = null
	for marble in _marbles:
		if not marble.visible:
			new_marble = marble
			break

	if new_marble == null:
		return null

	new_marble.position = (
		piece.position
		+ Vector3.UP * (5.0 + position[0] * 0.5)
		+ Vector3.FORWARD * (position[0] - (_grid_rows - 1) / 2.0)
		+ Vector3.RIGHT * (position[1] - (START_COLS - 1) / 2.0)
	)
	new_marble.roll()
	return new_marble


# Get the highest piece in the race
func get_highest_piece() -> Piece:
	var pieces = _race.get_children()
	if len(pieces) == 0:
		return null
	var highest_piece = null
	for piece in pieces:
		if not piece is Piece:
			continue
		if highest_piece == null:
			highest_piece = piece
		elif piece.position.y > highest_piece.position.y:
			highest_piece = piece
	return highest_piece


func get_lowest_piece(piece_or_race, recursive: bool = false) -> Piece:
	var pieces = piece_or_race.get_children()
	if len(pieces) == 0:
		return null

	# Find the lower piece from children of the current node3d
	var lowest_piece = null
	for piece in pieces:
		if not piece is Piece:
			continue
		if lowest_piece == null:
			lowest_piece = piece
		elif piece.position.y < lowest_piece.position.y:
			lowest_piece = piece

	if recursive:
		var child_lowest_piece = get_lowest_piece(lowest_piece)
		if child_lowest_piece != null:
			lowest_piece = child_lowest_piece
	return lowest_piece


# Replace cameras with a new one
func replace_camera(new_camera, old_cameras) -> void:
	# Ensure old cameras are removed from the current scene
	for camera in old_cameras:
		if camera.is_inside_tree():
			Main.remove_from_tree(camera)
	# And create a new one
	if not new_camera.is_inside_tree():
		add_child(new_camera)


func _on_timer_timeout():
	# Release SceneTree
	get_tree().set_pause(false)
	_timer.start()
	_race_has_started = true
	_hub_round_time = 0.0
	hud_status("🏁 Race in progress")

	# Put the camera at the right place for the start
	replace_camera(_marble_camera, [_rotation_camera])


# Set the game mode
func set_mode(mode):
	var start_a_new_race = false

	if mode != _mode:
		if _mode == State.MODE_PAUSE or _mode == State.MODE_START:
			# For each start action, delete all marbles
			if _pause_menu.is_start() or _pause_menu.is_quit():
				start_a_new_race = true
				for marble in _marbles:
					marble.pause()

				# Ensure the timer is reset
				_race_has_started = false
				_timer.set_wait_time(10)
				_timer.stop()

			# Ensure that the pause menu is closed
			if _pause_menu.visible:
				_pause_menu.close()

	_mode = mode

	if _mode == State.MODE_MARBLE:
		# If no marbles exist
		if start_a_new_race:
			_podium.hide()

			await Fade.fade_out(1, Color.BLACK, "Diamond", false, false).finished

			_explosion_enabled = SettingsManager.get_value(&"marbles", &"explosion_enabled") as bool
			_race.generate_race(!_explosion_enabled)
			_lower_boundary = get_lowest_piece(_race, true).global_transform.origin.y

			# Reset values at each new race
			_max_checkpoint_count = -1
			_old_lap_count = 0

			_overlay.reset()
			reset_position()

			# Show HUD
			_overlay.show()

			# Put the camera at the right place for the start
			replace_camera(_rotation_camera, [_marble_camera])

			# Focus the rotation camera on the marble start line
			_rotation_camera.target = get_highest_piece().global_position + Vector3.UP * 5
			_rotation_camera.distance_to_target = 10.0

			var names = _pause_menu.get_names()
			if hub_mode:
				names = _hub_pending.duplicate()
			if len(names) > 0:
				# Stop SceneTree, to make all the marbles leave at the same time
				get_tree().set_pause(true)

				# Create one marble for each name
				for marble_name in names:
					var marble = try_place_start_marble()
					if marble == null:
						break
					marble.set_marble_name(marble_name)
					_overlay.add_marble_rank(marble)
					_marble_camera.set_target(marble)

			await Fade.fade_in(1, Color.BLACK, "Diamond", false, false).finished
			_countdown.connect("countdown_finished", _on_timer_timeout, CONNECT_ONE_SHOT)
			_countdown.start()

		else:
			_overlay.show()

			replace_camera(_marble_camera, [_rotation_camera])

	elif _mode == State.MODE_START:
		_overlay.hide()
		_pause_menu.open_start_menu()
		replace_camera(_rotation_camera, [_marble_camera])
		# Focus the rotation camera on race
		_rotation_camera.target = Vector3.ZERO
		_rotation_camera.distance_to_target = 50.0

	elif _mode == State.MODE_PAUSE:
		_pause_menu.open_pause_menu()
		replace_camera(_rotation_camera, [_marble_camera])
		# Focus the rotation camera on race
		_rotation_camera.target = Vector3.ZERO
		_rotation_camera.distance_to_target = 50.0


# Remove a node from the scene tree
static func remove_from_tree(node):
	node.get_parent().remove_child(node)


func _process(delta):
	_time += delta

	if _time > TIME_PERIOD:
		if _mode == State.MODE_START and not hub_mode:
			# Regenerate race
			_race.generate_race(true)

			# Reset timer
			_time = 0

	if _mode != State.MODE_START and _explosion_enabled:
		var time_left := _timer.get_time_left()

		_panel_timer.show()
		_label_timer.set_text("%d:%02d" % [floor((time_left + 1) / 60), int(time_left + 1) % 60])

		if time_left == 0.0 and _race_has_started:
			_timer.start()

			if _ranking._last_marble != null:
				var skip := explosion_victory(_ranking._last_marble)

				if !skip:
					_ranking._last_marble.explode()

					_explosion.global_position = _ranking._last_marble.global_position
					_explosion.set_emitting(true)

		if _ranking._first_marble:
			# If a new checkpoint is crossed by the first marble
			if _ranking._first_marble._checkpoint_count > _max_checkpoint_count:
				# Store the max number of checkpoints crossed
				_max_checkpoint_count = _ranking._first_marble._checkpoint_count

				# Compute the lap (1 lap equals  to one chunk)
				var lap_count := ceili(_max_checkpoint_count / (_race._step_count - 3.0))
				# If one more lap was done
				if lap_count > _old_lap_count:
					# Generate a chunk
					_race.generate_chunk()
					_lower_boundary = get_lowest_piece(_race, true).global_transform.origin.y
					_old_lap_count = lap_count
	else:
		_panel_timer.hide()

	if not hub_mode:
		if not _pause_menu.visible:
			if _mode == State.MODE_PAUSE or _mode == State.MODE_START:
				set_mode(State.MODE_MARBLE)
		else:
			if _mode == State.MODE_PAUSE and _pause_menu.is_quit():
				set_mode(State.MODE_START)

	# Hub mode: end the round when the leader finishes, or when the time limit hits
	# (so a stuck marble can never hang the loop).
	if hub_mode and _race_has_started and _hub_restart_in < 0.0:
		_hub_round_time += delta
		var lead = _ranking._first_marble
		if lead != null and (lead.has_finish() or _hub_round_time >= _round_max):
			_end_hub_round(lead)
	if _hub_restart_in >= 0.0:
		_hub_restart_in -= delta
		if _hub_restart_in <= 0.0:
			_hub_restart_in = -1.0
			start_hub_round()

	# Hub mode: streamer-controllable camera (auto follows the leader).
	if hub_mode:
		_update_camera()

	if not hub_mode and (not _marble_camera.has_target() or not _marble_camera.get_target().visible):
		var found = false
		for marble in _marbles:
			if marble.visible:
				found = true
				_marble_camera.set_target(marble)
				break
		if not found:
			replace_camera(_rotation_camera, [_marble_camera])

			# In hub mode the round end is handled by _end_hub_round (a late first
			# joiner must not be mistaken for "everyone finished").
			if _race_has_started and not hub_mode:
				_race_has_started = false
				_podium.show()
				_podium.set_first(_ranking._first_marble)
				_podium.set_second(_ranking._second_marble)
				_podium.set_third(_ranking._third_marble)
		else:
			# A marble is visible again — watch it, not the overview.
			replace_camera(_marble_camera, [_rotation_camera])

	# Check if some marbles are out of bound
	if _race_has_started and _lower_boundary != null:
		for marble in _marbles:
			if (
				marble.visible
				and marble._state == Marble.State.ROLL
				and marble.global_transform.origin.y + 100 < _lower_boundary
			):
				marble.out_of_bound()
				if hub_mode:
					var nm := str(marble.get_marble_name())
					hub_mark_down(nm.to_lower(), nm)
	if not _respawn_at.is_empty():
		var now_s := Time.get_ticks_msec() / 1000.0
		for key in _respawn_at.keys():
			if now_s >= float(_respawn_at[key]):
				_do_respawn(key)


# Handle victory conditions on explosion mode
func explosion_victory(_last_marble: Marble) -> bool:
	var marble_exploded_count := 0
	var tmp_marble = null

	for marble in _marbles:
		if marble.in_race() and marble.visible:
			marble_exploded_count += 1
			if _last_marble != marble:
				tmp_marble = marble

		if marble_exploded_count > 2:
			break

	if marble_exploded_count == 2:
		tmp_marble.finish()

	if marble_exploded_count == 1:
#		_last_marble.finish()
		return true

	if marble_exploded_count == 0:
		return true

	return false


# ============================================================================
# Tikora hub integration
# ============================================================================

## Switch to a continuous, streamer-free round loop driven by the hub.
func enable_hub_mode() -> void:
	if hub_mode:
		return
	hub_mode = true
	_pause_menu.close()
	_overlay.hide()
	_hub_names.clear()
	_ensure_marble_capacity(int(cfg.capacity))
	start_hub_round()


## Grow the marble pool at runtime so we can host more than the base's 14.
func _ensure_marble_capacity(n: int) -> void:
	var current := _marble_pool.get_child_count()
	for _i in range(current, n):
		_marble_pool.add_child(MarbleScene.instantiate())
	_marbles = _marble_pool.get_children()
	print("[MarbleRoyale] marble capacity: %d" % _marbles.size())


## Begin a fresh round: build a track, drop queued joiners, run the countdown.
func start_hub_round() -> void:
	_hub_restart_in = -1.0
	for marble in _marbles:
		marble.pause()
	_overlay.reset()
	reset_position()
	_explosion_enabled = false
	_track_no += 1
	# Apply the current level (length, piece mix, sky) then advance for next round.
	_apply_level(_level_index)
	_level_index = (_level_index + 1) % Levels.LEVELS.size()
	_race.generate_race(true)
	_lower_boundary = get_lowest_piece(_race, true).global_transform.origin.y
	_max_checkpoint_count = -1
	_old_lap_count = 0
	_podium.hide()
	_overlay.show()
	replace_camera(_rotation_camera, [_marble_camera])
	_rotation_camera.target = get_highest_piece().global_position + Vector3.UP * 5
	_rotation_camera.distance_to_target = 10.0
	_mode = State.MODE_MARBLE
	# Freeze until the countdown so everyone leaves together.
	get_tree().set_pause(true)
	# Re-spawn the whole persistent roster so the same viewers stay in the race.
	_hub_names.clear()
	for key in _hub_roster:
		_place_hub_marble(str(_hub_display.get(key, key)))
	hud_status("Level %d · %s — comment to join" % [_level_applied + 1, _level_name()])
	_countdown.connect("countdown_finished", _on_timer_timeout, CONNECT_ONE_SHOT)
	_countdown.start()


func _place_hub_marble(username: String) -> Marble:
	var marble := try_place_start_marble()
	if marble == null:
		return null
	marble.set_marble_name(username)
	marble.reset_skin()
	var tier = _hub_tiers.get(username.to_lower())
	if tier != null:
		marble.set_skin_tier(str(tier))
	_overlay.add_marble_rank(marble)
	_hub_names[username.to_lower()] = marble
	_marble_camera.set_target(marble)
	var p := _profile(username.to_lower(), username)
	p.races = int(p.races) + 1
	return marble


## Give a viewer a skin tier (persists across rounds; applied on next spawn too).
func hub_set_tier(username: String, tier: String) -> void:
	_hub_tiers[username.to_lower()] = tier
	var m := hub_marble_for(username)
	if m != null:
		m.set_skin_tier(tier)


## A viewer joined (comment). Place now if racing, otherwise queue for next round.
## A viewer joined (comment). Adds them to the persistent roster and, if a race
## is running, drops their marble in immediately (one marble per viewer).
func hub_join(username: String) -> void:
	var uname := username.strip_edges()
	if uname == "":
		return
	var key := uname.to_lower()
	_hub_display[key] = uname
	if not _hub_roster.has(key):
		_hub_roster.append(key)
		var p := _profile(key, uname)
		if int(p.get("races", 0)) > 0:
			hud_feed("👋 Welcome back @%s — %d wins" % [uname, int(p.get("wins", 0))], Color(1.0, 0.9, 0.6))
	if _mode != State.MODE_MARBLE:
		return
	var existing = _hub_names.get(key)
	# Already in this round (even if they finished / went out of bounds) — no dup.
	if existing != null and is_instance_valid(existing):
		return
	if _place_hub_marble(uname) != null:
		print("[MarbleRoyale] join: ", uname)
		hud_status("🏁 %d marbles racing — comment to join" % _hub_names.size())
		hud_feed("➕ @%s joined" % uname, Color(0.7, 0.9, 1.0))
		_update_leaderboard()


func hub_marble_for(username: String) -> Marble:
	var m = _hub_names.get(username.to_lower())
	if m != null and is_instance_valid(m) and m.visible:
		return m
	return null


## Apply a routed gift effect. Physics-only for now; skins come next.
func hub_apply_effect(effect: String, username: String, payload: Dictionary) -> void:
	if effect == "configure":
		_hub_configure(payload)
		return
	match effect:
		"boost":
			var t := hub_marble_for(username)
			if t != null:
				t.linear_velocity *= 2.0
		"hazard_shell", "hazard_bomb":
			var leader = _ranking._first_marble
			if leader != null:
				leader.linear_velocity *= 0.15
			_do_shake(2.5, 0.4)
		"hazard_banana", "slow_leader":
			var leader2 = _ranking._first_marble
			if leader2 != null:
				leader2.linear_velocity *= 0.4
		"freeze_pack":
			for m in _marbles:
				if m.visible and m.in_race():
					m.linear_velocity *= 0.25
		"magnet":
			var t2 := hub_marble_for(username)
			if t2 != null:
				for m in _marbles:
					if m != t2 and m.visible and m.in_race():
						m.linear_velocity *= 0.6
		"teleport":
			var t3 := hub_marble_for(username)
			if t3 != null:
				var v: Vector3 = t3.linear_velocity
				if v.length() > 0.5:
					t3.linear_velocity = v.normalized() * (v.length() + 8.0)
				else:
					t3.linear_velocity += Vector3(0, 0, -8.0)
		"spawn_decoys":
			var n := int(payload.get("count", 2))
			for i in range(max(1, n)):
				var d := try_place_start_marble()
				if d != null:
					d.set_marble_name("%s#%d" % [username, i + 1])
					_overlay.add_marble_rank(d)
		"chaos":
			for m in _marbles:
				if m.visible and m.in_race():
					m.linear_velocity += Vector3(randf_range(-4, 4), 3.0, randf_range(-4, 4))
			_do_shake(3.5, 0.6)
		"grant_skin":
			var skin := str(payload.get("skin_id", ""))
			if skin != "":
				hub_set_tier(username, skin)
		"shield", "use_avatar_face":
			pass  # cosmetic pass (next step)
		_:
			pass
	print("[MarbleRoyale] effect '%s' -> %s" % [effect, username])

