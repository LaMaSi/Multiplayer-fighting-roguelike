class_name Hud
extends CanvasLayer
## In-game overlay: per-player HP / meter / 15-slot loadout grid, shared combo counter,
## revive count, boss bar, GO arrow, banners and the result screen.

class Canvas extends Control:
	var hud: Hud

	func _draw() -> void:
		if hud != null:
			hud.paint(self)


var level: LevelBase

var _canvas: Canvas
var _trail: Array[float] = [100.0, 100.0]
var _banner := ""
var _banner_t := 0.0
var _banner_col := Color.WHITE
var _go := false
var _result := ""
var _result_win := false
var _combo_end := ""
var _combo_end_t := 0.0
var _combo_pulse := 0.0
var _go_t := 0.0
var _last_combo := 0


func _ready() -> void:
	layer = 10
	_canvas = Canvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	Coop.combo_ended.connect(_on_combo_ended)
	Coop.combo_changed.connect(func(): _combo_pulse = 1.0)


func banner(text: String, col: Color) -> void:
	_banner = text
	_banner_t = 1.6
	_banner_col = col


func set_go(v: bool) -> void:
	_go = v


func show_result(text: String, win: bool) -> void:
	_result = text
	_result_win = win


func _on_combo_ended(count: int, relays: int) -> void:
	if count >= 4:
		_combo_end = "TEAM COMBO  %d" % count + ("   (%d relays)" % relays if relays > 0 else "")
		_combo_end_t = 2.0


func _process(delta: float) -> void:
	_banner_t = maxf(0.0, _banner_t - delta)
	_combo_end_t = maxf(0.0, _combo_end_t - delta)
	_combo_pulse = maxf(0.0, _combo_pulse - delta * 5.0)
	_go_t += delta
	for i in Coop.fighters.size():
		var f := Coop.fighters[i]
		_trail[i] = move_toward(_trail[i], f.hp, 40.0 * delta)
	if _result != "":
		for p in Inp.players:
			if p.pressed(PlayerInput.Btn.JUMP):
				if _result_win:
					level.to_menu()
				else:
					level.restart()
			elif p.pressed(PlayerInput.Btn.B):
				level.to_menu()
	_canvas.queue_redraw()


static func _c(c: Color) -> Color:
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), c.a)


func _text(c: Control, pos: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string_outline(f, pos, text, align, width, size, 5, Color(0, 0, 0, 0.9))
	c.draw_string(f, pos, text, align, width, size, _c(col))


func paint(c: Control) -> void:
	for i in Coop.fighters.size():
		_paint_player(c, Coop.fighters[i], i)
	_paint_combo(c)
	# revive hearts
	_text(c, Vector2(540, 22), "REVIVES", 12, Color(1, 1, 1, 0.7), 200.0, HORIZONTAL_ALIGNMENT_CENTER)
	for h in 3:
		var col := Color(1.0, 0.3, 0.45) if h < Coop.revives_left else Color(0.25, 0.25, 0.3)
		c.draw_circle(Vector2(600 + h * 20, 34), 6.0, col)
	# boss bar
	for b in get_tree().get_nodes_in_group("boss"):
		if b is Enemy and is_instance_valid(b):
			var e := b as Enemy
			var r := Rect2(390, 684, 500, 14)
			c.draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e.hp / e.max_hp, 0, 1), r.size.y)), Color(1.0, 0.25, 0.25))
			_text(c, Vector2(390, 676), String(e.def["name"]).to_upper(), 15, Color(1, 0.7, 0.7))
	if _go:
		var a := 0.5 + 0.5 * sin(_go_t * 8.0)
		_text(c, Vector2(1080, 380), "GO  >>", 46, Color(1, 0.9, 0.3, a), 200.0, HORIZONTAL_ALIGNMENT_CENTER)
	if _banner_t > 0.0:
		var k := clampf(_banner_t / 1.6, 0.0, 1.0)
		var sz := int(70 + 30 * pow(k, 6.0))
		_text(c, Vector2(240, 300), _banner, sz, Color(_banner_col.r, _banner_col.g, _banner_col.b, minf(1.0, k * 3.0)), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
	if _result != "":
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
		_text(c, Vector2(240, 300), _result, 84, Color(0.6, 1.0, 0.8) if _result_win else Color(1, 0.4, 0.4), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		_text(c, Vector2(240, 370), "Best combo %d" % Coop.best_combo, 26, Color(1, 1, 1), 800.0, HORIZONTAL_ALIGNMENT_CENTER)
		var prompt := "A: main menu     B: main menu" if _result_win else "A: try again     B: main menu"
		_text(c, Vector2(240, 430), prompt, 22, Color(1, 1, 1, 0.85), 800.0, HORIZONTAL_ALIGNMENT_CENTER)


func _paint_player(c: Control, f: Fighter, i: int) -> void:
	var w := 292.0
	var x0 := 14.0 if i == 0 else 1280.0 - 14.0 - w
	var col := _c(f.figure.color)
	c.draw_rect(Rect2(x0, 8, w, 124), Color(0, 0, 0, 0.5))
	c.draw_rect(Rect2(x0, 8, w, 124), Color(col.r, col.g, col.b, 0.7), false, 2.0)
	_text(c, Vector2(x0 + 8, 28), "P%d" % (i + 1), 20, col)
	# hp
	var bar := Rect2(x0 + 42, 14, 236, 14)
	c.draw_rect(bar, Color(0.12, 0.05, 0.08))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_trail[i] / f.max_hp, 0, 1), bar.size.y)), Color(1, 1, 1, 0.8))
	var frac := clampf(f.hp / f.max_hp, 0.0, 1.0)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(1.0 - frac * 0.7, 0.3 + frac * 0.6, 0.3))
	_text(c, bar.position + Vector2(4, 12), "%d" % int(f.hp), 12, Color(1, 1, 1), 60.0)
	# meter
	var m := Rect2(x0 + 42, 32, 236, 7)
	c.draw_rect(m, Color(0.1, 0.1, 0.05))
	var mc := Color(1.0, 0.85, 0.2) if f.meter >= 50.0 else Color(0.7, 0.6, 0.2)
	c.draw_rect(Rect2(m.position, Vector2(m.size.x * f.meter / 100.0, m.size.y)), mc)
	c.draw_line(m.position + Vector2(m.size.x * 0.5, -1), m.position + Vector2(m.size.x * 0.5, 8), Color(1, 1, 1, 0.6), 1.0)
	# buffs
	var bx := x0 + 8.0
	for b in f.buffs:
		_text(c, Vector2(bx, 128), String(b).to_upper(), 10, Color(1, 0.9, 0.5))
		bx += 46.0
	if f.shield_hits > 0:
		_text(c, Vector2(bx, 128), "SHIELD %d" % f.shield_hits, 10, Color(0.6, 0.9, 1.0))
	# loadout grid
	var gx := x0 + 20.0
	var gy := 52.0
	var heads := ["-", "UP", "FWD", "DWN", "BCK"]
	for ci in 5:
		_text(c, Vector2(gx + ci * 52.0, gy - 3), heads[ci], 9, Color(1, 1, 1, 0.55), 52.0, HORIZONTAL_ALIGNMENT_CENTER)
	var names := ["X", "Y", "B"]
	var sufs := ["", "_UP", "_FWD", "_DOWN", "_BACK"]
	for r in 3:
		_text(c, Vector2(x0 + 6, gy + 15 + r * 23), names[r], 13, col)
		for ci in 5:
			var slot: String = names[r] + sufs[ci]
			var id: String = f.loadout.get(slot, "")
			var rect := Rect2(gx + ci * 52.0, gy + r * 23, 50, 21)
			var active := f.attack != null and f.attack.active and f.attack.move.id.rstrip("0123456789") == id and id != ""
			c.draw_rect(rect, Color(col.r, col.g, col.b, 0.55) if active else Color(1, 1, 1, 0.07))
			if id != "":
				var mv := MoveDB.get_move(id)
				_text(c, rect.position + Vector2(0, 14), mv.short, 10, Color(1, 1, 1), 50.0, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				c.draw_rect(rect, Color(1, 1, 1, 0.1), false, 1.0)


func _paint_combo(c: Control) -> void:
	var n := Coop.combo
	if n >= 2:
		var pulse := 1.0 + 0.25 * _combo_pulse
		var sz := int((40 + minf(n, 30)) * pulse)
		_text(c, Vector2(440, 100), "%d HITS" % n, sz, Color(1, 1, 1), 400.0, HORIZONTAL_ALIGNMENT_CENTER)
		var mult := Coop.combo_mult()
		var sub := "x%.2f DMG" % mult
		if Coop.relay > 0:
			sub += "   RELAY x%d" % Coop.relay
		_text(c, Vector2(440, 124), sub, 18, Color(1.0, 0.9, 0.4) if Coop.relay > 0 else Color(1, 1, 1, 0.8), 400.0, HORIZONTAL_ALIGNMENT_CENTER)
		# who contributed
		var total := float(maxi(Coop.hits_by[0] + Coop.hits_by[1], 1))
		var bw := 260.0
		var bx := 640.0 - bw * 0.5
		var w1 := bw * Coop.hits_by[0] / total
		c.draw_rect(Rect2(bx, 134, w1, 7), _c(Fighter.PLAYER_COLORS[0]))
		c.draw_rect(Rect2(bx + w1, 134, bw - w1, 7), _c(Fighter.PLAYER_COLORS[1]))
		# time left
		c.draw_rect(Rect2(bx, 143, bw * clampf(Coop.combo_t / 1.7, 0.0, 1.0), 2), Color(1, 1, 1, 0.7))
	if _combo_end_t > 0.0:
		_text(c, Vector2(340, 100), _combo_end, 30, Color(1, 0.9, 0.4, minf(1.0, _combo_end_t)), 600.0, HORIZONTAL_ALIGNMENT_CENTER)
