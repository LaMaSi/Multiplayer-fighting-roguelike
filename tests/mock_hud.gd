extends Node
## HUD style mockups drawn over the real level (fake numbers).
##   godot --path . res://tests/mock_hud.tscn -- <level_scene> <out_dir>

const P1 := Color(0.15, 1.0, 1.28)
const P2 := Color(0.55, 1.28, 0.15)

var f_head: Font
var f_body: Font
var f_toon: Font


class Mock extends Control:
	var style := 0  # 0 neon, 1 cartoon, 2 minimal
	var fh: Font
	var fb: Font
	var ft: Font

	func _draw() -> void:
		match style:
			0: _neon(0)
			1: _toon()
			2: _minimal()
			3: _neon(1)
			4: _ref()

	# ---------------------------------------------------------------- helpers
	func _glow(pts: PackedVector2Array, col: Color, w := 2.0, closed := true) -> void:
		var p := pts.duplicate()
		if closed:
			p.append(pts[0])
		for i in 3:
			draw_polyline(p, Color(col.r, col.g, col.b, 0.10), w + (3 - i) * 5.0, true)
		draw_polyline(p, col, w, true)

	func _slab(x: float, y: float, w: float, h: float, sl: float, flip: bool) -> PackedVector2Array:
		if flip:
			return PackedVector2Array([Vector2(x, y), Vector2(x + w - sl, y), Vector2(x + w, y + h), Vector2(x + sl, y + h)])
		return PackedVector2Array([Vector2(x + sl, y), Vector2(x + w, y), Vector2(x + w - sl, y + h), Vector2(x, y + h)])

	func _fill_part(x: float, y: float, w: float, h: float, sl: float, flip: bool, a: float, b: float) -> PackedVector2Array:
		# part of a slab between fractions a..b measured from the outer edge
		var xa := x + w * a
		var xb := x + w * b
		if flip:
			xa = x + w - w * b
			xb = x + w - w * a
			return PackedVector2Array([Vector2(xa, y), Vector2(xb - sl * (1.0 - 0.0), y), Vector2(xb, y + h), Vector2(xa + sl, y + h)])
		return PackedVector2Array([Vector2(xa + sl, y), Vector2(xb, y), Vector2(xb - sl, y + h), Vector2(xa, y + h)])

	func _head(c: Vector2, r: float, col: Color, on: bool, toon := false) -> void:
		if toon:
			draw_circle(c, r + 3.5, Color.BLACK)
			draw_circle(c, r, col if on else Color(0.55, 0.55, 0.6))
			if on:
				draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.55))
			draw_circle(c + Vector2(-r * 0.3, 1), r * 0.2, Color.BLACK)
			draw_circle(c + Vector2(r * 0.3, 1), r * 0.2, Color.BLACK)
			if not on:
				draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color.BLACK, 3.0)
				draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), Color.BLACK, 3.0)
			return
		if on:
			draw_circle(c, r + 4.0, Color(col.r, col.g, col.b, 0.14))
			draw_arc(c, r, 0.0, TAU, 24, col, 3.0, true)
			for s in [-1.0, 1.0]:
				draw_rect(Rect2(c.x + s * r * 0.38 - r * 0.16, c.y - r * 0.15, r * 0.32, r * 0.3), Color.BLACK)
		else:
			draw_arc(c, r, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.22), 2.0, true)
			draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4), Color(1, 0.3, 0.3, 0.5), 2.0)
			draw_line(c + Vector2(r * 0.4, -r * 0.4), c + Vector2(-r * 0.4, r * 0.4), Color(1, 0.3, 0.3, 0.5), 2.0)

	func _txt(f: Font, pos: Vector2, t: String, size: int, col: Color, outline := 0, ocol := Color.BLACK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
		if outline > 0:
			draw_string_outline(f, pos, t, align, width, size, outline, ocol)
		draw_string(f, pos, t, align, width, size, col)

	# ---------------------------------------------------------------- A: neon arcade (no portraits)
	## sub 0 = compact glass panel, sub 1 = open (no panel), bigger bars
	func _neon(sub := 0) -> void:
		for pi in 2:
			var flip := pi == 1
			var col := P2 if flip else P1
			var hp := 0.58 if flip else 0.94
			var trail := 0.74 if flip else 1.0
			var meter := 0.8 if flip else 0.35
			var stocks := 2 if flip else 3
			var bw := 330.0 if sub == 0 else 440.0
			var bh := 24.0 if sub == 0 else 30.0
			var pw := bw + 60.0
			var px := 1280.0 - 22.0 - pw if flip else 22.0
			var bx := px + 28.0 if sub == 0 else px + 20.0
			if flip and sub == 1:
				bx = px + pw - 20.0 - bw
			var by := 38.0
			if sub == 0:
				var panel := _slab(px, 14, pw, 88, 20, flip)
				draw_colored_polygon(panel, Color(0.02, 0.01, 0.06, 0.6))
				_glow(panel, Color(col.r, col.g, col.b, 0.75), 2.0)
			# bar
			var slab := _slab(bx, by, bw, bh, 14, flip)
			draw_colored_polygon(slab, Color(0.03, 0.02, 0.08, 0.92))
			if trail > hp:
				draw_colored_polygon(_fill_part(bx, by, bw, bh, 14, flip, hp, trail), Color(1.5, 0.45, 0.3, 0.9))
			var c0 := Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0))
			draw_colored_polygon(_fill_part(bx, by, bw, bh, 14, flip, 0.0, hp), c0 * 0.82)
			draw_colored_polygon(_fill_part(bx, by + bh * 0.5, bw, bh * 0.5, 14, flip, 0.0, hp), c0 * 0.62)
			# thin highlight along the top of the fill
			draw_colored_polygon(_fill_part(bx + 2, by + 2, bw - 4, 4, 14, flip, 0.0, hp), Color(1, 1, 1, 0.28))
			_glow(slab, Color(col.r, col.g, col.b, 0.95), 2.0)
			# name plate and number
			var plate_w := 46.0
			var plate_x := bx + bw - plate_w if flip else bx
			var plate := _slab(plate_x, by - 22, plate_w, 18, 8, flip)
			draw_colored_polygon(plate, col)
			_txt(fh, Vector2(plate_x, by - 8), "P2" if flip else "P1", 13, Color(0.02, 0.01, 0.06), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, plate_w)
			var nx := bx if flip else bx + bw - 70.0
			_txt(fb, Vector2(nx, by - 6), "%d" % int(hp * 100.0), 22, Color(1.9, 1.9, 1.9), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT if flip else HORIZONTAL_ALIGNMENT_RIGHT, 70.0)
			# super meter
			var mw := bw * 0.62
			var mx := bx + bw - mw - 8.0 if flip else bx + 8.0
			draw_colored_polygon(_slab(mx, by + bh + 8, mw, 8, 6, flip), Color(0.03, 0.02, 0.08, 0.9))
			draw_colored_polygon(_fill_part(mx, by + bh + 8, mw, 8, 6, flip, 0.0, meter), Color(1.7, 1.7, 2.2))
			_glow(_slab(mx, by + bh + 8, mw, 8, 6, flip), Color(1.0, 1.0, 1.6, 0.5), 1.2)
			# stocks (right of the meter on the same row)
			var sx := bx + 4.0 if flip else bx + bw - 4.0
			for i in 3:
				var cx := sx + 12.0 + i * 28.0 if flip else sx - 12.0 - i * 28.0
				_head(Vector2(cx, by + bh + 12), 9.0 if sub == 0 else 10.0, col, i < stocks)
		# combo: tilted + italic, neon pink glow, slash accent behind
		var pink := Color(2.0, 0.7, 1.2)
		_txt(fh, Vector2(540, 34), "3250", 18, Color(1.6, 1.6, 1.8), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		var xf := Transform2D(Vector2(1, 0), Vector2(-0.28, 1), Vector2(640, 104)).rotated_local(-0.06)
		draw_set_transform_matrix(xf)
		var slash := PackedVector2Array([Vector2(-100, 14), Vector2(-76, -52), Vector2(100, -52), Vector2(76, 14)])
		draw_colored_polygon(slash, Color(pink.r * 0.25, pink.g * 0.12, pink.b * 0.2, 0.55))
		_glow(slash, Color(pink.r, pink.g, pink.b, 0.55), 1.5)
		for i in 3:
			_txt(fh, Vector2(-100, 0), "x18", 68, Color(pink.r, pink.g, pink.b, 0.18), 10 + i * 8, Color(pink.r, pink.g, pink.b, 0.10), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(fh, Vector2(-100, 0), "x18", 68, Color(2.0, 1.9, 2.0), 4, Color(0.05, 0.0, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(fb, Vector2(-100, 38), "TEAM COMBO  ·  3 RELAYS", 18, pink, 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# ---------------------------------------------------------------- D: ring + block bar (from reference)
	## Solid colours, no glow. Ring = health number (outer ticks = super meter); bar = 10 health blocks.
	func _ref() -> void:
		var dark := Color(0.03, 0.02, 0.07, 0.8)
		for pi in 2:
			var flip := pi == 1
			var col := Color(0.55, 0.98, 0.2) if flip else Color(0.2, 0.9, 1.0)
			var hp := 0.58 if flip else 0.94
			var trail := 0.74 if flip else 1.0
			var meter := 0.8 if flip else 0.35
			var x0 := 24.0
			var y0 := 18.0
			var cx := 1280.0 - (x0 + 38.0) if flip else x0 + 38.0
			var cy := y0 + 38.0
			# geometry is authored for P1 and mirrored for P2
			var mx := Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(1280, 0)) if flip else Transform2D.IDENTITY
			draw_set_transform_matrix(mx)
			var hx := x0 + 62.0
			var hy := y0 + 10.0
			var frame := PackedVector2Array([
				Vector2(hx, hy + 6), Vector2(hx + 34, hy + 6), Vector2(hx + 44, hy), Vector2(hx + 290, hy), Vector2(hx + 300, hy + 6),
				Vector2(hx + 386, hy + 6), Vector2(hx + 386, hy + 34), Vector2(hx + 364, hy + 56), Vector2(hx + 60, hy + 56),
				Vector2(hx + 48, hy + 50), Vector2(hx, hy + 50)])
			draw_colored_polygon(frame, dark)
			var fr := frame.duplicate()
			fr.append(frame[0])
			draw_polyline(fr, col, 3.0, true)
			# health blocks
			var bw := 29.0
			var gap := 6.0
			var bxs := hx + 22.0
			var bys := hy + 15.0
			for i in 10:
				var r := Rect2(bxs + i * (bw + gap), bys, bw, 26)
				var t0 := float(i) / 10.0
				var t1 := float(i + 1) / 10.0
				if hp >= t1:
					draw_rect(r, col)
				elif hp > t0:
					draw_rect(Rect2(r.position, Vector2(r.size.x * (hp - t0) * 10.0, r.size.y)), col)
					draw_rect(r, Color(col.r, col.g, col.b, 0.3), false, 2.0)
				elif trail > t0:
					draw_rect(r, Color(0.95, 0.4, 0.25, 0.85) if trail >= t1 else Color(0.95, 0.4, 0.25, 0.5))
				else:
					draw_rect(r, Color(col.r, col.g, col.b, 0.22), false, 2.0)
			# ring
			draw_circle(Vector2(cx if not flip else 1280.0 - cx, cy), 36.0, Color(0.03, 0.02, 0.07, 0.9))
			var rc := Vector2(cx if not flip else 1280.0 - cx, cy)
			draw_arc(rc, 36.0, 0.0, TAU, 40, col, 3.5, true)
			for i in 24:
				var a0 := -PI * 0.5 + TAU * float(i) / 24.0
				var on := float(i) / 24.0 < meter
				draw_arc(rc, 29.0, a0 + 0.03, a0 + TAU / 24.0 - 0.07, 3, Color(1, 1, 1, 0.9) if on else Color(col.r, col.g, col.b, 0.22), 4.0, true)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			_txt(fb, Vector2(cx - 30, cy + 9), "%d" % int(hp * 100.0), 28, Color(0.95, 0.95, 1.0), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			_txt(fh, Vector2(cx - 30, cy - 12), "P2" if flip else "P1", 10, col, 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
		# combo (tilted, solid, no glow)
		var pink := Color(1.0, 0.4, 0.72)
		_txt(fh, Vector2(540, 34), "3250", 18, Color(0.9, 0.9, 1.0), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		var xf := Transform2D(Vector2(1, 0), Vector2(-0.28, 1), Vector2(640, 104)).rotated_local(-0.06)
		draw_set_transform_matrix(xf)
		var slash := PackedVector2Array([Vector2(-96, 12), Vector2(-74, -52), Vector2(96, -52), Vector2(74, 12)])
		draw_colored_polygon(slash, Color(0.03, 0.02, 0.07, 0.8))
		var sl := slash.duplicate()
		sl.append(slash[0])
		draw_polyline(sl, pink, 2.5, true)
		_txt(fh, Vector2(-100, 0), "x18", 64, Color(0.97, 0.97, 1.0), 4, Color(0.05, 0.0, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(fb, Vector2(-100, 36), "TEAM COMBO  ·  3 RELAYS", 17, pink, 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# shared lives
		_txt(fb, Vector2(540, 166), "LIVES", 14, Color(0.8, 0.8, 0.9), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		for i in 3:
			_head(Vector2(610 + i * 30, 184), 9.0, Color(0.95, 0.95, 1.0), i < 2)

	# ---------------------------------------------------------------- B: cartoon
	func _rrect(r: Rect2, col: Color, rad := 10.0, outline := 5.0) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.BLACK
		sb.set_corner_radius_all(int(rad + outline))
		draw_style_box(sb, r.grow(outline))
		var sf := StyleBoxFlat.new()
		sf.bg_color = col
		sf.set_corner_radius_all(int(rad))
		draw_style_box(sf, r)

	func _toon() -> void:
		var c1 := Color(0.2, 0.8, 1.0)
		var c2 := Color(0.5, 0.9, 0.2)
		for pi in 2:
			var flip := pi == 1
			var col := c2 if flip else c1
			var hp := 0.58 if flip else 0.94
			var trail := 0.74 if flip else 1.0
			var stocks := 2 if flip else 3
			var bw := 300.0
			var bx := 1280.0 - 24.0 - 80.0 - bw if flip else 24.0 + 80.0
			var by := 46.0
			# bar
			_rrect(Rect2(bx, by, bw, 30), Color(0.18, 0.1, 0.25), 12.0, 5.0)
			var ox := bx + bw * (1.0 - trail) if flip else bx
			_rrect_clip(Rect2(ox, by, bw * trail, 30), Color(1.0, 0.45, 0.2), flip)
			var hx := bx + bw * (1.0 - hp) if flip else bx
			_rrect_clip(Rect2(hx, by, bw * hp, 30), col, flip)
			var hl := Rect2(hx + 8, by + 4, bw * hp - 16, 7)
			draw_rect(hl, Color(1, 1, 1, 0.4))
			# portrait
			var pc := Vector2(bx + bw + 52.0, by + 18) if flip else Vector2(bx - 52.0, by + 18)
			draw_circle(pc, 43, Color.BLACK)
			draw_circle(pc, 37, col)
			draw_circle(pc + Vector2(-12, -14), 9, Color(1, 1, 1, 0.45))
			for s in [-1.0, 1.0]:
				draw_circle(pc + Vector2(s * 12, -2), 9, Color.WHITE)
				draw_circle(pc + Vector2(s * 12 + 2, -1), 4.5, Color.BLACK)
			draw_arc(pc + Vector2(0, 8), 12, 0.25, PI - 0.25, 12, Color.BLACK, 4.0, true)
			_txt(ft, Vector2(bx + (bw - 50 if flip else 4), by - 8), "P2" if flip else "P1", 30, Color.WHITE, 8)
			# stocks
			for i in 3:
				var cx := bx + bw - 14.0 - i * 36.0 if flip else bx + 14.0 + i * 36.0
				_head(Vector2(cx, 104), 13.0, col, i < stocks, true)
		# combo
		draw_set_transform(Vector2(640, 90), -0.1, Vector2.ONE)
		_txt(ft, Vector2(-100, 30), "18", 110, Color(1.0, 0.85, 0.15), 18, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(ft, Vector2(-100, 52), "HIT COMBO!", 30, Color.WHITE, 8, Color(0.8, 0.1, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _rrect_clip(r: Rect2, col: Color, _flip: bool) -> void:
		var sf := StyleBoxFlat.new()
		sf.bg_color = col
		sf.set_corner_radius_all(10)
		draw_style_box(sf, r)

	# ---------------------------------------------------------------- C: minimal
	func _minimal() -> void:
		for pi in 2:
			var flip := pi == 1
			var col := P2 if flip else P1
			var hp := 0.58 if flip else 0.94
			var stocks := 2 if flip else 3
			var w := 260.0
			var x := 1280.0 - 24.0 - w if flip else 24.0
			draw_rect(Rect2(x, 24, w, 8), Color(0.03, 0.02, 0.08, 0.8))
			var fx := x + w * (1.0 - hp) if flip else x
			draw_rect(Rect2(fx, 24, w * hp, 8), col)
			draw_rect(Rect2(x - 1, 23, w + 2, 10), Color(col.r, col.g, col.b, 0.35), false, 1.5)
			for i in 3:
				var cx := x + w - 8.0 - i * 20.0 if flip else x + 8.0 + i * 20.0
				_head(Vector2(cx, 48), 6.0, col, i < stocks)
			_txt(fb, Vector2(x + (w - 30 if flip else 0), 20), "P2" if flip else "P1", 15, col)
		_txt(fb, Vector2(540, 56), "x18", 40, Color(2.0, 1.9, 2.0), 3, Color(0.05, 0.0, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 200.0)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	f_head = _font("res://assets/fonts/Orbitron.ttf", 800)
	f_body = _font("res://assets/fonts/Rajdhani-Bold.ttf", 0)
	f_toon = _font("res://assets/fonts/Bangers.ttf", 0)
	Pal.terrain_pink = true
	Backdrop.variant = 4
	var level: LevelBase = load(String(args[0])).instantiate()
	add_child(level)
	for i in 10:
		await get_tree().process_frame
	level.hud.visible = false
	Dbg._hint.visible = false
	level.fighters[0].global_position = Vector2(560, 469)
	level.fighters[1].global_position = Vector2(660, 469)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var m := Mock.new()
	m.fh = f_head
	m.fb = f_body
	m.ft = f_toon
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(m)
	for s in [4]:
		m.style = s
		m.queue_redraw()
		for i in 25:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hud_%d.png" % [args[1], s])
	get_tree().quit()


func _font(path: String, weight: int) -> Font:
	var f: Font = load(path)
	if weight > 0:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		return fv
	return f
