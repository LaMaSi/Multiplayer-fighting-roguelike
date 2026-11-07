class_name PauseMenu
extends CanvasLayer
## Pause menu (Start / Esc): friendly-fire settings, Move Lab (assign any of the 30 moves to
## any of the 15 slots), training tools, restart. Navigate with the stick/D-pad, A = select, B = back.

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
const SPAWNABLE := ["thug", "biker", "thrower", "boss_street", "dummy"]
const SLOT_NAMES := {
	"X": "X", "X_UP": "X + Up", "X_SIDE": "X + Left/Right", "X_DOWN": "X + Down",
	"Y": "Y", "Y_UP": "Y + Up", "Y_SIDE": "Y + Left/Right", "Y_DOWN": "Y + Down",
	"B": "B", "B_UP": "B + Up", "B_SIDE": "B + Left/Right", "B_DOWN": "B + Down",
}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Canvas.new()
	_canvas.menu = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if open and _page != "main":
			_page = "main"
			_sel = 0
		else:
			_toggle()


func _toggle() -> void:
	if level._cleared or Coop.is_over:
		return
	open = not open
	get_tree().paused = open
	_page = "main"
	_sel = 0
	Sfx.play("ui")


func _items() -> Array:
	var out: Array = [["resume", "Resume"],
		["ff", "Friendly fire: %s" % ("ON" if Coop.friendly_fire else "OFF")],
		["ffscale", "Friendly fire damage: %d%%" % int(Coop.ff_scale * 100.0)],
		["lo0", "Move Lab - Player 1"], ["lo1", "Move Lab - Player 2"]]
	if level is TrainingLevel:
		out.append_array([["spawn_kind", "Enemy to spawn: %s   (A: spawn)" % SPAWNABLE[_spawn_idx]], ["crate", "Spawn a crate"], ["heal", "Heal both players"]])
	out.append_array([["restart", "Restart level"], ["menu", "Main menu"]])
	return out


func _process(_delta: float) -> void:
	for p in Inp.players:
		if p.pressed(PlayerInput.Btn.START):
			_toggle()
	if open:
		for p in Inp.players:
			var d := p.digital_dir()
			if d != _last_dir[p.index] and d != Vector2i.ZERO:
				_nav(d)
			_last_dir[p.index] = d
			if p.pressed(PlayerInput.Btn.JUMP):
				_activate()
			elif p.pressed(PlayerInput.Btn.B):
				if _page != "main":
					_page = "main"
					_sel = 0
					Sfx.play("ui", 0.8)
				else:
					_toggle()
		_canvas.queue_redraw()


func _count() -> int:
	return _items().size() if _page == "main" else PlayerSlots.size() + 1


func _nav(d: Vector2i) -> void:
	Sfx.play("ui")
	if d.y != 0:
		_sel = posmod(_sel + d.y, _count())
	elif d.x != 0:
		_side(d.x)


func _side(dx: int) -> void:
	if _page == "main":
		var id: String = _items()[_sel][0]
		match id:
			"ff": Coop.friendly_fire = not Coop.friendly_fire
			"ffscale":
				var opts := [0.25, 0.5, 0.75, 1.0]
				var i := opts.find(Coop.ff_scale)
				Coop.ff_scale = opts[posmod(i + dx, opts.size())]
			"spawn_kind": _spawn_idx = posmod(_spawn_idx + dx, SPAWNABLE.size())
	elif _sel < PlayerSlots.size():
		var f := Coop.fighters[_lo_player]
		var slot: String = PlayerSlots[_sel]
		var list: Array = [""]
		list.append_array(MoveDB.POOL)
		var cur: String = f.loadout.get(slot, "")
		var i2 := list.find(cur)
		f.set_move(slot, list[posmod(i2 + dx, list.size())])


func _activate() -> void:
	if _page == "main":
		var id: String = _items()[_sel][0]
		match id:
			"resume": _toggle()
			"ff", "ffscale": _side(1)
			"lo0", "lo1":
				_lo_player = int(id.substr(2))
				_page = "lab"
				_sel = 0
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
			"restart": level.restart()
			"menu": level.to_menu()
	elif _sel == PlayerSlots.size():
		_page = "main"
		_sel = 0


const PlayerSlots: Array[String] = ["X", "X_UP", "X_SIDE", "X_DOWN", "Y", "Y_UP", "Y_SIDE", "Y_DOWN", "B", "B_UP", "B_SIDE", "B_DOWN"]


func _text(c: Control, pos: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, pos, text, align, width, size, 5, Color(0, 0, 0, 0.9))
	c.draw_string(f, pos, text, align, width, size, col)


func paint(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.06, 0.82))
	if _page == "main":
		_text(c, Vector2(240, 120), "PAUSED", 56, Color(1, 1, 1), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		var items := _items()
		for i in items.size():
			var sel := i == _sel
			var col := Color(1, 0.9, 0.4) if sel else Color(1, 1, 1, 0.75)
			_text(c, Vector2(240, 190 + i * 38), ("> " if sel else "") + String(items[i][1]), 26, col, 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		_text(c, Vector2(240, 660), "Stick / D-pad: move and change      A: select      B or Start: back", 16, Color(1, 1, 1, 0.55), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var f := Coop.fighters[_lo_player]
		var pc := Color(minf(f.figure.color.r, 1.0), minf(f.figure.color.g, 1.0), minf(f.figure.color.b, 1.0))
		_text(c, Vector2(240, 70), "MOVE LAB - PLAYER %d" % (_lo_player + 1), 40, pc, 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		_text(c, Vector2(240, 98), "Left/Right swaps the move in a slot. Resume and try it out.", 16, Color(1, 1, 1, 0.6), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		for i in PlayerSlots.size():
			var slot := PlayerSlots[i]
			var id: String = f.loadout.get(slot, "")
			var name := "(empty)" if id == "" else MoveDB.get_move(id).name
			var sel := i == _sel
			var col := Color(1, 0.9, 0.4) if sel else Color(1, 1, 1, 0.75)
			var y := 140.0 + i * 26.0
			_text(c, Vector2(300, y), ("> " if sel else "") + String(SLOT_NAMES[slot]), 20, col, 220.0)
			_text(c, Vector2(540, y), name, 20, col if id != "" else Color(1, 1, 1, 0.35), 360.0)
		var back_sel := _sel == PlayerSlots.size()
		_text(c, Vector2(300, 140.0 + 12 * 26.0 + 8.0), ("> " if back_sel else "") + "Back", 20, Color(1, 0.9, 0.4) if back_sel else Color(1, 1, 1, 0.75))
		if _sel < PlayerSlots.size():
			var id2: String = f.loadout.get(PlayerSlots[_sel], "")
			if id2 != "":
				var mv := MoveDB.get_move(id2)
				var tags := ", ".join(mv.tags) if mv.tags.size() > 0 else "melee"
				var extra := ""
				if mv.ground_only:
					extra = "   (ground only)"
				elif mv.air_only:
					extra = "   (air only)"
				_text(c, Vector2(240, 664), "%s  -  %s   [%s]%s" % [mv.name, mv.desc, tags, extra], 18, Color(0.8, 1, 0.9), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
