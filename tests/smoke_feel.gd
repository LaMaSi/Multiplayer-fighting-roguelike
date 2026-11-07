extends Node
## Snappy movement, enemies that climb platforms, wave spawns between the players, moving platforms, no frozen LT cancel.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(40)
	var f: Fighter = Coop.fighters[0]
	var o: Fighter = Coop.fighters[1]
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	# walk vs run
	f.global_position = Vector2(300, 599)
	o.global_position = Vector2(100, 599)
	f.input.script_set(Vector2(0.45, 0))
	await frames(40)
	var walk_v := f.velocity.x
	f.input.script_set(Vector2(1, 0))
	await frames(40)
	var run_v := f.velocity.x
	check("walk %.0f is clearly slower than run %.0f" % [walk_v, run_v], walk_v > 100.0 and run_v > walk_v * 2.0)
	f.input.script_set(Vector2.ZERO)
	await frames(12)
	check("stops quickly", absf(f.velocity.x) < 20.0)
	# enemy climbs to a platform where the player stands
	var py := lv.ground_y - 150.0
	var plat := Rect2(900, py, 300, 16)
	lv.platforms.append(plat)
	lv._make_body(plat, 2, true)
	f.global_position = Vector2(1050, py - 2.0)
	o.global_position = Vector2(100, 599)
	await frames(10)
	var e: Enemy = lv.spawn_enemy("thug", Vector2(700, 599))
	e.invuln = 0.0
	var up := false
	for i in 360:
		await get_tree().physics_frame
		if e.global_position.y < lv.ground_y - 110.0:
			up = true
			break
	check("a thug climbs onto the platform to reach the player (y %.0f)" % e.global_position.y, up)
	e.queue_free()
	# waves appear between the players
	f.global_position = Vector2(1400, 599)
	o.global_position = Vector2(1900, 599)
	lv._arena = Vector2(900, 2400)
	lv._spawn_wave([["thug", 2]])
	await frames(2)
	var xs: Array[float] = []
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy and n != e:
			xs.append(n.global_position.x)
	var between := xs.size() == 2
	for x in xs:
		between = between and x > 1350.0 and x < 1950.0
	check("wave spawns between the two players %s" % str(xs), between)
	# moving platform carries a fighter
	var ms := MovingPlatform.new()
	lv.add_child(ms)
	ms.setup(Rect2(2200, 540, 160, 16), false, 100.0, 4.0, 0.0, Color.WHITE)
	f.global_position = Vector2(2280, 520)
	f.velocity = Vector2.ZERO
	await frames(30)
	var x0 := f.global_position.x
	await frames(30)
	check("a moving platform carries its rider (%.0f -> %.0f)" % [x0, f.global_position.x], absf(f.global_position.x - x0) > 15.0 and f.is_on_floor())
	# partner-aimed knockback
	var hi := HitInfo.new()
	hi.attacker = f
	hi.kb = Vector2(300, -500)
	f.global_position = Vector2(400, 599)
	o.global_position = Vector2(1000, 599)
	Coop._aim_at_partner(hi)
	check("knockback toward the partner is scaled to land near them (%.0f)" % hi.kb.x, hi.kb.x != 300.0 and hi.kb.x >= 225.0 and hi.kb.x <= 405.0)
	hi.kb = Vector2(-300, -500)
	Coop._aim_at_partner(hi)
	check("knockback away from the partner is untouched", hi.kb.x == -300.0)
	# LT cancel that finds no move must not leave the fighter frozen
	f.global_position = Vector2(500, 599)
	f.meter = 100.0
	f.loadout["X_UP"] = "uppercut"
	f.input.script_set(Vector2(0, -1), [PlayerInput.Btn.X])
	await frames(3)
	f.input.script_set(Vector2.ZERO, [])
	await frames(70)
	check("uppercut ends and the fighter is free again (%s)" % f.state, f.state != "attack")
	f.state = "attack"  # regression: attack state with no running move (a failed LT cancel) used to freeze the fighter
	f.attack.active = false
	await frames(3)
	check("a dead attack state frees the fighter", f.state != "attack")
	get_tree().quit()
