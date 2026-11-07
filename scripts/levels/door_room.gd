class_name DoorRoom
extends Node2D
## The single-screen room behind a door, built inside the level far to the right of the level end so the level
## state (enemies, props, progress) is kept. Kinds: "challenge" (tough waves, then a reward) and "shop"
## (pedestals selling move / power-up picks and a heal).

const ROOM_W := 1500.0

var level: LevelBase
var kind := "challenge"
var x0 := 0.0
var cleared := false
var exit_x := 0.0
var _wave := 0
var _t := 0.0
var _hp_before := 1.0
var _items: Array = []  # {x, label, price, kind, sold}
var _msg := ""


func setup(lv: LevelBase, k: String) -> DoorRoom:
	level = lv
	kind = k
	x0 = lv.level_w + 1800.0
	exit_x = x0 + ROOM_W - 150.0
	return self


func gy() -> float:
	return level.ground_y


func enter() -> void:
	z_index = -2
	level.add_child(self)
	level._make_body(Rect2(x0 - 300.0, gy(), ROOM_W + 600.0, 400.0), 1)
	level._make_body(Rect2(x0 - 100.0, -1500.0, 100.0, 3000.0), 1)
	level._make_body(Rect2(x0 + ROOM_W, -1500.0, 100.0, 3000.0), 1)
	level.cam.set_bounds(x0, x0 + ROOM_W)
	Coop.bounds = Rect2(x0, -1200.0, ROOM_W, 2400.0)
	var i := 0
	for f in level.fighters:
		f.global_position = Vector2(x0 + 160.0 + i * 70.0, gy() - 1.0)
		f.velocity = Vector2.ZERO
		f.last_safe = f.global_position
		i += 1
	level.cam.snap()
	_hp_before = Coop.enemy_hp_mult
	if kind == "challenge":
		Coop.enemy_hp_mult = level.enemy_hp_mult * 1.3
		level.hud.banner("CHALLENGE!", Color(2.2, 0.5, 0.4))
		Sfx.play("boom", 1.1)
		_spawn_wave()
	else:
		level.hud.banner("MOVE SHOP", Color(2.0, 1.6, 0.5))
		_items = [
			{"x": x0 + 480.0, "label": "MOVE PICK", "price": 50, "kind": "move", "sold": false},
			{"x": x0 + 760.0, "label": "POWER-UP PICK", "price": 35, "kind": "level", "sold": false},
			{"x": x0 + 1040.0, "label": "HEAL BOTH", "price": 25, "kind": "heal", "sold": false},
		]
		cleared = true
	queue_redraw()


func _spawn_wave() -> void:
	var table: Array = [["heavy", "brute"], ["brute", "brute", "heavy"]]
	var kinds: Array = table[mini(_wave, table.size() - 1)]
	var n := 0
	for k in kinds:
		level.spawn_enemy(String(k), Vector2(x0 + ROOM_W - 140.0 - n * 90.0, gy() - 1.0))
		n += 1
	_wave += 1


func _process(_delta: float) -> void:
	_t += _delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if level == null or not level.in_room:
		return
	if kind == "challenge" and not cleared:
		if level.alive_enemies() == 0:
			if _wave < 2:
				_spawn_wave()
			else:
				_finish_challenge()
	for f in level.fighters:
		if not f.is_alive() or f.state == "downed":
			continue
		if f.input.pressed(PlayerInput.Btn.INTERACT):
			if cleared and absf(f.global_position.x - exit_x) < 90.0:
				level.leave_room()
				return
			if kind == "shop":
				_try_buy(f)


func _finish_challenge() -> void:
	cleared = true
	var depth := RunState.levels_cleared if RunState.active else 0
	var coins := 60 + 25 * depth
	_msg = "+%d COINS" % coins
	if RunState.active:
		RunState.coins += coins
		if randf() < 0.4:
			for p in 2:
				RunState.bonus_picks.append({"player": p, "kind": "move"})
			_msg += "  +  A MOVE TO CHOOSE (end of level)"
	level.hud.banner("CLEARED!", Color(2.0, 1.8, 0.6))
	Sfx.play("relay")
	Coop.say(_msg, Color(2.0, 1.7, 0.4), Vector2(x0 + ROOM_W * 0.5, gy() - 220.0))


func _try_buy(f: Fighter) -> void:
	for it in _items:
		if bool(it["sold"]) or absf(f.global_position.x - float(it["x"])) > 70.0:
			continue
		if RunState.coins < int(it["price"]):
			Coop.say("NOT ENOUGH COINS", Color(2.0, 0.5, 0.4), Vector2(float(it["x"]), gy() - 200.0))
			return
		RunState.coins -= int(it["price"])
		it["sold"] = true
		match String(it["kind"]):
			"heal":
				for g in level.fighters:
					g.hp = g.max_hp
			_:
				RunState.bonus_picks.append({"player": f.player_index, "kind": String(it["kind"])})
		Sfx.play("pickup")
		Coop.say("BOUGHT: %s" % String(it["label"]), Color(2.0, 1.7, 0.4), Vector2(float(it["x"]), gy() - 200.0))
		return


func leave() -> void:
	Coop.enemy_hp_mult = _hp_before
	queue_free()


func _draw() -> void:
	var g := gy()
	var col := Color(1.0, 0.2, 0.25) if kind == "challenge" else Pal.interact()
	draw_rect(Rect2(x0 - 600.0, -900.0, ROOM_W + 1200.0, g + 900.0), Color(0.03, 0.015, 0.06))
	for i in 12:
		var px := x0 + 60.0 + i * 125.0
		draw_line(Vector2(px, g), Vector2(px, g - 520.0), Color(col.r, col.g, col.b, 0.10), 2.0)
	draw_rect(Rect2(x0 - 300.0, g, ROOM_W + 600.0, 400.0), Color(0.05, 0.03, 0.10))
	draw_line(Vector2(x0 - 300.0, g), Vector2(x0 + ROOM_W + 300.0, g), col, 3.0, true)
	draw_line(Vector2(x0, g - 900.0), Vector2(x0, g), col, 3.0)
	draw_line(Vector2(x0 + ROOM_W, g - 900.0), Vector2(x0 + ROOM_W, g), col, 3.0)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(x0, g - 380.0), "CHALLENGE ROOM" if kind == "challenge" else "MOVE SHOP", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 44, col)
	if kind == "challenge" and not cleared:
		draw_string(f, Vector2(x0, g - 330.0), "Defeat them all (wave %d of 2)" % mini(_wave, 2), HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 22, Color(1, 1, 1, 0.8))
	var ec := col if cleared else Color(col.r * 0.3, col.g * 0.3, col.b * 0.3)
	draw_rect(Rect2(exit_x - 46.0, g - 150.0, 92.0, 150.0), Color(ec.r * 0.1, ec.g * 0.1, ec.b * 0.1), true)
	draw_rect(Rect2(exit_x - 46.0, g - 150.0, 92.0, 150.0), ec, false, 4.0)
	draw_string(f, Vector2(exit_x - 60.0, g - 160.0), "EXIT" if cleared else "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, ec)
	for it in _items:
		var sold: bool = it["sold"]
		var ic := Color(0.4, 0.4, 0.4) if sold else Pal.interact()
		var px2: float = it["x"]
		draw_rect(Rect2(px2 - 50.0, g - 40.0, 100.0, 40.0), Color(0.1, 0.07, 0.02))
		draw_rect(Rect2(px2 - 50.0, g - 40.0, 100.0, 40.0), ic, false, 3.0)
		draw_string(f, Vector2(px2 - 90.0, g - 90.0), String(it["label"]), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 22, ic)
		draw_string(f, Vector2(px2 - 90.0, g - 56.0), "SOLD" if sold else "%d COINS" % int(it["price"]), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 22, ic)
		if not sold:
			draw_string(f, Vector2(px2 - 90.0, g - 8.0), "RB: BUY", HORIZONTAL_ALIGNMENT_CENTER, 180.0, 16, Color(1, 1, 1, 0.7))
