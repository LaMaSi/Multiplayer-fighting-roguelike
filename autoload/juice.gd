extends Node
## Autoload "Juice": camera trauma-shake, directional kick, zoom punch, and brief slow motion.

var trauma := 0.0
var punch := 0.0
var kick_vec := Vector2.ZERO  ## camera offset pushed toward the blow, decays quickly
var _slow_token := 0
## The time scale chosen in the options (for experimenting with timings). Hit-stop slow motion multiplies it and returns to it.
var user_time_scale := 1.0
const TIME_STEPS := [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]


## Back to normal speed: the user's chosen time scale (1.0 unless changed in the options).
func reset_time() -> void:
	Engine.time_scale = user_time_scale


func set_user_time_scale(v: float) -> void:
	user_time_scale = clampf(v, 0.05, 4.0)
	_slow_token += 1  # cancel a running slow motion
	Engine.time_scale = user_time_scale


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
	Engine.time_scale = scale * user_time_scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if tok == _slow_token:
		Engine.time_scale = user_time_scale


func _process(delta: float) -> void:
	var d := delta / maxf(Engine.time_scale, 0.05)
	trauma = maxf(0.0, trauma - 1.6 * d)
	punch = maxf(0.0, punch - 0.9 * d)
	kick_vec = kick_vec.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * d))
