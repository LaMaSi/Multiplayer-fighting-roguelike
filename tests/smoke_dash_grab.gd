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
	check("collisions restored afterwards", f.get_collision_mask_value(4) and f.get_collision_mask_value(3))
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
	get_tree().quit()
