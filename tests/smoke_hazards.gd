extends Node
## Spike traps, bumpers and springs.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var f: Fighter = Coop.fighters[0]
	var other: Fighter = Coop.fighters[1]
	other.global_position = Vector2(100, 599)
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("hazards"):
		n.queue_free()
	await frames(3)
	# --- spikes
	var sp := SpikeTrap.new()
	sp.position = Vector2(1500, 600)
	lv.add_child(sp)
	var e: Enemy = lv.spawn_enemy("brute", Vector2(1700, 599))
	await frames(60)
	e.max_hp = 9999.0
	e.hp = 9999.0
	e.last_hitter = f
	e.invuln = 0.0
	# throw the enemy into the spikes: airborne when it lands on them
	e.global_position = Vector2(1500, 500)
	e.thrown(Vector2(0, 400), f)
	var h0 := e.hp
	await frames(40)
	check("an enemy thrown into spikes takes a big hit (%.0f lost)" % (h0 - e.hp), h0 - e.hp >= 30.0)
	check("the damage keeps the combo going", Coop.combo >= 1)
	var fhp := f.hp
	f.global_position = Vector2(1500, 599)
	await frames(10)
	check("a player standing on spikes is hurt a little (%.0f)" % (fhp - f.hp), f.hp < fhp and fhp - f.hp <= 12.0)
	f.global_position = Vector2(900, 599)
	e.global_position = Vector2(2600, 599)
	# --- bumper
	var bp := Bumper.new()
	bp.position = Vector2(1000, 600)
	lv.add_child(bp)
	f.global_position = Vector2(960, 599)
	f.velocity = Vector2(300, 0)
	await frames(3)
	check("a bumper flings the player away (vx %.0f)" % f.velocity.x, f.velocity.x < -400.0 or f._flung_t > 0.0)
	# --- spring
	f.global_position = Vector2(1800, 599)
	var spr := lv.spawn_prop("spring", Vector2(1830, 599))
	await frames(20)
	f.velocity = Vector2.ZERO
	f.global_position = Vector2(1830, 590)
	await frames(4)
	check("a spring launches whoever lands on it (vy %.0f)" % f.velocity.y, f.velocity.y < -700.0)
	# --- throw a spring: it lands and becomes a pad
	f.input.script_set(Vector2.ZERO)
	f.global_position = Vector2(270, 599)
	f.velocity = Vector2.ZERO
	f._flung_t = 0.0
	f.state = "idle"
	f.facing = 1
	var spr2 := lv.spawn_prop("spring", Vector2(330, 599))
	await frames(15)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(4)
	check("a spring can be picked up", f.held == spr2)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(90)
	check("a thrown spring survives and lands as a pad", is_instance_valid(spr2) and spr2.state == "idle" and spr2.global_position.x > 450.0)
	get_tree().quit()
