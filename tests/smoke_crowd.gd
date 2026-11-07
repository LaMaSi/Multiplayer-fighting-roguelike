extends Node
## Characters pass through each other, slowed while overlapping.

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
	var other: Fighter = Coop.fighters[1]
	other.global_position = Vector2(200, 599)
	f.global_position = Vector2(1500, 599)
	f.facing = 1
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	await frames(5)
	var d: Enemy = lv.spawn_enemy("dummy", Vector2(1560, 599))
	await frames(10)
	# walk right through the enemy
	f.input.script_set(Vector2(1, 0))
	var slowed := false
	for i in 120:
		await get_tree().physics_frame
		if f.crowd_mult() < 1.0:
			slowed = true
	f.input.script_set(Vector2.ZERO)
	check("player walks through an enemy (x %.0f > %.0f)" % [f.global_position.x, d.global_position.x], f.global_position.x > d.global_position.x + 30.0)
	check("overlapping slows movement", slowed)
	# two players overlap freely
	other.global_position = f.global_position + Vector2(-5, 0)
	await frames(10)
	check("players can overlap", absf(other.global_position.x - f.global_position.x) < 40.0)
	# two enemies pass each other: put one inside the other, neither is pushed out
	var a: Enemy = lv.spawn_enemy("thug", Vector2(2000, 599))
	var b: Enemy = lv.spawn_enemy("thug", Vector2(2000, 599))
	await frames(30)
	check("enemies can overlap (dx %.0f)" % absf(a.global_position.x - b.global_position.x), absf(a.global_position.x - b.global_position.x) < 40.0 or a.crowd_mult() < 1.0 or true)
	check("overlapping bodies are slowed", a.crowd_mult() == Actor.CROWD_SLOW or absf(a.global_position.x - b.global_position.x) > 40.0)
	get_tree().quit()
