extends Node
## Charge visuals at three charge levels.  Godot --path . res://tests/shot_charge.tscn -- <out_prefix>

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "charge"
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var f: Fighter = lv.fighters[0]
	var p: PlayerInput = Inp.players[0]
	for g in ["hazards", "props", "hurt_enemy"]:
		for n in get_tree().get_nodes_in_group(g):
			if g != "hurt_enemy" or n is Enemy:
				n.queue_free()
	f.global_position = Vector2(700.0, lv.ground_y - 1.0)
	lv.fighters[1].global_position = Vector2(300.0, lv.ground_y - 1.0)
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	f.start_attack(MoveDB.get_move_for("haymaker", f.class_id), PlayerInput.Btn.B)
	var marks := {50: "low", 110: "mid", 175: "full"}  # 22 frames of wind-up, then the charge
	for i in range(1, 205):
		await get_tree().physics_frame
		if marks.has(i):
			lv.cam.global_position = f.global_position + Vector2(0, -60)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, marks[i]])
	p.script_set(Vector2.ZERO, [])
	get_tree().quit()
