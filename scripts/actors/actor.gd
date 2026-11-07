class_name Actor
extends CharacterBody2D
## Shared base for fighters and enemies: HP, hit reactions (hurt / launched / down / get-up),
## juggling, grabs, attack playback, buffs and the stickfigure visuals.
## Origin = feet. Collision layers: 1 ground, 2 platforms, 3 players, 4 enemies.

const GRAVITY := 2300.0
const MAX_FALL := 1700.0
const NO_GRAB_STATES := ["launched", "down", "dead", "grabbed", "tossed", "getup", "downed"]

var team := "enemy"
var max_hp := 100.0
var hp := 100.0
var facing := 1
var state := "idle"
var freeze := 0
var stun_frames := 0
var invuln := 0.0
var armor_t := 0.0
var guard_t := 0
var parry_t := 0
var reflect_t := 0
var flash_t := 0.0
var run_speed := 330.0
var move_input_x := 0.0
var body_w := 34.0
var body_h := 86.0
var body_scale := 1.0
var launch_resist := false
var no_grab := false
var kill_y := 2200.0

var figure: StickFigure
var attack: AttackRunner
var last_hitter: Actor = null
var juggle_hits := 0
var buffs: Dictionary = {}
var upgrades: Dictionary = {}  ## move_id -> {dmg, spd, kb} multipliers earned from rewards
var squash := Vector2.ONE
var holder: Node = null
var thrown_by: Actor = null
var debug_hit_rect := Rect2()
var dying := false

var _launch_t := 0.0
var _down_t := 0.0
var _getup_t := 0.0
var _tumble := 1.0
var _bumped: Dictionary = {}
var _bounced := false
var _wallbounce := false
var _victim_freeze := false
var _walk_phase := 0.0


func _configure() -> void:
	pass


func _ready() -> void:
	_configure()
	attack = AttackRunner.new(self)
	add_to_group("actors")
	add_to_group("hurt_" + team)
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(4, true)  # barriers (Bulwark Plant) block bodies but not projectiles
	floor_snap_length = 8.0
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = body_w * 0.5 * body_scale
	cap.height = body_h * body_scale
	cs.shape = cap
	cs.position = Vector2(0, -body_h * body_scale * 0.5)
	add_child(cs)
	figure = StickFigure.new()
	add_child(figure)
	figure.set_target(PoseLib.idle(0.0), true)


# ------------------------------------------------------------------ queries

func is_targetable() -> bool:
	return state != "down" and state != "dead"


func is_alive() -> bool:
	return hp > 0.0 and state != "dead"


func get_hurt_rect() -> Rect2:
	var w := body_w * body_scale
	var h := body_h * body_scale
	return Rect2(global_position.x - w * 0.5, global_position.y - h, w, h)


func center() -> Vector2:
	return global_position + Vector2(0, -body_h * body_scale * 0.5)


func hit_targets() -> Array:
	var out: Array = []
	if team == "player":
		for n in get_tree().get_nodes_in_group("hurt_enemy"):
			if n.is_targetable():
				out.append(n)
		if Coop.friendly_fire:
			for n in get_tree().get_nodes_in_group("hurt_player"):
				if n != self and n.is_targetable():
					out.append(n)
	else:
		for n in get_tree().get_nodes_in_group("hurt_player"):
			if n.is_targetable():
				out.append(n)
	return out


func nearest_target(max_dist: float) -> Actor:
	var best: Actor = null
	var bd := max_dist
	for t in hit_targets():
		if t is Actor and (t as Actor).team != team:
			var d := absf(t.global_position.x - global_position.x) + absf(t.global_position.y - global_position.y) * 0.5
			if d < bd:
				bd = d
				best = t
	return best


func is_btn_held(_b: int) -> bool:
	return false


func has_buff(n: String) -> bool:
	return buffs.has(n)


func add_buff(n: String, dur: float) -> void:
	buffs[n] = dur


func dmg_mult() -> float:
	var m := 1.0
	if has_buff("rage"):
		m *= 1.5
	if has_buff("dmg"):
		m *= 1.5
	if has_buff("boost"):
		m *= 2.0
	return m


func take_mult() -> float:
	return 1.3 if has_buff("rage") else 1.0


## Reward upgrades for a move (chain parts jab2/jab3 count as "jab").
func upgrade_mult(move_id: String, stat: String) -> float:
	var u: Dictionary = upgrades.get(move_id.rstrip("0123456789"), {})
	return float(u.get(stat, 1.0))


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func telegraph() -> void:
	pass


func on_attack_end(_m: MoveData) -> void:
	if state == "attack":
		state = "idle"
		figure.set_target(PoseLib.idle(0.0))


func on_hit_landed(_info: HitInfo, _target: Node) -> void:
	if has_buff("boost"):
		buffs.erase("boost")


func _filter_hit(_info: HitInfo) -> bool:
	return false


func _on_damaged(_info: HitInfo) -> void:
	pass


func _on_defeated() -> void:
	pass


# ------------------------------------------------------------------ taking hits

## Override: true if this actor avoids the hit entirely (e.g. a crouching player vs a HIGH attack).
func _dodges(_info: HitInfo) -> bool:
	return false


func take_hit(info: HitInfo) -> bool:
	if not is_targetable() or invuln > 0.0:
		return false
	if _dodges(info):
		return false
	if _filter_hit(info):
		return true
	Coop.pre_hit(info, self)
	var atk := info.attacker as Actor
	var dmg := info.dmg * take_mult()
	if info.friendly:
		dmg *= Coop.ff_scale
	hp = maxf(hp - dmg, 1.0 if info.friendly else 0.0)
	if self is Fighter:
		Coop.stat_damage += dmg
	if atk != null and atk.team != team:
		last_hitter = atk
	var lethal := hp <= 0.0
	var armored := armor_t > 0.0 and not lethal
	if attack.active and not armored:
		attack.interrupt()
	if state == "grabbed" and holder != null:
		holder = null

	var was_launched := state == "launched"
	var launch := info.kind in ["launch", "spike", "trip"] or lethal or was_launched or not is_on_floor() or info.kb.length() > 760.0
	if launch_resist and not lethal and not was_launched:
		launch = false
	if atk != null and absf(atk.global_position.x - global_position.x) > 2.0 and not armored:
		facing = 1 if atk.global_position.x > global_position.x else -1

	if armored:
		velocity.x += info.kb.x * 0.08
	elif info.kind == "pull" and atk != null:
		state = "hurt"
		stun_frames = info.stun
		velocity = Vector2(clampf((atk.global_position.x - global_position.x) * 5.0, -info.pull_speed, info.pull_speed), 0)
	elif launch:
		_start_launch(info, lethal)
	else:
		state = "hurt"
		stun_frames = info.stun
		velocity = Vector2(info.kb.x, 0)
	_wallbounce = info.wallbounce if launch else _wallbounce

	freeze = info.stop
	_victim_freeze = true
	flash_t = 0.12
	var sq := clampf(dmg / 20.0, 0.4, 0.7)
	squash = Vector2(1.0 + sq, 1.0 - sq * 0.9)  # squashed by the blow
	_hit_feedback(info, dmg)
	Coop.post_hit(info, self, dmg)
	_on_damaged(info)
	if lethal:
		dying = true
	return true


func _start_launch(info: HitInfo, lethal: bool) -> void:
	var kb := info.kb
	var was_launched := state == "launched"
	var sc := maxf(0.5, 1.0 - 0.1 * juggle_hits) if was_launched else 1.0
	if info.kind == "spike":
		velocity = Vector2(kb.x * 0.3, absf(kb.y))
	else:
		velocity = Vector2(kb.x, kb.y * sc if kb.y < 0.0 else -260.0)
		if info.kind == "trip":
			velocity.y = minf(velocity.y, -240.0)
		if lethal and velocity.y > -320.0:
			velocity.y = -380.0
		if lethal and absf(velocity.x) < 160.0:
			velocity.x = 160.0 * (-1 if facing > 0 else 1)
	juggle_hits = juggle_hits + 1 if was_launched else 0
	state = "launched"
	_launch_t = 0.0
	_bounced = false
	_bumped.clear()
	_tumble = -signf(kb.x) if kb.x != 0.0 else 1.0


func _hit_feedback(info: HitInfo, dmg: float) -> void:
	var parent := get_parent()
	var power := clampf(dmg / 6.0, 0.9, 3.0)
	var dir := info.kb.normalized() if info.kb != Vector2.ZERO else Vector2(facing, -0.3)
	Fx.impact(parent, info.pos, info.color, power, dir)
	var pitch := 1.0 + minf(Coop.combo, 24) * 0.025
	if info.relay:
		Sfx.play("relay", 1.0 + minf(Coop.relay, 6) * 0.08)
	if dmg >= 14.0 or info.kind == "spike":
		Sfx.play("heavy")
	else:
		Sfx.play("hit" if randf() < 0.5 else "hit2", pitch)
	if not info.no_combo and not info.friendly:
		var txt := "%d" % int(round(dmg))
		var col := Color(1.0, 0.95, 0.5) if info.relay else Color(1.0, 1.0, 1.0)
		Fx.number(parent, global_position + Vector2(randf_range(-14, 14), -body_h * body_scale - 6.0), txt, col, int(clampf(18.0 + dmg * 0.9, 18.0, 40.0)))
	elif info.friendly:
		Fx.number(parent, global_position + Vector2(0, -body_h - 6.0), "%d" % int(round(dmg)), Color(0.7, 0.7, 0.7), 16)
	Juice.shake(info.shake * (1.4 if info.relay else 1.0))
	# camera: directional kick toward the blow, zoom punch and a flash of slow motion on heavy hits
	if not info.friendly:
		Juice.kick(dir * clampf(dmg * 3.2, 12.0, 68.0))
		var zp := clampf((dmg - 5.0) / 80.0, 0.0, 0.14)
		if info.punch > 0.0 or info.relay or zp > 0.0:
			Juice.zoom_punch(maxf(maxf(info.punch, zp), 0.05 if info.relay else 0.0))
		if (dmg >= 12.0 or hp <= 0.0 or info.relay) and Engine.time_scale > 0.9:
			Juice.slowmo(0.22, 0.12 if hp > 0.0 else 0.22)


func apply_direct_damage(amount: float, label := "") -> void:
	hp = maxf(0.0, hp - amount)
	Fx.number(get_parent(), global_position + Vector2(0, -body_h * body_scale - 6.0), label if label != "" else "%d" % int(amount), Color(1.0, 0.8, 0.4), 22)
	if hp <= 0.0:
		dying = true


# ------------------------------------------------------------------ grabs / throws

func can_be_grabbed() -> bool:
	return not no_grab and not (state in NO_GRAB_STATES) and is_alive()


func grab(by: Node) -> void:
	if attack.active:
		attack.interrupt()
	state = "grabbed"
	holder = by
	velocity = Vector2.ZERO
	invuln = maxf(invuln, 0.0)


func release() -> void:
	if state == "grabbed":
		state = "hurt"
		stun_frames = 12
		holder = null
		velocity = Vector2.ZERO


func thrown(vel: Vector2, by: Actor) -> void:
	state = "launched"
	holder = null
	velocity = vel
	thrown_by = by
	last_hitter = by if by.team != team else last_hitter
	juggle_hits = 0
	_launch_t = 0.0
	_bounced = true
	_bumped.clear()
	_tumble = -signf(vel.x) if vel.x != 0.0 else 1.0
	global_position.y -= 6.0


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if freeze > 0:
		freeze -= 1
		figure.frozen = true  # hold the pose on impact
		figure.jitter = 3.0 if _victim_freeze else 0.0
		figure.self_modulate = Color(1.9, 1.9, 1.9) if flash_t > 0.0 else Color.WHITE
		return
	figure.jitter = 0.0
	figure.frozen = false
	_victim_freeze = false
	_tick_timers(delta)
	match state:
		"hurt": _st_hurt(delta)
		"launched": _st_launched(delta)
		"down": _st_down(delta)
		"getup": _st_getup(delta)
		"grabbed": _st_grabbed(delta)
		"attack": _st_attack(delta)
		"dead": pass
		_: _control(delta)
	if global_position.y > kill_y:
		_fell_out()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	armor_t = maxf(0.0, armor_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	if guard_t > 0 and guard_t < 99999:
		guard_t -= 1
	parry_t = maxi(0, parry_t - 1)
	reflect_t = maxi(0, reflect_t - 1)
	for k in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if float(buffs[k]) <= 0.0:
			buffs.erase(k)


func _control(_delta: float) -> void:
	pass


func _fell_out() -> void:
	apply_direct_damage(hp)
	state = "dead"


func start_attack(m: MoveData, btn := -1) -> void:
	state = "attack"
	attack.start(m, btn)


func _st_attack(delta: float) -> void:
	_attack_extra(delta)
	if state != "attack":
		return
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 50.0
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	attack.tick()
	move_and_slide()


func _attack_extra(_delta: float) -> void:
	pass


func _st_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	if is_on_floor():
		velocity.y = 50.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	stun_frames -= 1
	if stun_frames <= 0:
		state = "idle"


func _st_launched(delta: float) -> void:
	_launch_t += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)
	var vx_before := velocity.x
	var vy_before := velocity.y
	move_and_slide()
	figure.rot += _tumble * facing * 10.0 * delta
	if is_on_wall() and absf(vx_before) > 230.0:
		var n := get_wall_normal()
		velocity.x = n.x * absf(vx_before) * 0.45
		Fx.impact(get_parent(), global_position + Vector2(-n.x * 14.0, -50.0), Color(1.6, 1.6, 1.6), 0.9, n)
		Sfx.play("heavy", 1.2)
		Juice.shake(0.3)
		if _wallbounce:
			_wallbounce = false
			apply_direct_damage(10.0, "WALL BOUNCE!")
			Juice.shake(0.4)
			Coop.bonus_hit(last_hitter, self, 10.0)
		elif team == "enemy" and absf(vx_before) > 450.0:
			apply_direct_damage(3.0, "SPLAT")
	_launch_collisions()
	if is_on_floor() and vy_before >= 0.0 and _launch_t > 0.06:
		_land_from_launch(vy_before)


func _launch_collisions() -> void:
	if team != "enemy" or velocity.length() < 280.0:
		return
	var credit: Actor = thrown_by if thrown_by != null else last_hitter
	if credit == null:
		return
	for t in get_tree().get_nodes_in_group("hurt_enemy"):
		if t == self or _bumped.has(t.get_instance_id()) or not t.has_method("take_hit"):
			continue
		if t.has_method("is_targetable") and not t.is_targetable():
			continue
		if get_hurt_rect().intersects(t.get_hurt_rect()):
			_bumped[t.get_instance_id()] = true
			var info := HitInfo.new()
			info.attacker = credit
			info.team = "player"
			info.dmg = 12.0 if thrown_by != null else 8.0
			info.kind = "normal"
			info.kb = Vector2(signf(velocity.x) * 320.0, -240.0)
			info.stun = 24
			info.stop = 6
			info.source = "thrown" if thrown_by != null else "pinball"
			info.pos = get_hurt_rect().intersection(t.get_hurt_rect()).get_center()
			info.shake = 0.3
			if t.take_hit(info):
				velocity.x *= 0.6
				Coop.say("PINBALL!" if thrown_by == null else "STRIKE!", Color(1.8, 1.4, 0.4), info.pos)


func _land_from_launch(vy: float) -> void:
	var parent := get_parent()
	Fx.dust(parent, global_position, 8 + int(vy / 300.0))
	squash = Vector2(1.3, 0.7)
	if vy > 850.0 and not _bounced and not dying:
		# spiked: bounce back up for the next hit
		_bounced = true
		velocity = Vector2(velocity.x * 0.5, -vy * 0.4)
		apply_direct_damage(minf(vy / 250.0, 5.0), "SLAM")
		Fx.ring(parent, global_position + Vector2(0, -4), Color(1.8, 1.4, 0.6), 90.0, 0.3)
		Sfx.play("boom", 1.4)
		Juice.shake(0.45)
		Juice.zoom_punch(0.05)
		return
	Sfx.play("land", 0.8)
	Juice.shake(clampf(vy / 3000.0, 0.05, 0.3))
	juggle_hits = 0
	thrown_by = null
	_bumped.clear()
	figure.rot = fmod(figure.rot + PI, TAU) - PI
	if hp <= 0.0:
		_on_defeated()
		return
	state = "down"
	_down_t = 0.55


func _st_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL) if not is_on_floor() else 50.0
	move_and_slide()
	_down_t -= delta
	if _down_t <= 0.0:
		state = "getup"
		_getup_t = 0.3
		invuln = maxf(invuln, 0.6)


func _st_getup(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 50.0 if is_on_floor() else minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_getup_t -= delta
	if _getup_t <= 0.0:
		state = "idle"


func _st_grabbed(_delta: float) -> void:
	if holder == null or not is_instance_valid(holder):
		release()
		return
	var h := holder as Actor
	if h != null:
		global_position = h.global_position + Vector2(h.facing * 30.0, -26.0)
	velocity = Vector2.ZERO


# ------------------------------------------------------------------ visuals

func _loco_pose() -> Dictionary:
	return PoseLib.idle(Time.get_ticks_msec() / 1000.0)


func _update_visuals(delta: float) -> void:
	if not attack.active:
		figure.zeta = 0.32 if (state == "hurt" or state == "launched" or state == "getup") else 1.0
	match state:
		"hurt":
			figure.set_target(PoseLib.hurt())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"launched":
			figure.set_target(PoseLib.launched())
		"down", "downed":
			figure.set_target(PoseLib.down())
			figure.rot = lerpf(figure.rot, -PI * 0.5, 0.35)
		"getup":
			figure.set_target(PoseLib.getup())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"grabbed":
			figure.set_target(PoseLib.grabbed())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"attack":
			pass
		_:
			var p := _loco_pose()
			if not p.is_empty():
				figure.set_target(p)
			if state != "tossed":
				figure.rot = lerpf(figure.rot, 0.0, 0.3)
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	figure.scale = Vector2(facing * squash.x * body_scale, squash.y * body_scale)
	figure.self_modulate = Color(2.6, 2.6, 2.6) if flash_t > 0.0 else Color.WHITE
