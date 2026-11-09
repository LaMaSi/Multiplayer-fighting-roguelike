class_name DoorRoom
extends Node2D
## The single-screen room behind a door, built inside the level far to the right of the level end so the level
## state (enemies, props, progress) is kept. Kinds: "challenge" (tough waves, then coins and sometimes a move to pick
## RIGHT AWAY) and "shop" (pedestals with real moves: a bought move asks at once which button it goes on).
## The coins are shown at the top of the screen.

const ROOM_W := 1500.0

var level: LevelBase
var kind := "challenge"
var x0 := 0.0
var cleared := false
var exit_x := 0.0
var pick_move := false  ## the challenge reward includes a move choice (decided by the door)
var _wave := 0
var _t := 0.0
var _hp_before := 1.0
var _items: Array = []  # {x, kind, id, class, label, price, sold_by[2], sold}
var _msg := ""
var _pickers: Array[SlotPicker] = [SlotPicker.new(), SlotPicker.new()]
var _ui_layer: CanvasLayer = null
var _ui: Ui = null  ## the screen overlay (coins, messages and the button picker): it must be redrawn every frame
var _reward_layer: CanvasLayer = null
var _flash := ""
var _flash_t := 0.0


class Ui extends Control:
	var room: DoorRoom

	func _draw() -> void:
		if room != null:
			room.paint_ui(self)


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
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps running while a button / reward pick pauses the fighters
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
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 12
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var ui := Ui.new()
	ui.room = self
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(ui)
	_ui = ui
	add_child(_ui_layer)
	_hp_before = Coop.enemy_hp_mult
	if kind == "challenge":
		Coop.enemy_hp_mult = level.enemy_hp_mult * 1.3
		level.hud.banner("CHALLENGE!", Color(2.2, 0.5, 0.4))
		Sfx.play("boom", 1.1)
		_spawn_wave()
	else:
		level.hud.banner("MOVE SHOP", Color(2.0, 1.6, 0.5))
		_build_items()
		cleared = true
	queue_redraw()


func _build_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var taken: Array = []
	var picks: Array = []
	# one off-hand or adaptive move both players can buy, then a weapon move for each class in play
	var shared_pool: Array = []
	for id in ClassData.X_POOL + ClassData.Y_POOL:
		var owned_both := true
		for p in 2:
			if not (id in (RunState.loadouts[p] as Dictionary).values()):
				owned_both = false
		if not owned_both:
			shared_pool.append(id)
	if not shared_pool.is_empty():
		var sid: String = shared_pool[rng.randi() % shared_pool.size()]
		taken.append(sid)
		picks.append({"id": sid, "class": "", "price": 90})
	for p in 2:
		var cid: String = RunState.classes[p]
		if cid == "":
			continue
		var bp: Array = []
		for id in (ClassData.get_class_data(cid)["b_pool"] as Array):
			if not (id in (RunState.loadouts[p] as Dictionary).values()) and not (id in taken):
				bp.append(id)
		if not bp.is_empty():
			var bid: String = bp[rng.randi() % bp.size()]
			taken.append(bid)
			picks.append({"id": bid, "class": cid, "price": 110})
	var n := picks.size() + 1
	for i in picks.size():
		var d: Dictionary = picks[i]
		var m := MoveDB.get_move(String(d["id"]))
		_items.append({"x": x0 + ROOM_W * float(i + 1) / float(n + 1), "kind": "move", "id": d["id"], "class": d["class"], "label": m.name.to_upper(),
			"price": d["price"], "sold_by": [false, false], "sold": false})
	_items.append({"x": x0 + ROOM_W * float(n) / float(n + 1), "kind": "heal", "id": "", "class": "", "label": "HEAL BOTH", "price": 25, "sold_by": [false, false], "sold": false})


func _spawn_wave() -> void:
	var table: Array = [["heavy", "brute"], ["brute", "brute", "heavy"]]
	var kinds: Array = table[mini(_wave, table.size() - 1)]
	var n := 0
	for k in kinds:
		level.spawn_enemy(String(k), Vector2(x0 + ROOM_W - 140.0 - n * 90.0, gy() - 1.0))
		n += 1
	_wave += 1


func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	queue_redraw()
	if _ui != null:
		_ui.queue_redraw()  # the overlay shows the coins and the button picker; nothing else asks it to redraw


func _physics_process(_delta: float) -> void:
	if level == null or not level.in_room:
		return
	for p in 2:
		if _pickers[p].active:
			_pickers[p].update(Inp.players[p])
	if kind == "challenge" and not cleared:
		if level.alive_enemies() == 0:
			if _wave < 2:
				_spawn_wave()
			else:
				_finish_challenge()
	if _reward_layer == null and not _pickers[0].active and not _pickers[1].active and level.get_tree().paused:
		level.get_tree().paused = false
	for f in level.fighters:
		if not f.is_alive() or f.state == "downed" or _pickers[f.player_index].active or _reward_layer != null:
			continue
		if f.input.pressed(PlayerInput.Btn.INTERACT):
			if cleared and absf(f.global_position.x - exit_x) < 90.0:
				level.leave_room()
				return
			if kind == "shop":
				_try_buy(f)


## Coins paid by a challenge room at the current depth (the door shows this amount).
static func challenge_coins() -> int:
	return 60 + 25 * (RunState.levels_cleared if RunState.active else 0)


func _finish_challenge() -> void:
	cleared = true
	var coins := challenge_coins()
	_msg = "+%d COINS" % coins
	var pick := false
	if RunState.active:
		RunState.coins += coins
		pick = pick_move
		if pick:
			_msg += "  +  CHOOSE A MOVE"
	level.hud.banner("CLEARED!", Color(2.0, 1.8, 0.6))
	Sfx.play("relay")
	Coop.say(_msg, Color(2.0, 1.7, 0.4), Vector2(x0 + ROOM_W * 0.5, gy() - 220.0))
	if pick:
		_open_reward()


## The move choice happens right now, in the room: both players pick from the same cards.
func _open_reward() -> void:
	var rs := RewardScreen.new()
	rs.overlay = true
	_reward_layer = CanvasLayer.new()
	_reward_layer.layer = 30
	_reward_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_reward_layer)
	_reward_layer.add_child(rs)
	rs.finished.connect(func() -> void:
		if _reward_layer != null:
			_reward_layer.queue_free()
			_reward_layer = null
		level.get_tree().paused = false)
	level.get_tree().paused = true


func _say(t: String) -> void:
	_flash = t
	_flash_t = 1.8


func _try_buy(f: Fighter) -> void:
	var p := f.player_index
	for it in _items:
		if absf(f.global_position.x - float(it["x"])) > 70.0:
			continue
		if String(it["kind"]) == "move":
			if String(it["class"]) != "" and String(it["class"]) != String(RunState.classes[p]):
				_say("ONLY FOR %s" % String(it["class"]).to_upper())
				Sfx.play("ui", 0.7)
				return
			if bool((it["sold_by"] as Array)[p]) or String(it["id"]) in (RunState.loadouts[p] as Dictionary).values():
				_say("YOU ALREADY HAVE IT")
				return
		elif bool(it["sold"]):
			return
		if RunState.coins < int(it["price"]):
			_say("NOT ENOUGH COINS")
			Sfx.play("ui", 0.7)
			return
		var price := int(it["price"])
		RunState.coins -= price
		if String(it["kind"]) == "heal":
			it["sold"] = true
			for g in level.fighters:
				g.hp = g.max_hp
			Sfx.play("pickup")
			return
		(it["sold_by"] as Array)[p] = true
		Sfx.play("pickup")
		_pickers[p].start(p, String(it["id"]), func(slot: String) -> void:
			if slot == "":
				RunState.coins += price  # cancelled: money back
				(it["sold_by"] as Array)[p] = false
				return
			(RunState.loadouts[p] as Dictionary)[slot] = it["id"]
			f.loadout[slot] = it["id"]  # usable right now, in this level
			Sfx.play("pickup"))
		level.get_tree().paused = true
		return


func leave() -> void:
	Coop.enemy_hp_mult = _hp_before
	level.get_tree().paused = false
	queue_free()


# ------------------------------------------------------------------ screen overlay (coins, button picker)

func paint_ui(c: Control) -> void:
	var head := UiKit.head()
	UiKit.panel(c, Rect2(500, 10, 280, 56), 12.0, UiKit.AMBER, 3.0, 0.85)
	UiKit.coin(c, Vector2(534, 38), 14.0)
	UiKit.txt(c, UiKit.body(), Vector2(558, 30), "COINS", 13, UiKit.DIM_TEXT)
	UiKit.txt(c, head, Vector2(558, 58), str(RunState.coins), 28, UiKit.AMBER)
	if _flash_t > 0.0:
		UiKit.txt(c, UiKit.body(), Vector2(0, 100), _flash, 24, Color(1.0, 0.75, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 1280.0)
	for p in 2:
		if _pickers[p].active:
			_pickers[p].paint(c, Rect2(40.0 + p * 630.0, 440.0, 600.0, 252.0), UiKit.player_color(p))


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
	draw_string(f, Vector2(x0, g - 420.0), "CHALLENGE ROOM" if kind == "challenge" else "MOVE SHOP", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 44, col)
	if kind == "challenge" and not cleared:
		draw_string(f, Vector2(x0, g - 372.0), "Defeat them all (wave %d of 2)" % mini(_wave, 2), HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 22, Color(1, 1, 1, 0.8))
	if kind == "shop":
		draw_string(f, Vector2(x0, g - 372.0), "Stand at a pedestal and press RB to buy. Each player buys for themselves; the move goes on a button right away.", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 17, Color(1, 1, 1, 0.75))
	var ec := col if cleared else Color(col.r * 0.3, col.g * 0.3, col.b * 0.3)
	draw_rect(Rect2(exit_x - 46.0, g - 150.0, 92.0, 150.0), Color(ec.r * 0.1, ec.g * 0.1, ec.b * 0.1), true)
	draw_rect(Rect2(exit_x - 46.0, g - 150.0, 92.0, 150.0), ec, false, 4.0)
	draw_string(f, Vector2(exit_x - 60.0, g - 160.0), "EXIT" if cleared else "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, ec)
	for it in _items:
		var px2: float = it["x"]
		var is_move := String(it["kind"]) == "move"
		var all_sold := bool(it["sold"])
		if is_move:
			all_sold = true
			for p in 2:
				if (String(it["class"]) == "" or String(it["class"]) == String(RunState.classes[p])) and not bool((it["sold_by"] as Array)[p]):
					all_sold = false
		var ic := Color(0.4, 0.4, 0.4) if all_sold else Pal.interact()
		if is_move:
			var pv := 0
			if String(it["class"]) != "" and String(RunState.classes[1]) == String(it["class"]) and String(RunState.classes[0]) != String(it["class"]):
				pv = 1
			MovePreview.draw(self, String(it["id"]), String(RunState.classes[pv]), pv, Rect2(px2 - 80.0, g - 230.0, 160.0, 112.0))
		draw_rect(Rect2(px2 - 55.0, g - 40.0, 110.0, 40.0), Color(0.1, 0.07, 0.02))
		draw_rect(Rect2(px2 - 55.0, g - 40.0, 110.0, 40.0), ic, false, 3.0)
		draw_string(f, Vector2(px2 - 100.0, g - 92.0), String(it["label"]), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 20, ic)
		var sub := "FOR BOTH" if (is_move and String(it["class"]) == "") else (String(it["class"]).to_upper() + " ONLY" if is_move else "")
		if sub != "":
			draw_string(f, Vector2(px2 - 100.0, g - 72.0), sub, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 13, Color(1, 1, 1, 0.6))
		draw_string(f, Vector2(px2 - 100.0, g - 52.0), "SOLD" if all_sold else "%d COINS" % int(it["price"]), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 18, ic)
		if not all_sold:
			draw_string(f, Vector2(px2 - 90.0, g - 8.0), "RB: BUY", HORIZONTAL_ALIGNMENT_CENTER, 180.0, 14, Color(1, 1, 1, 0.7))
