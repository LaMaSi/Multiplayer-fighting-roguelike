extends Node
## Finish line (safe zone, level end), the bonus pole and the reward shown on challenge doors.
##   Godot --path . res://tests/finish_test.tscn [-- <out_prefix>]

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _make(seed_: int) -> LevelBase:
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": seed_, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	return lv


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var lv := _make(3)
	await frames(10)
	check(LevelBase.FINISH_CLEAR > 700.0, "the finish safe zone is half a screen (%.0f px)" % LevelBase.FINISH_CLEAR)
	# 1. safe zone, across seeds
	var bad := 0
	for sd in range(1, 11):
		lv.queue_free()
		await frames(2)
		lv = _make(sd)
		await frames(6)
		for pr in get_tree().get_nodes_in_group("props"):
			if lv.near_finish((pr as Node2D).global_position.x):
				bad += 1
				print('  prop ', (pr as Prop).kind, ' seed ', sd, ' at ', (pr as Node2D).global_position, ' exit ', lv.exit_x, ' state ', (pr as Prop).state)
		for hz in lv.get_children():
			if hz is SpikeTrap and not (hz as SpikeTrap).ceiling and lv.near_finish((hz as Node2D).position.x):
				bad += 1
				print('  spike seed ', sd, ' x ', (hz as Node2D).position.x, ' exit ', lv.exit_x)
			if hz is Door and lv.near_finish((hz as Node2D).position.x):
				bad += 1
				print('  door seed ', sd, ' x ', (hz as Node2D).position.x, ' exit ', lv.exit_x)
		for enc in lv.encounters:
			if absf(float(enc["x"]) + 800.0 - lv.exit_x) < LevelBase.FINISH_CLEAR - 300.0:
				bad += 1  # an arena reaching into the safe zone
				print('  arena seed ', sd, ' enc ', enc['x'], ' exit ', lv.exit_x)
	check(bad == 0, "nothing spawns within the finish safe zone across 10 seeds (%d violations)" % bad)
	# 2. door reward
	var d := Door.new()
	d.kind = "challenge"
	d.pick_move = true
	check(d.reward_text().contains("COINS") and d.reward_text().contains("MOVE"), "a challenge door with a move choice says so: '%s'" % d.reward_text())
	d.pick_move = false
	check(d.reward_text().contains("COINS") and not d.reward_text().contains("MOVE"), "a plain challenge door shows only coins: '%s'" % d.reward_text())
	d.free()
	# 3. the bonus pole
	var pole: BonusPole = null
	for n in lv.get_children():
		if n is BonusPole:
			pole = n
	check(pole != null, "the level has a bonus pole")
	if pole != null:
		check(BonusPole.LOW > 250.0, "the pole's lowest point (%.0f px up) is above a single jump (~180)" % BonusPole.LOW)
		check(absf(pole.position.x - (lv.exit_x - 330.0)) < 1.0, "the pole stands before the finish line")
		var lo := 1.0e9
		var hi := -1.0e9
		for i in 400:
			await get_tree().physics_frame
			lo = minf(lo, pole.bottom_h())
			hi = maxf(hi, pole.bottom_h())
		check(lo >= BonusPole.LOW - 1.0 and hi <= BonusPole.HIGH + 1.0 and hi - lo > 60.0, "it slides up and down within %.0f..%.0f px (saw %.0f..%.0f)" % [BonusPole.LOW, BonusPole.HIGH, lo, hi])
		var c0 := RunState.coins
		var info := HitInfo.new()
		info.attacker = lv.fighters[0]
		check(pole.take_hit(info), "a hit on the pole lands")
		check(RunState.coins > c0, "the pole pays coins (%d -> %d)" % [c0, RunState.coins])
		check(not pole.take_hit(info), "a second hit in the same instant does not pay twice")
		check(pole in get_tree().get_nodes_in_group("hurt_enemy"), "player attacks and projectiles can target it")
	# 4. the finish line ends the level
	lv.encounters = []
	lv._enc_idx = 0
	var a: Fighter = lv.fighters[0]
	var b: Fighter = lv.fighters[1]
	a.global_position = Vector2(lv.exit_x - 200.0, lv.ground_top(lv.exit_x) - 1.0)
	b.global_position = Vector2(lv.exit_x - 240.0, lv.ground_top(lv.exit_x) - 1.0)
	await frames(30)
	check(not lv._cleared, "the level is not over before the line")
	a.global_position = Vector2(lv.exit_x + 20.0, lv.ground_top(lv.exit_x) - 1.0)
	b.global_position = Vector2(lv.exit_x + 10.0, lv.ground_top(lv.exit_x) - 1.0)
	await frames(30)
	check(lv._cleared, "walking across the finish line ends the level")
	if args.size() > 0:
		lv.queue_free()
		await frames(2)
		lv = _make(3)
		await frames(10)
		lv.encounters = []
		var f0: Fighter = lv.fighters[0]
		f0.global_position = Vector2(lv.exit_x - 380.0, lv.ground_top(lv.exit_x) - 1.0)
		lv.fighters[1].global_position = Vector2(lv.exit_x - 440.0, lv.ground_top(lv.exit_x) - 1.0)
		await frames(90)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0] + "_finish.png")
		if lv.doors_spec.size() > 0:
			var dx := float(lv.doors_spec[0]["x"])
			f0.global_position = Vector2(dx - 10.0, lv.ground_top(dx) - 1.0)
			lv.fighters[1].global_position = Vector2(dx - 90.0, lv.ground_top(dx) - 1.0)
			await frames(60)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[0] + "_door.png")
	# the HUD: low health turns the bar red and pulses the panel (screenshots only)
	if args.size() > 0:
		lv.queue_free()
		await frames(2)
		lv = _make(3)
		await frames(10)
		lv.fighters[0].hp = lv.fighters[0].max_hp * 0.22
		lv.fighters[1].hp = lv.fighters[1].max_hp * 0.8
		await frames(40)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0] + "_lowhp.png")
	print("finish test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
