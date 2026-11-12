extends Node
## Autoload "Juice": camera trauma-shake, directional kick, zoom punch, and brief slow motion.

var trauma := 0.0
var punch := 0.0
var kick_vec := Vector2.ZERO  ## camera offset pushed toward the blow, decays quickly
var _slow_token := 0
## The time scale chosen in the options (for experimenting with timings). Hit-stop slow motion multiplies it and returns to it.
var user_time_scale := 1.0
const TIME_STEPS := [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
## How fast a level runs compared to the timings written in the code: the tempo of the whole world (moves, enemies,
## physics, effects). It stays at 1.0: above that the game read as fast-forwarded (jumps as leaden at 2.0), and a tick
## rate that is not the usual 60 steps unevenly against the screen, which made fast movement stutter. The players'
## speed comes from the fighter's own numbers instead (see Fighter.RUN_SPEED). Menus and shop screens stay at 1.0.
## Godot's time scale alone only stretches the physics step: speeds in px/s double while everything counted in frames
## (move startup / active / recovery, hit-stop, parry windows) does not, so dashes travel twice as far and multi-hit
## moves miss. That is why the tick rate rises with the scale here: each physics frame stays 1/60 s of game time and
## the whole game, moves included, speeds up evenly with every distance and combo as authored.
const GAME_SPEED := 1.0
const BASE_TICKS := 60
var base_speed := 1.0  ## GAME_SPEED inside a level, 1.0 in menus


## The speed everything returns to after a slow motion.
func normal_scale() -> float:
	return base_speed * user_time_scale


func _apply() -> void:
	_slow_token += 1  # cancel a running slow motion
	Engine.time_scale = normal_scale()
	# faster than 1.0: more ticks, each still 1/60 s. Slower: the same 60 ticks with smaller steps (smooth slow motion).
	Engine.physics_ticks_per_second = roundi(BASE_TICKS * maxf(1.0, normal_scale()))
	Engine.max_physics_steps_per_frame = maxi(8, ceili(maxf(1.0, normal_scale()) * 4.0))


## Back to normal menu speed: the user's chosen time scale (1.0 unless changed in the options).
func reset_time() -> void:
	base_speed = 1.0
	_apply()


## A level starts: run at GAME_SPEED (times the user's time scale).
func gameplay_time() -> void:
	base_speed = GAME_SPEED
	_apply()


func set_user_time_scale(v: float) -> void:
	user_time_scale = clampf(v, 0.05, 4.0)
	_apply()


func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount * 0.6)  # screen shake was too intense: scaled down globally


func zoom_punch(amount: float) -> void:
	punch = maxf(punch, amount * 0.7)


func kick(v: Vector2) -> void:
	kick_vec += v
	if kick_vec.length() > 46.0:
		kick_vec = kick_vec.normalized() * 46.0


func slowmo(scale: float, real_seconds: float) -> void:
	_slow_token += 1
	var tok := _slow_token
	Engine.time_scale = scale * normal_scale()
	# the authored length is for 60 ticks a second: at a higher tick rate it shrinks, so the same number of frames pass in slow motion
	await get_tree().create_timer(real_seconds / maxf(1.0, normal_scale()), true, false, true).timeout
	if tok == _slow_token:
		Engine.time_scale = normal_scale()


func _process(delta: float) -> void:
	var d := delta / maxf(Engine.time_scale, 0.05)
	trauma = maxf(0.0, trauma - 1.6 * d)
	punch = maxf(0.0, punch - 0.9 * d)
	kick_vec = kick_vec.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * d))
