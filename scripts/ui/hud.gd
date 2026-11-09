class_name Hud
extends CanvasLayer
## In-game overlay (see docs/STYLEGUIDE.md): per player a ring with the HP number, 10 HP blocks and a
## big super meter (gold pulse when usable, burning when full); a shared tilted combo counter that
## punches on every hit and grows every 5; shared lives; boss bar, GO arrow, banners and the level
## complete / game over screens. The move grid is hidden by default (F2 toggles it).

class Canvas extends Control:
	var hud: Hud

	func _draw() -> void:
		if hud != null:
			hud.paint(self)


const TILTS := [-0.06, 0.09, -0.15, 0.13, -0.21, 0.17]
const METER_USABLE := 0.5  ## a super / Duo needs at least half a meter

static var show_moves := false

var level: LevelBase
var objective := ""  ## one-line goal shown under the revive hearts

var _canvas: Canvas
var _trail: Array[float] = [100.0, 100.0]
var _hp_prev: Array[float] = [-1.0, -1.0]
var _hp_shake: Array[float] = [0.0, 0.0]  ## health bar shake per player: jumps on damage, decays fast
var _banner := ""
var _banner_t := 0.0
var _banner_col := Color.WHITE
var _go := false
var _result := ""
var _result_win := false
var _stats: Dictionary = {}
var _combo_end := ""
var _combo_end_t := 0.0
var _combo_age := 9.0
var _callouts: Array = []  # {text, col, age, tilt, dx}: keyword shout-outs next to the combo counter
const CALLOUT_LIFE := 1.5
var _go_t := 0.0
var _clock := 0.0
var _result_t := 0.0
var _result_layer: CanvasLayer


func _ready() -> void:
	layer = 10
	_canvas = Canvas.new()
	_canvas.hud = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	Coop.combo_ended.connect(_on_combo_ended)
	Coop.combo_changed.connect(func(): _combo_age = 0.0)
	Coop.callout_made.connect(_on_callout)


func banner(text: String, col: Color) -> void:
	_banner = text
	_banner_t = 1.6
	_banner_col = col


func set_go(v: bool) -> void:
	_go = v


func show_result(text: String, win: bool, stats := {}) -> void:
	_result = text
	_result_win = win
	_stats = stats
	_result_t = 0.0
	if win and _result_layer == null and level != null:
		_spawn_result_backdrop()


## Dimmed backdrop and the two cheering stickfigures, one canvas layer below the HUD text.
func _spawn_result_backdrop() -> void:
	for f in Coop.fighters:
		if is_instance_valid(f):
			f.visible = false  # the cheering figures below stand in for them
	for n in level.get_children():
		if n is Prop or n is Pickup or n is Enemy:
			n.visible = false
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 9
	level.add_child(_result_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_layer.add_child(dim)
	var poses := [
		{"lean": -0.05, "head": -0.12, "root_y": -4.0, "th_f": 0.35, "kn_f": 0.3, "th_b": -0.35, "kn_b": 0.3, "ua_f": 2.7, "la_f": 0.3, "ua_b": 2.9, "la_b": 0.2},
		{"lean": 0.0, "head": -0.15, "root_y": -10.0, "th_f": 0.25, "kn_f": 0.7, "th_b": -0.25, "kn_b": 0.7, "ua_f": 2.5, "la_f": 0.4, "ua_b": 3.0, "la_b": 0.1},
	]
	for i in (1 if RunState.solo else 2):
		var f := StickFigure.new()
		f.color = UiKit.player_color(i)
		f.arm_scale = 1.22
		f.leg_scale = 1.2
		f.eyes = true
		f.aim = Vector2(0.3 if i == 0 else -0.3, -0.8)
		f.position = Vector2(90.0 + i * 100.0, 668)
		f.scale = Vector2(1.4, 1.4)
		f.set_target(poses[i], true)
		_result_layer.add_child(f)


func _on_callout(text: String, col: Color) -> void:
	for co in _callouts:
		if co["text"] == text and float(co["age"]) < 0.3:
			return
	_callouts.push_front({"text": text, "col": col, "age": 0.0, "tilt": randf_range(-0.3, 0.3), "dx": randf_range(-70.0, 70.0)})
	if _callouts.size() > 4:
		_callouts.resize(4)


func _on_combo_ended(count: int, relays: int) -> void:
	if count >= 4:
		_combo_end = "TEAM COMBO  %d" % count + ("   (%d relays)" % relays if relays > 0 else "")
		_combo_end_t = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		show_moves = not show_moves


func _process(delta: float) -> void:
	_clock += delta
	_banner_t = maxf(0.0, _banner_t - delta)
	_combo_end_t = maxf(0.0, _combo_end_t - delta)
	_combo_age += delta
	for co in _callouts:
		co["age"] = float(co["age"]) + delta
	_callouts = _callouts.filter(func(co): return float(co["age"]) < CALLOUT_LIFE)
	_go_t += delta
	if _result != "":
		_result_t += delta
	for i in Coop.fighters.size():
		var f := Coop.fighters[i]
		_trail[i] = move_toward(_trail[i], f.hp, 40.0 * delta)
		if _hp_prev[i] >= 0.0 and f.hp < _hp_prev[i] - 0.01:
			_hp_shake[i] = clampf(0.5 + (_hp_prev[i] - f.hp) / 30.0, 0.5, 1.0)
		_hp_prev[i] = f.hp
		_hp_shake[i] = maxf(0.0, _hp_shake[i] - 3.2 * delta)
	if _result != "":
		for p in Inp.players:
			if p.pressed(PlayerInput.Btn.JUMP):
				if _result_win:
					level.finish_level()
				elif RunState.active:
					RunState.end_run()
					level.to_menu()
				else:
					level.restart()
			elif p.pressed(PlayerInput.Btn.B) and not _result_win:
				RunState.end_run()
				level.to_menu()
	_canvas.queue_redraw()


static func _c(c: Color) -> Color:
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), c.a)


func paint(c: Control) -> void:
	if _result != "" and _result_win:
		LevelCompleteView.paint(c, _stats, _result_t)
		return
	for i in Coop.fighters.size():
		_paint_player(c, Coop.fighters[i], i)
	_paint_combo(c)
	_paint_lives(c)
	_paint_boss(c)
	if absf(Juice.user_time_scale - 1.0) > 0.01:
		UiKit.txt(c, UiKit.body(), Vector2(0, 706), "TIME SCALE x%.2f" % Juice.user_time_scale, 16, Color(1.0, 0.75, 0.4, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
	if go_visible():  # (never inside a challenge room: you fight there, you do not leave)
		var a := 0.5 + 0.5 * sin(_go_t * 8.0)
		c.draw_set_transform_matrix(UiKit.italic(Vector2(1180, 380), -0.04))
		UiKit.txt(c, UiKit.head(), Vector2(-100, 0), "GO >>", 46, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, a), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 5, Color(0, 0, 0, a))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _banner_t > 0.0:
		var k := clampf(_banner_t / 1.6, 0.0, 1.0)
		var sc := 1.0 + 0.45 * pow(k, 6.0)
		var col := Color(_banner_col.r, _banner_col.g, _banner_col.b, minf(1.0, k * 3.0))
		c.draw_set_transform_matrix(UiKit.italic(Vector2(640, 330), -0.03, sc))
		for g in 3:
			UiKit.txt(c, UiKit.head(), Vector2(-400, 0), _banner, 72, Color(col.r, col.g, col.b, col.a * 0.14), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 8 + g * 8, Color(col.r, col.g, col.b, col.a * 0.07))
		UiKit.txt(c, UiKit.head(), Vector2(-400, 0), _banner, 72, _c(col), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 6, Color(0.05, 0.0, 0.1, col.a))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _result != "":
		_paint_game_over(c)


# ------------------------------------------------------------------ players

## Whether the GO >> arrow shows: not inside a challenge room.
func go_visible() -> bool:
	var in_challenge := level != null and level.in_room and level._room != null and level._room.kind == "challenge"
	return _go and not in_challenge


func _flame(c: Control, x: float, y: float, w: float, strength: float) -> void:
	var n := int(w / 9.0)
	for i in n:
		var ph := _clock * 11.0 + float(i) * 1.9
		var hgt := (14.0 + 16.0 * (0.5 + 0.5 * sin(ph)) + 8.0 * sin(ph * 2.3 + 1.0)) * strength
		var fx := x + 4.0 + i * 9.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 5.5, y), Vector2(fx + sin(ph) * 2.0, y - hgt), Vector2(fx + 5.5, y)]), Color(2.2, 0.9, 0.2, 0.9))
		c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 2.5, y), Vector2(fx, y - hgt * 0.6), Vector2(fx + 2.5, y)]), Color(2.4, 2.0, 1.0, 0.95))


const LOW_HP := 0.3  ## below this share of health the HP bar turns red and the panel pulses
const LOW_RED := Color(2.1, 0.22, 0.26)


func _paint_player(c: Control, f: Fighter, i: int) -> void:
	var flip := i == 1
	var col := UiKit.player_color(i)
	var hp := clampf(f.hp / f.max_hp, 0.0, 1.0)
	var trail := clampf(_trail[i] / f.max_hp, 0.0, 1.0)
	var meter := clampf(f.meter / 100.0, 0.0, 1.0)
	var x0 := 24.0
	var y0 := 18.0
	# low health: the HP blocks turn red (the frame and ring keep the player's colour) and the whole panel pulses a little,
	# faster the lower it gets, so the weak player is easy to spot at a glance
	var low := hp > 0.0 and hp <= LOW_HP
	var bar_col := LOW_RED if low else col
	var base := Transform2D.IDENTITY
	if low:
		var k := 1.0 + 0.032 * (0.5 + 0.5 * sin(_clock * (5.0 + 5.0 * (1.0 - hp / LOW_HP))))
		var anchor := Vector2(1280.0 - x0, y0) if flip else Vector2(x0, y0)
		base = Transform2D(0.0, Vector2(k, k), 0.0, anchor * (1.0 - k))
	if _hp_shake[i] > 0.0:
		base.origin += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 12.0 * _hp_shake[i]
	var cx := 1280.0 - (x0 + 38.0) if flip else x0 + 38.0
	var cy := y0 + 38.0
	var mx := Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(1280, 0)) if flip else Transform2D.IDENTITY
	c.draw_set_transform_matrix(base * mx)
	var hx := x0 + 62.0
	var hy := y0 + 10.0
	var frame := PackedVector2Array([
		Vector2(hx, hy + 6), Vector2(hx + 34, hy + 6), Vector2(hx + 44, hy), Vector2(hx + 290, hy), Vector2(hx + 300, hy + 6),
		Vector2(hx + 386, hy + 6), Vector2(hx + 386, hy + 34), Vector2(hx + 364, hy + 56), Vector2(hx + 60, hy + 56),
		Vector2(hx + 48, hy + 50), Vector2(hx, hy + 50)])
	c.draw_colored_polygon(frame, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.8))
	UiKit.poly_line(c, frame, col, 3.0)
	# 10 HP blocks
	for b in 10:
		var r := Rect2(hx + 22.0 + b * 35.0, hy + 15.0, 29.0, 26.0)
		var t0 := float(b) / 10.0
		var t1 := float(b + 1) / 10.0
		if hp >= t1:
			c.draw_rect(r, bar_col)
		elif hp > t0:
			c.draw_rect(Rect2(r.position, Vector2(r.size.x * (hp - t0) * 10.0, r.size.y)), bar_col)
			c.draw_rect(r, Color(bar_col.r, bar_col.g, bar_col.b, 0.3), false, 2.0)
		elif trail > t0:
			c.draw_rect(r, Color(0.95, 0.4, 0.25, 0.85) if trail >= t1 else Color(0.95, 0.4, 0.25, 0.5))
		else:
			c.draw_rect(r, Color(col.r, col.g, col.b, 0.22), false, 2.0)
	# stun meter: a thin amber strip under the HP blocks; while dazed it drains with the time left to wake up
	var sr := Rect2(hx + 22.0, hy + 43.0, 350.0, 4.0)
	var stunned := f.state == "stunned"
	var sfrac := clampf(f.stunned_t / Actor.STUN_TIME, 0.0, 1.0) if stunned else clampf(f.stun_meter / Actor.STUN_MAX, 0.0, 1.0)
	c.draw_rect(sr, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.9))
	if sfrac > 0.0:
		var sc := Color(2.2, 2.0, 0.5) if stunned and int(_clock * 8.0) % 2 == 0 else Color(1.9, 1.3, 0.3)
		c.draw_rect(Rect2(sr.position, Vector2(sr.size.x * sfrac, sr.size.y)), sc)
	# super meter: calm below the usable mark, gold + soft pulse when usable, burning when full
	var mxp := hx + 14.0
	var myp := hy + 66.0
	var mw := 372.0
	var mh := 22.0
	var full := meter >= 0.999
	var usable := meter >= METER_USABLE
	var pulse := 0.5 + 0.5 * sin(_clock * (9.0 if full else 3.4))
	var mframe := PackedVector2Array([Vector2(mxp, myp), Vector2(mxp + mw - 18.0, myp), Vector2(mxp + mw, myp + mh), Vector2(mxp + 14.0, myp + mh)])
	if usable:
		var ha := (0.10 + 0.16 * pulse) if not full else (0.22 + 0.28 * pulse)
		UiKit.glow_poly(c, mframe, Color(2.0, 1.4, 0.5), ha * 1.6)
	c.draw_colored_polygon(mframe, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	if meter > 0.01:
		var fw := (mw - 22.0) * meter
		var fill_poly := PackedVector2Array([Vector2(mxp + 2.0, myp + 2.0), Vector2(mxp + 2.0 + fw, myp + 2.0), Vector2(mxp + 2.0 + fw + 12.0, myp + mh - 2.0), Vector2(mxp + 14.0, myp + mh - 2.0)])
		var fc := Color(0.85, 0.85, 1.0)
		if usable:
			fc = Color(1.6, 1.4, 0.8).lerp(Color(2.2, 1.7, 0.7), pulse) if not full else Color(2.4, 1.6, 0.5).lerp(Color(2.6, 2.4, 1.4), pulse)
		c.draw_colored_polygon(fill_poly, fc)
	for q in [0.5]:
		var qx: float = mxp + 2.0 + (mw - 22.0) * q + 7.0
		c.draw_line(Vector2(qx, myp + 2.0), Vector2(qx, myp + mh - 2.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.9), 3.0)
	UiKit.poly_line(c, mframe, Color(2.0, 1.6, 0.8) if usable else Color(1.0, 0.95, 0.8), 2.5)
	if full:
		_flame(c, mxp + 16.0, myp + 1.0, mw - 40.0, 0.7 + 0.3 * pulse)
	c.draw_set_transform_matrix(base)
	# ring: HP number and player tag
	var rc := Vector2(cx, cy)
	c.draw_circle(rc, 36.0, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.9))
	c.draw_arc(rc, 36.0, 0.0, TAU, 40, col, 3.5, true)
	c.draw_arc(rc, 29.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.25), 2.0, true)
	UiKit.txt(c, UiKit.body(), Vector2(cx - 30, cy + 9), "%d" % int(ceil(f.hp)), 28, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	UiKit.txt(c, UiKit.head(), Vector2(cx - 30, cy - 12), "P%d" % (i + 1), 10, col, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
	if full:
		var bcx := 1280.0 - (mxp + mw * 0.5) if flip else mxp + mw * 0.5
		UiKit.txt(c, UiKit.head(), Vector2(bcx - 100.0, myp + 16.0), "SUPER READY", 12, Color(0.12, 0.04, 0.02), HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	# buffs under the meter
	var side := -1.0 if flip else 1.0
	var bx := 1280.0 - hx - 14.0 if flip else hx + 14.0
	var by := myp + mh + 18.0
	for b in f.buffs:
		var tx := bx - (46.0 if flip else 0.0)
		UiKit.txt(c, UiKit.body(), Vector2(tx, by), String(b).to_upper(), 13, UiKit.AMBER, HORIZONTAL_ALIGNMENT_LEFT, 46.0, 3)
		bx += 50.0 * side
	if f.shield_hits > 0:
		UiKit.txt(c, UiKit.body(), Vector2(bx - (80.0 if flip else 0.0), by), "SHIELD %d" % f.shield_hits, 13, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 3)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_moves:
		_paint_moves(c, f, i, 140.0)


func _paint_moves(c: Control, f: Fighter, i: int, gy: float) -> void:
	var col := UiKit.player_color(i)
	var w := 292.0
	var x0 := 24.0 if i == 0 else 1280.0 - 24.0 - w
	c.draw_rect(Rect2(x0 - 6, gy - 16, w + 12, 96), Color(0, 0, 0, 0.5))
	var heads := ["-", "UP", "SIDE", "DOWN"]
	var names := ["X", "Y", "B"]
	var sufs := ["", "_UP", "_SIDE", "_DOWN"]
	for ci in 4:
		UiKit.txt(c, UiKit.body(), Vector2(x0 + 18 + ci * 62.0, gy - 3), heads[ci], 11, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 62.0)
	for r in 3:
		UiKit.txt(c, UiKit.body(), Vector2(x0, gy + 15 + r * 23), names[r], 15, col)
		for ci in 4:
			var slot: String = names[r] + sufs[ci]
			var id: String = f.loadout.get(slot, "")
			var rect := Rect2(x0 + 18 + ci * 62.0, gy + r * 23 - 2, 60, 21)
			var active := f.attack != null and f.attack.active and f.attack.move.id.rstrip("0123456789") == id and id != ""
			c.draw_rect(rect, Color(col.r, col.g, col.b, 0.55) if active else Color(1, 1, 1, 0.07))
			if id != "":
				UiKit.txt(c, UiKit.body(), rect.position + Vector2(0, 15), MoveDB.get_move(id).short, 12, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			else:
				c.draw_rect(rect, Color(1, 1, 1, 0.1), false, 1.0)


# ------------------------------------------------------------------ shared: combo, lives, boss

func _paint_combo(c: Control) -> void:
	var n := Coop.combo
	if n >= 2:
		var tier := n / 5
		var age := _combo_age
		var spring := 1.0 + 0.26 * exp(-9.0 * age) * cos(24.0 * age)
		var base := 0.92 + 0.045 * minf(float(tier), 4.0)  # capped: the combo must not cover the screen
		var tilt: float = TILTS[tier % TILTS.size()] + 0.09 * exp(-6.0 * age) * sin(30.0 * age)
		var shake := Vector2.ZERO
		if age < 0.25:
			shake = Vector2(sin(_clock * 90.0), cos(_clock * 77.0)) * 5.0 * (1.0 - age / 0.25)
		var heat := clampf(float(tier) / 5.0, 0.0, 1.0)
		var glow_c := UiKit.GLOW_PINK.lerp(Color(2.4, 1.6, 0.6), heat)
		var plate_c := UiKit.PINK.lerp(Color(1.0, 0.72, 0.3), heat)
		var s := base * spring
		if n % 5 == 0 and age < 0.5:
			var rr := 50.0 + 150.0 * (age / 0.5)
			c.draw_arc(Vector2(640, 134), rr, 0.0, TAU, 48, Color(glow_c.r, glow_c.g, glow_c.b, 0.7 * (1.0 - age / 0.5)), 4.0, true)
		c.draw_set_transform_matrix(UiKit.italic(Vector2(640, 152) + shake, tilt, s, -0.28))
		var slash := PackedVector2Array([Vector2(-96, 12), Vector2(-74, -52), Vector2(96, -52), Vector2(74, 12)])
		var ga := 0.14 + 0.05 * float(tier) + 0.3 * exp(-6.0 * age)
		UiKit.glow_poly(c, slash, glow_c, ga)
		c.draw_colored_polygon(slash, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
		UiKit.poly_line(c, slash, plate_c, 2.5)
		var label := "x%d" % n
		for k in 3:
			UiKit.txt(c, UiKit.head(), Vector2(-100, 0), label, 64, Color(glow_c.r, glow_c.g, glow_c.b, ga * 0.7), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 8 + k * 8, Color(glow_c.r, glow_c.g, glow_c.b, ga * 0.4))
		var numc := Color(0.97, 0.97, 1.0).lerp(Color(2.2, 2.0, 1.4), heat * 0.7)
		UiKit.txt(c, UiKit.head(), Vector2(-100, 0), label, 64, numc, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 4, Color(0.05, 0.0, 0.1))
		var sub := "TEAM COMBO"
		if Coop.relay > 0:
			sub += "  ·  %d RELAYS" % Coop.relay
		UiKit.txt(c, UiKit.body(), Vector2(-100, 36), sub, 17, plate_c, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
		# who contributed + time left
		var total := float(maxi(Coop.hits_by[0] + Coop.hits_by[1], 1))
		var w1 := 160.0 * Coop.hits_by[0] / total
		c.draw_rect(Rect2(-80, 44, w1, 5), UiKit.P1)
		c.draw_rect(Rect2(-80 + w1, 44, 160.0 - w1, 5), UiKit.P2)
		c.draw_rect(Rect2(-80, 51, 160.0 * clampf(Coop.combo_t / 1.7, 0.0, 1.0), 2), Color(1, 1, 1, 0.7))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in _callouts.size():
		var co: Dictionary = _callouts[i]
		var age := float(co["age"])
		var col: Color = co["col"]
		var pop := 1.0 + 0.4 * exp(-12.0 * age) * cos(28.0 * age)
		var fade := clampf((CALLOUT_LIFE - age) / 0.4, 0.0, 1.0)
		var p := Vector2(640.0 + float(co["dx"]), 232.0 + float(i) * 38.0)
		c.draw_set_transform_matrix(UiKit.italic(p, float(co["tilt"]), pop, -0.22))
		UiKit.txt(c, UiKit.head(), Vector2(-200, 0), String(co["text"]), 32 - i * 3, Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0), fade), HORIZONTAL_ALIGNMENT_CENTER, 400.0, 5, Color(0.05, 0.0, 0.1, 0.9 * fade))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _combo_end_t > 0.0:
		UiKit.txt(c, UiKit.head(), Vector2(340, 250), _combo_end, 24, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, minf(1.0, _combo_end_t)), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 5, Color(0, 0, 0, 0.8))


func _paint_lives(c: Control) -> void:
	var n := Coop.revives_max
	var x0 := 640.0 - (n - 1) * 17.0
	for h in n:
		UiKit.heart(c, Vector2(x0 + h * 34.0, 46), 13.0, h < Coop.revives_left)


func _paint_boss(c: Control) -> void:
	for b in get_tree().get_nodes_in_group("boss"):
		if b is Enemy and is_instance_valid(b):
			var e := b as Enemy
			var r := Rect2(390, 676, 500, 22)
			c.draw_colored_polygon(UiKit.chamfer(r, 8.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
			var fr := Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6.0) * clampf(e.hp / e.max_hp, 0.0, 1.0), r.size.y - 6.0))
			c.draw_rect(fr, Color(1.0, 0.25, 0.25))
			UiKit.poly_line(c, UiKit.chamfer(r, 8.0), Color(1.0, 0.45, 0.45), 2.5)
			UiKit.txt(c, UiKit.head(), Vector2(390, 666), String(e.def["name"]).to_upper(), 14, Color(1, 0.7, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)


func _paint_game_over(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	c.draw_set_transform_matrix(UiKit.italic(Vector2(640, 300), -0.03))
	var col := Color(1.0, 0.4, 0.4)
	for g in 3:
		UiKit.txt(c, UiKit.head(), Vector2(-400, 0), _result, 72, Color(col.r, col.g, col.b, 0.14), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 8 + g * 8, Color(col.r, col.g, col.b, 0.07))
	UiKit.txt(c, UiKit.head(), Vector2(-400, 0), _result, 72, col, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 6, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	UiKit.txt(c, UiKit.body(), Vector2(240, 360), "Best combo %d" % maxi(Coop.best_combo, RunState.best_combo), 26, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 4)
	var prompt := "A  MAIN MENU   (RUN OVER)" if RunState.active else "A  TRY AGAIN      B  MAIN MENU"
	UiKit.txt(c, UiKit.head(), Vector2(240, 430), prompt, 20, Color(1, 1, 1, 0.5 + 0.5 * sin(_result_t * 5.0)), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 4)
