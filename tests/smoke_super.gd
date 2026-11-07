extends Node
## Supers: the motion (down, down-forward, forward, twice) plus X / B spends 50 % meter and starts the super.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _motion(f: Fighter, button: int) -> void:
	for d in [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
		f.input.script_set(d)
		await frames(3)
	f.input.script_set(Vector2(1, 0), [button])
	await frames(2)
	f.input.script_set(Vector2.ZERO)


func _ready() -> void:
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(40)
	var f: Fighter = Coop.fighters[0]
	var other: Fighter = Coop.fighters[1]
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await frames(3)
	var dummy: Enemy = lv.spawn_enemy("dummy", Vector2(980, 599))
	await frames(5)
	for c in ["brawler", "sword", "hammer", "magic"]:
		dummy.hp = dummy.max_hp
		dummy.global_position = Vector2(980, 599)
		dummy.velocity = Vector2.ZERO
		dummy.state = "idle"
		f.apply_class(c)
		f.global_position = Vector2(1085, 599)
		other.global_position = Vector2(300, 599)
		f.state = "idle"
		f.attack.interrupt()
		f.facing = 1
		f.meter = 100.0
		f.hp = f.max_hp
		await frames(20)
		await _motion(f, PlayerInput.Btn.B)
		await frames(2)
		dummy.global_position = Vector2(f.global_position.x + 70.0, 599.0)
		dummy.invuln = 0.0
		dummy.velocity = Vector2.ZERO
		check("%s: motion + B starts %s" % [c, MoveDBSupers.CLASS_SUPER[c]], f.attack.active and f.attack.move != null and f.attack.move.id == MoveDBSupers.CLASS_SUPER[c])
		check("%s: the super cost 50%% meter (%.0f left)" % [c, f.meter], f.meter < 60.0)
		var low := dummy.hp
		for k in 160:
			await get_tree().physics_frame
			low = minf(low, dummy.hp)
		check("%s super damages an enemy in front (%.0f)" % [c, dummy.max_hp - low], low < dummy.max_hp - 10.0)
		f.attack.interrupt()
	f.global_position = Vector2(1085, 599)
	f.state = "idle"
	f.meter = 100.0
	await frames(30)
	await _motion(f, PlayerInput.Btn.X)
	await frames(2)
	check("motion + X starts the generic super", f.attack.active and f.attack.move != null and f.attack.move.id == "super_generic")
	check("a super is invulnerable while it winds up", f.invuln > 0.1 or f.attack.active)
	await frames(100)
	f.attack.interrupt()
	f.state = "idle"
	f.meter = 20.0
	await frames(20)
	await _motion(f, PlayerInput.Btn.B)
	await frames(2)
	check("not enough meter: no super", not (f.attack.active and f.attack.move != null and f.attack.move.tier == "super"))
	# LT empowers a move for a little meter
	f.attack.interrupt()
	f.state = "idle"
	f.meter = 60.0
	f.global_position = Vector2(1085, 599)
	await frames(30)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.EMPOWER, PlayerInput.Btn.X])
	await frames(2)
	f.input.script_set(Vector2.ZERO)
	await frames(2)
	check("holding LT empowers the move for 10 meter (%.0f left)" % f.meter, f.attack.empowered and f.meter < 55.0)
	get_tree().quit()
