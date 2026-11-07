extends Node
## RT dash phases through enemies / players; LB grabs.

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
	other.global_position = f.global_position + Vector2(-600, 0)
	f.facing = 1
	var d: Enemy = lv.spawn_enemy("dummy", f.global_position + Vector2(55, 0))
	await frames(20)
	var dx := d.global_position.x
	var x0 := f.global_position.x
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.DASH])
	await get_tree().physics_frame
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(6)
	await frames(24)
	check("dash phases through an enemy (x %.0f > %.0f)" % [f.global_position.x, dx], f.global_position.x > dx + 5.0)
	check("collisions restored afterwards", f.get_collision_mask_value(5))
	# grab with LB
	f.facing = 1
	await frames(30)
	d.global_position = Vector2(f.global_position.x + 35, f.global_position.y)
	await frames(5)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(14)
	check("LB starts the grab move", f.attack.move != null and f.attack.move.id == "grab_throw")
	check("enemy is grabbed", d.state == "grabbed")
	await frames(25)
	check("the grab holds until you throw (aiming)", f.attack.active and f.attack.aiming and d.state == "grabbed")
	f.input.script_set(Vector2(0, -1))
	await frames(3)
	f.input.script_set(Vector2(0, -1), [PlayerInput.Btn.X])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(3)
	check("pressing a button throws in the aimed direction (up: vy %.0f)" % d.velocity.y, d.state == "launched" and d.velocity.y < -300.0)

	# a KO'd player is not an obstacle
	other._on_defeated()
	check("downed player is non-solid", not other.get_collision_layer_value(3))
	other.revive()
	check("revived player is solid again", other.get_collision_layer_value(3))
	# batting an enemy projectile back
	f.attack.interrupt()
	f.state = "idle"
	await frames(40)
	var e := {"kind": "bottle", "pos": Vector2(0, -60), "vel": Vector2.ZERO, "dmg": 6.0, "stun": 12, "kb": Vector2(100, 0), "life": 3.0, "radius": 12.0, "color": Color.RED}
	Projectile.launch(d, e)
	var pr: Projectile = null
	for n in get_tree().get_nodes_in_group("projectiles"):
		pr = n
	pr.global_position = f.global_position + Vector2(f.facing * 40, -80)
	pr.vel = Vector2.ZERO
	pr.gravity = 0.0
	check("enemy projectile starts hostile", pr.team == "enemy")
	f.start_attack(MoveDB.get_move_for("jab", f.class_id), PlayerInput.Btn.B)
	await frames(14)
	check("swing bats the projectile back", pr.reflected and pr.team == "player")
	get_tree().quit()
