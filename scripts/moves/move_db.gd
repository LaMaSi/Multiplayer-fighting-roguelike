class_name MoveDB
extends RefCounted
## All moves. The 30 player moves are in POOL (index order = the design table in PLAN.md);
## jab2/jab3 are chain parts and the e_* / boss_* moves belong to enemies.

const POOL: Array[String] = [
	"jab", "uppercut", "dash_punch", "sweep", "back_kick",
	"fireball", "boomerang", "spread_shot", "ground_wave", "guard",
	"parry", "reflect", "pocket_mine", "spin_kick", "cyclone",
	"stomp", "dive_kick", "rising_dragon", "anti_air", "haymaker",
	"wall_elbow", "flurry", "shockwave", "pull_hook", "teleport_strike",
	"ally_toss", "heal_pulse", "rage_taunt", "boost_spark", "pillar_smash",
]

## Every move a player can equip (legacy 30-move POOL plus the weapon-class moves).
static func all_player_moves() -> Array:
	var out: Array = []
	for id in ClassData.X_POOL:
		out.append(id)
	for id in ClassData.Y_POOL:
		out.append(id)
	for cid in ClassData.IDS:
		for id in (ClassData.get_class_data(cid)["b_pool"] as Array):
			if not (id in out):
				out.append(id)
	return out


## 12 slots per character: X / Y / B  x  neutral, up, down, side (left and right are the same move;
## pressing a side direction also turns the fighter that way).
const STARTER := {
	"X": "jab", "X_UP": "uppercut", "X_SIDE": "dash_punch", "X_DOWN": "sweep",
}

const SLOTS: Array[String] = [
	"X", "X_UP", "X_SIDE", "X_DOWN",
	"Y", "Y_UP", "Y_SIDE", "Y_DOWN",
	"B", "B_UP", "B_SIDE", "B_DOWN",
]

const ORANGE := Color(2.2, 1.0, 0.3)
const CYAN := Color(0.4, 1.6, 2.2)
const GREEN := Color(2.0, 1.7, 1.9)  ## heal colour: warm white (green/cyan are reserved for the players)
const RED := Color(2.2, 0.4, 0.4)
const GOLD := Color(2.2, 1.8, 0.5)

static var _db: Dictionary = {}


static func get_move(id: String) -> MoveData:
	if _db.is_empty():
		_build()
	return _db.get(id)


static func has_move(id: String) -> bool:
	if _db.is_empty():
		_build()
	return _db.has(id)


static var _variants: Dictionary = {}


## The move as `class_id` performs it. Weapon / universal moves are returned unchanged (apart from the
## class base pose in the recovery); adaptive (Y) moves go through the class modifier table once and are cached.
static func get_move_for(id: String, class_id: String) -> MoveData:
	var m := get_move(id)
	if m == null or class_id == "" or m.enemy:
		return m
	var key := id + "@" + class_id
	if _variants.has(key):
		return _variants[key]
	var v := _make_variant(m, class_id)
	_variants[key] = v
	return v


static func _clone(m: MoveData) -> MoveData:
	var c := MoveData.new()
	for p in m.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var val = m.get(p["name"])
			c.set(p["name"], val.duplicate(true) if (val is Array or val is Dictionary) else val)
	return c


## Piecewise time warp: the wind-up scales by `st`, the active part is untouched, the recovery scales by `rc`.
static func _warp(f: float, first: float, last: float, st: float, rc: float) -> int:
	if f <= first:
		return int(round(f * st))
	if f <= last:
		return int(round(first * st + (f - first)))
	return int(round(first * st + (last - first) + (f - last) * rc))


static func _make_variant(m: MoveData, class_id: String) -> MoveData:
	var cd := ClassData.get_class_data(class_id)
	var mods: Dictionary = cd["mods"]
	var v := _clone(m)
	v.class_id = class_id
	var base := ClassData.base_pose(class_id, 0.0)
	var weapon := String(cd["weapon"])
	# recovery returns to the class silhouette; weapon keys get sensible defaults
	for i in v.kf.size():
		var pose: Dictionary = v.kf[i][1]
		if PoseLib.is_idle(pose):
			v.kf[i][1] = base.duplicate()
		else:
			if weapon == "sword" and not pose.has("wp_rot"):
				# arm strikes (extended arm) run along the blade, so the hit visibly leaves the sword tip
				var extended: bool = pose.has("ua_f") and float(pose.get("la_f", 1.0)) < 0.8
				pose["wp_rot"] = 0.0 if extended else float(base["wp_rot"])
			if weapon == "hammer" and not pose.has("wp_rot"):
				# adaptive moves: the head extends along the front forearm
				var fa: float = float(pose.get("ua_f", 0.95)) + float(pose.get("la_f", 1.55))
				pose["wp_rot"] = PI * 0.5 - fa
			if weapon in ["sword", "hammer"]:
				pose["fist_f"] = pose.get("fist_f", 1.0)
				pose["fist_b"] = pose.get("fist_b", 1.0)
				pose["fist_f"] = minf(float(pose["fist_f"]), 1.5)  # no oversized fists around a weapon
				pose["fist_b"] = minf(float(pose["fist_b"]), 1.5)
	if m.tier != "adaptive":
		return v
	var st: float = mods["startup"]
	var rc: float = mods["recovery"]
	var first := 9999.0
	var last := 0.0
	for h in v.hits:
		first = minf(first, float(h["at"]))
		last = maxf(last, float(h["at"]) + float(h["dur"]))
	if v.hits.is_empty():
		first = float(v.total) * 0.3
		last = first
	for k in v.kf:
		k[0] = _warp(float(k[0]), first, last, st, rc)
	for e in v.events:
		e["at"] = _warp(float(e["at"]), first, last, st, rc)
		if e.has("to"):
			e["to"] = _warp(float(e["to"]), first, last, st, rc)
	var reach: float = mods["reach"]
	var dz: float = mods.get("dead_zone", 0.0)
	for h in v.hits:
		var b: Rect2 = h["box"]
		var d := float(h["dur"])
		h["at"] = _warp(float(h["at"]), first, last, st, rc)
		h["dur"] = maxi(1, int(d))
		if not bool(h.get("radial", false)):
			var left := b.position.x * reach
			var right := (b.position.x + b.size.x) * reach
			if dz > 0.0 and left < dz and right > dz + 24.0 and b.position.x >= 0.0:
				left = dz  # dead zone: nothing connects at point-blank range
			h["box"] = Rect2(left, b.position.y, maxf(right - left, 12.0), b.size.y)
		else:
			h["box"] = Rect2(b.position.x * reach, b.position.y, b.size.x * reach, b.size.y)
		h["dmg"] = float(h["dmg"]) * float(mods["dmg"])
		h["kb"] = (h["kb"] as Vector2) * float(mods["kb"])
		if bool(mods.get("guard_break", false)):
			h["guard_break"] = true
	for d in v.drive:
		d["from"] = _warp(float(d["from"]), first, last, st, rc)
		d["to"] = _warp(float(d["to"]), first, last, st, rc)
	if not v.spin.is_empty():
		v.spin["at"] = _warp(float(v.spin["at"]), first, last, st, rc)
	v.total = _warp(float(v.total), first, last, st, rc)
	if v.cancel_from >= 0:
		v.cancel_from = _warp(float(v.cancel_from), first, last, st, rc)
	if v.chain_from > 0:
		v.chain_from = _warp(float(v.chain_from), first, last, st, rc)
	if v.hold_frame > 0:
		v.hold_frame = _warp(float(v.hold_frame), first, last, st, rc)
	if v.land_wait >= 0:
		v.land_wait = _warp(float(v.land_wait), first, last, st, rc)
	return v


# ---------------------------------------------------------------- helpers

static func _hit(at: int, dur: int, box: Rect2, dmg: float, stun: int, kb: Vector2, extra := {}) -> Dictionary:
	var h := {"at": at, "dur": dur, "box": box, "dmg": dmg, "stun": stun, "kb": kb,
		"kind": "normal", "stop": 3, "low": false, "shake": 0.12, "radial": false}
	h.merge(extra, true)
	return h


static func _mk(d: Dictionary) -> MoveData:
	var m := MoveData.new()
	for k in d:
		m.set(k, d[k])
	if m.short == "":
		m.short = m.name.substr(0, 6).to_upper()
	for i in m.kf.size():
		m.kf[i][1] = _exaggerate(m.kf[i][1])
	_db[m.id] = m
	return m


## Animation principles, applied automatically to every keyframe:
## extended limbs get a big fist/foot and stretch (exaggeration, "smear"),
## cocked limbs contract (anticipation). The spring in StickFigure adds overshoot.
static func _exaggerate(p: Dictionary) -> Dictionary:
	var q := p.duplicate()
	for s in ["f", "b"]:
		var ua: float = q.get("ua_" + s, StickFigure.NEUTRAL["ua_" + s])
		var la: float = q.get("la_" + s, StickFigure.NEUTRAL["la_" + s])
		if la < 0.55 and (ua > 1.0 or ua < -0.9):
			q["fist_" + s] = q.get("fist_" + s, 4.6)
			q["reach_" + s] = q.get("reach_" + s, 1.55)
		elif la > 1.6 and ua > 0.3:
			q["reach_" + s] = q.get("reach_" + s, 0.72)
		var th: float = q.get("th_" + s, StickFigure.NEUTRAL["th_" + s])
		var kn: float = q.get("kn_" + s, StickFigure.NEUTRAL["kn_" + s])
		if absf(th) > 1.1 and kn < 0.5:
			q["foot_" + s] = q.get("foot_" + s, 4.2)
			q["legr_" + s] = q.get("legr_" + s, 1.5)
		elif kn > 1.4:
			q["legr_" + s] = q.get("legr_" + s, 0.78)
	return q


static func _idle() -> Dictionary:
	return PoseLib.idle(0.0)


static func _p(d: Dictionary) -> Dictionary:
	return d


static func _proj(at: int, d: Dictionary) -> Dictionary:
	var e := {"at": at, "type": "proj", "sfx": "shoot"}
	e.merge(d, true)
	return e


# ---------------------------------------------------------------- build

static func _build() -> void:
	_build_player()
	_build_enemy()
	MoveDBWeapons.build()
	MoveDBSupers.build()
	_apply_status()
	_lengthen_short_hits()
	# tiers (weapon / adaptive / universal), owning class and the height of the first hit
	for id in _db:
		var m: MoveData = _db[id]
		if m.enemy:
			continue
		var head := String(id).rstrip("0123456789")
		var t := ClassData.tier_of(head)
		if m.tier == "" and t != "":
			m.tier = t
		if m.tier == "weapon" and m.class_id == "":
			m.class_id = ClassData.class_of_weapon_move(head)
		if not m.hits.is_empty():
			var h0: Dictionary = m.hits[0]
			m.height = String(h0.get("height", "low" if bool(h0.get("low", false)) else "mid"))


static func _build_player() -> void:
	# --- 1 Jab chain (X) -------------------------------------------------
	_mk({"id": "jab", "name": "Jab Chain", "short": "JAB", "desc": "3-hit combo. Tap again to chain.",
		"total": 20, "chain_next": "jab2", "chain_from": 6,
		"kf": [[0, {"lean": 0.25, "ua_f": 0.6, "la_f": 2.2, "ua_b": 0.8, "la_b": 1.8, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.6}],
			[3, {"lean": 0.35, "ua_f": 1.55, "la_f": 0.05, "ua_b": 0.6, "la_b": 2.0, "th_f": 0.6, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.3}],
			[11, _idle()]],
		"events": [{"at": 2, "type": "vel", "vx": 140.0}, {"at": 2, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(3, 3, Rect2(10, -80, 55, 28), 6, 16, Vector2(110, 0))]})
	_mk({"id": "jab2", "name": "Jab 2", "short": "JAB2", "total": 20, "chain_next": "jab3", "chain_from": 6,
		"kf": [[0, {"lean": 0.25, "ua_b": 0.6, "la_b": 2.2, "ua_f": 0.8, "la_f": 1.8, "th_f": 0.5, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.6}],
			[3, {"lean": 0.4, "ua_b": 1.55, "la_b": 0.05, "ua_f": 0.6, "la_f": 2.0, "th_f": 0.7, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.3}],
			[11, _idle()]],
		"events": [{"at": 2, "type": "vel", "vx": 140.0}, {"at": 2, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(3, 3, Rect2(10, -76, 55, 28), 6, 16, Vector2(110, 0), {"stop": 4})]})
	_mk({"id": "jab3", "name": "Jab Finisher", "short": "JAB3", "total": 32,
		"kf": [[0, {"lean": -0.2, "th_f": 0.5, "kn_f": 1.4, "th_b": -0.4, "kn_b": 0.8, "ua_f": 0.8, "la_f": 1.8}],
			[6, {"lean": -0.45, "th_f": 1.5, "kn_f": 0.05, "th_b": -0.3, "kn_b": 0.3, "ua_f": 0.4, "la_f": 1.0, "ua_b": 1.0}],
			[20, _idle()]],
		"events": [{"at": 5, "type": "vel", "vx": 180.0}, {"at": 5, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(6, 4, Rect2(10, -66, 72, 34), 10, 24, Vector2(330, -300), {"kind": "launch", "stop": 6, "shake": 0.3})]})

	# --- 2 Uppercut (X+Up) ----------------------------------------------
	_mk({"id": "uppercut", "name": "Uppercut", "short": "UPPER", "desc": "Launcher. Follow up in the air!",
		"total": 36, "tags": ["launcher"], "cancel_from": 12,
		"kf": [[0, {"lean": 0.3, "th_f": 0.8, "kn_f": 1.4, "th_b": -0.6, "kn_b": 1.4, "ua_f": 0.5, "la_f": 2.0}],
			[6, {"lean": -0.15, "th_f": 0.2, "kn_f": 0.1, "th_b": -0.2, "kn_b": 0.1, "ua_f": 3.1, "la_f": 0.1, "ua_b": 2.0, "la_b": 0.3}],
			[26, _idle()]],
		"events": [{"at": 6, "type": "vel", "vx": 80.0, "vy": -430.0}, {"at": 5, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(6, 5, Rect2(0, -145, 62, 115), 9, 30, Vector2(70, -760), {"kind": "launch", "stop": 5, "shake": 0.3})]})

	# --- 3 Dash punch (X+Fwd) -------------------------------------------
	_mk({"id": "dash_punch", "name": "Dash Punch", "short": "DASHP", "desc": "Gap closer.",
		"total": 30, "cancel_from": 10,
		"kf": [[0, {"lean": 0.5, "ua_f": 0.3, "la_f": 2.4, "th_f": 0.9, "kn_f": 1.0, "th_b": -0.6, "kn_b": 0.8}],
			[5, {"lean": 0.75, "ua_f": 1.55, "la_f": 0.0, "th_f": 1.0, "kn_f": 0.2, "th_b": -0.9, "kn_b": 0.3, "ua_b": -0.5}],
			[20, _idle()]],
		"events": [{"at": 4, "type": "vel", "vx": 900.0}, {"at": 4, "type": "sfx", "name": "whoosh"},
			{"at": 5, "type": "ghost"}, {"at": 8, "type": "ghost"}, {"at": 11, "type": "ghost"}],
		"hits": [_hit(5, 9, Rect2(5, -80, 68, 32), 10, 22, Vector2(340, 0), {"kind": "push", "stop": 4})]})

	# --- 4 Leg sweep (X+Down) -------------------------------------------
	_mk({"id": "sweep", "name": "Leg Sweep", "short": "SWEEP", "desc": "Low. Trips enemies.",
		"total": 34, "tags": ["low"], "cancel_from": 12,
		"kf": [[0, {"lean": 0.35, "th_f": 1.2, "kn_f": 2.2, "th_b": -0.8, "kn_b": 2.0, "ua_f": 1.0, "la_f": 1.0}],
			[6, {"lean": -0.3, "th_f": 1.5, "kn_f": 0.0, "th_b": -0.5, "kn_b": 2.2, "ua_f": -0.5, "la_f": 0.3, "ua_b": 1.3, "la_b": 0.5}],
			[22, _idle()]],
		"events": [{"at": 5, "type": "vel", "vx": 120.0}, {"at": 5, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(6, 5, Rect2(0, -24, 88, 26), 7, 26, Vector2(90, -330), {"kind": "trip", "low": true, "stop": 4})]})

	# --- 5 Back kick (X+Back) -------------------------------------------
	_mk({"id": "back_kick", "name": "Back Kick", "short": "BKICK", "desc": "Hits behind you.",
		"total": 30, "cancel_from": 10,
		"kf": [[0, {"lean": 0.3, "th_f": 0.4, "kn_f": 0.8, "ua_f": 1.0, "la_f": 1.5}],
			[6, {"lean": 0.7, "th_b": -1.55, "kn_b": 0.0, "th_f": 0.3, "kn_f": 0.6, "ua_f": 1.3, "la_f": 0.6, "ua_b": 0.9}],
			[20, _idle()]],
		"events": [{"at": 5, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(6, 4, Rect2(-98, -68, 82, 34), 11, 22, Vector2(-300, -140), {"kind": "push", "stop": 4})]})

	# --- 6 Fireball -----------------------------------------------------
	_mk({"id": "fireball", "name": "Fireball", "short": "FIRE", "desc": "Projectile.",
		"total": 40, "tags": ["projectile"],
		"kf": [[0, {"lean": 0.1, "ua_f": 0.4, "la_f": 1.8, "ua_b": 0.5, "la_b": 1.8, "th_f": 0.4, "kn_f": 0.6}],
			[10, {"lean": -0.1, "ua_f": 1.5, "la_f": 0.1, "ua_b": 1.45, "la_b": 0.15, "th_f": 0.5, "kn_f": 0.6, "th_b": -0.4}],
			[28, _idle()]],
		"events": [_proj(10, {"kind": "fireball", "splash": 90.0, "pos": Vector2(45, -62), "vel": Vector2(580, 0), "dmg": 9.0, "stun": 18,
			"kb": Vector2(200, 0), "life": 1.4, "radius": 14.0, "color": ORANGE})]})

	# --- 7 Boomerang disc -----------------------------------------------
	_mk({"id": "boomerang", "name": "Boomerang Disc", "short": "DISC", "desc": "Returns and hits twice.",
		"total": 38, "tags": ["projectile"],
		"kf": [[0, {"lean": -0.2, "ua_f": -0.6, "la_f": 1.0, "th_f": 0.4, "kn_f": 0.6}],
			[8, {"lean": 0.3, "ua_f": 1.55, "la_f": 0.1, "th_f": 0.6, "kn_f": 0.4, "th_b": -0.4}],
			[26, _idle()]],
		"events": [_proj(8, {"kind": "blade", "pos": Vector2(40, -62), "vel": Vector2(560, 0), "dmg": 6.0, "stun": 16,
			"kb": Vector2(120, -80), "life": 2.4, "radius": 16.0, "color": CYAN, "returns": 0.42, "pierce": true})]})

	# --- 8 Spread shot --------------------------------------------------
	_mk({"id": "spread_shot", "name": "Spread Shot", "short": "SPREAD", "desc": "Three-way projectile.",
		"total": 36, "tags": ["projectile"],
		"kf": [[0, {"lean": 0.1, "ua_f": 0.6, "la_f": 1.6, "ua_b": 0.6, "la_b": 1.6}],
			[8, {"lean": -0.1, "ua_f": 1.5, "la_f": 0.2, "ua_b": 1.4, "la_b": 0.2, "th_f": 0.5, "kn_f": 0.5, "th_b": -0.5}],
			[26, _idle()]],
		"events": [
			_proj(8, {"kind": "dart", "pos": Vector2(42, -62), "vel": Vector2(520, -120), "dmg": 5.0, "stun": 14, "kb": Vector2(120, 0), "life": 0.9, "radius": 10.0, "color": GREEN}),
			_proj(8, {"kind": "dart", "pos": Vector2(42, -62), "vel": Vector2(540, 0), "dmg": 5.0, "stun": 14, "kb": Vector2(120, 0), "life": 0.9, "radius": 10.0, "color": GREEN, "sfx": ""}),
			_proj(8, {"kind": "dart", "pos": Vector2(42, -62), "vel": Vector2(520, 120), "dmg": 5.0, "stun": 14, "kb": Vector2(120, 0), "life": 0.9, "radius": 10.0, "color": GREEN, "sfx": ""})]})

	# --- 9 Ground wave --------------------------------------------------
	_mk({"id": "ground_wave", "name": "Ground Wave", "short": "WAVE", "desc": "Low projectile that trips.",
		"total": 44, "tags": ["projectile", "low"], "ground_only": true,
		"kf": [[0, {"lean": 0.4, "ua_f": 2.4, "la_f": 0.3, "th_f": 0.6, "kn_f": 1.0, "th_b": -0.5, "kn_b": 1.0}],
			[10, {"lean": 0.85, "ua_f": 0.6, "la_f": 0.1, "th_f": 1.0, "kn_f": 1.6, "th_b": -0.7, "kn_b": 1.8}],
			[30, _idle()]],
		"events": [_proj(10, {"kind": "wave", "pos": Vector2(40, -14), "vel": Vector2(470, 0), "dmg": 8.0, "stun": 26,
			"kb": Vector2(80, -330), "pkind": "trip", "life": 1.1, "radius": 18.0, "color": ORANGE, "pierce": true, "ground": true})]})

	# --- 10 Guard block (hold) -------------------------------------------
	_mk({"id": "guard", "name": "Guard Block", "short": "GUARD", "desc": "Hold to block frontal hits.",
		"total": 14, "tags": ["defensive"], "hold": true, "hold_frame": 6, "steer": 0.0,
		"kf": [[0, PoseLib.guard()], [6, PoseLib.guard()], [8, _idle()]],
		"events": [{"at": 2, "type": "guard"}, {"at": 7, "type": "guard_off"}]})

	# --- 11 Parry counter -----------------------------------------------
	_mk({"id": "parry", "name": "Parry Counter", "short": "PARRY", "desc": "Perfect timing: negate and counter.",
		"total": 42, "tags": ["defensive"],
		"kf": [[0, {"lean": 0.0, "ua_f": 1.5, "la_f": 1.0, "ua_b": 1.4, "la_b": 1.1, "th_f": 0.3, "kn_f": 0.5}],
			[4, {"lean": -0.1, "ua_f": 1.7, "la_f": 0.2, "ua_b": 1.6, "la_b": 0.3, "th_f": 0.4, "kn_f": 0.4}],
			[16, {"lean": 0.1, "ua_f": 1.2, "la_f": 1.4}], [34, _idle()]],
		"events": [{"at": 3, "type": "parry", "dur": 11}]})

	# --- 12 Reflect shield ----------------------------------------------
	_mk({"id": "reflect", "name": "Reflect Shield", "short": "REFL", "desc": "Bounces projectiles back.",
		"total": 46, "tags": ["defensive"],
		"kf": [[0, {"lean": 0.0, "ua_f": 1.2, "la_f": 1.2, "ua_b": 1.2, "la_b": 1.2}],
			[5, {"lean": -0.1, "ua_f": 1.57, "la_f": 0.0, "ua_b": 1.57, "la_b": 0.0, "th_f": 0.4, "kn_f": 0.4, "th_b": -0.4}],
			[34, {"lean": -0.1, "ua_f": 1.57, "la_f": 0.0, "ua_b": 1.57, "la_b": 0.0}], [46, _idle()]],
		"events": [{"at": 4, "type": "reflect", "dur": 30}, {"at": 4, "type": "sfx", "name": "buff"}]})

	# --- 13 Pocket Mine (replaces Dodge Roll Strike, which the RT dash now covers) ---
	_mk({"id": "pocket_mine", "name": "Pocket Mine", "short": "MINE", "desc": "Drops a mine. Launches the first enemy to step on it.",
		"total": 30, "tags": ["projectile"],
		"kf": [[0, {"lean": 0.5, "th_f": 0.9, "kn_f": 1.6, "th_b": -0.5, "kn_b": 1.4, "ua_f": 0.6, "la_f": 0.4, "ua_b": 0.3, "la_b": 0.3}],
			[8, {"lean": 0.7, "th_f": 1.0, "kn_f": 1.7, "th_b": -0.5, "kn_b": 1.5, "ua_f": 0.4, "la_f": 0.1}],
			[22, _idle()]],
		"events": [_proj(8, {"kind": "mine", "pos": Vector2(34, -6), "vel": Vector2.ZERO, "dmg": 12.0, "stun": 30,
			"kb": Vector2(180, -640), "life": 10.0, "radius": 14.0, "color": ORANGE, "pkind": "launch", "ground": true, "sfx": "pickup"})]})

	# --- 14 Spin kick ---------------------------------------------------
	var spin_hits: Array = []
	for i in 3:
		spin_hits.append(_hit(8 + i * 8, 3, Rect2(-88, -78, 176, 46), 5, 16, Vector2(220, 0), {"radial": true, "stop": 3}))
	spin_hits[2] = _hit(24, 4, Rect2(-90, -80, 180, 50), 7, 28, Vector2(260, -380), {"radial": true, "kind": "launch", "stop": 6, "shake": 0.25})
	_mk({"id": "spin_kick", "name": "Spin Kick", "short": "SPIN", "desc": "360 multi-hit.",
		"total": 46, "steer": 0.35, "spin": {"at": 6, "dur": 28, "turns": 2.0}, "cancel_from": 30,
		"kf": [[0, {"lean": 0.2, "th_f": 0.5, "kn_f": 1.0, "ua_f": 1.0, "la_f": 1.0}],
			[6, {"lean": -0.1, "th_f": 1.55, "kn_f": 0.0, "th_b": -0.2, "kn_b": 0.2, "ua_f": 1.57, "la_f": 0.0, "ua_b": -1.57, "la_b": 0.0}],
			[34, _idle()]],
		"events": [{"at": 6, "type": "sfx", "name": "whoosh"}, {"at": 14, "type": "sfx", "name": "whoosh"}, {"at": 22, "type": "sfx", "name": "whoosh"}],
		"hits": spin_hits})

	# --- 15 Cyclone -----------------------------------------------------
	var cy_hits: Array = []
	for i in 8:
		cy_hits.append(_hit(8 + i * 9, 3, Rect2(-80, -80, 160, 56), 4, 14, Vector2(160, 0), {"radial": true, "stop": 2}))
	cy_hits[7] = _hit(80, 4, Rect2(-84, -84, 168, 62), 6, 26, Vector2(260, -420), {"radial": true, "kind": "launch", "stop": 6})
	_mk({"id": "cyclone", "name": "Cyclone", "short": "CYCLN", "desc": "Moving whirlwind. Steer with the stick.",
		"total": 98, "steer": 0.75, "spin": {"at": 6, "dur": 80, "turns": 6.0},
		"kf": [[0, {"lean": 0.3, "th_f": 0.6, "kn_f": 1.0}],
			[6, {"lean": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -0.9, "kn_b": 0.3, "ua_f": 1.5, "la_f": 0.0, "ua_b": -1.5, "la_b": 0.0}],
			[88, _idle()]],
		"events": [{"at": 6, "type": "sfx", "name": "whoosh"}, {"at": 30, "type": "sfx", "name": "whoosh"}, {"at": 54, "type": "sfx", "name": "whoosh"}, {"at": 76, "type": "sfx", "name": "whoosh"}],
		"drive": [{"from": 6, "to": 84, "vx": 150.0}],
		"hits": cy_hits})

	# --- 16 Shockwave stomp ---------------------------------------------
	_mk({"id": "stomp", "name": "Shockwave Stomp", "short": "STOMP", "desc": "Ground AoE. Breaks crates.",
		"total": 46, "ground_only": true, "cancel_from": 20,
		"kf": [[0, {"lean": 0.0, "th_f": 1.6, "kn_f": 1.8, "th_b": -0.2, "kn_b": 0.3, "ua_f": 2.0, "la_f": 0.4, "ua_b": 2.0, "la_b": 0.4}],
			[12, {"lean": 0.3, "th_f": 0.2, "kn_f": 0.0, "th_b": -0.2, "kn_b": 1.0, "ua_f": 0.2, "la_f": 0.2, "ua_b": -0.2}],
			[36, _idle()]],
		"events": [{"at": 12, "type": "ring", "radius": 150.0, "sfx": "boom", "shake": 0.45}],
		"hits": [_hit(12, 3, Rect2(-125, -34, 250, 36), 10, 30, Vector2(170, -440), {"radial": true, "kind": "launch", "low": true, "stop": 7, "shake": 0.4, "prop_power": 1.4})]})

	# --- 17 Dive kick ---------------------------------------------------
	_mk({"id": "dive_kick", "name": "Dive Kick", "short": "DIVE", "desc": "Air: slam enemies down. Spikes juggled enemies!",
		"total": 30, "air_only": true, "land_wait": 8, "tags": ["air"],
		"kf": [[0, {"lean": 0.3, "th_f": 1.0, "kn_f": 1.5, "th_b": 0.4, "kn_b": 1.5, "ua_f": 1.5, "la_f": 1.0}],
			[8, {"lean": 0.1, "th_f": 0.35, "kn_f": 0.0, "th_b": -0.1, "kn_b": 0.2, "ua_f": 2.2, "la_f": 0.3, "ua_b": 2.0, "la_b": 0.3}],
			[18, _idle()]],
		"events": [{"at": 8, "type": "dive", "vx": 380.0, "vy": 1150.0}, {"at": 8, "type": "tilt", "rot": -0.85},
			{"at": 9, "type": "tilt", "rot": 0.0}, {"at": 9, "type": "ring", "radius": 90.0, "sfx": "land", "shake": 0.3}],
		"hits": [_hit(8, 1, Rect2(-8, -34, 78, 62), 12, 30, Vector2(150, 900), {"kind": "spike", "stop": 6, "shake": 0.3}),
			_hit(9, 3, Rect2(-80, -28, 160, 30), 5, 20, Vector2(200, -300), {"radial": true, "kind": "launch"})]})

	# --- 18 Rising dragon -----------------------------------------------
	_mk({"id": "rising_dragon", "name": "Rising Dragon", "short": "DRAGON", "desc": "Invulnerable launcher.",
		"total": 56, "tags": ["launcher"], "spin": {"at": 4, "dur": 16, "turns": 1.0},
		"kf": [[0, {"lean": 0.4, "th_f": 0.8, "kn_f": 1.5, "th_b": -0.6, "kn_b": 1.5, "ua_f": 0.5, "la_f": 2.0}],
			[4, {"lean": -0.1, "th_f": 0.1, "kn_f": 0.0, "th_b": -0.1, "kn_b": 0.0, "ua_f": 3.1, "la_f": 0.0, "ua_b": 3.0, "la_b": 0.0}],
			[24, {"lean": 0.0, "th_f": 0.6, "kn_f": 0.8, "th_b": -0.3, "kn_b": 0.8, "ua_f": 2.0, "la_f": 0.4}], [56, _idle()]],
		"events": [{"at": 0, "type": "invuln", "dur": 16}, {"at": 4, "type": "vel", "vx": 130.0, "vy": -930.0}, {"at": 4, "type": "sfx", "name": "whoosh"}, {"at": 6, "type": "ghost"}, {"at": 9, "type": "ghost"}],
		"hits": [_hit(4, 3, Rect2(-10, -185, 85, 185), 6, 24, Vector2(60, -520), {"kind": "launch", "stop": 3}),
			_hit(7, 3, Rect2(-10, -185, 85, 185), 6, 24, Vector2(60, -560), {"kind": "launch", "stop": 3}),
			_hit(10, 4, Rect2(-10, -190, 85, 190), 8, 30, Vector2(120, -840), {"kind": "launch", "stop": 6, "shake": 0.3})]})

	# --- 19 Anti-air hook -----------------------------------------------
	_mk({"id": "anti_air", "name": "Anti-air Hook", "short": "HOOK", "desc": "Hits high above you.",
		"total": 28, "tags": ["launcher"], "cancel_from": 10,
		"kf": [[0, {"lean": 0.2, "ua_f": -0.4, "la_f": 1.0, "th_f": 0.4, "kn_f": 0.6}],
			[5, {"lean": -0.35, "ua_f": 2.5, "la_f": 0.1, "ua_b": 0.5, "th_f": 0.3, "kn_f": 0.3}],
			[18, _idle()]],
		"events": [{"at": 4, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(5, 4, Rect2(-5, -215, 105, 150), 9, 26, Vector2(120, -640), {"kind": "launch", "stop": 4, "shake": 0.2})]})

	# --- 20 Heavy haymaker ----------------------------------------------
	_mk({"id": "haymaker", "name": "Heavy Haymaker", "short": "HAYMKR", "desc": "Slow, huge knockback, armoured windup.",
		"total": 60,
		"kf": [[0, {"lean": -0.5, "ua_f": -1.0, "la_f": 0.5, "ua_b": 0.5, "la_b": 1.0, "th_f": 0.5, "kn_f": 0.8, "th_b": -0.6, "kn_b": 0.5}],
			[12, {"lean": -0.95, "ua_f": -1.7, "la_f": 0.6, "th_f": 0.7, "kn_f": 1.1, "th_b": -0.9, "kn_b": 0.9, "root_x": -6.0}],
			[22, {"lean": -1.0, "ua_f": -1.8, "la_f": 0.6, "th_f": 0.7, "kn_f": 1.1, "root_x": -8.0}],
			[24, {"lean": 1.05, "ua_f": 1.57, "la_f": 0.0, "ua_b": -0.4, "th_f": 1.0, "kn_f": 0.2, "th_b": -0.9, "kn_b": 0.3}],
			[44, _idle()]],
		"events": [{"at": 6, "type": "armor", "dur": 20}, {"at": 24, "type": "vel", "vx": 220.0}, {"at": 23, "type": "sfx", "name": "whoosh"}],
		"hits": [_hit(24, 4, Rect2(5, -92, 86, 50), 24, 40, Vector2(780, -200), {"kind": "launch", "stop": 10, "shake": 0.6, "punch": 0.06})]})

	# --- 21 Wall-bounce elbow -------------------------------------------
	_mk({"id": "wall_elbow", "name": "Wall-bounce Elbow", "short": "ELBOW", "desc": "Enemies bounce off walls for bonus damage.",
		"total": 36, "cancel_from": 14,
		"kf": [[0, {"lean": 0.4, "ua_f": 0.6, "la_f": 2.4, "th_f": 0.8, "kn_f": 1.0, "th_b": -0.6, "kn_b": 0.8}],
			[7, {"lean": 0.8, "ua_f": 1.1, "la_f": 2.6, "th_f": 1.0, "kn_f": 0.4, "th_b": -0.9, "kn_b": 0.3}],
			[24, _idle()]],
		"events": [{"at": 6, "type": "vel", "vx": 560.0}, {"at": 6, "type": "sfx", "name": "whoosh"}, {"at": 7, "type": "ghost"}],
		"hits": [_hit(8, 5, Rect2(10, -82, 52, 38), 10, 26, Vector2(540, -80), {"kind": "launch", "wallbounce": true, "stop": 6})]})

	# --- 22 Flurry ------------------------------------------------------
	var fl_hits: Array = []
	var fl_kf: Array = [[0, {"lean": 0.5, "ua_f": 0.6, "la_f": 1.6, "ua_b": 0.6, "la_b": 1.6, "th_f": 0.7, "kn_f": 1.0, "th_b": -0.6, "kn_b": 1.0}]]
	for i in 10:
		var f := 4 + i * 4
		fl_hits.append(_hit(f, 2, Rect2(8, -82 + (i % 3) * 6, 58, 28), 2.5, 9, Vector2(25, 0), {"stop": 1, "shake": 0.05}))
		if i % 2 == 0:
			fl_kf.append([f, {"lean": 0.55, "ua_f": 1.55, "la_f": 0.0, "ua_b": 0.5, "la_b": 2.0, "th_f": 0.7, "kn_f": 1.0, "th_b": -0.6, "kn_b": 1.0}])
		else:
			fl_kf.append([f, {"lean": 0.55, "ua_b": 1.55, "la_b": 0.0, "ua_f": 0.5, "la_f": 2.0, "th_f": 0.7, "kn_f": 1.0, "th_b": -0.6, "kn_b": 1.0}])
	fl_hits.append(_hit(46, 3, Rect2(8, -84, 64, 34), 6, 24, Vector2(420, -120), {"kind": "launch", "stop": 6}))
	fl_kf.append([46, {"lean": 0.9, "ua_f": 1.57, "la_f": 0.0, "th_f": 1.0, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.4}])
	fl_kf.append([62, _idle()])
	_mk({"id": "flurry", "name": "Flurry", "short": "FLURRY", "desc": "Rapid jabs, low knockback.",
		"total": 64, "steer": 0.2, "drive": [{"from": 4, "to": 44, "vx": 55.0}],
		"kf": fl_kf, "hits": fl_hits})

	# --- 23 Grab & throw ------------------------------------------------
	_mk({"id": "grab_throw", "name": "Grab & Throw", "short": "GRAB", "desc": "Grab an enemy. Aim with the stick (forward, back, up, down), then press a button again to throw.",
		"total": 58, "tags": ["grab"], "ground_only": true,
		"kf": [[0, {"lean": 0.3, "ua_f": 1.5, "la_f": 0.1, "ua_b": 1.5, "la_b": 0.1, "th_f": 0.5, "kn_f": 0.6}],
			[10, {"lean": -0.12, "ua_f": 3.0, "la_f": 0.1, "ua_b": 2.95, "la_b": 0.1, "th_f": 0.5, "kn_f": 0.8, "th_b": -0.45, "kn_b": 0.8}],
			[26, {"lean": -0.18, "ua_f": 3.05, "la_f": 0.05, "ua_b": 3.0, "la_b": 0.05, "th_f": 0.5, "kn_f": 0.8, "th_b": -0.45, "kn_b": 0.8}],
			[32, {"lean": 0.55, "ua_f": 1.3, "la_f": 0.15, "ua_b": 1.3, "la_b": 0.15, "th_f": 0.8, "kn_f": 0.5, "th_b": -0.5, "kn_b": 0.4}],
			[58, _idle()]],
		"events": [{"at": 11, "type": "whiff_skip", "to": 40}, {"at": 26, "type": "throw", "vx": 600.0, "vy": -300.0}],
		"hits": [_hit(5, 3, Rect2(8, -88, 50, 74), 0, 0, Vector2.ZERO, {"grab": true, "partner_safe": true})]})

	# --- Shockwave clap: replaces Grab & Throw in the X pool (grab is on LB now) ---------------
	_mk({"id": "shockwave", "name": "Shockwave Clap", "short": "CLAP", "desc": "A clap that blasts everything around you away. Makes room, breaks crates.",
		"total": 40, "ground_only": true, "cancel_from": 22,
		"kf": [[0, {"lean": -0.1, "ua_f": -0.6, "la_f": 0.3, "ua_b": -0.9, "la_b": 0.3, "th_f": 0.4, "kn_f": 0.7, "th_b": -0.4, "kn_b": 0.7}],
			[8, {"lean": 0.2, "ua_f": 1.55, "la_f": 0.05, "ua_b": 1.5, "la_b": 0.05, "th_f": 0.5, "kn_f": 0.6, "th_b": -0.35, "kn_b": 0.5}],
			[30, _idle()]],
		"events": [{"at": 8, "type": "ring", "radius": 120.0, "sfx": "boom", "shake": 0.3}],
		"hits": [_hit(8, 6, Rect2(-120, -96, 240, 100), 6, 22, Vector2(560, -140), {"radial": true, "stop": 5, "shake": 0.25, "prop_power": 1.6})]})

	# --- 24 Pull hook ---------------------------------------------------
	_mk({"id": "pull_hook", "name": "Pull Hook", "short": "PULL", "desc": "Drags an enemy to you.",
		"total": 40, "tags": ["utility"],
		"kf": [[0, {"lean": 0.0, "ua_f": 0.4, "la_f": 1.8, "th_f": 0.4, "kn_f": 0.5}],
			[6, {"lean": 0.3, "ua_f": 1.55, "la_f": 0.0, "th_f": 0.6, "kn_f": 0.4, "th_b": -0.5}],
			[16, {"lean": -0.3, "ua_f": 0.9, "la_f": 1.3}], [28, _idle()]],
		"events": [{"at": 6, "type": "beam", "len": 310.0, "dur": 10, "sfx": "throw"}],
		"hits": [_hit(6, 6, Rect2(15, -88, 310, 30), 4, 26, Vector2.ZERO, {"kind": "pull", "stop": 4, "color": CYAN})]})

	# --- 25 Teleport strike ---------------------------------------------
	_mk({"id": "teleport_strike", "name": "Teleport Strike", "short": "BLINK", "desc": "Blink behind the nearest enemy and slash.",
		"total": 42, "tags": ["utility"],
		"kf": [[0, {"lean": 0.4, "th_f": 0.8, "kn_f": 1.5, "th_b": -0.6, "kn_b": 1.5, "ua_f": 0.5, "la_f": 1.8}],
			[12, {"lean": 0.7, "ua_f": 1.55, "la_f": 0.0, "ua_b": -0.6, "th_f": 1.0, "kn_f": 0.2, "th_b": -0.9, "kn_b": 0.3}],
			[28, _idle()]],
		"events": [{"at": 4, "type": "vis", "v": false}, {"at": 4, "type": "tp"}, {"at": 10, "type": "vis", "v": true}],
		"hits": [_hit(12, 4, Rect2(0, -84, 66, 44), 12, 24, Vector2(260, -100), {"kind": "push", "stop": 5, "shake": 0.2})]})

	# --- 26 Ally toss ---------------------------------------------------
	_mk({"id": "ally_toss", "name": "Ally Toss", "short": "TOSS", "desc": "Throw your partner as a flying kick!",
		"total": 64, "tags": ["team"], "ground_only": true,
		"kf": [[0, {"lean": 0.3, "ua_f": 1.5, "la_f": 0.1, "ua_b": 1.5, "la_b": 0.1, "th_f": 0.5, "kn_f": 0.6}],
			[10, {"lean": -0.1, "ua_f": 3.0, "la_f": 0.1, "ua_b": 2.9, "la_b": 0.1}],
			[30, {"lean": 0.7, "ua_f": 1.0, "la_f": 0.2, "ua_b": 1.0, "la_b": 0.2, "th_f": 0.8, "kn_f": 0.5}],
			[64, _idle()]],
		"events": [{"at": 6, "type": "toss_grab"}, {"at": 12, "type": "whiff_skip", "to": 44}, {"at": 30, "type": "toss"}]})

	# --- 27 Heal pulse --------------------------------------------------
	_mk({"id": "heal_pulse", "name": "Heal Pulse", "short": "HEAL", "desc": "Damages nearby enemies, heals you and your partner.",
		"total": 54, "tags": ["buff"],
		"kf": [[0, {"lean": 0.3, "ua_f": 1.2, "la_f": 1.8, "ua_b": 1.2, "la_b": 1.8, "th_f": 0.5, "kn_f": 0.9, "th_b": -0.4, "kn_b": 0.9}],
			[14, {"lean": -0.2, "ua_f": 1.2, "la_f": 0.0, "ua_b": 1.4, "la_b": 0.0, "th_f": 0.3, "kn_f": 0.2, "th_b": -0.3, "kn_b": 0.2}],
			[40, _idle()]],
		"events": [{"at": 14, "type": "heal_pulse", "radius": 170.0, "amount": 10.0}],
		"hits": [_hit(14, 2, Rect2(-150, -105, 300, 112), 3, 18, Vector2(170, -100), {"radial": true, "heal_self": 4.0, "color": GREEN, "stop": 3})]})

	# --- 28 Rage taunt --------------------------------------------------
	_mk({"id": "rage_taunt", "name": "Rage Taunt", "short": "RAGE", "desc": "Damage up, defence down for 8s.",
		"total": 62, "tags": ["buff"],
		"kf": [[0, {"lean": 0.2, "ua_f": 1.0, "la_f": 2.4, "ua_b": 1.0, "la_b": 2.4}],
			[10, {"lean": -0.35, "ua_f": 2.8, "la_f": 0.2, "ua_b": 2.8, "la_b": 0.2, "th_f": 0.3, "kn_f": 0.3, "th_b": -0.3, "kn_b": 0.3}],
			[44, {"lean": -0.35, "ua_f": 2.8, "la_f": 0.2, "ua_b": 2.8, "la_b": 0.2}], [62, _idle()]],
		"events": [{"at": 12, "type": "rage", "dur": 8.0}]})

	# --- 29 Boost spark -------------------------------------------------
	_mk({"id": "boost_spark", "name": "Boost Spark", "short": "BOOST", "desc": "Charges your partner's next hit.",
		"total": 42, "tags": ["buff", "team"],
		"kf": [[0, {"lean": 0.1, "ua_f": 1.0, "la_f": 1.6, "ua_b": 1.0, "la_b": 1.6}],
			[10, {"lean": -0.1, "ua_f": 1.57, "la_f": 0.0, "ua_b": 2.4, "la_b": 0.2, "th_f": 0.4, "kn_f": 0.4}],
			[30, _idle()]],
		"events": [{"at": 10, "type": "boost"}]})

	# --- 30 Pillar smash ------------------------------------------------
	_mk({"id": "pillar_smash", "name": "Pillar Smash", "short": "PILLAR", "desc": "Overhead smash. Spikes enemies, launches crates.",
		"total": 56,
		"kf": [[0, {"lean": -0.3, "ua_f": 3.0, "la_f": 0.1, "ua_b": 2.9, "la_b": 0.1, "th_f": 0.3, "kn_f": 0.5, "th_b": -0.3, "kn_b": 0.5}],
			[20, {"lean": -0.5, "ua_f": 3.2, "la_f": 0.0, "ua_b": 3.1, "la_b": 0.0}],
			[22, {"lean": 0.9, "ua_f": 1.0, "la_f": 0.1, "ua_b": 0.9, "la_b": 0.1, "th_f": 0.9, "kn_f": 0.6, "th_b": -0.7, "kn_b": 0.5}],
			[44, _idle()]],
		"events": [{"at": 22, "type": "ring", "radius": 110.0, "sfx": "boom", "shake": 0.5}],
		"hits": [_hit(22, 4, Rect2(12, -125, 108, 128), 14, 34, Vector2(170, 430), {"kind": "spike", "stop": 8, "shake": 0.5, "prop_power": 2.2, "punch": 0.04})]})


static func _build_enemy() -> void:
	# thug: telegraphed punch
	_mk({"id": "e_punch", "name": "Punch", "enemy": true, "tele": true, "total": 44, "color": RED,
		"kf": [[0, {"lean": -0.2, "ua_f": -0.5, "la_f": 1.4, "th_f": 0.4, "kn_f": 0.6}],
			[16, {"lean": 0.5, "ua_f": 1.55, "la_f": 0.0, "th_f": 0.8, "kn_f": 0.3, "th_b": -0.7}],
			[28, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 15, "type": "vel", "vx": 120.0}],
		"hits": [_hit(16, 4, Rect2(8, -82, 58, 32), 8, 16, Vector2(180, 0), {"stop": 3, "height": "high"})]})
	_mk({"id": "e_double", "name": "Double Punch", "enemy": true, "tele": true, "total": 56, "color": RED,
		"kf": [[0, {"lean": -0.2, "ua_f": -0.5, "la_f": 1.4}],
			[14, {"lean": 0.5, "ua_f": 1.55, "la_f": 0.0, "th_f": 0.8, "kn_f": 0.3, "th_b": -0.7}],
			[24, {"lean": 0.5, "ua_b": 1.55, "la_b": 0.0, "ua_f": 0.3, "la_f": 1.8}],
			[40, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 13, "type": "vel", "vx": 100.0}, {"at": 23, "type": "vel", "vx": 100.0}],
		"hits": [_hit(14, 3, Rect2(8, -82, 58, 32), 6, 14, Vector2(100, 0), {"stop": 3, "height": "high"}),
			_hit(24, 4, Rect2(8, -82, 62, 32), 8, 22, Vector2(300, -220), {"kind": "launch", "stop": 4})]})
	# biker: charge
	_mk({"id": "e_charge", "name": "Charge", "enemy": true, "tele": true, "total": 74, "color": RED,
		"kf": [[0, {"lean": 0.4, "th_f": 0.8, "kn_f": 1.4, "th_b": -0.6, "kn_b": 1.4, "ua_f": 0.5, "la_f": 1.6}],
			[30, {"lean": 0.9, "th_f": 1.0, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.3, "ua_f": 1.2, "la_f": 0.3, "ua_b": 1.0}],
			[58, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 30, "type": "ghost"}, {"at": 36, "type": "ghost"}, {"at": 42, "type": "ghost"}, {"at": 48, "type": "ghost"}],
		"drive": [{"from": 30, "to": 52, "vx": 680.0}],
		"hits": [_hit(30, 22, Rect2(-4, -74, 62, 74), 12, 28, Vector2(420, -330), {"kind": "launch", "stop": 5})]})
	# bottle thrower
	_mk({"id": "e_throw", "name": "Throw Bottle", "enemy": true, "tele": true, "total": 64, "color": RED,
		"kf": [[0, {"lean": -0.3, "ua_f": 2.6, "la_f": 1.0}], [24, {"lean": 0.3, "ua_f": 1.2, "la_f": 0.0}], [44, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"},
			{"at": 24, "type": "proj", "kind": "bottle", "pos": Vector2(30, -88), "aim": true, "dmg": 8.0, "stun": 20,
				"kb": Vector2(160, -200), "life": 3.0, "radius": 10.0, "color": Color(1.6, 1.8, 0.6), "sfx": "throw"}]})
	# boss attacks
	_mk({"id": "boss_slam", "name": "Ground Slam", "enemy": true, "tele": true, "total": 100, "color": RED,
		"kf": [[0, {"lean": -0.5, "ua_f": 3.0, "la_f": 0.1, "ua_b": 3.0, "la_b": 0.1, "th_f": 0.3, "kn_f": 0.5}],
			[40, {"lean": -0.6, "ua_f": 3.2, "la_f": 0.0, "ua_b": 3.2}],
			[42, {"lean": 0.9, "ua_f": 0.8, "la_f": 0.1, "ua_b": 0.8, "th_f": 0.9, "kn_f": 0.5, "th_b": -0.8, "kn_b": 0.6}],
			[70, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 42, "type": "ring", "radius": 230.0, "sfx": "boom", "shake": 0.7}],
		"hits": [_hit(42, 3, Rect2(-170, -50, 340, 52), 16, 30, Vector2(320, -520), {"radial": true, "kind": "launch", "stop": 8, "shake": 0.5, "height": "low"})]})
	_mk({"id": "boss_swing", "name": "Wide Swing", "enemy": true, "tele": true, "total": 70, "color": RED,
		"kf": [[0, {"lean": -0.5, "ua_f": -1.2, "la_f": 0.4}],
			[26, {"lean": 0.7, "ua_f": 1.57, "la_f": 0.0, "th_f": 0.9, "kn_f": 0.3, "th_b": -0.8}], [50, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 25, "type": "vel", "vx": 220.0}],
		"hits": [_hit(26, 5, Rect2(10, -115, 120, 70), 13, 28, Vector2(480, -140), {"kind": "launch", "stop": 6, "shake": 0.35, "height": "high"})]})
	_mk({"id": "boss_charge", "name": "Bull Rush", "enemy": true, "tele": true, "total": 110, "color": RED,
		"kf": [[0, {"lean": 0.5, "th_f": 0.8, "kn_f": 1.5, "th_b": -0.6, "kn_b": 1.5}],
			[34, {"lean": 1.0, "th_f": 1.0, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.3, "ua_f": 1.4, "la_f": 0.2, "ua_b": 1.2}],
			[78, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 34, "type": "ghost"}, {"at": 42, "type": "ghost"}, {"at": 50, "type": "ghost"}, {"at": 58, "type": "ghost"}],
		"drive": [{"from": 34, "to": 68, "vx": 560.0}],
		"hits": [_hit(34, 34, Rect2(-10, -120, 100, 120), 14, 30, Vector2(520, -420), {"kind": "launch", "stop": 6})]})
	_mk({"id": "boss_summon", "name": "Call Backup", "enemy": true, "tele": true, "total": 90, "color": RED,
		"kf": [[0, {"lean": -0.3, "ua_f": 2.8, "la_f": 0.2, "ua_b": 2.8, "la_b": 0.2}], [60, PoseLib.idle_enemy(0.0)]],
		"events": [{"at": 0, "type": "tele"}, {"at": 34, "type": "summon", "count": 2}]})


## Moves that set targets on fire (seconds). Burning targets take +30% damage from everything, so these are
## the setup half of a synergy; the rest of the kit can pay it off.
## Elemental moves (seconds of status). Fire burns (+30 % damage taken, damage over time), shock arcs to a neighbour
## when a shocked target is hit, frost slows and freezes after three chilling hits. Not only Magic: basic and weapon
## moves carry elements too (and the Infusion level-up card puts an element on every attack).
const ELEMENTS := {
	"fireball": ["ignite", 3.0], "rising_dragon": ["ignite", 2.5], "overhead_smash": ["ignite", 2.0], "quake_line": ["ignite", 3.0],
	"haymaker": ["ignite", 2.0], "thrust_lunge": ["ignite", 2.0],
	"spark_shot": ["shock", 3.0], "arcane_beam": ["shock", 3.5], "riposte_step": ["shock", 3.0], "sky_launcher": ["shock", 3.0],
	"popup_kick": ["shock", 2.5], "teleport_strike": ["shock", 3.0], "dash_punch": ["shock", 2.0],
	"ground_wave": ["frost", 3.0], "spread_shot": ["frost", 2.5], "boomerang": ["frost", 2.5], "wind_slash": ["frost", 2.5],
	"whirlwind_haul": ["frost", 2.5], "low_cut": ["frost", 2.5], "side_sweep": ["frost", 2.0],
}
const ELEMENT_WORD := {"ignite": "Ignites.", "shock": "Shocks.", "frost": "Chills."}


static func _apply_status() -> void:
	for id in ELEMENTS:
		var m: MoveData = _db.get(id)
		if m == null:
			continue
		var key: String = ELEMENTS[id][0]
		var secs: float = ELEMENTS[id][1]
		for h in m.hits:
			h[key] = secs
		for e in m.events:
			if String(e.get("type", "")) == "proj":
				e[key] = secs
		var word: String = ELEMENT_WORD[key]
		if not m.desc.contains(word):
			m.desc += " " + word


## Clarity pass: a hit window under 6 frames (about a tenth of a second) is too short to see or read. Stretch every
## melee hit window to at least 6 frames (each target is still hit once) and make sure the move outlasts it.
static func _lengthen_short_hits() -> void:
	for id in _db:
		var m: MoveData = _db[id]
		if m.enemy:
			continue
		for h in m.hits:
			if bool(h.get("grab", false)) or int(h["dur"]) >= 6 or m.hits.size() > 3:
				continue
			h["dur"] = 6
			m.total = maxi(m.total, int(h["at"]) + 6 + 8)
