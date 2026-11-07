class_name StickFigure
extends Node2D
## Articulated neon stickfigure drawn in code. Origin = feet on the ground, +x = forward.
## A pose is a Dictionary of joint angles (radians). Angle 0 = limb hanging straight down,
## positive = swung forward. Elbow/knee keys are the BEND relative to the parent limb.
## The hip height is solved so the lowest foot always touches y = 0.
## `rot` spins the whole body around its middle; pose key `lie` (0..1) lowers that pivot.
##
## Animation: the pose chases its target with a damped SPRING. zeta < 1 overshoots and
## settles (anticipation -> strike -> overshoot -> follow-through). Extra pose keys exaggerate
## strikes: fist_*/foot_* scale the hand/foot, reach_*/legr_* stretch or contract the limbs.
## Fast limb tips leave a fading swoosh trail while `trail_on`.

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
	"fist_f": 1.0, "fist_b": 1.0, "reach_f": 1.0, "reach_b": 1.0,
	"foot_f": 1.0, "foot_b": 1.0, "legr_f": 1.0, "legr_b": 1.0,
}

var color := Color(0.3, 1.5, 1.8)
var style := ""  ## "", "helmet", "crown", "cap", "horns", "hood"
## body build (enemies differ from the round-headed, line-only players)
var arm_scale := 1.0  ## limb lengths (players have longer arms and legs)
var leg_scale := 1.0
var limb_scale := 1.0
var head_scale := 1.0
var fill_torso := false
var square_head := false

var pose: Dictionary = NEUTRAL.duplicate()
var target: Dictionary = NEUTRAL.duplicate()
var follow_speed := 28.0  ## spring frequency (rad/s)
var zeta := 1.0  ## damping ratio: 1 = no overshoot, ~0.5 = snappy with overshoot
var rot := 0.0
var jitter := 0.0  ## hit-stop shake amplitude in px
var frozen := false  ## hit-stop: hold the pose
var trail_on := false

## filled while drawing (figure-local space, rotation applied)
var head_pos := Vector2(0, -80)
var hand_f_pos := Vector2(20, -50)
var hand_b_pos := Vector2(10, -50)
var foot_f_pos := Vector2(10, 0)
var foot_b_pos := Vector2(-10, 0)

var _vel: Dictionary = {}
var _trail: Array = []


func set_target(t: Dictionary, snap := false) -> void:
	target = NEUTRAL.merged(t, true)
	if snap:
		pose = target.duplicate()
		_vel.clear()


func _process(delta: float) -> void:
	if not frozen:
		var dt := minf(delta, 1.0 / 30.0)
		var w := follow_speed
		var k := w * w
		var c := 2.0 * zeta * w
		for key in pose:
			var v: float = _vel.get(key, 0.0)
			var p: float = pose[key]
			v += (k * (float(target[key]) - p) - c * v) * dt
			_vel[key] = v
			pose[key] = p + v * dt
		if trail_on:
			_trail.push_back([to_global(hand_f_pos), to_global(hand_b_pos), to_global(foot_f_pos), to_global(foot_b_pos)])
			if _trail.size() > 8:
				_trail.pop_front()
		elif not _trail.is_empty():
			_trail.pop_front()
	queue_redraw()


static func _v(angle: float, length: float) -> Vector2:
	return Vector2(sin(angle), cos(angle)) * length


func _draw() -> void:
	var pivot_y := lerpf(-40.0 * leg_scale, -9.0, clampf(float(pose["lie"]), 0.0, 1.0))
	var pivot := Vector2(0, pivot_y)
	var off := Vector2.ZERO
	if jitter > 0.0:
		off = Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	draw_set_transform(pivot - pivot.rotated(rot) + off, rot)
	_render(true)
	_render(false)
	draw_set_transform(Vector2.ZERO, 0.0)
	# store rotated tip positions for trails / attachments
	var m := pivot - pivot.rotated(rot)
	hand_f_pos = m + hand_f_pos.rotated(rot)
	hand_b_pos = m + hand_b_pos.rotated(rot)
	foot_f_pos = m + foot_f_pos.rotated(rot)
	foot_b_pos = m + foot_b_pos.rotated(rot)
	head_pos = m + head_pos.rotated(rot)
	_draw_trails()


## Swoosh ribbons: a filled strip along the recent path of each fast limb tip. The width is 0 at
## the old end, swells toward the limb and comes to a point at the tip (no blunt line ends).
func _draw_trails() -> void:
	var n := _trail.size()
	if n < 3:
		return
	var c := Color(minf(color.r + 0.5, 2.6), minf(color.g + 0.5, 2.6), minf(color.b + 0.5, 2.6))
	for tip in 4:
		var pts: Array[Vector2] = []
		var total := 0.0
		for i in n:
			pts.append(to_local(_trail[i][tip]))
			if i > 0:
				total += pts[i - 1].distance_to(pts[i])
		if total < 30.0 or total > 900.0:
			continue
		var left: Array[Vector2] = []
		var right: Array[Vector2] = []
		for i in n:
			var dir := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
			if dir.length() < 0.001:
				dir = Vector2.RIGHT
			var nrm := Vector2(-dir.y, dir.x).normalized()
			var s := float(i) / float(n - 1)
			var w := 15.0 * pow(maxf(sin(PI * pow(s, 2.4)), 0.0), 0.9)
			left.append(pts[i] + nrm * w)
			right.append(pts[i] - nrm * w)
		for i in range(1, n):
			var s2 := float(i) / float(n - 1)
			var col := Color(c.r, c.g, c.b, 0.12 + 0.6 * s2)
			# two triangles per segment: never self-intersecting, even on sharp bends
			_tri(left[i - 1], left[i], right[i], col)
			_tri(left[i - 1], right[i], right[i - 1], col)


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if absf((b - a).cross(c - a)) < 1.0:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), col)


func _render(halo: bool) -> void:
	var p := pose
	var lean: float = p["lean"]
	var th_f: float = p["th_f"]
	var th_b: float = p["th_b"]
	var lr_f: float = p["legr_f"]
	var lr_b: float = p["legr_b"]
	var kn_f_pos := _v(th_f, THIGH * lr_f * leg_scale)
	var ft_f_off := _v(th_f - float(p["kn_f"]), SHIN * lr_f * leg_scale)
	var kn_b_pos := _v(th_b, THIGH * lr_b * leg_scale)
	var ft_b_off := _v(th_b - float(p["kn_b"]), SHIN * lr_b * leg_scale)
	var hip := Vector2(p["root_x"], -maxf(kn_f_pos.y + ft_f_off.y, kn_b_pos.y + ft_b_off.y) + float(p["root_y"]))

	var hr := HEAD_R * head_scale
	var ls := limb_scale
	var up := Vector2(sin(lean), -cos(lean))
	var neck_base := hip + up * TORSO
	var shoulder := hip + up * (TORSO - 4.0)
	var head_ang := lean + float(p["head"])
	var head_dir := Vector2(sin(head_ang), -cos(head_ang))
	var head_c := neck_base + head_dir * (NECK + hr)

	var col_f := color
	var col_b := color.darkened(0.45)

	var ua_b: float = p["ua_b"]
	var ua_f: float = p["ua_f"]
	var rc_f: float = p["reach_f"]
	var rc_b: float = p["reach_b"]
	var arm_f_a := _v(ua_f, UARM * rc_f * arm_scale)
	var arm_f_b := _v(ua_f + float(p["la_f"]), LARM * rc_f * arm_scale)
	var arm_b_a := _v(ua_b, UARM * rc_b * arm_scale)
	var arm_b_b := _v(ua_b + float(p["la_b"]), LARM * rc_b * arm_scale)
	if not halo:
		head_pos = head_c
		hand_f_pos = shoulder + arm_f_a + arm_f_b
		hand_b_pos = shoulder + arm_b_a + arm_b_b
		foot_f_pos = hip + kn_f_pos + ft_f_off
		foot_b_pos = hip + kn_b_pos + ft_b_off

	# back arm, back leg
	_limb(shoulder, arm_b_a, arm_b_b, 4.5 * ls, col_b, halo, float(p["fist_b"]))
	_limb(hip, kn_b_pos, ft_b_off, 5.0 * ls, col_b, halo, float(p["foot_b"]))
	# torso + neck
	if fill_torso and not halo:
		var side := Vector2(cos(lean), sin(lean))
		var poly := PackedVector2Array([hip - side * 8.0 * ls, hip + side * 8.0 * ls, shoulder + side * 12.0 * ls, shoulder - side * 12.0 * ls])
		draw_colored_polygon(poly, Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1.0))
		draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), col_f, 2.5, true)
	_seg(hip, neck_base + head_dir * NECK, 6.0 * ls, col_f, halo)
	# front leg
	_limb(hip, kn_f_pos, ft_f_off, 5.5 * ls, col_f, halo, float(p["foot_f"]))
	# head
	if halo:
		draw_circle(head_c, hr + 3.5, Color(0.02, 0.01, 0.05, 0.88))
	else:
		if square_head:
			var rx := Vector2(cos(head_ang), sin(head_ang)) * hr
			var ry := Vector2(sin(head_ang), -cos(head_ang)) * hr
			var sq := PackedVector2Array([head_c - rx - ry, head_c + rx - ry, head_c + rx + ry, head_c - rx + ry])
			draw_colored_polygon(sq, Color(0.03, 0.02, 0.08))
			draw_polyline(PackedVector2Array([sq[0], sq[1], sq[2], sq[3], sq[0]]), col_f, 3.5, true)
			# angry visor
			draw_line(head_c + rx * 0.9 - ry * 0.1, head_c - rx * 0.1 + ry * 0.2, col_f, 3.0, true)
		else:
			draw_circle(head_c, hr - 1.0, Color(0.03, 0.02, 0.08))
			draw_arc(head_c, hr, 0.0, TAU, 28, col_f, 3.5, true)
			draw_circle(head_c + Vector2(5.0, -1.0).rotated(head_ang), 2.0, col_f)
		_accessory(head_c, col_f, hr)
	# front arm
	_limb(shoulder, arm_f_a, arm_f_b, 5.0 * ls, col_f, halo, float(p["fist_f"]))


func _accessory(h: Vector2, c: Color, hr: float) -> void:
	match style:
		"helmet":
			draw_arc(h, hr + 3.0, PI, TAU, 14, c, 4.5, true)
			draw_line(h + Vector2(-hr - 3.0, 0), h + Vector2(hr + 3.0, 0), c, 3.0, true)
		"cap":
			draw_line(h + Vector2(-hr, -4), h + Vector2(hr + 9, -4), c, 3.5, true)
			draw_arc(h, hr, PI, TAU, 12, c, 4.0, true)
		"crown":
			var b := h + Vector2(0, -hr - 1)
			draw_polyline(PackedVector2Array([b + Vector2(-12, 0), b + Vector2(-12, -11), b + Vector2(-6, -4), b + Vector2(0, -15), b + Vector2(6, -4), b + Vector2(12, -11), b + Vector2(12, 0)]), c, 3.5, true)
		"horns":
			draw_line(h + Vector2(-7, -8), h + Vector2(-13, -20), c, 3.5, true)
			draw_line(h + Vector2(7, -8), h + Vector2(13, -20), c, 3.5, true)
		"hood":
			draw_polyline(PackedVector2Array([h + Vector2(-hr - 2, 4), h + Vector2(-2, -hr - 14), h + Vector2(hr + 2, 4)]), c, 4.0, true)


func _limb(origin: Vector2, a_off: Vector2, b_off: Vector2, w: float, col: Color, halo: bool, end_scale := 1.0) -> void:
	var mid := origin + a_off
	var end := mid + b_off
	_seg(origin, mid, w, col, halo)
	_seg(mid, end, w, col, halo)
	if not halo and end_scale > 1.05:
		draw_circle(end, w * 0.5 * end_scale, col)
		draw_circle(end, w * 0.25 * end_scale, Color(minf(col.r + 0.8, 3.0), minf(col.g + 0.8, 3.0), minf(col.b + 0.8, 3.0)))


func _seg(a: Vector2, b: Vector2, w: float, col: Color, halo: bool) -> void:
	if halo:
		var hc := Color(0.02, 0.01, 0.05, 0.88)  # dark outline: separates the figure from busy backgrounds
		w += 5.0
		draw_line(a, b, hc, w, true)
		draw_circle(a, w * 0.5, hc)
		draw_circle(b, w * 0.5, hc)
	else:
		draw_line(a, b, col, w, true)
		draw_circle(a, w * 0.5, col)
		draw_circle(b, w * 0.5, col)
