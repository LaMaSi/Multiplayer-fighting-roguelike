extends Node
## Run flow test: node map, reward cards, upgrades, generated levels, completion, UI scenes.
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_run.tscn

var fails := 0
var level: LevelBase


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func load_level(path: String) -> void:
	if level != null:
		level.queue_free()
		await frames(2)
	level = load(path).instantiate()
	add_child(level)
	await frames(5)
	var inp := get_node("/root/Inp")
	inp.players[0].script_set(Vector2.ZERO)
	inp.players[1].script_set(Vector2.ZERO)


func kill_all_enemies() -> void:
	for e in level._enemies:
		if is_instance_valid(e):
			e.queue_free()


func _ready() -> void:
	await _run()
	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(fails)


func _run() -> void:
	print("[map generation]")
	for sd in [1, 5, 42, 99, 1234]:
		RunState.start_run(sd)
		var ok := RunState.map.size() == 6
		var boss_layer: Array = RunState.map[5]
		ok = ok and boss_layer.size() == 1 and boss_layer[0]["type"] == "boss"
		# every node leads somewhere and every node is reachable
		var reach := {}
		for n in RunState.map[0]:
			reach["0:%d" % n["idx"]] = true
		for l in 5:
			for n in RunState.map[l]:
				if reach.has("%d:%d" % [l, n["idx"]]):
					ok = ok and n["next"].size() >= 1
					for ti in n["next"]:
						reach["%d:%d" % [l + 1, ti]] = true
		ok = ok and reach.has("5:0")
		var has_rest := false
		for n in RunState.map[4]:
			if n["type"] == "rest":
				has_rest = true
		check(ok and has_rest, "seed %d: 6 layers, boss reachable, rest before boss" % sd)

	print("[reward cards]")
	RunState.start_run(7)
	var cards := RunState.make_cards(0, "move")
	var ids := {}
	var owned_clash := false
	for c in cards:
		ids[c["id"]] = true
		if c["id"] in RunState.loadouts[0].values():
			owned_clash = true
	check(cards.size() == 3 and ids.size() == 3 and not owned_clash, "3 distinct, not-yet-owned move cards")
	RunState.apply_card(0, cards[0], "X_DOWN")
	check(RunState.loadouts[0]["X_DOWN"] == cards[0]["id"], "move card replaces the chosen slot")
	check(RunState.loadouts[1]["X_DOWN"] == "sweep", "other player's loadout untouched")
	RunState.apply_card(0, cards[1], "Y_UP")
	check(RunState.loadouts[0].size() == 5 and RunState.loadouts[0].has("Y_UP"), "a move can go into an empty slot")
	var lv := RunState.make_cards(0, "level")
	check(lv.size() == 3, "3 level-up cards")
	var hp_before: float = RunState.max_hp[0]
	RunState.apply_card(0, {"kind": "hp"})
	check(RunState.max_hp[0] == hp_before + 20.0, "+20 max HP card")
	RunState.apply_card(0, {"kind": "up", "stat": "dmg", "id": "jab"})
	check(is_equal_approx(RunState.upgrades[0]["jab"]["dmg"], 1.25), "empower card stores a damage multiplier")

	print("[upgrade changes real damage]")
	await load_level("res://scenes/training.tscn")
	RunState.end_run()
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await frames(2)
	var f1: Fighter = level.fighters[0]
	var f2: Fighter = level.fighters[1]
	var inp := get_node("/root/Inp")
	var p1: PlayerInput = inp.players[0]
	f2.global_position = Vector2(300, 599)
	var damages: Array = []
	for mult in [1.0, 2.0]:
		f1.global_position = Vector2(1000, 599)
		f1.facing = 1
		f1.state = "idle"
		f1.upgrades = {"jab": {"dmg": mult, "kb": 1.0, "spd": 1.0}}
		Coop.reset_run()
		Coop.fighters.append(f1)
		Coop.fighters.append(f2)
		var d := level.spawn_enemy("dummy", Vector2(1070, 599))
		await frames(3)
		var h0 := d.hp
		p1.script_set(Vector2.ZERO, [PlayerInput.Btn.X])
		await frames(1)
		p1.script_set(Vector2.ZERO)
		await frames(20)
		damages.append(h0 - d.hp)
		d.queue_free()
		await frames(40)
	check(damages[0] > 0.0 and is_equal_approx(damages[1], damages[0] * 2.0), "x2 damage upgrade doubles jab damage (%.1f -> %.1f)" % [damages[0], damages[1]])

	print("[fight level generated from a map node]")
	RunState.start_run(11)
	var node: Dictionary = RunState.map[0][0]
	RunState.choose(node)
	await load_level("res://scenes/streets.tscn")
	check(level.level_w == 3800.0 and level.exit_x > 0.0 and level.encounters.size() == 2, "fight level: width %d, exit at %d, %d encounters" % [level.level_w, level.exit_x, level.encounters.size()])
	var lf1: Fighter = level.fighters[0]
	var lf2: Fighter = level.fighters[1]
	lf1.global_position = Vector2(1250, 599)
	lf2.global_position = Vector2(1200, 599)
	await frames(10)
	check(level._locked and level.alive_enemies() > 0, "first encounter locks the arena and spawns enemies")
	for i in 4:
		kill_all_enemies()
		await frames(25)
	check(not level._locked and level._enc_idx == 1, "arena unlocks after both waves")
	lf1.global_position = Vector2(2450, 599)
	lf2.global_position = Vector2(2400, 599)
	await frames(10)
	for i in 4:
		kill_all_enemies()
		await frames(25)
	check(level._enc_idx == 2 and not level._cleared, "second encounter done, level not complete until the exit is reached")
	lf1.global_position = Vector2(level.exit_x + 20.0, 599)
	lf2.global_position = Vector2(level.exit_x + 40.0, 599)
	await frames(10)
	check(level._cleared, "reaching the exit completes the level")
	lf1.hp = 30.0
	RunState.save_from(level.fighters)
	RunState.level_cleared()
	check(RunState.levels_cleared == 1 and RunState.queue.size() == 2, "rewards queued: %d picks" % RunState.queue.size())
	check(RunState.queue[0]["player"] != RunState.queue[1]["player"], "each player gets a pick")
	var first_picker: int = RunState.queue[0]["player"]
	check(is_equal_approx(RunState.hp[0], 55.0), "HP carries over with a 25%% heal (%.0f)" % RunState.hp[0])
	RunState.apply_card(0, {"kind": "move", "id": "fireball"}, "X_DOWN")

	print("[next level uses run state]")
	RunState.choose(RunState.available_next()[0])
	await load_level("res://scenes/streets.tscn")
	var nf1: Fighter = level.fighters[0]
	check(nf1.loadout.get("X_DOWN") == "fireball", "new level starts with the picked move")
	check(is_equal_approx(nf1.hp, 55.0), "new level starts with carried-over HP (%.0f)" % nf1.hp)
	RunState.save_from(level.fighters)
	RunState.level_cleared()
	check(RunState.queue[0]["player"] != first_picker, "first picker alternates between levels")

	print("[treasure + boss levels]")
	RunState.start_run(3)
	RunState.current = {"type": "treasure", "seed": 9, "layer": 1, "idx": 0, "next": [], "done": false}
	await load_level("res://scenes/streets.tscn")
	check(level.encounters.is_empty() and level.props_spec.size() >= 15, "treasure level: no fights, %d containers" % level.props_spec.size())
	level.fighters[0].global_position = Vector2(level.exit_x + 30.0, 599)
	level.fighters[1].global_position = Vector2(level.exit_x + 60.0, 599)
	await frames(10)
	check(level._cleared, "treasure level completes at the exit")
	RunState.current = {"type": "boss", "seed": 4, "layer": 5, "idx": 0, "next": [], "done": false}
	await load_level("res://scenes/streets.tscn")
	level.fighters[0].global_position = Vector2(900, 599)
	level.fighters[1].global_position = Vector2(850, 599)
	await frames(15)
	var boss: Enemy = null
	for n in get_tree().get_nodes_in_group("boss"):
		boss = n
	check(boss != null, "boss level spawns the boss")
	if boss != null:
		boss.invuln = 0.0
		var bi := HitInfo.new()
		bi.attacker = level.fighters[0]
		bi.team = "player"
		bi.dmg = 99999.0
		bi.kb = Vector2(200, -300)
		bi.kind = "launch"
		boss.take_hit(bi)
		await frames(160)
	check(level._cleared, "defeating the boss completes the level")
	RunState.save_from(level.fighters)
	RunState.level_cleared()
	check(RunState.finished and RunState.won, "boss clear finishes the run")

	print("[reward + map screens run]")
	RunState.start_run(21)
	RunState.current = RunState.map[0][0]
	RunState.queue = [{"player": 1, "kind": "level"}, {"player": 0, "kind": "move"}]
	level.queue_free()  # its result screen would react to the simulated A presses
	await frames(3)
	var rs = load("res://scenes/reward.tscn").instantiate()
	add_child(rs)
	await frames(5)
	var p2: PlayerInput = inp.players[1]
	var maxhp_before: float = RunState.max_hp[1] + RunState.hp[1]
	p2.script_set(Vector2(1, 0))
	await frames(3)
	p2.script_set(Vector2(-1, 0))
	await frames(3)
	p2.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
	await frames(2)
	p2.script_set(Vector2.ZERO)
	await frames(3)
	check(rs._i == 1, "P2's pick is applied, then it is P1's turn")
	# P1 takes a move card into the slot picker
	var p1b: PlayerInput = inp.players[0]
	p1b.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
	await frames(2)
	p1b.script_set(Vector2.ZERO)
	await frames(3)
	check(rs._phase == "slot", "a move card opens the slot picker")
	p1b.script_set(Vector2(1, 0))
	await frames(3)
	p1b.script_set(Vector2.ZERO)
	await frames(2)
	p1b.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	await frames(2)
	p1b.script_set(Vector2.ZERO)
	await frames(2)
	check(rs._phase == "cards", "B goes back from the slot picker")
	rs.queue_free()
	await frames(2)
	var rm = load("res://scenes/run_map.tscn").instantiate()
	add_child(rm)
	await frames(10)
	check(RunState.available_next().size() >= 1, "run map shows choices")
	rm.queue_free()
	await frames(2)
	RunState.end_run()
