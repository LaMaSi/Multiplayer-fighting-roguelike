extends Node
## Vertical-play feedback: jump arc (higher than it is long), analog walk -> run, jump squat and turn-around for players
## and enemies, ledge grab off by default, X = weapon / Y = adaptive / B = default moves with 3 starting moves, empowered
## hits give no meter, no reward picks after the final boss.
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_vertical_feel.tscn

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("  PASS  " if cond else "  FAIL  "), msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_test_moves()
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	var f: Fighter = Coop.fighters[0]
	var o: Fighter = Coop.fighters[1]
	o.global_position = Vector2(2600, lv.ground_y - 1.0)
	await _test_walk(f, lv)
	await _test_jump(f, lv)
	await _test_turn(f, lv)
	await _test_enemy(lv)
	await _test_meter(f, lv)
	check(not Fighter.ledge_grab, "the ledge grab is off by default")
	_test_boss_reward()
	print("RESULT: %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_moves() -> void:
	print("[moves on buttons]")
	var rng := RandomNumberGenerator.new()
	var bad := 0
	for cid in ClassData.IDS:
		for s in 40:
			rng.seed = s
			var lo := ClassData.roll_loadout(cid, rng)
			if lo.size() != 3 or not (lo.has("X") and lo.has("Y") and lo.has("B")):
				bad += 1
				continue
			if ClassData.tier_of(String(lo["X"])) != "weapon" or ClassData.tier_of(String(lo["Y"])) != "adaptive" or ClassData.tier_of(String(lo["B"])) != "universal":
				bad += 1
	check(bad == 0, "every starting loadout has 3 moves: weapon on X, adaptive on Y, default on B (%d bad)" % bad)
	var kicks := ["sweep", "spin_kick", "dive_kick", "bicycle_kick", "slide_strike", "stomp"]
	var k_ok := true
	for id in kicks:
		k_ok = k_ok and ClassData.tier_of(id) == "universal" and MoveDB.get_move(id).tier == "universal"
	check(k_ok, "every kick is a default (B) move")
	check(ClassData.tier_of("off_hand_jab") == "adaptive" and MoveDB.get_move("off_hand_jab").tier == "adaptive", "the off-hand jab is an adaptive (Y) move")
	check(MoveDB.get_move_for("off_hand_jab", "sword").hits[0]["box"] != MoveDB.get_move("off_hand_jab").hits[0]["box"], "the off-hand jab takes the sword's reach")
	check(SlotPicker.row_for("long_slash", "sword") == 0 and SlotPicker.row_for("uppercut", "sword") == 1 and SlotPicker.row_for("sweep", "sword") == 2,
		"new moves go on X (weapon), Y (adaptive), B (default)")
	var spin := MoveDB.get_move("spin_kick")
	var launches := false
	for h in spin.hits:
		launches = launches or String(h.get("kind", "")) == "launch"
	check(launches, "kicks moved to B keep their launch (not softened like the old off-hand moves)")


func _test_walk(f: Fighter, lv: LevelBase) -> void:
	print("[analog walk -> run]")
	var speeds: Array[float] = []
	for tilt in [0.3, 0.5, 0.7, 0.85, 1.0]:
		f.global_position = Vector2(300, lv.ground_y - 1.0)
		f.velocity = Vector2.ZERO
		f.input.script_set(Vector2(tilt, 0))
		await frames(30)
		speeds.append(f.velocity.x)
	f.input.script_set(Vector2.ZERO)
	await frames(10)
	var rising := true
	for i in range(1, speeds.size()):
		rising = rising and speeds[i] > speeds[i - 1] + 30.0
	check(rising, "speed grows steadily with the stick tilt: %s" % str(speeds.map(func(v): return int(v))))
	check(speeds[3] < speeds[4] * 0.9, "the full run needs the stick pushed all the way (85%%: %.0f, 100%%: %.0f)" % [speeds[3], speeds[4]])
	check(speeds[0] < speeds[4] * 0.3, "a light tilt is a slow walk")


func _test_jump(f: Fighter, lv: LevelBase) -> void:
	print("[jump]")
	f.global_position = Vector2(300, lv.ground_y - 1.0)
	f.velocity = Vector2.ZERO
	f.input.script_set(Vector2(1, 0))
	await frames(20)  # (short run-up: the jump lands on the flat part of the training room)
	var x0 := f.global_position.x
	var y0 := f.global_position.y
	f.input.script_set(Vector2(1, 0), [PlayerInput.Btn.JUMP])
	await frames(1)
	var squat := f.state == "squat" and f.is_on_floor()
	await frames(1)
	check(squat and f.is_on_floor(), "the jump starts with a short squat on the ground")
	var top := y0
	var left_at := -1
	var take_x := f.global_position.x
	var land_x := take_x
	for i in 80:
		await frames(1)
		if left_at < 0 and not f.is_on_floor():
			left_at = i
			take_x = f.global_position.x
		top = minf(top, f.global_position.y)
		if left_at >= 0 and f.is_on_floor():
			land_x = f.global_position.x
			break
	f.input.script_set(Vector2.ZERO)
	var h := y0 - top
	var d := land_x - take_x
	print("  info  x0 %.0f take-off %.0f landing %.0f" % [x0, take_x, land_x])
	check(left_at >= 0 and left_at <= 2, "it leaves the ground about 3 frames after the press (+%d)" % left_at)
	check(h > 200.0 and h < 235.0, "a full jump rises about 215 px (%.0f)" % h)
	check(d < h * 1.2, "a running jump goes about as far across as it goes up (%.0f across, %.0f up)" % [d, h])
	await frames(10)


func _test_turn(f: Fighter, lv: LevelBase) -> void:
	print("[turn around]")
	f.global_position = Vector2(600, lv.ground_y - 1.0)
	f.velocity = Vector2.ZERO
	f.facing = 1
	await frames(10)
	f.input.script_set(Vector2(-1, 0))
	var narrow := false
	for i in 14:
		await frames(1)
		if f.facing == -1 and absf(f.figure.scale.x) < 0.9 * absf(f.figure.scale.y) / maxf(f.squash.y, 0.01) * maxf(f.squash.x, 0.01):
			narrow = true
	f.input.script_set(Vector2.ZERO)
	await frames(10)
	check(narrow, "turning around is animated (the body narrows through the turn)")
	check(f.figure.scale.x < 0.0, "and ends facing the new way")


func _test_enemy(lv: LevelBase) -> void:
	print("[enemy jump squat]")
	var e: Enemy = lv.spawn_enemy("thug", Vector2(1500, lv.ground_y - 1.0))
	await frames(20)
	e._jump(1.0, 300.0, 900.0)
	await frames(1)
	var squat := e.state == "squat" and e.is_on_floor()
	await frames(4)
	check(squat, "an enemy crouches before it jumps")
	check(not e.is_on_floor() and e.velocity.y < 0.0, "and then takes off")
	e.queue_free()
	await frames(2)


func _test_meter(f: Fighter, lv: LevelBase) -> void:
	print("[empowered hits give no meter]")
	var e: Enemy = lv.spawn_enemy("brute", Vector2(800, lv.ground_y - 1.0))
	await frames(30)
	e.invuln = 0.0
	f.meter = 50.0
	var info := HitInfo.new()
	info.attacker = f
	info.dmg = 20.0
	info.empowered = true
	Coop.post_hit(info, e, 20.0)
	check(is_equal_approx(f.meter, 50.0), "an empowered hit adds no meter (%.1f)" % f.meter)
	info.empowered = false
	Coop.post_hit(info, e, 20.0)
	check(f.meter > 50.0, "a normal hit still does (%.1f)" % f.meter)
	e.queue_free()


func _test_boss_reward() -> void:
	print("[after the final boss]")
	RunState.start_run(3)
	RunState.current = {"type": "boss", "seed": 1, "layer": 5, "idx": 0, "next": [], "done": false}
	RunState.bonus_picks.append({"player": 0, "kind": "move"})
	RunState.level_cleared()
	check(RunState.queue.is_empty() and RunState.finished, "no reward picks after the final boss")
	RunState.end_run()
