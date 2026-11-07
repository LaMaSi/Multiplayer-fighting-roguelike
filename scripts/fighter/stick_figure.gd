class_name StickFigure
extends Node2D
## Articulated neon stickfigure drawn in code. Origin = feet on the ground, +x = forward.
## A pose is a Dictionary of joint angles (radians). Angle 0 = limb hanging straight down,
## positive = swung forward. Elbow/knee keys are the BEND relative to the parent limb.
## The hip height is solved so the lowest foot always touches y = 0.

const HEAD_R := 11.0
const NECK := 7.0
const TORSO := 30.0
const UARM := 17.0
const LARM := 17.0
const THIGH := 22.0
const SHIN := 22.0

const NEUTRAL := {
	"lean": 0.0, "head": 0.0, "root_x": 0.0, "root_y": 0.0,
	"ua_f": 0.2, "la_f": 0.3, "ua_b": 0.1, "la_b": 0.3,
	"th_f": 0.0, "kn_f": 0.05, "th_b": 0.0, "kn_b": 0.05,
}

var color := Color(0.3, 1.5, 1.8)
var pose: Dictionary = NEUTRAL.duplicate()
var target: Dictionary = NEUTRAL.duplicate()
var follow_speed := 24.0  ## how fast the pose chases the target (higher = snappier)


func set_target(t: Dictionary, snap := false) -> void:
	target = NEUTRAL.merged(t, true)
	if snap:
		pose = target.duplicate()


func _process(delta: float) -> void:
	var k := 1.0 - exp(-follow_speed * delta)
	for key in pose:
		pose[key] = lerpf(pose[key], target[key], k)
	queue_redraw()


static func _v(angle: float, length: float) -> Vector2:
	return Vector2(sin(angle), cos(angle)) * length


func _draw() -> void:
	_render(true)
	_render(false)


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

	# back arm, back leg
	_limb(shoulder, _v(float(p["ua_b"]), UARM), _v(float(p["ua_b"]) + float(p["la_b"]), LARM), 4.5, col_b, halo)
	_limb(hip, kn_b_pos, ft_b_off, 5.0, col_b, halo)
	# torso + neck
	_seg(hip, neck_base + head_dir * NECK, 6.0, col_f, halo)
	# front leg
	_limb(hip, kn_f_pos, ft_f_off, 5.5, col_f, halo)
	# head
	if halo:
		draw_circle(head_c, HEAD_R + 5.0, Color(col_f.r, col_f.g, col_f.b, 0.12))
	else:
		draw_circle(head_c, HEAD_R - 1.0, Color(0.03, 0.02, 0.08))
		draw_arc(head_c, HEAD_R, 0.0, TAU, 28, col_f, 3.5, true)
		draw_circle(head_c + Vector2(5.0, -1.0), 2.0, col_f)
	# front arm
	_limb(shoulder, _v(float(p["ua_f"]), UARM), _v(float(p["ua_f"]) + float(p["la_f"]), LARM), 5.0, col_f, halo)


func _limb(origin: Vector2, a_off: Vector2, b_off: Vector2, w: float, col: Color, halo: bool) -> void:
	var mid := origin + a_off
	var end := mid + b_off
	_seg(origin, mid, w, col, halo)
	_seg(mid, end, w, col, halo)


func _seg(a: Vector2, b: Vector2, w: float, col: Color, halo: bool) -> void:
	if halo:
		var hc := Color(col.r, col.g, col.b, 0.14)
		w += 8.0
		draw_line(a, b, hc, w, true)
		draw_circle(a, w * 0.5, hc)
		draw_circle(b, w * 0.5, hc)
	else:
		draw_line(a, b, col, w, true)
		draw_circle(a, w * 0.5, col)
		draw_circle(b, w * 0.5, col)
