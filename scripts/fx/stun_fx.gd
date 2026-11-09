class_name StunFx
extends Node2D
## Dizzy stars circling the head of a stunned actor, plus a ring that drains with the time left to wake up
## (the actor wakes on the next hit, or when the ring is empty).

var actor: Actor
var _t := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor) or actor.state != "stunned":
		queue_free()
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var top := -actor.body_h * actor.body_scale - 8.0
	var col := Color(2.2, 2.0, 0.5)
	for i in 3:
		var a := _t * 4.5 + float(i) * TAU / 3.0
		var p := Vector2(cos(a) * 26.0, top + sin(a) * 7.0)
		var s := 5.5 + sin(a) * 1.5
		var pts := PackedVector2Array()
		for k in 10:
			var r := s if k % 2 == 0 else s * 0.45
			var ang := float(k) * PI / 5.0 - PI * 0.5 + _t * 3.0
			pts.append(p + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, col)
	var frac := clampf(actor.stunned_t / Actor.STUN_TIME, 0.0, 1.0)
	draw_arc(Vector2(0, top), 34.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, Color(col.r, col.g, col.b, 0.55), 2.5, true)
