extends Control
## Minimal main menu until the run map exists. Navigate with stick / D-pad or WASD, A / Space to select.

const ITEMS := [
	["New Run - Streets", "run"],
	["", "class0"],
	["", "class1"],
	["", "magic"],
	["Streets (full test level)", "res://scenes/streets.tscn"],
	["Training Room", "res://scenes/training.tscn"],
	["Shop (preview)", "shop"],
	["Quit", ""],
]

var _sel := 0

const CLASS_CYCLE := ["", "brawler", "sword", "hammer", "magic"]
var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _t := 0.0


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


func _process(delta: float) -> void:
	_t += delta
	for p in Inp.players:
		var d := p.digital_dir()
		if d != _last[p.index] and d.y != 0:
			_sel = posmod(_sel + d.y, ITEMS.size())
			Sfx.play("ui")
		var key: String = ITEMS[_sel][1]
		if d != _last[p.index] and d.x != 0 and key.begins_with("class"):
			_cycle_class(int(key.substr(5)), d.x)
		_last[p.index] = d
		if p.pressed(PlayerInput.Btn.JUMP):
			if key.begins_with("class"):
				_cycle_class(int(key.substr(5)), 1)
				return
			if key == "magic":
				RunState.magic_unlocked = not RunState.magic_unlocked
				if not RunState.magic_unlocked:
					for i in 2:
						if RunState.classes[i] == "magic":
							RunState.classes[i] = ""
				Sfx.play("ui")
				return
			Sfx.play("pickup")
			var path: String = ITEMS[_sel][1]
			if path == "":
				get_tree().quit()
			elif path == "shop":
				RunState.start_run()
				RunState.coins = 260
				RunState.current = {"seed": randi(), "type": "shop", "layer": 0, "idx": 0, "next": [], "done": false}
				get_tree().change_scene_to_file("res://scenes/shop.tscn")
			elif path == "run":
				RunState.start_run()
				get_tree().change_scene_to_file("res://scenes/run_map.tscn")
			else:
				RunState.end_run()
				get_tree().change_scene_to_file(path)
			return
	queue_redraw()


func _cycle_class(player: int, dx: int) -> void:
	var i := CLASS_CYCLE.find(RunState.classes[player])
	for _n in CLASS_CYCLE.size():
		i = posmod(i + dx, CLASS_CYCLE.size())
		if CLASS_CYCLE[i] != "magic" or RunState.magic_unlocked:
			break
	RunState.classes[player] = CLASS_CYCLE[i]
	Sfx.play("ui")


func _label(i: int) -> String:
	var key: String = ITEMS[i][1]
	if key.begins_with("class"):
		var cid: String = RunState.classes[int(key.substr(5))]
		var nm := "Fists (no class)" if cid == "" else String(ClassData.get_class_data(cid)["name"])
		return "Player %d class:  < %s >" % [int(key.substr(5)) + 1, nm]
	if key == "magic":
		return "Magic class: %s   (testing toggle; locked in meta progression)" % ("UNLOCKED" if RunState.magic_unlocked else "locked")
	return String(ITEMS[i][0])


func _txt(pos: Vector2, text: String, size: int, col: Color, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 6, Color(0, 0, 0, 0.9))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.01, 0.08))
	for i in 24:
		var y := 720.0 * float(i) / 24.0
		draw_rect(Rect2(0, y, 1280, 31), Color(0.25, 0.05, 0.3, 0.012 * i))
	var wob := sin(_t * 2.0) * 4.0
	_txt(Vector2(0, 170 + wob), "NEON BRAWL", 96, Color(1.0, 0.45, 1.0), 1280.0)
	_txt(Vector2(0, 215), "co-op stickfigure brawler", 24, Color(0.5, 0.95, 1.0), 1280.0)
	for i in ITEMS.size():
		var sel := i == _sel
		_txt(Vector2(0, 320 + i * 46), ("> " if sel else "") + _label(i), 28, Color(1, 0.9, 0.4) if sel else Color(1, 1, 1, 0.75), 1280.0)
	var pads := Input.get_connected_joypads().size()
	_txt(Vector2(0, 590), "Controllers connected: %d     (keyboard works too)" % pads, 18, Color(1, 1, 1, 0.6), 1280.0)
	_txt(Vector2(0, 620), "Pause (Start / Esc) opens the Move Lab: try all 30 moves", 18, Color(1, 1, 1, 0.6), 1280.0)
