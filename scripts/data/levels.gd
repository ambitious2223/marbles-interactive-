class_name Levels
extends RefCounted
## Curated levels for Marble Royale. Each entry controls the generated track
## (length + which pieces appear), the sky palette, the track colour, lighting,
## fog and how many boost pads spawn — so levels differ structurally, not just
## by background hue.
##
## `pool` indexes PieceList.PIECES:
##   0 forward_down  1 turn_left_covered  2 turn_left_2  3 turn_left_3
##   4 turn_right_covered  5 turn_right_2  6 turn_right_3
##   7 hopper  8 hopper2  9 hopper3  10 bumper

const POOL_CALM := [0, 1, 4]
const POOL_MIXED := [0, 1, 2, 4, 5, 7, 8]
const POOL_WILD := [2, 3, 5, 6, 7, 8, 9, 10]
const POOL_CHAOS := [3, 6, 8, 9, 10]
const POOL_BUMPER := [0, 10, 7, 8, 0]
const POOL_TECH := [1, 2, 3, 4, 5, 6, 0]
const POOL_HILLS := [0, 0, 7, 8, 9, 10]

# Sky palettes: [top, bottom, horizon]
const SKY_DAY := [Color(0.10, 0.60, 1.00), Color(0.40, 0.80, 1.00), Color(0.00, 0.70, 0.80)]
const SKY_SUNSET := [Color(0.55, 0.45, 0.95), Color(1.00, 0.60, 0.45), Color(1.00, 0.45, 0.35)]
const SKY_DUSK := [Color(0.15, 0.15, 0.45), Color(0.55, 0.35, 0.60), Color(0.90, 0.45, 0.55)]
const SKY_NIGHT := [Color(0.02, 0.02, 0.10), Color(0.08, 0.06, 0.22), Color(0.15, 0.10, 0.35)]
const SKY_MINT := [Color(0.10, 0.55, 0.45), Color(0.55, 0.90, 0.75), Color(0.30, 0.80, 0.70)]
const SKY_VOLCANO := [Color(0.25, 0.08, 0.06), Color(0.90, 0.35, 0.15), Color(1.00, 0.55, 0.20)]
const SKY_ICE := [Color(0.35, 0.55, 0.85), Color(0.80, 0.92, 1.00), Color(0.70, 0.85, 1.00)]
const SKY_ALIEN := [Color(0.35, 0.05, 0.45), Color(0.70, 0.30, 0.85), Color(0.55, 0.85, 0.35)]

# Track tints (multiplied over the wood texture; white = untouched).
const TRACK_WOOD := Color(1.00, 1.00, 1.00)
const TRACK_SAND := Color(1.00, 0.86, 0.62)
const TRACK_ICE := Color(0.68, 0.84, 1.00)
const TRACK_LAVA := Color(1.00, 0.52, 0.38)
const TRACK_MINT := Color(0.68, 1.00, 0.86)
const TRACK_ALIEN := Color(0.78, 0.62, 1.00)
const TRACK_DUSK := Color(0.72, 0.72, 0.98)
const TRACK_NIGHT := Color(0.52, 0.58, 0.86)
const TRACK_CANDY := Color(1.00, 0.72, 0.86)

# Sun / key-light colours.
const SUN_DAY := Color(1.00, 0.98, 0.92)
const SUN_WARM := Color(1.00, 0.90, 0.70)
const SUN_COOL := Color(0.80, 0.88, 1.00)
const SUN_RED := Color(1.00, 0.66, 0.52)

const LEVELS := [
	{ "name": "Sunny Start",       "steps": 130, "pool": POOL_CALM,   "sky": SKY_DAY,     "track": TRACK_WOOD,  "sun": SUN_DAY,  "energy": 1.0,  "power": 0.35 },
	{ "name": "Rolling Hills",     "steps": 42,  "pool": POOL_MIXED,  "sky": SKY_DAY,     "track": TRACK_SAND,  "sun": SUN_DAY,  "energy": 1.0,  "power": 0.35 },
	{ "name": "Twin Turns",        "steps": 46,  "pool": POOL_MIXED,  "sky": SKY_MINT,    "track": TRACK_MINT,  "sun": SUN_DAY,  "energy": 1.0,  "power": 0.40 },
	{ "name": "Bumper Yard",       "steps": 48,  "pool": POOL_BUMPER, "sky": SKY_MINT,    "track": TRACK_WOOD,  "sun": SUN_DAY,  "energy": 1.0,  "power": 0.45 },
	{ "name": "Sunset Run",        "steps": 48,  "pool": POOL_MIXED,  "sky": SKY_SUNSET,  "track": TRACK_SAND,  "sun": SUN_WARM, "energy": 0.95, "power": 0.40 },
	{ "name": "Hopper Heights",    "steps": 44,  "pool": POOL_WILD,   "sky": SKY_SUNSET,  "track": TRACK_SAND,  "sun": SUN_WARM, "energy": 0.95, "power": 0.45 },
	{ "name": "Dusk Descent",      "steps": 44,  "pool": POOL_WILD,   "sky": SKY_DUSK,    "track": TRACK_DUSK,  "sun": SUN_WARM, "energy": 0.85, "power": 0.45 },
	{ "name": "Chaos Corners",     "steps": 42,  "pool": POOL_CHAOS,  "sky": SKY_DUSK,    "track": TRACK_DUSK,  "sun": SUN_WARM, "energy": 0.85, "power": 0.50, "fog": Color(0.55, 0.4, 0.55), "fog_density": 0.008 },
	{ "name": "Midnight Plunge",   "steps": 44,  "pool": POOL_WILD,   "sky": SKY_NIGHT,   "track": TRACK_NIGHT, "sun": SUN_COOL, "energy": 0.6,  "power": 0.45 },
	{ "name": "Neon Fall",         "steps": 42,  "pool": POOL_CHAOS,  "sky": SKY_NIGHT,   "track": TRACK_CANDY, "sun": SUN_COOL, "energy": 0.6,  "power": 0.55, "fog": Color(0.2, 0.1, 0.35), "fog_density": 0.01 },
	{ "name": "Ice Shelf",         "steps": 72,  "pool": POOL_HILLS,  "sky": SKY_ICE,     "track": TRACK_ICE,   "sun": SUN_COOL, "energy": 1.05, "power": 0.40 },
	{ "name": "Glacier Rush",      "steps": 46,  "pool": POOL_WILD,   "sky": SKY_ICE,     "track": TRACK_ICE,   "sun": SUN_COOL, "energy": 1.05, "power": 0.45 },
	{ "name": "Volcano Slide",     "steps": 40,  "pool": POOL_CHAOS,  "sky": SKY_VOLCANO, "track": TRACK_LAVA,  "sun": SUN_RED,  "energy": 1.1,  "power": 0.50, "fog": Color(0.5, 0.15, 0.08), "fog_density": 0.012 },
	{ "name": "Lava Lanes",        "steps": 40,  "pool": POOL_CHAOS,  "sky": SKY_VOLCANO, "track": TRACK_LAVA,  "sun": SUN_RED,  "energy": 1.1,  "power": 0.55, "fog": Color(0.5, 0.15, 0.08), "fog_density": 0.012 },
	{ "name": "Alien Ridge",       "steps": 46,  "pool": POOL_TECH,   "sky": SKY_ALIEN,   "track": TRACK_ALIEN, "sun": SUN_COOL, "energy": 0.9,  "power": 0.50 },
	{ "name": "Gravity Well",      "steps": 78,  "pool": POOL_HILLS,  "sky": SKY_ALIEN,   "track": TRACK_ALIEN, "sun": SUN_COOL, "energy": 0.9,  "power": 0.55, "fog": Color(0.3, 0.15, 0.4), "fog_density": 0.01 },
	{ "name": "The Gauntlet",      "steps": 48,  "pool": POOL_TECH,   "sky": SKY_DUSK,    "track": TRACK_DUSK,  "sun": SUN_WARM, "energy": 0.85, "power": 0.55 },
	{ "name": "Final Drop",        "steps": 84,  "pool": POOL_HILLS,  "sky": SKY_VOLCANO, "track": TRACK_LAVA,  "sun": SUN_RED,  "energy": 1.1,  "power": 0.60, "fog": Color(0.5, 0.15, 0.08), "fog_density": 0.012 },
	{ "name": "Storm Front",       "steps": 50,  "pool": POOL_TECH,   "sky": SKY_NIGHT,   "track": TRACK_NIGHT, "sun": SUN_COOL, "energy": 0.55, "power": 0.55, "fog": Color(0.2, 0.15, 0.3), "fog_density": 0.012 },
	{ "name": "Marble Apocalypse", "steps": 44,  "pool": POOL_CHAOS, "sky": SKY_VOLCANO, "track": TRACK_LAVA,  "sun": SUN_RED,  "energy": 1.15, "power": 0.65, "fog": Color(0.5, 0.15, 0.08), "fog_density": 0.014 },
]
