class_name ClassData
extends RefCounted
## Weapon classes (docs/CLASS_MOVES.md, ITERATION2 Phase C). Pure data: stats, the modifier table that
## reshapes the shared adaptive (Y) moves, the class base pose, and the move pools.
##
## Move tiers and buttons:  WEAPON (X slots, 8 per class, class-locked)  /  ADAPTIVE (Y, same move for everyone but
## reshaped by the modifier table: the weapon is the hitbox)  /  DEFAULT (B, identical for everyone: every kick, and
## off-hand / utility moves that never touch the weapon).

const IDS: Array[String] = ["brawler", "sword", "hammer", "magic"]

## Which slot letter (= button) each tier lives on.
const WEAPON_BTN := "X"
const ADAPT_BTN := "Y"
const DEFAULT_BTN := "B"

## B: default moves, the same for every class (all kicks plus moves that do not use the weapon)
const DEFAULT_POOL: Array[String] = [
	"sweep", "spin_kick", "stomp", "dive_kick", "slide_strike", "bicycle_kick",
	"spark_shot", "guard", "shockwave", "pull_hook", "grapple_dash", "heal_pulse", "rage_taunt", "boost_spark", "pocket_mine",
]
## Y: adaptive moves (arm strikes: the weapon becomes the hitbox)
const ADAPT_POOL: Array[String] = [
	"off_hand_jab", "uppercut", "cyclone", "anti_air", "pillar_smash", "flurry",
]
## Moves that may be rolled / offered first (the starred moves in CLASS_MOVES.md)
const DEFAULT_STARS: Array[String] = ["sweep", "spin_kick", "slide_strike", "spark_shot", "shockwave"]
const ADAPT_STARS: Array[String] = ["off_hand_jab", "uppercut", "flurry"]
## The light combo starters (little knockback, no launch): the original off-hand set, whatever tier they are in now.
const SOFT_MOVES: Array[String] = [
	"off_hand_jab", "spark_shot", "guard", "shockwave", "pull_hook",
	"grapple_dash", "heal_pulse", "rage_taunt", "boost_spark", "pocket_mine",
]

static var _db: Dictionary = {}


## id, display name, weapon, run-speed and HP multipliers, modifier table, base pose, B pool, starred B moves.
static func _build() -> void:
	_db["brawler"] = {
		"id": "brawler", "name": "Brawler", "weapon": "", "role": "Relay and juggle",
		"desc": "Fists. Fastest, short reach. Keeps combos alive.",
		"speed": 1.15, "hp": 100.0, "jump": 1.0,
		"ratings": {"SPEED": 9, "HEALTH": 5, "REACH": 2, "DAMAGE": 3},
		"mods": {"reach": 1.0, "startup": 0.85, "recovery": 0.9, "dmg": 0.9, "kb": 0.9, "guard_break": false},
		"b_pool": ["jab", "dash_punch", "rising_dragon", "haymaker", "wall_elbow", "counter_palm", "shoulder_rush", "popup_kick"],
		"b_stars": ["jab", "dash_punch", "wall_elbow", "shoulder_rush"],
		"base": {
			"lean": 0.09, "head": -0.04,
			"th_f": 0.34, "kn_f": 0.45, "th_b": -0.30, "kn_b": 0.35,
			"ua_f": 0.85, "la_f": 2.2, "ua_b": 0.55, "la_b": 2.4,  # boxing guard: fists up at the chin
			"wp_rot": 0.0,
		},
		"bob": 0.04, "hover": 0.0,
		"stance": Vector3(13, -13, 37),  # IK: front foot x, back foot x, hip drop (feet level, knees forward)
	}
	_db["sword"] = {
		"id": "sword", "name": "Sword", "weapon": "sword", "role": "Guard and counter",
		"desc": "Long blade, medium-slow. Parries and timing.",
		"speed": 0.95, "hp": 100.0, "jump": 1.0,
		"ratings": {"SPEED": 4, "HEALTH": 5, "REACH": 7, "DAMAGE": 5},
		"mods": {"reach": 1.5, "startup": 1.15, "recovery": 1.1, "dmg": 1.1, "kb": 1.0, "guard_break": false},
		"b_pool": ["long_slash", "thrust_lunge", "rising_slash", "low_cut", "wind_slash", "parry", "deflect_stance", "riposte_step"],
		"b_stars": ["long_slash", "thrust_lunge", "parry"],
		"base": {
			"lean": 0.04, "head": -0.02,
			"th_f": 0.4, "kn_f": 0.6, "th_b": -0.35, "kn_b": 0.4,
			"ua_f": 0.55, "la_f": 1.05, "ua_b": 1.55, "la_b": 1.0,  # sword hand (front arm) low at the hip, empty hand guards high
			"wp_rot": -1.05,
		},
		"bob": 0.02, "hover": 0.0,
		"stance": Vector3(14, -14, 38),
	}
	_db["hammer"] = {
		"id": "hammer", "name": "Hammer", "weapon": "hammer", "role": "Breaker and launcher",
		"desc": "Quick to swing, long recovery. Huge reach and damage. Dead zone up close.",
		"speed": 0.9, "hp": 120.0, "jump": 0.95,
		"ratings": {"SPEED": 2, "HEALTH": 9, "REACH": 7, "DAMAGE": 10},
		"mods": {"reach": 1.8, "startup": 1.3, "recovery": 1.9, "dmg": 1.8, "kb": 1.8, "guard_break": true, "dead_zone": 40.0},
		"b_pool": ["overhead_smash", "side_sweep", "sky_launcher", "quake_line", "whirlwind_haul", "guard_breaker", "home_run", "bulwark_plant"],
		"b_stars": ["overhead_smash", "side_sweep", "home_run"],
		"base": {
			"lean": 0.04, "head": 0.0,
			# planted stance: both shins vertical on the ground (kn = th), thighs splayed, hip solved from there
			"th_f": 0.5, "kn_f": 0.5, "th_b": -0.5, "kn_b": -0.5,
			"ua_f": 0.7, "la_f": 0.5, "ua_b": 0.45, "la_b": 0.6,
			"wp_rot": 2.8,
		},
		"bob": 0.015, "hover": 0.0,
		"stance": Vector3(17, -17, 35),  # wide, firm
	}
	_db["magic"] = {
		"id": "magic", "name": "Magic", "weapon": "magic", "role": "Primer and zoner",
		"desc": "Glowing hands, ranged. Lowest HP.",
		"speed": 1.0, "hp": 80.0, "jump": 1.05,
		"ratings": {"SPEED": 6, "HEALTH": 2, "REACH": 10, "DAMAGE": 3},
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
	if c.has("stance"):
		var s: Vector3 = c["stance"]
		# four-beat breathing on planted feet (in: up, out: down + weight right, in: up, out: down + weight left)
		var br := PoseLib.breath(t)
		var sh: float = br["x"]
		p.merge(PoseLib.stance(s.x - sh, s.y - sh, s.z - float(br["dip"])), true)
		p["root_x"] = sh
		p["lean"] = float(p["lean"]) + sh * 0.006 + float(br["down"]) * 0.03
	var b := cos(t * 10.0) * float(c["bob"]) * 1.0  # arms lift on the in-breath
	p["lean"] = float(p["lean"]) + b
	p["ua_f"] = float(p["ua_f"]) + b
	p["ua_b"] = float(p["ua_b"]) - b
	if float(c["hover"]) > 0.0:
		p["root_y"] = float(p.get("root_y", 0.0)) - float(c["hover"]) * (0.5 + 0.5 * sin(t * 2.2))
	if String(c["weapon"]) == "sword":
		p["wp_rot"] = float(p["wp_rot"]) + sin(t * 1.7) * 0.07  # the blade tip drifts
	return PoseLib.level_feet(p)


## Which pools a slot letter draws from for a class.
static func pool_for_slot(slot: String, class_id: String) -> Array:
	match slot.substr(0, 1):
		DEFAULT_BTN:
			return DEFAULT_POOL
		ADAPT_BTN:
			return ADAPT_POOL
	return get_class_data(class_id)["b_pool"]


## The slot letter (button) a move of this tier goes on.
static func button_of_tier(tier: String) -> String:
	match tier:
		"weapon":
			return WEAPON_BTN
		"adaptive":
			return ADAPT_BTN
	return DEFAULT_BTN


## "universal" / "adaptive" / "weapon" (and the class a weapon move belongs to)
static func tier_of(move_id: String) -> String:
	if move_id in DEFAULT_POOL:
		return "universal"
	if move_id in ADAPT_POOL:
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


## Fast, close-range attacks: every starting loadout needs at least one on a neutral button, so you always have a basic hit.
const CLOSE_ATTACKS := {
	"B": ["sweep", "spin_kick", "slide_strike", "bicycle_kick"],
	"Y": ["off_hand_jab", "uppercut", "flurry"],
	"brawler": ["jab", "dash_punch", "haymaker", "popup_kick"],
	"sword": ["long_slash", "thrust_lunge", "low_cut", "rising_slash"],
	"hammer": ["side_sweep", "overhead_smash", "sky_launcher"],
	"magic": ["spread_shot", "teleport_strike", "fireball"],
}
## Moves that do not hurt anyone on their own (defence, support, utility).
const NON_OFFENSIVE: Array[String] = [
	"guard", "heal_pulse", "rage_taunt", "boost_spark", "pull_hook", "pocket_mine",
	"parry", "deflect_stance", "riposte_step", "mirror_ward", "bulwark_plant", "gravity_well", "counter_palm",
]


## A starting loadout is fine when at least one button holds a close attack and at most one of the 3 moves is non-offensive.
static func loadout_ok(class_id: String, lo: Dictionary) -> bool:
	var close := false
	for slot in ["X", "Y", "B"]:
		var id: String = String(lo.get(slot, ""))
		var key: String = slot if slot != WEAPON_BTN else class_id
		if id in (CLOSE_ATTACKS.get(key, []) as Array):
			close = true
	var passive := 0
	for id in lo.values():
		if String(id) in NON_OFFENSIVE:
			passive += 1
	return close and passive <= 1


## Rolls a loadout (re-rolling internally until it passes loadout_ok).
static func roll_loadout(class_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := _roll_raw(class_id, rng)
	for i in 60:
		if loadout_ok(class_id, out):
			break
		out = _roll_raw(class_id, rng)
	return out


## Run-start loadout: three moves, one on each button: a weapon move on X, an adaptive move on Y, a default move on B.
## Each player may reroll twice in the setup.
static func _roll_raw(class_id: String, rng: RandomNumberGenerator) -> Dictionary:
	# Meta progression is off for now: EVERY move of the class is a candidate (no starred subset).
	var b: Array = get_class_data(class_id)["b_pool"]
	return {
		WEAPON_BTN: b[rng.randi() % b.size()],
		ADAPT_BTN: ADAPT_POOL[rng.randi() % ADAPT_POOL.size()],
		DEFAULT_BTN: DEFAULT_POOL[rng.randi() % DEFAULT_POOL.size()],
	}


## Fixed loadout for the training room: 4 weapon moves (X), 4 adaptive (Y), 4 default (B) so every class can be tried.
static func training_loadout(class_id: String) -> Dictionary:
	var c := get_class_data(class_id)
	var b: Array = c["b_pool"]
	return {
		"X": b[0], "X_UP": b[2], "X_SIDE": b[1], "X_DOWN": b[3],
		"Y": "off_hand_jab", "Y_UP": "uppercut", "Y_SIDE": "flurry", "Y_DOWN": "anti_air",
		"B": "spin_kick", "B_UP": "bicycle_kick", "B_SIDE": "slide_strike", "B_DOWN": "sweep",
	}
