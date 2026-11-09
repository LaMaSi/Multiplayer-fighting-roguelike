extends Node
## The Pull Hook's whip, nothing hit and hooked.  Godot --path . res://tests/shot_whip.tscn -- <out_prefix>

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "whip"
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	for g in ["hazards", "props", "hurt_enemy"]:
		for n in get_tree().get_nodes_in_group(g):
			if g != "hurt_enemy" or n is Enemy:
				n.queue_free()
	await frames(3)
	var f: Fighter = lv.fighters[0]
	lv.fighters[1].global_position = Vector2(200.0, lv.ground_y - 1.0)
	f.global_position = Vector2(700.0, lv.ground_y - 1.0)
	f.facing = 1
	lv.cam.global_position = Vector2(860.0, lv.ground_y - 150.0)
	await frames(10)
	f.start_attack(MoveDB.get_move_for("pull_hook", f.class_id), PlayerInput.Btn.X)
	await frames(9)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_miss.png")
	await frames(80)
	var c := lv.spawn_prop("crate", Vector2(950.0, lv.ground_y - 1.0))
	await frames(15)
	f.global_position = Vector2(700.0, lv.ground_y - 1.0)
	f.state = "idle"
	await frames(10)
	f.start_attack(MoveDB.get_move_for("pull_hook", f.class_id), PlayerInput.Btn.X)
	await frames(14)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_hook.png")
	get_tree().quit()
