class_name BurnFx
extends Node2D
## Flames licking up a burning actor. The flames wear the colour of whoever set them alight (player colours stay
## meaningful); only the shapes and the motion say "fire": teardrop tongues that flicker, shrink and rise.

var actor: Actor
var col := Color(2.2, 0.9, 0.3)
var _t := 0.0
var _ember_t := 0.0


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or actor.burn_t <= 0.0 or actor.state == "dead":
		queue_free()
		return
	_t += delta
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.07
		var bh := actor.body_h * actor.body_scale
		var p := actor.global_position + Vector2(randf_range(-12.0, 12.0) * actor.body_scale, -randf_range(0.2, 0.9) * bh)
		Fx._particles(actor.get_parent(), p, 1, col, Vector2(0, -1), 30.0, 50.0, 120.0, 0.45, Vector2(0, -260), 3.5, 0.5)
	queue_redraw()


func _draw() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var s := actor.body_scale
	var bh := actor.body_h * s
	var fade := clampf(actor.burn_t / 0.6, 0.0, 1.0)  # flames die down as the burn runs out
	for i in 7:
		var phase := _t * (9.0 + float(i) * 1.3) + float(i) * 2.4
		var fx := (float(i) / 6.0 - 0.5) * 30.0 * s
		var base_y := -bh * (0.12 + 0.78 * fmod(float(i) * 0.37, 1.0))
		var h := (16.0 + 14.0 * (0.5 + 0.5 * sin(phase))) * s * fade
		var w := 7.0 * s * fade
		var lean := sin(phase * 0.7) * 5.0 * s
		var tongue := PackedVector2Array([
			Vector2(fx - w, base_y), Vector2(fx - w * 0.6, base_y - h * 0.45), Vector2(fx + lean, base_y - h),
			Vector2(fx + w * 0.6, base_y - h * 0.45), Vector2(fx + w, base_y)])
		draw_colored_polygon(tongue, Color(col.r, col.g, col.b, 0.55 * fade))
		var inner := PackedVector2Array([
			Vector2(fx - w * 0.45, base_y), Vector2(fx + lean * 0.7, base_y - h * 0.62), Vector2(fx + w * 0.45, base_y)])
		draw_colored_polygon(inner, Color(minf(col.r * 1.5, 2.6), minf(col.g * 1.5, 2.6), minf(col.b * 1.5, 2.6), 0.8 * fade))
