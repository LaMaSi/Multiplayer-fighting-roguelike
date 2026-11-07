class_name ProjectileFx
extends RefCounted
## Drawing and particles for the projectile shapes. Every projectile keeps its owner's colour; the moves differ in
## SHAPE and MOTION only: a flickering teardrop of flame, a jagged lightning bolt, sharp darts, a spinning four-point
## blade, a row of ground spikes.


static func bright(col: Color, k: float) -> Color:
	return Color(minf(col.r * k, 2.6), minf(col.g * k, 2.6), minf(col.b * k, 2.6), 1.0)


static func fireball(c: CanvasItem, vel: Vector2, radius: float, col: Color, age: float) -> void:
	var ang := atan2(vel.y, vel.x)
	c.draw_set_transform(Vector2.ZERO, ang)
	var t := age * 22.0
	c.draw_circle(Vector2.ZERO, radius + 9.0, Color(col.r, col.g, col.b, 0.14))
	# flame tongues streaming behind: flickering length and sideways wobble
	for k in 5:
		var off := (float(k) - 2.0) * radius * 0.42
		var len := radius * (2.6 + 1.2 * sin(t + float(k) * 1.7)) * (1.0 - 0.14 * absf(float(k) - 2.0))
		var wob := sin(t * 1.3 + float(k) * 2.1) * radius * 0.35
		var tongue := PackedVector2Array([Vector2(0, off * 0.9), Vector2(-len * 0.5, off + wob * 0.5 + radius * 0.25), Vector2(-len, off + wob), Vector2(-len * 0.5, off + wob * 0.5 - radius * 0.25)])
		c.draw_colored_polygon(tongue, Color(col.r, col.g, col.b, 0.55))
	c.draw_circle(Vector2.ZERO, radius, col)
	c.draw_circle(Vector2(radius * 0.15, 0), radius * 0.62, bright(col, 1.4))
	c.draw_circle(Vector2(radius * 0.25, 0), radius * 0.28, Color(2.6, 2.6, 2.6))
	c.draw_set_transform(Vector2.ZERO, 0.0)


static func spark(c: CanvasItem, vel: Vector2, radius: float, col: Color, age: float) -> void:
	var ang := atan2(vel.y, vel.x)
	c.draw_set_transform(Vector2.ZERO, ang)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(age * 60.0) * 7919 + 13
	var pts := PackedVector2Array()
	var n := 7
	for i in n + 1:
		var x := -radius * 3.2 + float(i) * (radius * 3.8 / float(n))
		pts.append(Vector2(x, 0.0 if i == 0 or i == n else rnd.randf_range(-radius * 0.9, radius * 0.9)))
	c.draw_polyline(pts, Color(col.r, col.g, col.b, 0.3), 9.0, true)
	c.draw_polyline(pts, col, 4.0, true)
	c.draw_polyline(pts, Color(2.6, 2.6, 2.6), 1.6, true)
	c.draw_set_transform(Vector2.ZERO, 0.0)


static func dart(c: CanvasItem, vel: Vector2, radius: float, col: Color) -> void:
	var ang := atan2(vel.y, vel.x)
	c.draw_set_transform(Vector2.ZERO, ang)
	var r := radius
	var body := PackedVector2Array([Vector2(r * 2.2, 0), Vector2(-r * 0.4, -r * 0.75), Vector2(-r * 1.1, 0), Vector2(-r * 0.4, r * 0.75)])
	c.draw_colored_polygon(body, Color(col.r, col.g, col.b, 0.35))
	var outline := body.duplicate()
	outline.append(body[0])
	c.draw_polyline(outline, col, 3.0, true)
	c.draw_line(Vector2(-r * 0.8, 0), Vector2(r * 1.8, 0), bright(col, 1.5), 1.6, true)
	c.draw_line(Vector2(-r * 1.1, 0), Vector2(-r * 3.0, 0), Color(col.r, col.g, col.b, 0.4), 2.0, true)  # speed streak
	c.draw_set_transform(Vector2.ZERO, 0.0)


static func blade(c: CanvasItem, radius: float, col: Color, spin: float) -> void:
	c.draw_circle(Vector2.ZERO, radius + 8.0, Color(col.r, col.g, col.b, 0.10))
	for arm in 4:
		var a := spin * 1.6 + float(arm) * TAU / 4.0
		var tip := Vector2.from_angle(a) * radius * 1.5
		var l := Vector2.from_angle(a - 0.55) * radius * 0.5
		var rr := Vector2.from_angle(a + 0.35) * radius * 0.5
		c.draw_colored_polygon(PackedVector2Array([tip, rr, Vector2.ZERO, l]), Color(col.r, col.g, col.b, 0.45))
		c.draw_polyline(PackedVector2Array([l, tip, rr]), col, 2.5, true)
	c.draw_circle(Vector2.ZERO, radius * 0.35, bright(col, 1.5))
	c.draw_arc(Vector2.ZERO, radius * 1.3, spin * 1.6 - 2.2, spin * 1.6 - 0.6, 10, Color(col.r, col.g, col.b, 0.35), 3.0, true)  # spin arc


static func quake(c: CanvasItem, vel: Vector2, radius: float, col: Color, age: float) -> void:
	# a row of jagged ground spikes, rising and falling as they travel
	var s := signf(vel.x if vel.x != 0.0 else 1.0)
	for k in 5:
		var x := -s * float(k) * radius * 0.9
		var h := radius * (1.9 - 0.28 * float(k)) * (0.8 + 0.2 * sin(age * 30.0 + float(k)))
		var spike := PackedVector2Array([Vector2(x - radius * 0.45, 4), Vector2(x, -h), Vector2(x + radius * 0.45, 4)])
		c.draw_colored_polygon(spike, Color(col.r, col.g, col.b, 0.5 - 0.07 * float(k)))
		c.draw_polyline(PackedVector2Array([spike[0], spike[1], spike[2]]), col, 3.0, true)


## Trail particles by shape. Returns the delay until the next emission.
static func trail(parent: Node, shape: String, pos: Vector2, dir: Vector2, radius: float, col: Color) -> float:
	var back := -dir
	match shape:
		"fireball":
			Fx._particles(parent, pos + back * radius * 0.5, 2, col, back + Vector2(0, -0.6), 50.0, 40.0, 130.0, 0.4, Vector2(0, -420), 4.0, 1.0)
			return 0.025
		"spark":
			Fx._particles(parent, pos, 1, bright(col, 1.3), back, 90.0, 60.0, 220.0, 0.18, Vector2.ZERO, 2.0, 0.5)
			return 0.04
		"blade":
			Fx._particles(parent, pos, 1, col, back, 60.0, 20.0, 80.0, 0.25, Vector2.ZERO, 2.5, 0.5)
			return 0.05
		"quake":
			Fx.dust(parent, pos + Vector2(0, 6), 2, Color(col.r, col.g, col.b, 0.5))
			return 0.05
	return 0.2


## Burst when the projectile connects.
static func hit(parent: Node, shape: String, pos: Vector2, col: Color, splash: float) -> void:
	match shape:
		"fireball":
			Fx.ring(parent, pos, col, maxf(splash, 60.0), 0.3)
			Fx._particles(parent, pos, 14, col, Vector2(0, -1), 180.0, 80.0, 300.0, 0.5, Vector2(0, -200), 5.0, 1.0)
		"spark":
			Fx._particles(parent, pos, 10, bright(col, 1.3), Vector2(0, -1), 180.0, 120.0, 380.0, 0.22, Vector2.ZERO, 2.5, 0.5)
