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
	check(int(hm.get("dir", -9)) == 0, "haymaker sends FORWARD (%s)" % str(hm))
	var dk := MoveDB.card_dir(MoveDB.get_move("dive_kick"))
	check(int(dk.get("dir", -9)) == 6 and dk.get("ground") == "bounce", "dive kick sends DOWN and bounces (%s)" % str(dk))
	var jb := MoveDB.card_dir(MoveDB.get_move("jab"))
	check(int(jb.get("dir", -9)) == -1, "jab does not send (%s)" % str(jb))
	var sent := {}
	for id in MoveDB.all_player_moves():
		var m := MoveDB.get_move(id)
		if m != null:
			var cd := MoveDB.card_dir(m)
			if not cd.is_empty():
				sent[int(cd["dir"])] = true
	print("  directions in use: ", sent.keys())
	check(sent.size() >= 4, "several different directions are in use")

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
	await frames(90)
	check(d.state in ["down", "getup", "idle"] and d.is_on_floor(), "stop-type spike ends flat on the floor (%s)" % d.state)

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
