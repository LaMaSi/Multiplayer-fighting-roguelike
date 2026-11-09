class_name RewardScreen
extends Control
## Reward screen after a cleared level. ONE shared pool of cards: both players choose from the same picks at the same
## time, each with their own cursor (the same card can be taken by both; weapon moves only by the matching class).
## A move card immediately asks that player which button to put it on. A = confirm, B = cancel the button step.

const CARD_W := 190.0
const CARD_H := 322.0
const CARD_Y := 118.0

var _pool: Array = []
var _cursor: Array[int] = [0, 0]
var _phase: Array[String] = ["choose", "choose"]  ## per player: choose | slot | done
var _picked: Array = ["", ""]  ## title of what each player took
var _pickers: Array[SlotPicker] = [SlotPicker.new(), SlotPicker.new()]
var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _t := 0.0
var _flash := ["", ""]
var _all_done := false
var _end := false  ## the run is over (boss cleared): show the end card
var overlay := false  ## inside a door room: no scene change, closes itself when both players are done
signal finished


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RunState.solo:
		_phase[1] = "done"  # no P2 in solo playtests
	if overlay:
		_pool = _build_pool()
		return
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
	RunState.bonus_picks.clear()
	if RunState.queue.is_empty():
		_leave()
	else:
		_pool = _build_pool()
		RunState.queue.clear()


func _leave() -> void:
	if overlay:
		finished.emit()
		queue_free()
		return
	RunState.queue.clear()
	if RunState.finished:
		_end = true
	else:
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")


# ------------------------------------------------------------------ the pool

func _build_pool() -> Array:
	var pool: Array = []
	# two shared moves (off-hand and adaptive, same for every class)
	for c in RunState.make_cards(0, "move"):
		if pool.size() < 2:
			pool.append(c)
	# a new weapon move for each class in play (only that class can take it)
	for p in (1 if RunState.solo else 2):
		var cid: String = RunState.classes[p]
		for c in RunState.make_cards(p, "level"):
			if String(c["kind"]) == "move" and not _has_move(pool, String(c["id"])):
				c["class"] = cid
				pool.append(c)
				break
	# team-useful level-ups both players can take
	for c in RunState.make_cards(0, "level"):
		if String(c["kind"]) != "move" and String(c["kind"]) != "up" and pool.size() < 6:
			pool.append(c)
	return pool


func _has_move(pool: Array, id: String) -> bool:
	for c in pool:
		if c.has("id") and String(c["id"]) == id:
			return true
	return false


## Why player p cannot take card c, or "" when they can.
func _blocked(p: int, c: Dictionary) -> String:
	if c.has("class") and String(c["class"]) != String(RunState.classes[p]):
		return "OTHER CLASS"
	if String(c["kind"]) == "move" and (String(c["id"]) in (RunState.loadouts[p] as Dictionary).values()):
		return "OWNED"
	if String(c["kind"]) == "djump" and bool((RunState.perks[p] as Dictionary).get("double_jump", false)):
		return "OWNED"
	return ""


# ------------------------------------------------------------------ input (physics step: button edges are per tick)

func _physics_process(delta: float) -> void:
	_t += delta
	if _end:
		for p in Inp.players:
			if p.pressed(PlayerInput.Btn.JUMP):
				RunState.end_run()
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
				return
		return
	if _pool.is_empty():
		return
	for p in 2:
		var inp: PlayerInput = Inp.players[p]
		if _phase[p] == "slot":
			_pickers[p].update(inp)
			continue
		if _phase[p] == "done":
			continue
		var d := inp.digital_dir()
		if d != _last[p] and d.x != 0:
			_cursor[p] = posmod(_cursor[p] + d.x, _pool.size())
			Sfx.play("ui")
		_last[p] = d
		if inp.pressed(PlayerInput.Btn.JUMP):
			_confirm(p)
		elif inp.pressed(PlayerInput.Btn.Y):
			_reroll(p)
	if not _all_done and _phase[0] == "done" and _phase[1] == "done":
		_all_done = true
		get_tree().create_timer(0.7).timeout.connect(_leave)


## Spend a reroll token to reshuffle the offered picks. Only before anyone has picked.
func _reroll(p: int) -> void:
	if RunState.reroll_tokens <= 0:
		_flash[p] = "NO REROLLS LEFT"
		Sfx.play("ui", 0.7)
		return
	if _phase[0] != "choose" or (_phase[1] != "choose" and not RunState.solo):
		_flash[p] = "SOMEONE ALREADY PICKED"
		Sfx.play("ui", 0.7)
		return
	RunState.reroll_tokens -= 1
	_pool = _build_pool()
	_cursor = [0, 0]
	_flash = ["", ""]
	Sfx.play("relay")


func _confirm(p: int) -> void:
	var card: Dictionary = _pool[_cursor[p]]
	var why := _blocked(p, card)
	if why != "":
		Sfx.play("ui", 0.7)
		_flash[p] = why
		return
	if String(card["kind"]) == "move":
		_phase[p] = "slot"
		_pickers[p].start(p, String(card["id"]), func(slot: String) -> void:
			if slot == "":
				_phase[p] = "choose"
				return
			RunState.apply_card(p, card, slot)
			Sfx.play("pickup")
			_picked[p] = String(card["title"])
			_phase[p] = "done")
		Sfx.play("ui")
	else:
		RunState.apply_card(p, card)
		Sfx.play("buff")
		_picked[p] = String(card["title"])
		_phase[p] = "done"


func _process(_delta: float) -> void:
	queue_redraw()


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
	if _end:
		_draw_end()
		return
	_txt(Vector2(0, 50), "REWARD", 40, Color(1, 1, 1), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 80), "Both players choose from the same picks, at the same time", 16, Color(1, 1, 1, 0.6), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 104), "REROLLS: %d    (Y: reroll the picks)" % RunState.reroll_tokens, 15, Color(1.8, 1.6, 2.2) if RunState.reroll_tokens > 0 else Color(1, 1, 1, 0.4), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	for p in 2:
		var pc := _c(Fighter.PLAYER_COLORS[p])
		var status := "choosing..."
		if _phase[p] == "slot":
			status = "choosing a button..."
		elif _phase[p] == "done":
			status = "took  %s" % String(_picked[p]).to_upper()
		_txt(Vector2(30 if p == 0 else 650, 104), "P%d  %s" % [p + 1, status], 17, pc, 600.0, HORIZONTAL_ALIGNMENT_LEFT if p == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
	var total := float(_pool.size()) * CARD_W + float(_pool.size() - 1) * 10.0
	var x0 := (1280.0 - total) * 0.5
	for i in _pool.size():
		_draw_card(i, Rect2(x0 + i * (CARD_W + 10.0), CARD_Y + 14.0, CARD_W, CARD_H))
	# the button pickers, one per player, under the cards
	for p in 2:
		var pc2 := _c(Fighter.PLAYER_COLORS[p])
		var pr := Rect2(30.0 + p * 630.0, 468.0, 590.0, 236.0)
		if _phase[p] == "slot":
			_pickers[p].paint(self, pr, pc2)
		elif _phase[p] == "done":
			draw_rect(pr, Color(0.05, 0.03, 0.12, 0.7))
			draw_rect(pr, Color(pc2.r, pc2.g, pc2.b, 0.5), false, 2.0)
			_txt(pr.position + Vector2(0, 126), "READY", 34, pc2, pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			draw_rect(pr, Color(0.05, 0.03, 0.12, 0.45))
			draw_rect(pr, Color(pc2.r, pc2.g, pc2.b, 0.3), false, 2.0)
			_txt(pr.position + Vector2(0, 112), "LEFT / RIGHT: choose     A: take     Y: reroll", 18, Color(1, 1, 1, 0.75), pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			if String(_flash[p]) != "":
				_txt(pr.position + Vector2(0, 150), String(_flash[p]), 20, Color(1.0, 0.5, 0.4), pr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_card(i: int, r: Rect2) -> void:
	var card: Dictionary = _pool[i]
	var accent := Color(1.0, 0.9, 0.95)
	if String(card["kind"]) == "move":
		accent = Color(0.7, 0.9, 1.0)
	elif String(card["kind"]) == "up":
		accent = Color(1.0, 0.7, 0.3)
	draw_rect(r, Color(0.07, 0.04, 0.14))
	draw_rect(r, Color(accent.r, accent.g, accent.b, 0.3), false, 2.0)
	var f := ThemeDB.fallback_font
	var tag := String(card["tag"])
	if card.has("class"):
		tag = "%s MOVE" % String(card["class"]).to_upper()
	_txt(r.position + Vector2(0, 26), tag, 12, accent, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	draw_multiline_string(f, r.position + Vector2(8, 62), String(card["title"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 22, 2, Color(1, 1, 1))
	var desc_y := 112.0
	if card.has("id"):
		var pl := 0
		if card.has("class"):
			pl = 0 if String(RunState.classes[0]) == String(card["class"]) else 1
		MovePreview.draw(self, String(card["id"]), String(RunState.classes[pl]), pl, Rect2(r.position.x + 12.0, r.position.y + 96.0, r.size.x - 24.0, 100.0))
		UiKit.charge_chip(self, Rect2(r.position.x + 16.0, r.position.y + 98.0, minf(r.size.x - 32.0, 148.0), 32.0), MoveDB.get_move(String(card["id"])))
		desc_y = 222.0
	draw_multiline_string(f, r.position + Vector2(10, desc_y), String(card["desc"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 20.0, 14, 4, Color(0.85, 0.85, 0.95))
	if String(card["extra"]) != "":
		_txt(r.position + Vector2(0, r.size.y - 10.0), "[%s]" % card["extra"], 11, Color(1, 1, 1, 0.5), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# cursors and who can take it
	for p in 2:
		var pc := _c(Fighter.PLAYER_COLORS[p])
		var why := _blocked(p, card)
		if _cursor[p] == i and _phase[p] != "done":
			draw_rect(r.grow(2.0 + 4.0 * p), pc, false, 4.0)
			draw_rect(Rect2(r.position.x + 6.0 + p * 36.0, r.position.y - 20.0, 32.0, 18.0), pc)
			_txt(Vector2(r.position.x + 6.0 + p * 36.0, r.position.y - 6.0), "P%d" % (p + 1), 13, Color(0.05, 0.03, 0.1), 32.0, HORIZONTAL_ALIGNMENT_CENTER)
		if why != "":
			_txt(r.position + Vector2(0, 202.0 + p * 0.0), "P%d: %s" % [p + 1, why] if _cursor[p] == i else "", 12, Color(1.0, 0.5, 0.4), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_end() -> void:
	_txt(Vector2(0, 230), "STREETS CLEARED!", 80, Color(1.0, 0.85, 0.4), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 290), "RUN COMPLETE", 40, Color(1, 1, 1), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 360), "Levels cleared: %d     Best combo: %d" % [RunState.levels_cleared, RunState.best_combo], 26, Color(1, 1, 1, 0.9), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 410), "Wasteland and Ruins are coming in later milestones.", 18, Color(1, 1, 1, 0.55), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 500), "A: main menu", 24, Color(1, 1, 1, 0.8 + 0.2 * sin(_t * 5.0)), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
