class_name Backdrop
extends Node2D
## Procedural parallax skyline: a few layers of silhouette buildings with lit windows.
## Each layer drifts at a fraction of the camera speed. theme: sky_top, sky_bottom, bld (colors).

## Visual style variants for the background (0 = the original look, kept for comparison).
##   fog: how far the fill is pulled toward the haze colour (per layer, far layers get more)
##   desat: 0..1 pull toward grey, dim: brightness multiplier, edge: roof-line alpha (0 = pure silhouette)
##   win: window alpha, dens: window density multiplier
static var variant := 2
const STYLES := [
	{"fog": 0.0, "desat": 0.0, "dim": 1.0, "edge": 1.0, "win": 1.0, "dens": 1.0},
	{"fog": 0.55, "desat": 0.35, "dim": 0.75, "edge": 0.0, "win": 0.35, "dens": 0.6},
	{"fog": 0.7, "desat": 0.6, "dim": 0.6, "edge": 0.0, "win": 0.18, "dens": 0.35},
	{"fog": 0.35, "desat": 0.25, "dim": 0.45, "edge": 0.12, "win": 0.5, "dens": 0.5},
]

class SkyLayer extends Node2D:
	var factor := 0.5
	var blds: Array = []  # [x, w, h]
	var fill := Color(0.06, 0.03, 0.12)
	var edge := Color(0.6, 0.2, 0.9)
	var win := Color(1.6, 1.0, 0.4)
	var ground_y := 600.0
	var windows := true
	var edge_a := 1.0
	var dens := 0.22

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for b in blds:
			var r := Rect2(b[0], ground_y - b[2], b[1], b[2] + 200.0)
			draw_rect(r, fill)
			if edge_a > 0.0:
				draw_line(r.position, Vector2(r.end.x, r.position.y), Color(edge.r, edge.g, edge.b, edge_a), 2.0)
				draw_line(r.position, Vector2(r.position.x, ground_y), Color(edge.r, edge.g, edge.b, 0.4 * edge_a), 1.5)
			if windows:
				var cols := int(b[1] / 22.0)
				var rows := int(b[2] / 30.0)
				for cx in cols:
					for cy in rows:
						if rng.randf() < dens:
							draw_rect(Rect2(r.position.x + 8 + cx * 22.0, r.position.y + 14 + cy * 30.0, 9, 13), win)


var cam: Camera2D
var _layers: Array[SkyLayer] = []


func setup(theme: Dictionary, level_w: float, ground_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(theme.get("seed", 3))
	var specs := [
		{"f": 0.25, "hmin": 260.0, "hmax": 520.0, "wmin": 90.0, "wmax": 170.0, "fill": theme["bld_far"], "edge": theme["edge_far"], "win": false, "gap": 10.0},
		{"f": 0.5, "hmin": 180.0, "hmax": 400.0, "wmin": 100.0, "wmax": 200.0, "fill": theme["bld_mid"], "edge": theme["edge_mid"], "win": true, "gap": 16.0},
		{"f": 0.78, "hmin": 90.0, "hmax": 250.0, "wmin": 120.0, "wmax": 240.0, "fill": theme["bld_near"], "edge": theme["edge_near"], "win": true, "gap": 30.0},
	]
	var st: Dictionary = STYLES[clampi(variant, 0, STYLES.size() - 1)]
	var haze: Color = (theme["sky_bottom"] as Color).darkened(0.35)
	for s in specs:
		var l := SkyLayer.new()
		l.factor = s["f"]
		var fill: Color = s["fill"]
		var far_t: float = 1.0 - (float(s["f"]) - 0.25) / 0.53  # 1 = farthest, 0 = nearest
		var grey := Color(fill.get_luminance(), fill.get_luminance(), fill.get_luminance())
		fill = fill.lerp(grey, st["desat"]).lerp(haze, float(st["fog"]) * (0.35 + 0.65 * far_t))
		fill = Color(fill.r * st["dim"], fill.g * st["dim"], fill.b * st["dim"], 1.0)
		l.fill = fill
		l.edge = s["edge"]
		l.edge_a = st["edge"]
		l.dens = 0.22 * float(st["dens"])
		var wc: Color = theme["window"]
		l.win = Color(wc.r, wc.g, wc.b, float(st["win"]))
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
