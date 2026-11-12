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
var _charge_fx: ChargeFx = null
var _released := false
var _whip: WhipFx = null  ## the tether of a Pull Hook
var last_hit_dmg := 0.0  ## damage and knockback of the last hit this runner sent, before the target's own modifiers (for tests and tuning)
var last_hit_kb := 0.0
var _wait_frames := 0
var _tilt := 0.0
var _spun := false
var _kf_air := false
var _spd_acc := 0.0
var _reel_t := 0  ## Grapple Dash: frames left of being reeled towards the hooked enemy
var _reel_target: Actor = null


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
	_charge_fx = null
	_released = false
	_wait_frames = 0
	_tilt = 0.0
	_spun = false
	_spd_acc = 0.0
	_reel_t = 0
	_reel_target = null
	actor.figure.follow_speed = 52.0
	actor.figure.zeta = 0.36  # under-damped spring: strong overshoot + settle
	# Anticipation: coil up before the strike. Heavier moves coil deeper (and read longer), light jabs barely dip.
	var w := _weight(m)
	actor.squash = Vector2(lerpf(0.88, 0.66, w), lerpf(1.1, 1.36, w))


## 0..1: how heavy a move feels, from its strongest hit (jab ~0, haymaker / super ~1). Drives anticipation depth,
## strike stretch, impact squash and follow-through so big moves look and feel big.
func _weight(m: MoveData) -> float:
	var top := 0.0
	for h in m.hits:
		top = maxf(top, float(h["dmg"]))
	return clampf((top - 4.0) / 20.0, 0.0, 1.0)


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
		if move.is_chargeable():
			_charge_tick()
	elif move.land_wait >= 0 and frame == move.land_wait and not actor.is_on_floor() and _wait_frames < 150:
		_wait_frames += 1
	else:
		if move.is_chargeable() and _hold_frames > 0 and not _released and frame == move.hold_frame:
			_released = true
			_release_fx()
		frame += 1
	if frame >= move.total:
		finish()


## True while the button is being held at the charge point.
func charging() -> bool:
	return active and move != null and move.is_chargeable() and _hold_frames > 0 and frame == move.hold_frame and held_btn >= 0 and actor.is_btn_held(held_btn) and _hold_frames < move.hold_max + 1


## Charge progress, 0 (tap) to 1 (full, after charge_max frames).
func charge_t() -> float:
	if move == null or not move.is_chargeable():
		return 0.0
	return clampf(float(_hold_frames) / float(move.charge_max), 0.0, 1.0)


func charge_dmg_mult() -> float:
	return 1.0 + (move.charge_dmg * charge_t() if move != null and move.is_chargeable() else 0.0)


func charge_kb_mult() -> float:
	return 1.0 + (move.charge_kb * charge_t() if move != null and move.is_chargeable() else 0.0)


## Scale for the move's own movement (lunge, drive, jump): 1 for a tap, up to 1 + charge_move at full charge. The distance
## is front-loaded (ease-out): half a charge already gives three quarters of the extra distance, so a short hold is felt.
func charge_move_mult() -> float:
	if move == null or not move.is_chargeable():
		return 1.0
	var ct := charge_t()
	return 1.0 + move.charge_move * (1.0 - (1.0 - ct) * (1.0 - ct))


## A short press is just the move: the ring and the ticks only start after the button has been held this long.
const CHARGE_SHOW_FRAMES := 14


## Pitch and volume (db) of the release sound for a charge 0..1: the longer the charge, the lower and louder.
static func release_params(ct: float) -> Vector2:
	return Vector2(lerpf(1.45, 0.7, ct), lerpf(-9.0, 1.0, ct))


## Letting go of a held charge: a sound that grows with the charge, a shake and a burst of sparks in the player's colour.
func _release_fx() -> void:
	if _hold_frames < CHARGE_SHOW_FRAMES:
		return
	var ct := charge_t()
	var rp := release_params(ct)
	Sfx.play("release", rp.x, rp.y)
	Juice.shake(0.1 + 0.3 * ct)
	Fx.sparks(actor.get_parent(), actor.global_position + Vector2(0.0, -50.0), actor.figure.color, 6 + int(18.0 * ct))


func _charge_tick() -> void:
	if _hold_frames < CHARGE_SHOW_FRAMES:
		return
	if _charge_fx == null or not is_instance_valid(_charge_fx):
		_charge_fx = ChargeFx.new()
		_charge_fx.runner = self
		_charge_fx.actor = actor
		actor.add_child(_charge_fx)
	if (_hold_frames - CHARGE_SHOW_FRAMES) % 30 == 0:
		Sfx.play("buff", 0.7 + 0.8 * charge_t())  # a rising tick every half second


func finish() -> void:
	if not active:
		return
	active = false
	_cleanup()
	# follow-through: the body settles with a small rebound instead of snapping straight to idle
	actor.squash = Vector2(lerpf(1.04, 1.16, _weight(move)), lerpf(0.97, 0.88, _weight(move)))
	actor.on_attack_end(move)


## Called when the actor gets interrupted by a hit.
func interrupt() -> void:
	if not active:
		return
	active = false
	_cleanup()


func _cleanup() -> void:
	aiming = false
	if _charge_fx != null and is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null
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
	_follow_through(idx, air)


## Long end lag used to hold the strike pose until the next keyframe, which reads as unresponsive. After the last hit the
## pose now keeps moving: a short overshoot past the strike (follow-through), then a smooth settle into the next keyframe.
func _follow_through(idx: int, air: bool) -> void:
	if idx < 0 or idx + 1 >= move.kf.size() or move.hits.is_empty() or actor.figure == null:
		return
	var f0 := int(move.kf[idx][0])
	var f1 := int(move.kf[idx + 1][0])
	var start := maxi(f0, move.last_hit_end()) + 2
	if f1 - start < 6 or frame < start or frame >= f1:
		return
	var t := float(frame - start) / float(f1 - start)
	var k := t * t * (3.0 - 2.0 * t) - 0.12 * sin(PI * clampf(t * 1.6, 0.0, 1.0))
	var a: Dictionary = StickFigure.NEUTRAL.merged(actor.adapt_pose(move.kf[idx][1], air), true)  # full poses, so keys one side leaves out still blend
	var b: Dictionary = StickFigure.NEUTRAL.merged(actor.adapt_pose(move.kf[idx + 1][1], air), true)
	actor.figure.set_target(PoseLib.blend(a, b, k))


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
	if _reel_t > 0:
		_reel_t -= 1
		var ra := actor
		if _reel_target != null and is_instance_valid(_reel_target) and _reel_target.is_targetable():
			var rdx := _reel_target.global_position.x - ra.global_position.x
			if absf(rdx) > 52.0:
				ra.velocity.x = signf(rdx) * 1150.0
			else:
				ra.velocity.x = 0.0
				_reel_t = 0
		else:
			ra.velocity.x = float(ra.facing) * 800.0
		if _reel_t == 0:
			ra.velocity.x *= 0.3
	for d in move.drive:
		if frame >= int(d["from"]) and frame <= int(d["to"]):
			actor.velocity.x = float(d["vx"]) * actor.facing * charge_move_mult() + actor.move_input_x * actor.run_speed * move.steer


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
			# a charged lunge or jump covers more ground. Friction and gravity make distance grow with the SQUARE of the
			# launch speed, so the speed grows with its square root and the distance grows about as much as charge_move says
			var cm := charge_move_mult()
			a.velocity.x = float(e["vx"]) * a.facing * sqrt(cm)
			if e.has("vy"):
				a.velocity.y = float(e["vy"]) * sqrt(1.0 + (cm - 1.0) * 0.8)
		"sfx":
			if String(e["name"]) == "whoosh":
				var top := 0.0
				for hh: Dictionary in move.hits:
					top = maxf(top, float(hh["dmg"]))
				Sfx.swing(top * a.dmg_mult() * charge_dmg_mult())  # bigger swings sound lower, a charged one lowest
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
			var rk := 1.0 + (move.charge_range * charge_t() if move.charge_range > 0.0 else 0.0)  # the shockwave grows with the charge
			Fx.ring(parent, a.global_position + Vector2(0, -6), a.figure.color, float(e["radius"]) * rk, 0.35)
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
		"whip":
			# a tether from the hand out to the move's full reach, whether or not it hooks anything
			_whip = WhipFx.new()
			_whip.actor = a
			_whip.reach = float(e.get("reach", 325.0))
			parent.add_child(_whip)
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
		"reel":
			# Grapple Dash: a hook flies out and the user is yanked to the nearest enemy (a short dash when nothing is hooked)
			var rt := a.nearest_target(float(e.get("range", 460.0)))
			var from_p := a.global_position + Vector2(a.facing * 25.0, -70.0)
			if rt != null:
				a.facing = 1 if rt.global_position.x >= a.global_position.x else -1
				_reel_target = rt
				Fx.beam(parent, from_p, rt.global_position + Vector2(0, -60), a.figure.color, 0.25)
			else:
				_reel_target = null
				Fx.beam(parent, from_p, from_p + Vector2(a.facing * 220.0, 0), a.figure.color, 0.15)
			_reel_t = int(e.get("frames", 14))
			Sfx.play("throw", 1.2)
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
			Sfx.play("heal")  # Life Drain: the aura itself heals nothing, the healing comes from the damage it deals (see _connect)
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
				Coop.callout("TEAM BOOST", Color(2.0, 1.7, 1.9))
		"rage":
			a.add_buff("rage", float(e["dur"]))
			Fx.ring(parent, a.global_position + Vector2(0, -45), Color(2.2, 0.3, 0.2), 120.0, 0.4)
			Coop.callout("RAGE!", Color(2.2, 0.4, 0.3))
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
			Coop.callout("WARDED", Color(1.9, 1.9, 2.2))
			Sfx.play("buff", 1.2)
		"boost":
			var p3 := Coop.partner_of(a)
			var tgt: Actor = p3 if (p3 != null and p3.is_alive()) else a
			tgt.add_buff("boost", 10.0)
			Fx.beam(parent, a.global_position + Vector2(0, -60), tgt.global_position + Vector2(0, -60), Color(2.0, 1.8, 0.4), 0.35)
			Coop.callout("CHARGED!", Color(2.0, 1.8, 0.4))
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


## The hitbox of a hit, grown by the charge (charge_range) for moves that reach further when charged.
func _charged_box(h: Dictionary) -> Rect2:
	var b: Rect2 = h["box"]
	if move == null or move.charge_range <= 0.0 or charge_t() <= 0.0:
		return b
	var k := 1.0 + move.charge_range * charge_t()
	if bool(h.get("radial", false)):
		return Rect2(b.position.x * k, b.position.y, b.size.x * k, b.size.y)  # centred on the fighter: grows both ways
	return Rect2(b.position.x, b.position.y, b.size.x * k, b.size.y)  # forward hits grow forward


## How long a hit stays active: a charged lunge keeps hitting along its longer path.
func _hit_dur(h: Dictionary) -> int:
	var d := int(h["dur"])
	if move.charge_stretch:
		d = int(round(float(d) * charge_move_mult()))
	return d


func _hits() -> void:
	var swoosh := false
	for h2 in move.hits:
		if frame >= int(h2["at"]) and frame < int(h2["at"]) + _hit_dur(h2):  # a swoosh exists only while a hit is active
			swoosh = true
	actor.figure.trail_on = swoosh
	for i in move.hits.size():
		var h: Dictionary = move.hits[i]
		var at: int = h["at"]
		if frame == at - 1 and at > 0 and not _ev_done.has(2000 + i) and actor.team == "player" and float(h["dmg"]) >= 14.0 and (i == 0 or at - (int((move.hits[i - 1] as Dictionary)["at"]) + _hit_dur(move.hits[i - 1])) > 8):
			# pre-impact hold: heavy blows pause for one frame at the top of the swing, just before contact
			_ev_done[2000 + i] = true
			actor.freeze = maxi(actor.freeze, 1)
		if frame == at and not _ev_done.has(1000 + i):
			# strike: stretch the body along the attack, ghost on heavy blows
			_ev_done[1000 + i] = true
			var heavy := float(h["dmg"]) >= 14.0
			actor.squash = Vector2(1.6, 0.66) if heavy else Vector2(1.35, 0.78)
			if float(h["dmg"]) >= 7.0:
				Fx.afterimage(actor.get_parent(), actor.figure, actor.figure.color)
		if frame < at or frame >= at + _hit_dur(h):
			continue
		var rect := world_rect(_charged_box(h))
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


## True while one of the move's hits is active this frame (a swing that can connect right now).
func is_striking() -> bool:
	if not active or move == null:
		return false
	for h in move.hits:
		if not h.get("grab", false) and frame >= int(h["at"]) and frame < int(h["at"]) + int(h["dur"]):
			return true
	return false


## World rects of the hits that are active this frame (authored boxes plus weapon / limb contact rects).
func strike_rects() -> Array:
	var out: Array = []
	if not is_striking():
		return out
	for h in move.hits:
		if not h.get("grab", false) and frame >= int(h["at"]) and frame < int(h["at"]) + int(h["dur"]):
			out.append(world_rect(h["box"]))
	out.append_array(_contact_rects())
	return out


const KB_PLAYER := 1.9## player knockback multiplier: enemies reach the partner for team combos
const KB_EMPOWERED := 0.8  ## empowered moves keep the target close (personal combo starter)
const SEND_MIN := 680.0  ## slowest a sending hit throws its target (px/s): far enough that the partner need not stand close
const SEND_MAX := 1600.0


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
	# CLASH: two swings landing at the same moment. The player wins it: the enemy is staggered and its swing is cancelled.
	var clash := false
	if t is Actor and (t as Actor).team != a.team and (t as Actor).attack.is_striking():
		if a.team == "player":
			clash = true
		else:
			var mine := a.get_hurt_rect()
			for sr: Rect2 in (t as Actor).attack.strike_rects():
				if sr.intersects(mine):
					a.clash_stagger(t as Actor)
					(t as Actor).freeze = maxi((t as Actor).freeze, 5)
					return
	var info := HitInfo.new()
	info.attacker = a
	info.team = a.team
	info.clash = clash
	info.dmg = float(h["dmg"]) * a.dmg_mult() * a.upgrade_mult(move.id, "dmg") * (1.3 if empowered else 1.0)
	if a.team == "enemy":
		info.dmg *= Coop.enemy_dmg_mult
	info.stun = int(h["stun"]) + (3 if a.team == "player" else 0)  # a little extra hitstun: solo chains become possible
	info.kind = String(h["kind"])
	# hit-stop: the harder the blow the longer the world holds still on contact
	info.stop = maxi(Actor.MIN_HITSTOP, int(h["stop"]) + (6 if float(h["dmg"]) >= 18.0 else (3 if float(h["dmg"]) >= 9.0 else 2)))
	info.low = bool(h["low"])
	info.height = String(h.get("height", "low" if info.low else "mid"))
	info.guard_break = bool(h.get("guard_break", false))
	if move.is_chargeable() and _hold_frames > 0:
		info.dmg *= charge_dmg_mult()  # a charged move hits harder (and knocks back harder, below)
	info.shake = float(h["shake"])
	info.punch = float(h.get("punch", 0.0))
	info.prop_power = float(h.get("prop_power", 1.0))
	info.wallbounce = bool(h.get("wallbounce", false))
	info.pull_speed = float(h.get("pull_speed", 900.0))
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
	var sends: bool = a.team == "player" and h.has("ang")
	if sends:
		# The hit sends its target along the move's own angle (MoveDB.SEND). The authored knockback only sets how hard:
		# always hard enough to carry the target well away from the attacker, towards wherever the partner waits.
		var speed := clampf(Vector2(kb.x * KB_PLAYER, kb.y).length(), SEND_MIN, SEND_MAX)
		if h.has("speed"):
			speed = float(h["speed"]) * a.upgrade_mult(move.id, "kb")
		if empowered:
			speed *= 0.55  # an empowered move is a personal combo starter: the target stays near the attacker
		var lift_cap := 1000.0 if move.tags.has("launcher") else 880.0  # nothing rises much past a single jump
		if move.is_chargeable():
			speed *= charge_kb_mult()
			lift_cap *= 1.0 + move.charge_kb * charge_t()
		var ang := deg_to_rad(float(h["ang"]))
		kb = Vector2(cos(ang), -sin(ang)) * speed
		kb.y = maxf(kb.y, -lift_cap)
		info.sends = true
		info.ang = float(h["ang"])
		info.kind = "spike" if info.ang < -45.0 else "launch"
	elif a.team == "player":
		# Normal moves hit hard enough to send an enemy across to the partner (team combos); an empowered move is a
		# personal combo starter instead: the target barely leaves the attacker.
		var fx := KB_EMPOWERED if empowered else KB_PLAYER
		# Flights are sideways, not skyward: only launchers keep their full lift, and nothing rises past a single jump (~170 px).
		var lift := 1.0 if move.tags.has("launcher") else 0.6
		kb = Vector2(kb.x * fx, maxf(kb.y * lift, -780.0 * (1.0 + (move.charge_kb * charge_t() if move.is_chargeable() else 0.0))) if kb.y < 0.0 else kb.y)
		if move.is_chargeable():
			kb *= charge_kb_mult()
	# send direction: launches fly along one of the 8 basic directions; moves that do not send only nudge the target
	info.stun_mult = float(h.get("stun_mult", 1.0))
	if sends:
		info.ground_fx = "bounce"  # a spiked target rebounds off the floor: never a dead stop
	else:
		# hits without an angle (enemy moves, staggering jabs): the old 8 directions, or only a nudge
		info.dir = MoveDB.hit_dir(h)
		info.ground_fx = String(h.get("ground", MoveDB.default_ground(info.dir)))
		if info.dir >= 0 and info.kind in ["launch", "spike"]:
			kb = MoveDB.DIR_VECS[info.dir] * kb.length()
		elif info.dir < 0:
			kb = Vector2(clampf(kb.x, -40.0, 40.0), 0.0)
	if clash:
		info.sends = false
		# a clash is a stagger, not a launch: the enemy stays close, reeling, and the swing it started is gone
		info.kind = "normal"
		info.dmg *= 1.25
		info.stun = maxi(info.stun, 36)
		info.stop += 4
		kb = Vector2(clampf(kb.x, -90.0, 90.0), 0.0)
		info.dir = -1
		(t as Actor).armor_t = 0.0
	if info.friendly and not bool(h.get("partner_safe", false)):
		info.dir = -1
		info.sends = false
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
	last_hit_dmg = info.dmg
	last_hit_kb = info.kb.length()
	if t.take_hit(info):
		hit_connected = true
		a.freeze = maxi(a.freeze, info.stop)
		if info.kind == "pull" and _whip != null and is_instance_valid(_whip) and t is Node2D:
			_whip.hook(t as Node2D)  # the tether sticks to what it caught
		if move.is_chargeable() and charge_t() >= 0.25:
			Sfx.play("boom", lerpf(1.5, 0.8, charge_t()), lerpf(-10.0, -2.0, charge_t()))  # a charged hit lands with extra weight
		# impact: the attacker compresses into the blow while the pose is held, then rebounds as the freeze ends
		var iw := clampf((float(h["dmg"]) - 4.0) / 20.0, 0.0, 1.0)
		a.squash = Vector2(lerpf(1.12, 1.3, iw), lerpf(0.94, 0.8, iw))
		if info.clash:
			Actor.clash_fx(a.get_parent(), info.pos)
		var drain := float(h.get("drain", 0.0))
		if drain > 0.0 and t is Actor and not info.friendly and info.dmg > 0.0:
			# life drain: a share of the damage dealt comes back as health, a smaller share to a nearby partner
			var got := info.dmg * drain
			a.heal(got)
			Fx.number(a.get_parent(), a.global_position + Vector2(randf_range(-20.0, 20.0), -105), "+%d" % maxi(1, int(round(got))), Color(2.0, 1.7, 1.9), 18)
			var dp := Coop.partner_of(a)
			if dp != null and dp.is_alive() and dp.state != "downed" and dp.global_position.distance_to(a.global_position) < 420.0:
				dp.heal(got * 0.5)
				Fx.number(a.get_parent(), dp.global_position + Vector2(0, -105), "+%d" % maxi(1, int(round(got * 0.5))), Color(2.0, 1.7, 1.9), 16)
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
