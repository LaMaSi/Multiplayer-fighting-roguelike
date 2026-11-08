class_name RunSetup
extends Control
## The screen after NEW RUN (or TRAINING ROOM): both players choose their weapon class, or RANDOM.
## Up/Down moves, A locks in, B unlocks (or goes back to the main menu when nobody is locked).
## When both are locked in:
##   run mode:      the run is created (moves are rolled), then a reveal shows which moves each player got
##                  (B, UP+B, SIDE+B, X and Y; nothing else at the start) and both press A to begin.
##   training mode: straight into the training room with the chosen classes.

static var mode := "run"  ## "run" or "training", set by the main menu before opening this scene

const OPTIONS := ["brawler", "sword", "hammer", "magic", "random"]
const REVEAL_SLOTS := ["B", "B_UP", "B_SIDE", "X", "Y"]
const SLOT_LABEL := {"B": "B", "B_UP": "UP + B", "B_SIDE": "SIDE + B", "X": "X", "Y": "Y"}
const ROLL_START := 0.35
const ROLL_STEP := 0.4
const ROLL_TIME := 0.45
const REVEAL_END := ROLL_START + 4 * ROLL_STEP + ROLL_TIME + 0.25

class View extends Control:
	var screen: RunSetup
	var back := false  ## the back view draws the panel backings, below the preview figures

	func _draw() -> void:
		if screen == null:
			return
		if back:
			screen.paint_back(self)
		else:
			screen.paint(self)


var phase := "pick"  ## pick | reveal
var cursor: Array[int] = [0, 0]
var locked: Array[bool] = [false, false]
var choice: Array[String] = ["", ""]
var was_random: Array[bool] = [false, false]
var ready_flags: Array[bool] = [false, false]
var reveal_t := 0.0
var rev_cursor: Array[int] = [0, 0]  ## which revealed move each player has selected (Y rerolls just that one)
var _reroll_at: Array = [[-1.0, -1.0, -1.0, -1.0, -1.0], [-1.0, -1.0, -1.0, -1.0, -1.0]]  ## reveal_t when a single slot was rerolled

var _t := 0.0
var _view: View
var _back: View
var _figs: Array[StickFigure] = []
var _fig_cls: Array[String] = ["?", "?"]
var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _flash: Array[String] = ["", ""]
var _flash_t: Array[float] = [0.0, 0.0]
var _settled: Array = [[false, false, false, false, false], [false, false, false, false, false]]
var _leaving := false
var scene_changer: Callable  ## tests set this to observe scene changes instead of leaving the screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Engine.time_scale = 1.0
	Dbg._hint.visible = false
	add_child(ScreenBackdrop.new())
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_back = View.new()
	_back.screen = self
	_back.back = true
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	var figs := Node2D.new()
	add_child(figs)
	for i in 2:
		var f := StickFigure.new()
		f.color = UiKit.player_color(i)
		f.arm_scale = 1.22
		f.leg_scale = 1.2
		f.eyes = true
		f.aim = Vector2(0.9, -0.05)
		f.position = Vector2(30 + i * 615 + 95, 530)
		f.scale = Vector2(2.0, 2.0)
		figs.add_child(f)
		_figs.append(f)
	_view = View.new()
	_view.screen = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	for i in 2:
		var idx := OPTIONS.find(RunState.classes[i])
		cursor[i] = maxi(idx, 0)
	_update_figures(true)
	if RunState.solo:
		# solo playtest: P2 is auto locked in with its remembered class (never "random")
		locked[1] = true
		choice[1] = String(RunState.classes[1]) if RunState.classes[1] in ["brawler", "sword", "hammer", "magic"] else "brawler"


# ------------------------------------------------------------------ logic

func _available(cid: String) -> bool:
	return cid != "magic" or RunState.magic_unlocked


func _resolve_random() -> String:
	var pool: Array[String] = ["brawler", "sword", "hammer"]
	if RunState.magic_unlocked:
		pool.append("magic")
	return pool[randi() % pool.size()]


func lock_in(p: int) -> void:
	if locked[p]:
		return
	var opt: String = OPTIONS[cursor[p]]
	if not _available(opt):
		_say(p, "LOCKED")
		Sfx.play("ui", 0.6)
		return
	was_random[p] = opt == "random"
	choice[p] = _resolve_random() if opt == "random" else opt
	locked[p] = true
	Sfx.play("pickup")
	if locked[0] and locked[1]:
		_begin()


func unlock(p: int) -> void:
	if locked[p]:
		locked[p] = false
		Sfx.play("ui", 0.8)


func _say(p: int, t: String) -> void:
	_flash[p] = t
	_flash_t[p] = 1.2


func _begin() -> void:
	RunState.classes = [choice[0], choice[1]]
	if mode == "training":
		RunState.end_run()
		_goto("res://scenes/training.tscn")
		return
	RunState.start_run()  # rolls each player's moves for their class (no reroll)
	phase = "reveal"
	reveal_t = 0.0
	ready_flags = [false, false]
	for f in _figs:
		f.visible = false


## Back from the moves reveal to weapon selection. Player p unlocks (the other player's choice stays); the run is dropped
## and gets rolled again when everybody locks in.
func _back_to_pick(p: int) -> void:
	RunState.end_run()
	phase = "pick"
	locked[p] = false
	ready_flags = [false, false]
	_settled = [[false, false, false, false, false], [false, false, false, false, false]]
	_reroll_at = [[-1.0, -1.0, -1.0, -1.0, -1.0], [-1.0, -1.0, -1.0, -1.0, -1.0]]
	rev_cursor = [0, 0]
	Sfx.play("ui", 0.8)


func _go_map() -> void:
	_goto("res://scenes/run_map.tscn")


func _goto(path: String) -> void:
	_leaving = true
	if scene_changer.is_valid():
		scene_changer.call(path)
	else:
		get_tree().change_scene_to_file(path)


# ------------------------------------------------------------------ input (physics step: right after Inp polls)

func _physics_process(delta: float) -> void:
	if _leaving:
		return
	for p in 2:
		_flash_t[p] = maxf(0.0, _flash_t[p] - delta)
	if phase == "reveal":
		reveal_t += delta
	for p in (1 if RunState.solo else 2):
		var inp: PlayerInput = Inp.players[p]
		var d := inp.digital_dir()
		var edge := d != _last[p] and d != Vector2i.ZERO
		_last[p] = d
		if phase == "reveal" and edge and d.y != 0 and reveal_t >= REVEAL_END and not ready_flags[p]:
			rev_cursor[p] = posmod(rev_cursor[p] + d.y, REVEAL_SLOTS.size())
			Sfx.play("ui")
		if phase == "pick":
			if edge and not locked[p]:
				var step := d.y if d.y != 0 else d.x
				cursor[p] = posmod(cursor[p] + step, OPTIONS.size())
				Sfx.play("ui")
			if inp.pressed(PlayerInput.Btn.JUMP):
				lock_in(p)
			elif inp.pressed(PlayerInput.Btn.B):
				if locked[p]:
					unlock(p)
				elif not locked[0] and (RunState.solo or not locked[1]):
					_goto("res://scenes/main_menu.tscn")
					return
		else:
			if inp.pressed(PlayerInput.Btn.JUMP):
				if reveal_t < REVEAL_END:
					reveal_t = REVEAL_END  # skip the roll
				else:
					ready_flags[p] = true
					if RunState.solo:
						ready_flags[1] = true
					Sfx.play("ui")
					if ready_flags[0] and ready_flags[1]:
						_go_map()
						return
			elif inp.pressed(PlayerInput.Btn.B):
				if ready_flags[p]:
					ready_flags[p] = false
					if RunState.solo:
						ready_flags = [false, false]
				else:
					_back_to_pick(p)  # B on the moves reveal: back to weapon selection
					return
			elif inp.pressed(PlayerInput.Btn.Y) and reveal_t >= REVEAL_END and not ready_flags[p]:
				if RunState.setup_rerolls[p] <= 0:
					_say(p, "NO REROLLS LEFT")
					Sfx.play("ui", 0.7)
				elif RunState.reroll_move(p, REVEAL_SLOTS[rev_cursor[p]]):
					Sfx.play("relay")
					_reroll_at[p][rev_cursor[p]] = reveal_t  # replay the roll for this move only
					_settled[p][rev_cursor[p]] = false
					ready_flags = [false, false]
				else:
					_say(p, "NOTHING ELSE FITS")
					Sfx.play("ui", 0.7)


# ------------------------------------------------------------------ figures

func _update_figures(snap := false) -> void:
	for i in 2:
		var opt: String = OPTIONS[cursor[i]]
		var f := _figs[i]
		if phase != "pick" or opt == "random" or (i == 1 and RunState.solo):
			f.visible = false
			continue
		f.visible = true
		if opt != _fig_cls[i]:
			_fig_cls[i] = opt
			f.weapon = String(ClassData.get_class_data(opt)["weapon"])
		f.set_target(ClassData.base_pose(opt, _t + i), snap)


func _process(delta: float) -> void:
	_t += delta
	_update_figures()
	_back.queue_redraw()
	_view.queue_redraw()


# ------------------------------------------------------------------ drawing

func _title(c: Control, text: String) -> void:
	c.draw_set_transform_matrix(UiKit.italic(Vector2(40, 74), -0.02))
	for k in 3:
		UiKit.txt(c, UiKit.head(), Vector2.ZERO, text, 44, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, UiKit.head(), Vector2.ZERO, text, 44, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func paint_back(c: Control) -> void:
	for p in (1 if RunState.solo else 2):
		var r := Rect2(30 + p * 615, 120, 605, 540)
		var col := UiKit.player_color(p)
		c.draw_colored_polygon(UiKit.chamfer(r, 18.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.84))
		UiKit.poly_line(c, UiKit.chamfer(r, 18.0), Color(col.r, col.g, col.b, 0.9), 3.0)


func paint(c: Control) -> void:
	if phase == "pick":
		_title(c, "CHOOSE YOUR WEAPON")
		for p in (1 if RunState.solo else 2):
			_paint_pick(c, p, Rect2(30 + p * 615, 120, 605, 540))
	else:
		_title(c, "YOUR MOVES")
		for p in (1 if RunState.solo else 2):
			_paint_reveal(c, p, Rect2(30 + p * 615, 120, 605, 540))
		_paint_prompt(c)


func _class_label(cid: String) -> String:
	return "RANDOM" if cid == "random" else String(ClassData.get_class_data(cid)["name"]).to_upper()


func _panel(c: Control, p: int, r: Rect2, status: String) -> void:
	var col := UiKit.player_color(p)
	var tag := Rect2(r.position.x + 18, r.position.y + 14, 54, 26)
	c.draw_colored_polygon(UiKit.chamfer(tag, 7.0), col)
	UiKit.txt(c, UiKit.head(), tag.position + Vector2(0, 19), "P%d" % (p + 1), 15, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x)
	if status != "":
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 90, r.position.y + 34), status, 16, col)


func _paint_pick(c: Control, p: int, r: Rect2) -> void:
	var col := UiKit.player_color(p)
	var opt: String = OPTIONS[cursor[p]]
	_panel(c, p, r, "LOCKED IN" if locked[p] else "CHOOSING")
	# class list
	var lx := r.position.x + 290.0
	for i in OPTIONS.size():
		var o: String = OPTIONS[i]
		var br := Rect2(lx, r.position.y + 70 + i * 54.0, 295, 46)
		var sel := i == cursor[p]
		var avail := _available(o)
		var poly := UiKit.chamfer(br, 11.0)
		var picked := locked[p] and sel
		c.draw_colored_polygon(poly, Color(col.r * 0.28, col.g * 0.28, col.b * 0.28, 0.95) if picked else (Color(0.12, 0.05, 0.2, 0.92) if sel else Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.8)))
		UiKit.poly_line(c, poly, col if sel else Color(0.8, 0.8, 1.0, 0.4 if avail else 0.2), 4.0 if sel else 3.0)
		var label_col := UiKit.TEXT if (sel or avail) else Color(0.7, 0.7, 0.85, 0.4)
		UiKit.txt(c, UiKit.head(), br.position + Vector2(50, 30), _class_label(o), 19 if sel else 17, label_col)
		var ic := br.position + Vector2(26, 23)
		if not avail:
			c.draw_rect(Rect2(ic.x - 7, ic.y - 2, 14, 11), Color(0.8, 0.8, 1.0, 0.45))
			c.draw_arc(ic + Vector2(0, -2), 5.0, PI, TAU, 10, Color(0.8, 0.8, 1.0, 0.45), 2.5, true)
		elif o == "random":
			UiKit.txt(c, UiKit.head(), ic + Vector2(-12, 9), "?", 26, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
		else:
			c.draw_arc(ic, 9.0, 0.0, TAU, 16, col if sel else Color(col.r, col.g, col.b, 0.5), 3.0, true)
	if _flash_t[p] > 0.0:
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 90, r.position.y + 34), _flash[p], 16, Color(1.0, 0.45, 0.45), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	# details of the hovered option
	var dy := r.position.y + 70 + OPTIONS.size() * 54.0 + 8.0
	c.draw_rect(Rect2(lx, dy - 4, 295, 2), Color(1, 1, 1, 0.12))
	if opt == "random":
		UiKit.txt(c, UiKit.head(), Vector2(lx, dy + 28), "RANDOM", 20, UiKit.TEXT)
		UiKit.txt(c, UiKit.body(), Vector2(lx, dy + 54), "A surprise weapon.", 17, Color(0.85, 0.85, 1.0))
		# a big question mark where the figure would stand
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 20, r.position.y + 330), "?", 190, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 250.0, 6, Color(0, 0, 0, 0.6))
		return
	var cd := ClassData.get_class_data(opt)
	UiKit.txt(c, UiKit.head(), Vector2(lx, dy + 28), String(cd["role"]).to_upper(), 16, UiKit.PINK)
	var lines := LoadoutView._wrap(UiKit.body(), String(cd["desc"]), 16, 290.0)
	for li in mini(lines.size(), 2):
		UiKit.txt(c, UiKit.body(), Vector2(lx, dy + 50 + li * 18), lines[li], 16, Color(0.85, 0.85, 1.0))
	var mods: Dictionary = cd["mods"]
	var stats := [["SPEED", float(cd["speed"]) / 1.2], ["HEALTH", float(cd["hp"]) / 120.0], ["REACH", float(mods["reach"]) / 1.8], ["DAMAGE", float(mods["dmg"]) / 1.8]]
	for si in stats.size():
		var sy := dy + 92.0 + si * 22.0
		UiKit.txt(c, UiKit.body(), Vector2(lx, sy + 10), String(stats[si][0]), 14, UiKit.DIM_TEXT)
		var filled := clampi(int(round(float(stats[si][1]) * 10.0)), 1, 10)
		for b in 10:
			var br2 := Rect2(lx + 90 + b * 20.0, sy, 16, 11)
			if b < filled:
				c.draw_rect(br2, col)
			else:
				c.draw_rect(br2, Color(col.r, col.g, col.b, 0.2), false, 2.0)


func _paint_reveal(c: Control, p: int, r: Rect2) -> void:
	var col := UiKit.player_color(p)
	var cid := choice[p]
	_panel(c, p, r, _class_label(cid))
	if was_random[p]:
		var chip := Rect2(r.end.x - 130, r.position.y + 14, 112, 26)
		c.draw_colored_polygon(UiKit.chamfer(chip, 7.0), Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, 0.9))
		UiKit.txt(c, UiKit.head(), chip.position + Vector2(0, 19), "RANDOM", 13, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x)
	var lo: Dictionary = RunState.loadouts[p]
	for i in REVEAL_SLOTS.size():
		var slot: String = REVEAL_SLOTS[i]
		var rr := Rect2(r.position.x + 18, r.position.y + 62 + i * 94.0, r.size.x - 36, 84)
		var start := ROLL_START + i * ROLL_STEP + p * 0.08
		if float(_reroll_at[p][i]) >= 0.0:
			start = float(_reroll_at[p][i])
		var age := reveal_t - start - ROLL_TIME  # < 0 while hidden / rolling
		var poly := UiKit.chamfer(rr, 12.0)
		var id: String = lo.get(slot, "")
		# button badge
		var bc := rr.position + Vector2(36, 42)
		c.draw_circle(bc, 22.0, UiKit.INK)
		c.draw_arc(bc, 22.0, 0.0, TAU, 24, Color(0.9, 0.9, 1.0, 0.85), 3.0, true)
		UiKit.txt(c, UiKit.head(), bc + Vector2(-20, 7), String(slot.substr(0, 1)), 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
		if reveal_t < start:
			c.draw_colored_polygon(poly, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.5))
			UiKit.poly_line(c, poly, Color(1, 1, 1, 0.14), 3.0)
			UiKit.txt(c, UiKit.body(), rr.position + Vector2(72, 36), String(SLOT_LABEL[slot]), 15, Color(1, 1, 1, 0.3))
			continue
		if age < 0.0:
			# rolling: names flicker past
			var pool: Array = ClassData.get_class_data(cid)["b_pool"] if slot.begins_with("B") else (ClassData.X_POOL if slot == "X" else ClassData.Y_POOL)
			var pick: String = pool[int(reveal_t * 22.0 + i * 3 + p * 5) % pool.size()]
			c.draw_colored_polygon(poly, Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.9))
			UiKit.poly_line(c, poly, Color(col.r, col.g, col.b, 0.6), 3.0)
			UiKit.txt(c, UiKit.body(), rr.position + Vector2(72, 24), String(SLOT_LABEL[slot]), 15, UiKit.DIM_TEXT)
			UiKit.txt(c, UiKit.head(), rr.position + Vector2(72, 58), MoveDB.get_move_for(pick, cid).name.to_upper(), 22, Color(1, 1, 1, 0.45))
			continue
		if not _settled[p][i]:
			_settled[p][i] = true
			Sfx.play("pickup", 1.0 + i * 0.07)
		var pop := 1.0 + 0.1 * exp(-9.0 * age) * cos(26.0 * age)
		var ctr := rr.get_center()
		c.draw_set_transform_matrix(Transform2D(Vector2(pop, 0), Vector2(0, pop), ctr * (1.0 - pop)))
		var flash := exp(-6.0 * age)
		var border := Color(col.r, col.g, col.b, 0.9).lerp(Color(1, 1, 1, 1), flash)
		c.draw_colored_polygon(poly, Color(col.r * 0.14, col.g * 0.14, col.b * 0.14, 0.95))
		UiKit.poly_line(c, poly, border, 3.0 + 2.0 * flash)
		var m := MoveDB.get_move_for(id, cid)
		UiKit.txt(c, UiKit.body(), rr.position + Vector2(72, 20), String(SLOT_LABEL[slot]), 14, UiKit.DIM_TEXT)
		UiKit.txt(c, UiKit.head(), rr.position + Vector2(72, 44), m.name.to_upper(), 21, UiKit.TEXT)
		MovePreview.draw(c, id, cid, p, Rect2(rr.end.x - 150.0, rr.position.y + 4.0, 140.0, 76.0))
		var desc := LoadoutView._wrap(UiKit.body(), m.desc, 14, rr.size.x - 260.0)
		for di in mini(desc.size(), 2):
			UiKit.txt(c, UiKit.body(), rr.position + Vector2(72, 62 + di * 16), desc[di], 14, Color(0.8, 0.8, 0.95))
		var tier := String(LoadoutView.TIER_LABEL.get(ClassData.tier_of(id), "MELEE"))
		var tw := UiKit.body().get_string_size(tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18.0
		var chip2 := Rect2(rr.end.x - 150.0 - tw - 8.0, rr.position.y + 8, tw, 22)
		if i == rev_cursor[p] and reveal_t >= REVEAL_END:
			UiKit.poly_line(c, UiKit.chamfer(rr.grow(4.0), 14.0), Color(1, 1, 1, 0.95), 3.0)
		c.draw_colored_polygon(UiKit.chamfer(chip2, 6.0), Color(1, 1, 1, 0.12))
		UiKit.txt(c, UiKit.body(), chip2.position + Vector2(0, 17), tier, 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, tw)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _paint_prompt(c: Control) -> void:
	if reveal_t < REVEAL_END:
		return
	var txt := "A  START THE RUN     UP/DOWN  SELECT A MOVE     Y  REROLL IT  (P1: %d  P2: %d LEFT)" % [RunState.setup_rerolls[0], RunState.setup_rerolls[1]]
	var col := Color(1, 1, 1, 0.55 + 0.45 * sin(_t * 5.0))
	if ready_flags[0] or ready_flags[1]:
		var waiting := 1 if ready_flags[0] and not ready_flags[1] else 0
		txt = "WAITING FOR P%d" % (waiting + 1)
		col = UiKit.player_color(waiting)
	UiKit.txt(c, UiKit.head(), Vector2(0, 700), txt, 20, col, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4, Color(0, 0, 0, 0.6))
