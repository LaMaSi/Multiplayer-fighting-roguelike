extends Node
## Skyscraper (vertical level set): generated towers are climbable, battles lock the screen and drip enemies in,
## falls and ring-outs, side gates into shop / challenge screens, the goal at the top, the boss tower.
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_skyscraper.tscn

var fails := 0
var level: SkyscraperLevel


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _gen(type: String, seed_v: int, depth: int) -> SkyscraperLevel:
	var lv := SkyscraperLevel.new()
	lv._generated({"type": type, "seed": seed_v}, depth)
	return lv


## Height of the highest surface reachable from the street (the level's own reach rules, over every surface).
func _highest(lv: SkyscraperLevel) -> float:
	var s: Array = lv.surfs
	var seen := {0: true}
	var todo: Array = [0]
	var best: float = lv.ground_y
	while not todo.is_empty():
		var i: int = todo.pop_back()
		best = minf(best, float(s[i]["y"]))
		for j in s.size():
			if not seen.has(j) and SkyscraperLevel.reach(s[i], s[j]):
				seen[j] = true
				todo.append(j)
	return best


## Static surfaces (and moving platforms' travel) that overlap, sit squeezed under each other, or sit side by side too close.
func _clashes(lv: SkyscraperLevel) -> int:
	var n := 0
	var boxes: Array = []
	for s in lv.surfs:
		boxes.append(s["box"])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Rect2 = boxes[i]
			var b: Rect2 = boxes[j]
			var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			if ox <= 4.0:
				continue
			var top := a if a.position.y < b.position.y else b
			var bot := b if top == a else a
			var room := bot.position.y - top.end.y
			if room < 90.0 and room > -bot.size.y - top.size.y:
				# battle floors are built from pieces at one height that touch: not a clash
				if absf(a.position.y - b.position.y) < 1.0 and ox <= 4.0:
					continue
				n += 1
	return n


## Platforms that leave a narrow slot to a side wall (they must touch the wall or keep WALL_CLEAR).
func _wall_slots(lv: SkyscraperLevel) -> int:
	var n := 0
	for r: Rect2 in lv.platforms + lv.solids:
		var lg := r.position.x - SkyscraperLevel.PL
		var rg := SkyscraperLevel.PR - r.end.x
		if (lg > 0.5 and lg < SkyscraperLevel.WALL_CLEAR - 1.0) or (rg > 0.5 and rg < SkyscraperLevel.WALL_CLEAR - 1.0):
			n += 1
	return n


func _test_generation() -> void:
	print("[generation]")
	var unreachable := 0
	var squeezed := 0
	var slots := 0
	var per_row := 0.0
	var n_rows := 0
	var bad_gate := 0
	var bad_enc := 0
	var gate_kinds := {}
	var floor_types := {}
	var row_kinds := {}
	var total := 0
	for type in ["fight", "elite", "treasure", "boss"]:
		for s in range(1, 81):
			var lv := _gen(type, s, s % 5)
			total += 1
			var target: float = lv.goal.position.y if lv.goal.size.x > 0.0 else float(lv.encounters[lv.encounters.size() - 1]["y"])
			if _highest(lv) > target + 1.0:
				unreachable += 1
				if unreachable <= 3:
					print("  info  not climbable: %s seed %d" % [type, s])
			squeezed += _clashes(lv)
			slots += _wall_slots(lv)
			for rw in lv.rows:
				if not String(rw["kind"]).begins_with("floor_"):
					per_row += float((rw["rects"] as Array).size())
					n_rows += 1
			for g in lv.gates:
				gate_kinds[g["kind"]] = true
				var enc: Dictionary = lv.encounters[int(g["floor"])]
				if String(enc["type"]) == "block" or absf(float(g["y"]) - float(enc["y"])) > 0.1:
					bad_gate += 1
			for e in lv.encounters:
				floor_types[e["type"]] = true
				var q: Array = e["queue"]
				if q.is_empty() or int(e["start"]) < 1 or int(e["start"]) > 2 or float(e["interval"]) < 3.5:
					bad_enc += 1
			for i in range(1, lv.encounters.size()):
				if float(lv.encounters[i]["interval"]) > float(lv.encounters[i - 1]["interval"]):
					bad_enc += 1  # higher floors must not be slower
			for rw in lv.rows:
				row_kinds[rw["kind"]] = true
			if type == "boss" and (lv.goal.size.x > 0.0 or lv.encounters.size() != 1 or (lv.encounters[0]["queue"] as Array) != ["boss_street"]):
				bad_enc += 1
			if (type == "fight" and lv.encounters.size() != 2) or (type == "elite" and lv.encounters.size() != 3) or (type == "treasure" and lv.encounters.size() != 0):
				bad_enc += 1
			if (type == "fight" or type == "elite") and lv.gates.is_empty():
				bad_gate += 1
			lv.free()
	check(unreachable == 0, "every generated tower can be climbed to its goal / boss floor (%d of %d fail)" % [unreachable, total])
	check(squeezed == 0, "no platforms overlap or sit squeezed on top of each other (%d)" % squeezed)
	check(slots == 0, "no platform leaves a narrow slot to a side wall (%d)" % slots)
	check(per_row / maxf(n_rows, 1.0) <= 1.6, "the climb is sparse: %.2f platforms per row" % (per_row / maxf(n_rows, 1.0)))
	check(bad_gate == 0, "every fight / elite tower has a side gate, on a floor that reaches the wall (%d bad)" % bad_gate)
	check(bad_enc == 0, "battles: 1-2 enemies to start, a queue, faster higher up, boss tower has only the boss (%d bad)" % bad_enc)
	check(gate_kinds.size() == 2, "both shop and challenge gates occur")
	check(floor_types.size() == 4, "all four battle floor layouts occur: %s" % str(floor_types.keys()))
	check(row_kinds.has("block") and row_kinds.has("lift") and row_kinds.has("mover") and row_kinds.has("full") and row_kinds.has("step"),
		"climbs mix one-way platforms, solid blocks, lifts and movers")


func _load(type: String, seed_v: int) -> void:
	if level != null:
		level.queue_free()
		await frames(3)
	RunState.start_run(11)
	RunState.biome = "skyscraper"
	RunState.coins = 300
	RunState.current = {"type": type, "seed": seed_v, "layer": 0, "idx": 0, "next": [], "done": false}
	level = load(RunState.level_scene()).instantiate()
	add_child(level)
	await frames(10)
	var inp := get_node("/root/Inp")
	inp.players[0].script_set(Vector2.ZERO)
	inp.players[1].script_set(Vector2.ZERO)


func _kill_all() -> void:
	for e in level._enemies:
		if is_instance_valid(e):
			e.queue_free()


## Step onto battle floor `i` and wait for the lock.
func _start_floor(i: int) -> void:
	var enc: Dictionary = level.encounters[i]
	level.fighters[0].global_position = (enc["safe"] as Vector2) + Vector2(0, -1)
	level.fighters[0].velocity = Vector2.ZERO
	await frames(12)


func _clear_floor() -> void:
	var guard := 0
	while level._locked and guard < 400:
		guard += 1
		_kill_all()
		await frames(10)


func _seed_with_gate(kind: String, floor_idx: int) -> int:
	for s in range(1, 400):
		var lv := _gen("fight", s, 0)
		var ok := false
		for g in lv.gates:
			if String(g["kind"]) == kind and int(g["floor"]) == floor_idx:
				ok = true
		lv.free()
		if ok:
			return s
	return -1


func _gate_of(kind: String) -> Dictionary:
	for g in level.gates:
		if String(g["kind"]) == kind:
			return g
	return {}


func _test_battle() -> void:
	print("[battle lock, drip spawns, falls]")
	var sd := _seed_with_gate("shop", 0)
	await _load("fight", sd)
	var f0: Fighter = level.fighters[0]
	var f1: Fighter = level.fighters[1]
	check(absf(level.cam.zoom.x - 1280.0 / SkyscraperLevel.W) < 0.02, "the camera is fixed to the level width")
	check(absf(f0.global_position.x - f1.global_position.x) >= 400.0, "the players start well apart")
	check(level.hud.go_text == "GO UP", "the HUD points up")
	var enc: Dictionary = level.encounters[0]
	var f_y: float = enc["y"]
	var gate := _gate_of("shop")
	check(gate["body"] != null and not bool(gate["open"]), "the side gate is shut before the battle")
	await _start_floor(0)
	check(level._locked and level._ceiling != null, "stepping onto the battle floor locks the screen under a ceiling")
	check(f1.global_position.y <= f_y + 4.0, "the partner still below is brought onto the floor")
	check(absf(level.cam.focus.y - (f_y + SkyscraperLevel.FLOOR_PAD - SkyscraperLevel.VIEW_H * 0.5)) < 1.0, "the camera stops on the battle screen")
	check(level.alive_enemies() == 0, "nobody has dropped in yet (time to take positions)")
	await frames(80)
	var start := int(enc["start"])
	check(level.alive_enemies() == start, "the battle starts with %d enemy / enemies (got %d)" % [start, level.alive_enemies()])
	var cx := 0.0
	for e in level._enemies:
		cx += e.global_position.x / float(level._enemies.size())
	check(absf(cx - SkyscraperLevel.W * 0.5) < 320.0, "they drop in around the middle of the screen (x %.0f)" % cx)
	var total: int = (enc["queue"] as Array).size()
	await frames(int(float(enc["interval"]) * 60.0) + 20)
	check(level.alive_enemies() == mini(start + 1, total), "one more drops in after the interval while the first still stand (%d alive)" % level.alive_enemies())
	# ring-out
	var before := level.alive_enemies()
	var victim: Enemy = level._enemies[0]
	victim.global_position = Vector2(100.0, level._kill + 20.0)
	await frames(4)
	check(level.alive_enemies() == before - 1, "an enemy that falls out of the bottom of the screen is out for good")
	# a player's fall
	var hp0 := f0.hp
	f0.global_position = Vector2(700.0, level._kill + 20.0)
	await frames(4)
	check(f0.hp < hp0 and f0.global_position.y <= f_y + 4.0, "a player who falls out loses a little health and is back on the floor")
	check(absf(level.cam.focus.y - (f_y + SkyscraperLevel.FLOOR_PAD - SkyscraperLevel.VIEW_H * 0.5)) < 1.0, "the camera did not follow the fall")
	# empty screen: the next one comes at once
	_kill_all()
	await frames(60)
	check(level.alive_enemies() >= 1 or (level._trickle.get("queue", []) as Array).is_empty(), "with the screen empty the next enemy drops in right away")
	await _clear_floor()
	check(not level._locked and level._enc_idx == 1, "defeating the whole queue unlocks the screen")
	await frames(40)
	check(level._ceiling == null, "the ceiling lifts")
	check(bool(gate["open"]) and gate["body"] == null, "the side gate opens after the battle")

	print("[side shop]")
	var side := int(gate["side"])
	var edge := SkyscraperLevel.W if side > 0 else 0.0
	f0.global_position = Vector2(edge + side * 50.0, f_y - 1.0)
	await frames(6)
	check(level.in_room and level._room is SideRoom and level._room.kind == "shop", "walking through the gate opens the shop screen")
	check(level._past(gate, f0.global_position) > 100.0 and level._past(gate, f1.global_position) > 100.0, "both players are in the side screen")
	check(absf(level.cam.focus.x - (level._room.x0 + DoorRoom.ROOM_W * 0.5)) < 1.0, "the camera scrolls sideways to it")
	check(level._room._items.size() >= 2, "the shop has its pedestals")
	var room: Node = level._room
	f0.global_position = Vector2(edge - side * 60.0, f_y - 1.0)
	await frames(6)
	check(not level.in_room and bool(gate["used"]) and gate["body"] != null, "walking back out closes the gate behind the players")
	check(f1.global_position.x > 0.0 and f1.global_position.x < SkyscraperLevel.W and absf(level.cam.focus.x - SkyscraperLevel.W * 0.5) < 1.0, "both are back in the tower and the camera returns")
	await frames(90)
	check(not is_instance_valid(room), "the side screen is removed once it has scrolled away")

	print("[co-op climb and the goal]")
	f1.global_position = Vector2(300.0, level.ground_y - 1.0)
	f1.velocity = Vector2.ZERO
	await frames(90)
	check(f1.global_position.y < f_y + 60.0, "a partner left far below is pulled up beside the leader (y %.0f)" % f1.global_position.y)
	await _start_floor(1)
	check(level._locked, "the second battle locks")
	await _clear_floor()
	check(not level._cleared, "the level is not over before the goal")
	f0.global_position = Vector2(level.goal.get_center().x, level.goal.position.y - 1.0)
	f0.velocity = Vector2.ZERO
	await frames(12)
	check(level._cleared, "standing on the goal block at the top completes the level")


func _test_challenge() -> void:
	print("[side challenge]")
	var sd := _seed_with_gate("challenge", 0)
	await _load("fight", sd)
	var gate := _gate_of("challenge")
	gate["pick"] = false
	var f_y: float = gate["y"]
	await _start_floor(0)
	await _clear_floor()
	var f0: Fighter = level.fighters[0]
	var side := int(gate["side"])
	var edge := SkyscraperLevel.W if side > 0 else 0.0
	var coins := RunState.coins
	f0.global_position = Vector2(edge + side * 50.0, f_y - 1.0)
	await frames(6)
	check(level.in_room and level._room.kind == "challenge" and gate["body"] != null, "the challenge screen shuts the gate behind the players")
	await frames(60)
	check(level.alive_enemies() == 3, "a challenge starts with 3 enemies (got %d)" % level.alive_enemies())
	# defeat all but the last one, then knock the last one out with a real hit: the slow-motion finish must play
	var guard := 0
	while ((level._trickle.get("queue", []) as Array).size() > 0 or level.alive_enemies() > 1) and guard < 400:
		guard += 1
		var alive: Array = level._enemies.filter(func(e): return is_instance_valid(e) and e.state != "dead")
		for k in maxi(0, alive.size() - (1 if (level._trickle.get("queue", []) as Array).is_empty() else 0)):
			alive[k].queue_free()
		await frames(10)
	var last: Enemy = null
	for e in level._enemies:
		if is_instance_valid(e) and e.state != "dead":
			last = e
	check(last != null, "one enemy is left for the finishing blow")
	if last != null:
		last.invuln = 0.0
		var hit := HitInfo.new()
		hit.attacker = f0
		hit.dmg = 99999.0
		hit.kb = Vector2(300, -400)
		last.take_hit(hit)
		await frames(2)
		check(Engine.time_scale < 0.5, "the last kill of a challenge plays the slow-motion finish (time scale %.2f)" % Engine.time_scale)
		check(not level._room.cleared, "the payout waits for the slow motion")
	guard = 0
	while not level._room.cleared and guard < 400:
		guard += 1
		_kill_all()
		await frames(10)
	check(level._room.cleared and RunState.coins > coins, "clearing it pays coins")
	await frames(4)
	check(gate["body"] == null, "and reopens the way back")
	f0.global_position = Vector2(edge - side * 60.0, f_y - 1.0)
	await frames(6)
	check(not level.in_room and bool(gate["used"]), "the players walk back into the tower")


func _test_boss() -> void:
	print("[boss tower]")
	await _load("boss", 5)
	await _start_floor(0)
	check(level._locked and level._boss_fight, "the boss floor locks as a boss fight")
	await frames(90)
	var boss: Enemy = null
	for e in level._enemies:
		if is_instance_valid(e) and e.kind == "boss_street":
			boss = e
	check(boss != null, "the boss drops in")
	if boss != null:
		check(not boss.launch_resist and boss.stun_resist, "the boss can be launched and juggled (still tough against stun)")
		await frames(60)
		var info := HitInfo.new()
		info.attacker = level.fighters[0]
		info.dmg = 5.0
		info.kind = "launch"
		info.kb = Vector2(200.0, -900.0)
		boss.invuln = 0.0
		boss.take_hit(info)
		await frames(3)
		check(boss.state == "launched", "a launcher sends the boss into the air (state %s)" % boss.state)
	await _clear_floor()
	check(level._cleared, "defeating the boss completes the level")


func _ready() -> void:
	_test_generation()
	await _test_battle()
	await _test_challenge()
	await _test_boss()
	print("RESULT: %s (%d failed)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
