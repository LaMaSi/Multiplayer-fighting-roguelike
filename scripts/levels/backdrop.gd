class_name Backdrop
extends Node2D
## Procedural parallax skyline: a few layers of silhouette buildings with lit windows.
## Each layer drifts at a fraction of the camera speed. theme: sky_top, sky_bottom, bld (colors).

## Visual style variants for the background (0 = the original look, kept for comparison).
##   fog: how far the fill is pulled toward the haze colour (per layer, far layers get more)
##   desat: 0..1 pull toward grey, dim: brightness multiplier, edge: roof-line alpha (0 = pure silhouette)
##   win: window alpha, dens: window density multiplier
static var variant := 5
const STYLES := [
	{"fog": 0.0, "desat": 0.0, "dim": 1.0, "edge": 1.0, "win": 1.0, "dens": 1.0},
	{"fog": 0.55, "desat": 0.35, "dim": 0.75, "edge": 0.0, "win": 0.35, "dens": 0.6},
	{"fog": 0.7, "desat": 0.6, "dim": 0.6, "edge": 0.0, "win": 0.18, "dens": 0.35},
	{"fog": 0.35, "desat": 0.25, "dim": 0.45, "edge": 0.12, "win": 0.5, "dens": 0.5},
	{"fog": 0.0, "desat": 0.0, "dim": 1.0, "edge": 0.0, "win": 1.0, "dens": 0.28, "limited": true},  # 4: limited palette
	{"fog": 0.0, "desat": 0.0, "dim": 1.0, "edge": 0.0, "win": 1.0, "dens": 0.28, "synth": true},  # 5: synthwave
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
	var synth := false
	var li := 0  ## layer index 0 far .. 2 near (synth)

	func _draw_synth() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + li
		var base: Color = Pal.SYNTH_FILL[li]
		var rim: Color = Pal.SYNTH_RIM[li]
		var haze: Color = Pal.SYNTH_HAZE
		haze.a = Pal.SYNTH_HAZE_A[li]
		var win_a: float = Pal.SYNTH_WIN_A[li]
		for b in blds:
			var x: float = b[0]
			var w: float = b[1]
			var h: float = b[2]
			var v: float = b[3]
			var fill := base.lightened((v - 0.5) * 0.16)
			var top := ground_y - h
			var dark := fill.darkened(0.3)
			draw_rect(Rect2(x, top, w, h + 200.0), fill)
			draw_rect(Rect2(x + w * 0.66, top, w * 0.34, h + 200.0), dark)
			# setback on the roof
			if b[4] > 0.45:
				var sw: float = w * (0.35 + 0.3 * float(b[4]))
				var sh: float = 12.0 + float(b[5]) * 34.0
				var sx: float = x + (w - sw) * 0.5
				draw_rect(Rect2(sx, top - sh, sw, sh), fill)
				draw_rect(Rect2(sx + sw * 0.6, top - sh, sw * 0.4, sh), dark)
				if rim.a > 0.0:
					draw_rect(Rect2(sx, top - sh, 2.0, sh), rim)
				top -= sh
			# antenna on some tall ones
			if b[6] > 0.7 and h > 150.0:
				var ah: float = 26.0 + float(b[6]) * 60.0
				draw_line(Vector2(x + w * 0.5, top), Vector2(x + w * 0.5, top - ah), dark, 2.0)
				if li > 0:
					draw_circle(Vector2(x + w * 0.5, top - ah), 2.5, Color(1.0, 0.35, 0.55, 0.9))
			# cool rim light on the lit (left) edge
			if rim.a > 0.0:
				draw_rect(Rect2(x, ground_y - h, 2.0, h + 20.0), rim)
			# horizon haze on the lower part
			for k in 8:
				var hz := haze
				hz.a = haze.a * float(k + 1) / 8.0 * 0.35
				draw_rect(Rect2(x, ground_y - 200.0 + k * 25.0, w, 25.0 + (200.0 if k == 7 else 0.0)), hz)
			# windows: whole columns lit, rows mostly lit, one colour family per building
			if win_a > 0.0:
				var wc: Color = Pal.SYNTH_WIN[int(floor(v * 7.0)) % 2]
				wc.a = win_a
				var cols := int((w - 14.0) / 12.0)
				var rows := int((h - 22.0) / 16.0)
				for cx in cols:
					if rng.randf() < 0.55:
						for cy in rows:
							if rng.randf() < 0.72:
								draw_rect(Rect2(x + 9.0 + cx * 12.0, ground_y - h + 12.0 + cy * 16.0, 6, 9), wc)

	func _draw() -> void:
		if synth:
			_draw_synth()
			return
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


class SunLayer extends Node2D:
	var ground_y := 600.0
	var stars: Array = []

	func _draw() -> void:
		for st in stars:
			draw_rect(Rect2(st[0], ground_y - st[1], st[2], st[2]), Color(0.85, 0.8, 1.0, st[3]))
		var c := Vector2(300.0, ground_y - 380.0)
		var r := 150.0
		for i in 3:
			draw_circle(c, r + 26.0 - i * 9.0, Color(1.0, 0.3, 0.55, 0.05))
		var yy := -r
		while yy < r:
			var t := (yy + r) / (2.0 * r)
			var skip := false
			if t > 0.52:
				var period := 15.0
				var gap := lerpf(2.0, 10.0, (t - 0.52) / 0.48)
				skip = fposmod(yy + r, period) < gap
			if not skip:
				var half := sqrt(maxf(r * r - yy * yy, 0.0))
				var col: Color = (Pal.SYNTH_SUN[0] as Color).lerp(Pal.SYNTH_SUN[1], t)
				draw_rect(Rect2(c.x - half, c.y + yy, half * 2.0, 1.6), col)
			yy += 1.0


var cam: Camera2D
var _layers: Array[SkyLayer] = []
var _sun: SunLayer


func setup(theme: Dictionary, level_w: float, ground_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(theme.get("seed", 3))
	var specs := [
		{"f": 0.25, "hmin": 260.0, "hmax": 520.0, "wmin": 90.0, "wmax": 170.0, "fill": theme["bld_far"], "edge": theme["edge_far"], "win": false, "gap": 10.0},
		{"f": 0.5, "hmin": 180.0, "hmax": 400.0, "wmin": 100.0, "wmax": 200.0, "fill": theme["bld_mid"], "edge": theme["edge_mid"], "win": true, "gap": 16.0},
		{"f": 0.78, "hmin": 90.0, "hmax": 250.0, "wmin": 120.0, "wmax": 240.0, "fill": theme["bld_near"], "edge": theme["edge_near"], "win": true, "gap": 30.0},
	]
	var st: Dictionary = STYLES[clampi(variant, 0, STYLES.size() - 1)]
	var synth: bool = st.get("synth", false)
	if synth:
		specs = [
			{"f": 0.25, "hmin": 150.0, "hmax": 340.0, "wmin": 80.0, "wmax": 150.0, "fill": Color.BLACK, "edge": Color.BLACK, "win": false, "gap": 6.0, "tall": 0.12},
			{"f": 0.5, "hmin": 120.0, "hmax": 270.0, "wmin": 90.0, "wmax": 170.0, "fill": Color.BLACK, "edge": Color.BLACK, "win": true, "gap": 10.0, "tall": 0.0},
			{"f": 0.78, "hmin": 70.0, "hmax": 180.0, "wmin": 110.0, "wmax": 200.0, "fill": Color.BLACK, "edge": Color.BLACK, "win": true, "gap": 24.0, "tall": 0.0},
		]
	if synth:
		_sun = SunLayer.new()
		_sun.ground_y = ground_y
		_sun.z_index = -80
		for i in 70:
			_sun.stars.append([rng.randf_range(-760.0, 760.0), rng.randf_range(420.0, 1000.0), rng.randf_range(1.5, 2.8), rng.randf_range(0.25, 0.8)])
		add_child(_sun)
	var haze: Color = (theme["sky_bottom"] as Color).darkened(0.35)
	for s in specs:
		var l := SkyLayer.new()
		l.factor = s["f"]
		var fill: Color = s["fill"]
		var far_t: float = 1.0 - (float(s["f"]) - 0.25) / 0.53  # 1 = farthest, 0 = nearest
		var grey := Color(fill.get_luminance(), fill.get_luminance(), fill.get_luminance())
		fill = fill.lerp(grey, st["desat"]).lerp(haze, float(st["fog"]) * (0.35 + 0.65 * far_t))
		fill = Color(fill.r * st["dim"], fill.g * st["dim"], fill.b * st["dim"], 1.0)
		if st.get("limited", false):
			var li := clampi(int(round((float(s["f"]) - 0.25) / 0.265)), 0, 2)
			fill = Pal.BG_BUILDING[li]
		l.fill = fill
		l.edge = s["edge"]
		l.edge_a = st["edge"]
		l.dens = 0.22 * float(st["dens"])
		l.synth = synth
		l.li = clampi(int(round((float(s["f"]) - 0.25) / 0.265)), 0, 2)
		var wc: Color = theme["window"]
		l.win = Color(wc.r, wc.g, wc.b, float(st["win"]))
		if st.get("limited", false):
			l.win = Pal.BG_WINDOW
		l.windows = s["win"]
		l.ground_y = ground_y
		l.z_index = -50
		var x := -1400.0
		while x < level_w * float(s["f"]) + 2000.0:
			var w := rng.randf_range(s["wmin"], s["wmax"])
			var bh: float = rng.randf_range(s["hmin"], s["hmax"])
			if synth and rng.randf() < float(s.get("tall", 0.0)):
				bh = rng.randf_range(380.0, 470.0)
			l.blds.append([x, w, bh, rng.randf(), rng.randf(), rng.randf(), rng.randf()])
			x += w + rng.randf_range(0.0, s["gap"])
		add_child(l)
		_layers.append(l)


func _process(_d: float) -> void:
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	if _sun != null:
		_sun.position.x = c.x
	for l in _layers:
		l.position.x = c.x * (1.0 - l.factor)
