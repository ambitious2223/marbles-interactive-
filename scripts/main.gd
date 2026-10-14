class_name Main
extends Node

enum State { MODE_START, MODE_PAUSE, MODE_MARBLE }

const RotationCameraScene := preload("res://scenes/camera/rotation_camera.tscn")
const MarbleCameraScene := preload("res://scenes/camera/marble_camera.tscn")
const Group := preload("res://scripts/constants/groups.gd")
const NameGenerator := preload("res://scripts/utils/name_generator.gd")
const TikoraControllerScript := preload("res://scripts/tikora/tikora_controller.gd")
const MarbleScene := preload("res://scenes/marble.tscn")

# Start-grid size (grows the base's fixed 14-slot grid to ~24 marbles).
const START_ROWS := 8
const START_COLS := 3

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
var _hub_pending: Array = []    # (legacy, unused in hub mode)
var _hub_restart_in := -1.0

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
	_rotation_camera = RotationCameraScene.instantiate()
	_marble_camera = MarbleCameraScene.instantiate()
	reset_position()
	set_mode(_mode)
	add_child(TikoraControllerScript.new())
	_add_psx_post()


## Full-screen PS1 post-process (dither + colour quantization) over everything.
func _add_psx_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/psx_post.gdshader")
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)


func _exit_tree():
	if not _rotation_camera.is_inside_tree():
		_rotation_camera.free()
	if not _marble_camera.is_inside_tree():
		_marble_camera.free()


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
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
	for i in range(START_ROWS):
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
		+ Vector3.FORWARD * (position[0] - (START_ROWS - 1) / 2.0)
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

	# In hub mode, end the round shortly after the first marble finishes.
	if hub_mode and _race_has_started and _hub_restart_in < 0.0:
		if _ranking._first_marble != null and _ranking._first_marble.has_finish():
			_hub_restart_in = 8.0
	if _hub_restart_in >= 0.0:
		_hub_restart_in -= delta
		if _hub_restart_in <= 0.0:
			_hub_restart_in = -1.0
			start_hub_round()

	# Hub mode: keep the broadcast camera on the current leader.
	if hub_mode:
		var lead = _ranking._first_marble
		if lead != null and is_instance_valid(lead) and lead.visible:
			if _marble_camera.get_target() != lead:
				_marble_camera.set_target(lead)
			if not _marble_camera.is_inside_tree():
				replace_camera(_marble_camera, [_rotation_camera])

	if not _marble_camera.has_target() or not _marble_camera.get_target().visible:
		var found = false
		for marble in _marbles:
			if marble.visible:
				found = true
				_marble_camera.set_target(marble)
				break
		if not found:
			replace_camera(_rotation_camera, [_marble_camera])

			if _race_has_started:
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
	_ensure_marble_capacity(START_ROWS * START_COLS)
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
	if _mode != State.MODE_MARBLE:
		return
	var existing = _hub_names.get(key)
	if existing != null and is_instance_valid(existing) and existing.visible:
		return
	if _place_hub_marble(uname) != null:
		print("[MarbleRoyale] join: ", uname)


func hub_marble_for(username: String) -> Marble:
	var m = _hub_names.get(username.to_lower())
	if m != null and is_instance_valid(m) and m.visible:
		return m
	return null


## Apply a routed gift effect. Physics-only for now; skins come next.
func hub_apply_effect(effect: String, username: String, payload: Dictionary) -> void:
	match effect:
		"boost":
			var t := hub_marble_for(username)
			if t != null:
				t.linear_velocity *= 2.0
		"hazard_shell", "hazard_bomb":
			var leader = _ranking._first_marble
			if leader != null:
				leader.linear_velocity *= 0.15
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
		"grant_skin":
			var skin := str(payload.get("skin_id", ""))
			if skin != "":
				hub_set_tier(username, skin)
		"shield", "use_avatar_face":
			pass  # cosmetic pass (next step)
		_:
			pass
	print("[MarbleRoyale] effect '%s' -> %s" % [effect, username])

