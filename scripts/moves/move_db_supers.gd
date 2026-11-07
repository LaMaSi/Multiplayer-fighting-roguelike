class_name MoveDBSupers
extends RefCounted
## Supers (docs/DESIGN.md section 5). Cost 50 % of the personal meter. Input: a double quarter-circle forward
## (down, down-forward, forward, twice) then X for the generic super or B for the class super.
## Every super is invulnerable while it winds up and carries a TEAM RIDER: a partner within reach gets a damage buff
## and a little healing, so using a super is also something you do for the other player.

const COST := 50.0

const SUPER_IDS := ["super_generic", "super_brawler", "super_sword", "super_hammer", "super_magic"]
const CLASS_SUPER := {"brawler": "super_brawler", "sword": "super_sword", "hammer": "super_hammer", "magic": "super_magic"}


static func _hit(at: int, dur: int, box: Rect2, dmg: float, stun: int, kb: Vector2, extra := {}) -> Dictionary:
	return MoveDB._hit(at, dur, box, dmg, stun, kb, extra)


static func _mk(d: Dictionary, class_id := "") -> MoveData:
	d["tier"] = "super"
	d["class_id"] = class_id
	d["meter_cost"] = COST
	return MoveDB._mk(d)


static func build() -> void:
	var idle := PoseLib.idle(0.0)
	# --- generic: Team Surge -------------------------------------------------------------------------------------
	_mk({"id": "super_generic", "name": "Team Surge", "short": "SURGE", "desc": "SUPER (50%). A shockwave that launches everything near you, powers you up and boosts your partner.",
		"total": 60, "ground_only": true,
		"kf": [[0, {"lean": -0.1, "ua_f": 1.2, "la_f": 1.4, "ua_b": 1.2, "la_b": 1.4, "th_f": 0.4, "kn_f": 0.8, "th_b": -0.4, "kn_b": 0.8}],
			[16, {"lean": -0.2, "ua_f": 3.0, "la_f": 0.1, "ua_b": 3.0, "la_b": 0.1, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.5, "kn_b": 0.7}],
			[22, {"lean": 0.3, "ua_f": 1.5, "la_f": 0.05, "ua_b": 1.5, "la_b": 0.05, "th_f": 0.6, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.4}],
			[40, idle], [60, idle]],
		"events": [{"at": 0, "type": "invuln", "dur": 34}, {"at": 22, "type": "ring", "radius": 280.0, "sfx": "boom", "shake": 0.45},
			{"at": 22, "type": "rage", "dur": 8.0}, {"at": 22, "type": "rider"}],
		"hits": [_hit(22, 6, Rect2(-280, -120, 560, 130), 14, 30, Vector2(560, -420), {"radial": true, "kind": "launch", "stop": 7, "shake": 0.4})]})

	# --- Brawler: Fury Barrage -----------------------------------------------------------------------------------
	var bh: Array = []
	var bk: Array = [[0, {"lean": 0.5, "ua_f": 0.6, "la_f": 1.6, "ua_b": 0.6, "la_b": 1.6, "th_f": 0.7, "kn_f": 1.0, "th_b": -0.6, "kn_b": 1.0}]]
	for i in 12:
		var f := 8 + i * 4
		bh.append(_hit(f, 3, Rect2(10, -92 + (i % 3) * 8, 96, 46), 4, 14, Vector2(70, 0), {"stop": 2, "shake": 0.08}))
		if i % 2 == 0:
			bk.append([f, {"lean": 0.6, "ua_f": 1.55, "la_f": 0.0, "ua_b": 0.5, "la_b": 2.0, "th_f": 0.8, "kn_f": 1.0, "th_b": -0.7, "kn_b": 1.0}])
		else:
			bk.append([f, {"lean": 0.6, "ua_b": 1.55, "la_b": 0.0, "ua_f": 0.5, "la_f": 2.0, "th_f": 0.8, "kn_f": 1.0, "th_b": -0.7, "kn_b": 1.0}])
	bh.append(_hit(60, 5, Rect2(10, -96, 110, 70), 20, 30, Vector2(480, -560), {"kind": "launch", "stop": 8, "shake": 0.4}))
	bk.append([60, {"lean": 0.9, "ua_f": 1.57, "la_f": 0.0, "th_f": 1.0, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.4}])
	bk.append([84, idle])
	_mk({"id": "super_brawler", "name": "Fury Barrage", "short": "FURY", "desc": "SUPER (50%). An invulnerable rush of rapid punches that ends in a launcher.",
		"total": 88, "steer": 0.3, "drive": [{"from": 6, "to": 58, "vx": 240.0}],
		"kf": bk, "hits": bh,
		"events": [{"at": 0, "type": "invuln", "dur": 66}, {"at": 8, "type": "rider"}, {"at": 60, "type": "ring", "radius": 120.0, "sfx": "boom", "shake": 0.3}]}, "brawler")

	# --- Sword: Blade Storm --------------------------------------------------------------------------------------
	var sk: Array = [[0, MoveDBWeapons.SWORD_READY],
		[10, {"lean": 0.0, "ua_f": 1.5, "la_f": 0.0, "ua_b": -1.5, "la_b": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -0.9, "kn_b": 0.3, "wp_rot": 0.0}],
		[80, {"lean": 0.0, "ua_f": 1.5, "la_f": 0.0, "ua_b": -1.5, "la_b": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -0.9, "kn_b": 0.3, "wp_rot": 0.0}],
		[100, idle]]
	var sh: Array = []
	for i in 8:
		sh.append(_hit(12 + i * 8, 4, Rect2(-170, -104, 340, 74), 6, 16, Vector2(300, -60), {"radial": true, "stop": 2, "shake": 0.1, "frost": 2.0}))
	sh.append(_hit(78, 5, Rect2(-190, -110, 380, 90), 18, 30, Vector2(340, -640), {"radial": true, "kind": "launch", "stop": 8, "shake": 0.35, "frost": 3.0}))
	_mk({"id": "super_sword", "name": "Blade Storm", "short": "STORM", "desc": "SUPER (50%). A long spinning storm of cuts that chills everything around you, ending in a launch.",
		"total": 104, "steer": 0.6, "spin": {"at": 10, "dur": 66, "turns": 5.0},
		"kf": sk, "hits": sh,
		"events": [{"at": 0, "type": "invuln", "dur": 84}, {"at": 12, "type": "rider"}, {"at": 78, "type": "ring", "radius": 210.0, "sfx": "boom", "shake": 0.4}]}, "sword")

	# --- Hammer: Meteor Slam -------------------------------------------------------------------------------------
	_mk({"id": "super_hammer", "name": "Meteor Slam", "short": "METEOR", "desc": "SUPER (50%). Leap high and crash down: a huge shockwave that launches everything and breaks guards.",
		"total": 112, "land_wait": 34, "steer": 0.4,
		"kf": [[0, MoveDBWeapons.HAMMER_UP], [18, MoveDBWeapons.HAMMER_UP],
			[34, {"lean": 0.5, "ua_f": 1.0, "la_f": 0.3, "ua_b": 0.9, "la_b": 0.3, "th_f": 0.9, "kn_f": 0.6, "th_b": -0.7, "kn_b": 0.7, "wp_rot": 1.2}],
			[46, {"lean": 0.55, "ua_f": 1.0, "la_f": 0.3, "ua_b": 0.9, "la_b": 0.3, "th_f": 0.9, "kn_f": 0.6, "th_b": -0.7, "kn_b": 0.7, "wp_rot": 1.2}],
			[112, idle]],
		"events": [{"at": 0, "type": "invuln", "dur": 80}, {"at": 4, "type": "vel", "vx": 140.0, "vy": -980.0},
			{"at": 24, "type": "dive", "vx": 220.0, "vy": 1500.0}, {"at": 36, "type": "ring", "radius": 300.0, "sfx": "boom", "shake": 0.7},
			{"at": 36, "type": "rider"}],
		"hits": [_hit(36, 7, Rect2(-300, -130, 600, 150), 38, 40, Vector2(520, -720), {"radial": true, "kind": "launch", "stop": 10, "shake": 0.6, "guard_break": true, "prop_power": 2.0, "ignite": 2.5})]}, "hammer")

	# --- Magic: Arcane Nova --------------------------------------------------------------------------------------
	_mk({"id": "super_magic", "name": "Arcane Nova", "short": "NOVA", "desc": "SUPER (50%). Gather power, then a huge burst that shocks and sets everything on fire.",
		"total": 92, "ground_only": true,
		"kf": [[0, {"lean": -0.1, "ua_f": 2.2, "la_f": 0.4, "ua_b": -2.2, "la_b": -0.4, "th_f": 0.3, "kn_f": 0.5, "th_b": -0.3, "kn_b": 0.5}],
			[40, {"lean": 0.1, "ua_f": 3.0, "la_f": 0.1, "ua_b": -3.0, "la_b": -0.1, "th_f": 0.4, "kn_f": 0.6, "th_b": -0.4, "kn_b": 0.6}],
			[50, {"lean": 0.2, "ua_f": 1.6, "la_f": 0.0, "ua_b": -1.6, "la_b": 0.0, "th_f": 0.5, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.5}],
			[92, idle]],
		"events": [{"at": 0, "type": "invuln", "dur": 62}, {"at": 10, "type": "ring", "radius": 70.0, "shake": 0.1}, {"at": 22, "type": "ring", "radius": 110.0, "shake": 0.15},
			{"at": 34, "type": "ring", "radius": 160.0, "shake": 0.2}, {"at": 44, "type": "ring", "radius": 340.0, "sfx": "boom", "shake": 0.6}, {"at": 44, "type": "rider"}],
		"hits": [_hit(44, 6, Rect2(-340, -140, 680, 180), 30, 36, Vector2(640, -500), {"radial": true, "kind": "launch", "stop": 9, "shake": 0.5, "ignite": 3.0, "shock": 3.0})]}, "magic")
