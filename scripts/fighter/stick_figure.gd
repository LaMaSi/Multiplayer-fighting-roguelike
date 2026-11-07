class_name StickFigure
extends Node2D
## Articulated neon stickfigure drawn in code. Origin = feet on the ground, +x = forward.
## A pose is a Dictionary of joint angles (radians). Angle 0 = limb hanging straight down,
## positive = swung forward. Elbow/knee keys are the BEND relative to the parent limb.
## The hip height is solved so the lowest foot always touches y = 0.
## `rot` spins the whole body around its middle (flips, spin kicks, tumbling); pose key `lie`
## (0..1) lowers that pivot so a rotated body lies on the floor.

const HEAD_R := 11.0
const NECK := 7.0
const TORSO := 30.0
const UARM := 17.0
const LARM := 17.0
const THIGH := 22.0
const SHIN := 22.0

const NEUTRAL := {
	"lean": 0.0, "head": 0.0, "root_x": 0.0, "root_y": 0.0, "lie": 0.0,
	"ua_f": 0.2, "la_f": 0.3, "ua_b": 0.1, "la_b": 0.3,
	"th_f": 0.0, "kn_f": 0.05, "th_b": 0.0, "kn_b": 0.05,
}

var color := Color(0.3, 1.5, 1.8)
var style := ""  ## "", "helmet", "crown", "cap", "horns", "hood"
var pose: Dictionary = NEUTRAL.duplicate()
var target: Dictionary = NEUTRAL.duplicate()
var follow_speed := 24.0  ## how fast the pose chases the target (higher = snappier)
var rot := 0.0
var jitter := 0.0  ## hit-stop shake amplitude in px

## filled while drawing (figure-local space) so other code can attach things
var head_pos := Vector2(0, -80)
var hand_f_pos := Vector2(20, -50)
var hand_b_pos := Vector2(10, -50)
var foot_f_pos := Vector2(10, 0)
var foot_b_pos := Vector2(-10, 0)


func set_target(t: Dictionary, snap := false) -> void:
	target = NEUTRAL.merged(t, true)
	if snap:
		pose = target.duplicate()


func _process(delta: float) -> void:
	var k := 1.0 - exp(-follow_speed * delta) if follow_speed > 0.0 else 0.0
	for key in pose:
		pose[key] = lerpf(pose[key], target[key], k)
	queue_redraw()


static func _v(angle: float, length: float) -> Vector2:
	return Vector2(sin(angle), cos(angle)) * length


func _draw() -> void:
	var pivot_y := lerpf(-40.0, -9.0, clampf(float(pose["lie"]), 0.0, 1.0))
	var pivot := Vector2(0, pivot_y)
	var off := Vector2.ZERO
	if jitter > 0.0:
		off = Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	draw_set_transform(pivot - pivot.rotated(rot) + off, rot)
	_render(true)
	_render(false)
	draw_set_transform(Vector2.ZERO, 0.0)


func _render(halo: bool) -> void:
	var p := pose
	var lean: float = p["lean"]
	var th_f: float = p["th_f"]
	var th_b: float = p["th_b"]
	var kn_f_pos := _v(th_f, THIGH)
	var ft_f_off := _v(th_f - float(p["kn_f"]), SHIN)
	var kn_b_pos := _v(th_b, THIGH)
	var ft_b_off := _v(th_b - float(p["kn_b"]), SHIN)
	var hip := Vector2(p["root_x"], -maxf(kn_f_pos.y + ft_f_off.y, kn_b_pos.y + ft_b_off.y) + float(p["root_y"]))

	var up := Vector2(sin(lean), -cos(lean))
	var neck_base := hip + up * TORSO
	var shoulder := hip + up * (TORSO - 4.0)
	var head_dir := Vector2(sin(lean + float(p["head"])), -cos(lean + float(p["head"])))
	var head_c := neck_base + head_dir * (NECK + HEAD_R)

	var col_f := color
	var col_b := color.darkened(0.45)

	var ua_b: float = p["ua_b"]
	var ua_f: float = p["ua_f"]
	if not halo:
		head_pos = head_c
		hand_f_pos = shoulder + _v(ua_f, UARM) + _v(ua_f + float(p["la_f"]), LARM)
		hand_b_pos = shoulder + _v(ua_b, UARM) + _v(ua_b + float(p["la_b"]), LARM)
		foot_f_pos = hip + kn_f_pos + ft_f_off
		foot_b_pos = hip + kn_b_pos + ft_b_off

	# back arm, back leg
	_limb(shoulder, _v(ua_b, UARM), _v(ua_b + float(p["la_b"]), LARM), 4.5, col_b, halo)
	_limb(hip, kn_b_pos, ft_b_off, 5.0, col_b, halo)
	# torso + neck
	_seg(hip, neck_base + head_dir * NECK, 6.0, col_f, halo)
	# front leg
	_limb(hip, kn_f_pos, ft_f_off, 5.5, col_f, halo)
	# head
	if halo:
		draw_circle(head_c, HEAD_R + 4.0, Color(col_f.r, col_f.g, col_f.b, 0.05))
	else:
		draw_circle(head_c, HEAD_R - 1.0, Color(0.03, 0.02, 0.08))
		draw_arc(head_c, HEAD_R, 0.0, TAU, 28, col_f, 3.5, true)
		draw_circle(head_c + Vector2(5.0, -1.0).rotated(float(p["head"]) + lean), 2.0, col_f)
		_accessory(head_c, col_f)
	# front arm
	_limb(shoulder, _v(ua_f, UARM), _v(ua_f + float(p["la_f"]), LARM), 5.0, col_f, halo)


func _accessory(h: Vector2, c: Color) -> void:
	match style:
		"helmet":
			draw_arc(h, HEAD_R + 3.0, PI, TAU, 14, c, 4.0, true)
		"cap":
			draw_line(h + Vector2(-HEAD_R, -4), h + Vector2(HEAD_R + 8, -4), c, 3.5, true)
			draw_arc(h, HEAD_R, PI, TAU, 12, c, 4.0, true)
		"crown":
			var b := h + Vector2(0, -HEAD_R - 1)
			draw_polyline(PackedVector2Array([b + Vector2(-10, 0), b + Vector2(-10, -9), b + Vector2(-5, -3), b + Vector2(0, -12), b + Vector2(5, -3), b + Vector2(10, -9), b + Vector2(10, 0)]), c, 3.0, true)
		"horns":
			draw_line(h + Vector2(-7, -8), h + Vector2(-13, -20), c, 3.5, true)
			draw_line(h + Vector2(7, -8), h + Vector2(13, -20), c, 3.5, true)
		"hood":
			draw_arc(h, HEAD_R + 4.0, PI * 0.8, PI * 2.2, 14, c, 5.0, true)


func _limb(origin: Vector2, a_off: Vector2, b_off: Vector2, w: float, col: Color, halo: bool) -> void:
	var mid := origin + a_off
	var end := mid + b_off
	_seg(origin, mid, w, col, halo)
	_seg(mid, end, w, col, halo)


func _seg(a: Vector2, b: Vector2, w: float, col: Color, halo: bool) -> void:
	if halo:
		var hc := Color(col.r, col.g, col.b, 0.06)
		w += 6.0
		draw_line(a, b, hc, w, true)
		draw_circle(a, w * 0.5, hc)
		draw_circle(b, w * 0.5, hc)
	else:
		draw_line(a, b, col, w, true)
		draw_circle(a, w * 0.5, col)
		draw_circle(b, w * 0.5, col)
