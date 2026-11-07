class_name Fighter
extends Actor
## A player character: locomotion, the 15-slot move loadout, dash, carrying, toss and revive.

const RUN_SPEED := 330.0
const ACCEL := 2800.0
const AIR_ACCEL := 1800.0
const FRICTION := 3400.0
const AIR_FRICTION := 600.0
const FALL_MULT := 1.35
const JUMP_V := -880.0
const COYOTE := 0.09
const JUMP_BUFFER := 0.12
const DROP_MAX_TIME := 0.6
const TURN_DELAY := 4
## Reserved: cyan and lime appear nowhere else in the game (enemies are red/orange/amber/crimson).
const PLAYER_COLORS := [Color(0.2, 1.5, 2.3), Color(0.75, 2.2, 0.25)]

@export var player_index := 0

var input: PlayerInput
var loadout: Dictionary = {}
var meter := 0.0
var spawn_point := Vector2.ZERO
var held: Node = null
var shield_hits := 0
var revive_progress := 0.0

var _coyote := 0.0
var _jump_buf := 0.0
var _jumping := false
var _drop_t := 0.0
var _drop_clear_y := 0.0
var _floor_collider: Object = null
var _was_on_floor := false
var _land_t := 0.0
var _turn_t := 0
var _buf_slot := ""
var _buf_btn := -1
var _buf_t := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _ghost := false
var _toss_t := 0.0
var _toss_hit: Dictionary = {}
var _ghost_tick := 0.0


func _configure() -> void:
	team = "player"
	max_hp = 100.0
	hp = max_hp
	run_speed = RUN_SPEED


func _ready() -> void:
	super._ready()
	add_to_group("fighters")
	set_collision_layer_value(3, true)
	set_collision_mask_value(3, true)
	figure.color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	input = Inp.players[player_index]
	spawn_point = global_position
	loadout = MoveDB.STARTER.duplicate()
	Coop.fighters.append(self)
	tree_exiting.connect(func(): Coop.fighters.erase(self))


func get_run_speed() -> float:
	return RUN_SPEED * (1.3 if has_buff("speed") else 1.0) * (0.75 if held != null else 1.0)


func is_btn_held(b: int) -> bool:
	return input.is_held(b)


func is_targetable() -> bool:
	return state != "down" and state != "dead" and state != "downed" and state != "tossed"


func is_alive() -> bool:
	return hp > 0.0 and state != "downed" and state != "dead"


func set_move(slot: String, id: String) -> void:
	if id == "":
		loadout.erase(slot)
	else:
		loadout[slot] = id


# ------------------------------------------------------------------ main control

func _tick_timers(delta: float) -> void:
	super._tick_timers(delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if _ghost and state != "dash":
		var overlap := false
		for f in Coop.fighters:
			if f != self and get_hurt_rect().intersects(f.get_hurt_rect()):
				overlap = true
		if not overlap:
			_ghost = false
			set_collision_mask_value(3, true)


func _control(delta: float) -> void:
	match state:
		"dash":
			_st_dash(delta)
		"tossed":
			_st_tossed(delta)
		"downed":
			_st_downed(delta)
		_:
			_locomotion(delta)


func _locomotion(delta: float) -> void:
	var on_floor := is_on_floor()
	var mx := input.dir.x
	if absf(mx) < 0.2:
		mx = 0.0
	move_input_x = mx
	if mx != 0.0:
		var want := 1 if mx > 0.0 else -1
		if want != facing:
			_turn_t += 1
			if _turn_t >= TURN_DELAY:
				facing = want
				_turn_t = 0
		else:
			_turn_t = 0
		var a := ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, mx * get_run_speed(), a * delta)
	else:
		_turn_t = 0
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if on_floor else AIR_FRICTION) * delta)
	if on_floor and _floor_collider is Fighter:
		var away := signf(global_position.x - (_floor_collider as Fighter).global_position.x)
		velocity.x = (away if away != 0.0 else float(facing)) * 160.0

	if on_floor:
		_coyote = COYOTE
		_jumping = false
		velocity.y = 50.0
	else:
		_coyote -= delta
		var g := GRAVITY * (FALL_MULT if velocity.y > 0.0 else 1.0)
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	# jump / drop through
	_jump_buf -= delta
	if input.pressed(PlayerInput.Btn.JUMP):
		_jump_buf = JUMP_BUFFER
	if _jump_buf > 0.0:
		if on_floor and input.dir.y > 0.6 and _on_platform():
			_start_drop()
			_jump_buf = 0.0
		elif _coyote > 0.0:
			velocity.y = JUMP_V
			_coyote = 0.0
			_jump_buf = 0.0
			_jumping = true
			squash = Vector2(0.8, 1.25)
			Sfx.play("jump")
			Fx.dust(get_parent(), global_position, 6)
	if input.released(PlayerInput.Btn.JUMP) and _jumping and velocity.y < 0.0:
		velocity.y *= 0.45
		_jumping = false
	if _drop_t > 0.0:
		_drop_t -= delta
		if global_position.y - body_h > _drop_clear_y or _drop_t <= 0.0:
			_drop_t = 0.0
			set_collision_mask_value(2, true)

	# actions
	if held != null:
		if input.pressed(PlayerInput.Btn.INTERACT) or input.pressed(PlayerInput.Btn.X) or input.pressed(PlayerInput.Btn.Y) or input.pressed(PlayerInput.Btn.B):
			_throw_held()
	else:
		if input.pressed(PlayerInput.Btn.DASH) and _dash_cd <= 0.0:
			_start_dash()
		elif input.pressed(PlayerInput.Btn.INTERACT):
			_try_pickup()
		else:
			for b in [PlayerInput.Btn.X, PlayerInput.Btn.Y, PlayerInput.Btn.B]:
				if input.pressed(b):
					if _try_slot(_slot_for(b), b):
						break
	if state == "attack":
		return

	var vy_before := velocity.y
	move_and_slide()
	_floor_collider = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.6:
			_floor_collider = c.get_collider()

	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor and vy_before > 250.0:
		var k := clampf(vy_before / 1500.0, 0.12, 0.35)
		squash = Vector2(1.0 + k, 1.0 - k)
		_land_t = 0.10 if vy_before > 600.0 else 0.0
		Fx.dust(get_parent(), global_position, 8)
		Sfx.play("land", 1.0, -6.0)
	_was_on_floor = now_floor
	_land_t = maxf(0.0, _land_t - delta)
	if _land_t > 0.0:
		state = "land"
	elif not now_floor:
		state = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 25.0:
		state = "walk"
		var dir_sign := 1.0 if velocity.x * facing >= 0.0 else -1.0
		_walk_phase += absf(velocity.x) * 0.055 * delta * dir_sign
	else:
		state = "idle"


func _on_platform() -> bool:
	if _floor_collider is CollisionObject2D:
		return ((_floor_collider as CollisionObject2D).collision_layer & 2) != 0
	return false


func _start_drop() -> void:
	var bottom: float = global_position.y + 20.0
	if _floor_collider is Node:
		bottom = (_floor_collider as Node).get_meta("bottom_y", bottom)
	_drop_clear_y = bottom
	_drop_t = DROP_MAX_TIME
	set_collision_mask_value(2, false)
	global_position.y += 2.0
	velocity.y = 120.0


func respawn() -> void:
	var p := Coop.partner_of(self)
	if p != null and p.is_alive():
		global_position = p.global_position + Vector2(-p.facing * 40.0, -30.0)
	else:
		global_position = spawn_point
	velocity = Vector2.ZERO
	_drop_t = 0.0
	set_collision_mask_value(2, true)
	invuln = 1.5
	state = "idle"


func _fell_out() -> void:
	respawn()


# ------------------------------------------------------------------ attacks

func _slot_for(b: int) -> String:
	var name := "X"
	if b == PlayerInput.Btn.Y:
		name = "Y"
	elif b == PlayerInput.Btn.B:
		name = "B"
	var d := input.digital_dir()
	if d.y < 0:
		return name + "_UP"
	if d.y > 0:
		return name + "_DOWN"
	if d.x != 0:
		return name + "_SIDE"
	return name


func _try_slot(slot: String, btn: int) -> bool:
	var id: String = loadout.get(slot, "")
	if id == "":
		return false
	var m := MoveDB.get_move(id)
	if m == null:
		return false
	if m.ground_only and not is_on_floor():
		return false
	# left and right share a slot: the move goes the way the stick points
	if slot.ends_with("_SIDE") and absf(input.dir.x) > 0.2:
		facing = 1 if input.dir.x > 0.0 else -1
		_turn_t = 0
	if m.air_only and is_on_floor():
		velocity.y = -520.0
	start_attack(m, btn)
	return true


func _attack_extra(_delta: float) -> void:
	for b in [PlayerInput.Btn.X, PlayerInput.Btn.Y, PlayerInput.Btn.B]:
		if input.pressed(b):
			_buf_slot = _slot_for(b)
			_buf_btn = b
			_buf_t = 0.22
	if _buf_t > 0.0:
		_buf_t -= _delta
		var id: String = loadout.get(_buf_slot, "")
		if id != "":
			var cur := attack.move
			var head := cur.id.rstrip("0123456789")
			if attack.can_chain() and id == head:
				_buf_t = 0.0
				start_attack(MoveDB.get_move(cur.chain_next), _buf_btn)
				return
			if attack.can_cancel() and id != head and _try_slot(_buf_slot, _buf_btn):
				_buf_t = 0.0
				return
	# dash cancel on hit
	if input.pressed(PlayerInput.Btn.DASH) and _dash_cd <= 0.0 and attack.can_cancel():
		attack.interrupt()
		_start_dash()


func on_attack_end(m: MoveData) -> void:
	super.on_attack_end(m)
	if state == "idle":
		_was_on_floor = is_on_floor()


func on_hit_landed(info: HitInfo, target: Node) -> void:
	super.on_hit_landed(info, target)
	if info.source == "melee" and target is Actor and (target as Actor).team == "enemy":
		meter = minf(100.0, meter + 1.0)


# ------------------------------------------------------------------ dash / carry / toss / revive

func _start_dash() -> void:
	var dir := signf(input.dir.x) if absf(input.dir.x) > 0.3 else float(facing)
	state = "dash"
	_dash_t = 0.17
	_dash_cd = 0.5
	velocity = Vector2(dir * 640.0, 0.0)
	invuln = maxf(invuln, 0.22)
	_ghost = true
	set_collision_mask_value(3, false)
	Sfx.play("whoosh", 1.2)
	Fx.dust(get_parent(), global_position, 6)
	figure.set_target({"lean": 0.9, "th_f": 1.1, "kn_f": 0.3, "th_b": -1.0, "kn_b": 0.4, "ua_f": 1.4, "la_f": 0.2, "ua_b": 1.2, "la_b": 0.2})


func _st_dash(delta: float) -> void:
	_dash_t -= delta
	_ghost_tick -= delta
	if _ghost_tick <= 0.0:
		_ghost_tick = 0.04
		Fx.afterimage(get_parent(), figure, figure.color)
	velocity.y = minf(velocity.y + GRAVITY * 0.5 * delta, MAX_FALL) if not is_on_floor() else 50.0
	move_and_slide()
	if _dash_t <= 0.0:
		velocity.x *= 0.4
		state = "idle"


func _try_pickup() -> void:
	var best: Node = null
	var bd := 80.0
	for p in get_tree().get_nodes_in_group("props"):
		if p.has_method("can_be_grabbed") and p.can_be_grabbed():
			var d := absf(p.global_position.x - global_position.x) + absf(p.global_position.y - global_position.y) * 0.5
			if d < bd:
				bd = d
				best = p
	if best != null:
		best.grab(self)
		held = best
		Sfx.play("pickup", 0.8)


func _throw_held() -> void:
	if held != null and is_instance_valid(held):
		held.thrown(Vector2(facing * 640.0, -280.0), self)
		Sfx.play("throw")
	held = null


func _on_damaged(_info: HitInfo) -> void:
	if held != null and is_instance_valid(held):
		held.release()
	held = null
	if state == "dash":
		_ghost = true


func begin_toss(dir: int, _by: Actor) -> void:
	state = "tossed"
	holder = null
	_toss_t = 0.6
	_toss_hit.clear()
	velocity = Vector2(dir * 760.0, -120.0)
	facing = dir
	invuln = 0.7
	figure.rot = -1.0
	attack.interrupt()


func _st_tossed(delta: float) -> void:
	_toss_t -= delta
	_ghost_tick -= delta
	if _ghost_tick <= 0.0:
		_ghost_tick = 0.04
		Fx.afterimage(get_parent(), figure, Color(2.0, 1.6, 0.5))
	velocity.x = facing * 760.0
	velocity.y += GRAVITY * 0.28 * delta + input.dir.y * 500.0 * delta
	move_and_slide()
	var rect := Rect2(global_position.x - 30.0 + facing * 28.0, global_position.y - 90.0, 72.0, 95.0)
	for t in get_tree().get_nodes_in_group("hurt_enemy"):
		if not t.is_targetable() or _toss_hit.has(t.get_instance_id()):
			continue
		if rect.intersects(t.get_hurt_rect()):
			_toss_hit[t.get_instance_id()] = true
			var info := HitInfo.new()
			info.attacker = self
			info.team = "player"
			info.dmg = 14.0 * dmg_mult()
			info.kind = "launch"
			info.kb = Vector2(380.0 * facing, -440.0)
			info.stun = 26
			info.stop = 5
			info.shake = 0.35
			info.color = Color(2.0, 1.6, 0.5)
			info.pos = rect.get_center()
			if t.take_hit(info):
				freeze = maxi(freeze, 4)
				meter = minf(100.0, meter + 5.0)
	if _toss_t <= 0.0 or is_on_wall() or (is_on_floor() and _toss_t < 0.5):
		state = "idle"
		figure.rot = 0.0
		invuln = maxf(invuln, 0.3)
		Fx.dust(get_parent(), global_position, 8)


func _on_defeated() -> void:
	state = "downed"
	velocity = Vector2.ZERO
	revive_progress = 0.0
	if held != null and is_instance_valid(held):
		held.release()
	held = null
	Sfx.play("death")
	Coop.say("P%d DOWN!" % (player_index + 1), Color(2.0, 0.4, 0.4), global_position + Vector2(0, -90))
	Coop.check_game_over()


func _st_downed(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	velocity.y = 50.0 if is_on_floor() else minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	var p := Coop.partner_of(self)
	var reviving := false
	if p != null and p.is_alive() and p.state != "launched" and Coop.revives_left > 0:
		if p.input.is_held(PlayerInput.Btn.INTERACT) and absf(p.global_position.x - global_position.x) < 90.0 and absf(p.global_position.y - global_position.y) < 60.0:
			reviving = true
	if reviving:
		revive_progress += delta / 2.0
		if randf() < 0.3:
			Fx.sparks(get_parent(), global_position + Vector2(0, -20), Color(2.0, 1.7, 1.9), 2, Vector2(0, -1))
	else:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)
	if revive_progress >= 1.0:
		revive()


func revive() -> void:
	Coop.revives_left = maxi(0, Coop.revives_left - 1)
	hp = max_hp * 0.3
	revive_progress = 0.0
	state = "getup"
	_getup_t = 0.5
	invuln = 2.0
	Sfx.play("revive")
	Fx.ring(get_parent(), global_position + Vector2(0, -40), Color(2.0, 1.7, 1.9), 140.0, 0.5)
	Fx.number(get_parent(), global_position + Vector2(0, -100), "REVIVED!", Color(2.0, 1.7, 1.9), 28)
	Coop.is_over = false


# ------------------------------------------------------------------ taking hits (guard / parry / shield)

func _filter_hit(info: HitInfo) -> bool:
	var atk := info.attacker as Node2D
	var front := atk == null or (atk.global_position.x - global_position.x) * facing >= 0.0
	if parry_t > 0 and info.source != "pinball":
		_do_parry(info)
		return true
	if guard_t > 0 and front and not info.guard_break:
		hp = maxf(1.0, hp - info.dmg * 0.12)
		velocity.x = -facing * 170.0
		freeze = 3
		flash_t = 0.06
		Sfx.play("block")
		Fx.impact(get_parent(), global_position + Vector2(facing * 28.0, -60.0), Color(1.9, 1.9, 2.2), 0.7, Vector2(-facing, 0))
		Juice.shake(0.08)
		meter = minf(100.0, meter + 3.0)
		if atk is Actor:
			(atk as Actor).freeze = maxi((atk as Actor).freeze, 3)
		return true
	if shield_hits > 0:
		shield_hits -= 1
		Sfx.play("block")
		Fx.ring(get_parent(), global_position + Vector2(0, -45), Color(1.9, 1.9, 2.2), 80.0, 0.3)
		return true
	return false


func _do_parry(info: HitInfo) -> void:
	parry_t = 0
	invuln = 0.8
	var parent := get_parent()
	var pos := global_position + Vector2(facing * 34.0, -55.0)
	Fx.impact(parent, pos, Color(2.2, 2.0, 1.0), 1.6)
	Sfx.play("parry")
	Juice.shake(0.4)
	Juice.zoom_punch(0.07)
	Juice.slowmo(0.3, 0.18)
	meter = minf(100.0, meter + 20.0)
	Coop.say("PARRY!", Color(2.2, 2.0, 1.0), global_position + Vector2(0, -110))
	attack.hit_connected = true
	var atk := info.attacker as Actor
	if atk != null and atk.team != team and atk.is_targetable():
		var c := HitInfo.new()
		c.attacker = self
		c.team = "player"
		c.dmg = 24.0 * dmg_mult()
		c.kind = "launch"
		c.kb = Vector2(380.0 * facing, -650.0)
		c.stun = 30
		c.stop = 12
		c.pos = atk.center()
		c.shake = 0.5
		c.color = Color(2.2, 2.0, 1.0)
		atk.invuln = 0.0
		atk.take_hit(c)


# ------------------------------------------------------------------ pickups

func apply_pickup(kind: String) -> void:
	var parent := get_parent()
	match kind:
		"hp_s":
			heal(20.0)
			Fx.number(parent, global_position + Vector2(0, -100), "+20", Color(2.0, 1.7, 1.9), 24)
		"hp_m":
			heal(50.0)
			Fx.number(parent, global_position + Vector2(0, -100), "+50", Color(2.0, 1.7, 1.9), 28)
		"dmg":
			add_buff("dmg", 12.0)
			Fx.number(parent, global_position + Vector2(0, -100), "DAMAGE UP", Color(2.2, 0.8, 0.3), 22)
		"speed":
			add_buff("speed", 12.0)
			Fx.number(parent, global_position + Vector2(0, -100), "SPEED UP", Color(1.7, 1.0, 2.2), 22)
		"shield":
			shield_hits = 3
			Fx.number(parent, global_position + Vector2(0, -100), "SHIELD", Color(1.9, 1.9, 2.2), 22)
		"meter":
			meter = minf(100.0, meter + 50.0)
			Fx.number(parent, global_position + Vector2(0, -100), "+METER", Color(2.0, 1.8, 0.5), 22)
	Sfx.play("pickup")
	Fx.ring(parent, global_position + Vector2(0, -45), Color(1.6, 1.8, 2.0), 70.0, 0.3)


# ------------------------------------------------------------------ visuals

func _loco_pose() -> Dictionary:
	var p: Dictionary
	match state:
		"land":
			p = PoseLib.land()
		"jump":
			p = PoseLib.rise()
		"fall":
			p = PoseLib.fall()
		"walk":
			p = PoseLib.walk(_walk_phase)
		"dash":
			return {}
		"tossed":
			return {"lean": 0.0, "th_f": 1.5, "kn_f": 0.0, "th_b": 0.3, "kn_b": 0.5, "ua_f": 2.0, "la_f": 0.3, "ua_b": 2.2, "la_b": 0.2}
		_:
			p = PoseLib.idle(Time.get_ticks_msec() / 1000.0 + player_index)
	if held != null:
		var c := PoseLib.carry()
		for k in ["ua_f", "la_f", "ua_b", "la_b", "lean"]:
			p[k] = c[k]
	return p


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	if held != null and is_instance_valid(held):
		held.global_position = global_position + Vector2(facing * 4.0, -body_h - 22.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var a0 := 0.0 if facing > 0 else PI
	# player marker: a coloured arrow + number above the head
	if state != "downed" and state != "dead":
		var mc := figure.color
		var my := -body_h - 26.0 + sin(t * 4.0) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(-7, my - 9), Vector2(7, my - 9), Vector2(0, my)]), mc)
		draw_string(ThemeDB.fallback_font, Vector2(-14, my - 12), "P%d" % (player_index + 1), HORIZONTAL_ALIGNMENT_CENTER, 28.0, 13, mc)
	if guard_t > 0:
		draw_arc(Vector2(facing * 18.0, -48.0), 46.0, a0 - 1.1, a0 + 1.1, 20, Color(1.9, 1.9, 2.2, 0.9), 4.0, true)
	if reflect_t > 0:
		draw_arc(Vector2(facing * 26.0, -50.0), 56.0, a0 - 1.5, a0 + 1.5, 24, Color(2.0, 2.0, 2.4, 0.9), 5.0, true)
	if shield_hits > 0:
		draw_arc(Vector2(0, -45), 55.0, 0.0, TAU, 32, Color(1.9, 1.9, 2.2, 0.55 + 0.2 * sin(t * 8.0)), 3.0, true)
	if has_buff("rage"):
		draw_arc(Vector2(0, -45), 50.0 + 4.0 * sin(t * 14.0), 0.0, TAU, 32, Color(2.2, 0.3, 0.2, 0.6), 3.0, true)
	if has_buff("boost"):
		draw_arc(Vector2(0, -45), 50.0 + 4.0 * sin(t * 14.0), 0.0, TAU, 32, Color(2.0, 1.8, 0.4, 0.7), 3.0, true)
	if has_buff("dmg"):
		draw_circle(Vector2(0, -105), 4.0, Color(2.2, 0.8, 0.3))
	if has_buff("speed"):
		draw_circle(Vector2(8, -105), 4.0, Color(0.5, 1.8, 2.2))
	if state == "downed":
		var c := Vector2(0, -50)
		draw_arc(c, 34.0, 0.0, TAU, 32, Color(1, 1, 1, 0.2), 4.0, true)
		if revive_progress > 0.0:
			draw_arc(c, 34.0, -PI * 0.5, -PI * 0.5 + TAU * revive_progress, 32, Color(2.0, 1.7, 1.9), 5.0, true)
		var f := ThemeDB.fallback_font
		var txt := "HOLD RT" if Coop.revives_left > 0 else "NO REVIVES"
		draw_string(f, Vector2(-34, -92), txt, HORIZONTAL_ALIGNMENT_CENTER, 70.0, 13, Color(1, 1, 1, 0.8))
	if Dbg.enabled:
		draw_rect(Rect2(-body_w * 0.5, -body_h, body_w, body_h), Color(1, 1, 0, 0.8), false, 1.0)
		draw_line(Vector2.ZERO, Vector2(facing * 30.0, 0), Color(1, 0.4, 0.2), 2.0)
		if attack.active:
			draw_rect(Rect2(debug_hit_rect.position - global_position, debug_hit_rect.size), Color(1, 0.2, 0.2, 0.9), false, 2.0)


func debug_text() -> String:
	return "P%d %-8s hp=%3.0f meter=%3.0f pos(%4.0f,%4.0f) v(%5.0f,%5.0f) floor=%s %s\n    dir(%+.2f,%+.2f) btns: %s" % [
		player_index + 1, state, hp, meter, global_position.x, global_position.y, velocity.x, velocity.y,
		is_on_floor(), attack.move.id if attack.active else "", input.dir.x, input.dir.y, input.buttons_string()]
