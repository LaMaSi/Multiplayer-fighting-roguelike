class_name CameraRig
extends Camera2D
## Shared camera: follows the midpoint of all targets and zooms out to keep both in view.
## (Soft tether, shake and zoom punch arrive in M1/M2.)

const MIN_ZOOM := 0.62
const MAX_ZOOM := 1.15

var targets: Array[Node2D] = []


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	enabled = true


func snap() -> void:
	_update(1.0, true)
	reset_smoothing()


func _process(delta: float) -> void:
	_update(delta, false)


func _update(delta: float, instant: bool) -> void:
	if targets.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for t in targets:
		var p := t.global_position - Vector2(0, 43)
		mn = mn.min(p)
		mx = mx.max(p)
	var span := mx - mn
	var fit := minf(1280.0 / (span.x + 700.0), 720.0 / (span.y + 420.0))
	var z := clampf(fit, MIN_ZOOM, MAX_ZOOM)
	var target_zoom := Vector2(z, z)
	zoom = target_zoom if instant else zoom.lerp(target_zoom, 1.0 - exp(-4.0 * delta))
	global_position = (mn + mx) * 0.5 + Vector2(0, -60)
