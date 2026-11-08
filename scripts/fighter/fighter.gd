class_name Fighter
extends Actor
## A player character: locomotion, the 15-slot move loadout, dash, carrying, toss and revive.

const RUN_SPEED := 400.0
const WALK_FRAC := 0.42  ## a gentle stick tilt walks at this fraction of the run speed
const WALK_TILT := 0.65
const ACCEL := 7000.0
const AIR_ACCEL := 4200.0
const FRICTION := 8000.0
const AIR_FRICTION := 900.0
const FALL_MULT := 1.6
const JUMP_V := -880.0
const COYOTE := 0.09
const JUMP_BUFFER := 0.12
const DROP_MAX_TIME := 0.6
const TURN_DELAY := 4
const SPRINT_MULT := 1.5
const SPRINT_TAP_WINDOW := 0.3  ## flick the stick the same way twice within this to start a sprint
## Reserved: cyan and lime appear nowhere else in the game (enemies are red/orange/amber/crimson).
const PLAYER_COLORS := [Color(0.15, 1.0, 1.28), Color(0.55, 1.28, 0.15)]

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
var last_safe := Vector2.ZERO  ## last solid ground (>= 60 px from a pit edge) stood on: where a fall respawns

## Ledge grab: hang from the corner of a pit / platform; 3 s to climb alone, instant when the partner helps.
const LEDGE_SOLO_TIME := 3.0
const LEDGE_HANG_Y := 112.0  # feet this far below the corner: the raised hands are on it
var _ledge := {}  # the corner being held ({p, dir}), empty when not hanging
var _ledge_t := 0.0
var _ledge_cd := 0.0
var _ledge_climb := 0.0
var _ledge_from := Vector2.ZERO
var _ledge_to := Vector2.ZERO
var _was_on_floor := false
var _land_t := 0.0
var _turn_t := 0
var _buf_slot := ""
var _buf_btn := -1
var _buf_t := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _air_dash_used := false  ## one dash per air time; reset on landing
var class_id := ""  ## "brawler" / "sword" / "hammer" / "magic", "" = legacy
var class_speed := 1.0
var double_jump := false  ## unlocked by a level-up card
var _air_jump_ready := true
var _crouch := 0.0  ## 0..1, eases in over ~7 frames while holding down on the ground
var _ghost := false
var _toss_t := 0.0
var _toss_hit: Dictionary = {}
var _flung_t := 0.0  ## thrown by the partner: a fast floaty jump that can still act (attack, dash) and body-checks enemies
var _fling_grace := 0.0
var _dir_hist: Array = []  ## [physics frame, token] of recent stick directions for the super motion
var _super_hint_shown := false
var _ghost_tick := 0.0


func _configure() -> void:
	team = "player"
	body_h = 100.0
	max_hp = 100.0
	hp = max_hp
	run_speed = RUN_SPEED


func _ready() -> void:
	super._ready()
	add_to_group("fighters")
	set_collision_layer_value(3, true)
	figure.color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	figure.arm_scale = 1.22
	figure.leg_scale = 1.2
	figure.eyes = true
	input = Inp.players[player_index]
	spawn_point = global_position
	loadout = MoveDB.STARTER.duplicate()
	var cid: String = RunState.classes[player_index % 2]
	if cid != "":
		apply_class(cid)
		if not RunState.active:
			loadout = ClassData.training_loadout(cid)
	if RunState.active:
		RunState.apply_to(self)
	Coop.fighters.append(self)
	tree_exiting.connect(func(): Coop.fighters.erase(self))


func get_run_speed() -> float:
	return RUN_SPEED * (SPRINT_MULT if _sprint != 0 else 1.0) * class_speed * (1.3 if has_buff("speed") else 1.0) * (0.75 if held != null else 1.0) * crowd_mult()


## Weapon class: stats, weapon visual and base pose. "" = legacy (no class, plain fists).
func apply_class(id: String) -> void:
	class_id = id
	if id == "":
		class_speed = 1.0
		figure.weapon = ""
		return
	var c := ClassData.get_class_data(id)
	class_speed = float(c["speed"])
	figure.weapon = String(c["weapon"])
	if not RunState.active:
		max_hp = float(c["hp"])
		hp = max_hp


## Class base pose (the silhouette idle, walk arms and recovery return to), or {} for the legacy fighter.
func _base_pose() -> Dictionary:
	if class_id == "":
		return {}
	return ClassData.base_pose(class_id, Time.get_ticks_msec() / 1000.0 + player_index)


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
	if state in ["hurt", "launched", "attack", "dash", "downed", "tossed", "ledge", "dead"]:
		_sprint = 0  # a sprint never survives being hit, attacking or hanging
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_fling_grace = maxf(0.0, _fling_grace - delta)
	_record_motion()
	if meter >= MoveDBSupers.COST and not _super_hint_shown and class_id != "x":
		_super_hint_shown = true
		Coop.say("SUPER READY!  Down, down-forward, forward (twice) + X (team) or B (class)", Color(2.0, 1.8, 0.5), global_position + Vector2(0, -150))
	if _ghost and state != "dash":
		# actors never block each other any more; the dash only phases through barriers, solid again once clear
		var me := get_hurt_rect()
		var overlap := false
		for n in get_tree().get_nodes_in_group("barriers"):
			if n.has_method("get_rect") and me.intersects(n.get_rect()):
				overlap = true
		if not overlap:
			_ghost = false
			set_collision_mask_value(5, true)


func _control(delta: float) -> void:
	match state:
		"dash":
			_st_dash(delta)
		"tossed":
			_st_tossed(delta)
		"downed":
			_st_downed(delta)
		"ledge":
			_st_ledge(delta)
		_:
			_locomotion(delta)


var _air_spring := false
var _sprint := 0  ## 0 or the direction (-1/1) of a running sprint
var _tap_dir := 0
var _tap_t := 9.0
var _stick_active := false


## Flick the stick one way, let go, flick it again quickly: sprint until you let go or turn around.
func _update_sprint(delta: float, on_floor: bool) -> void:
	var raw := input.dir.x
	_tap_t += delta
	if absf(input.dir.y) > 0.5:
		_tap_t = 9.0  # a motion input (down / diagonal) is not a double tap
	var active := absf(raw) > 0.6 and absf(input.dir.y) < 0.5  # diagonals belong to special-move motions, not sprints
	var neutral := absf(raw) < 0.25
	if active and not _stick_active:
		var s := 1 if raw > 0.0 else -1
		if _tap_dir == s and _tap_t <= SPRINT_TAP_WINDOW and on_floor:
			_sprint = s
		_stick_active = true
	elif neutral and _stick_active:
		_stick_active = false
		_tap_dir = _last_raw_sign
		_tap_t = 0.0
		_sprint = 0
	if _sprint != 0 and (neutral or signf(raw) != float(_sprint) or state == "attack" or held != null):
		_sprint = 0
	if absf(raw) > 0.25:
		_last_raw_sign = 1 if raw > 0.0 else -1


var _last_raw_sign := 1


func _locomotion(delta: float) -> void:
	var sprint_floor := is_on_floor()
	_update_sprint(delta, sprint_floor)
	var on_floor := is_on_floor() and _fling_grace <= 0.0  # right after a fling the stale floor flag must not cancel the launch
	_ledge_cd = maxf(0.0, _ledge_cd - delta)
	if not on_floor and _ledge_cd <= 0.0 and velocity.y > -120.0 and held == null and _try_ledge():
		return
	var mx := input.dir.x
	if absf(mx) < 0.2:
		mx = 0.0
	elif absf(mx) < WALK_TILT:
		mx = signf(mx) * WALK_FRAC  # walk: a light tilt gives a clearly slower pace than a full push (run)
	else:
		mx = signf(mx)
	# crouch: hold down (stick mostly vertical) on the ground; stationary, no crouch-walking
	var want_crouch := on_floor and held == null and state != "attack" and input.dir.y > 0.6 and absf(input.dir.x) < 0.5
	_crouch = move_toward(_crouch, 1.0 if want_crouch else 0.0, delta / 0.115)
	if _crouch > 0.3 and want_crouch:
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
		if not (_flung_t > 0.0 and signf(mx) == signf(velocity.x)):  # a fling keeps its speed unless you steer against it
			velocity.x = move_toward(velocity.x, mx * get_run_speed(), a * delta)
	else:
		_turn_t = 0
		if _flung_t <= 0.0:
			velocity.x = move_toward(velocity.x, 0.0, (FRICTION if on_floor else AIR_FRICTION) * delta)
	if not is_instance_valid(_floor_collider):
		_floor_collider = null  # the thing we stood on was freed (a crate broke, an enemy died)
	if on_floor and _floor_collider is Fighter:
		var away := signf(global_position.x - (_floor_collider as Fighter).global_position.x)
		velocity.x = (away if away != 0.0 else float(facing)) * 160.0

	if on_floor:
		_coyote = COYOTE
		var lvl := get_parent()
		if lvl != null and lvl.has_method("is_safe_ground") and lvl.is_safe_ground(global_position):
			last_safe = global_position
		_jumping = false
		_air_dash_used = false
		_air_jump_ready = true
		velocity.y = 50.0
	else:
		_coyote -= delta
		var g := GRAVITY * (FALL_MULT if velocity.y > 0.0 else 1.0) * (0.55 if _flung_t > 0.0 else 1.0)  # flung: a fast, floaty jump
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if _flung_t > 0.0:
		_flung_tick(delta, on_floor)
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
		elif double_jump and _air_jump_ready and not on_floor:
			velocity.y = JUMP_V * 0.92
			_air_jump_ready = false
			_jump_buf = 0.0
			_jumping = true
			squash = Vector2(0.8, 1.25)
			Sfx.play("jump", 1.25)
			Fx.ring(get_parent(), global_position + Vector2(0, -10), figure.color, 36.0, 0.2)
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
		if input.pressed(PlayerInput.Btn.INTERACT) or input.pressed(PlayerInput.Btn.LB) or input.pressed(PlayerInput.Btn.X) or input.pressed(PlayerInput.Btn.Y) or input.pressed(PlayerInput.Btn.B):
			_throw_held()
	else:
		if input.pressed(PlayerInput.Btn.DASH) and _dash_cd <= 0.0 and (on_floor or not _air_dash_used):
			_start_dash()
		elif input.pressed(PlayerInput.Btn.INTERACT):
			_try_pickup()
		elif input.pressed(PlayerInput.Btn.LB):
			_try_grab()
		elif (input.pressed(PlayerInput.Btn.X) or input.pressed(PlayerInput.Btn.B)) and _try_super(input.pressed(PlayerInput.Btn.B)):
			pass
		else:
			for b in [PlayerInput.Btn.X, PlayerInput.Btn.Y, PlayerInput.Btn.B]:
				if input.pressed(b):
					if _try_slot(_slot_for(b), b):
						break
	if state == "attack" or state == "dash":  # a dash just started here: _st_dash drives it from the next frame on
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
		_walk_phase += absf(velocity.x) * (0.07 if absf(velocity.x) > RUN_SPEED * 0.7 else 0.085) * delta * dir_sign
	else:
		state = "idle"


func _on_platform() -> bool:
	if is_instance_valid(_floor_collider) and _floor_collider is CollisionObject2D:
		return ((_floor_collider as CollisionObject2D).collision_layer & 2) != 0
	return false


func _start_drop() -> void:
	var bottom: float = global_position.y + 20.0
	if is_instance_valid(_floor_collider) and _floor_collider is Node:
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
	set_collision_layer_value(3, true)


func _fell_out() -> void:
	hp = maxf(1.0, hp - 8.0)  # a fall stings a little but never kills
	respawn()
	if last_safe != Vector2.ZERO:
		global_position = last_safe + Vector2(0, -2)  # back to the last solid ground, not beside the partner
	Fx.number(get_parent(), global_position + Vector2(0, -110), "-8", Color(1.0, 0.8, 0.4), 20)


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
		# nothing on that direction: do the move on the neutral slot of the same button instead of doing nothing
		id = loadout.get(slot.substr(0, 1), "")
	if id == "":
		return false
	var m := MoveDB.get_move_for(id, class_id)
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
	var emp := input.is_held(PlayerInput.Btn.EMPOWER) and meter >= 10.0 and not m.hits.is_empty() and m.tier != "super"
	if emp:
		meter -= 10.0
	start_attack(m, btn)
	if emp:
		attack.empowered = true
		Fx.ring(get_parent(), global_position + Vector2(0, -50), figure.color, 60.0, 0.25)
		Fx.number(get_parent(), global_position + Vector2(0, -130), "EMPOWERED", Color(2.0, 1.7, 0.5), 18)
	return true


func _attack_extra(_delta: float) -> void:
	if attack.aiming:
		_buf_t = 0.0  # buttons throw the grabbed enemy; they must not also start or buffer a move
		return
	# LT held: a pressed attack button cancels the running move at once (empowered, for better combos)
	if input.is_held(PlayerInput.Btn.EMPOWER) and meter >= 10.0 and attack.move != null and attack.move.tier != "super":
		for eb in [PlayerInput.Btn.X, PlayerInput.Btn.Y, PlayerInput.Btn.B]:
			if input.pressed(eb):
				attack.interrupt()
				if _try_slot(_slot_for(eb), eb):
					_buf_t = 0.0
					return
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
				start_attack(MoveDB.get_move_for(cur.chain_next, class_id), _buf_btn)
				return
			if attack.can_cancel() and id != head and _try_slot(_buf_slot, _buf_btn):
				_buf_t = 0.0
				return
	# dash cancel on hit
	if input.pressed(PlayerInput.Btn.DASH) and _dash_cd <= 0.0 and attack.can_cancel() and (is_on_floor() or not _air_dash_used):
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
	_dash_cd = 0.7
	if not is_on_floor():
		_air_dash_used = true
	velocity = Vector2(dir * 640.0, 0.0)
	invuln = maxf(invuln, 0.12)  # a few i-frames at the start only
	_ghost = true
	set_collision_mask_value(5, false)  # phase through barriers
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


## LB: grab. A crate or barrel in reach is picked up, otherwise the grab move reaches for an enemy in front.
func _try_grab() -> void:
	if _try_pickup():
		return
	var m := MoveDB.get_move_for("grab_throw", class_id)
	if m != null and is_on_floor():
		start_attack(m, PlayerInput.Btn.LB)


func _try_pickup() -> bool:
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
		return true
	return false


## Throw direction from the stick (analog), neutral = forward. A little upward bias so a flat throw still arcs up.
func throw_dir() -> Vector2:
	var d := input.dir
	if d.length() < 0.35:
		d = Vector2(float(facing), 0.0)
	else:
		d = d.normalized()
	d.y -= 0.16
	return d.normalized()


const THROW_SPEED_ENEMY := 1000.0
const THROW_SPEED_ALLY := 1000.0
const THROW_SPEED_PROP := 1650.0


## Throwing the partner is a high arc (about 40 degrees when neutral) so gaps can be cleared; the stick steepens or
## flattens it. They are flung in a floaty jump (see _begin_fling), so the arc is longer than for an enemy.
func ally_throw_dir() -> Vector2:
	var d := input.dir
	if d.length() < 0.35:
		d = Vector2(float(facing), 0.0)
	else:
		d = d.normalized()
	d.y -= 0.85
	return d.normalized()


func _throw_held() -> void:
	if held != null and is_instance_valid(held):
		var td := throw_dir()
		held.global_position = global_position + Vector2(float(facing) * 18.0, -34.0 if td.y > -0.5 else -70.0)  # released at chest height, not from above the head
		held.thrown(td * THROW_SPEED_PROP, self)
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
	set_collision_layer_value(3, false)  # a KO'd player is not an obstacle: the partner walks (and dashes) straight over
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
	Coop.stat_rescues += 1
	hp = max_hp * 0.3
	revive_progress = 0.0
	state = "getup"
	set_collision_layer_value(3, true)
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
			Fx.number(parent, global_position + Vector2(0, -100), "+20 HEALTH", Color(2.0, 1.7, 1.9), 22)
		"hp_m":
			heal(50.0)
			Fx.number(parent, global_position + Vector2(0, -100), "+50 HEALTH", Color(2.0, 1.7, 1.9), 24)
		"dmg":
			add_buff("dmg", 12.0)
			Fx.number(parent, global_position + Vector2(0, -100), "DAMAGE UP 12s", Color(2.2, 0.8, 0.3), 22)
		"speed":
			add_buff("speed", 12.0)
			Fx.number(parent, global_position + Vector2(0, -100), "SPEED UP 12s", Color(1.7, 1.0, 2.2), 22)
		"shield":
			shield_hits = 3
			Fx.number(parent, global_position + Vector2(0, -100), "SHIELD: BLOCKS 3 HITS", Color(1.9, 1.9, 2.2), 20)
		"meter":
			meter = minf(100.0, meter + 50.0)
			Fx.number(parent, global_position + Vector2(0, -100), "+50% SUPER", Color(2.0, 1.8, 0.5), 22)
	Sfx.play("pickup")
	Fx.ring(parent, global_position + Vector2(0, -45), Color(1.6, 1.8, 2.0), 70.0, 0.3)


# ------------------------------------------------------------------ visuals

## Crouching under a HIGH attack or projectile avoids it. MID and LOW still hit.
func is_crouched() -> bool:
	return _crouch >= 0.6 and is_on_floor()


func _dodges(info: HitInfo) -> bool:
	if info.height == "high" and info.attacker != self and is_crouched() and not info.friendly:
		Fx.number(get_parent(), global_position + Vector2(0, -body_h - 8.0), "DUCK", Color(1, 1, 1, 0.8), 16)
		return true
	return false


func _loco_pose() -> Dictionary:
	var p := _loco_pose_base()
	var base := _base_pose()
	if not base.is_empty() and not p.is_empty():
		if state == "idle" or state == "land":
			p = base.duplicate() if state == "idle" else PoseLib.blend(p, base, 0.5)
		else:
			# walk: legs animate, the arms (and weapon) keep the class guard. Jump / fall: the arms mostly follow the air pose
			# (thrown up, trailing) so a weapon class does not hover in a rigid guard; the weapon stays in the hand
			var air := state == "jump" or state == "fall"
			for k in ["ua_f", "la_f", "ua_b", "la_b", "wp_rot", "root_y"]:
				if base.has(k):
					if air and k in ["ua_f", "la_f", "ua_b", "la_b"] and p.has(k):
						p[k] = lerpf(float(base[k]), float(p[k]), 0.8)
					else:
						p[k] = base[k]
	if _crouch > 0.01 and not p.is_empty():
		p = PoseLib.blend(p, PoseLib.crouch(), _crouch)
	return p


func _loco_pose_base() -> Dictionary:
	var p: Dictionary
	match state:
		"land":
			p = PoseLib.land()
		"jump":
			p = PoseLib.rise(velocity.y, Time.get_ticks_msec() / 1000.0 + player_index)
		"fall":
			p = PoseLib.fall(velocity.y, Time.get_ticks_msec() / 1000.0 + player_index)
		"ledge":
			p = PoseLib.hang()
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
	# loose, springy limbs while airborne (underdamped pose spring = natural overshoot and settle)
	var airborne := (state == "jump" or state == "fall") and not attack.active
	if airborne:
		figure.follow_speed = 30.0
		figure.zeta = 0.7
		_air_spring = true
	elif _air_spring and not attack.active:
		_air_spring = false
		figure.follow_speed = 36.0
		figure.zeta = 1.0
	# eyes follow the stick (falling back to the facing direction); figure space is flipped by facing
	var aim_w := input.dir if input.dir.length() > 0.2 else Vector2(facing, 0)
	figure.aim = Vector2(aim_w.x * facing, aim_w.y)
	figure.squint = 1.0 if (state == "hurt" or state == "launched") else 0.0
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
		var txt := "HOLD RB" if Coop.revives_left > 0 else "NO REVIVES"
		draw_string(f, Vector2(-34, -92), txt, HORIZONTAL_ALIGNMENT_CENTER, 70.0, 13, Color(1, 1, 1, 0.8))
	if state == "ledge" and _ledge_climb <= 0.0:
		draw_arc(Vector2(0, -50), 34.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_ledge_t / LEDGE_SOLO_TIME, 0.0, 1.0), 32, Color(2.0, 1.5, 0.4), 5.0, true)
	if (attack.active and attack.aiming) or (held != null and is_instance_valid(held)):
		_draw_throw_aim(held != null)
	if Dbg.enabled:
		draw_rect(Rect2(-body_w * 0.5, -body_h, body_w, body_h), Color(1, 1, 0, 0.8), false, 1.0)
		draw_line(Vector2.ZERO, Vector2(facing * 30.0, 0), Color(1, 0.4, 0.2), 2.0)
		if attack.active:
			draw_rect(Rect2(debug_hit_rect.position - global_position, debug_hit_rect.size), Color(1, 0.2, 0.2, 0.9), false, 2.0)


func debug_text() -> String:
	return "P%d %-8s hp=%3.0f meter=%3.0f pos(%4.0f,%4.0f) v(%5.0f,%5.0f) floor=%s %s\n    dir(%+.2f,%+.2f) btns: %s" % [
		player_index + 1, state, hp, meter, global_position.x, global_position.y, velocity.x, velocity.y,
		is_on_floor(), attack.move.id if attack.active else "", input.dir.x, input.dir.y, input.buttons_string()]


# ------------------------------------------------------------------ ledge grab

## While falling next to a pit edge or platform end, grab it and hang.
func _try_ledge() -> bool:
	var lvl := get_parent()
	if lvl == null or not lvl.has_method("ledge_points"):
		return false
	for l: Dictionary in lvl.ledge_points():
		var c: Vector2 = l["p"]
		if int(l["dir"]) != facing:
			continue
		var dxf := (c.x - global_position.x) * float(facing)
		var dy := c.y - (global_position.y - 96.0)
		if dxf >= 2.0 and dxf <= 36.0 and dy >= -24.0 and dy <= 40.0:
			_ledge = l
			state = "ledge"
			_ledge_t = 0.0
			_ledge_climb = 0.0
			velocity = Vector2.ZERO
			global_position = Vector2(c.x - float(facing) * 16.0, c.y + LEDGE_HANG_Y)
			_air_dash_used = false
			_air_jump_ready = true
			Sfx.play("pickup", 1.3)
			Fx.dust(get_parent(), c, 4)
			return true
	return false


func _st_ledge(delta: float) -> void:
	velocity = Vector2.ZERO
	if _ledge_climb > 0.0:
		# pulling up: slide from the hang to the top of the ledge
		_ledge_climb = maxf(0.0, _ledge_climb - delta)
		var k := 1.0 - _ledge_climb / 0.22
		global_position = _ledge_from.lerp(_ledge_to, k)
		if _ledge_climb <= 0.0:
			global_position = _ledge_to
			state = "idle"
			_ledge = {}
			_ledge_cd = 0.4
			Fx.dust(get_parent(), global_position, 6)
		return
	if input.pressed(PlayerInput.Btn.JUMP) or input.dir.y > 0.7:
		state = "fall"
		_ledge = {}
		_ledge_cd = 0.5
		velocity = Vector2(-float(facing) * 60.0, -200.0 if input.pressed(PlayerInput.Btn.JUMP) else 60.0)
		return
	_ledge_t += delta
	var helped := false
	var p := Coop.partner_of(self)
	if p != null and p.is_alive() and p.state != "downed" and absf(p.global_position.x - global_position.x) < 160.0 and absf(p.global_position.y - global_position.y) < 180.0:
		if p.input.pressed(PlayerInput.Btn.INTERACT) or p.input.pressed(PlayerInput.Btn.LB):
			helped = true
	if helped or _ledge_t >= LEDGE_SOLO_TIME:
		var c: Vector2 = _ledge["p"]
		_ledge_from = global_position
		_ledge_to = Vector2(c.x + float(facing) * 26.0, c.y - 1.0)
		_ledge_climb = 0.22
		if helped:
			Fx.ring(get_parent(), global_position + Vector2(0, -60), Color(2.0, 1.7, 1.9), 60.0, 0.3)
			Fx.number(get_parent(), global_position + Vector2(0, -130), "HELP!", Color(2.0, 1.7, 1.9), 22)
			Sfx.play("revive", 1.2)


## Small arrow plus a dotted arc showing where the throw will go (drawn in world-aligned local space).
func _draw_throw_aim(is_prop: bool) -> void:
	var col := Color(2.0, 1.6, 0.4)
	var ally := attack.active and attack.aiming and attack.grabbed is Fighter
	var dir := ally_throw_dir() if ally else throw_dir()
	var speed := THROW_SPEED_PROP if is_prop else (THROW_SPEED_ALLY if ally else THROW_SPEED_ENEMY)
	var grav := GRAVITY * (0.55 if ally else 1.0)
	var start := Vector2(0, -body_h - 8.0) if is_prop else Vector2(0, -90.0)
	# dotted arc: x = v t, y = v t + g t^2 / 2
	for i in range(1, 6):
		var t := 0.045 * float(i)
		var p := start + dir * speed * t + Vector2(0, 0.5 * grav * t * t)
		draw_circle(p, 3.2 - 0.3 * float(i), Color(col.r, col.g, col.b, 0.9 - 0.12 * float(i)))
	var tip := start + dir * 60.0
	var perp := Vector2(-dir.y, dir.x)
	draw_line(start + dir * 20.0, tip, col, 4.0, true)
	draw_colored_polygon(PackedVector2Array([tip + dir * 16.0, tip + perp * 8.0, tip - perp * 8.0]), col)


# ------------------------------------------------------------------ being thrown by the partner

## Grab & Throw on the partner: instead of falling, the thrown player is flung in a fast, floaty jump and can act out
## of it (attacks, dash, double jump). The body also checks enemies on the way: a combo starter.
func thrown(vel: Vector2, by: Actor) -> void:
	if by != null and by.team == team:
		_begin_fling(vel)
	else:
		super.thrown(vel, by)


func _begin_fling(vel: Vector2) -> void:
	if attack.active:
		attack.interrupt()
	state = "jump"
	holder = null
	velocity = vel
	_flung_t = 1.6
	_fling_grace = 0.12
	_toss_hit.clear()
	figure.rot = 0.0
	invuln = maxf(invuln, 0.25)
	_air_dash_used = false
	_air_jump_ready = true
	_jumping = false
	global_position.y -= 8.0
	Sfx.play("whoosh", 0.8)
	Fx.ring(get_parent(), global_position + Vector2(0, -40), Color(2.0, 1.7, 1.9), 70.0, 0.3)


func _flung_tick(delta: float, on_floor: bool) -> void:
	_flung_t = maxf(0.0, _flung_t - delta)
	if on_floor and _flung_t < 0.8:
		_flung_t = 0.0
		return
	_ghost_tick -= delta
	if _ghost_tick <= 0.0:
		_ghost_tick = 0.05
		Fx.afterimage(get_parent(), figure, Color(2.0, 1.6, 0.5))
	if velocity.length() < 450.0:
		return
	var rect := Rect2(global_position.x - 30.0 + signf(velocity.x if velocity.x != 0.0 else float(facing)) * 24.0, global_position.y - 95.0, 68.0, 100.0)
	for t in get_tree().get_nodes_in_group("hurt_enemy"):
		if not t.is_targetable() or _toss_hit.has(t.get_instance_id()) or not (t is Actor):
			continue
		if rect.intersects(t.get_hurt_rect()):
			_toss_hit[t.get_instance_id()] = true
			var info := HitInfo.new()
			info.attacker = self
			info.team = "player"
			info.dmg = 16.0 * dmg_mult()
			info.kind = "launch"
			info.kb = Vector2(signf(velocity.x if velocity.x != 0.0 else float(facing)) * 300.0, -620.0)  # pops them up for the follow-up
			info.stun = 34
			info.stop = 6
			info.shake = 0.35
			info.color = Color(2.0, 1.6, 0.5)
			info.pos = rect.get_center()
			if t.take_hit(info):
				freeze = maxi(freeze, 4)
				meter = minf(100.0, meter + 6.0)


# ------------------------------------------------------------------ supers (double quarter-circle forward + X / B)

## Remember the stick as one of: D (down), DF (down-forward), F (forward), N (anything else).
func _record_motion() -> void:
	var d := input.dir
	var sy := 1 if d.y > 0.5 else (-1 if d.y < -0.5 else 0)
	var sx := 1 if d.x > 0.5 else (-1 if d.x < -0.5 else 0)
	var fwd := sx * facing
	var tok := "N"
	if sy > 0 and fwd == 0:
		tok = "D"
	elif sy > 0 and fwd > 0:
		tok = "DF"
	elif sy == 0 and fwd > 0:
		tok = "F"
	var now := Engine.get_physics_frames()
	if _dir_hist.is_empty() or _dir_hist[_dir_hist.size() - 1][1] != tok:
		_dir_hist.append([now, tok])
	while not _dir_hist.is_empty() and now - int(_dir_hist[0][0]) > 90:
		_dir_hist.pop_front()
	while _dir_hist.size() > 16:
		_dir_hist.pop_front()


## True when the recent stick history contains down, forward, down, forward (down-forward may sit between): a double
## quarter-circle forward, entered within the last 1.5 s and finished at most 0.25 s ago.
func _motion_ready() -> bool:
	var now := Engine.get_physics_frames()
	var want := ["D", "F", "D", "F"]
	var wi := 0
	var last_f := -1000
	for e in _dir_hist:
		if wi < want.size() and e[1] == want[wi]:
			wi += 1
			if wi == want.size():
				last_f = int(e[0])
	if wi < want.size():
		return false
	# F is the last token recorded while held; allow the stick still being on forward or released shortly after
	var tail: String = _dir_hist[_dir_hist.size() - 1][1]
	return tail == "F" or now - last_f <= 15 or now - int(_dir_hist[_dir_hist.size() - 1][0]) <= 15


func _try_super(class_super: bool) -> bool:
	if not is_on_floor() or meter < MoveDBSupers.COST or not _motion_ready():
		return false
	var id: String = "super_generic"
	if class_super and class_id != "":
		id = String(MoveDBSupers.CLASS_SUPER.get(class_id, "super_generic"))
	var m := MoveDB.get_move_for(id, class_id)
	if m == null:
		return false
	meter -= MoveDBSupers.COST
	_dir_hist.clear()
	start_attack(m, PlayerInput.Btn.B if class_super else PlayerInput.Btn.X)
	Fx.ring(get_parent(), global_position + Vector2(0, -50), Color(2.0, 1.7, 0.5), 140.0, 0.4)
	Fx.number(get_parent(), global_position + Vector2(0, -135), m.name.to_upper() + "!", Color(2.0, 1.7, 0.5), 26)
	Juice.zoom_punch(0.08)
	Sfx.play("relay")
	return true
