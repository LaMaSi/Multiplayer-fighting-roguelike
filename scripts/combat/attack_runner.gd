class_name AttackRunner
extends RefCounted
## Plays a MoveData on an Actor: pose keyframes, events, spin/drive and hitbox checks.
## tick() is called once per (non-frozen) physics frame.

var actor: Actor
var move: MoveData = null
var frame := 0
var active := false
var hit_connected := false
var grabbed: Node = null
var held_btn := -1

var _hit_done: Dictionary = {}
var _ev_done: Dictionary = {}
var _kf_idx := -1
var _hold_frames := 0
var _wait_frames := 0
var _tilt := 0.0
var _spun := false
var _spd_acc := 0.0


func _init(a: Actor = null) -> void:
	actor = a


func start(m: MoveData, btn := -1) -> void:
	move = m
	frame = 0
	active = true
	hit_connected = false
	grabbed = null
	held_btn = btn
	_hit_done.clear()
	_ev_done.clear()
	_kf_idx = -1
	_hold_frames = 0
	_wait_frames = 0
	_tilt = 0.0
	_spun = false
	_spd_acc = 0.0
	actor.figure.follow_speed = 52.0
	actor.figure.zeta = 0.36  # under-damped spring: strong overshoot + settle
	actor.squash = Vector2(0.76, 1.26)  # anticipation: coil up before the strike


func can_cancel() -> bool:
	if not active or not hit_connected:
		return false
	var from := move.cancel_from if move.cancel_from >= 0 else move.last_hit_end()
	return frame >= from


func can_chain() -> bool:
	return active and move.chain_next != "" and frame >= move.chain_from


func tick() -> void:
	if not active:
		return
	_tick_once()
	if active:
		var spd := actor.upgrade_mult(move.id, "spd")
		if spd > 1.0:
			_spd_acc += spd - 1.0
			if _spd_acc >= 1.0:
				_spd_acc -= 1.0
				_tick_once()


func _tick_once() -> void:
	_keyframes()
	_events()
	_spin_drive()
	_hits()
	# advance (or hold)
	if move.hold and frame == move.hold_frame and held_btn >= 0 and actor.is_btn_held(held_btn) and _hold_frames < move.hold_max:
		_hold_frames += 1
	elif move.land_wait >= 0 and frame == move.land_wait and not actor.is_on_floor() and _wait_frames < 150:
		_wait_frames += 1
	else:
		frame += 1
	if frame >= move.total:
		finish()


func finish() -> void:
	if not active:
		return
	active = false
	_cleanup()
	actor.on_attack_end(move)


## Called when the actor gets interrupted by a hit.
func interrupt() -> void:
	if not active:
		return
	active = false
	_cleanup()


func _cleanup() -> void:
	actor.figure.rot = 0.0
	actor.figure.modulate = Color.WHITE
	actor.figure.follow_speed = 28.0
	actor.figure.zeta = 1.0
	actor.figure.trail_on = false
	actor.guard_t = 0
	actor.parry_t = 0
	if grabbed != null and is_instance_valid(grabbed) and grabbed.has_method("release"):
		grabbed.release()
	grabbed = null


# ------------------------------------------------------------------ pose / motion

func _keyframes() -> void:
	var idx := -1
	for i in move.kf.size():
		if int(move.kf[i][0]) <= frame:
			idx = i
	if idx != _kf_idx and idx >= 0:
		_kf_idx = idx
		actor.figure.set_target(move.kf[idx][1])


func _spin_drive() -> void:
	var fig := actor.figure
	if not move.spin.is_empty():
		var at: int = move.spin["at"]
		var dur: int = move.spin["dur"]
		if frame >= at and frame <= at + dur:
			fig.rot = float(frame - at) / float(dur) * float(move.spin["turns"]) * TAU
			_spun = true
		elif _spun:
			fig.rot = 0.0
			_spun = false
	elif _tilt != 0.0 or fig.rot != 0.0:
		fig.rot = lerpf(fig.rot, _tilt, 0.4)
	for d in move.drive:
		if frame >= int(d["from"]) and frame <= int(d["to"]):
			actor.velocity.x = float(d["vx"]) * actor.facing + actor.move_input_x * actor.run_speed * move.steer


# ------------------------------------------------------------------ events

func _events() -> void:
	for i in move.events.size():
		var e: Dictionary = move.events[i]
		if int(e["at"]) != frame or _ev_done.has(i):
			continue
		_ev_done[i] = true
		_do_event(e)


func _do_event(e: Dictionary) -> void:
	var a := actor
	var parent := a.get_parent()
	match String(e["type"]):
		"vel":
			a.velocity.x = float(e["vx"]) * a.facing
			if e.has("vy"):
				a.velocity.y = float(e["vy"])
		"sfx":
			Sfx.play(String(e["name"]))
		"ghost":
			Fx.afterimage(parent, a.figure, a.figure.color)
		"proj":
			Projectile.launch(a, e)
		"guard":
			a.guard_t = 99999
		"guard_off":
			a.guard_t = 0
		"parry":
			a.parry_t = int(e["dur"])
			Fx.ring(parent, a.global_position + Vector2(a.facing * 30, -50), Color(1.8, 1.8, 2.2), 50.0, 0.2)
		"reflect":
			a.reflect_t = int(e["dur"])
		"invuln":
			a.invuln = maxf(a.invuln, float(e["dur"]) / 60.0)
		"armor":
			a.armor_t = float(e["dur"]) / 60.0
		"tilt":
			_tilt = float(e["rot"])
		"vis":
			a.figure.modulate.a = 1.0 if bool(e["v"]) else 0.0
		"dive":
			a.velocity = Vector2(float(e["vx"]) * a.facing, float(e["vy"]))
			Sfx.play("whoosh", 0.7)
		"ring":
			Fx.ring(parent, a.global_position + Vector2(0, -6), a.figure.color, float(e["radius"]), 0.35)
			Fx.dust(parent, a.global_position, 14)
			if e.has("sfx"):
				Sfx.play(String(e["sfx"]))
			if e.has("shake"):
				Juice.shake(float(e["shake"]))
		"beam":
			var from := a.global_position + Vector2(a.facing * 25.0, -70.0)
			Fx.beam(parent, from, from + Vector2(a.facing * float(e["len"]), 0), a.figure.color, float(e["dur"]) / 60.0)
			if e.has("sfx"):
				Sfx.play(String(e["sfx"]))
		"tele":
			a.telegraph()
		"tp":
			_teleport()
		"summon":
			Coop.summon_requested.emit(a, int(e["count"]))
		"whiff_skip":
			if grabbed == null:
				frame = int(e["to"]) - 1
		"throw":
			if grabbed != null and is_instance_valid(grabbed) and grabbed.has_method("thrown"):
				grabbed.thrown(Vector2(float(e["vx"]) * a.facing, float(e["vy"])), a)
				Sfx.play("throw")
				grabbed = null
		"toss_grab":
			var p := Coop.partner_of(a)
			if p != null and p.can_be_grabbed() and absf(p.global_position.x - a.global_position.x) < 130.0 and absf(p.global_position.y - a.global_position.y) < 60.0:
				p.grab(a)
				grabbed = p
		"toss":
			if grabbed is Fighter:
				(grabbed as Fighter).begin_toss(a.facing, a)
				Sfx.play("throw", 0.8)
				grabbed = null
		"heal_pulse":
			Fx.ring(parent, a.global_position + Vector2(0, -50), Color(2.0, 1.7, 1.9), float(e["radius"]), 0.4)
			Sfx.play("heal")
			a.heal(float(e["amount"]) * 0.5)
			var p2 := Coop.partner_of(a)
			if p2 != null and p2.is_alive() and p2.global_position.distance_to(a.global_position) < float(e["radius"]) + 40.0:
				p2.heal(float(e["amount"]))
				Fx.number(parent, p2.global_position + Vector2(0, -100), "+%d" % int(e["amount"]), Color(2.0, 1.7, 1.9), 24)
		"rage":
			a.add_buff("rage", float(e["dur"]))
			Fx.ring(parent, a.global_position + Vector2(0, -45), Color(2.2, 0.3, 0.2), 120.0, 0.4)
			Fx.number(parent, a.global_position + Vector2(0, -110), "RAGE!", Color(2.2, 0.4, 0.3), 28)
			Sfx.play("buff", 0.7)
			Juice.shake(0.3)
		"boost":
			var p3 := Coop.partner_of(a)
			var tgt: Actor = p3 if (p3 != null and p3.is_alive()) else a
			tgt.add_buff("boost", 10.0)
			Fx.beam(parent, a.global_position + Vector2(0, -60), tgt.global_position + Vector2(0, -60), Color(2.0, 1.8, 0.4), 0.35)
			Fx.number(parent, tgt.global_position + Vector2(0, -110), "CHARGED!", Color(2.0, 1.8, 0.4), 24)
			Sfx.play("buff")


func _teleport() -> void:
	var a := actor
	var parent := a.get_parent()
	Fx.dust(parent, a.global_position, 10, Color(1.5, 1.2, 2.0, 0.7))
	var tgt := a.nearest_target(520.0)
	if tgt != null:
		var dir := signf(tgt.global_position.x - a.global_position.x)
		if dir == 0.0:
			dir = float(a.facing)
		a.global_position.x = tgt.global_position.x + dir * 55.0
		if tgt.is_on_floor():
			a.global_position.y = tgt.global_position.y
		a.facing = -int(dir)
	else:
		a.global_position.x += a.facing * 220.0
	a.global_position.x = clampf(a.global_position.x, Coop.bounds.position.x + 30.0, Coop.bounds.end.x - 30.0)
	a.velocity = Vector2.ZERO
	Sfx.play("tp")
	Fx.dust(parent, a.global_position, 10, Color(1.5, 1.2, 2.0, 0.7))
	Fx.ring(parent, a.global_position + Vector2(0, -40), a.figure.color, 60.0, 0.3)


# ------------------------------------------------------------------ hits

func world_rect(box: Rect2) -> Rect2:
	var p := actor.global_position
	if actor.facing >= 0:
		return Rect2(p.x + box.position.x, p.y + box.position.y, box.size.x, box.size.y)
	return Rect2(p.x - box.position.x - box.size.x, p.y + box.position.y, box.size.x, box.size.y)


func _hits() -> void:
	var swoosh := false
	for h2 in move.hits:
		if frame >= int(h2["at"]) - 1 and frame < int(h2["at"]) + int(h2["dur"]) + 4:
			swoosh = true
	actor.figure.trail_on = swoosh
	for i in move.hits.size():
		var h: Dictionary = move.hits[i]
		var at: int = h["at"]
		if frame == at and not _ev_done.has(1000 + i):
			# strike: stretch the body along the attack, ghost on heavy blows
			_ev_done[1000 + i] = true
			var heavy := float(h["dmg"]) >= 14.0
			actor.squash = Vector2(1.6, 0.66) if heavy else Vector2(1.35, 0.78)
			if float(h["dmg"]) >= 7.0:
				Fx.afterimage(actor.get_parent(), actor.figure, actor.figure.color)
		if frame < at or frame >= at + int(h["dur"]):
			continue
		var rect := world_rect(h["box"])
		actor.debug_hit_rect = rect
		for t in actor.hit_targets():
			var key := "%d:%d" % [i, t.get_instance_id()]
			if _hit_done.has(key):
				continue
			if rect.intersects(t.get_hurt_rect()):
				_hit_done[key] = true
				_connect(h, t, rect)


func _connect(h: Dictionary, t: Node, rect: Rect2) -> void:
	var a := actor
	if h.get("grab", false):
		if t.has_method("can_be_grabbed") and t.can_be_grabbed() and grabbed == null:
			t.grab(a)
			grabbed = t
			hit_connected = true
			Sfx.play("hit2", 0.8)
			Fx.impact(a.get_parent(), rect.get_center(), a.figure.color, 0.5)
		return
	var info := HitInfo.new()
	info.attacker = a
	info.team = a.team
	info.dmg = float(h["dmg"]) * a.dmg_mult() * a.upgrade_mult(move.id, "dmg")
	if a.team == "enemy":
		info.dmg *= Coop.enemy_dmg_mult
	info.stun = int(h["stun"])
	info.kind = String(h["kind"])
	info.stop = int(h["stop"]) + (4 if float(h["dmg"]) >= 18.0 else (2 if float(h["dmg"]) >= 9.0 else 1))
	info.low = bool(h["low"])
	info.height = String(h.get("height", "low" if info.low else "mid"))
	info.shake = float(h["shake"])
	info.punch = float(h.get("punch", 0.0))
	info.prop_power = float(h.get("prop_power", 1.0))
	info.wallbounce = bool(h.get("wallbounce", false))
	info.heal_self = float(h.get("heal_self", 0.0))
	info.color = h.get("color", a.figure.color)
	if a.team == "enemy" and info.height == "high":
		info.color = Color(2.4, 2.0, 0.3)  # high attacks spark amber
	info.friendly = (t is Actor and (t as Actor).team == a.team)
	info.pos = rect.get_center().clamp(t.get_hurt_rect().position, t.get_hurt_rect().end)
	var kb: Vector2 = (h["kb"] as Vector2) * a.upgrade_mult(move.id, "kb")
	if bool(h["radial"]):
		var dx: float = t.get_hurt_rect().get_center().x - a.global_position.x
		var s := signf(dx) if absf(dx) > 4.0 else float(a.facing)
		info.kb = Vector2(s * absf(kb.x), kb.y)
	else:
		info.kb = Vector2(kb.x * a.facing, kb.y)
	if t.take_hit(info):
		hit_connected = true
		a.freeze = maxi(a.freeze, info.stop)
		if info.heal_self > 0.0:
			a.heal(info.heal_self)
			Fx.number(a.get_parent(), a.global_position + Vector2(0, -105), "+%d" % int(info.heal_self), Color(2.0, 1.7, 1.9), 18)
		a.on_hit_landed(info, t)
