extends Control
## Run map: a branching path through the Streets. Either player moves the cursor (Up/Down) and
## confirms with A; both players travel together. Fight / Elite / Loot / Rest / ??? / Boss.

const COLORS := {
	"fight": Color(0.9, 0.9, 0.95), "elite": Color(1.0, 0.45, 0.2), "treasure": Color(1.0, 0.85, 0.3),
	"rest": Color(1.0, 0.75, 0.85), "mystery": Color(0.75, 0.6, 1.0), "boss": Color(1.0, 0.2, 0.2), "shop": Color(1.0, 0.72, 0.25),
}
const GLYPHS := {"fight": "X", "elite": "E", "treasure": "$", "rest": "+", "mystery": "?", "boss": "B", "shop": "S"}
const DESCS := {
	"fight": "A standard street fight. Reward: a new move or a level-up.",
	"elite": "Tougher enemies. Reward: a new move AND a level-up.",
	"treasure": "A loot room full of containers. Reward: a level-up.",
	"rest": "Recover 60% health, then choose a level-up.",
	"mystery": "Could be anything...",
	"boss": "The Big Boss. Defeat him to clear the Streets.",
	"shop": "Spend your shared coins on moves, upgrades and extra lives.",
}

var _sel := 0
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


func _node_pos(l: int, i: int) -> Vector2:
	var n: int = RunState.map[l].size()
	var y := 330.0 + (i - (n - 1) * 0.5) * 120.0
	return Vector2(250.0 + l * 170.0, y)


func _start_pos() -> Vector2:
	return Vector2(110.0, 330.0)


func _process(delta: float) -> void:
	_t += delta
	var opts := RunState.available_next()
	for p in Inp.players:
		var d := p.digital_dir()
		if d != _last[p.index] and d.y != 0 and opts.size() > 0:
			_sel = posmod(_sel + d.y, opts.size())
			Sfx.play("ui")
		_last[p.index] = d
		if p.pressed(PlayerInput.Btn.JUMP) and opts.size() > 0:
			_enter(opts[_sel])
			return
	queue_redraw()


func _enter(node: Dictionary) -> void:
	var t := RunState.choose(node)
	Sfx.play("pickup")
	if t == "rest":
		RunState.rest_here()
		get_tree().change_scene_to_file("res://scenes/reward.tscn")
	elif t == "shop":
		get_tree().change_scene_to_file("res://scenes/shop.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/streets.tscn")


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
	_txt(Vector2(0, 62), "THE STREETS", 44, Color(1, 0.8, 0.5), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(0, 92), "Levels cleared: %d   |   choose your next stop" % RunState.levels_cleared, 18, Color(1, 1, 1, 0.6), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	var opts := RunState.available_next()
	# edges
	var here := _start_pos() if RunState.pos.x < 0 else _node_pos(RunState.pos.x, RunState.pos.y)
	for n in RunState.map[0]:
		_edge(_start_pos(), _node_pos(0, n["idx"]), RunState.pos.x < 0)
	for l in RunState.map.size() - 1:
		for n in RunState.map[l]:
			for ti in n["next"]:
				var on_path: bool = RunState.pos.x == l and RunState.pos.y == n["idx"]
				_edge(_node_pos(l, n["idx"]), _node_pos(l + 1, ti), on_path)
	# start marker
	draw_circle(_start_pos(), 14.0, Color(1, 1, 1, 0.5))
	_txt(_start_pos() + Vector2(-30, 38), "START", 12, Color(1, 1, 1, 0.6), 60.0, HORIZONTAL_ALIGNMENT_CENTER)
	# nodes
	for l in RunState.map.size():
		for n in RunState.map[l]:
			var p := _node_pos(l, n["idx"])
			var col := _c(COLORS[n["type"]])
			var avail := false
			var sel := false
			for k in opts.size():
				if opts[k] == n:
					avail = true
					sel = k == _sel
			var done: bool = n["done"]
			var r := 30.0 if n["type"] != "boss" else 40.0
			if sel:
				r += 4.0 + 2.0 * sin(_t * 8.0)
			draw_circle(p, r, Color(0.07, 0.04, 0.14))
			draw_arc(p, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 1.0 if avail else (0.25 if not done else 0.6)), 4.0 if sel else 2.5, true)
			var label := String(GLYPHS[n["type"]])
			_txt(p + Vector2(-20, 9), label, 26, Color(col.r, col.g, col.b, 1.0 if avail else 0.4), 40.0, HORIZONTAL_ALIGNMENT_CENTER)
			if done:
				_txt(p + Vector2(-20, 52), "done", 11, Color(1, 1, 1, 0.5), 40.0, HORIZONTAL_ALIGNMENT_CENTER)
	if RunState.pos.x >= 0:
		draw_arc(here, 40.0, 0.0, TAU, 36, Color(1, 1, 1, 0.5), 1.5, true)
	# info
	if opts.size() > 0:
		var cur: Dictionary = opts[_sel]
		var tn: String = RunState.TYPE_NAMES[cur["type"]]
		_txt(Vector2(0, 600), tn, 30, _c(COLORS[cur["type"]]), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(0, 632), String(DESCS[cur["type"]]), 18, Color(1, 1, 1, 0.8), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(0, 668), "Up / Down: choose      A: go", 16, Color(1, 1, 1, 0.5), 1280.0, HORIZONTAL_ALIGNMENT_CENTER)
	for p in 2:
		var x := 20.0 if p == 0 else 1280.0 - 20.0 - 230.0
		var col := _c(Fighter.PLAYER_COLORS[p])
		_txt(Vector2(x, 160), "PLAYER %d" % (p + 1), 16, col)
		var frac := clampf(float(RunState.hp[p]) / float(RunState.max_hp[p]), 0.0, 1.0)
		draw_rect(Rect2(x, 170, 230, 12), Color(0.12, 0.05, 0.08))
		draw_rect(Rect2(x, 170, 230.0 * frac, 12), Color(1.0, 0.25 + 0.7 * frac, 0.25 + 0.7 * frac))
		_txt(Vector2(x, 202), "%d / %d HP" % [int(RunState.hp[p]), int(RunState.max_hp[p])], 13, Color(1, 1, 1, 0.7))


func _edge(a: Vector2, b: Vector2, hot: bool) -> void:
	draw_line(a, b, Color(1, 1, 1, 0.55 if hot else 0.14), 3.0 if hot else 2.0, true)
