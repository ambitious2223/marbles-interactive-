extends Node
## Bridges Tikora hub events into the Marble Royale game (Main).
## Added as a child of Main at runtime. Keeps working while the game is paused.

var _main: Main


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent() as Main
	TikoraHub.hub_connected.connect(_on_hub_connected)
	TikoraHub.chat_received.connect(_on_chat)
	TikoraHub.gift_received.connect(_on_gift)
	TikoraHub.effect_received.connect(_on_effect)
	if TikoraHub.is_open:
		_on_hub_connected()
	print("[MarbleRoyale] controller ready (hub_open=%s)" % str(TikoraHub.is_open))


func _on_hub_connected() -> void:
	if _main == null:
		_main = get_parent() as Main
	if _main:
		_main.enable_hub_mode()


func _on_chat(ev: Dictionary) -> void:
	if _main == null:
		return
	var user := str(ev.get("username", "")).strip_edges()
	if user == "":
		return
	# Any comment joins the race for free (explicit "!join" also works).
	_main.hub_join(user)
	var avatar := str(ev.get("avatar", "")).strip_edges()
	_main.hub_set_avatar(user, avatar)
	if avatar != "":
		_fetch_avatar(user, avatar)


## Download a viewer's TikTok profile photo and wrap it onto their marble.
func _fetch_avatar(user: String, url: String) -> void:
	var marble := _main.hub_marble_for(user)
	if marble == null:
		return
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(
		func(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			_apply_avatar(marble, body)
			http.queue_free()
	)
	var err := http.request(url)
	if err != OK:
		http.queue_free()


func _apply_avatar(marble: Marble, body: PackedByteArray) -> void:
	if not is_instance_valid(marble) or body.is_empty():
		return
	var img := Image.new()
	var ok := img.load_jpg_from_buffer(body) == OK
	if not ok:
		ok = img.load_png_from_buffer(body) == OK
	if not ok:
		ok = img.load_webp_from_buffer(body) == OK
	if ok:
		marble.set_face_texture(ImageTexture.create_from_image(img))


func _on_gift(ev: Dictionary) -> void:
	if _main == null:
		return
	var user := str(ev.get("username", "")).strip_edges()
	if user == "":
		return
	# Cosmetic side-effect: the gifter's marble wears their gift tier (color/glow).
	_main.hub_set_tier(user, str(ev.get("tier", "small")))
	var avatar := str(ev.get("avatar", "")).strip_edges()
	_main.hub_set_avatar(user, avatar)
	if avatar != "":
		_fetch_avatar(user, avatar)
	_main.hud_alert(user, str(ev.get("giftName", "a gift")), avatar, str(ev.get("tier", "small")))
	_main.hud_feed(
		"🎁 @%s sent %s (%d coins)" % [user, str(ev.get("giftName", "gift")), int(ev.get("coins", 0))],
		Color(1.0, 0.82, 0.5)
	)


func _on_effect(ef: Dictionary) -> void:
	if _main == null:
		return
	var effect := str(ef.get("effect", ""))
	var ev: Dictionary = ef.get("event", {}) if typeof(ef.get("event", {})) == TYPE_DICTIONARY else {}
	var payload: Dictionary = ef.get("payload", {}) if typeof(ef.get("payload", {})) == TYPE_DICTIONARY else {}
	var user := str(ev.get("username", ""))
	_main.hub_apply_effect(effect, user, payload)
	if user != "":
		_main.hud_feed("⚡ @%s → %s" % [user, effect], Color(0.6, 1.0, 0.72))
	TikoraHub.ack_effect(ef.get("id", null), { "ok": true })
