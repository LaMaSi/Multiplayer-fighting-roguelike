class_name DepthLayer
extends Node2D
## 2.5D depth for the flat side view. Collision stays exactly as it was; this is only drawing.
## One camera model for everything: a vanishing point sits above the camera centre (looking slightly down at the
## world). A point at depth z (px behind the walking plane) is drawn at  vp + (p - vp) * EYE / (EYE + z).
## So the floor and every platform are real boxes: their back edges converge toward the vanishing point, tops are
## visible because the horizon is above them, and sides appear on the side that faces the camera. Everything
## shifts correctly as the camera moves, horizontally and vertically.
## Characters get a soft contact shadow on whatever they stand over.

const EYE := 700.0  ## distance from the eye to the walking plane
const RISE := 0.0  ## how far above the camera centre the horizon (vanishing point) sits; 0 = eye level at the screen centre (platforms above it are seen from below)
const FLOOR_BACK := 120.0  ## depth of the ground behind the walking line
const FLOOR_FRONT := 24.0  ## the lip of the ground in front of the line (fixed, drawn by the level)
const PLAT_BACK := 40.0  ## platform boxes reach this far behind the walking line
const PLAT_FRONT := 10.0  ## and this far in front of it
const PLAT_LIP := 6.0  ## the box extends this far below the collision rectangle
const TUNNEL_DEPTH := 90.0  ## a tunnel's roof reaches back to its far wall
const TUNNEL_EXTRA := 12.0  ## the roof is drawn this much thicker than its collision slab

var level: LevelBase
var _shadows: Node2D
var _vp := Vector2.ZERO
var _view := Rect2()


func _ready() -> void:
	z_index = -11
	_shadows = Node2D.new()
	_shadows.z_as_relative = false
	_shadows.z_index = -5  # above the ground and platforms (-10), below characters and props
	_shadows.draw.connect(_draw_shadows)
	add_child(_shadows)


func _process(_d: float) -> void:
	queue_redraw()
	_shadows.queue_redraw()


## Screen position (in world coordinates) of the point `p` at depth `z`, seen from the vanishing point `vp`.
static func P(p: Vector2, z: float, vp: Vector2) -> Vector2:
	return vp + (p - vp) * (EYE / (EYE + z))


## Vanishing point in world coordinates for the active camera (or a sensible default).
static func vanish_point(vp_node: Node, fallback: Vector2) -> Vector2:
	var cam := vp_node.get_viewport().get_camera_2d()
	var ctr := cam.get_screen_center_position() if cam != null else fallback
	return Vector2(ctr.x, ctr.y - RISE)


func _update_view() -> void:
	var cam := get_viewport().get_camera_2d()
	var ctr := Vector2(level.level_w * 0.5, level.ground_y)
	var z := 1.0
	if cam != null:
		ctr = cam.get_screen_center_position()
		z = maxf(cam.zoom.x, 0.05)
	var sz := get_viewport_rect().size / z
	_view = Rect2(ctr - sz * 0.5, sz)
	_vp = Vector2(ctr.x, ctr.y - RISE)


func _draw() -> void:
	if level == null:
		return
	_update_view()
	var ng: Color = level.theme["neon_ground"]
	var np: Color = level.theme["neon_plat"]
	var margin := 260.0
	var vx0 := _view.position.x - margin
	var vx1 := _view.end.x + margin
	# ground pieces, lowest first so that higher steps are drawn over the lower ones next to them
	var segs: Array = level._ground_rects()
	segs.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y > b.position.y)
	for g: Rect2 in segs:
		_draw_floor(g, ng, vx0, vx1)
	_draw_finish()
	if Backdrop.variant == 0:
		return  # the legacy flat look keeps its own platforms
	# platforms: farthest (highest) first so lower ones overlap them
	var plats: Array = level.platforms.duplicate()
	plats.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
	for r: Rect2 in plats:
		if r.end.x < vx0 or r.position.x > vx1:
			continue
		if level.tunnel_roofs.has(r):
			_draw_tunnel(r, np)
		else:
			draw_platform(self, r, np, _vp, true)


## The finish line: only a ground effect, a checkered strip across the whole depth of the floor with a soft glow along
## its edges. Walking past it (once the fights are done) ends the level.
func _draw_finish() -> void:
	if level.exit_x <= 0.0:
		return
	var x0: float = level.exit_x
	if x0 < _view.position.x - 300.0 or x0 > _view.end.x + 300.0:
		return
	var y: float = level.ground_top(x0)
	var w := 100.0
	var rows := 9
	var cols := 4
	var glow := Color(1.3, 1.8, 2.2)
	# a soft glow on the floor around the strip
	var g0 := _floor_pt(x0 - 26.0, y, 0.0)
	var g1 := _floor_pt(x0 + w + 26.0, y, 0.0)
	var g2 := _floor_pt(x0 + w + 26.0, y, 1.0)
	var g3 := _floor_pt(x0 - 26.0, y, 1.0)
	draw_polygon(PackedVector2Array([g0, g1, g2, g3]), PackedColorArray([Color(glow.r, glow.g, glow.b, 0.10), Color(glow.r, glow.g, glow.b, 0.10), Color(glow.r, glow.g, glow.b, 0.05), Color(glow.r, glow.g, glow.b, 0.05)]))
	for r in rows:
		for c in cols:
			var t0 := float(r) / float(rows)
			var t1 := float(r + 1) / float(rows)
			var xa := x0 + w * float(c) / float(cols)
			var xb := x0 + w * float(c + 1) / float(cols)
			var col := Color(1.7, 1.7, 2.0) if (r + c) % 2 == 0 else Color(0.03, 0.02, 0.06)
			var pts := PackedVector2Array([_floor_pt(xa, y, t0), _floor_pt(xb, y, t0), _floor_pt(xb, y, t1), _floor_pt(xa, y, t1)])
			draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())
	draw_line(_floor_pt(x0, y, 0.0), _floor_pt(x0, y, 1.0), Color(glow.r, glow.g, glow.b, 0.8), 2.0, true)
	draw_line(_floor_pt(x0 + w, y, 0.0), _floor_pt(x0 + w, y, 1.0), Color(glow.r, glow.g, glow.b, 0.8), 2.0, true)


## A point on the floor at x, t = 0 at the front lip, 1 at the far edge.
func _floor_pt(x: float, y: float, t: float) -> Vector2:
	return Vector2(x, y + FLOOR_FRONT).lerp(P(Vector2(x, y), FLOOR_BACK, _vp), t)


## A tunnel: a dark far wall and lights under a thick roof. The way through is at ground level; the roof is a platform.
func _draw_tunnel(r: Rect2, np: Color) -> void:
	var gy: float = level.ground_top(r.get_center().x)
	var roof := Rect2(r.position, Vector2(r.size.x, r.size.y + TUNNEL_EXTRA))
	var z := TUNNEL_DEPTH
	var x0 := r.position.x
	var x1 := r.end.x
	var bottom := roof.end.y + PLAT_LIP
	# the far wall, from the roof down to where the floor meets it
	var wt0 := P(Vector2(x0, bottom), z, _vp)
	var wt1 := P(Vector2(x1, bottom), z, _vp)
	var wb0 := P(Vector2(x0, gy), z, _vp)
	var wb1 := P(Vector2(x1, gy), z, _vp)
	var dark := Color(0.015, 0.008, 0.04)
	var mid := Color(np.r * 0.07, np.g * 0.07, np.b * 0.07)
	draw_polygon(PackedVector2Array([wt0, wt1, wb1, wb0]), PackedColorArray([dark, dark, mid, mid]))
	var lx := x0 - fmod(x0, 120.0) + 120.0
	while lx < x1:
		draw_line(P(Vector2(lx, bottom), z, _vp), P(Vector2(lx, gy), z, _vp), Color(np.r, np.g, np.b, 0.10), 2.0)
		lx += 120.0
	draw_line(wb0, wb1, Color(np.r, np.g, np.b, 0.35), 2.0, true)
	# the thick roof, then the ceiling lights on its underside
	draw_platform(self, roof, np, _vp, true, z)
	var lamp := Color(1.6, 1.5, 1.2, 0.85)
	var lamp_x := x0 + 60.0
	while lamp_x < x1 - 30.0:
		var a := P(Vector2(lamp_x - 14.0, bottom), z * 0.45, _vp)
		var b := P(Vector2(lamp_x + 14.0, bottom), z * 0.45, _vp)
		draw_line(a, b, lamp, 4.0, true)
		draw_line(a, b, Color(lamp.r, lamp.g, lamp.b, 0.18), 12.0, true)
		lamp_x += 110.0


func _draw_floor(g: Rect2, ng: Color, vx0: float, vx1: float) -> void:
	if g.end.x < vx0 or g.position.x > vx1:
		return
	var y := g.position.y
	var x0 := maxf(g.position.x, vx0)
	var x1 := minf(g.end.x, vx1)
	var tint := Color(minf(ng.r, 1.0), minf(ng.g, 1.0), minf(ng.b, 1.0))
	var base: Color = Pal.BG_GROUND
	var near := base.lerp(tint, 0.20)
	var far := base.lerp(tint, 0.07)
	var b0 := P(Vector2(x0, y), FLOOR_BACK, _vp)
	var b1 := P(Vector2(x1, y), FLOOR_BACK, _vp)
	var yb := b0.y  # same for both: the far edge is level
	# haze above the far edge so the buildings sit into the floor
	var fog := PackedVector2Array([Vector2(b0.x, yb - 38.0), Vector2(b1.x, yb - 38.0), Vector2(b1.x, yb), Vector2(b0.x, yb)])
	var fc := Color(0.04, 0.02, 0.09, 0.0)
	var fd := Color(0.04, 0.02, 0.09, 0.55)
	draw_polygon(fog, PackedColorArray([fc, fc, fd, fd]))
	# the surface itself: dark at the far edge, lighter at the near edge
	var top := PackedVector2Array([b0, b1, Vector2(x1, y + FLOOR_FRONT), Vector2(x0, y + FLOOR_FRONT)])
	draw_polygon(top, PackedColorArray([far, far, near, near]))
	# lines running into the distance, and rows across
	var gx := x0 - fmod(x0, 100.0)
	while gx < x1:
		if gx > x0:
			draw_line(Vector2(gx, y + FLOOR_FRONT), P(Vector2(gx, y), FLOOR_BACK, _vp), Color(ng.r, ng.g, ng.b, 0.13), 1.5)
		gx += 100.0
	for d: float in [FLOOR_BACK * 0.33, FLOOR_BACK * 0.66]:
		draw_line(P(Vector2(x0, y), d, _vp), P(Vector2(x1, y), d, _vp), Color(ng.r, ng.g, ng.b, 0.09), 1.5)
	# faint centre line = where feet stand, and a thin far edge
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(ng.r, ng.g, ng.b, 0.14), 1.5)
	draw_line(b0, b1, Color(ng.r, ng.g, ng.b, 0.30), 2.0, true)
	# the end faces, only when they face the camera (looking at a pit from the pit side)
	var wall := Color(0.03, 0.015, 0.07)
	if g.position.x >= vx0 and _vp.x < g.position.x:
		var t := P(Vector2(g.position.x, y), FLOOR_BACK, _vp)
		var bt := P(Vector2(g.position.x, y + 900.0), FLOOR_BACK, _vp)
		draw_polygon(PackedVector2Array([Vector2(g.position.x, y + FLOOR_FRONT), t, bt, Vector2(g.position.x, y + FLOOR_FRONT + 900.0)]), PackedColorArray([near, far, wall, wall]))
		draw_line(Vector2(g.position.x, y + FLOOR_FRONT), t, Color(ng.r, ng.g, ng.b, 0.45), 2.0, true)
	if g.end.x <= vx1 and _vp.x > g.end.x:
		var t2 := P(Vector2(g.end.x, y), FLOOR_BACK, _vp)
		var bt2 := P(Vector2(g.end.x, y + 900.0), FLOOR_BACK, _vp)
		draw_polygon(PackedVector2Array([Vector2(g.end.x, y + FLOOR_FRONT), t2, bt2, Vector2(g.end.x, y + FLOOR_FRONT + 900.0)]), PackedColorArray([near, far, wall, wall]))
		draw_line(Vector2(g.end.x, y + FLOOR_FRONT), t2, Color(ng.r, ng.g, ng.b, 0.45), 2.0, true)


## Draws a platform as a real box in the shared camera model. `r` is the collision rectangle in the canvas space of
## `c`, `vp` the vanishing point in that space. Returns the front face rectangle (for decorations such as stripes).
## `fill` (alpha > 0) replaces the body colour of every face, for structures that should look dark like the background.
static func draw_platform(c: CanvasItem, r: Rect2, np: Color, vp: Vector2, with_shadow: bool, z_back := PLAT_BACK, fill := Color(0, 0, 0, 0)) -> Rect2:
	var x0 := r.position.x
	var x1 := r.end.x
	var yt := r.position.y
	var yb := r.end.y + PLAT_LIP
	var zf := -PLAT_FRONT
	var zb := z_back
	var f_tl := P(Vector2(x0, yt), zf, vp)
	var f_tr := P(Vector2(x1, yt), zf, vp)
	var f_bl := P(Vector2(x0, yb), zf, vp)
	var f_br := P(Vector2(x1, yb), zf, vp)
	var b_tl := P(Vector2(x0, yt), zb, vp)
	var b_tr := P(Vector2(x1, yt), zb, vp)
	var b_bl := P(Vector2(x0, yb), zb, vp)
	var b_br := P(Vector2(x1, yb), zb, vp)
	if with_shadow:
		for i in 3:
			c.draw_rect(Rect2(f_bl.x + 6 + i * 3, f_bl.y + 2 + i * 6, f_br.x - f_bl.x - 12 - i * 6, 6), Color(0, 0, 0, 0.22 - i * 0.06))
	var custom := fill.a > 0.0
	var side := fill.lightened(0.04) if custom else Color(np.r * 0.09, np.g * 0.09, np.b * 0.09)
	# sides that face the camera
	if vp.x < x0:
		_quad(c, PackedVector2Array([f_tl, b_tl, b_bl, f_bl]), side)  # (a side seen edge-on is a sliver: no polygon triangulation)
		c.draw_line(f_tl, b_tl, Color(np.r, np.g, np.b, 0.35), 1.5, true)
	elif vp.x > x1:
		_quad(c, PackedVector2Array([f_tr, b_tr, b_br, f_br]), side)
		c.draw_line(f_tr, b_tr, Color(np.r, np.g, np.b, 0.35), 1.5, true)
	# the top is visible because the horizon is above it; the underside if the platform is above the horizon
	if vp.y < yt:
		var near := Color(np.r * 0.34, np.g * 0.34, np.b * 0.34)
		var far := Color(np.r * 0.17, np.g * 0.17, np.b * 0.17)
		if custom:
			near = fill.lightened(0.08)
			far = fill
		c.draw_polygon(PackedVector2Array([b_tl, b_tr, f_tr, f_tl]), PackedColorArray([far, far, near, near]))
		c.draw_line(b_tl, b_tr, Color(np.r, np.g, np.b, 0.30), 1.5, true)
	elif vp.y > yb:
		_quad(c, PackedVector2Array([f_bl, f_br, b_br, b_bl]), fill.darkened(0.3) if custom else Color(np.r * 0.05, np.g * 0.05, np.b * 0.05))
	# the front face, with the bright edge
	c.draw_colored_polygon(PackedVector2Array([f_tl, f_tr, f_br, f_bl]), fill if custom else Color(np.r * 0.16, np.g * 0.16, np.b * 0.16))
	var fh := f_bl.y - f_tl.y
	if not custom:
		c.draw_rect(Rect2(f_tl.x, f_tl.y, f_tr.x - f_tl.x, fh * 0.5), Color(np.r * 0.30, np.g * 0.30, np.b * 0.30))
	c.draw_rect(Rect2(f_bl.x, f_bl.y - 3.0, f_br.x - f_bl.x, 3.0), Color(0.02, 0.01, 0.04, 0.9))
	c.draw_line(f_tl, f_tr, np, 3.0, true)
	c.draw_line(f_tl, f_bl, Color(np.r, np.g, np.b, 0.55), 3.0, true)
	c.draw_line(f_tr, f_br, Color(np.r, np.g, np.b, 0.55), 3.0, true)
	return Rect2(f_tl, f_br - f_tl)


## Corners of a box seen from the vanishing point: the front face (depth zf) and the back face (depth zb) of the
## rectangle `r`. Keys f_tl f_tr f_bl f_br b_tl b_tr b_bl b_br.
static func box(r: Rect2, zf: float, zb: float, vp: Vector2) -> Dictionary:
	return {
		"f_tl": P(r.position, zf, vp), "f_tr": P(Vector2(r.end.x, r.position.y), zf, vp),
		"f_bl": P(Vector2(r.position.x, r.end.y), zf, vp), "f_br": P(r.end, zf, vp),
		"b_tl": P(r.position, zb, vp), "b_tr": P(Vector2(r.end.x, r.position.y), zb, vp),
		"b_bl": P(Vector2(r.position.x, r.end.y), zb, vp), "b_br": P(r.end, zb, vp),
	}


## A filled quad that never fails to triangulate, even when it is a sliver or flat.
static func _quad(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	c.draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())


## Height of the surface under a point: the closest ground, platform or moving platform top at or below `feet`.
func surface_below(feet: Vector2) -> float:
	var best := INF
	var gy: float = level.ground_at(feet.x)
	if gy != INF and gy >= feet.y - 8.0:
		best = gy
	for r: Rect2 in level.platforms:
		if feet.x >= r.position.x and feet.x <= r.end.x and r.position.y >= feet.y - 8.0 and r.position.y < best:
			best = r.position.y
	for n in get_tree().get_nodes_in_group("moving_platforms"):
		var mp := n as MovingPlatform
		if mp == null:
			continue
		var top := mp.global_position.y - mp.size.y * 0.5
		if absf(feet.x - mp.global_position.x) <= mp.size.x * 0.5 and top >= feet.y - 8.0 and top < best:
			best = top
	return best


func _draw_shadows() -> void:
	if level == null:
		return
	_draw_prop_shadows()
	for n in get_tree().get_nodes_in_group("actors"):
		var a := n as Node2D
		if a == null or not a.visible or a.modulate.a < 0.3:
			continue
		var feet := a.global_position
		var sy := surface_below(feet)
		if sy == INF or sy - feet.y > 900.0:
			continue
		var h := maxf(sy - feet.y, 0.0)
		var k := clampf(1.0 - h / 420.0, 0.0, 1.0)
		if k <= 0.02:
			continue
		var rx := (62.0 if a.is_in_group("boss") else 34.0) * (0.55 + 0.45 * k)
		var ry := rx * 0.22
		var c := Vector2(feet.x, sy)
		_shadows.draw_colored_polygon(_ellipse(c, rx * 1.35, ry * 1.4), Color(0.0, 0.0, 0.03, 0.20 * k))
		_shadows.draw_colored_polygon(_ellipse(c, rx, ry), Color(0.0, 0.0, 0.03, 0.34 * k))


func _draw_prop_shadows() -> void:
	for n in get_tree().get_nodes_in_group("props"):
		var pr := n as Prop
		if pr == null or pr.state == "dead" or pr.state == "held":
			continue
		if pr.kind == "vase" and pr._depth > 1.0:
			continue  # a vase set back draws its own shadow at its drawn base
		var feet := pr.global_position
		var sy := surface_below(feet)
		if sy == INF or sy - feet.y > 900.0:
			continue
		var k := clampf(1.0 - maxf(sy - feet.y, 0.0) / 420.0, 0.0, 1.0)
		if k <= 0.02:
			continue
		var rx := pr.w * 0.62 * (0.6 + 0.4 * k)
		var c := Vector2(feet.x, sy)
		_shadows.draw_colored_polygon(_ellipse(c, rx * 1.3, rx * 0.3), Color(0.0, 0.0, 0.03, 0.18 * k))
		_shadows.draw_colored_polygon(_ellipse(c, rx, rx * 0.22), Color(0.0, 0.0, 0.03, 0.30 * k))


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
