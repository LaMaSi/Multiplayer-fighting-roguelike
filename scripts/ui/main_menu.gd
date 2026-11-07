extends Control
## Start screen (see docs/UI.md): synthwave backdrop, tilted neon title, a button list and the two
## players on screen showing the class they picked. Pages: main, options, testing.
## Stick up/down moves, left/right changes a value, A selects, B goes back. Either player can drive it.

const CLASS_CYCLE := ["", "brawler", "sword", "hammer", "magic"]

class View extends Control:
	var menu: Control

	func _draw() -> void:
		if menu != null:
			menu.paint(self)


var _page := "main"
var _sel := 0
var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _t := 0.0
var _view: View
var _figs: Array[StickFigure] = []
var _fig_class: Array[String] = ["?", "?"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Engine.time_scale = 1.0
	Dbg._hint.visible = false
	add_child(ScreenBackdrop.new())
	var figs := Node2D.new()
	add_child(figs)
	for i in 2:
		var f := StickFigure.new()
		f.color = UiKit.player_color(i)
		f.arm_scale = 1.22
		f.leg_scale = 1.2
		f.eyes = true
		f.aim = Vector2(0.9, -0.05)
		f.position = Vector2(880 + i * 210, 668)
		f.scale = Vector2(-1.9, 1.9)  # they stand on the right, facing the menu
		figs.add_child(f)
		_figs.append(f)
	_view = View.new()
	_view.menu = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_update_figures(true)


# ------------------------------------------------------------------ items

func _items() -> Array:
	match _page:
		"options":
			return OptionsList.items()
		"testing":
			return [["streets", "STREETS FULL TEST LEVEL", ""], ["shop", "SHOP PREVIEW", ""],
				["magic", "MAGIC CLASS", "UNLOCKED" if RunState.magic_unlocked else "LOCKED"], ["back", "BACK", ""]]
	return [["run", "NEW RUN", "STREETS"], ["class0", "", ""], ["class1", "", ""], ["training", "TRAINING ROOM", ""],
		["options", "OPTIONS", ""], ["testing", "TESTING", ""], ["quit", "QUIT", ""]]


func _go_page(page: String, sel := 0) -> void:
	_page = page
	_sel = sel
	Sfx.play("ui")


# ------------------------------------------------------------------ input (physics step: right after Inp polls)

func _physics_process(_delta: float) -> void:
	var items := _items()
	for p in Inp.players:
		var d := p.digital_dir()
		if d != _last[p.index] and d != Vector2i.ZERO:
			if d.y != 0:
				_sel = posmod(_sel + d.y, items.size())
				Sfx.play("ui")
			else:
				_side(String(items[_sel][0]), d.x)
		_last[p.index] = d
		if p.pressed(PlayerInput.Btn.JUMP):
			_activate(String(items[_sel][0]))
			return
		if p.pressed(PlayerInput.Btn.B) and _page != "main":
			_go_page("main", 4 if _page == "options" else 5)
			return


func _side(id: String, dx: int) -> void:
	if id.begins_with("class"):
		_cycle_class(int(id.substr(5)), dx)
	elif _page == "options":
		OptionsList.adjust(id, dx)
		Sfx.play("ui")
	elif id == "magic":
		_toggle_magic()


func _activate(id: String) -> void:
	if id.begins_with("class"):
		_cycle_class(int(id.substr(5)), 1)
		return
	if _page == "options":
		if id == "back":
			_go_page("main", 4)
		else:
			OptionsList.adjust(id, 1)
			Sfx.play("ui")
		return
	match id:
		"magic":
			_toggle_magic()
		"back":
			_go_page("main", 5)
		"options":
			_go_page("options")
		"testing":
			_go_page("testing")
		"quit":
			get_tree().quit()
		"run":
			Sfx.play("pickup")
			RunState.start_run()
			get_tree().change_scene_to_file("res://scenes/run_map.tscn")
		"training":
			Sfx.play("pickup")
			RunState.end_run()
			get_tree().change_scene_to_file("res://scenes/training.tscn")
		"streets":
			Sfx.play("pickup")
			RunState.end_run()
			get_tree().change_scene_to_file("res://scenes/streets.tscn")
		"shop":
			Sfx.play("pickup")
			RunState.start_run()
			RunState.coins = 260
			RunState.current = {"seed": randi(), "type": "shop", "layer": 0, "idx": 0, "next": [], "done": false}
			get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _toggle_magic() -> void:
	RunState.magic_unlocked = not RunState.magic_unlocked
	if not RunState.magic_unlocked:
		for i in 2:
			if RunState.classes[i] == "magic":
				RunState.classes[i] = ""
	Sfx.play("ui")


func _cycle_class(player: int, dx: int) -> void:
	var i := CLASS_CYCLE.find(RunState.classes[player])
	for _n in CLASS_CYCLE.size():
		i = posmod(i + dx, CLASS_CYCLE.size())
		if CLASS_CYCLE[i] != "magic" or RunState.magic_unlocked:
			break
	RunState.classes[player] = CLASS_CYCLE[i]
	Sfx.play("ui")


# ------------------------------------------------------------------ figures

func _update_figures(snap := false) -> void:
	for i in 2:
		var cid: String = RunState.classes[i]
		var f := _figs[i]
		if cid != _fig_class[i]:
			_fig_class[i] = cid
			f.weapon = "" if cid == "" else String(ClassData.get_class_data(cid)["weapon"])
		var pose: Dictionary = PoseLib.idle(_t + i) if cid == "" else ClassData.base_pose(cid, _t + i)
		f.set_target(pose, snap)


func _process(delta: float) -> void:
	_t += delta
	_update_figures()
	_view.queue_redraw()


# ------------------------------------------------------------------ drawing

func _class_name(player: int) -> String:
	var cid: String = RunState.classes[player]
	return "FISTS" if cid == "" else String(ClassData.get_class_data(cid)["name"]).to_upper()


func _class_row(c: Control, r: Rect2, player: int, selected: bool) -> void:
	var pc := UiKit.player_color(player)
	var p := UiKit.chamfer(r, 12.0)
	if selected:
		UiKit.glow_poly(c, p, Color(pc.r, pc.g, pc.b, 1.0) * 1.6, 0.22)
	c.draw_colored_polygon(p, Color(pc.r * 0.15, pc.g * 0.15, pc.b * 0.15, 0.9))
	UiKit.poly_line(c, p, UiKit.TEXT if selected else Color(pc.r, pc.g, pc.b, 0.75), 4.0 if selected else 3.0)
	if selected:
		var my := r.position.y + r.size.y * 0.5
		c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 26, my - 12), Vector2(r.position.x - 8, my), Vector2(r.position.x - 26, my + 12)]), UiKit.PINK)
	UiKit.txt(c, UiKit.head(), r.position + Vector2(22, r.size.y * 0.5 + 7), "P%d" % (player + 1), 17, pc)
	var name := _class_name(player)
	UiKit.txt(c, UiKit.head(), r.position + Vector2(0, r.size.y * 0.5 + 7), ("<  %s  >" % name) if selected else name, 17, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0)


func paint(c: Control) -> void:
	# title: tilted, glowing, with a cyan offset shadow
	c.draw_set_transform_matrix(UiKit.italic(Vector2(640, 150), -0.035, 1.0, -0.22))
	UiKit.txt(c, UiKit.head(), Vector2(-520, 4), "NEON BRAWL", 96, Color(0.2, 0.9, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 1040.0)
	for k in 3:
		UiKit.txt(c, UiKit.head(), Vector2(-520, 0), "NEON BRAWL", 96, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_CENTER, 1040.0, 10 + k * 10, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, UiKit.head(), Vector2(-520, 0), "NEON BRAWL", 96, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 1040.0, 5, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	c.draw_rect(Rect2(430, 194, 420, 3), UiKit.PINK)
	UiKit.txt(c, UiKit.head(), Vector2(0, 226), "CO-OP STICKFIGURE BRAWLER", 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 4, Color(0, 0, 0, 0.7))
	var heading := {"main": "", "options": "OPTIONS", "testing": "TESTING"}[_page] as String
	if heading != "":
		UiKit.txt(c, UiKit.head(), Vector2(110, 268), heading, 16, UiKit.PINK)
	var items := _items()
	var y0 := 284.0 if heading != "" else 270.0
	for i in items.size():
		var r := Rect2(110, y0 + i * 56.0, 360, 46)
		var id: String = items[i][0]
		var sel := i == _sel
		if _page == "main" and id.begins_with("class"):
			_class_row(c, r, int(id.substr(5)), sel)
		else:
			var adj := _page == "options" and id != "back" and id != "post" or id == "magic"
			if _page == "options" and id == "post":
				adj = true
			UiKit.button(c, r, String(items[i][1]), sel, String(items[i][2]), adj)
	UiKit.txt(c, UiKit.body(), Vector2(40, 700), "STICK  MOVE      A  SELECT      B  BACK", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
	UiKit.txt(c, UiKit.body(), Vector2(900, 700), "V0.1  ·  GODOT 4.5", 16, Color(0.6, 0.6, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 3)
