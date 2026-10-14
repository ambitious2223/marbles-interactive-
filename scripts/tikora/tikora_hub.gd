extends Node
## Tikora Hub client (protocol v2) — one reusable file for every Godot game.
##
## The Tikora desktop app runs a local WebSocket "relay" that owns the TikTok
## connection and routes events/effects. This node connects to it and re-emits
## everything as Godot signals. NO TikTok code lives here — the hub does all of
## that, so this file is identical across games.
##
## Identity is injected by Tikora at launch via environment variables:
##   TIKORA_RELAY_URL, TIKORA_GAME_SLUG, TIKORA_GAME_KEY
## Fallbacks: --game=/--key=/--relay= command-line args, then res://tikora.manifest.json.
##
## Usage (from any script, once the autoload exists):
##   TikoraHub.gift_received.connect(_on_gift)
##   TikoraHub.effect_received.connect(_on_effect)
##   TikoraHub.chat_received.connect(_on_chat)

signal hub_connected
signal hub_disconnected
signal hub_ready(info)          # 'hello' (protocol/catalog/status/integration)
signal hub_welcome(info)        # authenticated successfully
signal hub_status(status)       # relay status (running, clients, ...)
signal hub_catalog(list)        # full gift catalog
signal hub_event(ev)            # every normalized event
signal gift_received(ev)
signal chat_received(ev)
signal like_received(ev)
signal follow_received(ev)
signal share_received(ev)
signal member_received(ev)
signal subscribe_received(ev)
signal room_user_received(ev)
signal effect_received(ef)      # an effect addressed to THIS game
signal hub_error(err)

const DEFAULT_URL := "ws://127.0.0.1:27016/"
const HEARTBEAT_S := 20.0
const MAX_BACKOFF_S := 15.0
const MANIFEST_PATH := "res://tikora.manifest.json"

@export var debug_verbose := false

var relay_url := DEFAULT_URL
var game_slug := ""
var game_key := ""
var auto_reconnect := true

var status: Dictionary = {}
var catalog: Array = []
var manifest: Dictionary = {}
var integration: Dictionary = {}
var is_open := false

var _ws: WebSocketPeer
var _state := "idle"            # idle | connecting | open | closed
var _closed := false
var _auth_failed := false
var _reconnect_in := -1.0
var _backoff := 0.5
var _heartbeat := 0.0
var _capabilities: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_identity()
	_load_manifest()
	_build_capabilities()
	_log("identity slug='%s' relay='%s' key=%s" % [game_slug, relay_url, ("set" if game_key != "" else "empty")])
	_connect()


func _exit_tree() -> void:
	_closed = true
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()


func _process(delta: float) -> void:
	if _reconnect_in > 0.0:
		_reconnect_in -= delta
		if _reconnect_in <= 0.0:
			_connect()
		return

	if _state == "idle" or _ws == null:
		return

	_ws.poll()
	var rs := _ws.get_ready_state()

	if rs == WebSocketPeer.STATE_OPEN:
		if not is_open:
			is_open = true
			_state = "open"
			_backoff = 0.5
			_heartbeat = 0.0
			_log("connected to %s" % relay_url)
			hub_connected.emit()
		_heartbeat += delta
		if _heartbeat >= HEARTBEAT_S:
			_heartbeat = 0.0
			send({ "type": "ping" })
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			_handle_text(pkt.get_string_from_utf8())
	elif rs == WebSocketPeer.STATE_CLOSED:
		if is_open:
			is_open = false
			_log("disconnected")
			hub_disconnected.emit()
		if _state != "closed":
			_log("closed (was %s)" % _state)
		_state = "closed"
		if auto_reconnect and not _closed and not _auth_failed:
			_schedule_reconnect()


# --- connection -------------------------------------------------------------

func _connect() -> void:
	_reconnect_in = -1.0
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	_ws = WebSocketPeer.new()
	# The hub's initial 'hello' carries the full gift catalog (megabytes); the
	# default 64 KiB inbound buffer would drop the socket mid-frame.
	_ws.inbound_buffer_size = 8 * 1024 * 1024
	_ws.outbound_buffer_size = 8 * 1024 * 1024
	_ws.max_queued_packets = 4096
	var err := _ws.connect_to_url(_build_url())
	if err != OK:
		_log("connect_to_url failed (%d) url=%s" % [err, _build_url()])
		_state = "closed"
		if auto_reconnect and not _closed and not _auth_failed:
			_schedule_reconnect()
	else:
		_state = "connecting"
		_log("connecting to %s" % _build_url())


func _schedule_reconnect() -> void:
	_reconnect_in = _backoff
	_backoff = min(MAX_BACKOFF_S, _backoff * 1.7)


func _build_url() -> String:
	var url := relay_url
	# Identify as a specific game only when we hold a key. Without a key the hub
	# treats us as a generic client (broadcast events still arrive; effects don't).
	if game_key != "":
		var sep := "&" if url.contains("?") else "?"
		url += "%sgame=%s&key=%s" % [sep, game_slug.uri_encode(), game_key.uri_encode()]
	return url


# --- outbound ---------------------------------------------------------------

func send(msg: Dictionary) -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	_ws.send_text(JSON.stringify(msg))
	return true


func ack_effect(id: Variant, result: Dictionary = {}) -> void:
	send({ "type": "effect:ack", "data": { "id": id, "result": result } })


func report_state(data: Dictionary) -> void:
	send({ "type": "state", "data": data })


func get_catalog() -> void:
	send({ "type": "get-catalog" })


func inject_gift(payload: Dictionary) -> void:
	send({ "type": "debug:gift", "data": payload })


func inject_event(data: Dictionary) -> void:
	send({ "type": "debug:event", "data": data })


func set_capabilities(caps: Dictionary) -> void:
	_capabilities = caps
	_send_capabilities()


# --- inbound ----------------------------------------------------------------

func _handle_text(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	var m: Dictionary = msg
	var t := str(m.get("type", ""))
	match t:
		"hello":
			catalog = _as_array(m.get("catalog", []))
			status = _as_dict(m.get("status", {}))
			integration = _as_dict(m.get("integration", {}))
			hub_catalog.emit(catalog)
			hub_ready.emit(m)
		"welcome":
			var data := _as_dict(m.get("data", {}))
			status = _as_dict(data.get("status", status))
			_send_capabilities()
			_log("authenticated as %s" % data.get("gameSlug", "?"))
			hub_welcome.emit(data)
		"status":
			status = _as_dict(m.get("data", {}))
			hub_status.emit(status)
		"catalog":
			catalog = _as_array(m.get("data", []))
			hub_catalog.emit(catalog)
		"catalog_page":
			pass
		"catalog_updated":
			pass
		"event":
			_dispatch_event(_as_dict(m.get("data", {})))
		"effect":
			var ef := _as_dict(m.get("data", {}))
			_log("effect: %s" % ef.get("effect", "?"))
			effect_received.emit(ef)
		"error":
			var err := _as_dict(m.get("data", {}))
			_log("error: %s" % err)
			if str(err.get("error", "")) == "unauthorized":
				_auth_failed = true
			if err.has("integration"):
				integration = _as_dict(err.get("integration", {}))
			hub_error.emit(err)
		"pong":
			pass
		_:
			pass


func _dispatch_event(ev: Dictionary) -> void:
	_log("event: %s from %s" % [ev.get("type", ""), ev.get("username", "")])
	hub_event.emit(ev)
	match str(ev.get("type", "")):
		"gift":
			gift_received.emit(ev)
		"chat":
			chat_received.emit(ev)
		"like":
			like_received.emit(ev)
		"follow":
			follow_received.emit(ev)
		"share":
			share_received.emit(ev)
		"member":
			member_received.emit(ev)
		"subscribe":
			subscribe_received.emit(ev)
		"roomUser":
			room_user_received.emit(ev)


# --- identity / manifest ----------------------------------------------------

func _load_identity() -> void:
	relay_url = _first_nonempty([
		OS.get_environment("TIKORA_RELAY_URL"),
		_arg("relay"),
	], DEFAULT_URL)
	var port := OS.get_environment("TIKORA_RELAY_PORT")
	if port != "" and relay_url == DEFAULT_URL:
		relay_url = "ws://127.0.0.1:%s/" % port
	game_slug = _first_nonempty([
		OS.get_environment("TIKORA_GAME_SLUG"),
		_arg("game"),
		_arg("slug"),
	], "")
	game_key = _first_nonempty([
		OS.get_environment("TIKORA_GAME_KEY"),
		_arg("key"),
	], "")


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		manifest = data
		if game_slug == "" and manifest.has("slug"):
			game_slug = str(manifest.get("slug", ""))


func _build_capabilities() -> void:
	var effects := _as_array(manifest.get("effects", []))
	_capabilities = {
		"effects": effects,
		"meta": { "engine": "godot", "name": str(manifest.get("slug", game_slug)) },
	}


func _send_capabilities() -> void:
	send({ "type": "capabilities", "data": _capabilities })


# --- helpers ----------------------------------------------------------------

func _arg(name: String) -> String:
	var prefix := "--%s=" % name
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _first_nonempty(values: Array, fallback: String) -> String:
	for v in values:
		var s := str(v).strip_edges()
		if s != "":
			return s
	return fallback


func _as_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _as_array(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _log(s: String) -> void:
	if debug_verbose or OS.get_environment("TIKORA_DEBUG") == "1":
		print("[TikoraHub] ", s)
