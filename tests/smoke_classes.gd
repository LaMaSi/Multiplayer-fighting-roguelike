extends Node
## Weapon classes: every class B move plus the new X / Y moves starts, finishes and (where it damages) hits;
## adaptive variants are reshaped by the class table; the loadout roll and reward cards respect the tiers.
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_classes.tscn

var fails := 0
var level: Node
var f1: Fighter
var f2: Fighter
var p1: PlayerInput
const X := PlayerInput.Btn.X


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(f: Fighter, pos: Vector2, facing := 1) -> void:
	f.global_position = pos
	f.velocity = Vector2.ZERO
	f.facing = facing


func clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	await frames(2)


func spawn_dummy(pos: Vector2) -> Enemy:
	var d: Enemy = level.spawn_enemy("dummy", pos)
	await frames(2)
	return d


func _ready() -> void:
	var inp := get_node("/root/Inp")
	RunState.classes = ["sword", "hammer"]
	level = load("res://scenes/training.tscn").instantiate()
	add_child(level)
	await frames(5)
	f1 = level.fighters[0]
	f2 = level.fighters[1]
	p1 = inp.players[0]
	inp.players[1].script_set(Vector2.ZERO)
	p1.script_set(Vector2.ZERO)

	print("[class data]")
	check(f1.class_id == "sword" and f2.class_id == "hammer", "classes applied from RunState")
	check(f1.figure.weapon == "sword" and f2.figure.weapon == "hammer", "weapons attached")
	check(f2.get_run_speed() < f1.get_run_speed(), "hammer is slower than sword")
	check(f2.max_hp > f1.max_hp, "hammer has more HP")
	check(f1.loadout.get("B", "") != "", "training loadout has B moves")
	check(ClassData.X_POOL.size() == 10 and ClassData.Y_POOL.size() == 10, "10 universal X and 10 adaptive Y")
	for cid in ClassData.IDS:
		var pool: Array = ClassData.get_class_data(cid)["b_pool"]
		check(pool.size() == 8, "%s has 8 B moves" % cid)
		for id in pool:
			check(MoveDB.has_move(id), "%s move %s exists" % [cid, id])
			check(MoveDB.get_move(id).tier == "weapon" and MoveDB.get_move(id).class_id == cid, "%s is a weapon move of %s" % [id, cid])
	for id in ClassData.X_POOL:
		check(MoveDB.get_move(id).tier == "universal", "%s is universal" % id)
	for id in ClassData.Y_POOL:
		check(MoveDB.get_move(id).tier == "adaptive", "%s is adaptive" % id)

	print("[adaptive variants]")
	var up_b := MoveDB.get_move_for("uppercut", "brawler")
	var up_h := MoveDB.get_move_for("uppercut", "hammer")
	var up_s := MoveDB.get_move_for("uppercut", "sword")
	check(up_h.total > up_b.total, "hammer uppercut is slower (%d vs %d frames)" % [up_h.total, up_b.total])
	check(up_h.hits[0]["dmg"] > up_b.hits[0]["dmg"] * 1.5, "hammer uppercut hits much harder (%.1f vs %.1f)" % [up_h.hits[0]["dmg"], up_b.hits[0]["dmg"]])
	check((up_s.hits[0]["box"] as Rect2).size.x > (MoveDB.get_move("uppercut").hits[0]["box"] as Rect2).size.x, "sword uppercut reaches further")
	check(bool(up_h.hits[0].get("guard_break", false)), "hammer moves break guard")
	check(MoveDB.get_move("uppercut").hits[0]["dmg"] == 9.0, "the base move is untouched")
	var sw_b := MoveDB.get_move_for("sweep", "hammer")
	var dz: Rect2 = sw_b.hits[0]["box"]
	check(dz.position.x >= 40.0, "hammer has a dead zone up close (box starts at %.0f)" % dz.position.x)

	print("[run-start roll]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for cid in ClassData.IDS:
		var lo := ClassData.roll_loadout(cid, rng)
		check(lo.size() == 5, "%s roll: 5 moves (3 B, 1 X, 1 Y)" % cid)
		var bs := [lo["B"], lo["B_UP"], lo["B_SIDE"]]
		check(bs[0] != bs[1] and bs[1] != bs[2] and bs[0] != bs[2], "%s roll: three different B moves" % cid)
		var ok := true
		for b in bs:
			ok = ok and (b in (ClassData.get_class_data(cid)["b_pool"] as Array))
		check(ok and lo["X"] in ClassData.X_POOL and lo["Y"] in ClassData.Y_POOL, "%s roll: tiers respected" % cid)

	print("[reward cards respect tiers]")
	RunState.start_run(5)
	check((RunState.loadouts[0] as Dictionary).has("B") and (RunState.loadouts[1] as Dictionary).has("B_UP"), "run start gives class loadouts")
	check(RunState.max_hp[1] == 120.0, "run HP follows the class (hammer %.0f)" % RunState.max_hp[1])
	var mc := RunState.make_cards(0, "move")
	var all_xy := true
	for c in mc:
		all_xy = all_xy and (int(c["row"]) in [0, 1])
	check(mc.size() == 3 and all_xy, "shared move pick offers only X / Y moves")
	var lc := RunState.make_cards(0, "level")
	var has_b := false
	for c in lc:
		if c["kind"] == "move" and int(c["row"]) == 2:
			has_b = true
	check(has_b, "personal level-up offers a new weapon move")
	RunState.end_run()

	print("[every new move runs]")
	var dist := {"off_hand_jab": 55, "ground_wave": 220, "fireball": 220, "boomerang": 220, "spread_shot": 220, "pull_hook": 250, "teleport_strike": 300, "wind_slash": 220, "quake_line": 240, "arcane_beam": 120, "gravity_well": 230, "spark_shot": 200,
		"counter_palm": 70, "riposte_step": 70, "deflect_stance": 70, "pocket_mine": 40, "mirror_ward": 70,
		"bulwark_plant": 70, "slide_strike": 70, "home_run": 80, "whirlwind_haul": 80,
		"javelin": 250, "plunge": 40, "pole_vault": 60}
	var no_damage := ["parry", "counter_palm", "riposte_step", "deflect_stance", "mirror_ward", "bulwark_plant", "gravity_well", "guard_breaker", "vault_over", "air_parry"]
	var ids: Array = ["off_hand_jab", "spark_shot", "slide_strike"]
	for cid in ["brawler", "sword", "hammer", "magic", "lance"]:
		for id in (ClassData.get_class_data(cid)["b_pool"] as Array):
			if not (id in ids):
				ids.append(id)
	for id in ids:
		var cid := ClassData.class_of_weapon_move(id)
		if cid == "":
			cid = "sword"
		await clear_enemies()
		Coop.reset_run()
		Coop.fighters.append(f1)
		Coop.fighters.append(f2)
		f1.apply_class(cid)
		place(f1, Vector2(1000, 599), 1)
		place(f2, Vector2(300, 599), 1)
		f1.loadout["X"] = id
		var dm := await spawn_dummy(Vector2(1000 + int(dist.get(id, 80)), 599))
		await frames(3)
		var h0 := dm.hp
		var x0 := dm.global_position.x
		p1.script_set(Vector2.ZERO, [X])
		await frames(1)
		p1.script_set(Vector2.ZERO, [])
		var longest := 0
		for i in 400:
			await frames(1)
			if not f1.attack.active and f1.state in ["idle", "walk", "land", "jump", "fall"]:
				longest = i
				break
		await frames(40)
		check(longest > 0, "%s (%s): starts and finishes (%d frames)" % [id, cid, longest])
		if not (id in no_damage):
			var moved := dm.hp < h0 or absf(dm.global_position.x - x0) > 12.0 or dm.state != "idle"
			check(moved, "%s: affects the dummy (dmg %.1f)" % [id, h0 - dm.hp])
	f1.apply_class("sword")

	print("[lance and air rules]")
	var lance := ClassData.get_class_data("lance")
	check(float(lance["jump"]) > 1.0 and float(lance["speed"]) > ClassData.get_class_data("sword")["speed"] * 1.0, "lance jumps higher and runs faster than the sword")
	check(int(ClassData.air("lance")["refunds"]) > int(ClassData.air("sword")["refunds"]), "lance gets more air refunds than the base classes")
	check(int(ClassData.air("lance")["hang"]) > int(ClassData.air("hammer")["hang"]), "lance hangs longer after an air hit")
	check(MoveDB.get_move("thrust").air_variant == "thrust_air" and MoveDB.has_move("thrust_air"), "thrust has an air variant")
	check(MoveDB.get_move("skyhook").hits[0].get("reset_juggle", false), "skyhook restores the juggle")
	f1.apply_class("lance")
	check(f1.class_jump > 1.0 and f1.innate_double_jump and f1.figure.weapon == "lance", "lance: jump stat wired, innate double jump, weapon attached")
	f1.apply_class("hammer")
	check(f1.class_jump < 1.0 and not f1.innate_double_jump, "the class jump stat applies to other classes too (hammer jumps lower)")
	f1.apply_class("sword")
	await clear_enemies()
	var cd := await spawn_dummy(Vector2(1000, 599))
	var h1 := HitInfo.new()
	h1.attacker = f2
	h1.team = "player"
	h1.kind = "launch"
	h1.kb = Vector2(100, -700)
	h1.dmg = 5.0
	cd.take_hit(h1)
	check(cd.state == "launched", "a launch puts the dummy in the air")
	cd.juggle_hits = 5
	var h2 := HitInfo.new()
	h2.attacker = f1
	h2.team = "player"
	h2.kind = "launch"
	h2.kb = Vector2(100, -700)
	h2.dmg = 5.0
	cd.take_hit(h2)
	check(cd.juggle_hits == 0 and cd.launch_hang == 12, "the partner catching a launched enemy restores the juggle and makes it hang")
	await clear_enemies()

	print("[hammer partner launch, barrier, ward]")
	await clear_enemies()
	Coop.friendly_fire = false
	f1.apply_class("hammer")
	f1.loadout["X"] = "home_run"
	place(f1, Vector2(1000, 599), 1)
	place(f2, Vector2(1090, 599), 1)
	var hp2 := f2.hp
	p1.script_set(Vector2.ZERO, [X])
	await frames(1)
	p1.script_set(Vector2.ZERO, [])
	await frames(70)
	check(f2.global_position.x > 1200.0 or f2.state in ["launched", "hurt"], "home run launches the partner even with friendly fire off")
	check(f2.hp == hp2, "the partner takes no damage from it")
	Coop.friendly_fire = true
	await frames(60)
	f1.loadout["X"] = "bulwark_plant"
	place(f1, Vector2(1000, 599), 1)
	place(f2, Vector2(300, 599), 1)
	p1.script_set(Vector2.ZERO, [X])
	await frames(1)
	p1.script_set(Vector2.ZERO, [])
	await frames(50)
	check(get_tree().get_nodes_in_group("barriers").size() == 1, "bulwark plant raises a barrier")
	await frames(260)
	check(get_tree().get_nodes_in_group("barriers").size() == 0, "the barrier expires after ~4 s")
	f1.apply_class("magic")
	f1.loadout["X"] = "mirror_ward"
	place(f1, Vector2(1000, 599), 1)
	place(f2, Vector2(1100, 599), 1)
	f2.shield_hits = 0
	p1.script_set(Vector2.ZERO, [X])
	await frames(1)
	p1.script_set(Vector2.ZERO, [])
	await frames(40)
	check(f2.shield_hits == 1, "mirror ward shields the partner")

	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(fails)
