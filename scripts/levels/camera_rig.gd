class_name CameraRig
extends Camera2D
## Shared camera: follows the midpoint of all targets, zooms out to keep both in view,
## shakes with Juice.trauma and punches in on heavy hits. set_bounds() locks it to an arena.

const MAX_ZOOM := 1.15

var targets: Array[Node2D] = []
var min_zoom := 0.62


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	enabled = true


func set_bounds(left: float, right: float) -> void:
	limit_left = int(left)
	limit_right = int(right)
	min_zoom = clampf(1280.0 / maxf(right - left, 1.0), 0.5, 1.0)


func snap() -> void:
	_update(1.0, true)
	reset_smoothing()


func _process(delta: float) -> void:
	_update(delta, false)
	var t2 := Juice.trauma * Juice.trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * t2 * 26.0 + Juice.kick_vec
	rotation = randf_range(-1.0, 1.0) * t2 * 0.025


func _update(delta: float, instant: bool) -> void:
	var live: Array[Node2D] = []
	for t in targets:
		if is_instance_valid(t):
			live.append(t)
	if live.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for t in live:
		var p := t.global_position - Vector2(0, 43)
		mn = mn.min(p)
		mx = mx.max(p)
	var span := mx - mn
	var fit := minf(1280.0 / (span.x + 700.0), 720.0 / (span.y + 420.0))
	var z := clampf(fit, min_zoom, MAX_ZOOM) * (1.0 + Juice.punch)
	var target_zoom := Vector2(z, z)
	zoom = target_zoom if instant else zoom.lerp(target_zoom, 1.0 - exp(-5.0 * delta))
	global_position = (mn + mx) * 0.5 + Vector2(0, -60)
