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
var aiming := false  ## holding a grabbed enemy: steer with the stick, press a button to throw that way
var empowered := false  ## LT held when the move started and meter was spent: +30 % damage, +20 % knockback, +25 % hitbox
var _aim_t := 0
var held_btn := -1

var _hit_done: Dictionary = {}
var _ev_done: Dictionary = {}
var _kf_idx := -1
var _hold_frames := 0
var _wait_frames := 0
var _tilt := 0.0
var _spun := false
var _kf_air := false
var _spd_acc := 0.0


func _init(a: Actor = null) -> void:
	actor = a


func start(m: MoveData, btn := -1) -> void:
	move = m
	frame = 0
	active = true
	if grabbed != null and is_instance_valid(grabbed) and grabbed.has_method("release"):
		grabbed.release()  # never leave a grabbed enemy stuck when a new move starts
	grabbed = null
	aiming = false
	empowered = false
	hit_connected = false
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
	if aiming:
		_aim_t += 1
		if grabbed == null or not is_instance_valid(grabbed):
			aiming = false
		elif _aim_pressed() or _aim_t > 150:
			_throw_aimed()
			aiming = false
		else:
			return  # hold the grab until the throw button is pressed
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
	aiming = false
	actor.figure.rot = 0.0
	actor.figure.modulate = Color.WHITE
	actor.figure.follow_speed = 36.0
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
	var air := not actor.is_on_floor()
	if idx >= 0 and (idx != _kf_idx or air != _kf_air):
		_kf_idx = idx
		_kf_air = air
		actor.figure.set_target(actor.adapt_pose(move.kf[idx][1], air))


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
			if String(e["name"]) == "whoosh":
				var top := 0.0
				for hh: Dictionary in move.hits:
					top = maxf(top, float(hh["dmg"]))
				Sfx.swing(top * a.dmg_mult())  # bigger swings sound lower
			else:
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
				if a is Fighter:
					aiming = true  # players choose the direction, then press the button again
					_aim_t = 0
				else:
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
		"well":
			var gz := GravityZone.new()
			gz.owner_actor = a
			gz.team = a.team
			gz.col = a.figure.color
			gz.radius = float(e["radius"])
			gz.life = float(e["life"])
			gz.global_position = a.global_position + Vector2(float(a.facing) * float(e["dist"]), -40.0)
			parent.add_child(gz)
		"rider":
			# every super helps the partner: a damage buff and a little healing when they are near
			var rp := Coop.partner_of(a)
			if rp != null and rp.is_alive() and rp.state != "downed" and rp.global_position.distance_to(a.global_position) < 520.0:
				rp.add_buff("dmg", 8.0)
				rp.heal(15.0)
				Fx.ring(parent, rp.global_position + Vector2(0, -45), Color(2.0, 1.7, 1.9), 90.0, 0.4)
				Fx.number(parent, rp.global_position + Vector2(0, -110), "TEAM BOOST", Color(2.0, 1.7, 1.9), 22)
		"rage":
			a.add_buff("rage", float(e["dur"]))
			Fx.ring(parent, a.global_position + Vector2(0, -45), Color(2.2, 0.3, 0.2), 120.0, 0.4)
			Fx.number(parent, a.global_position + Vector2(0, -110), "RAGE!", Color(2.2, 0.4, 0.3), 28)
			Sfx.play("buff", 0.7)
			Juice.shake(0.3)
		"pillar":
			Barrier.spawn(parent, a.global_position + Vector2(a.facing * float(e["dx"]), 0.0), float(e["life"]), a.team)
		"ward":
			# shield bubble on the partner (if close) or on yourself: absorbs one hit
			var pw := Coop.partner_of(a)
			var wt: Actor = a
			if pw != null and pw.is_alive() and pw.global_position.distance_to(a.global_position) < 420.0:
				wt = pw
			wt.shield_hits += 1
			Fx.ring(parent, wt.global_position + Vector2(0, -45), a.figure.color, 80.0, 0.35)
			Fx.beam(parent, a.global_position + Vector2(0, -60), wt.global_position + Vector2(0, -60), a.figure.color, 0.3)
			Fx.number(parent, wt.global_position + Vector2(0, -110), "WARDED", Color(1.9, 1.9, 2.2), 22)
			Sfx.play("buff", 1.2)
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
	if empowered:
		box = Rect2(box.position.x * 1.1, box.position.y - box.size.y * 0.125, box.size.x * 1.25, box.size.y * 1.25)
	if actor.facing >= 0:
		return Rect2(p.x + box.position.x, p.y + box.position.y, box.size.x, box.size.y)
	return Rect2(p.x - box.position.x - box.size.x, p.y + box.position.y, box.size.x, box.size.y)


func _hits() -> void:
	var swoosh := false
	for h2 in move.hits:
		if frame >= int(h2["at"]) and frame < int(h2["at"]) + int(h2["dur"]):  # a swoosh exists only while a hit is active
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
		var crects: Array = _contact_rects() if not bool(h.get("radial", false)) else []
		var all_r := rect
		for cr: Rect2 in crects:
			all_r = all_r.merge(cr)
		actor.debug_hit_rect = all_r
		if actor.team == "player":
			# batting thrown bottles and enemy shots back: any active swing, weapon or swoosh that touches one reflects it
			for pr in actor.get_tree().get_nodes_in_group("projectiles"):
				if not is_instance_valid(pr) or pr.team == actor.team or pr.reflected:
					continue
				var pr_rect: Rect2 = pr._rect()
				if rect.intersects(pr_rect) or crects.any(func(cr: Rect2) -> bool: return cr.intersects(pr_rect)):
					pr.reflect_by(actor)
					actor.freeze = maxi(actor.freeze, 3)
		var targets: Array = actor.hit_targets()
		if bool(h.get("partner_safe", false)):
			# Home Run: the partner can be batted too, even with friendly fire off (no damage to them)
			var pp := Coop.partner_of(actor)
			if pp != null and pp.is_targetable() and not (pp in targets):
				targets.append(pp)
		for t in targets:
			var key := "%d:%d" % [i, t.get_instance_id()]
			if _hit_done.has(key):
				continue
			var hurt: Rect2 = t.get_hurt_rect()
			var src := Rect2()
			for cr: Rect2 in crects:  # the swoosh, weapon head or blade: impacts come from there
				if cr.intersects(hurt):
					src = cr
					break
			if src.has_area():
				_hit_done[key] = true
				_connect(h, t, src)
			elif rect.intersects(hurt):
				_hit_done[key] = true
				_connect(h, t, rect)


const KB_PLAYER := 1.5  ## player knockback multiplier: enemies reach the partner for team combos
const KB_EMPOWERED := 0.8  ## empowered moves keep the target close (personal combo starter)


func _connect(h: Dictionary, t: Node, rect: Rect2) -> void:
	var a := actor
	if h.get("grab", false):
		if t.has_method("can_be_grabbed") and t.can_be_grabbed() and grabbed == null:
			t.grab(a)
			grabbed = t
			hit_connected = true
			Sfx.impact(8.0)
			Fx.impact(a.get_parent(), rect.get_center(), a.figure.color, 0.5)
		return
	var info := HitInfo.new()
	info.attacker = a
	info.team = a.team
	info.dmg = float(h["dmg"]) * a.dmg_mult() * a.upgrade_mult(move.id, "dmg") * (1.3 if empowered else 1.0)
	if a.team == "enemy":
		info.dmg *= Coop.enemy_dmg_mult
	info.stun = int(h["stun"]) + (3 if a.team == "player" else 0)  # a little extra hitstun: solo chains become possible
	info.kind = String(h["kind"])
	info.stop = int(h["stop"]) + (4 if float(h["dmg"]) >= 18.0 else (2 if float(h["dmg"]) >= 9.0 else 1))
	info.low = bool(h["low"])
	info.height = String(h.get("height", "low" if info.low else "mid"))
	info.guard_break = bool(h.get("guard_break", false))
	if move.hold and _hold_frames > 0:
		info.dmg *= 1.0 + 0.8 * minf(float(_hold_frames), 60.0) / 60.0  # charged moves hit harder
	info.shake = float(h["shake"])
	info.punch = float(h.get("punch", 0.0))
	info.prop_power = float(h.get("prop_power", 1.0))
	info.wallbounce = bool(h.get("wallbounce", false))
	info.heal_self = float(h.get("heal_self", 0.0))
	info.ignite = float(h.get("ignite", 0.0))
	info.shock = float(h.get("shock", 0.0))
	info.frost = float(h.get("frost", 0.0))
	info.color = h.get("color", a.figure.color)
	if a.team == "enemy" and info.height == "high":
		info.color = Color(2.4, 2.0, 0.3)  # high attacks spark amber
	info.friendly = (t is Actor and (t as Actor).team == a.team)
	if bool(h.get("partner_safe", false)) and info.friendly:
		info.dmg = 0.0  # a partner launch never hurts the partner
		info.no_combo = true
	info.pos = rect.get_center().clamp(t.get_hurt_rect().position, t.get_hurt_rect().end)
	var kb: Vector2 = (h["kb"] as Vector2) * a.upgrade_mult(move.id, "kb")
	if a.team == "player":
		# Normal moves hit hard enough to send an enemy across to the partner (team combos); an empowered move is a
		# personal combo starter instead: the target barely leaves the attacker.
		var fx := KB_EMPOWERED if empowered else KB_PLAYER
		kb = Vector2(kb.x * fx, kb.y * (1.0 + (fx - 1.0) * 0.4) if kb.y < 0.0 else kb.y)
	if info.friendly and not bool(h.get("partner_safe", false)):
		# Player-vs-player: no damage or effects, only a light stagger that interrupts the other player.
		info.dmg = 0.0
		info.no_combo = true
		info.kind = "normal"
		info.stun = 10
		info.stop = 3
		info.shake = 0.0
		info.punch = 0.0
		info.ignite = 0.0
		info.shock = 0.0
		info.frost = 0.0
		info.heal_self = 0.0
		info.wallbounce = false
		info.guard_break = false
		kb = Vector2(clampf(kb.x, -140.0, 140.0), 0.0)
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


## World rects that actually strike while a hit is active, so hits and impact effects come from what the player
## sees: the weapon head / blade (weapon and adaptive moves) and every limb tip that is drawing a swoosh.
## Only for players; enemies keep their authored boxes.
func _contact_rects() -> Array:
	var out: Array = []
	var f := actor.figure
	if f == null or actor.team != "player":
		return out
	if f.weapon in ["sword", "hammer"] and move.tier in ["weapon", "adaptive"]:
		var tip: Vector2 = f.to_global(f.weapon_tip)
		if f.weapon == "hammer":
			var s := 46.0 * f.weapon_scale
			out.append(Rect2(tip - Vector2(s, s) * 0.5, Vector2(s, s)))
		else:
			var r := Rect2(f.to_global(f.hand_f_pos), Vector2.ZERO).expand(tip)
			out.append(r.grow_individual(0.0, maxf(0.0, 11.0 - r.size.y * 0.5), 0.0, maxf(0.0, 11.0 - r.size.y * 0.5)))
	out.append_array(f.swoosh_rects())
	return out


## Any fresh button press throws the grabbed enemy (the stick picked the direction).
func _aim_pressed() -> bool:
	var f := actor as Fighter
	if f == null:
		return true
	for b in [PlayerInput.Btn.X, PlayerInput.Btn.Y, PlayerInput.Btn.B, PlayerInput.Btn.LB, PlayerInput.Btn.INTERACT]:
		if f.input.pressed(b):
			return true
	return false


## Direction chosen with the stick: forward (default), back, up (launcher for juggles) or down (slam).
func aim_vector() -> Vector2:
	var f := actor as Fighter
	if f == null:
		return Vector2(float(actor.facing) * 600.0, -300.0)
	if grabbed is Fighter:
		return f.ally_throw_dir() * Fighter.THROW_SPEED_ALLY
	return f.throw_dir() * Fighter.THROW_SPEED_ENEMY


func _throw_aimed() -> void:
	if grabbed == null or not is_instance_valid(grabbed) or not grabbed.has_method("thrown"):
		return
	var v := aim_vector()
	grabbed.thrown(v, actor)
	Sfx.play("throw")
	Fx.dust(actor.get_parent(), actor.global_position + Vector2(actor.facing * 30.0, -40.0), 6)
	grabbed = null
