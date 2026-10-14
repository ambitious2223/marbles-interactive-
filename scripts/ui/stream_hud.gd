class_name StreamHud
extends CanvasLayer
## Clean, stream-facing HUD: round status, gift alerts (with the gifter's avatar),
## and a live event feed. Built in code so no scene edits are needed.

const FEED_MAX := 6
const ALERT_HOLD := 3.2

var _status: Label
var _alert: PanelContainer
var _alert_avatar: TextureRect
var _alert_text: RichTextLabel
var _feed: VBoxContainer
var _alert_tween: Tween
var _avatar_cache := {}

const TIER_COLORS := {
	"small": Color(0.86, 0.90, 0.96),
	"medium": Color(0.55, 0.92, 0.60),
	"large": Color(0.55, 0.72, 1.0),
	"epic": Color(0.80, 0.55, 1.0),
	"legendary": Color(1.0, 0.84, 0.35),
}


func _ready() -> void:
	layer = 10
	_build_ui()
	set_status("")


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Round status (top center) ---
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 14
	_status.offset_bottom = 58
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 30)
	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.add_theme_constant_override("outline_size", 6)
	root.add_child(_status)

	# --- Gift alert (center, under status) ---
	_alert = PanelContainer.new()
	_alert.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_left = -280
	_alert.offset_right = 280
	_alert.offset_top = 74
	_alert.offset_bottom = 178
	_alert.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.82)
	sb.border_color = Color(0.30, 0.80, 0.75, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	_alert.add_theme_stylebox_override("panel", sb)
	root.add_child(_alert)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_alert.add_child(hb)

	_alert_avatar = TextureRect.new()
	_alert_avatar.custom_minimum_size = Vector2(96, 96)
	_alert_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_alert_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_alert_avatar.visible = false
	hb.add_child(_alert_avatar)

	_alert_text = RichTextLabel.new()
	_alert_text.bbcode_enabled = true
	_alert_text.fit_content = true
	_alert_text.scroll_active = false
	_alert_text.custom_minimum_size = Vector2(420, 0)
	_alert_text.add_theme_font_size_override("normal_font_size", 26)
	_alert_text.add_theme_font_size_override("bold_font_size", 30)
	hb.add_child(_alert_text)

	# --- Event feed (bottom left) ---
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_feed.offset_left = 18
	_feed.offset_right = 520
	_feed.offset_top = -210
	_feed.offset_bottom = -18
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.add_theme_constant_override("separation", 4)
	root.add_child(_feed)


# --- Public API -------------------------------------------------------------

func set_status(text: String) -> void:
	if _status:
		_status.text = text


## A big gift alert with the gifter's avatar.
func show_alert(username: String, gift_name: String, avatar_url: String, tier: String) -> void:
	if _alert == null:
		return
	var tier_color: Color = TIER_COLORS.get(tier.to_lower(), Color(0.86, 0.90, 0.96))
	_alert_text.text = "[b][color=#%s]%s[/color][/b]\nsent [b]%s[/b]" % [
		tier_color.to_html(false), _esc(username), _esc(gift_name)
	]
	_set_alert_avatar(avatar_url)
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert.modulate.a = 0.0
	_alert_tween = create_tween()
	_alert_tween.tween_property(_alert, "modulate:a", 1.0, 0.18)
	_alert_tween.tween_interval(ALERT_HOLD)
	_alert_tween.tween_property(_alert, "modulate:a", 0.0, 0.45)


func push_feed(text: String, color: Color = Color.WHITE) -> void:
	if _feed == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	_feed.add_child(lbl)
	while _feed.get_child_count() > FEED_MAX:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))


# --- Helpers ----------------------------------------------------------------

func _set_alert_avatar(url: String) -> void:
	if url == "":
		_alert_avatar.visible = false
		return
	if _avatar_cache.has(url):
		_alert_avatar.texture = _avatar_cache[url]
		_alert_avatar.visible = _avatar_cache[url] != null
		return
	_alert_avatar.visible = false
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(
		func(_r: int, _c: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			var tex := _decode(body)
			_avatar_cache[url] = tex
			if tex != null and is_instance_valid(_alert_avatar):
				_alert_avatar.texture = tex
				_alert_avatar.visible = true
			http.queue_free()
	)
	if http.request(url) != OK:
		http.queue_free()


func _decode(body: PackedByteArray) -> Texture2D:
	if body.is_empty():
		return null
	var img := Image.new()
	if img.load_jpg_from_buffer(body) != OK and img.load_png_from_buffer(body) != OK and img.load_webp_from_buffer(body) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _esc(s: String) -> String:
	return s.replace("[", "［")
