const FORWARD := 1
const TURN_LEFT := 2
const TURN_RIGHT := 3

# NOTE: only downhill / turn / hopper / bumper pieces are enabled. The upstream
# project also ships flat & upward pieces (forward, forward_up, looping, tube),
# but marbles stall or fall on those — they were disabled upstream and we keep
# them off so races always progress.
const PIECES := [
	# 0 forward (downhill)
	{
		&"resource": preload("res://scenes/blocks/forward_down.tscn"),
		&"next_piece_orientation": FORWARD
	},
	# 1-3 turn left
	{
		&"resource": preload("res://scenes/blocks/turn_left_covered.tscn"),
		&"next_piece_orientation": TURN_LEFT
	},
	{
		&"resource": preload("res://scenes/blocks/turn_left_2.tscn"),
		&"next_piece_orientation": TURN_LEFT
	},
	{
		&"resource": preload("res://scenes/blocks/turn_left_3.tscn"),
		&"next_piece_orientation": TURN_LEFT
	},
	# 4-6 turn right
	{
		&"resource": preload("res://scenes/blocks/turn_right_covered.tscn"),
		&"next_piece_orientation": TURN_RIGHT
	},
	{
		&"resource": preload("res://scenes/blocks/turn_right_2.tscn"),
		&"next_piece_orientation": TURN_RIGHT
	},
	{
		&"resource": preload("res://scenes/blocks/turn_right_3.tscn"),
		&"next_piece_orientation": TURN_RIGHT
	},
	# 7-9 hopper
	{&"resource": preload("res://scenes/blocks/hopper.tscn"), &"next_piece_orientation": FORWARD},
	{&"resource": preload("res://scenes/blocks/hopper2.tscn"), &"next_piece_orientation": FORWARD},
	{&"resource": preload("res://scenes/blocks/hopper3.tscn"), &"next_piece_orientation": FORWARD},
	# 10 bumper
	{&"resource": preload("res://scenes/blocks/bumper.tscn"), &"next_piece_orientation": FORWARD},
	# 11-12 start / finish (must stay last, in this order)
	{
		&"resource": preload("res://scenes/blocks/start_line.tscn"),
		&"next_piece_orientation": FORWARD
	},
	{
		&"resource": preload("res://scenes/blocks/finish_line.tscn"),
		&"next_piece_orientation": FORWARD
	},
]
