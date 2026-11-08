class_name DepthLayer
extends Node2D
## 2.5D depth for the flat side view. Collision stays exactly as it was; this is only drawing.
## The ground and the platforms get a top surface that reaches a bit to the back (behind the walking line) and a bit to
## the front (the lip you see in front of it). The back edge converges toward the camera centre, so the surfaces shift
## slightly while the camera moves and pit and platform sides appear when you look at them from the right direction.
## Characters get a soft contact shadow on whatever they stand over (the strongest depth cue for the cost).

const FLOOR_BACK := 46.0  ## how far the ground reaches behind the walking line
const FLOOR_FRONT := 24.0  ## and in front of it
const PLAT_BACK := 22.0
const PLAT_FRONT := 14.0
const PLAT_LIP := 6.0  ## front face reaches this far below the collision rectangle
const VANISH := 700.0  ## distance of the imaginary horizon: a point `depth` px back converges by depth / VANISH

var level: LevelBase
var _shadows: Node2D
var _vp_x := 0.0
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


## x of a point `depth` px behind the line, as seen from the camera centre.
static func proj(x: float, vp_x: float, depth: float) -> float:
	return x + (vp_x - x) * depth / VANISH


func _update_view() -> void:
	var cam := get_viewport().get_camera_2d()
	var ctr := Vector2(level.level_w * 0.5, level.ground_y)
	var z := 1.0
	if cam != null:
		ctr = cam.get_screen_center_position()
		z = maxf(cam.zoom.x, 0.05)
	var sz := get_viewport_rect().size / z
	_view = Rect2(ctr - sz * 0.5, sz)
	_vp_x = ctr.x


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
	for r: Rect2 in level.platforms:
		if r.end.x < vx0 or r.position.x > vx1:
			continue
		draw_platform(self, r, np, _vp_x)


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
	var bx0 := proj(x0, _vp_x, FLOOR_BACK)
	var bx1 := proj(x1, _vp_x, FLOOR_BACK)
	# haze above the far edge so the buildings sit into the floor
	var fog := PackedVector2Array([Vector2(bx0, y - FLOOR_BACK - 38.0), Vector2(bx1, y - FLOOR_BACK - 38.0), Vector2(bx1, y - FLOOR_BACK), Vector2(bx0, y - FLOOR_BACK)])
	var fc := Color(0.04, 0.02, 0.09, 0.0)
	var fd := Color(0.04, 0.02, 0.09, 0.55)
	draw_polygon(fog, PackedColorArray([fc, fc, fd, fd]))
	# the surface itself: dark at the far edge, lighter at the near edge
	var top := PackedVector2Array([Vector2(bx0, y - FLOOR_BACK), Vector2(bx1, y - FLOOR_BACK), Vector2(x1, y + FLOOR_FRONT), Vector2(x0, y + FLOOR_FRONT)])
	draw_polygon(top, PackedColorArray([far, far, near, near]))
	# lines running into the distance, and rows across
	var gx := x0 - fmod(x0, 100.0)
	while gx < x1:
		if gx > x0:
			draw_line(Vector2(gx, y + FLOOR_FRONT), Vector2(proj(gx, _vp_x, FLOOR_BACK), y - FLOOR_BACK), Color(ng.r, ng.g, ng.b, 0.13), 1.5)
		gx += 100.0
	for d: float in [FLOOR_BACK * 0.33, FLOOR_BACK * 0.66]:
		draw_line(Vector2(proj(x0, _vp_x, d), y - d), Vector2(proj(x1, _vp_x, d), y - d), Color(ng.r, ng.g, ng.b, 0.09), 1.5)
	# faint centre line = where feet stand, and a thin far edge
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(ng.r, ng.g, ng.b, 0.14), 1.5)
	draw_line(Vector2(bx0, y - FLOOR_BACK), Vector2(bx1, y - FLOOR_BACK), Color(ng.r, ng.g, ng.b, 0.30), 2.0, true)
	# the end faces, only when they face the camera (looking at a pit from the pit side)
	var wall := Color(0.03, 0.015, 0.07)
	if g.position.x >= vx0 and _vp_x < g.position.x:
		var px := proj(g.position.x, _vp_x, FLOOR_BACK)
		draw_polygon(PackedVector2Array([Vector2(g.position.x, y + FLOOR_FRONT), Vector2(px, y - FLOOR_BACK), Vector2(px, y - FLOOR_BACK + 900.0), Vector2(g.position.x, y + FLOOR_FRONT + 900.0)]), PackedColorArray([near, far, wall, wall]))
		draw_line(Vector2(g.position.x, y + FLOOR_FRONT), Vector2(px, y - FLOOR_BACK), Color(ng.r, ng.g, ng.b, 0.45), 2.0, true)
	if g.end.x <= vx1 and _vp_x > g.end.x:
		var px2 := proj(g.end.x, _vp_x, FLOOR_BACK)
		draw_polygon(PackedVector2Array([Vector2(g.end.x, y + FLOOR_FRONT), Vector2(px2, y - FLOOR_BACK), Vector2(px2, y - FLOOR_BACK + 900.0), Vector2(g.end.x, y + FLOOR_FRONT + 900.0)]), PackedColorArray([near, far, wall, wall]))
		draw_line(Vector2(g.end.x, y + FLOOR_FRONT), Vector2(px2, y - FLOOR_BACK), Color(ng.r, ng.g, ng.b, 0.45), 2.0, true)


## A platform's top surface (reaching back and forward) and its visible side. `r` is the collision rectangle in the
## canvas space of `c`, `vp_x` the camera centre in that space. The front face and neon edge are drawn by the level.
static func draw_platform(c: CanvasItem, r: Rect2, np: Color, vp_x: float) -> void:
	var y := r.position.y
	var x0 := r.position.x
	var x1 := r.end.x
	var bx0 := proj(x0, vp_x, PLAT_BACK)
	var bx1 := proj(x1, vp_x, PLAT_BACK)
	var near := Color(np.r * 0.34, np.g * 0.34, np.b * 0.34)
	var far := Color(np.r * 0.17, np.g * 0.17, np.b * 0.17)
	var thick := r.size.y + PLAT_LIP - PLAT_FRONT
	var side := Color(np.r * 0.08, np.g * 0.08, np.b * 0.08)
	if vp_x < x0:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y + PLAT_FRONT), Vector2(bx0, y - PLAT_BACK), Vector2(bx0, y - PLAT_BACK + thick), Vector2(x0, y + PLAT_FRONT + thick)]), side)
	elif vp_x > x1:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x1, y + PLAT_FRONT), Vector2(bx1, y - PLAT_BACK), Vector2(bx1, y - PLAT_BACK + thick), Vector2(x1, y + PLAT_FRONT + thick)]), side)
	c.draw_polygon(PackedVector2Array([Vector2(bx0, y - PLAT_BACK), Vector2(bx1, y - PLAT_BACK), Vector2(x1, y + PLAT_FRONT), Vector2(x0, y + PLAT_FRONT)]), PackedColorArray([far, far, near, near]))
	c.draw_line(Vector2(bx0, y - PLAT_BACK), Vector2(bx1, y - PLAT_BACK), Color(np.r, np.g, np.b, 0.30), 1.5, true)
	c.draw_line(Vector2(x0, y + PLAT_FRONT), Vector2(bx0, y - PLAT_BACK), Color(np.r, np.g, np.b, 0.20), 1.5, true)
	c.draw_line(Vector2(x1, y + PLAT_FRONT), Vector2(bx1, y - PLAT_BACK), Color(np.r, np.g, np.b, 0.20), 1.5, true)


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


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
