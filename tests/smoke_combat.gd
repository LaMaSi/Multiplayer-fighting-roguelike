extends Node
## Combat / co-op / enemies headless test. Run:
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_combat.tscn
## Exit code = number of failed checks. Also grep stderr for "SCRIPT ERROR".

var fails := 0
var level: LevelBase
var f1: Fighter
var f2: Fighter
var p1: PlayerInput
var p2: PlayerInput

const A := PlayerInput.Btn.JUMP
const X := PlayerInput.Btn.X
const Y := PlayerInput.Btn.Y
const B := PlayerInput.Btn.B
const RT := PlayerInput.Btn.INTERACT


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap(p: PlayerInput, btn: int, dir := Vector2.ZERO) -> void:
	p.script_set(dir, [btn])
	await frames(1)
	p.script_set(dir, [])


func place(f: Actor, pos: Vector2, face := 1) -> void:
	f.global_position = pos
	f.velocity = Vector2.ZERO
	f.facing = face
	if f is Fighter:
		f.state = "idle"
		f.hp = f.max_hp
		f.invuln = 0.0
		f.attack.interrupt()


func load_level(path: String) -> void:
	if level != null:
		level.queue_free()
		await frames(2)
	level = load(path).instantiate()
	add_child(level)
	await frames(5)
	f1 = level.fighters[0]
	f2 = level.fighters[1]
	p1 = get_node("/root/Inp").players[0]
	p2 = get_node("/root/Inp").players[1]
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)


func clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	await frames(2)


func spawn_dummy(pos: Vector2) -> Enemy:
	var d := level.spawn_enemy("dummy", pos)
	await frames(2)
	return d


func _ready() -> void:
	RunState.classes = ["", ""]  # this test is written for the legacy no-class fighter
	await _run()
	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(fails)


func _run() -> void:
	await load_level("res://scenes/training.tscn")
	await clear_enemies()
	await frames(20)

	print("[basic hit + hit reaction]")
	place(f1, Vector2(1000, 599))
	place(f2, Vector2(300, 599))
	var d := await spawn_dummy(Vector2(1070, 599))
	var hp0 := d.hp
	await tap(p1, X)
	await frames(8)
	check(d.hp < hp0, "jab damages the dummy (%.1f)" % (hp0 - d.hp))
	check(Coop.combo >= 1, "combo counter ticks (%d)" % Coop.combo)
	await frames(40)

	print("[side slot: left and right are the same move]")
	await clear_enemies()
	for side in [-1, 1]:
		place(f1, Vector2(1500, 599), 1)
		var sd := await spawn_dummy(Vector2(1500 + side * 80, 599))
		var sh := sd.hp
		await tap(p1, X, Vector2(side, 0))
		await frames(30)
		check(sd.hp < sh and f1.facing == side, "X+%s hits the dummy on that side with the same move (facing %d)" % ["right" if side > 0 else "left", f1.facing])
		sd.queue_free()
		await frames(30)
	await clear_enemies()
	place(f1, Vector2(1000, 599))
	d = await spawn_dummy(Vector2(1070, 599))

	print("[jab chain]")
	var seen := {}
	await tap(p1, X)
	for i in 3:
		await frames(7)
		await tap(p1, X)
		if f1.attack.active:
			seen[f1.attack.move.id] = true
		await frames(3)
	await frames(6)
	check(seen.has("jab2") or seen.has("jab3"), "tapping X chains (%s)" % str(seen.keys()))
	await frames(80)

	print("[launcher + juggle relay]")
	await clear_enemies()
	Coop.reset_run()
	Coop.fighters.append(f1)
	Coop.fighters.append(f2)
	place(f1, Vector2(1000, 599), 1)
	place(f2, Vector2(1140, 599), -1)
	d = await spawn_dummy(Vector2(1070, 599))
	await frames(5)
	await tap(p1, X, Vector2(0, -1))
	await frames(16)
	check(d.state == "launched", "uppercut launches (state=%s)" % d.state)
	check(MoveDB.SLOTS.size() == 12 and MoveDB.STARTER.size() == 4, "12 slots, 4 starter moves")
	f2.loadout["X"] = "anti_air"
	await frames(0)
	await tap(p2, X)
	await frames(14)
	f2.loadout = MoveDB.STARTER.duplicate()
	check(Coop.relay >= 1, "partner hit on airborne enemy = relay (relay=%d, combo=%d)" % [Coop.relay, Coop.combo])
	await frames(90)

	print("[friendly fire]")
	place(f1, Vector2(1500, 599), 1)
	place(f2, Vector2(1560, 599), 1)
	Coop.friendly_fire = true
	var hp2 := f2.hp
	await tap(p1, X)
	await frames(10)
	check(f2.hp < hp2, "friendly fire damages partner (%.1f)" % (hp2 - f2.hp))
	await frames(60)
	place(f1, Vector2(1500, 599), 1)
	place(f2, Vector2(1560, 599), 1)
	Coop.friendly_fire = false
	hp2 = f2.hp
	await tap(p1, X)
	await frames(10)
	check(f2.hp == hp2, "friendly fire OFF: no damage")
	Coop.friendly_fire = true
	await frames(60)

	print("[crouch avoids HIGH attacks only]")
	await clear_enemies()
	place(f1, Vector2(1000, 599), 1)
	f1.invuln = 0.0
	p1.script_set(Vector2(0, 1), [])
	await frames(14)
	check(f1.is_crouched(), "holding down crouches (crouch=%.2f)" % f1._crouch)
	var hi := HitInfo.new()
	hi.team = "enemy"
	hi.height = "high"
	hi.dmg = 5.0
	var hp_c := f1.hp
	check(not f1.take_hit(hi) and f1.hp == hp_c, "crouching avoids a HIGH hit")
	var mid := HitInfo.new()
	mid.team = "enemy"
	mid.height = "mid"
	mid.dmg = 5.0
	check(f1.take_hit(mid) and f1.hp < hp_c, "crouching does not avoid a MID hit")
	await frames(80)
	p1.script_set(Vector2.ZERO, [])
	await frames(14)
	f1.invuln = 0.0
	var hi2 := HitInfo.new()
	hi2.team = "enemy"
	hi2.height = "high"
	hi2.dmg = 5.0
	check(f1.take_hit(hi2), "standing takes a HIGH hit")
	await frames(60)

	print("[all 30 moves execute]")
	await clear_enemies()
	var dist := {"fireball": 220, "boomerang": 220, "spread_shot": 220, "ground_wave": 220, "pull_hook": 250,
		"teleport_strike": 300, "pocket_mine": 40, "grab_throw": 60, "dive_kick": 130, "cyclone": 40, "back_kick": -70}
	var no_damage := ["guard", "parry", "reflect", "rage_taunt", "boost_spark", "ally_toss", "grab_throw", "pull_hook", "dive_kick"]
	for id in MoveDB.POOL:
		await clear_enemies()
		Coop.reset_run()
		Coop.fighters.append(f1)
		Coop.fighters.append(f2)
		place(f1, Vector2(1000, 599), 1)
		place(f2, Vector2(300, 599), 1)
		f1.loadout["X"] = id
		var off: int = dist.get(id, 70)
		var dm := await spawn_dummy(Vector2(1000 + off, 599))
		await frames(3)
		var h0 := dm.hp
		var x0 := dm.global_position.x
		var air := id == "dive_kick"
		if air:
			place(f1, Vector2(1000, 450), 1)
		p1.script_set(Vector2.ZERO, [X])
		await frames(1)
		p1.script_set(Vector2.ZERO, [X] if id == "guard" else [])
		var started := f1.attack.active or air
		var longest := 0
		for i in 240:
			await frames(1)
			if id == "guard" and i == 30:
				p1.script_set(Vector2.ZERO, [])
			if not f1.attack.active and f1.state in ["idle", "walk", "land", "jump", "fall"]:
				longest = i
				break
		if id == "pocket_mine":
			await frames(45)  # the mine arms after ~0.45 s
		var damaged := dm.hp < h0 or absf(dm.global_position.x - x0) > 12.0 or dm.state != "idle"
		var ok := longest > 0 or id == "dive_kick"
		check(ok, "%s: starts and finishes (%d frames)" % [id, longest])
		if not (id in no_damage):
			check(damaged, "%s: hit the dummy (dmg %.1f)" % [id, h0 - dm.hp])
		await frames(30)
	f1.loadout = MoveDB.STARTER.duplicate()

	print("[guard blocks / parry counters]")
	await clear_enemies()
	place(f1, Vector2(1000, 599), 1)
	f1.loadout["X"] = "guard"
	var th := level.spawn_enemy("thug", Vector2(1075, 599))
	th.invuln = 0.0
	await frames(2)
	p1.script_set(Vector2.ZERO, [X])
	await frames(30)
	check(f1.guard_t > 0, "guard active while held")
	var gh := f1.hp
	var info := HitInfo.new()
	info.attacker = th
	info.team = "enemy"
	info.dmg = 20.0
	f1.take_hit(info)
	check(gh - f1.hp < 5.0, "guard reduces damage (%.1f)" % (gh - f1.hp))
	p1.script_set(Vector2.ZERO, [])
	await frames(30)
	f1.loadout["X"] = "parry"
	th.state = "idle"
	th.invuln = 0.0
	var thp := th.hp
	await tap(p1, X)
	await frames(5)
	var info2 := HitInfo.new()
	info2.attacker = th
	info2.team = "enemy"
	info2.dmg = 20.0
	var ph := f1.hp
	f1.take_hit(info2)
	check(f1.hp == ph, "parry negates damage")
	check(th.hp < thp, "parry counters the attacker (%.1f)" % (thp - th.hp))
	f1.loadout = MoveDB.STARTER.duplicate()
	await frames(60)

	print("[enemies fight back]")
	for kind in ["thug", "biker", "thrower", "boss_street"]:
		await clear_enemies()
		Coop.reset_run()
		Coop.fighters.append(f1)
		Coop.fighters.append(f2)
		place(f1, Vector2(1000, 599), 1)
		place(f2, Vector2(300, 599), 1)
		f1.max_hp = 5000.0
		f1.hp = 5000.0
		var e := level.spawn_enemy(kind, Vector2(1450, 599))
		var attacked := false
		for i in 600:
			await frames(1)
			if e.state == "attack":
				attacked = true
			if attacked and f1.hp < 5000.0:
				break
		check(attacked, "%s enters attack state" % kind)
		check(f1.hp < 5000.0, "%s damages the player (%.1f)" % [kind, 5000.0 - f1.hp])
		f1.max_hp = 100.0
	await clear_enemies()

	print("[enemy dies + juggle count]")
	place(f1, Vector2(1000, 599), 1)
	f1.hp = 100.0
	f1.max_hp = 100.0
	var vic := level.spawn_enemy("thug", Vector2(1070, 599))
	await frames(40)
	vic.invuln = 0.0
	var lethal := HitInfo.new()
	lethal.attacker = f1
	lethal.team = "player"
	lethal.dmg = 9999.0
	lethal.kb = Vector2(200, -300)
	vic.take_hit(lethal)
	for i in 150:
		await frames(1)
		if not is_instance_valid(vic):
			break
	check(not is_instance_valid(vic) or vic.state == "dead", "thug defeated")

	print("[crates + pickups]")
	await clear_enemies()
	place(f1, Vector2(2000, 599), 1)
	f1.hp = 40.0
	var crate := level.spawn_prop("crate", Vector2(2070, 599), "hp_m")
	await frames(3)
	for i in 4:
		await tap(p1, X)
		await frames(22)
		if not is_instance_valid(crate):
			break
	check(not is_instance_valid(crate) or crate.state == "dead", "crate breaks when hit")
	await frames(30)
	check(get_tree().get_nodes_in_group("pickups").size() >= 1 or f1.hp > 40.0, "crate dropped a pickup")
	p1.script_set(Vector2(1, 0))
	await frames(70)
	p1.script_set(Vector2.ZERO)
	await frames(30)
	check(f1.hp > 40.0, "pickup heals (%.0f hp)" % f1.hp)
	var crate2 := level.spawn_prop("barrel", Vector2(f1.global_position.x + 40, 599))
	await frames(10)
	await tap(p1, RT)
	await frames(3)
	check(f1.held == crate2, "RT picks up a barrel")
	var tgt := level.spawn_enemy("dummy", Vector2(f1.global_position.x + 220, 599))
	await frames(3)
	var th0 := tgt.hp
	await tap(p1, RT)
	await frames(60)
	check(tgt.hp < th0, "thrown barrel damages enemy (%.1f)" % (th0 - tgt.hp))

	print("[downed + revive]")
	await clear_enemies()
	Coop.reset_run()
	Coop.fighters.append(f1)
	Coop.fighters.append(f2)
	place(f1, Vector2(2400, 599), 1)
	place(f2, Vector2(2450, 599), -1)
	var kill := HitInfo.new()
	kill.attacker = null
	kill.team = "enemy"
	kill.dmg = 500.0
	kill.kb = Vector2(100, -200)
	kill.kind = "launch"
	f1.take_hit(kill)
	await frames(90)
	check(f1.state == "downed", "P1 goes down (state=%s)" % f1.state)
	check(not Coop.is_over, "run continues while partner stands")
	place(f2, Vector2(f1.global_position.x + 40, 599), -1)
	p2.script_set(Vector2.ZERO, [RT])
	await frames(150)
	p2.script_set(Vector2.ZERO, [])
	check(f1.state != "downed" and f1.hp > 0.0, "partner revives P1 (hp %.0f, state %s)" % [f1.hp, f1.state])
	check(Coop.revives_left == 2, "revive budget decreased (%d)" % Coop.revives_left)

	print("[ally toss]")
	await clear_enemies()
	place(f1, Vector2(1000, 599), 1)
	place(f2, Vector2(1050, 599), 1)
	f1.loadout["Y"] = "ally_toss"
	var td := await spawn_dummy(Vector2(1500, 599))
	var tdh := td.hp
	await tap(p1, Y)
	await frames(100)
	check(td.hp < tdh or f2.global_position.x > 1250.0, "partner flies when tossed (x=%.0f, dummy dmg %.1f)" % [f2.global_position.x, tdh - td.hp])
	f1.loadout = MoveDB.STARTER.duplicate()

	print("[game over when both down]")
	Coop.reset_run()
	Coop.fighters.append(f1)
	Coop.fighters.append(f2)
	await clear_enemies()
	place(f1, Vector2(2400, 599), 1)
	place(f2, Vector2(2600, 599), 1)
	var over := [false]
	Coop.game_over.connect(func(): over[0] = true)
	f1.take_hit(kill)
	f2.take_hit(kill)
	await frames(120)
	check(over[0], "game over fires when both players are down")

	print("[streets level encounters]")
	Coop.friendly_fire = true
	await load_level("res://scenes/streets.tscn")
	check(level.encounters.size() == 5, "streets has 5 encounters")
	place(f1, Vector2(1400, 599), 1)
	place(f2, Vector2(1340, 599), 1)
	await frames(10)
	check(level._locked, "arena locks when players reach the first encounter")
	check(level.alive_enemies() > 0, "enemies spawned (%d)" % level.alive_enemies())
	for i in 3:
		for e in level._enemies:
			if is_instance_valid(e):
				e.queue_free()
		await frames(20)
	check(not level._locked and level._enc_idx == 1, "arena unlocks after waves are cleared")
	level._enc_idx = 4
	place(f1, Vector2(6100, 599), 1)
	place(f2, Vector2(6040, 599), 1)
	await frames(10)
	var boss: Enemy = null
	for n in get_tree().get_nodes_in_group("boss"):
		boss = n
	check(boss != null, "boss spawns in the final encounter")
	if boss != null:
		boss.invuln = 0.0
		var bi := HitInfo.new()
		bi.attacker = f1
		bi.team = "player"
		bi.dmg = 9999.0
		bi.kb = Vector2(200, -300)
		bi.kind = "launch"
		boss.take_hit(bi)
		await frames(150)
	check(level._cleared, "level clear after the boss falls")
