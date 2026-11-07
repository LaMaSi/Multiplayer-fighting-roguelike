extends Control
## Reward screen after a cleared level. Both players are on screen; the queue in RunState says
## who picks next (the first picker alternates every level). Cards: new move (then choose which of
## the 12 slots it goes into), +max HP, full heal, or empower one of your equipped moves.
## Left/Right = choose, A = confirm, B = back (slot step).

const SLOT_LABELS := ["-", "UP", "SIDE", "DOWN"]
const ROWS := ["X", "Y", "B"]
const SUFFIX := ["", "_UP", "_SIDE", "_DOWN"]

var _i := 0
var _cards: Array = []
var _sel := 0
var _slot := 0
var _phase := "cards"  ## cards | slot | end
var _last := Vector2i.ZERO
var _t := 0.0
var _flash := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.22
	e.glow_strength = 0.6
	e.glow_hdr_threshold = 1.7
	env.environment = e
	add_child(env)
	Engine.time_scale = 1.0
	if RunState.queue.is_empty():
		_after_queue()
	else:
		_begin_pick()


func _player() -> int:
	return int(RunState.queue[_i]["player"])


func _begin_pick() -> void:
	var item: Dictionary = RunState.queue[_i]
	_cards = RunState.make_cards(int(item["player"]), String(item["kind"]))
	if _cards.is_empty():
		_cards = RunState.make_cards(int(item["player"]), "level")
	_sel = 0
	_phase = "cards"
	_flash = ""


func _next_pick() -> void:
	_i += 1
	if _i >= RunState.queue.size():
		_after_queue()
	else:
		_begin_pick()


func _after_queue() -> void:
	RunState.queue.clear()
	if RunState.finished:
		_phase = "end"
	else:
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _process(delta: float) -> void:
	_t += delta
	if _phase == "end":
		for p in Inp.players:
			if p.pressed(PlayerInput.Btn.JUMP):
				RunState.end_run()
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
				return
		queue_redraw()
		return
	var inp: PlayerInput = Inp.players[_player()]
	var d := inp.digital_dir()
	if d != _last and d != Vector2i.ZERO:
		Sfx.play("ui")
		if _phase == "cards":
			_sel = posmod(_sel + d.x, _cards.size())
		else:
			var col := _slot % 4
			var row := _slot / 4
			col = posmod(col + d.x, 4)
			row = posmod(row + d.y, 3)
			if _cards[_sel].has("row"):
				row = int(_cards[_sel]["row"])  # X / Y / B moves only fit their own row
			_slot = row * 4 + col
	_last = d
	if inp.pressed(PlayerInput.Btn.JUMP):
		_confirm()
	elif inp.pressed(PlayerInput.Btn.B) and _phase == "slot":
		_phase = "cards"
		Sfx.play("ui", 0.8)
	queue_redraw()


func _confirm() -> void:
	var card: Dictionary = _cards[_sel]
	if _phase == "cards":
		if card["kind"] == "move":
			_phase = "slot"
			var row0 := int(card.get("row", 0))
			_slot = row0 * 4
			var loadout: Dictionary = RunState.loadouts[_player()]
			for s in 12:
				if card.has("row") and s / 4 != row0:
					continue
				if not loadout.has(_slot_name(s)):
					_slot = s
					break
			Sfx.play("ui")
		else:
			RunState.apply_card(_player(), card)
			Sfx.play("buff")
			_next_pick()
	else:
		RunState.apply_card(_player(), card, _slot_name(_slot))
		Sfx.play("pickup")
		_next_pick()


func _slot_name(s: int) -> String:
	return ROWS[s / 4] + SUFFIX[s % 4]


# ------------------------------------------------------------------ drawing

static func _c(c: Color) -> Color:
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), c.a)


func _txt(pos: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, text, align, width, size, 5, Color(0, 0, 0, 0.9))
	draw_string(f, pos, text, align, width, size, col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.09))
	for i in 20:
		draw_rect(Rect2(0, 720.0 * i / 20.0, 1280, 37), Color(0.3, 0.08, 0.25, 0.02 * i))
	if _phase == "end":
		_draw_end()
		return
	var pl := _player()
	var pc := _c(Fighter.PLAYER_COLORS[pl])
	_txt(Vector2(0, 70), "REWARD", 46, Color(1, 1, 1), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 112), "PLAYER %d CHOOSES" % (pl + 1), 28, pc, 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 140), "pick %d of %d" % [_i + 1, RunState.queue.size()], 16, Color(1, 1, 1, 0.55), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_panel(0, 14.0, 170.0)
	_draw_panel(1, 1280.0 - 14.0 - 250.0, 170.0)
	if _phase == "cards":
		for i in _cards.size():
			_draw_card(i)
	else:
		_draw_slot_picker(pc)


func _draw_card(i: int) -> void:
	var card: Dictionary = _cards[i]
	var selected := i == _sel
	var r := Rect2(300 + i * 230, 215 - (14 if selected else 0), 210, 330)
	var accent := _c(Fighter.PLAYER_COLORS[_player()]) if card["kind"] == "move" else (Color(1.0, 0.7, 0.3) if card["kind"] == "up" else Color(1.0, 0.9, 0.95))
	draw_rect(r, Color(0.07, 0.04, 0.14))
	draw_rect(r, Color(accent.r, accent.g, accent.b, 1.0 if selected else 0.35), false, 4.0 if selected else 2.0)
	_txt(r.position + Vector2(0, 34), String(card["tag"]), 15, accent, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var f := ThemeDB.fallback_font
	draw_multiline_string(f, r.position + Vector2(10, 90), String(card["title"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 20.0, 26, 3, Color(1, 1, 1))
	draw_multiline_string(f, r.position + Vector2(14, 190), String(card["desc"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 28.0, 17, 5, Color(0.85, 0.85, 0.95))
	if String(card["extra"]) != "":
		_txt(r.position + Vector2(0, 310), "[%s]" % card["extra"], 13, Color(1, 1, 1, 0.5), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if card["kind"] == "up":
		var cur := float((RunState.upgrades[_player()].get(card["id"], {}) as Dictionary).get(card["stat"], 1.0))
		if cur > 1.0:
			_txt(r.position + Vector2(0, 290), "already x%.2f" % cur, 13, Color(1, 0.8, 0.4), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_slot_picker(pc: Color) -> void:
	var card: Dictionary = _cards[_sel]
	_txt(Vector2(0, 205), "Place  %s  in a slot" % String(card["title"]).to_upper(), 26, Color(1, 1, 1), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 232), "Picking an occupied slot replaces that move", 16, Color(1, 1, 1, 0.55), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	var loadout: Dictionary = RunState.loadouts[_player()]
	for ci in 4:
		_txt(Vector2(380 + ci * 140, 272), SLOT_LABELS[ci], 15, Color(1, 1, 1, 0.6), 130.0, HORIZONTAL_ALIGNMENT_CENTER)
	for s in 12:
		var col := s % 4
		var row := s / 4
		var r := Rect2(380 + col * 140, 285 + row * 80, 130, 68)
		var id: String = loadout.get(_slot_name(s), "")
		var sel := s == _slot
		draw_rect(r, Color(0.07, 0.04, 0.14))
		draw_rect(r, pc if sel else Color(1, 1, 1, 0.2), false, 4.0 if sel else 1.5)
		_txt(r.position + Vector2(8, 20), ROWS[row], 15, pc)
		if id == "":
			_txt(r.position + Vector2(0, 46), "(empty)", 16, Color(1, 1, 1, 0.35), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_txt(r.position + Vector2(0, 46), MoveDB.get_move(id).name, 15, Color(1, 0.8, 0.5) if sel else Color(1, 1, 1), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_panel(p: int, x: float, y: float) -> void:
	var w := 250.0
	var col := _c(Fighter.PLAYER_COLORS[p])
	var active := p == _player()
	draw_rect(Rect2(x, y, w, 250), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(x, y, w, 250), Color(col.r, col.g, col.b, 1.0 if active else 0.35), false, 3.0 if active else 1.5)
	_txt(Vector2(x + 10, y + 28), "PLAYER %d" % (p + 1), 20, col)
	var frac := clampf(float(RunState.hp[p]) / float(RunState.max_hp[p]), 0.0, 1.0)
	draw_rect(Rect2(x + 10, y + 40, w - 20, 14), Color(0.12, 0.05, 0.08))
	draw_rect(Rect2(x + 10, y + 40, (w - 20) * frac, 14), Color(1.0, 0.25 + 0.7 * frac, 0.25 + 0.7 * frac))
	_txt(Vector2(x + 14, y + 52), "%d / %d" % [int(RunState.hp[p]), int(RunState.max_hp[p])], 12, Color(1, 1, 1), 120.0)
	var loadout: Dictionary = RunState.loadouts[p]
	for s in 12:
		var cx := s % 4
		var cy := s / 4
		var r := Rect2(x + 10 + cx * 58, y + 74 + cy * 50, 56, 44)
		var id: String = loadout.get(_slot_name(s), "")
		draw_rect(r, Color(1, 1, 1, 0.07))
		if id != "":
			_txt(r.position + Vector2(0, 17), MoveDB.get_move(id).short, 11, Color(1, 1, 1), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			if RunState.upgrades[p].has(id.rstrip("0123456789")):
				_txt(r.position + Vector2(0, 36), "+ + +", 11, Color(1, 0.75, 0.3), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			draw_rect(r, Color(1, 1, 1, 0.1), false, 1.0)
		if cy == 0:
			_txt(r.position + Vector2(0, -3), SLOT_LABELS[cx], 9, Color(1, 1, 1, 0.45), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_end() -> void:
	_txt(Vector2(0, 230), "STREETS CLEARED!", 80, Color(1.0, 0.85, 0.4), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 290), "RUN COMPLETE", 40, Color(1, 1, 1), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 360), "Levels cleared: %d     Best combo: %d" % [RunState.levels_cleared, RunState.best_combo], 26, Color(1, 1, 1, 0.9), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 410), "Wasteland and Ruins are coming in later milestones.", 18, Color(1, 1, 1, 0.55), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 500), "A: main menu", 24, Color(1, 1, 1, 0.8 + 0.2 * sin(_t * 5.0)), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
