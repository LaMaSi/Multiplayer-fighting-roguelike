class_name MoveDBWeapons
extends RefCounted
## The class moves added for weapon classes (docs/CLASS_MOVES.md): Brawler, Sword, Hammer and Magic B moves,
## the new universal (X) and adaptive (Y) moves. Authored with the same keyframe + hit + event format as MoveDB.
## Speeds: F fast, M medium, S slow, VS very slow. Heights: H / M / L (see the "height" hit key).

const HAMMER_UP := {"lean": -0.3, "ua_f": 3.0, "la_f": 0.1, "ua_b": 2.5, "la_b": 0.4,
	"th_f": 0.5, "kn_f": 0.8, "th_b": -0.5, "kn_b": 0.8, "wp_rot": -1.45}
const SWORD_READY := {"lean": 0.2, "th_f": 0.7, "kn_f": 0.9, "th_b": -0.6, "kn_b": 0.5,
	"ua_f": 1.45, "la_f": 0.1, "ua_b": 0.3, "la_b": 0.5, "wp_rot": -0.95}


static func _p(base: Dictionary, d: Dictionary) -> Dictionary:
	var o := base.duplicate()
	o.merge(d, true)
	return o


static func _mk(d: Dictionary, tier: String, class_id := "") -> MoveData:
	d["tier"] = tier
	d["class_id"] = class_id
	return MoveDB._mk(d)


static func _hit(at: int, dur: int, box: Rect2, dmg: float, stun: int, kb: Vector2, extra := {}) -> Dictionary:
	return MoveDB._hit(at, dur, box, dmg, stun, kb, extra)


static func _idle() -> Dictionary:
	return PoseLib.idle(0.0)


static func build() -> void:
	_universal()
	_adaptive()
	_brawler()
	_sword()
	_hammer()
	_magic()


# ------------------------------------------------------------------ X: universal (off-hand)

static func _universal() -> void:
	_mk({"id": "off_hand_jab", "name": "Off-hand Jab", "short": "OHJAB", "desc": "Quick 2-hit jab with the free hand. Same for every class.",
		"total": 22, "chain_next": "off_hand_jab2", "chain_from": 6,
		"kf": [[0, {"lean": 0.2, "ua_b": 0.6, "la_b": 2.2, "ua_f": 0.8, "la_f": 1.8, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.6}],
			[3, {"lean": 0.35, "ua_b": 1.55, "la_b": 0.05, "ua_f": 0.6, "la_f": 2.0, "th_f": 0.6, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.3}],
			[12, _idle()]],
		"events": [{"at": 2, "type": "vel", "vx": 100.0}, {"at": 2, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(3, 3, Rect2(8, -80, 50, 26), 3, 12, Vector2(60, 0), {"stop": 2})]}, "universal")
	_mk({"id": "off_hand_jab2", "name": "Off-hand Jab 2", "short": "OHJB2", "total": 26,
		"kf": [[0, {"lean": 0.2, "ua_b": 0.8, "la_b": 1.8, "ua_f": 0.6, "la_f": 2.2, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.6}],
			[3, {"lean": 0.4, "ua_f": 1.55, "la_f": 0.05, "ua_b": 0.6, "la_b": 2.0, "th_f": 0.7, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.3}],
			[14, _idle()]],
		"events": [{"at": 2, "type": "vel", "vx": 120.0}, {"at": 2, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(3, 3, Rect2(8, -76, 54, 26), 4, 14, Vector2(90, 0), {"stop": 3})]}, "universal")
	_mk({"id": "spark_shot", "name": "Spark Shot", "short": "SPARK", "desc": "Small straight projectile. Not affected by the weapon.",
		"total": 28, "tags": ["projectile"],
		"kf": [[0, {"lean": 0.0, "ua_f": 0.5, "la_f": 1.7, "th_f": 0.4, "kn_f": 0.6}],
			[6, {"lean": -0.05, "ua_f": 1.5, "la_f": 0.1, "th_f": 0.45, "kn_f": 0.5, "th_b": -0.4}],
			[20, _idle()]],
		"events": [MoveDB._proj(6, {"kind": "spark", "pos": Vector2(42, -62), "vel": Vector2(720, 0), "dmg": 4.0, "stun": 12,
			"kb": Vector2(60, 0), "life": 1.0, "radius": 8.0, "color": Color(1.9, 1.9, 2.2)})]}, "universal")


# ------------------------------------------------------------------ Y: the new adaptive move

static func _adaptive() -> void:
	_mk({"id": "slide_strike", "name": "Slide Strike", "short": "SLIDE", "desc": "Low slide that ends in a crouch. Slides under high attacks.",
		"total": 40, "tags": ["low"], "ground_only": true, "cancel_from": 14,
		"kf": [[0, {"lean": 0.7, "th_f": 1.45, "kn_f": 1.7, "th_b": -0.5, "kn_b": 1.9, "ua_f": 1.0, "la_f": 1.4, "ua_b": 0.4, "la_b": 1.2}],
			[8, {"lean": 0.9, "th_f": 1.6, "kn_f": 0.1, "th_b": -0.4, "kn_b": 1.9, "ua_f": 1.2, "la_f": 0.8, "ua_b": -0.3, "la_b": 0.6}],
			[28, PoseLib.crouch()], [38, _idle()]],
		"events": [{"at": 2, "type": "invuln", "dur": 10}, {"at": 2, "type": "sfx", "name": "whoosh"},
			{"at": 4, "type": "ghost"}, {"at": 8, "type": "ghost"}],
		"drive": [{"from": 2, "to": 20, "vx": 620.0}],
		"hits": [_hit(4, 14, Rect2(0, -30, 90, 32), 6, 24, Vector2(420, 0), {"low": true, "height": "low", "stop": 3, "stun_mult": 1.6})]}, "adaptive")


# ------------------------------------------------------------------ Brawler B (3 new)

static func _brawler() -> void:
	_mk({"id": "counter_palm", "name": "Counter Palm", "short": "CPALM", "desc": "Counter stance. If hit in the window, the attacker is launched.",
		"total": 52, "tags": ["defensive"],
		"kf": [[0, {"lean": 0.0, "ua_f": 1.5, "la_f": 0.0, "ua_b": 1.2, "la_b": 1.5, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.6}],
			[6, {"lean": -0.1, "ua_f": 1.7, "la_f": -0.1, "ua_b": 1.0, "la_b": 1.6, "th_f": 0.5, "kn_f": 0.6, "th_b": -0.5, "kn_b": 0.5}],
			[34, _idle()]],
		"events": [{"at": 3, "type": "parry", "dur": 20}, {"at": 3, "type": "sfx", "name": "buff"}]}, "weapon", "brawler")
	_mk({"id": "shoulder_rush", "name": "Shoulder Rush", "short": "RUSH", "desc": "Armoured charge that shoves enemies away.",
		"total": 44, "cancel_from": 16,
		"kf": [[0, {"lean": 0.6, "th_f": 0.9, "kn_f": 1.3, "th_b": -0.7, "kn_b": 1.0, "ua_f": 0.3, "la_f": 1.8, "ua_b": 0.5, "la_b": 1.7}],
			[6, {"lean": 1.0, "th_f": 1.0, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.3, "ua_f": 0.2, "la_f": 1.9, "ua_b": 0.3, "la_b": 1.8}],
			[30, _idle()]],
		"events": [{"at": 3, "type": "armor", "dur": 26}, {"at": 5, "type": "sfx", "name": "whoosh"},
			{"at": 7, "type": "ghost"}, {"at": 11, "type": "ghost"}, {"at": 15, "type": "ghost"}],
		"drive": [{"from": 6, "to": 22, "vx": 560.0}],
		"hits": [_hit(6, 16, Rect2(-4, -92, 66, 92), 9, 22, Vector2(420, -60), {"kind": "push", "stop": 4})]}, "weapon", "brawler")
	_mk({"id": "popup_kick", "name": "Pop-up Kick", "short": "POPUP", "desc": "Quick low kick that lifts an enemy. Keeps a juggle alive.",
		"total": 28, "tags": ["launcher", "low"], "cancel_from": 9,
		"kf": [[0, {"lean": 0.2, "th_f": 0.4, "kn_f": 1.2, "th_b": -0.5, "kn_b": 0.8, "ua_f": 0.8, "la_f": 1.8}],
			[5, {"lean": 0.5, "th_f": 1.4, "kn_f": 0.1, "th_b": -0.5, "kn_b": 0.5, "ua_f": 0.3, "la_f": 0.8, "ua_b": 1.0}],
			[18, _idle()]],
		"events": [{"at": 4, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(5, 4, Rect2(5, -44, 84, 46), 4, 22, Vector2(60, -540), {"kind": "launch", "low": true, "height": "low", "stop": 3})]}, "weapon", "brawler")


# ------------------------------------------------------------------ Sword B (7 new; Parry Counter exists)

static func _sword() -> void:
	_mk({"id": "long_slash", "name": "Long Slash", "short": "SLASH", "desc": "Wide slash with long reach. Tap again for a second cut.",
		"total": 40, "chain_next": "long_slash2", "chain_from": 14,
		"kf": [[0, _p(SWORD_READY, {"lean": -0.2, "ua_f": -2.0, "la_f": 0.3, "wp_rot": 0.55})],
			[8, _p(SWORD_READY, {"lean": 0.5, "ua_f": 1.65, "la_f": 0.0, "th_f": 1.0, "kn_f": 0.3, "th_b": -0.7, "wp_rot": -0.1})],
			[26, _idle()]],
		"events": [{"at": 7, "type": "vel", "vx": 150.0}, {"at": 7, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(8, 5, Rect2(10, -112, 128, 84), 8, 18, Vector2(200, 0), {"stop": 4})]}, "weapon", "sword")
	_mk({"id": "long_slash2", "name": "Backhand Cut", "short": "SLASH2", "total": 40,
		"kf": [[0, _p(SWORD_READY, {"lean": 0.4, "ua_f": 1.9, "la_f": 0.2, "wp_rot": -0.3})],
			[7, _p(SWORD_READY, {"lean": 0.55, "ua_f": -1.2, "la_f": 0.0, "wp_rot": 0.2, "th_f": 1.0, "kn_f": 0.3})],
			[26, _idle()]],
		"events": [{"at": 6, "type": "vel", "vx": 150.0}, {"at": 6, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(7, 5, Rect2(10, -118, 130, 88), 9, 22, Vector2(300, -240), {"kind": "launch", "stop": 5})]}, "weapon", "sword")
	_mk({"id": "thrust_lunge", "name": "Thrust Lunge", "short": "THRUST", "desc": "Piercing lunge. Hits every enemy in the line.",
		"total": 40, "cancel_from": 14,
		"kf": [[0, _p(SWORD_READY, {"lean": 0.1, "ua_f": 0.6, "la_f": 1.6, "wp_rot": 0.0, "th_f": 0.9, "kn_f": 1.1})],
			[6, _p(SWORD_READY, {"lean": 0.75, "ua_f": 1.5, "la_f": 0.0, "wp_rot": -0.05, "th_f": 1.1, "kn_f": 0.25, "th_b": -0.9, "kn_b": 0.3})],
			[28, _idle()]],
		"events": [{"at": 5, "type": "vel", "vx": 640.0}, {"at": 5, "type": "sfx", "name": "whoosh"},
			{"at": 6, "type": "ghost"}, {"at": 9, "type": "ghost"}],
		"hits": [_hit(6, 9, Rect2(20, -92, 156, 30), 11, 22, Vector2(330, 0), {"kind": "push", "stop": 4})]}, "weapon", "sword")
	_mk({"id": "rising_slash", "name": "Rising Slash", "short": "RISE", "desc": "Upward arc that launches. Reaches higher than a fist.",
		"total": 44, "tags": ["launcher"], "cancel_from": 14,
		"kf": [[0, _p(SWORD_READY, {"lean": 0.35, "ua_f": 0.2, "la_f": 0.3, "wp_rot": 0.7, "th_f": 0.9, "kn_f": 1.3})],
			[7, _p(SWORD_READY, {"lean": -0.2, "ua_f": 3.0, "la_f": 0.1, "wp_rot": -0.15, "th_f": 0.3, "kn_f": 0.2, "th_b": -0.3})],
			[30, _idle()]],
		"events": [{"at": 6, "type": "vel", "vx": 70.0, "vy": -300.0}, {"at": 6, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(7, 5, Rect2(5, -215, 120, 195), 10, 28, Vector2(60, -820), {"kind": "launch", "stop": 5, "shake": 0.25})]}, "weapon", "sword")
	_mk({"id": "low_cut", "name": "Low Cut", "short": "LOWCUT", "desc": "Two low slashes. Staggers (no trip) and fills the stun meter fast.",
		"total": 46, "tags": ["low"], "cancel_from": 22,
		"kf": [[0, _p(SWORD_READY, {"lean": 0.4, "ua_f": -0.5, "la_f": 0.4, "wp_rot": 0.4, "th_f": 1.2, "kn_f": 1.7})],
			[7, _p(SWORD_READY, {"lean": 0.7, "ua_f": 1.9, "la_f": 0.0, "wp_rot": 0.1, "th_f": 1.5, "kn_f": 1.6, "th_b": -0.5, "kn_b": 1.9})],
			[28, _idle()]],
		"events": [{"at": 6, "type": "vel", "vx": 110.0}, {"at": 6, "type": "sfx", "name": "whoosh"}, {"at": 15, "type": "vel", "vx": 90.0}, {"at": 15, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(7, 4, Rect2(10, -30, 138, 34), 6, 24, Vector2(120, 0), {"low": true, "height": "low", "stop": 3, "stun_mult": 2.2}),
			_hit(15, 4, Rect2(10, -30, 150, 34), 7, 30, Vector2(260, 0), {"low": true, "height": "low", "stop": 4, "stun_mult": 2.2})]}, "weapon", "sword")
	_mk({"id": "wind_slash", "name": "Wind Slash", "short": "WIND", "desc": "Crescent of wind. Short range projectile.",
		"total": 46, "tags": ["projectile"],
		# vertical chop: blade raised high over the head, then brought straight down; the crescent flies off the tip
		"kf": [[0, _p(SWORD_READY, {"lean": -0.35, "ua_f": 2.9, "la_f": 0.2, "ua_b": 2.6, "la_b": 0.3, "wp_rot": -0.9, "th_f": 0.5, "kn_f": 0.6, "th_b": -0.5, "kn_b": 0.5})],
			[11, _p(SWORD_READY, {"lean": -0.45, "ua_f": 3.1, "la_f": 0.2, "ua_b": 2.8, "la_b": 0.3, "wp_rot": -1.0, "th_f": 0.5, "kn_f": 0.6, "th_b": -0.5, "kn_b": 0.5})],
			[14, _p(SWORD_READY, {"lean": 0.6, "ua_f": 1.2, "la_f": 0.0, "ua_b": 1.0, "la_b": 0.2, "wp_rot": 0.5, "th_f": 0.9, "kn_f": 0.4, "th_b": -0.7, "kn_b": 0.4})],
			[34, _idle()]],
		"events": [MoveDB._proj(14, {"kind": "crescent", "pos": Vector2(60, -82), "vel": Vector2(650, 0), "dmg": 8.0, "stun": 18,
			"kb": Vector2(200, 0), "life": 0.5, "radius": 24.0, "color": Color(1.9, 1.9, 2.2), "sfx": "whoosh"})]}, "weapon", "sword")
	_mk({"id": "deflect_stance", "name": "Deflect Stance", "short": "DEFLCT", "desc": "Parries projectiles and sends them back. No counter.",
		"total": 54, "tags": ["defensive"],
		# planted wide, blade fanned left-right in front of the body like a windscreen wiper
		"kf": [[0, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.6, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": -2.2, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[6, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.9, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": -2.2, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[12, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.4, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": 0.1, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[18, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.9, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": -2.2, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[24, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.4, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": 0.1, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[30, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.9, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": -2.2, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[36, _p(SWORD_READY, {"lean": 0.0, "ua_f": 1.4, "la_f": 0.3, "ua_b": -0.5, "la_b": 0.5, "wp_rot": 0.1, "th_f": 0.7, "kn_f": 0.7, "th_b": -0.7, "kn_b": 0.7})],
			[46, _idle()]],
		"events": [{"at": 3, "type": "reflect", "dur": 40}, {"at": 3, "type": "sfx", "name": "buff"}]}, "weapon", "sword")
	_mk({"id": "riposte_step", "name": "Riposte Step", "short": "RIPOST", "desc": "Hop back. If struck during the step, counter.",
		"total": 44, "tags": ["defensive"],
		# deep backward crouch: blade trails low behind you, empty hand held out as bait; afterimages mark the hop
		"kf": [[0, _p(SWORD_READY, {"lean": -0.6, "ua_f": -0.7, "la_f": 0.3, "ua_b": 1.9, "la_b": 0.3, "wp_rot": 1.3, "th_f": 0.5, "kn_f": 1.3, "th_b": -1.0, "kn_b": 0.9})],
			[14, _p(SWORD_READY, {"lean": -0.5, "ua_f": -0.7, "la_f": 0.3, "ua_b": 1.9, "la_b": 0.3, "wp_rot": 1.3, "th_f": 0.5, "kn_f": 1.3, "th_b": -1.0, "kn_b": 0.9})],
			[22, _p(SWORD_READY, {"lean": 0.2, "ua_f": 1.5, "la_f": 0.1, "wp_rot": -0.2})],
			[32, _idle()]],
		"events": [{"at": 2, "type": "vel", "vx": -430.0, "vy": -180.0}, {"at": 2, "type": "parry", "dur": 22}, {"at": 2, "type": "sfx", "name": "whoosh"},
			{"at": 4, "type": "ghost"}, {"at": 8, "type": "ghost"}, {"at": 12, "type": "ghost"}]}, "weapon", "sword")


# ------------------------------------------------------------------ Hammer B (8 new)

static func _hammer() -> void:
	_mk({"id": "overhead_smash", "name": "Overhead Smash", "short": "SMASH", "desc": "Huge downward smash. Spikes and ground-bounces.",
		"total": 100,
		# heave up (knee bend, arch back), hang at the top (the tell), a 3-frame chop, then a long recovery with the hammer stuck in the ground
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.15, "ua_f": 1.3, "la_f": 0.5, "ua_b": 1.1, "la_b": 0.5, "wp_rot": -0.2, "th_f": 0.7, "kn_f": 0.9, "th_b": -0.7, "kn_b": 0.9})],
			[13, _p(HAMMER_UP, {"lean": -0.7, "ua_f": 3.3, "la_f": 0.1, "ua_b": 3.0, "la_b": 0.2, "wp_rot": -1.8, "th_f": 0.4, "kn_f": 0.4, "th_b": -0.4, "kn_b": 0.4})],
			[23, _p(HAMMER_UP, {"lean": -0.78, "ua_f": 3.4, "la_f": 0.1, "ua_b": 3.1, "la_b": 0.2, "wp_rot": -1.9, "th_f": 0.4, "kn_f": 0.4, "th_b": -0.4, "kn_b": 0.4})],
			[26, _p(HAMMER_UP, {"lean": 1.0, "ua_f": 1.0, "la_f": 0.1, "ua_b": 0.8, "la_b": 0.3, "th_f": 0.9, "kn_f": 0.6, "th_b": -0.8, "kn_b": 0.6, "wp_rot": 0.9})],
			[66, _p(HAMMER_UP, {"lean": 0.95, "ua_f": 1.0, "la_f": 0.1, "ua_b": 0.8, "la_b": 0.3, "th_f": 0.9, "kn_f": 0.6, "th_b": -0.8, "kn_b": 0.6, "wp_rot": 0.9})],
			[100, _idle()]],
		"events": [{"at": 26, "type": "ring", "radius": 150.0, "sfx": "boom", "shake": 0.6}, {"at": 25, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(26, 4, Rect2(55, -150, 120, 160), 22, 34, Vector2(170, 500), {"kind": "spike", "height": "high", "stop": 9, "shake": 0.5, "prop_power": 2.5, "punch": 0.05}),
			_hit(27, 3, Rect2(-70, -44, 280, 48), 8, 26, Vector2(150, -540), {"radial": true, "kind": "launch", "stop": 4})]}, "weapon", "hammer")
	_mk({"id": "side_sweep", "name": "Side Sweep", "short": "SWEEP", "desc": "Wide swing with very long reach and big knockback.",
		"total": 60,
		# quick low-to-high golf swing with a lunging step: short start-up, follow-through hangs (compare: Overhead Smash)
		"kf": [[0, _p(HAMMER_UP, {"lean": -0.3, "ua_f": -1.1, "la_f": 0.3, "ua_b": -1.4, "la_b": 0.3, "wp_rot": 3.0, "th_f": 0.8, "kn_f": 0.5, "th_b": -0.9, "kn_b": 0.5})],
			[11, _p(HAMMER_UP, {"lean": -0.6, "ua_f": -1.5, "la_f": 0.3, "ua_b": -1.6, "la_b": 0.2, "wp_rot": 3.1, "th_f": 0.8, "kn_f": 0.5, "th_b": -0.9, "kn_b": 0.5})],
			[15, _p(HAMMER_UP, {"lean": 0.8, "ua_f": 1.6, "la_f": 0.0, "ua_b": 1.3, "la_b": 0.2, "th_f": 1.0, "kn_f": 0.4, "th_b": -0.9, "kn_b": 0.4, "wp_rot": 0.1})],
			[24, _p(HAMMER_UP, {"lean": 1.0, "ua_f": 2.2, "la_f": 0.2, "ua_b": 2.0, "la_b": 0.3, "th_f": 1.0, "kn_f": 0.4, "th_b": -0.9, "kn_b": 0.4, "wp_rot": -0.9})],
			[42, _p(HAMMER_UP, {"lean": 0.9, "ua_f": 2.2, "la_f": 0.2, "ua_b": 2.0, "la_b": 0.3, "th_f": 1.0, "kn_f": 0.4, "th_b": -0.9, "kn_b": 0.4, "wp_rot": -0.8})],
			[60, _idle()]],
		"drive": [{"from": 12, "to": 24, "vx": 320.0}],
		"events": [{"at": 14, "type": "sfx", "name": "whoosh"}, {"at": 15, "type": "ghost"}],
		"hits": [_hit(15, 6, Rect2(45, -104, 205, 84), 16, 32, Vector2(720, -80), {"kind": "push", "stop": 7, "shake": 0.35})]}, "weapon", "hammer")
	_mk({"id": "sky_launcher", "name": "Sky Launcher", "short": "SKYLCH", "desc": "Upward swing with a huge launch.",
		"total": 78, "tags": ["launcher"],
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.5, "ua_f": 0.2, "la_f": 0.3, "ua_b": 0.1, "la_b": 0.3, "th_f": 0.9, "kn_f": 1.3, "th_b": -0.8, "kn_b": 1.2, "wp_rot": 2.4})],
			[26, _p(HAMMER_UP, {"lean": 0.55, "ua_f": 0.1, "wp_rot": 2.4})],
			[30, _p(HAMMER_UP, {"lean": -0.25, "ua_f": 3.1, "la_f": 0.1, "ua_b": 2.9, "la_b": 0.2, "th_f": 0.3, "kn_f": 0.2, "th_b": -0.3, "kn_b": 0.2, "wp_rot": -1.6})],
			[54, _idle()]],
		"events": [{"at": 29, "type": "vel", "vx": 60.0, "vy": -260.0}, {"at": 29, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(30, 5, Rect2(25, -245, 135, 245), 14, 34, Vector2(60, -1000), {"kind": "launch", "stop": 8, "shake": 0.4})]}, "weapon", "hammer")
	_mk({"id": "quake_line", "name": "Quake Line", "short": "QUAKE", "desc": "Slam that sends a staggering shockwave along the ground.",
		"total": 82, "tags": ["projectile", "low"], "ground_only": true,
		# low and fast: crouch with the hammer dragged behind, then a short ground chop out of the crouch
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.4, "ua_f": 0.6, "la_f": 0.5, "ua_b": 0.5, "la_b": 0.6, "wp_rot": 2.4, "th_f": 0.9, "kn_f": 1.4, "th_b": -0.9, "kn_b": 1.3})],
			[26, _p(HAMMER_UP, {"lean": -0.15, "ua_f": 0.9, "la_f": 0.4, "ua_b": 0.8, "la_b": 0.4, "wp_rot": 2.9, "th_f": 1.0, "kn_f": 1.5, "th_b": -1.0, "kn_b": 1.4})],
			[30, _p(HAMMER_UP, {"lean": 1.1, "ua_f": 0.9, "la_f": 0.1, "ua_b": 0.7, "la_b": 0.2, "wp_rot": 1.1, "th_f": 1.1, "kn_f": 1.6, "th_b": -0.9, "kn_b": 1.2})],
			[58, _idle()]],
		"events": [{"at": 30, "type": "ring", "radius": 90.0, "sfx": "boom", "shake": 0.45},
			MoveDB._proj(30, {"kind": "quake", "pos": Vector2(70, -16), "vel": Vector2(540, 0), "dmg": 9.0, "stun": 26,
				"kb": Vector2(200, 0), "stun_mult": 2.0, "life": 1.0, "radius": 20.0, "color": Color(1.9, 1.9, 2.2), "pierce": true, "ground": true, "sfx": ""})],
		"hits": [_hit(30, 3, Rect2(50, -64, 110, 68), 12, 30, Vector2(100, -360), {"kind": "trip", "dir": 6, "low": true, "height": "low", "stop": 6, "shake": 0.35})]}, "weapon", "hammer")
	_mk({"id": "whirlwind_haul", "name": "Whirlwind Haul", "short": "WHIRL", "desc": "Spinning swing: hits in front and behind.",
		"total": 84, "steer": 0.3, "spin": {"at": 20, "dur": 38, "turns": 1.0},
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.3, "ua_f": 0.3, "la_f": 0.4, "ua_b": 0.2, "la_b": 0.4, "th_f": 0.8, "kn_f": 1.0, "th_b": -0.8, "kn_b": 1.0, "wp_rot": 2.4})],
			[20, _p(HAMMER_UP, {"lean": 0.0, "ua_f": 1.57, "la_f": 0.0, "ua_b": 1.57, "la_b": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -0.9, "kn_b": 0.3, "wp_rot": 0})],
			[58, _idle()]],
		"events": [{"at": 20, "type": "sfx", "name": "whoosh"}, {"at": 36, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(24, 4, Rect2(-195, -96, 390, 72), 9, 22, Vector2(300, 0), {"radial": true, "stop": 4}),
			_hit(46, 5, Rect2(-200, -100, 400, 78), 11, 30, Vector2(280, -400), {"radial": true, "kind": "launch", "stop": 6, "shake": 0.3})]}, "weapon", "hammer")
	_mk({"id": "guard_breaker", "name": "Guard Breaker", "short": "GBREAK", "desc": "Hold to charge a slam that breaks shields and armour and stuns.",
		"total": 100, "hold": true, "hold_frame": 30, "hold_max": 90,
		# lift the hammer flat overhead like a barbell (armoured, shaking with the charge), then drive it down in a big stride
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.0, "ua_f": 2.0, "la_f": 0.6, "ua_b": 1.9, "la_b": 0.7, "wp_rot": -0.2, "th_f": 0.8, "kn_f": 0.8, "th_b": -0.8, "kn_b": 0.8})],
			[28, _p(HAMMER_UP, {"lean": -0.15, "ua_f": 3.05, "la_f": 0.05, "ua_b": 3.05, "la_b": 0.05, "wp_rot": 0.0, "th_f": 0.9, "kn_f": 0.7, "th_b": -0.9, "kn_b": 0.7})],
			[40, _p(HAMMER_UP, {"lean": 0.7, "ua_f": 1.3, "la_f": 0.1, "ua_b": 1.1, "la_b": 0.2, "th_f": 1.1, "kn_f": 0.5, "th_b": -0.9, "kn_b": 0.5, "wp_rot": 1.3})],
			[72, _idle()]],
		"events": [{"at": 0, "type": "armor", "dur": 80}, {"at": 40, "type": "ring", "radius": 130.0, "sfx": "boom", "shake": 0.5}],
		"hits": [_hit(40, 4, Rect2(50, -135, 135, 135), 18, 70, Vector2(160, -300), {"kind": "launch", "guard_break": true, "stop": 9, "shake": 0.5})]}, "weapon", "hammer")
	_mk({"id": "home_run", "name": "Home Run", "short": "HOMER", "desc": "Launches enemies or your partner far across the screen.",
		"total": 92, "tags": ["team"],
		# batter's stance: sink low with the hammer behind, wobble/tell, then one huge level swing that finishes over the shoulder
		"kf": [[0, _p(HAMMER_UP, {"lean": -0.3, "ua_f": -0.9, "la_f": 0.6, "ua_b": -1.1, "la_b": 0.5, "wp_rot": 2.7, "th_f": 1.0, "kn_f": 1.2, "th_b": -1.0, "kn_b": 1.2})],
			[20, _p(HAMMER_UP, {"lean": -0.65, "ua_f": -1.4, "la_f": 0.4, "ua_b": -1.5, "la_b": 0.3, "wp_rot": 3.0, "th_f": 1.1, "kn_f": 1.3, "th_b": -1.1, "kn_b": 1.3})],
			[32, _p(HAMMER_UP, {"lean": -0.7, "ua_f": -1.5, "la_f": 0.4, "ua_b": -1.6, "la_b": 0.3, "wp_rot": 3.05, "th_f": 1.1, "kn_f": 1.3, "th_b": -1.1, "kn_b": 1.3})],
			[36, _p(HAMMER_UP, {"lean": 0.9, "ua_f": 1.5, "la_f": 0.0, "ua_b": 1.4, "la_b": 0.1, "wp_rot": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.3})],
			[48, _p(HAMMER_UP, {"lean": 0.7, "ua_f": 2.6, "la_f": 0.5, "ua_b": 2.4, "la_b": 0.5, "wp_rot": -2.7, "th_f": 0.8, "kn_f": 0.3, "th_b": -0.8, "kn_b": 0.3})],
			[92, _idle()]],
		"events": [{"at": 35, "type": "sfx", "name": "whoosh"}, {"at": 36, "type": "ghost"}],
		"hits": [_hit(36, 7, Rect2(40, -112, 125, 92), 14, 34, Vector2(1000, -260), {"kind": "launch", "stop": 8, "shake": 0.45, "partner_safe": true})]}, "weapon", "hammer")
	_mk({"id": "bulwark_plant", "name": "Bulwark Plant", "short": "BULWRK", "desc": "Plant the hammer: a barrier that blocks projectiles and melee for 4 s.",
		"total": 64, "tags": ["defensive"],
		# hammer hoisted point-down like a flag, one big stride, then planted upright in front of you; you stand tall behind it
		"kf": [[0, _p(HAMMER_UP, {"lean": 0.0, "ua_f": 2.2, "la_f": 0.3, "ua_b": 2.0, "la_b": 0.4, "wp_rot": 1.2, "th_f": 0.8, "kn_f": 0.6, "th_b": -0.8, "kn_b": 0.6})],
			[24, _p(HAMMER_UP, {"lean": 0.25, "ua_f": 1.5, "la_f": 0.1, "ua_b": 1.4, "la_b": 0.2, "wp_rot": 1.57, "th_f": 1.0, "kn_f": 0.5, "th_b": -0.7, "kn_b": 0.7})],
			[46, _idle()]],
		"events": [{"at": 24, "type": "pillar", "dx": 100.0, "life": 4.0}, {"at": 24, "type": "ring", "radius": 80.0, "sfx": "boom", "shake": 0.35}]}, "weapon", "hammer")


# ------------------------------------------------------------------ Magic B (3 new; marks are pending in MARKS.md)

static func _magic() -> void:
	_mk({"id": "arcane_beam", "name": "Arcane Beam", "short": "BEAM", "desc": "Channel a beam of energy. Keep the partner close to protect you.",
		"total": 96, "tags": ["projectile"], "steer": 0.0,
		"kf": [[0, {"lean": 0.0, "ua_f": 1.7, "la_f": 0.2, "ua_b": 1.6, "la_b": 0.2, "th_f": 0.4, "kn_f": 0.5, "th_b": -0.4, "kn_b": 0.4}],
			[14, {"lean": -0.1, "ua_f": 1.57, "la_f": 0.0, "ua_b": 1.57, "la_b": 0.0, "th_f": 0.5, "kn_f": 0.4, "th_b": -0.5, "kn_b": 0.3}],
			[76, _idle()]],
		"events": [{"at": 16, "type": "beam", "len": 360.0, "dur": 10.0, "sfx": "shoot"}, {"at": 24, "type": "beam", "len": 360.0, "dur": 10.0},
			{"at": 32, "type": "beam", "len": 360.0, "dur": 10.0}, {"at": 40, "type": "beam", "len": 360.0, "dur": 10.0},
			{"at": 48, "type": "beam", "len": 360.0, "dur": 10.0}, {"at": 56, "type": "beam", "len": 360.0, "dur": 10.0}],
		"hits": [_hit(16, 2, Rect2(30, -94, 360, 40), 3, 10, Vector2(40, 0), {"stop": 1, "shake": 0.04}),
			_hit(24, 2, Rect2(30, -94, 360, 40), 3, 10, Vector2(40, 0), {"stop": 1, "shake": 0.04}),
			_hit(32, 2, Rect2(30, -94, 360, 40), 3, 10, Vector2(40, 0), {"stop": 1, "shake": 0.04}),
			_hit(40, 2, Rect2(30, -94, 360, 40), 3, 10, Vector2(40, 0), {"stop": 1, "shake": 0.04}),
			_hit(48, 2, Rect2(30, -94, 360, 40), 3, 10, Vector2(40, 0), {"stop": 1, "shake": 0.04}),
			_hit(56, 3, Rect2(30, -98, 360, 48), 5, 20, Vector2(200, -120), {"kind": "launch", "stop": 4, "shake": 0.15})]}, "weapon", "magic")
	_mk({"id": "gravity_well", "name": "Gravity Well", "short": "WELL", "desc": "Leaves a zone that drags enemies toward its centre for 4 seconds. Gather a crowd for a team combo.",
		"total": 70, "tags": ["utility"],
		# hunch and slam both palms into the floor: the zone opens under your hands
		"kf": [[0, {"lean": 0.1, "ua_f": 2.4, "la_f": 0.3, "ua_b": 2.2, "la_b": 0.3, "th_f": 0.3, "kn_f": 0.4}],
			[10, {"lean": 0.7, "ua_f": 0.5, "la_f": 0.1, "ua_b": 0.2, "la_b": 0.1, "th_f": 0.9, "kn_f": 1.4, "th_b": -0.8, "kn_b": 1.2}],
			[40, {"lean": 0.7, "ua_f": 0.5, "la_f": 0.1, "ua_b": 0.2, "la_b": 0.1, "th_f": 0.9, "kn_f": 1.4, "th_b": -0.8, "kn_b": 1.2}],
			[64, _idle()]],
		"events": [{"at": 12, "type": "ring", "radius": 200.0, "sfx": "buff", "shake": 0.1}, {"at": 12, "type": "well", "radius": 200.0, "life": 4.0, "dist": 240.0}],
		"hits": []}, "weapon", "magic")
	_mk({"id": "mirror_ward", "name": "Mirror Ward", "short": "WARD", "desc": "A shield bubble on your partner (or you): absorbs one hit.",
		"total": 36, "tags": ["buff"],
		# arms sweep up and over the head in a wide arc, then wrap inward: a cloak of light settles on the target
		"kf": [[0, {"lean": 0.1, "ua_f": 0.3, "la_f": 0.4, "ua_b": 0.2, "la_b": 0.4, "th_f": 0.3, "kn_f": 0.4}],
			[10, {"lean": -0.2, "ua_f": 3.0, "la_f": 0.2, "ua_b": 3.0, "la_b": 0.2, "th_f": 0.3, "kn_f": 0.2, "th_b": -0.2, "kn_b": 0.2}],
			[18, {"lean": 0.1, "ua_f": 1.6, "la_f": 1.7, "ua_b": 1.5, "la_b": 1.7}],
			[28, _idle()]],
		"events": [{"at": 18, "type": "ward"}]}, "weapon", "magic")
