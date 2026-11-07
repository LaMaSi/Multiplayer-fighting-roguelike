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
			0: _neon()
			1: _toon()
			2: _minimal()

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

	# ---------------------------------------------------------------- A: neon arcade
	func _neon() -> void:
		for pi in 2:
			var flip := pi == 1
			var col := P2 if flip else P1
			var hp := 0.58 if flip else 0.94
			var trail := 0.74 if flip else 1.0
			var meter := 0.8 if flip else 0.35
			var stocks := 2 if flip else 3
			var px := 1280.0 - 20.0 - 430.0 if flip else 20.0
			# glass panel
			var panel := _slab(px, 14, 430, 96, 22, flip)
			draw_colored_polygon(panel, Color(0.02, 0.01, 0.06, 0.62))
			_glow(panel, Color(col.r, col.g, col.b, 0.8), 2.0)
			# portrait
			var pc := Vector2(px + (430 - 56) if flip else px + 56, 62)
			var sq := PackedVector2Array([pc + Vector2(-34, -34), pc + Vector2(34, -34), pc + Vector2(34, 34), pc + Vector2(-34, 34)])
			draw_colored_polygon(sq, Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.9))
			_glow(sq, col, 2.5)
			draw_arc(pc + Vector2(0, -8), 12, 0.0, TAU, 24, col, 3.5, true)
			draw_line(pc + Vector2(0, 4), pc + Vector2(0, 22), col, 4.0, true)
			draw_line(pc + Vector2(-16, 12), pc + Vector2(16, 12), col, 4.0, true)
			for s in [-1.0, 1.0]:
				draw_rect(Rect2(pc.x + s * 5.0 - 2.5, pc.y - 12, 5, 7), Color.BLACK)
			# health bar
			var bx := px + 8.0 if flip else px + 104.0
			var bw := 300.0
			draw_colored_polygon(_slab(bx, 30, bw, 22, 12, flip), Color(0.03, 0.02, 0.08, 0.9))
			draw_colored_polygon(_fill_part(bx, 30, bw, 22, 12, flip, 0.0, trail), Color(1.6, 1.3, 0.5, 0.85))
			for i in 12:
				var a := hp * float(i) / 12.0
				var b := hp * float(i + 1) / 12.0
				var k := 0.7 + 0.5 * float(i) / 12.0
				draw_colored_polygon(_fill_part(bx, 30, bw, 22, 12, flip, a, b), Color(col.r * k, col.g * k, col.b * k, 1.0))
			_glow(_slab(bx, 30, bw, 22, 12, flip), Color(col.r, col.g, col.b, 0.9), 2.0)
			_txt(fh, Vector2(bx + (bw - 40.0 if flip else 4.0), 26), "P2" if flip else "P1", 16, col, 0, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT)
			_txt(fb, Vector2(bx + (0.0 if flip else bw - 60.0), 26), "%d" % int(hp * 100.0), 20, Color(1.8, 1.8, 1.8), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_RIGHT if not flip else HORIZONTAL_ALIGNMENT_LEFT, 60.0)
			# super meter
			draw_colored_polygon(_slab(bx + 6, 60, 220, 8, 6, flip), Color(0.03, 0.02, 0.08, 0.9))
			draw_colored_polygon(_fill_part(bx + 6, 60, 220, 8, 6, flip, 0.0, meter), Color(1.7, 1.7, 2.2))
			_glow(_slab(bx + 6, 60, 220, 8, 6, flip), Color(1.0, 1.0, 1.6, 0.5), 1.2)
			# stocks
			for i in 3:
				var cx := bx + 16.0 + i * 30.0 if not flip else bx + bw - 16.0 - i * 30.0
				_head(Vector2(cx, 90), 9.0, col, i < stocks)
		# combo
		_txt(fh, Vector2(640, 36), "3250", 20, Color(1.6, 1.6, 1.8), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		for i in 3:
			_txt(fh, Vector2(540, 108), "x18", 72, Color(2.0, 0.7, 1.2, 0.18), 10 + i * 8, Color(2.0, 0.7, 1.2, 0.10), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(fh, Vector2(540, 108), "x18", 72, Color(2.0, 1.9, 2.0), 4, Color(0.05, 0.0, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		_txt(fb, Vector2(540, 132), "TEAM COMBO  ·  3 RELAYS", 18, Color(2.0, 0.7, 1.2), 0, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, 200.0)

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
	Backdrop.variant = 2
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
	for s in 3:
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
