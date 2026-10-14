class_name Overlay

extends Control

const ParticipantScene := preload("res://scenes/gui/participant.tscn")
const Group := preload("res://scripts/constants/groups.gd")

@onready var _ranking := get_node(^"%Ranking") as Ranking
@onready var _rank_panel := get_node(^"Panel") as ColorRect
@onready var _marble_pool = get_tree().get_nodes_in_group(&"marble_pool")[0]


## Show/hide the left ranking panel (streamer control).
func set_ranking_visible(on: bool) -> void:
	if _rank_panel:
		_rank_panel.visible = on


## Resize the ranking panel live (0.6–1.5), scaled around its own centre.
func set_ranking_scale(s: float) -> void:
	if _rank_panel:
		_rank_panel.scale = Vector2(s, s)
		_rank_panel.pivot_offset = _rank_panel.size * 0.5


func _process(_delta):
	var marble_count = _marble_pool.get_child_count()

	if marble_count > 0:
		_ranking.update()


func add_marble_rank(marble: Marble) -> void:
	# Add the marble to the list of participants
	var participant = ParticipantScene.instantiate()
	participant.set_marble(marble)
	_ranking.add_child(participant)
	_ranking.add_child(HSeparator.new())


func reset() -> void:
	if _ranking:
		_ranking.reset()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if not visible:
				reset()
