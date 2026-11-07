class_name LevelCompleteView
## Level complete screen (drawn by the HUD canvas over a dimmed level with two cheering figures):
## team rank plate, six stat rows each with its own rank tile, team score and, during a run, the
## coins earned (shared wallet) and the heart-link heal. Data comes from LevelStats.compute().


static func _rank_color(r: String) -> Color:
	return Color(1.0, 0.72, 0.25) if (r == "S" or r == "A") else Color(0.8, 0.8, 1.0)


static func paint(c: Control, s: Dictionary, t: float) -> void:
	if s.is_empty():
		return
	var head := UiKit.head()
	var body := UiKit.body()
	var rank: String = s["rank"]
	var glow := Color(2.4, 1.7, 0.5) if (rank == "S" or rank == "A") else Color(1.6, 1.6, 2.0)
	# title
	c.draw_set_transform_matrix(UiKit.italic(Vector2(640, 66), -0.02))
	for k in 3:
		UiKit.txt(c, head, Vector2(-400, 0), "LEVEL COMPLETE", 46, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, head, Vector2(-400, 0), "LEVEL COMPLETE", 46, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 4, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sub := "STREETS"
	if RunState.active:
		sub = "STREETS  ·  CLEARED %d" % (RunState.levels_cleared + 1)
	UiKit.txt(c, body, Vector2(240, 96), sub, 20, UiKit.PINK, HORIZONTAL_ALIGNMENT_CENTER, 800.0)
	# rank plate
	UiKit.txt(c, head, Vector2(180, 150), "TEAM RANK", 18, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	var pop := 1.0 + 0.35 * exp(-7.0 * t) * cos(22.0 * t)
	c.draw_set_transform_matrix(UiKit.italic(Vector2(330, 300), -0.07, pop, -0.22))
	var plate := PackedVector2Array([Vector2(-130, 100), Vector2(-96, -110), Vector2(130, -110), Vector2(96, 100)])
	UiKit.glow_poly(c, plate, glow, 0.5)
	c.draw_colored_polygon(plate, UiKit.INK)
	UiKit.poly_line(c, plate, Color(1.0, 0.8, 0.3) if glow.r > 2.0 else Color(0.85, 0.85, 1.0), 4.0)
	for k in 3:
		UiKit.txt(c, head, Vector2(-150, 70), rank, 210, Color(glow.r, glow.g, glow.b, 0.2), HORIZONTAL_ALIGNMENT_CENTER, 300.0, 10 + k * 10, Color(glow.r, glow.g, glow.b, 0.1))
	UiKit.txt(c, head, Vector2(-150, 70), rank, 210, Color(2.4, 2.1, 1.4) if glow.r > 2.0 else UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 6, Color(0.1, 0.04, 0.0))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	# rank effect chip (real: the rank scales the coins you earn)
	var mult: float = s["rank_mult"]
	var chip_text := "RANK %s" % rank
	if RunState.active and absf(mult - 1.0) > 0.01:
		chip_text += "  ·  %s%d%% COINS" % ["+" if mult > 1.0 else "-", int(round(absf(mult - 1.0) * 100.0))]
	UiKit.panel(c, Rect2(180, 428, 300, 34), 8.0, UiKit.AMBER, 3.0, 0.85)
	UiKit.txt(c, body, Vector2(180, 453), chip_text, 18, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, 300.0)
	# stat rows
	var y := 168.0
	var rows: Array = s["rows"]
	for i in rows.size():
		var r: Dictionary = rows[i]
		# rows slide in one after another
		var a := clampf((t - 0.15 * i) * 6.0, 0.0, 1.0)
		if a <= 0.0:
			y += 50.0
			continue
		var ox := (1.0 - a) * 40.0
		c.draw_rect(Rect2(660 + ox, y + 36, 560, 2), Color(1, 1, 1, 0.12 * a))
		UiKit.txt(c, body, Vector2(660 + ox, y + 28), String(r["label"]), 26, Color(0.85, 0.85, 1.0, a))
		UiKit.txt(c, head, Vector2(940 + ox, y + 28), String(r["value"]), 24, Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		var tile := Rect2(1172 + ox, y + 2, 48, 32)
		var rk: String = r["rank"]
		var big := rk == "S"
		c.draw_colored_polygon(UiKit.chamfer(tile, 8.0), Color(1.0, 0.72, 0.25, 0.9 * a) if big else Color(0.1, 0.07, 0.18, 0.9 * a))
		if not big:
			UiKit.poly_line(c, UiKit.chamfer(tile, 8.0), Color(_rank_color(rk).r, _rank_color(rk).g, _rank_color(rk).b, 0.7 * a), 2.0)
		UiKit.txt(c, head, Vector2(1172 + ox, y + 27), rk, 20, Color(0.1, 0.04, 0.0, a) if big else Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a), HORIZONTAL_ALIGNMENT_CENTER, 48.0)
		y += 50.0
	# score (counts up)
	var shown := int(float(s["score"]) * clampf((t - 0.9) / 0.8, 0.0, 1.0))
	UiKit.txt(c, body, Vector2(660, 520), "TEAM SCORE", 22, UiKit.DIM_TEXT)
	UiKit.txt(c, head, Vector2(840, 530), _commas(shown), 54, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 380.0, 5, Color(0.05, 0.0, 0.1))
	# rewards (only inside a run)
	if RunState.active and t > 1.4:
		var by := 566.0
		UiKit.panel(c, Rect2(660, by, 270, 56), 10.0, Color(0.8, 0.8, 1.0, 0.55), 3.0, 0.8)
		UiKit.coin(c, Vector2(690, by + 28), 14.0)
		UiKit.txt(c, head, Vector2(714, by + 26), "+%d" % int(s["coins"]), 22, UiKit.AMBER)
		UiKit.txt(c, body, Vector2(714, by + 47), "COINS  (WALLET %d)" % RunState.coins, 15, UiKit.DIM_TEXT)
		UiKit.panel(c, Rect2(950, by, 270, 56), 10.0, Color(0.8, 0.8, 1.0, 0.55), 3.0, 0.8)
		var heal := int(round(float(RunState.max_hp[0]) * 0.25 + float(s["heal_bonus"])))
		UiKit.txt(c, head, Vector2(974, by + 26), "+%d HP" % heal, 22, UiKit.P1)
		UiKit.txt(c, body, Vector2(974, by + 47), "HEART LINK REFILL", 15, UiKit.DIM_TEXT)
	# continue prompt
	var pa := 0.55 + 0.45 * sin(t * 5.0 + 1.2)
	UiKit.txt(c, head, Vector2(660, 704), "A  CONTINUE", 20, Color(1, 1, 1, pa), HORIZONTAL_ALIGNMENT_RIGHT, 560.0, 4, Color(0, 0, 0, 0.6))


static func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
