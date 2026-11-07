extends Node
## Autoload "Juice": camera trauma-shake and zoom punch, plus brief slow motion.

var trauma := 0.0
var punch := 0.0
var _slow_token := 0


func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func zoom_punch(amount: float) -> void:
	punch = maxf(punch, amount)


func slowmo(scale: float, real_seconds: float) -> void:
	_slow_token += 1
	var tok := _slow_token
	Engine.time_scale = scale
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if tok == _slow_token:
		Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var d := delta / maxf(Engine.time_scale, 0.05)
	trauma = maxf(0.0, trauma - 1.6 * d)
	punch = maxf(0.0, punch - 0.9 * d)
