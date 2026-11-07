class_name Barrier
extends Node2D
## Hammer's Bulwark Plant: a pillar that physically blocks movement and eats enemy projectiles for a few seconds.

var life := 4.0
var team := "player"
var w := 46.0
var h := 150.0

var _age := 0.0
var _body: StaticBody2D


static func spawn(parent: Node, pos: Vector2, duration: float, owner_team: String) -> Barrier:
	var b := Barrier.new()
	b.life = duration
	b.team = owner_team
	b.global_position = pos
	parent.add_child(b)
	return b


func _ready() -> void:
	add_to_group("barriers")
	z_index = 4
	_body = StaticBody2D.new()
	_body.collision_layer = 0
	_body.set_collision_layer_value(4, true)  # actors collide with layer 4; projectile rays (layer 1) pass through
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(0, -h * 0.5)
	_body.add_child(cs)
	add_child(_body)
	Fx.dust(get_parent(), global_position, 12)


func get_rect() -> Rect2:
	return Rect2(global_position.x - w * 0.5, global_position.y - h, w, h)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		Fx.shatter(get_parent(), global_position + Vector2(0, -h * 0.5), Color(1.9, 1.9, 2.2), 16)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow := clampf(_age / 0.15, 0.0, 1.0)  # rises out of the ground
	var fade := clampf((life - _age) / 0.6, 0.0, 1.0)
	var hh := h * grow
	var r := Rect2(-w * 0.5, -hh, w, hh)
	draw_rect(r, Color(0.07, 0.05, 0.12, 0.9 * fade))
	var c := Color(1.9, 1.9, 2.2, fade)
	draw_rect(r, c, false, UiKit.LINE)
	for i in 4:
		var y := -hh + (i + 1) * hh / 5.0
		draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y), Color(c.r, c.g, c.b, 0.55 * fade), UiKit.LINE)
