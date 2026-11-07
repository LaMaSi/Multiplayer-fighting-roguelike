extends Node
## Mockups: start screen, pause menu and loadout screen (real move data, fake state).
##   godot --path . res://tests/mock_menus.tscn -- <out_dir>

const SLOTS := ["X", "X_UP", "X_SIDE", "X_DOWN", "Y", "Y_UP", "Y_SIDE", "Y_DOWN", "B", "B_UP", "B_SIDE", "B_DOWN"]
const COLS := ["NEUTRAL", "UP", "SIDE", "DOWN"]
const ROWS := ["X", "Y", "B"]
const LOADOUTS := [
	{"X": "jab", "X_UP": "uppercut", "X_SIDE": "dash_punch", "X_DOWN": "sweep", "Y": "fireball", "Y_UP": "anti_air", "Y_DOWN": "stomp", "B": "guard", "B_SIDE": "spin_kick"},
	{"X": "jab", "X_UP": "uppercut", "X_SIDE": "flurry", "X_DOWN": "sweep", "Y": "boomerang", "Y_SIDE": "ground_wave", "B": "parry", "B_UP": "rising_dragon"},
]


class Screen extends Control:
	var mode := 0  # 0 start, 1 pause, 2 loadout
	var t := 0.3

	# ------------------------------------------------------------ shared bits
	func _button(r: Rect2, label: String, selected: bool, sub := "") -> void:
		var col := UiKit.TEXT if selected else Color(0.8, 0.8, 1.0, 0.45)
		var p := UiKit.chamfer(r, 14.0)
		if selected:
			UiKit.glow_poly(self, p, Color(2.0, 0.7, 1.2), 0.28)
		draw_colored_polygon(p, Color(0.12, 0.05, 0.2, 0.92) if selected else Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.8))
		UiKit.poly_line(self, p, col, 4.0 if selected else 2.5)
		if selected:
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(-26, r.size.y * 0.5 - 12), r.position + Vector2(-8, r.size.y * 0.5), r.position + Vector2(-26, r.size.y * 0.5 + 12)]), UiKit.PINK)
		UiKit.txt(self, UiKit.head(), r.position + Vector2(24, r.size.y * 0.5 + 8), label, 22 if selected else 20, UiKit.TEXT if selected else Color(0.8, 0.8, 0.95))
		if sub != "":
			UiKit.txt(self, UiKit.body(), r.position + Vector2(0, r.size.y * 0.5 + 7), sub, 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 22.0)

	func _title(text: String, pos: Vector2, size: int, tilt := -0.03) -> void:
		draw_set_transform_matrix(UiKit.italic(pos, tilt))
		for k in 3:
			UiKit.txt(self, UiKit.head(), Vector2.ZERO, text, size, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
		UiKit.txt(self, UiKit.head(), Vector2.ZERO, text, size, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	func _draw() -> void:
		match mode:
			0: _start()
			1: _pause()
			2: _loadout()

	# ------------------------------------------------------------ start screen
	func _start() -> void:
		# big title, centred, tilted, with a cyan/pink split shadow
		draw_set_transform_matrix(UiKit.italic(Vector2(640, 168), -0.035, 1.0, -0.22))
		UiKit.txt(self, UiKit.head(), Vector2(-520, 4), "NEON BRAWL", 104, Color(0.2, 0.9, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 1040.0, 0)
		for k in 3:
			UiKit.txt(self, UiKit.head(), Vector2(-520, 0), "NEON BRAWL", 104, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_CENTER, 1040.0, 10 + k * 10, Color(2.0, 0.7, 1.2, 0.08))
		UiKit.txt(self, UiKit.head(), Vector2(-520, 0), "NEON BRAWL", 104, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 1040.0, 5, Color(0.05, 0.0, 0.1))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# subtitle with the two player colours
		draw_rect(Rect2(430, 214, 420, 3), UiKit.PINK)
		UiKit.txt(self, UiKit.head(), Vector2(0, 248), "CO-OP STICKFIGURE BRAWLER", 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4, Color(0, 0, 0, 0.7))
		# menu
		var items := [["NEW RUN", "STREETS"], ["TRAINING ROOM", ""], ["OPTIONS", ""], ["QUIT", ""]]
		for i in items.size():
			_button(Rect2(110, 318 + i * 66, 340, 54), items[i][0], i == 0, items[i][1])
		UiKit.txt(self, UiKit.body(), Vector2(110, 612), "TESTING  >", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
		# players
		for i in 2:
			var col := UiKit.player_color(i)
			var r := Rect2(500 + i * 150, 646, 138, 38)
			UiKit.panel(self, r, 8.0, col, 2.5, 0.85)
			draw_circle(r.position + Vector2(18, 19), 5.0, col)
			UiKit.txt(self, UiKit.head(), r.position + Vector2(30, 24), "P%d" % (i + 1), 14, col)
			UiKit.txt(self, UiKit.body(), r.position + Vector2(62, 24), "PAD" if i == 0 else "KEYS", 16, UiKit.DIM_TEXT)
		UiKit.txt(self, UiKit.body(), Vector2(40, 672), "STICK  MOVE      A  SELECT", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
		UiKit.txt(self, UiKit.body(), Vector2(900, 672), "V0.1  ·  GODOT 4.5", 16, Color(0.6, 0.6, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 3)

	# ------------------------------------------------------------ pause menu
	func _mini_grid(p: int, r: Rect2) -> void:
		var col := UiKit.player_color(p)
		UiKit.panel(self, r, 14.0, col, 3.0, 0.85)
		UiKit.txt(self, UiKit.head(), r.position + Vector2(18, 30), "P%d" % (p + 1), 18, col)
		UiKit.txt(self, UiKit.body(), r.position + Vector2(66, 28), "BRAWLER", 16, UiKit.DIM_TEXT)
		var lo: Dictionary = LOADOUTS[p]
		for ci in 4:
			UiKit.txt(self, UiKit.body(), Vector2(r.position.x + 58 + ci * 78, r.position.y + 54), COLS[ci], 11, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 74.0)
		for ri in 3:
			UiKit.txt(self, UiKit.head(), Vector2(r.position.x + 18, r.position.y + 100 + ri * 48), ROWS[ri], 16, UiKit.TEXT)
			for ci in 4:
				var slot: String = SLOTS[ri * 4 + ci]
				var id: String = lo.get(slot, "")
				var cell := Rect2(r.position.x + 58 + ci * 78, r.position.y + 70 + ri * 48, 74, 40)
				if id != "":
					draw_colored_polygon(UiKit.chamfer(cell, 7.0), Color(col.r, col.g, col.b, 0.16))
					UiKit.poly_line(self, UiKit.chamfer(cell, 7.0), Color(col.r, col.g, col.b, 0.8), 2.0)
					UiKit.txt(self, UiKit.body(), cell.position + Vector2(0, 26), MoveDB.get_move(id).short.to_upper(), 17, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x)
				else:
					UiKit.poly_line(self, UiKit.chamfer(cell, 7.0), Color(1, 1, 1, 0.15), 1.5)

	func _pause() -> void:
		_title("PAUSED", Vector2(60, 96), 56, -0.02)
		var items := ["RESUME", "LOADOUT", "OPTIONS", "RESTART LEVEL", "QUIT TO MENU"]
		for i in items.size():
			_button(Rect2(80, 150 + i * 72, 330, 56), items[i], i == 1)
		# run status
		UiKit.txt(self, UiKit.head(), Vector2(470, 164), "RUN STATUS", 16, UiKit.PINK)
		UiKit.panel(self, Rect2(470, 178, 360, 50), 12.0, UiKit.AMBER, 2.5, 0.85)
		UiKit.coin(self, Vector2(498, 203), 13.0)
		UiKit.txt(self, UiKit.head(), Vector2(522, 212), "260", 22, UiKit.AMBER)
		UiKit.txt(self, UiKit.body(), Vector2(600, 210), "SHARED COINS", 16, UiKit.DIM_TEXT)
		UiKit.panel(self, Rect2(850, 178, 380, 50), 12.0, Color(0.8, 0.8, 1.0, 0.55), 2.5, 0.85)
		for h in 3:
			UiKit.heart(self, Vector2(886 + h * 36, 204), 13.0, h < 2)
		UiKit.txt(self, UiKit.body(), Vector2(1010, 210), "STREETS  ·  3 CLEARED", 16, UiKit.DIM_TEXT)
		_mini_grid(0, Rect2(470, 250, 370, 232))
		_mini_grid(1, Rect2(860, 250, 370, 232))
		UiKit.txt(self, UiKit.body(), Vector2(80, 672), "STICK  MOVE      A  SELECT      B  RESUME", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

	# ------------------------------------------------------------ loadout
	func _wrap(f: Font, s: String, size: int, width: float) -> PackedStringArray:
		var lines := PackedStringArray()
		var cur := ""
		for w in s.split(" "):
			var test := w if cur == "" else cur + " " + w
			if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
				lines.append(cur)
				cur = w
			else:
				cur = test
		if cur != "":
			lines.append(cur)
		return lines

	func _player_loadout(p: int, r: Rect2, cursor: String, holding: String, from_slot: String) -> void:
		var col := UiKit.player_color(p)
		var lo: Dictionary = LOADOUTS[p]
		draw_colored_polygon(UiKit.chamfer(r, 18.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
		UiKit.poly_line(self, UiKit.chamfer(r, 18.0), Color(col.r, col.g, col.b, 0.9), 3.0)
		# header
		var tag := Rect2(r.position.x + 18, r.position.y + 14, 54, 26)
		draw_colored_polygon(UiKit.chamfer(tag, 7.0), col)
		UiKit.txt(self, UiKit.head(), tag.position + Vector2(0, 19), "P%d" % (p + 1), 15, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x)
		UiKit.txt(self, UiKit.head(), r.position + Vector2(86, 34), "BRAWLER", 18, UiKit.TEXT)
		var sub := "DROP IT ON A SLOT" if holding != "" else "LIFT A MOVE"
		UiKit.txt(self, UiKit.body(), Vector2(r.position.x + 200.0, r.position.y + 32), sub, 15, col if holding != "" else UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 218.0)
		var cw := 118.0
		var gx := r.position.x + 64.0
		var gy := r.position.y + 84.0
		for ci in 4:
			UiKit.txt(self, UiKit.body(), Vector2(gx + ci * (cw + 8.0), gy - 8), COLS[ci], 13, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
		for ri in 3:
			var cy := gy + ri * 66.0
			draw_circle(Vector2(r.position.x + 36, cy + 28), 17.0, UiKit.INK)
			draw_arc(Vector2(r.position.x + 36, cy + 28), 17.0, 0.0, TAU, 24, Color(0.9, 0.9, 1.0, 0.8), 2.5, true)
			UiKit.txt(self, UiKit.head(), Vector2(r.position.x + 18, cy + 35), ROWS[ri], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 36.0)
			for ci in 4:
				var slot: String = SLOTS[ri * 4 + ci]
				var id: String = lo.get(slot, "")
				var cell := Rect2(gx + ci * (cw + 8.0), cy, cw, 56)
				var poly := UiKit.chamfer(cell, 10.0)
				var is_cursor := slot == cursor
				var is_from := slot == from_slot
				if id != "" and not is_from:
					draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.14))
					UiKit.poly_line(self, poly, Color(col.r, col.g, col.b, 0.7), 2.0)
					UiKit.txt(self, UiKit.body(), cell.position + Vector2(0, 26), MoveDB.get_move(id).short.to_upper(), 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
					var tg := String(MoveDB.get_move(id).tags[0]).to_upper() if MoveDB.get_move(id).tags.size() > 0 else "MELEE"
					UiKit.txt(self, UiKit.body(), cell.position + Vector2(0, 45), tg, 12, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
				elif is_from:
					UiKit.poly_line(self, poly, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, 0.5), 2.0)
					UiKit.txt(self, UiKit.body(), cell.position + Vector2(0, 34), "LIFTED", 15, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, cw)
				else:
					UiKit.poly_line(self, poly, Color(1, 1, 1, 0.14), 1.5)
					UiKit.txt(self, UiKit.body(), cell.position + Vector2(0, 34), "EMPTY", 14, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, cw)
				if is_cursor:
					UiKit.poly_line(self, UiKit.chamfer(cell.grow(4.0), 12.0), col, 4.0)
					if holding != "":
						var gh := Rect2(cell.position.x + 6, cell.position.y - 20, cw - 12, 26)
						draw_colored_polygon(UiKit.chamfer(gh, 7.0), UiKit.AMBER)
						UiKit.txt(self, UiKit.head(), gh.position + Vector2(0, 19), MoveDB.get_move(holding).short.to_upper(), 14, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, gh.size.x)
		# detail card for the move under the cursor (or the lifted move)
		var shown: String = holding if holding != "" else String(lo.get(cursor, ""))
		var dy := gy + 3 * 66.0 + 8.0
		var dr := Rect2(r.position.x + 18, dy, r.size.x - 36, r.end.y - dy - 16.0)
		draw_rect(Rect2(dr.position.x, dr.position.y - 4, dr.size.x, 2), Color(1, 1, 1, 0.12))
		if shown != "":
			var m := MoveDB.get_move(shown)
			UiKit.txt(self, UiKit.head(), dr.position + Vector2(0, 30), m.name.to_upper(), 22, UiKit.TEXT)
			var tx := dr.position.x
			for tg in m.tags:
				var w := UiKit.body().get_string_size(String(tg).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
				var chip := Rect2(tx, dr.position.y + 40, w, 20)
				draw_colored_polygon(UiKit.chamfer(chip, 5.0), Color(1, 1, 1, 0.12))
				UiKit.txt(self, UiKit.body(), chip.position + Vector2(0, 15), String(tg).to_upper(), 13, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
				tx += w + 6.0
			var lines := _wrap(UiKit.body(), m.desc, 17, dr.size.x - 150.0)
			for li in mini(lines.size(), 2):
				UiKit.txt(self, UiKit.body(), dr.position + Vector2(0, 82 + li * 20), lines[li], 17, Color(0.85, 0.85, 1.0))
			# upgrade chips on the right
			UiKit.txt(self, UiKit.body(), dr.position + Vector2(dr.size.x - 130, 26), "UPGRADES", 13, UiKit.DIM_TEXT)
			UiKit.panel(self, Rect2(dr.end.x - 130, dr.position.y + 36, 130, 28), 7.0, UiKit.AMBER, 2.0, 0.85)
			UiKit.txt(self, UiKit.body(), Vector2(dr.end.x - 130, dr.position.y + 56), "+25% DAMAGE", 15, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, 130.0)
			UiKit.txt(self, UiKit.body(), dr.position + Vector2(dr.size.x - 130, 88), "kept when moved", 12, UiKit.DIM_TEXT)
			UiKit.txt(self, UiKit.body(), dr.position + Vector2(dr.size.x - 130, 102), "lost if replaced", 12, UiKit.DIM_TEXT)
		else:
			UiKit.txt(self, UiKit.body(), dr.position + Vector2(0, 40), "EMPTY SLOT", 20, Color(1, 1, 1, 0.4))

	func _loadout() -> void:
		_title("LOADOUT", Vector2(40, 74), 48, -0.02)
		UiKit.txt(self, UiKit.body(), Vector2(40, 104), "SWAP MOVES BETWEEN BUTTONS  ·  BOTH PLAYERS AT ONCE", 18, UiKit.PINK)
		_player_loadout(0, Rect2(30, 126, 605, 470), "Y_SIDE", "dash_punch", "X_SIDE")
		_player_loadout(1, Rect2(645, 126, 605, 470), "B_UP", "", "")
		UiKit.txt(self, UiKit.body(), Vector2(30, 640), "A  LIFT / DROP (SWAPS)      B  CANCEL      Y  CLEAR SLOT      START  DONE", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	Pal.terrain_pink = true
	Backdrop.variant = 5
	# world: sky + backdrop + ground, camera fixed (same recipe as the shop screen)
	var sky := Node2D.new()
	sky.z_index = -100
	sky.draw.connect(func():
		Backdrop.paint_synth_sky(sky, -400.0, 2080.0, -300.0, 570.0)
		sky.draw_rect(Rect2(-400, 570, 2080, 400), Pal.BG_GROUND)
		sky.draw_line(Vector2(-400, 570), Vector2(1680, 570), Pal.terrain(), 3.0, true))
	add_child(sky)
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	var bd := Backdrop.new()
	bd.setup(Backdrop.default_theme(), 1280.0, 570.0)
	bd.cam = cam
	add_child(bd)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var figs := Node2D.new()
	layer.add_child(figs)
	for i in 2:
		var f := StickFigure.new()
		f.color = UiKit.player_color(i)
		f.arm_scale = 1.22
		f.leg_scale = 1.2
		f.eyes = true
		f.aim = Vector2(0.9, -0.05)
		f.position = Vector2(930 + i * 130, 668)
		f.scale = Vector2(-1.9, 1.9)
		f.set_target(PoseLib.idle(0.6 + i), true)
		figs.add_child(f)
	var ui := Screen.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	Dbg._hint.visible = false
	var shots := [["start", 0, 0.0, true], ["pause", 1, 0.62, false], ["loadout", 2, 0.72, false]]
	for s in shots:
		ui.mode = s[1]
		dim.color = Color(0.02, 0.01, 0.06, s[2])
		figs.visible = s[3]
		ui.queue_redraw()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/menu_mock_%s.png" % [out, s[0]])
	get_tree().quit()
