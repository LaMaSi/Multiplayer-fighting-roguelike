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
const NECK := 2.0
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
	"wp_rot": 0.0,  ## sword: angle relative to the front forearm (negative = tip raised). hammer: absolute angle (see _draw_weapon)
}

var color := Color(0.3, 1.5, 1.8)
var style := ""  ## "", "helmet", "crown", "cap", "horns", "hood"
var weapon := ""  ## "", "sword", "hammer", "magic": drawn on the hands (code-drawn, no sprites)
var weapon_scale := 1.0
## body build (enemies differ from the round-headed, line-only players)
var arm_scale := 1.0  ## limb lengths (players have longer arms and legs)
var leg_scale := 1.0
var limb_scale := 1.0
var head_scale := 1.0
var fill_torso := false
var square_head := false
## cosmetic eyes (players only): aim is the wanted look direction in figure-local space
var eyes := false
var aim := Vector2.ZERO
var squint := 0.0  ## 0..1, set by the owner (e.g. on hit)
var _eye_off := Vector2.ZERO
var _blink_t := 2.0
var _blink := 0.0

var pose: Dictionary = NEUTRAL.duplicate()
var target: Dictionary = NEUTRAL.duplicate()
var follow_speed := 36.0  ## spring frequency (rad/s)
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
var weapon_tip := Vector2.ZERO  ## tip of the sword / head of the hammer (the swoosh trail follows it instead of the fist)

var _vel: Dictionary = {}
var _trail: Array = []


func set_target(t: Dictionary, snap := false) -> void:
	target = NEUTRAL.merged(t, true)
	if snap:
		pose = target.duplicate()
		_vel.clear()


func _process(delta: float) -> void:
	if eyes:
		_eye_off = _eye_off.lerp(aim, 1.0 - exp(-12.0 * delta))
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink = 0.12
			_blink_t = randf_range(2.0, 5.0)
		_blink = maxf(0.0, _blink - delta)
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
			_trail.push_back([to_global(weapon_tip if weapon in ["sword", "hammer"] else hand_f_pos), to_global(hand_b_pos), to_global(foot_f_pos), to_global(foot_b_pos)])
			if _trail.size() > 8:
				_trail.pop_front()
		elif not _trail.is_empty():
			_trail.clear()  # no swoosh without an active hit
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
	weapon_tip = m + weapon_tip.rotated(rot)
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
	if weapon == "hammer":
		# two-handed grip: the back hand is solved (2-bone IK) onto the shaft just above the front hand, in every pose
		var hf := shoulder + arm_f_a + arm_f_b
		var hd := Vector2.from_angle(float(p["wp_rot"]))
		var l1 := UARM * rc_f * arm_scale
		var l2 := LARM * rc_f * arm_scale
		var reach := (l1 + l2) * 0.985
		var grip := hf
		for s in [18.0, 14.0, 10.0, 6.0, 3.0, 0.0]:
			grip = hf + hd * s
			if grip.distance_to(shoulder) <= reach:
				break
		var d := grip - shoulder
		var dist := clampf(d.length(), 4.0, reach)
		var ang_d := atan2(d.x, d.y)
		var bend := acos(clampf(dist / (2.0 * l1), -1.0, 1.0)) if absf(l1 - l2) < 0.01 else acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
		ua_b = ang_d - bend
		arm_b_a = _v(ua_b, l1)
		arm_b_b = (d.normalized() * dist) - arm_b_a
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
		draw_circle(head_c, hr + 3.5, Color(0.02, 0.01, 0.05, 1.0))
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
			# players: a tinted face so the black eyes are visible; enemies keep the dark fill
			var face := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0) if eyes else Color(0.03, 0.02, 0.08)
			draw_circle(head_c, hr - 1.0, face)
			draw_arc(head_c, hr, 0.0, TAU, 28, col_f, 3.5, true)
			if eyes:
				_draw_eyes(head_c, hr, head_ang)
			else:
				draw_circle(head_c + Vector2(5.0, -1.0).rotated(head_ang), 2.0, col_f)
		_accessory(head_c, col_f, hr)
	# front arm
	_limb(shoulder, arm_f_a, arm_f_b, 5.0 * ls, col_f, halo, float(p["fist_f"]))
	if weapon != "":
		_draw_weapon(halo, shoulder + arm_f_a, shoulder + arm_f_a + arm_f_b, shoulder + arm_b_a + arm_b_b, col_f)


## Weapons are drawn from the hands, so every move's arm keyframes move the weapon with them.
## elbow_f / hand_f = front arm, hand_b = back hand.
func _draw_weapon(halo: bool, elbow_f: Vector2, hand_f: Vector2, hand_b: Vector2, col: Color) -> void:
	var dark := Color(0.02, 0.01, 0.05, 1.0)
	var fd := (hand_f - elbow_f)
	fd = fd.normalized() if fd.length() > 0.5 else Vector2.RIGHT
	var wd := fd.rotated(float(pose["wp_rot"]))
	var n := Vector2(-wd.y, wd.x)
	var ws := weapon_scale
	match weapon:
		"sword":
			var blade := 62.0 * ws * maxf(arm_scale, 1.0)
			var base := hand_f + wd * 5.0
			var tip := base + wd * blade
			if not halo:
				weapon_tip = tip
			if halo:
				draw_line(hand_f - wd * 7.0, tip + wd * 3.0, dark, 11.0 * ws)
				draw_line(base - n * 11.0, base + n * 11.0, dark, 8.0)
			else:
				draw_line(hand_f - wd * 7.0, base, col.darkened(0.35), 5.0)       # grip
				draw_line(base - n * 10.0, base + n * 10.0, col, 4.0, true)         # cross-guard
				draw_colored_polygon(PackedVector2Array([base + n * 4.0, tip, base - n * 4.0]), col.darkened(0.55))
				draw_polyline(PackedVector2Array([base + n * 4.0, tip, base - n * 4.0]), col, 2.5, true)
				draw_line(base, tip - wd * 6.0, Color(2.0, 2.0, 2.2), 1.5, true)    # bright edge
		"hammer":
			# the hammer angle is absolute in figure space (0 = forward, + = down, -PI/2 = straight up, PI = back)
			var hd := Vector2.from_angle(float(pose["wp_rot"]))
			var shaft := 74.0 * ws * maxf(arm_scale, 1.0)
			var head_c := hand_f + hd * shaft
			if not halo:
				weapon_tip = head_c
			var tail := hand_f - hd * 24.0
			var sd := (head_c - tail).normalized()
			var sn := Vector2(-sd.y, sd.x)
			var hw := 17.0 * ws  # half length of the head across the shaft
			var ht := 12.0 * ws  # half thickness along the shaft
			var quad := PackedVector2Array([head_c + sn * hw + sd * ht, head_c - sn * hw + sd * ht, head_c - sn * hw - sd * ht, head_c + sn * hw - sd * ht])
			if halo:
				draw_line(tail, head_c, dark, 10.0)
				draw_colored_polygon(PackedVector2Array([quad[0] + (sn + sd) * 3.0, quad[1] + (-sn + sd) * 3.0, quad[2] + (-sn - sd) * 3.0, quad[3] + (sn - sd) * 3.0]), dark)
			else:
				draw_line(tail, head_c, col.darkened(0.3), 5.0, true)
				draw_colored_polygon(quad, col.darkened(0.6))
				draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]), col, 3.0, true)
				draw_line(head_c - sn * hw * 0.6, head_c + sn * hw * 0.6, Color(1.8, 1.8, 2.0), 1.5, true)
					for gp: Vector2 in [hand_f, hand_b]:  # both fists wrap the shaft
						draw_circle(gp, 4.6, col)
						draw_circle(gp, 2.2, Color(1.8, 1.8, 2.0))
		"magic":
			if not halo:
				var t := Time.get_ticks_msec() / 1000.0
				for hp_: Vector2 in [hand_f, hand_b]:
					var r := 9.0 + 2.0 * sin(t * 6.0 + hp_.x)
					draw_circle(hp_, r + 7.0, Color(col.r, col.g, col.b, 0.14))
					draw_circle(hp_, r, Color(col.r, col.g, col.b, 0.35))
					draw_circle(hp_, r * 0.45, Color(2.0, 2.0, 2.2))
					for i in 3:
						var a := t * 3.0 + i * TAU / 3.0 + hp_.y * 0.05
						draw_circle(hp_ + Vector2.from_angle(a) * (r + 6.0), 1.8, col)


## Black half-circle eyes (flat side up, slight inward tilt = "cool, not angry"). They slide towards
## the aim vector, clamped inside the head, close on a blink and flatten when squinting.
func _draw_eyes(h: Vector2, hr: float, ang: float) -> void:
	var off := _eye_off.limit_length(1.0) * hr * 0.28
	var open := 0.12 if _blink > 0.0 else lerpf(1.0, 0.35, squint)
	var r := hr * 0.27
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(hr * 0.1 + sx * hr * 0.36, hr * 0.0) + off
		var tilt: float = -sx * 0.18
		var pts := PackedVector2Array()
		for i in range(9):
			var a := PI * float(i) / 8.0  # lower half-circle, flat side on top
			pts.append(Vector2(cos(a) * r, sin(a) * r * open).rotated(tilt))
		var poly := PackedVector2Array()
		for q in pts:
			poly.append(h + (c + q).rotated(ang))
		draw_colored_polygon(poly, Color(0, 0, 0, 1))  # black eyes; visible because players have a tinted face


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
		var hc := Color(0.02, 0.01, 0.05, 1.0)  # opaque dark outline (translucent pieces darkened where they overlap = jagged joints): separates the figure from busy backgrounds
		w += 5.0
		draw_line(a, b, hc, w, true)
		draw_circle(a, w * 0.5, hc, true, -1.0, true)
		draw_circle(b, w * 0.5, hc, true, -1.0, true)
	else:
		draw_line(a, b, col, w, true)
		draw_circle(a, w * 0.5, col, true, -1.0, true)
		draw_circle(b, w * 0.5, col, true, -1.0, true)


## Global rects along every limb tip that is currently drawing a swoosh ribbon (the weapon tip stands in for the
## front hand when a sword / hammer is held). The attack runner turns these into hit areas: a swoosh always hurts.
func swoosh_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := _trail.size()
	if not trail_on or n < 3:
		return out
	for tip in 4:
		var total := 0.0
		for i in range(1, n):
			total += (_trail[i - 1][tip] as Vector2).distance_to(_trail[i][tip])
		if total < 30.0 or total > 900.0:
			continue
		var r := Rect2(_trail[n - 1][tip], Vector2.ZERO)
		for i in range(maxi(0, n - 4), n):
			r = r.expand(_trail[i][tip])
		out.append(r.grow(16.0))
	return out
