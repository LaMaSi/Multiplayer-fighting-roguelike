class_name PauseMenu
extends CanvasLayer
## Pause menu (Start / Esc). Pages: main (resume, loadout, options, testing, restart, quit), options,
## testing (Move Lab, enemy spawner ...), lab (any move in any slot for the training room) and
## loadout (swap moves between buttons, both players at once, see LoadoutView).
## Stick up/down moves, left/right changes a value, A selects, B goes back, Start / Esc resumes.

class Canvas extends Control:
	var menu: PauseMenu

	func _draw() -> void:
		if menu != null and menu.open:
			menu.paint(self)


var level: LevelBase
var open := false

var _canvas: Canvas
var _page := "main"
var _sel := 0
var _lo_player := 0
var _spawn_idx := 1
var _last_dir: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _lv: LoadoutView
var _b_guard := false  ## ignore B until it is released (the loadout screen closes on B)
var _t := 0.0
var _toggle_cd := 0.0
const SPAWNABLE := ["thug", "biker", "thrower", "boss_street", "dummy"]
const SLOT_NAMES := {
	"X": "X", "X_UP": "X + Up", "X_SIDE": "X + Left/Right", "X_DOWN": "X + Down",
	"Y": "Y", "Y_UP": "Y + Up", "Y_SIDE": "Y + Left/Right", "Y_DOWN": "Y + Down",
	"B": "B", "B_UP": "B + Up", "B_SIDE": "B + Left/Right", "B_DOWN": "B + Down",
}
const PlayerSlots: Array[String] = ["X", "X_UP", "X_SIDE", "X_DOWN", "Y", "Y_UP", "Y_SIDE", "Y_DOWN", "B", "B_UP", "B_SIDE", "B_DOWN"]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Canvas.new()
	_canvas.menu = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_lv = LoadoutView.new(
		func(p: int) -> Dictionary: return Coop.fighters[p].loadout,
		func(p: int, slot: String, id: String) -> void: Coop.fighters[p].set_move(slot, id),
		func(p: int) -> String: return Coop.fighters[p].class_id,
		func(p: int) -> Dictionary: return Coop.fighters[p].upgrades)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if open and _page != "main":
			_back()
		else:
			_toggle()


func _toggle() -> void:
	if level._cleared or Coop.is_over:
		return
	open = not open
	get_tree().paused = open
	if level.hud != null:
		level.hud.visible = not open  # the pause screens replace the HUD
	_page = "main"
	_sel = 0
	_lv.reset()
	Sfx.play("ui")


func _back() -> void:
	match _page:
		"lab":
			_go("testing", 0)
		"options":
			_go("main", 2)
		"testing":
			_go("main", 3)
		"loadout":
			_lv.reset()
			_go("main", 1)
		_:
			_go("main", 0)


func _go(page: String, sel := 0) -> void:
	_page = page
	_sel = sel
	Sfx.play("ui", 0.8)


# ------------------------------------------------------------------ items

func _testing_items() -> Array:
	var t: Array = []
	if not RunState.active:
		t.append(["lo0", "MOVE LAB  -  PLAYER 1", ""])
		if not RunState.solo:
			t.append(["lo1", "MOVE LAB  -  PLAYER 2", ""])
	if level is TrainingLevel:
		t.append_array([["spawn_kind", "SPAWN ENEMY", String(SPAWNABLE[_spawn_idx]).to_upper()], ["crate", "SPAWN A CRATE", ""], ["heal", "HEAL BOTH PLAYERS", ""]])
	t.append(["back", "BACK", ""])
	return t


func _items() -> Array:
	match _page:
		"options":
			return OptionsList.items()
		"testing":
			return _testing_items()
	var m: Array = [["resume", "RESUME", ""], ["loadout", "LOADOUT", ""], ["options", "OPTIONS", ""]]
	if _testing_items().size() > 1:
		m.append(["testing", "TESTING", ""])
	m.append_array([["restart", "RESTART LEVEL", ""], ["menu", "QUIT TO MENU", ""]])
	return m


func _count() -> int:
	return PlayerSlots.size() + 1 if _page == "lab" else _items().size()


# ------------------------------------------------------------------ input (physics step, right after Inp polls)

func _physics_process(delta: float) -> void:
	_t += delta
	_toggle_cd = maxf(0.0, _toggle_cd - delta)
	# Start / Back from either player. One toggle per step however many pressed (two simultaneous presses used to
	# open and close the menu again), and a short lockout so presses a few frames apart do not cancel either.
	var start_pressed := false
	var back_pressed := false
	for p in Inp.players:
		start_pressed = start_pressed or p.pressed(PlayerInput.Btn.START)
		back_pressed = back_pressed or p.pressed(PlayerInput.Btn.BACK)
	if _toggle_cd <= 0.0:
		if back_pressed:
			_toggle_cd = 0.2
			if not open:
				_toggle()
				if open:
					_lv.reset()
					_go("loadout", 0)
			elif _page == "loadout":
				_lv.reset()
				_toggle()
			else:
				_lv.reset()
				_go("loadout", 0)
		elif start_pressed:
			_toggle_cd = 0.2
			_lv.reset()
			_toggle()  # Start again closes the menu from any page, the loadout screen included
	if not open:
		return
	if _page == "loadout":
		_lv.update(delta)
		if _lv.close_requested:
			_lv.reset()
			_b_guard = true
			_go("main", 1)
		_canvas.queue_redraw()
		return
	var b_ok := true
	if _b_guard:
		b_ok = false
		var any_b := false
		for p in Inp.players:
			any_b = any_b or p.is_held(PlayerInput.Btn.B)
		_b_guard = any_b
	for p in Inp.players:
		var d := p.digital_dir()
		if d != _last_dir[p.index] and d != Vector2i.ZERO:
			_nav(d)
		_last_dir[p.index] = d
		if p.pressed(PlayerInput.Btn.JUMP):
			_activate()
		elif b_ok and p.pressed(PlayerInput.Btn.B):
			if _page != "main":
				_back()
			else:
				_toggle()
	_canvas.queue_redraw()


func _nav(d: Vector2i) -> void:
	Sfx.play("ui")
	if d.y != 0:
		_sel = posmod(_sel + d.y, _count())
	elif d.x != 0:
		_side(d.x)


func _side(dx: int) -> void:
	if _page == "lab":
		if _sel < PlayerSlots.size():
			var f := Coop.fighters[_lo_player]
			var slot: String = PlayerSlots[_sel]
			var list: Array = [""]
			if f.class_id == "":
				list.append_array(MoveDB.POOL)  # legacy fighter: the original pool, any slot
			else:
				list.append_array(ClassData.pool_for_slot(slot, f.class_id))  # X universal, Y adaptive, B own class
			var cur: String = f.loadout.get(slot, "")
			f.set_move(slot, list[posmod(list.find(cur) + dx, list.size())])
		return
	var id: String = _items()[_sel][0]
	if _page == "options":
		OptionsList.adjust(id, dx)
	elif id == "spawn_kind":
		_spawn_idx = posmod(_spawn_idx + dx, SPAWNABLE.size())


func _activate() -> void:
	if _page == "lab":
		if _sel == PlayerSlots.size():
			_go("testing", 0)
		return
	var id: String = _items()[_sel][0]
	if _page == "options":
		if id == "back":
			_back()
		else:
			OptionsList.adjust(id, 1)
		return
	match id:
		"resume":
			_toggle()
		"loadout":
			_lv.reset()
			_go("loadout", 0)
		"options":
			_go("options", 0)
		"testing":
			_go("testing", 0)
		"back":
			_back()
		"lo0", "lo1":
			_lo_player = int(id.substr(2))
			_go("lab", 0)
		"spawn_kind":
			var x := Coop.fighters[0].global_position.x + 360.0
			level.spawn_enemy(SPAWNABLE[_spawn_idx], Vector2(clampf(x, 100.0, level.level_w - 100.0), level.ground_y - 1.0))
			_toggle()
		"crate":
			level.spawn_prop(["crate", "barrel", "vase"][randi() % 3], Vector2(Coop.fighters[0].global_position.x + 120.0, level.ground_y - 200.0))
			_toggle()
		"heal":
			for f in Coop.fighters:
				f.hp = f.max_hp
				f.meter = 100.0
				if f.state == "downed":
					f.revive()
			_toggle()
		"restart":
			level.restart()
		"menu":
			level.to_menu()


# ------------------------------------------------------------------ drawing

func _title(c: Control, text: String, pos: Vector2, size: int) -> void:
	c.draw_set_transform_matrix(UiKit.italic(pos, -0.02))
	for k in 3:
		UiKit.txt(c, UiKit.head(), Vector2.ZERO, text, size, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, UiKit.head(), Vector2.ZERO, text, size, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func paint(c: Control) -> void:
	if _page == "loadout":
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.06, 0.8))
		_lv.paint_screen(c)
		return
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.06, 0.68))
	var heading := {"main": "PAUSED", "options": "OPTIONS", "testing": "TESTING", "lab": "MOVE LAB"}[_page] as String
	_title(c, heading, Vector2(60, 96), 56 if _page == "main" else 44)
	if _page == "lab":
		_paint_lab(c)
		return
	var items := _items()
	for i in items.size():
		var id: String = items[i][0]
		var adj := (_page == "options" and id != "back") or id == "spawn_kind"
		UiKit.button(c, Rect2(80, 150 + i * 62.0, 360, 50), String(items[i][1]), i == _sel, String(items[i][2]), adj)
	if _page == "main":
		_paint_status(c)


## Right side of the main page: run info and a read-only view of both loadouts.
func _paint_status(c: Control) -> void:
	var x := 500.0
	if RunState.active:
		UiKit.panel(c, Rect2(x, 150, 330, 50), 12.0, UiKit.AMBER, 3.0, 0.85)
		UiKit.coin(c, Vector2(x + 28, 175), 13.0)
		UiKit.txt(c, UiKit.head(), Vector2(x + 52, 184), str(RunState.coins), 22, UiKit.AMBER)
	UiKit.panel(c, Rect2(x + 350, 150, 340, 50), 12.0, Color(0.8, 0.8, 1.0, 0.55), 3.0, 0.85)
	var n := Coop.revives_max
	for h in n:
		UiKit.heart(c, Vector2(x + 380 + h * 36, 176), 13.0, h < Coop.revives_left)
	if RunState.active:
		UiKit.txt(c, UiKit.body(), Vector2(x + 350, 182), "STREETS  ·  %d CLEARED" % RunState.levels_cleared, 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 326.0)
	_lv.paint_mini(c, 0, Rect2(x, 230, 370, 232))
	if not RunState.solo:
		_lv.paint_mini(c, 1, Rect2(x + 390, 230, 370, 232))


func _paint_lab(c: Control) -> void:
	var f := Coop.fighters[_lo_player]
	var pc := UiKit.player_color(_lo_player)
	UiKit.txt(c, UiKit.head(), Vector2(60, 126), "PLAYER %d" % (_lo_player + 1), 18, pc)
	UiKit.txt(c, UiKit.body(), Vector2(200, 124), "LEFT / RIGHT SWAPS THE MOVE IN A SLOT", 16, UiKit.DIM_TEXT)
	for i in PlayerSlots.size():
		var slot := PlayerSlots[i]
		var id: String = f.loadout.get(slot, "")
		var nm := "EMPTY" if id == "" else MoveDB.get_move(id).name.to_upper()
		var r := Rect2(80 + (i % 4) * 0.0, 150 + i * 36.0, 520, 32)
		UiKit.button(c, r, String(SLOT_NAMES[slot]).to_upper(), i == _sel, nm, true)
	var back_r := Rect2(80, 150 + PlayerSlots.size() * 36.0 + 8, 520, 32)
	UiKit.button(c, back_r, "BACK", _sel == PlayerSlots.size())
	if _sel < PlayerSlots.size():
		var id2: String = f.loadout.get(PlayerSlots[_sel], "")
		if id2 != "":
			var mv := MoveDB.get_move(id2)
			var tags := ", ".join(mv.tags) if mv.tags.size() > 0 else "melee"
			UiKit.txt(c, UiKit.body(), Vector2(660, 190), mv.name.to_upper(), 26, UiKit.TEXT)
			UiKit.txt(c, UiKit.body(), Vector2(660, 222), mv.desc, 18, Color(0.85, 0.85, 1.0))
			UiKit.charge_chip(c, Rect2(660.0, 262.0, 30.0, 30.0), mv)
			UiKit.txt(c, UiKit.body(), Vector2(660, 250), tags.to_upper() + ("   GROUND ONLY" if mv.ground_only else ("   AIR ONLY" if mv.air_only else "")), 14, UiKit.DIM_TEXT)


# ------------------------------------------------------------------ mouse
## Hover selects a row, left click activates it (Move Lab: next move), right click / wheel change a value.

func _row_rect(i: int) -> Rect2:
	if _page == "lab":
		if i == PlayerSlots.size():
			return Rect2(80, 150 + PlayerSlots.size() * 36.0 + 8, 520, 32)
		return Rect2(80, 150 + i * 36.0, 520, 32)
	return Rect2(80, 150 + i * 62.0, 360, 50)


func _row_at(pos: Vector2) -> int:
	for i in _count():
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not open or _canvas == null or _page == "loadout":
		return
	if event is InputEventMouseMotion:
		var i := _row_at(_canvas.get_local_mouse_position())
		if i >= 0 and i != _sel:
			_sel = i
			Sfx.play("ui", 1.2)
	elif event is InputEventMouseButton and event.pressed:
		var i2 := _row_at(_canvas.get_local_mouse_position())
		if i2 < 0:
			return
		_sel = i2
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				Sfx.play("ui")
				if _page == "lab" and i2 < PlayerSlots.size():
					_side(1)
				else:
					_activate()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_DOWN:
				_side(-1)
			MOUSE_BUTTON_WHEEL_UP:
				_side(1)
		get_viewport().set_input_as_handled()
