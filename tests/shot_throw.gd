extends Node
## Screenshot: holding an enemy overhead with the aim arrow, and an explosive crate.  Godot --path . res://tests/shot_throw.tscn -- <out_dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	for i in 30:
		await get_tree().process_frame
	var f: Fighter = Coop.fighters[0]
	var other: Fighter = Coop.fighters[1]
	other.global_position = f.global_position + Vector2(-500, 0)
	f.global_position = Vector2(1300, 599)
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await get_tree().process_frame
	lv.spawn_prop("explosive", Vector2(1480, 599))
	var d: Enemy = lv.spawn_enemy("dummy", Vector2(1335, 599))
	for i in 20:
		await get_tree().physics_frame
	f.facing = 1
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await get_tree().physics_frame
	await get_tree().physics_frame
	f.input.script_set(Vector2(1, -0.6))
	for i in 40:
		await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/hold.png")
	get_tree().quit()
