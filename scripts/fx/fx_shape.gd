class_name FxShape
extends Node2D
## Short-lived drawn effect: an expanding ring or a radiating burst of lines.

var mode := "ring"
var col := Color(1, 1, 1)
var size := 40.0
var dur := 0.25
var t := 0.0
var _angles: Array[float] = []


func _ready() -> void:
	z_index = 60
	if mode == "burst":
		var base := randf() * TAU
		for i in 8:
			_angles.append(base + TAU * i / 8.0 + randf_range(-0.25, 0.25))
	var tw := create_tween()
	tw.tween_property(self, "t", 1.0, dur)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - t
	var c := Color(col.r, col.g, col.b, a)
	if mode == "ring":
		var r := size * (1.0 - pow(1.0 - t, 3.0))
		draw_arc(Vector2.ZERO, maxf(r, 1.0), 0.0, TAU, 40, c, 1.5 + 5.0 * a, true)
	else:
		# needles: wide at the base, pointed at the outer tip
		for ang in _angles:
			var d := Vector2.from_angle(ang)
			var nrm := Vector2(-d.y, d.x)
			var e := 1.0 - pow(1.0 - t, 2.0)
			var base := d * size * (0.15 + 0.5 * e)
			var tip := d * size * (0.45 + 0.75 * e)
			var hw := 1.5 + 4.5 * a
			draw_colored_polygon(PackedVector2Array([base + nrm * hw, tip, base - nrm * hw]), c)
