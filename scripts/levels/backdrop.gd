class_name Backdrop
extends Node2D
## Procedural parallax skyline: a few layers of silhouette buildings with lit windows.
## Each layer drifts at a fraction of the camera speed. theme: sky_top, sky_bottom, bld (colors).

class SkyLayer extends Node2D:
	var factor := 0.5
	var blds: Array = []  # [x, w, h]
	var fill := Color(0.06, 0.03, 0.12)
	var edge := Color(0.6, 0.2, 0.9)
	var win := Color(1.6, 1.0, 0.4)
	var ground_y := 600.0
	var windows := true

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for b in blds:
			var r := Rect2(b[0], ground_y - b[2], b[1], b[2] + 200.0)
			draw_rect(r, fill)
			draw_line(r.position, Vector2(r.end.x, r.position.y), edge, 2.0)
			draw_line(r.position, Vector2(r.position.x, ground_y), Color(edge.r, edge.g, edge.b, 0.4), 1.5)
			if windows:
				var cols := int(b[1] / 22.0)
				var rows := int(b[2] / 30.0)
				for cx in cols:
					for cy in rows:
						if rng.randf() < 0.22:
							draw_rect(Rect2(r.position.x + 8 + cx * 22.0, r.position.y + 14 + cy * 30.0, 9, 13), win)


var cam: Camera2D
var _layers: Array[SkyLayer] = []


## Desaturate towards grey (sat 1 = unchanged, 0 = grey) and scale brightness: anything bright in the
## foreground then reads as gameplay.
static func _mute(c: Color, k: float, sat: float) -> Color:
	var g := (c.r + c.g + c.b) / 3.0
	return Color(lerpf(g, c.r, sat) * k, lerpf(g, c.g, sat) * k, lerpf(g, c.b, sat) * k, c.a)


func setup(theme: Dictionary, level_w: float, ground_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(theme.get("seed", 3))
	var specs := [
		{"f": 0.25, "hmin": 260.0, "hmax": 520.0, "wmin": 90.0, "wmax": 170.0, "fill": theme["bld_far"], "edge": theme["edge_far"], "win": false, "gap": 10.0},
		{"f": 0.5, "hmin": 180.0, "hmax": 400.0, "wmin": 100.0, "wmax": 200.0, "fill": theme["bld_mid"], "edge": theme["edge_mid"], "win": true, "gap": 16.0},
		{"f": 0.78, "hmin": 90.0, "hmax": 250.0, "wmin": 120.0, "wmax": 240.0, "fill": theme["bld_near"], "edge": theme["edge_near"], "win": true, "gap": 30.0},
	]
	for s in specs:
		var l := SkyLayer.new()
		l.factor = s["f"]
		l.fill = _mute(s["fill"], 0.75, 0.7)
		l.edge = _mute(s["edge"], 0.34, 0.5)  # below the bloom threshold, so the skyline never glows
		l.win = _mute(theme["window"], 0.36, 0.45)
		l.modulate.a = {0.25: 0.6, 0.5: 0.76, 0.78: 0.9}.get(s["f"], 0.8)  # atmospheric haze: far layers fade into the sky
		l.windows = s["win"]
		l.ground_y = ground_y
		l.z_index = -50
		var x := -1400.0
		while x < level_w * float(s["f"]) + 2000.0:
			var w := rng.randf_range(s["wmin"], s["wmax"])
			l.blds.append([x, w, rng.randf_range(s["hmin"], s["hmax"])])
			x += w + rng.randf_range(0.0, s["gap"])
		add_child(l)
		_layers.append(l)


func _process(_d: float) -> void:
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	for l in _layers:
		l.position.x = c.x * (1.0 - l.factor)
