class_name Fx
extends RefCounted
## The juice toolbox: dust, impact bursts, rings, sparks, floating text, afterimages, shatter.


static func dust(parent: Node, pos: Vector2, count: int = 8, col: Color = Color(1, 1, 1, 0.6)) -> void:
	_particles(parent, pos, count, col, Vector2(0, -1), 80.0, 40.0, 130.0, 0.45, Vector2(0, 180), 2.0, 4.0)


static func sparks(parent: Node, pos: Vector2, col: Color, count: int = 10, dir: Vector2 = Vector2.ZERO) -> void:
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2(0, -1)
	var spread := 35.0 if dir != Vector2.ZERO else 180.0
	_particles(parent, pos, count, col, d, spread, 150.0, 460.0, 0.38, Vector2(0, 700), 2.0, 3.6)


static func shatter(parent: Node, pos: Vector2, col: Color, count: int = 22) -> void:
	_particles(parent, pos, count, col, Vector2(0, -1), 180.0, 120.0, 520.0, 0.8, Vector2(0, 900), 2.5, 5.5)


static func _particles(parent: Node, pos: Vector2, count: int, col: Color, dir: Vector2, spread: float, v0: float, v1: float, life: float, grav: Vector2, s0: float, s1: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 55
	p.emitting = true
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	parent.add_child(p)
	parent.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


static func ring(parent: Node, pos: Vector2, col: Color, radius: float = 60.0, dur: float = 0.25) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var s := FxShape.new()
	s.mode = "ring"
	s.col = col
	s.size = radius
	s.dur = dur
	s.position = pos
	parent.add_child(s)


static func impact(parent: Node, pos: Vector2, col: Color, power: float = 1.0, dir: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var s := FxShape.new()
	s.mode = "burst"
	s.col = col
	s.size = 48.0 + 48.0 * power
	s.dur = 0.2
	s.position = pos
	parent.add_child(s)
	ring(parent, pos, col, 40.0 + 44.0 * power, 0.26)
	sparks(parent, pos, col, int(5 + 7 * power), dir)


static func number(parent: Node, pos: Vector2, text: String, col: Color, size: int = 22) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.z_index = 100
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0)))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos + Vector2(-text.length() * size * 0.28, -size)
	l.pivot_offset = Vector2(text.length() * size * 0.28, size * 0.5)
	l.scale = Vector2(0.4, 0.4)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "position:y", l.position.y - 50.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## A line that flashes and fades (hook, boost spark).
static func beam(parent: Node, from: Vector2, to: Vector2, col: Color, dur: float = 0.2) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var l := Line2D.new()
	l.points = PackedVector2Array([from, to])
	l.width = 14.0
	l.default_color = col
	l.z_index = 40
	# taper: thin at the start, full body near the origin, pointed at the far end (no blunt ends)
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.0))
	cv.add_point(Vector2(0.1, 1.0))
	cv.add_point(Vector2(1.0, 0.0))
	l.width_curve = cv
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 0.0, maxf(dur, 0.05))
	tw.tween_property(l, "width", 3.0, maxf(dur, 0.05))
	tw.chain().tween_callback(l.queue_free)


## Fading ghost of a figure's current pose (for dashes and fast moves).
static func afterimage(parent: Node, figure: StickFigure, col: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var g := StickFigure.new()
	g.color = col
	g.style = figure.style
	g.limb_scale = figure.limb_scale
	g.head_scale = figure.head_scale
	g.fill_torso = figure.fill_torso
	g.square_head = figure.square_head
	g.pose = figure.pose.duplicate()
	g.target = g.pose.duplicate()
	g.follow_speed = 0.0
	g.rot = figure.rot
	g.global_position = figure.global_position
	g.scale = figure.scale
	g.modulate = Color(1, 1, 1, 0.45)
	g.z_index = -1
	parent.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)
