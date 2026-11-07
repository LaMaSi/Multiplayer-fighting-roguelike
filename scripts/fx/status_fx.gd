class_name StatusFx
extends Node2D
## Elemental status looks on an actor (or a burning crate). Colours stay the colour of whoever applied the status
## (player colours stay meaningful); the SHAPES and MOTION say which element it is:
##   fire  = teardrop flames that flicker and rise
##   shock = jagged lightning arcs that crackle around the body
##   frost = angular ice crystals; a solid ice block while frozen

var actor: Node2D
var col := Color(2.2, 0.9, 0.3)
var _t := 0.0
var _ember_t := 0.0


func _ready() -> void:
	z_index = 3


func _active() -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if String(actor.get("state")) == "dead":
		return false
	return float(actor.get("burn_t")) > 0.0 or float(actor.get("shock_t")) > 0.0 or float(actor.get("frost_t")) > 0.0 or float(actor.get("frozen_t")) > 0.0


func _process(delta: float) -> void:
	if not _active():
		queue_free()
		return
	_t += delta
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.07
		var bh := _bh()
		var p := actor.global_position + Vector2(randf_range(-12.0, 12.0) * _bs(), -randf_range(0.2, 0.9) * bh)
		if float(actor.get("burn_t")) > 0.0:
			Fx._particles(actor.get_parent(), p, 1, col, Vector2(0, -1), 30.0, 50.0, 120.0, 0.45, Vector2(0, -260), 3.5, 0.5)
		if float(actor.get("frost_t")) > 0.0 or float(actor.get("frozen_t")) > 0.0:
			Fx._particles(actor.get_parent(), p, 1, Color(minf(col.r * 1.3, 2.4), minf(col.g * 1.3, 2.4), minf(col.b * 1.3, 2.4)), Vector2(0, 1), 20.0, 10.0, 40.0, 0.7, Vector2(0, 120), 2.5, 1.0)
	queue_redraw()


func _bs() -> float:
	return float(actor.get("body_scale")) if actor.get("body_scale") != null else 1.0


func _bh() -> float:
	var h: float = float(actor.get("body_h")) if actor.get("body_h") != null else 50.0
	return h * _bs()


func _draw() -> void:
	if not _active():
		return
	if float(actor.get("burn_t")) > 0.0:
		_draw_fire()
	if float(actor.get("shock_t")) > 0.0:
		_draw_shock()
	if float(actor.get("frost_t")) > 0.0 or float(actor.get("frozen_t")) > 0.0:
		_draw_frost()


func _bright(k: float, a: float) -> Color:
	return Color(minf(col.r * k, 2.6), minf(col.g * k, 2.6), minf(col.b * k, 2.6), a)


func _draw_fire() -> void:
	var s := _bs()
	var bh := _bh()
	var fade := clampf(float(actor.get("burn_t")) / 0.6, 0.0, 1.0)
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
		var inner := PackedVector2Array([Vector2(fx - w * 0.45, base_y), Vector2(fx + lean * 0.7, base_y - h * 0.62), Vector2(fx + w * 0.45, base_y)])
		draw_colored_polygon(inner, _bright(1.5, 0.8 * fade))


func _draw_shock() -> void:
	var s := _bs()
	var bh := _bh()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(_t * 18.0) * 104729 + 7
	for k in 3:
		var y0 := -bh * rnd.randf_range(0.1, 0.9)
		var x := rnd.randf_range(-26.0, 26.0) * s
		var pts := PackedVector2Array([Vector2(x, y0)])
		for j in 4:
			x += rnd.randf_range(-14.0, 14.0) * s
			y0 -= rnd.randf_range(6.0, 16.0) * s
			pts.append(Vector2(x, y0))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.35), 6.0, true)
		draw_polyline(pts, _bright(1.3, 1.0), 2.5, true)
		draw_polyline(pts, Color(2.6, 2.6, 2.6, 0.9), 1.0, true)


func _draw_frost() -> void:
	var s := _bs()
	var bh := _bh()
	var frozen := float(actor.get("frozen_t")) > 0.0
	if frozen:
		# a solid ice block around the whole body, with facets
		var w := 30.0 * s
		var block := PackedVector2Array([Vector2(-w, -4), Vector2(-w * 0.8, -bh - 8.0), Vector2(0, -bh - 18.0), Vector2(w * 0.8, -bh - 8.0), Vector2(w, -4)])
		draw_colored_polygon(block, Color(col.r, col.g, col.b, 0.18))
		var outline := block.duplicate()
		outline.append(block[0])
		draw_polyline(outline, _bright(1.3, 0.95), 3.0, true)
		draw_line(Vector2(-w * 0.5, -bh * 0.9), Vector2(-w * 0.2, -bh * 0.3), _bright(1.6, 0.7), 2.0, true)
		draw_line(Vector2(w * 0.3, -bh * 0.8), Vector2(w * 0.6, -bh * 0.2), _bright(1.6, 0.7), 2.0, true)
		return
	# chilled: small angular crystals clinging to the body
	for i in 6:
		var a := float(i) * 1.7 + 0.4
		var cx := sin(a * 2.3) * 16.0 * s
		var cy := -bh * (0.1 + 0.8 * fmod(float(i) * 0.31, 1.0))
		var sz := (6.0 + 3.0 * sin(_t * 3.0 + float(i))) * s
		var crystal := PackedVector2Array([Vector2(cx, cy - sz * 1.6), Vector2(cx + sz * 0.6, cy), Vector2(cx, cy + sz * 0.7), Vector2(cx - sz * 0.6, cy)])
		draw_colored_polygon(crystal, Color(col.r, col.g, col.b, 0.45))
		draw_polyline(PackedVector2Array([crystal[0], crystal[1], crystal[2], crystal[3], crystal[0]]), _bright(1.4, 0.9), 1.8, true)
