class_name Fx
extends RefCounted
## Small one-shot visual effects. Grows into the juice toolbox in M1.


static func dust(parent: Node, pos: Vector2, count: int = 8, col: Color = Color(1, 1, 1, 0.6)) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, 180)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	parent.add_child(p)
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
