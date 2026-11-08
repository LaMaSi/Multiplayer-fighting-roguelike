class_name MovingPlatform
extends AnimatableBody2D
## A one-way platform that glides back and forth (horizontal) or up and down (vertical). Fighters standing on it ride along.

var size := Vector2(200, 16)
var origin := Vector2.ZERO  ## centre of the travel
var axis := Vector2.RIGHT
var travel := 140.0  ## half-distance
var period := 4.0
var _t := 0.0
var neon := Color(2.0, 0.7, 1.2)


func setup(rect: Rect2, vertical: bool, half_travel: float, per: float, phase: float, col: Color) -> void:
	size = rect.size
	origin = rect.position + rect.size * 0.5
	axis = Vector2.DOWN if vertical else Vector2.RIGHT
	travel = half_travel
	period = per
	_t = phase * period
	neon = col
	position = origin + axis * sin(_t / period * TAU) * travel
	sync_to_physics = true
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.one_way_collision = true
	cs.one_way_collision_margin = 6.0
	add_child(cs)
	set_meta("bottom_y", origin.y + size.y * 0.5)
	z_index = -9
	add_to_group("moving_platforms")


func _physics_process(delta: float) -> void:
	_t += delta
	position = origin + axis * sin(_t / period * TAU) * travel
	set_meta("bottom_y", position.y + size.y * 0.5)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var cam := get_viewport().get_camera_2d()
	var ctr := cam.get_screen_center_position() if cam != null else global_position
	var vp := Vector2(ctr.x, ctr.y - DepthLayer.RISE) - global_position  # vanishing point in local coordinates
	var f := DepthLayer.draw_platform(self, r, neon, vp, false)
	# hazard stripes + end lights on the front face so it reads as "moving"
	for i in int(size.x / 24.0):
		draw_line(Vector2(f.position.x + 8.0 + i * 24.0, f.end.y - 2.0), Vector2(f.position.x + 20.0 + i * 24.0, f.position.y + 5.0), Color(1.4, 1.2, 0.3, 0.55), 2.0)
	var ly := f.position.y + f.size.y * 0.5
	draw_circle(Vector2(f.position.x + 5.0, ly), 3.0, Color(1.6, 1.4, 0.4))
	draw_circle(Vector2(f.end.x - 5.0, ly), 3.0, Color(1.6, 1.4, 0.4))
