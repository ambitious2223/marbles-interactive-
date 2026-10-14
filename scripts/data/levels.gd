class_name Levels
extends RefCounted
## Curated levels for Marble Royale. Each entry controls the generated track
## (length + which pieces appear), the sky palette, and how chaotic it feels.
##
## `pool` indexes PieceList.PIECES:
##   0 forward_down  1 turn_left_covered  2 turn_left_2  3 turn_left_3
##   4 turn_right_covered  5 turn_right_2  6 turn_right_3
##   7 hopper  8 hopper2  9 hopper3  10 bumper

const POOL_CALM := [0, 1, 4]
const POOL_MIXED := [0, 1, 2, 4, 5, 7, 8]
const POOL_WILD := [2, 3, 5, 6, 7, 8, 9, 10]
const POOL_CHAOS := [3, 6, 8, 9, 10]

# Sky palettes: [top, bottom, horizon]
const SKY_DAY := [Color(0.10, 0.60, 1.00), Color(0.40, 0.80, 1.00), Color(0.00, 0.70, 0.80)]
const SKY_SUNSET := [Color(0.55, 0.45, 0.95), Color(1.00, 0.60, 0.45), Color(1.00, 0.45, 0.35)]
const SKY_DUSK := [Color(0.15, 0.15, 0.45), Color(0.55, 0.35, 0.60), Color(0.90, 0.45, 0.55)]
const SKY_NIGHT := [Color(0.02, 0.02, 0.10), Color(0.08, 0.06, 0.22), Color(0.15, 0.10, 0.35)]
const SKY_MINT := [Color(0.10, 0.55, 0.45), Color(0.55, 0.90, 0.75), Color(0.30, 0.80, 0.70)]
const SKY_VOLCANO := [Color(0.25, 0.08, 0.06), Color(0.90, 0.35, 0.15), Color(1.00, 0.55, 0.20)]
const SKY_ICE := [Color(0.35, 0.55, 0.85), Color(0.80, 0.92, 1.00), Color(0.70, 0.85, 1.00)]
const SKY_ALIEN := [Color(0.35, 0.05, 0.45), Color(0.70, 0.30, 0.85), Color(0.55, 0.85, 0.35)]

const LEVELS := [
	{ "name": "Sunny Start",        "steps": 8,  "pool": POOL_CALM,  "sky": SKY_DAY },
	{ "name": "Rolling Hills",      "steps": 9,  "pool": POOL_MIXED, "sky": SKY_DAY },
	{ "name": "Twin Turns",         "steps": 10, "pool": POOL_MIXED, "sky": SKY_MINT },
	{ "name": "Bumper Yard",        "steps": 10, "pool": POOL_WILD,  "sky": SKY_MINT },
	{ "name": "Sunset Run",         "steps": 11, "pool": POOL_MIXED, "sky": SKY_SUNSET },
	{ "name": "Hopper Heights",     "steps": 11, "pool": POOL_WILD,  "sky": SKY_SUNSET },
	{ "name": "Dusk Descent",       "steps": 12, "pool": POOL_WILD,  "sky": SKY_DUSK },
	{ "name": "Chaos Corners",      "steps": 12, "pool": POOL_CHAOS, "sky": SKY_DUSK },
	{ "name": "Midnight Plunge",    "steps": 12, "pool": POOL_WILD,  "sky": SKY_NIGHT },
	{ "name": "Neon Fall",          "steps": 13, "pool": POOL_CHAOS, "sky": SKY_NIGHT },
	{ "name": "Ice Shelf",          "steps": 11, "pool": POOL_MIXED, "sky": SKY_ICE },
	{ "name": "Glacier Rush",       "steps": 13, "pool": POOL_WILD,  "sky": SKY_ICE },
	{ "name": "Volcano Slide",      "steps": 12, "pool": POOL_CHAOS, "sky": SKY_VOLCANO },
	{ "name": "Lava Lanes",         "steps": 14, "pool": POOL_CHAOS, "sky": SKY_VOLCANO },
	{ "name": "Alien Ridge",        "steps": 13, "pool": POOL_WILD,  "sky": SKY_ALIEN },
	{ "name": "Gravity Well",       "steps": 14, "pool": POOL_CHAOS, "sky": SKY_ALIEN },
	{ "name": "The Gauntlet",       "steps": 15, "pool": POOL_CHAOS, "sky": SKY_DUSK },
	{ "name": "Final Drop",         "steps": 16, "pool": POOL_CHAOS, "sky": SKY_VOLCANO },
	{ "name": "Storm Front",        "steps": 15, "pool": POOL_CHAOS, "sky": SKY_NIGHT },
	{ "name": "Marble Apocalypse",  "steps": 17, "pool": POOL_CHAOS, "sky": SKY_VOLCANO },
]
