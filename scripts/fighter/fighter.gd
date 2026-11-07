class_name Fighter
extends CharacterBody2D
## A player character (M0: locomotion only). Origin = feet. Physics layers:
## 1 ground, 2 one-way platforms, 3 players.

const RUN_SPEED := 330.0
const ACCEL := 2800.0
const AIR_ACCEL := 1800.0
const FRICTION := 3400.0
const AIR_FRICTION := 600.0
const GRAVITY := 2300.0
const FALL_MULT := 1.35
const MAX_FALL := 1500.0
const JUMP_V := -880.0
const COYOTE := 0.09
const JUMP_BUFFER := 0.12
const DROP_MAX_TIME := 0.6
const BODY_W := 34.0
const BODY_H := 86.0
const PLAYER_COLORS := [Color(0.25, 1.4, 1.9), Color(1.9, 0.35, 1.5)]

@export var player_index := 0

var input: PlayerInput
var facing := 1
var state := "idle"
var spawn_point := Vector2.ZERO
var kill_y := 1400.0
var figure: StickFigure

var _coyote := 0.0
var _jump_buf := 0.0
var _jumping := false
var _drop_t := 0.0
var _drop_clear_y := 0.0
var _floor_collider: Object = null
var _was_on_floor := false
var _land_t := 0.0
var _walk_phase := 0.0
var _squash := Vector2.ONE
var _dbg_was := false


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = 0
	set_collision_layer_value(3, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	floor_snap_length = 8.0

	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = BODY_W * 0.5
	cap.height = BODY_H
	cs.shape = cap
	cs.position = Vector2(0, -BODY_H * 0.5)
	add_child(cs)

	figure = StickFigure.new()
	figure.color = PLAYER_COLORS[player_index % PLAYER_COLORS.size()]
	add_child(figure)
	figure.set_target(PoseLib.idle(0.0), true)

	input = Inp.players[player_index]
	spawn_point = global_position


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# --- horizontal ---
	var mx := input.dir.x
	if absf(mx) < 0.2:
		mx = 0.0
	if mx != 0.0:
		facing = 1 if mx > 0.0 else -1
		var a := ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, mx * RUN_SPEED, a * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if on_floor else AIR_FRICTION) * delta)
	# standing on the other player's head: slide off so nobody gets stuck up there
	if on_floor and _floor_collider is Fighter:
		var other := _floor_collider as Fighter
		var away := signf(global_position.x - other.global_position.x)
		velocity.x = (away if away != 0.0 else float(facing)) * 160.0

	# --- vertical ---
	if on_floor:
		_coyote = COYOTE
		_jumping = false
		velocity.y = 50.0  # keep pressing into the floor so we always get a floor collision
	else:
		_coyote -= delta
		var g := GRAVITY * (FALL_MULT if velocity.y > 0.0 else 1.0)
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	# --- jump / drop through ---
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
			_squash = Vector2(0.8, 1.25)
			Fx.dust(get_parent(), global_position, 6)
	if input.released(PlayerInput.Btn.JUMP) and _jumping and velocity.y < 0.0:
		velocity.y *= 0.45
		_jumping = false

	if _drop_t > 0.0:
		_drop_t -= delta
		if global_position.y - BODY_H > _drop_clear_y or _drop_t <= 0.0:
			_drop_t = 0.0
			set_collision_mask_value(2, true)

	# --- move ---
	var vy_before := velocity.y
	move_and_slide()

	_floor_collider = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.6:
			_floor_collider = c.get_collider()

	# --- landing ---
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor and vy_before > 250.0:
		var k := clampf(vy_before / 1500.0, 0.12, 0.35)
		_squash = Vector2(1.0 + k, 1.0 - k)
		_land_t = 0.10 if vy_before > 600.0 else 0.0
		Fx.dust(get_parent(), global_position, 8)
	_was_on_floor = now_floor
	_land_t = maxf(0.0, _land_t - delta)

	if global_position.y > kill_y:
		respawn()

	_update_visuals(delta)


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
	global_position = spawn_point
	velocity = Vector2.ZERO
	_drop_t = 0.0
	set_collision_mask_value(2, true)


func _update_visuals(delta: float) -> void:
	var floor_now := is_on_floor()
	var pose: Dictionary
	if _land_t > 0.0:
		state = "land"
		pose = PoseLib.land()
	elif not floor_now:
		state = "jump" if velocity.y < 0.0 else "fall"
		pose = PoseLib.rise() if velocity.y < 0.0 else PoseLib.fall()
	elif absf(velocity.x) > 25.0:
		state = "walk"
		var dir_sign := 1.0 if velocity.x * facing >= 0.0 else -1.0
		_walk_phase += absf(velocity.x) * 0.055 * delta * dir_sign
		pose = PoseLib.walk(_walk_phase)
	else:
		state = "idle"
		pose = PoseLib.idle(Time.get_ticks_msec() / 1000.0 + player_index)
	figure.set_target(pose)

	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	figure.scale = Vector2(facing * _squash.x, _squash.y)

	if Dbg.enabled or _dbg_was:
		queue_redraw()
	_dbg_was = Dbg.enabled


func _draw() -> void:
	if Dbg.enabled:
		draw_rect(Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H), Color(1, 1, 0, 0.8), false, 1.0)
		draw_line(Vector2.ZERO, Vector2(facing * 30.0, 0), Color(1, 0.4, 0.2), 2.0)


func debug_text() -> String:
	return "P%d %-5s pos(%4.0f,%4.0f) v(%5.0f,%5.0f) floor=%s drop=%s\n    dir(%+.2f,%+.2f) btns: %s" % [
		player_index + 1, state, global_position.x, global_position.y, velocity.x, velocity.y,
		is_on_floor(), _drop_t > 0.0, input.dir.x, input.dir.y, input.buttons_string()]
