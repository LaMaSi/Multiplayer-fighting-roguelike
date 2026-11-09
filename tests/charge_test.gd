extends Node
## Chargeable moves: hold the button for up to 3 s for more damage and knockback; every category has some.
##   Godot --path . res://tests/charge_test.tscn [-- <out_prefix>]

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Plays `id` on P1 against a fresh dummy 80 px in front: returns {dmg, push, frames_to_hit, charge}.
func _trial(lv: LevelBase, id: String, hold_frames: int) -> Dictionary:
	var f: Fighter = lv.fighters[0]
	var p: PlayerInput = Inp.players[0]
	p.script_set(Vector2.ZERO, [])
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await frames(2)
	f.global_position = Vector2(700.0, lv.ground_y - 1.0)
	f.facing = 1
	f.velocity = Vector2.ZERO
	f.hp = f.max_hp
	f.state = "idle"
	Coop.combo = 0  # the team combo multiplies damage: every trial starts from none
	Coop.combo_t = 0.0
	var e: Enemy = lv.spawn_enemy("dummy", Vector2(790.0, lv.ground_y - 1.0))
	e.invuln = 0.0
	e.max_hp = 5000.0
	e.hp = 5000.0  # plenty of health: the damage must not be capped by the dummy dying
	await frames(25)
	var hp0 := e.hp
	var x0 := e.global_position.x
	var m := MoveDB.get_move_for(id, f.class_id)
	var btn := PlayerInput.Btn.B
	p.script_set(Vector2.ZERO, [btn] if hold_frames > 0 else [])
	f.start_attack(m, btn)
	var hit_at := -1
	var first_dmg := 0.0
	var first_push := 0.0
	var charge_seen := 0.0
	var released := false
	for i in 420:
		await get_tree().physics_frame
		if hold_frames > 0 and i >= hold_frames and not released:
			p.script_set(Vector2.ZERO, [])  # let go: the move plays out
			released = true
		charge_seen = maxf(charge_seen, f.attack.charge_t())
		if hit_at < 0 and e.hp < hp0:
			hit_at = i
			first_dmg = hp0 - e.hp  # the hit itself (burning and later damage come after)
			first_push = absf(e.velocity.x)  # the launch speed the hit gave
		if not f.attack.active and hit_at >= 0 and i > hit_at + 10:
			break
	p.script_set(Vector2.ZERO, [])
	return {"dmg": f.attack.last_hit_dmg, "push": f.attack.last_hit_kb, "hit_at": hit_at, "charge": charge_seen}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# 1. every category has chargeable moves, all of them 3 s
	var by_tier := {"weapon": 0, "adaptive": 0, "universal": 0}
	var by_class := {}
	var all_3s := true
	for id in MoveDB.all_player_moves():
		var m := MoveDB.get_move(String(id))
		if m != null and m.is_chargeable():
			by_tier[m.tier] = int(by_tier.get(m.tier, 0)) + 1
			if m.tier == "weapon":
				by_class[m.class_id] = true
			if m.charge_max != 180:
				all_3s = false
	check(int(by_tier["weapon"]) >= 1 and int(by_tier["adaptive"]) >= 1 and int(by_tier["universal"]) >= 1, "weapon (B), adaptive (Y) and universal (X) all have chargeable moves: %s" % str(by_tier))
	check(by_class.size() == 4, "every weapon class has a chargeable B move: %s" % str(by_class.keys()))
	check(all_3s, "a full charge takes 3 s (180 frames) for every chargeable move")
	# 2. a tap plays the move normally; holding builds charge and hits harder and knocks back further
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []
	var tap: Dictionary = await _trial(lv, "haymaker", 0)
	var full: Dictionary = await _trial(lv, "haymaker", 200)
	check(float(tap["dmg"]) > 0.0 and float(full["dmg"]) > 0.0, "both versions of Heavy Haymaker connect (hit damage tap %.1f, charged %.1f)" % [tap["dmg"], full["dmg"]])
	check(float(tap["charge"]) == 0.0, "a tap builds no charge")
	check(float(full["charge"]) >= 0.99, "holding builds a full charge (%.2f)" % full["charge"])
	check(float(full["dmg"]) > float(tap["dmg"]) * 2.0, "a full charge deals much more damage (%.1f vs %.1f)" % [full["dmg"], tap["dmg"]])
	check(float(full["push"]) > float(tap["push"]) * 1.8, "a full charge knocks back further (%.0f vs %.0f)" % [full["push"], tap["push"]])
	check(int(full["hit_at"]) > int(tap["hit_at"]) + 120, "the charge takes time: it hits %d frames later" % (int(full["hit_at"]) - int(tap["hit_at"])))
	# half a second of charge gives a smaller bonus than 3 s
	var part: Dictionary = await _trial(lv, "haymaker", 60)
	check(float(part["dmg"]) > float(tap["dmg"]) * 1.1 and float(part["dmg"]) < float(full["dmg"]), "a partial charge lands in between (%.1f)" % part["dmg"])
	# 3. a charged projectile (Fireball is a Magic move: borrow its data on the Brawler's attack runner)
	var fb := MoveDB.get_move("fireball")
	check(fb.is_chargeable(), "Fireball can be charged")
	# 4. the badge text
	var hm := MoveDB.get_move("haymaker")
	check(hm.charge_bonus_text().contains("DMG") and hm.charge_bonus_text().contains("KB"), "the card badge shows the bonus: '%s'" % hm.charge_bonus_text())
	if args.size() > 0:
		# screenshot: the charge effect at about 2 s, plus the card badge
		var p: PlayerInput = Inp.players[0]
		var f: Fighter = lv.fighters[0]
		for n in get_tree().get_nodes_in_group("hurt_enemy"):
			if n is Enemy:
				n.queue_free()
		f.global_position = Vector2(700.0, lv.ground_y - 1.0)
		p.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
		f.start_attack(MoveDB.get_move_for("haymaker", f.class_id), PlayerInput.Btn.B)
		await frames(125)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0] + "_charging.png")
		p.script_set(Vector2.ZERO, [])
	print("charge test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
