class_name ClassData
extends RefCounted
## Weapon classes (docs/CLASS_MOVES.md, ITERATION2 Phase C). Pure data: stats, the modifier table that
## reshapes the shared adaptive (Y) moves, the class base pose, and the move pools.
##
## Move tiers:  WEAPON (B slots, 8 per class, class-locked)  /  ADAPTIVE (Y, same move for everyone but
## reshaped by the modifier table)  /  UNIVERSAL (X, identical for everyone).

const IDS: Array[String] = ["brawler", "sword", "hammer", "magic"]

## X: universal off-hand moves (10)
const X_POOL: Array[String] = [
	"off_hand_jab", "spark_shot", "guard", "grab_throw", "pull_hook",
	"ally_toss", "heal_pulse", "rage_taunt", "boost_spark", "pocket_mine",
]
## Y: adaptive moves (10)
const Y_POOL: Array[String] = [
	"uppercut", "sweep", "spin_kick", "cyclone", "stomp",
	"dive_kick", "anti_air", "pillar_smash", "flurry", "slide_strike",
]
## Moves that may be rolled / offered first (the starred moves in CLASS_MOVES.md)
const X_STARS: Array[String] = ["off_hand_jab", "spark_shot", "grab_throw"]
const Y_STARS: Array[String] = ["uppercut", "sweep", "flurry", "slide_strike"]

static var _db: Dictionary = {}


## id, display name, weapon, run-speed and HP multipliers, modifier table, base pose, B pool, starred B moves.
static func _build() -> void:
	_db["brawler"] = {
		"id": "brawler", "name": "Brawler", "weapon": "", "role": "Relay and juggle",
		"desc": "Fists. Fastest, short reach. Keeps combos alive.",
		"speed": 1.15, "hp": 100.0, "jump": 1.0,
		"mods": {"reach": 1.0, "startup": 0.85, "recovery": 0.9, "dmg": 0.9, "kb": 0.9, "guard_break": false},
		"b_pool": ["jab", "dash_punch", "rising_dragon", "haymaker", "wall_elbow", "counter_palm", "shoulder_rush", "popup_kick"],
		"b_stars": ["jab", "dash_punch", "wall_elbow", "shoulder_rush"],
		"base": {
			"lean": 0.14, "head": -0.05,
			"th_f": 0.45, "kn_f": 0.75, "th_b": -0.35, "kn_b": 0.6,
			"ua_f": 2.3, "la_f": 1.9, "ua_b": 1.1, "la_b": 1.7,
			"wp_rot": 0.0,
		},
		"bob": 0.04, "hover": 0.0,
	}
	_db["sword"] = {
		"id": "sword", "name": "Sword", "weapon": "sword", "role": "Guard and counter",
		"desc": "Long blade, medium-slow. Parries and timing.",
		"speed": 0.95, "hp": 100.0, "jump": 1.0,
		"mods": {"reach": 1.5, "startup": 1.15, "recovery": 1.1, "dmg": 1.1, "kb": 1.0, "guard_break": false},
		"b_pool": ["long_slash", "thrust_lunge", "rising_slash", "low_cut", "wind_slash", "parry", "deflect_stance", "riposte_step"],
		"b_stars": ["long_slash", "thrust_lunge", "parry"],
		"base": {
			"lean": 0.2, "head": -0.05,
			"th_f": 0.7, "kn_f": 0.9, "th_b": -0.6, "kn_b": 0.5,
			"ua_f": 1.45, "la_f": 0.1, "ua_b": 0.3, "la_b": 0.5,
			"wp_rot": -0.95,
		},
		"bob": 0.02, "hover": 0.0,
	}
	_db["hammer"] = {
		"id": "hammer", "name": "Hammer", "weapon": "hammer", "role": "Breaker and launcher",
		"desc": "Very slow, huge reach and damage. Dead zone up close.",
		"speed": 0.8, "hp": 120.0, "jump": 0.95,
		"mods": {"reach": 1.8, "startup": 1.7, "recovery": 1.5, "dmg": 1.8, "kb": 1.8, "guard_break": true, "dead_zone": 40.0},
		"b_pool": ["overhead_smash", "side_sweep", "sky_launcher", "quake_line", "whirlwind_haul", "guard_breaker", "home_run", "bulwark_plant"],
		"b_stars": ["overhead_smash", "side_sweep", "home_run"],
		"base": {
			"lean": 0.32, "head": 0.1,
			"th_f": 0.75, "kn_f": 0.95, "th_b": -0.75, "kn_b": 0.95,
			"ua_f": 0.7, "la_f": 0.5, "ua_b": 0.45, "la_b": 0.6,
			"wp_rot": 2.8,
		},
		"bob": 0.015, "hover": 0.0,
	}
	_db["magic"] = {
		"id": "magic", "name": "Magic", "weapon": "magic", "role": "Primer and zoner",
		"desc": "Glowing hands, ranged. Lowest HP. Locked until unlocked in meta progression.",
		"speed": 1.0, "hp": 80.0, "jump": 1.05,
		"mods": {"reach": 1.2, "startup": 1.0, "recovery": 1.0, "dmg": 0.8, "kb": 1.0, "guard_break": false},
		"b_pool": ["fireball", "spread_shot", "boomerang", "ground_wave", "teleport_strike", "arcane_beam", "gravity_well", "mirror_ward"],
		"b_stars": ["fireball", "boomerang"],
		"base": {
			"lean": 0.0, "head": 0.0, "root_y": -4.0,
			"th_f": 0.1, "kn_f": 0.15, "th_b": -0.1, "kn_b": 0.1,
			"ua_f": 1.95, "la_f": 0.25, "ua_b": -1.95, "la_b": -0.25,
			"wp_rot": 0.0,
		},
		"bob": 0.03, "hover": 3.0,
	}


static func get_class_data(id: String) -> Dictionary:
	if _db.is_empty():
		_build()
	return _db.get(id, _db["brawler"])


static func has_class(id: String) -> bool:
	if _db.is_empty():
		_build()
	return _db.has(id)


## The class idle pose at time t (with a little breathing / hover motion).
static func base_pose(id: String, t: float = 0.0) -> Dictionary:
	var c := get_class_data(id)
	var p: Dictionary = (c["base"] as Dictionary).duplicate()
	var b := sin(t * 2.6) * float(c["bob"])
	p["lean"] = float(p["lean"]) + b
	p["ua_f"] = float(p["ua_f"]) + b
	p["ua_b"] = float(p["ua_b"]) - b
	if float(c["hover"]) > 0.0:
		p["root_y"] = float(p.get("root_y", 0.0)) - float(c["hover"]) * (0.5 + 0.5 * sin(t * 2.2))
	if String(c["weapon"]) == "sword":
		p["wp_rot"] = float(p["wp_rot"]) + sin(t * 1.7) * 0.07  # the blade tip drifts
	return p


## Which pools a slot letter draws from for a class.
static func pool_for_slot(slot: String, class_id: String) -> Array:
	match slot.substr(0, 1):
		"X":
			return X_POOL
		"Y":
			return Y_POOL
	return get_class_data(class_id)["b_pool"]


## "universal" / "adaptive" / "weapon" (and the class a weapon move belongs to)
static func tier_of(move_id: String) -> String:
	if move_id in X_POOL:
		return "universal"
	if move_id in Y_POOL:
		return "adaptive"
	for id in IDS:
		if move_id in (get_class_data(id)["b_pool"] as Array):
			return "weapon"
	return ""


static func class_of_weapon_move(move_id: String) -> String:
	for id in IDS:
		if move_id in (get_class_data(id)["b_pool"] as Array):
			return id
	return ""


## Run-start loadout: 3 random starred B moves (B, B_UP, B_SIDE), 1 random X, 1 random Y. No reroll.
## One of the B moves is always usable at mid range (non-projectile / not a pure close-range tool).
static func roll_loadout(class_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var c := get_class_data(class_id)
	var stars: Array = (c["b_stars"] as Array).duplicate()
	var rest: Array = (c["b_pool"] as Array).duplicate()
	var picks: Array = []
	while picks.size() < 3 and (not stars.is_empty() or not rest.is_empty()):
		var src: Array = stars if not stars.is_empty() else rest
		var i := rng.randi() % src.size()
		var id: String = src[i]
		src.remove_at(i)
		rest.erase(id)
		if not (id in picks):
			picks.append(id)
	var out := {"B": picks[0], "B_UP": picks[1], "B_SIDE": picks[2]}
	out["X"] = X_STARS[rng.randi() % X_STARS.size()]
	out["Y"] = Y_STARS[rng.randi() % Y_STARS.size()]
	return out


## Fixed loadout for the training room: 4 B moves, 4 X, 4 Y so every class can be tried straight away.
static func training_loadout(class_id: String) -> Dictionary:
	var c := get_class_data(class_id)
	var b: Array = c["b_pool"]
	return {
		"B": b[0], "B_UP": b[2], "B_SIDE": b[1], "B_DOWN": b[3],
		"X": "off_hand_jab", "X_UP": "spark_shot", "X_SIDE": "grab_throw", "X_DOWN": "guard",
		"Y": "uppercut", "Y_UP": "flurry", "Y_SIDE": "spin_kick", "Y_DOWN": "sweep",
	}
