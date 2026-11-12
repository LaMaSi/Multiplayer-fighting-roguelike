extends Node
## Send directions, meteor spikes, clashes, stun meter and screen-edge bounce. Run:
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_newcombat.tscn
## Exit code = number of failed checks. Also grep stderr for "SCRIPT ERROR".

var fails := 0
var level: LevelBase
var f1: Fighter
var f2: Fighter
var p1: PlayerInput


func check(cond: bool, msg: String) -> void:
	print("  PASS  " if cond else "  FAIL  ", msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(f: Actor, pos: Vector2, face := 1) -> void:
	f.global_position = pos
	f.velocity = Vector2.ZERO
	f.facing = face
	f.state = "idle"
	f.hp = f.max_hp
	f.invuln = 0.0
	f.attack.interrupt()


func hit(target: Actor, attacker: Actor, dmg: float, kind := "normal", kb := Vector2(100, 0), dir := -1) -> bool:
	var info := HitInfo.new()
	info.attacker = attacker
	info.team = attacker.team
	info.dmg = dmg
	info.kind = kind
	info.kb = kb
	info.dir = dir
	info.ground_fx = MoveDB.default_ground(dir)
	info.stun = 12
	info.pos = target.center()
	info.friendly = target.team == attacker.team
	if info.friendly:
		info.dmg = 0.0
	return target.take_hit(info)


func _ready() -> void:
	RunState.classes = ["", ""]
	await _run()
	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(fails)


func _run() -> void:
	level = load("res://scenes/training.tscn").instantiate()
	add_child(level)
	await frames(5)
	f1 = level.fighters[0]
	f2 = level.fighters[1]
	p1 = get_node("/root/Inp").players[0]
	p1.script_set(Vector2.ZERO)
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	await frames(20)

	print("[card directions]")
	var hm := MoveDB.card_dir(MoveDB.get_move("haymaker"))
	check(bool(hm.get("sends", false)) and is_equal_approx(float(hm["ang"]), 10.0), "haymaker sends at its own angle, 10 degrees (%s)" % str(hm))
	var dk := MoveDB.card_dir(MoveDB.get_move("dive_kick"))
	check(is_equal_approx(float(dk.get("ang", 0.0)), -90.0) and dk.get("name") == "SPIKE", "dive kick is a spike, -90 degrees (%s)" % str(dk))
	var jb := MoveDB.card_dir(MoveDB.get_move("jab"))
	check(not bool(jb.get("sends", true)), "jab only staggers (%s)" % str(jb))
	var bk := MoveDB.card_dir(MoveDB.get_move("bicycle_kick"))
	check(is_equal_approx(float(bk.get("ang", 0.0)), 180.0) and "bicycle_kick" in ClassData.Y_POOL, "the overhead kick is a Y move that sends behind you (%s)" % str(bk))
	var sent := {}
	var staggers: Array = []
	var spikes := 0
	var backs := 0
	for id in MoveDB.all_player_moves():
		var m := MoveDB.get_move(id)
		if m != null:
			var cd := MoveDB.card_dir(m)
			if cd.is_empty() or cd.get("name") == "PULL":
				continue
			if not bool(cd["sends"]):
				staggers.append(id)
				continue
			var a := float(cd["ang"])
			sent[int(round(a))] = true
			spikes += 1 if a < -45.0 else 0
			backs += 1 if a > 135.0 else 0
			if not (is_equal_approx(a, -90.0) or is_equal_approx(a, 180.0) or (a >= 0.0 and a <= 90.0)):
				check(false, "%s: angle %.0f is 0..90, -90 or 180" % [id, a])
	print("  angles in use: ", sent.keys(), "  staggering moves: ", staggers)
	check(sent.size() >= 10, "moves have their own angles (%d different ones)" % sent.size())
	check(spikes >= 2 and backs >= 2, "a few spikes (%d) and sends behind the player (%d)" % [spikes, backs])
	check(staggers.size() <= 3, "only a few moves stagger instead of sending: %s" % str(staggers))

	print("[meteor + ground effects]")
	var d := level.spawn_enemy("dummy", Vector2(1500, 599))
	place(f1, Vector2(1450, 599))
	await frames(3)
	d.global_position = Vector2(1500, 400)
	d.velocity = Vector2.ZERO
	await frames(2)
	var hp0 := d.hp
	hit(d, f1, 10.0, "launch", Vector2(150, 900), 6)
	check(d.state == "launched" and d.velocity.y > 800.0, "down-angled hit on an airborne enemy spikes it (vy %.0f)" % d.velocity.y)
	check(d.hp < hp0 - 10.0, "meteor bonus damage (%.1f)" % (hp0 - d.hp))
	# no hard knockdowns: a spiked enemy rebounds off the floor, and it never lies down afterwards
	var flat := false
	var rebound := false
	for i in 150:
		await get_tree().physics_frame
		flat = flat or d.state in ["down", "getup"]
		rebound = rebound or (d.state == "launched" and d.velocity.y < -100.0)
	check(rebound, "a spiked enemy bounces back up off the floor")
	check(not flat and d.state in ["idle", "hurt", "walk"] and d.is_on_floor(), "and lands on its feet, never knocked flat (%s)" % d.state)

	print("[send angles]")
	# a real move on a grounded enemy: launched along the move's angle, far enough to reach a partner, no knockdown
	for spec in [["haymaker", 10.0], ["uppercut", 80.0], ["bicycle_kick", 180.0], ["pillar_smash", -90.0]]:
		place(f1, Vector2(1400, 599))
		f1.facing = 1
		place(d, Vector2(1460, 599))
		d.hp = d.max_hp
		d.stun_meter = 0.0
		d.hit_chain = 0
		d.invuln = 0.0
		d.state = "idle"
		await frames(4)
		var x0 := d.global_position.x
		f1.start_attack(MoveDB.get_move(String(spec[0])))
		var v0 := Vector2.ZERO
		var far := 0.0
		var knocked := false
		for i in 150:
			await get_tree().physics_frame
			if v0 == Vector2.ZERO and d.state == "launched" and d.freeze == 0:
				v0 = d.velocity
			far = d.global_position.x - x0 if absf(d.global_position.x - x0) > absf(far) else far
			knocked = knocked or d.state in ["down", "getup"]
		var want := float(spec[1])
		var ok := false
		if want < -45.0:
			ok = v0.y < -400.0 and absf(v0.x) < 120.0  # grounded spike: popped straight up off the floor
		elif want > 135.0:
			ok = v0.x < -400.0 and far < -150.0  # behind the attacker
		elif want > 60.0:
			ok = v0.y < -600.0 and v0.x >= 0.0
		else:
			ok = v0.x > 500.0 and far > 200.0
		check(ok, "%s (%.0f deg) sends the enemy as its angle says (v %s, travelled %.0f px)" % [spec[0], want, str(v0.round()), far])
		check(not knocked, "%s: the enemy is not knocked down" % spec[0])
		f1.attack.interrupt()
		f1.state = "idle"
		await frames(20)

	print("[stun meter]")
	place(d, Vector2(1500, 599))
	d.stun_meter = 0.0
	d.hit_chain = 0
	var n := 0
	while d.state != "stunned" and n < 30:
		d.invuln = 0.0
		d.hit_chain = 0
		hit(d, f1, 12.0, "normal", Vector2(60, 0))
		await frames(30)
		n += 1
	check(d.state == "stunned", "enemy is stunned after %d hits" % n)
	await frames(60)
	check(d.state == "stunned", "still stunned a second later")
	d.invuln = 0.0
	hit(d, f1, 5.0)
	check(d.state != "stunned", "a hit wakes the stunned enemy (%s)" % d.state)
	await frames(60)

	print("[players wake each other]")
	place(f2, Vector2(900, 599))
	f2.stun_meter = 0.0
	f2._begin_stun()
	check(f2.state == "stunned", "partner is stunned")
	var hpb := f2.hp
	hit(f2, f1, 10.0)
	check(f2.state != "stunned" and f2.hp == hpb, "partner hit wakes without damage (%s, %.0f hp)" % [f2.state, f2.hp])
	await frames(40)
	f2._begin_stun()
	f2.grab(f1)
	check(f2.state == "grabbed", "grabbing a stunned partner wakes it")
	f2.release()
	await frames(40)

	print("[stun timeout]")
	place(f2, Vector2(900, 599))
	f2._begin_stun()
	await frames(5 * 60 + 20)
	check(f2.state != "stunned", "stun ends by itself after 5 seconds (%s)" % f2.state)

	print("[clash]")
	for e in get_tree().get_nodes_in_group("hurt_enemy"):
		e.queue_free()
	await frames(5)
	place(f1, Vector2(1000, 599))
	var c := level.spawn_enemy("dummy", Vector2(1060, 599))
	await frames(3)
	c.facing = -1
	c.start_attack(MoveDB.get_move("jab"))
	c.attack.frame = 4
	f1.start_attack(MoveDB.get_move("jab"))
	f1.attack.frame = 4
	await frames(12)
	check(c.state == "hurt" or c.stun_frames > 0 or c.hp < c.max_hp, "enemy swing is beaten in a clash (state %s, stun %d)" % [c.state, c.stun_frames])
	check(f1.hp >= f1.max_hp - 0.1, "the player takes no damage from the clashing swing (%.1f)" % f1.hp)

	print("[screen edge bounce]")
	for e in get_tree().get_nodes_in_group("hurt_enemy"):
		e.queue_free()
	await frames(5)
	var b := level.spawn_enemy("dummy", Vector2(Coop.bounds.position.x + 120.0, 599))
	await frames(3)
	b.thrown(Vector2(-1100, -80), f1)
	var bounced := false
	var minx := 1e9
	for i in 40:
		await frames(1)
		minx = minf(minx, b.global_position.x)
		if b.velocity.x > 100.0:
			bounced = true
	check(bounced, "a launched enemy rebounds off the left screen edge")
	check(minx >= Coop.bounds.position.x, "and never leaves the screen (min x %.0f)" % minx)
