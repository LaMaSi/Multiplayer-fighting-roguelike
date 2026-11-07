extends Node
## Mockups: level complete + shop screens (fake data), drawn over the real backdrop.
##   godot --path . res://tests/mock_screens.tscn -- <level_scene> <out_dir>

const P1 := Color(0.2, 0.9, 1.0)
const P2 := Color(0.55, 0.98, 0.2)
const PINK := Color(1.0, 0.4, 0.72)
const AMBER := Color(1.0, 0.72, 0.25)
const INK := Color(0.03, 0.02, 0.07)
const TEXT := Color(0.95, 0.95, 1.0)

var f_head: Font
var f_body: Font


class Screen extends Control:
	var mode := 0  # 0 level complete, 1 shop
	var fh: Font
	var fb: Font
	var tt := 0.31

	func _txt(f: Font, pos: Vector2, t: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, ocol := Color.BLACK) -> void:
		if outline > 0:
			draw_string_outline(f, pos, t, align, width, size, outline, ocol)
		draw_string(f, pos, t, align, width, size, col)

	func _poly_line(pts: PackedVector2Array, col: Color, w: float) -> void:
		var p := pts.duplicate()
		p.append(pts[0])
		draw_polyline(p, col, w, true)

	## chamfered rectangle (top-right and bottom-left corners cut)
	func _chamfer(r: Rect2, c: float) -> PackedVector2Array:
		return PackedVector2Array([r.position, Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c), r.end, Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c)])

	func _coin(c: Vector2, r: float) -> void:
		draw_circle(c, r, Color(0.05, 0.03, 0.02))
		draw_circle(c, r - 2.0, AMBER_C)
		draw_arc(c, r * 0.55, 0.0, TAU, 20, Color(0.45, 0.25, 0.05), 2.0, true)

	const AMBER_C := Color(1.0, 0.72, 0.25)

	func _head(c: Vector2, r: float, col: Color, on := true) -> void:
		draw_arc(c, r, 0.0, TAU, 20, col if on else Color(col.r, col.g, col.b, 0.25), 3.0, true)
		if on:
			for s in [-1.0, 1.0]:
				draw_rect(Rect2(c.x + s * r * 0.38 - r * 0.16, c.y - r * 0.15, r * 0.32, r * 0.3), Color.BLACK)

	func _draw() -> void:
		if mode == 0:
			_level_complete()
		else:
			_shop()

	# ------------------------------------------------------------ level complete
	func _level_complete() -> void:
		var pink := PINK
		# title
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.25, 1), Vector2(640, 66)).rotated_local(-0.02))
		for k in 3:
			_txt(fh, Vector2(-400, 0), "LEVEL COMPLETE", 46, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
		_txt(fh, Vector2(-400, 0), "LEVEL COMPLETE", 46, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 4, Color(0.05, 0.0, 0.1))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_txt(fb, Vector2(240, 96), "STREETS  ·  ARENA 2 OF 3", 20, pink, HORIZONTAL_ALIGNMENT_CENTER, 800.0)
		# rank plate
		_txt(fh, Vector2(180, 150), "TEAM RANK", 18, Color(0.8, 0.8, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 300.0)
		var gold := Color(2.4, 1.7, 0.5)
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.22, 1), Vector2(330, 300)).rotated_local(-0.07))
		var plate := PackedVector2Array([Vector2(-130, 100), Vector2(-96, -110), Vector2(130, -110), Vector2(96, 100)])
		for k in 3:
			draw_colored_polygon(Geometry2D.offset_polygon(plate, 6.0 + k * 8.0)[0], Color(gold.r, gold.g, gold.b, 0.12 - k * 0.03))
		draw_colored_polygon(plate, INK)
		_poly_line(plate, Color(1.0, 0.8, 0.3), 4.0)
		for k in 3:
			_txt(fh, Vector2(-150, 70), "S", 210, Color(gold.r, gold.g, gold.b, 0.2), HORIZONTAL_ALIGNMENT_CENTER, 300.0, 10 + k * 10, Color(gold.r, gold.g, gold.b, 0.1))
		_txt(fh, Vector2(-150, 70), "S", 210, Color(2.4, 2.1, 1.4), HORIZONTAL_ALIGNMENT_CENTER, 300.0, 6, Color(0.1, 0.04, 0.0))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var chip := Rect2(180, 428, 300, 34)
		draw_colored_polygon(_chamfer(chip, 8.0), Color(0.03, 0.02, 0.07, 0.85))
		_poly_line(_chamfer(chip, 8.0), AMBER, 2.5)
		_txt(fb, Vector2(180, 453), "S RANK  ·  +1 REWARD CARD FOR BOTH", 18, AMBER, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
		# stats
		var rows := [
			["COMBO PEAK", "x35", "S", 1.0], ["DAMAGE TAKEN", "12%", "A", 0.85], ["TIME  (PAR 2:00)", "1:42", "S", 1.0],
			["CONTAINERS", "9 / 10", "A", 0.9], ["RELAY HITS", "14", "S", 1.0], ["RESCUES", "1", "+", 1.0],
		]
		var y := 168.0
		for r in rows:
			draw_rect(Rect2(660, y + 36, 560, 2), Color(1, 1, 1, 0.12))
			_txt(fb, Vector2(660, y + 28), String(r[0]), 26, Color(0.85, 0.85, 1.0))
			_txt(fh, Vector2(940, y + 28), String(r[1]), 24, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
			var tile := Rect2(1172, y + 2, 48, 32)
			var big := String(r[2]) == "S"
			draw_colored_polygon(_chamfer(tile, 8.0), Color(1.0, 0.72, 0.25, 0.9) if big else Color(0.1, 0.07, 0.18, 0.9))
			if not big:
				_poly_line(_chamfer(tile, 8.0), Color(0.8, 0.8, 1.0, 0.7), 2.0)
			_txt(fh, Vector2(1172, y + 27), String(r[2]), 20, Color(0.1, 0.04, 0.0) if big else TEXT, HORIZONTAL_ALIGNMENT_CENTER, 48.0)
			y += 50.0
		# score
		_txt(fb, Vector2(660, 520), "TEAM SCORE", 22, Color(0.8, 0.8, 0.95))
		_txt(fh, Vector2(840, 530), "12,480", 54, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 380.0, 5, Color(0.05, 0.0, 0.1))
		# rewards band
		var by := 566.0
		var chips := [["+320", "COINS (SHARED)"], ["+20 HP", "HEART LINK REFILL"]]
		var cx := 660.0
		for c in chips:
			var rr := Rect2(cx, by, 270, 56)
			draw_colored_polygon(_chamfer(rr, 10.0), Color(0.03, 0.02, 0.07, 0.8))
			_poly_line(_chamfer(rr, 10.0), Color(0.8, 0.8, 1.0, 0.55), 2.0)
			if String(c[0]) == "+320":
				_coin(Vector2(cx + 30, by + 28), 14.0)
			_txt(fh, Vector2(cx + 54, by + 26), String(c[0]), 22, AMBER if String(c[0]) == "+320" else P1)
			_txt(fb, Vector2(cx + 54, by + 47), String(c[1]), 15, Color(0.8, 0.8, 0.95))
			cx += 290.0
		# unlock meter
		var mr := Rect2(660, 646, 560, 22)
		draw_colored_polygon(_chamfer(mr, 8.0), Color(0.03, 0.02, 0.07, 0.85))
		draw_colored_polygon(_chamfer(Rect2(662, 648, 556 * 0.62, 18), 6.0), PINK)
		draw_colored_polygon(_chamfer(Rect2(662 + 556 * 0.62, 648, 556 * 0.16, 18), 6.0), Color(1.0, 1.0, 1.0, 0.85))
		_poly_line(_chamfer(mr, 8.0), Color(0.8, 0.8, 1.0, 0.7), 2.0)
		_txt(fb, Vector2(660, 641), "UNLOCK PROGRESS   +16%   ·   NEXT: SWORD CLASS", 15, Color(0.8, 0.8, 0.95))
		# continue prompt
		var a := 0.55 + 0.45 * sin(tt * 5.0)
		_txt(fh, Vector2(660, 704), "A  CONTINUE", 20, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_RIGHT, 560.0)

	# ------------------------------------------------------------ shop
	func _icon(kind: String, c: Vector2, col: Color) -> void:
		match kind:
			"move":
				draw_arc(c + Vector2(-6, 6), 30.0, -2.4, 0.3, 16, col, 7.0, true)
				draw_arc(c + Vector2(-6, 6), 20.0, -2.0, 0.0, 12, Color(col.r, col.g, col.b, 0.5), 4.0, true)
			"mine":
				draw_circle(c, 15.0, col)
				for i in 8:
					var a := TAU * float(i) / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * 15.0, c + Vector2(cos(a), sin(a)) * 25.0, col, 4.0)
				draw_circle(c, 6.0, INK)
			"up":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -28), c + Vector2(24, 0), c + Vector2(8, 0), c + Vector2(8, 24), c + Vector2(-8, 24), c + Vector2(-8, 0), c + Vector2(-24, 0)]), col)
			"life":
				_head(c, 18.0, col)
				draw_line(c + Vector2(22, -22), c + Vector2(22, -8), col, 4.0)
				draw_line(c + Vector2(15, -15), c + Vector2(29, -15), col, 4.0)

	func _shop() -> void:
		# title + wallet
		draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.25, 1), Vector2(40, 70)).rotated_local(-0.02))
		for k in 3:
			_txt(fh, Vector2(0, 0), "SHOP", 52, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
		_txt(fh, Vector2(0, 0), "SHOP", 52, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_txt(fb, Vector2(44, 100), "EVERYTHING IS BOUGHT TOGETHER", 18, PINK)
		var wr := Rect2(980, 30, 260, 64)
		draw_colored_polygon(_chamfer(wr, 12.0), Color(0.03, 0.02, 0.07, 0.85))
		_poly_line(_chamfer(wr, 12.0), AMBER, 3.0)
		_coin(Vector2(1014, 62), 17.0)
		_txt(fb, Vector2(1040, 52), "SHARED WALLET", 14, Color(0.8, 0.8, 0.95))
		_txt(fh, Vector2(1040, 84), "260", 30, AMBER)
		# cards
		var cards := [
			{"n": "GROUND WAVE", "tag": "ADAPTS TO CLASS", "d": "Low shockwave that\\ntrips grounded foes", "p": 120, "i": "move"},
			{"n": "POCKET MINE", "tag": "OFF-HAND", "d": "Drop a mine that\\nlaunches enemies", "p": 90, "i": "mine"},
			{"n": "EMPOWER JAB", "tag": "UPGRADE", "d": "+25% damage,\\nshorter recovery", "p": 150, "i": "up"},
			{"n": "EXTRA LIFE", "tag": "TEAM", "d": "+1 shared life\\nfor this run", "p": 300, "i": "life"},
		]
		var cx := 400.0
		var cy := 150.0
		var cw := 190.0
		var ch := 270.0
		var idx := 0
		for c in cards:
			var r := Rect2(cx, cy, cw, ch)
			var afford: bool = int(c["p"]) <= 260
			var sel := idx == 1
			draw_colored_polygon(_chamfer(r, 16.0), Color(0.03, 0.02, 0.07, 0.88 if afford else 0.7))
			_poly_line(_chamfer(r, 16.0), TEXT if sel else (Color(0.8, 0.8, 1.0, 0.55) if afford else Color(0.8, 0.8, 1.0, 0.2)), 5.0 if sel else 2.5)
			var ic := AMBER if afford else Color(0.5, 0.5, 0.6)
			_icon(String(c["i"]), Vector2(cx + cw * 0.5, cy + 72), ic)
			var tagw := 150.0
			draw_rect(Rect2(cx + (cw - tagw) * 0.5, cy + 118, tagw, 20), Color(1, 1, 1, 0.12))
			_txt(fh, Vector2(cx, cy + 133), String(c["tag"]), 10, Color(0.85, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, cw)
			_txt(fb, Vector2(cx, cy + 166), String(c["n"]), 24, TEXT if afford else Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER, cw)
			var lines: PackedStringArray = String(c["d"]).split("\\n")
			for li in lines.size():
				_txt(fb, Vector2(cx, cy + 194 + li * 18), lines[li], 15, Color(0.78, 0.78, 0.9) if afford else Color(0.5, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER, cw)
			var pr := Rect2(cx + 36, cy + ch - 40, cw - 72, 30)
			draw_colored_polygon(_chamfer(pr, 8.0), Color(0.12, 0.08, 0.02, 0.9) if afford else Color(0.2, 0.05, 0.08, 0.9))
			_coin(Vector2(pr.position.x + 18, pr.position.y + 15), 9.0)
			_txt(fh, Vector2(pr.position.x + 30, pr.position.y + 22), str(c["p"]), 18, AMBER if afford else Color(1.0, 0.35, 0.35))
			if not afford:
				_txt(fb, Vector2(cx, cy + ch + 22), "NOT ENOUGH COINS", 14, Color(1.0, 0.45, 0.45), HORIZONTAL_ALIGNMENT_CENTER, cw)
			if sel:
				# player cursors above the card
				var p1 := Rect2(cx + 6, cy - 26, 84, 22)
				var p2 := Rect2(cx + cw - 90, cy - 26, 84, 22)
				draw_colored_polygon(_chamfer(p1, 6.0), P1)
				draw_colored_polygon(_chamfer(p2, 6.0), Color(P2.r, P2.g, P2.b, 0.25))
				_poly_line(_chamfer(p2, 6.0), P2, 2.0)
				_txt(fh, Vector2(p1.position.x + 8, p1.position.y + 16), "P1", 12, INK)
				# check mark
				var k0 := Vector2(p1.position.x + 50, p1.position.y + 12)
				draw_polyline(PackedVector2Array([k0, k0 + Vector2(5, 6), k0 + Vector2(16, -7)]), INK, 3.0, true)
				_txt(fh, Vector2(p2.position.x + 8, p2.position.y + 16), "P2", 12, P2)
				_txt(fh, Vector2(p2.position.x + 36, p2.position.y + 16), "...", 14, P2)
			cx += cw + 16.0
			idx += 1
		# vote strip
		var vr := Rect2(400, 458, 808, 40)
		draw_colored_polygon(_chamfer(vr, 10.0), Color(0.03, 0.02, 0.07, 0.8))
		_txt(fb, Vector2(416, 485), "BUY  POCKET MINE  FOR  90?", 22, TEXT)
		_txt(fb, Vector2(820, 485), "WAITING FOR P2", 18, P2, HORIZONTAL_ALIGNMENT_RIGHT, 372.0)
		# buttons
		var b1 := Rect2(400, 516, 220, 44)
		var b2 := Rect2(988, 516, 220, 44)
		for b in [b1, b2]:
			draw_colored_polygon(_chamfer(b, 10.0), Color(0.03, 0.02, 0.07, 0.85))
			_poly_line(_chamfer(b, 10.0), Color(0.8, 0.8, 1.0, 0.6), 2.5)
		_txt(fb, Vector2(b1.position.x, b1.position.y + 30), "REROLL STOCK", 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
		_coin(Vector2(b1.position.x + 168, b1.position.y + 22), 9.0)
		_txt(fh, Vector2(b1.position.x + 180, b1.position.y + 29), "40", 16, AMBER)
		_txt(fb, Vector2(b2.position.x, b2.position.y + 30), "LEAVE SHOP", 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
		# thought bubbles over the figures
		for i in 2:
			var bc := Vector2(150 + i * 160, 372 + i * 6)
			var col := P1 if i == 0 else P2
			draw_circle(bc + Vector2(-26, 52), 5.0, Color(col.r, col.g, col.b, 0.8))
			draw_circle(bc + Vector2(-16, 36), 8.0, Color(col.r, col.g, col.b, 0.8))
			draw_circle(bc, 30.0, INK)
			draw_arc(bc, 30.0, 0.0, TAU, 28, col, 3.0, true)
			_txt(fh, bc + Vector2(-30, 14), "?", 40, col, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
		_txt(fb, Vector2(60, 700), "A  VOTE TO BUY      Y  REROLL      B  LEAVE", 16, Color(0.8, 0.8, 0.95))


func _font(path: String, weight: int) -> Font:
	var f: Font = load(path)
	if weight > 0:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		return fv
	return f


func _figure(col: Color, pos: Vector2, scl: float, pose: Dictionary, aim: Vector2) -> StickFigure:
	var f := StickFigure.new()
	f.color = col
	f.arm_scale = 1.22
	f.leg_scale = 1.2
	f.eyes = true
	f.aim = aim
	f.position = pos
	f.scale = Vector2(scl, scl)
	f.set_target(pose, true)
	return f


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	f_head = _font("res://assets/fonts/Orbitron.ttf", 800)
	f_body = _font("res://assets/fonts/Rajdhani-Bold.ttf", 0)
	Pal.terrain_pink = true
	Backdrop.variant = 5
	var level: LevelBase = load(String(args[0])).instantiate()
	add_child(level)
	for i in 10:
		await get_tree().process_frame
	level.hud.visible = false
	Dbg._hint.visible = false
	for f in level.fighters:
		f.visible = false
	for n in level.get_children():
		if n is Prop or n is Pickup or n is Enemy:
			n.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.55)
	layer.add_child(dim)
	var figs := Node2D.new()
	layer.add_child(figs)
	var ui := Screen.new()
	ui.fh = f_head
	ui.fb = f_body
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)

	# ---- level complete: both figures cheer
	var cheer1 := {"lean": -0.05, "head": -0.12, "root_y": -4.0, "th_f": 0.35, "kn_f": 0.3, "th_b": -0.35, "kn_b": 0.3, "ua_f": 2.7, "la_f": 0.3, "ua_b": 2.9, "la_b": 0.2}
	var cheer2 := {"lean": 0.0, "head": -0.15, "root_y": -10.0, "th_f": 0.25, "kn_f": 0.7, "th_b": -0.25, "kn_b": 0.7, "ua_f": 2.5, "la_f": 0.4, "ua_b": 3.0, "la_b": 0.1}
	var a1 := _figure(P1, Vector2(90, 668), 1.4, cheer1, Vector2(0.4, -0.8))
	var a2 := _figure(P2, Vector2(190, 668), 1.4, cheer2, Vector2(-0.4, -0.8))
	figs.add_child(a1)
	figs.add_child(a2)
	ui.mode = 0
	ui.queue_redraw()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/screen_complete.png" % args[1])

	# ---- shop: thinking poses, eyes on the cards
	a1.queue_free()
	a2.queue_free()
	var think1 := {"lean": 0.05, "head": -0.12, "th_f": 0.18, "kn_f": 0.2, "th_b": -0.22, "kn_b": 0.25, "ua_f": 1.0, "la_f": 2.64, "ua_b": 0.45, "la_b": 2.3}
	var think2 := {"lean": 0.0, "head": 0.14, "th_f": 0.05, "kn_f": 0.1, "th_b": 0.3, "kn_b": 0.35, "ua_f": 1.0, "la_f": 2.64, "ua_b": 0.7, "la_b": 2.0}
	figs.add_child(_figure(P1, Vector2(120, 668), 1.7, think1, Vector2(0.95, -0.35)))
	figs.add_child(_figure(P2, Vector2(280, 668), 1.7, think2, Vector2(0.95, -0.2)))
	ui.mode = 1
	ui.queue_redraw()
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/screen_shop.png" % args[1])
	get_tree().quit()
