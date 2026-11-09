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


## Hazards and containers would hurt, launch or block the test fighter: clear them.
func _clear_level(_lv: LevelBase) -> void:
	for g in ["hazards", "props"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()
	await frames(2)


## Plays `id` on P1 against a fresh dummy 80 px in front: returns {dmg, push, frames_to_hit, charge}.
func _trial(lv: LevelBase, id: String, hold_frames: int, dist := 90.0) -> Dictionary:
	var f: Fighter = lv.fighters[0]
	var p: PlayerInput = Inp.players[0]
	p.script_set(Vector2.ZERO, [])
	f.attack.last_hit_dmg = 0.0  # no hit yet in this trial
	f.attack.last_hit_kb = 0.0
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
	var e: Enemy = lv.spawn_enemy("dummy", Vector2(700.0 + dist, lv.ground_y - 1.0))
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


## Plays `id` with nobody in front: returns how far the fighter travelled and how high it rose.
func _move_trial(lv: LevelBase, id: String, hold_frames: int) -> Dictionary:
	var f: Fighter = lv.fighters[0]
	var p: PlayerInput = Inp.players[0]
	p.script_set(Vector2.ZERO, [])
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await frames(2)
	f.global_position = Vector2(500.0, lv.ground_y - 1.0)
	f.facing = 1
	f.velocity = Vector2.ZERO
	f.state = "idle"
	await frames(10)
	var x0 := f.global_position.x
	var y0 := f.global_position.y
	var m := MoveDB.get_move_for(id, f.class_id)
	var btn := PlayerInput.Btn.B
	p.script_set(Vector2.ZERO, [btn] if hold_frames > 0 else [])
	f.start_attack(m, btn)
	var rise := 0.0
	var released := false
	for i in 420:
		await get_tree().physics_frame
		if hold_frames > 0 and i >= hold_frames and not released:
			p.script_set(Vector2.ZERO, [])
			released = true
		rise = maxf(rise, y0 - f.global_position.y)
		if not f.attack.active and i > hold_frames + 20:
			break
	await frames(40)  # let the slide stop
	p.script_set(Vector2.ZERO, [])
	return {"dist": f.global_position.x - x0, "rise": rise}


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
	await _clear_level(lv)
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
	# 2b. the charge also stretches the move's own movement: Thrust Lunge goes much further, Sky Launcher jumps higher
	var lt: Dictionary = await _move_trial(lv, "thrust_lunge", 0)
	var lf: Dictionary = await _move_trial(lv, "thrust_lunge", 200)
	check(float(lf["dist"]) > float(lt["dist"]) * 1.6, "a fully charged Thrust Lunge travels much further (%.0f vs %.0f px)" % [lf["dist"], lt["dist"]])
	var st: Dictionary = await _move_trial(lv, "side_sweep", 0)
	var sf: Dictionary = await _move_trial(lv, "side_sweep", 200)
	check(float(sf["dist"]) > float(st["dist"]) * 1.4, "a fully charged Side Sweep steps further (%.0f vs %.0f px)" % [sf["dist"], st["dist"]])
	var kt: Dictionary = await _move_trial(lv, "sky_launcher", 0)
	var kf: Dictionary = await _move_trial(lv, "sky_launcher", 200)
	check(float(kf["rise"]) > float(kt["rise"]) * 1.25, "a fully charged Sky Launcher jumps higher (%.0f vs %.0f px)" % [kf["rise"], kt["rise"]])
	var hammer_n := 0
	for id in ["overhead_smash", "guard_breaker", "side_sweep", "sky_launcher"]:
		if MoveDB.get_move(id).is_chargeable():
			hammer_n += 1
	check(hammer_n == 4, "four Hammer moves can be charged (%d)" % hammer_n)
	check(MoveDB.get_move("thrust_lunge").charge_stretch, "the lunge's hit window stretches with its longer path")
	# 2c. what changed after playtesting
	check(not MoveDB.get_move("off_hand_jab").is_chargeable(), "the Off-hand Jab stays a quick, weak punch (no charge)")
	check(MoveDB.get_move("shockwave").is_chargeable() and MoveDB.get_move("shockwave").charge_range > 0.0, "the Shockwave Clap charges for range and knockback")
	var sp0: Dictionary = await _move_trial(lv, "spin_kick", 0)
	var sp1: Dictionary = await _move_trial(lv, "spin_kick", 200)
	check(float(sp1["dist"]) > float(sp0["dist"]) * 1.8, "a fully charged Spin Kick travels much further (%.0f vs %.0f px)" % [sp1["dist"], sp0["dist"]])
	var up0: Dictionary = await _trial(lv, "uppercut", 0, 45.0)
	var up1: Dictionary = await _trial(lv, "uppercut", 200, 45.0)
	check(float(up1["push"]) > float(up0["push"]) * 2.5, "a fully charged Uppercut has much more knockback (%.0f vs %.0f)" % [up1["push"], up0["push"]])
	var cl0: Dictionary = await _trial(lv, "shockwave", 0, 200.0)
	var cl1: Dictionary = await _trial(lv, "shockwave", 200, 200.0)
	check(float(cl0["dmg"]) == 0.0 and float(cl1["dmg"]) > 0.0, "the clap reaches a far enemy only when charged (tap hit: %s, charged hit: %s)" % [float(cl0["dmg"]) > 0.0, float(cl1["dmg"]) > 0.0])
	# a short press shows no ring, a real hold does
	var f0: Fighter = lv.fighters[0]
	var pin: PlayerInput = Inp.players[0]
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	f0.global_position = Vector2(500.0, lv.ground_y - 1.0)
	f0.state = "idle"
	await frames(10)
	pin.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	f0.start_attack(MoveDB.get_move_for("haymaker", f0.class_id), PlayerInput.Btn.B)
	await frames(28)  # the wind-up takes 22 frames, so the button has been held about 6 frames at the charge point
	check(f0.attack._charge_fx == null, "no charge ring while the button has only been held a moment")
	pin.script_set(Vector2.ZERO, [])
	await frames(120)
	check(not f0.attack.active, "a short press releases the move normally")
	f0.state = "idle"
	await frames(10)
	pin.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	f0.start_attack(MoveDB.get_move_for("haymaker", f0.class_id), PlayerInput.Btn.B)
	await frames(60)
	check(f0.attack._charge_fx != null and is_instance_valid(f0.attack._charge_fx), "the ring appears once the button is really held")
	pin.script_set(Vector2.ZERO, [])
	await frames(120)
	# 2d. a charged Spark Shot is clearly a different shot, and charging changes the sounds
	var shots := {}
	for hold in [0, 200]:
		for n in get_tree().get_nodes_in_group("projectiles"):
			n.queue_free()
		await frames(2)
		f0.global_position = Vector2(500.0, lv.ground_y - 1.0)
		f0.state = "idle"
		await frames(10)
		pin.script_set(Vector2.ZERO, [PlayerInput.Btn.X] if hold > 0 else [])
		f0.start_attack(MoveDB.get_move_for("spark_shot", f0.class_id), PlayerInput.Btn.X)
		var seen = null
		for i in 260:
			await get_tree().physics_frame
			if hold > 0 and i == hold:
				pin.script_set(Vector2.ZERO, [])
			var ps := get_tree().get_nodes_in_group("projectiles")
			if ps.size() > 0:
				seen = ps[0]
				break
		if seen != null:
			shots[hold] = {"radius": seen.radius, "speed": seen.vel.length(), "dmg": seen.dmg, "col": seen.col}
		pin.script_set(Vector2.ZERO, [])
		await frames(30)
	check(shots.has(0) and shots.has(200), "both a tapped and a charged Spark Shot were fired")
	if shots.has(0) and shots.has(200):
		check(float(shots[200]["radius"]) > float(shots[0]["radius"]) * 2.4, "the charged spark is much bigger (radius %.0f vs %.0f)" % [shots[200]["radius"], shots[0]["radius"]])
		check(float(shots[200]["speed"]) > float(shots[0]["speed"]) * 1.4, "...and faster (%.0f vs %.0f px/s)" % [shots[200]["speed"], shots[0]["speed"]])
		check(float(shots[200]["dmg"]) > float(shots[0]["dmg"]) * 2.0, "...and hits harder (%.1f vs %.1f)" % [shots[200]["dmg"], shots[0]["dmg"]])
		check((shots[200]["col"] as Color) != (shots[0]["col"] as Color), "...and is brighter, tinted towards white-gold")
	var r0 := AttackRunner.release_params(0.2)
	var r1 := AttackRunner.release_params(1.0)
	check(r1.x < r0.x and r1.y > r0.y, "the release sound is lower and louder the longer it was charged (pitch %.2f -> %.2f, %.1f -> %.1f dB)" % [r0.x, r1.x, r0.y, r1.y])
	check(Sfx._sounds.has("release"), "there is a release sound")
	# 3. a charged projectile (Fireball is a Magic move: borrow its data on the Brawler's attack runner)
	var fb := MoveDB.get_move("fireball")
	check(fb.is_chargeable(), "Fireball can be charged")
	# the Pull Hook drags a container to the player instead of damaging it
	var crate := lv.spawn_prop("crate", Vector2(780.0, lv.ground_y - 1.0))
	await frames(20)
	f0.global_position = Vector2(500.0, lv.ground_y - 1.0)
	f0.facing = 1
	f0.state = "idle"
	var cx0 := crate.global_position.x
	var chp := crate.hp
	await frames(5)
	f0.start_attack(MoveDB.get_move_for("pull_hook", f0.class_id), PlayerInput.Btn.X)
	await frames(60)
	check(is_instance_valid(crate) and crate.global_position.x < cx0 - 120.0, "the Pull Hook drags a crate towards the player (%.0f -> %.0f)" % [cx0, crate.global_position.x if is_instance_valid(crate) else -1.0])
	check(is_instance_valid(crate) and crate.hp == chp and crate.state == "idle", "...without damaging or launching it")
	# the Pull Hook shows a tether out to its full reach even when nothing is hit, and sticks to what it hooks
	for n in get_tree().get_nodes_in_group("props"):
		n.queue_free()
	await frames(5)
	f0.global_position = Vector2(500.0, lv.ground_y - 1.0)
	f0.facing = 1
	f0.state = "idle"
	await frames(10)
	f0.start_attack(MoveDB.get_move_for("pull_hook", f0.class_id), PlayerInput.Btn.X)
	var whip: WhipFx = null
	for i in 20:
		await get_tree().physics_frame
		for n in lv.get_children():
			if n is WhipFx:
				whip = n
		if whip != null:
			break
	check(whip != null, "the Pull Hook throws a whip even though nothing is in range")
	if whip != null:
		var reach := absf(whip._tip(1.0).x - f0.global_position.x)
		check(reach >= 300.0, "...which reaches the move's full range (%.0f px)" % reach)
		check(whip._hooked == null, "...and is not hooked to anything")
	await frames(60)
	var crate2 := lv.spawn_prop("crate", Vector2(780.0, lv.ground_y - 1.0))
	await frames(20)
	f0.global_position = Vector2(500.0, lv.ground_y - 1.0)
	f0.state = "idle"
	await frames(10)
	f0.start_attack(MoveDB.get_move_for("pull_hook", f0.class_id), PlayerInput.Btn.X)
	var whip2: WhipFx = null
	for i in 25:
		await get_tree().physics_frame
		for n in lv.get_children():
			if n is WhipFx and n != whip:
				whip2 = n
		if whip2 != null and whip2._hooked != null:
			break
	check(whip2 != null and whip2._hooked == crate2, "the whip sticks to the crate it hooks")
	await frames(60)
	# class stat bars: every class has a clear low and a clear high
	for cid in ClassData.IDS:
		var r: Dictionary = ClassData.get_class_data(cid)["ratings"]
		var lo := 99
		var hi := 0
		for k in r:
			lo = mini(lo, int(r[k]))
			hi = maxi(hi, int(r[k]))
		check(lo <= 4 and hi >= 7, "%s: lowest stat %d, highest %d (a real spread)" % [cid, lo, hi])
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
