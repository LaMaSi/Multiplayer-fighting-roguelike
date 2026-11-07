extends Node
## Captures mid-animation frames of several moves + all enemy builds next to the players.
##   Godot.exe --path . res://tests/shot_moves.tscn -- <out_dir>

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	var level: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(level)
	await frames(10)
	var inp := get_node("/root/Inp")
	var p1: PlayerInput = inp.players[0]
	var p2: PlayerInput = inp.players[1]
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)
	var f1: Fighter = level.fighters[0]
	var f2: Fighter = level.fighters[1]
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		n.queue_free()
	await frames(2)
	f1.global_position = Vector2(1000, 599)
	f2.global_position = Vector2(1200, 599)
	f2.facing = -1
	# line-up of enemies for the "who is who" shot
	var kinds := ["thug", "biker", "thrower", "boss_street"]
	for i in kinds.size():
		var e := level.spawn_enemy(kinds[i], Vector2(1500 + i * 130, 599))
		e.invuln = 99.0
		e.set_physics_process(false)
	await frames(30)
	level.cam.global_position = Vector2(1250, 500)
	await snap(out + "/s0_lineup.png")
	# moves
	var seq := [["X", "jab", 4], ["X_UP", "uppercut", 8], ["X", "haymaker", 25], ["X", "spin_kick", 14], ["X", "dive_kick", 14], ["X", "flurry", 14]]
	var i2 := 0
	for s in seq:
		f1.global_position = Vector2(1000, 599)
		f1.loadout["X"] = s[1]
		f1.state = "idle"
		await frames(20)
		var d := level.spawn_enemy("dummy", Vector2(1075, 599))
		if s[1] == "dive_kick":
			f1.global_position = Vector2(1000, 450)
		p1.script_set(Vector2.ZERO, [PlayerInput.Btn.X])
		await frames(1)
		p1.script_set(Vector2.ZERO)
		await frames(int(s[2]))
		await snap(out + "/s%d_%s.png" % [i2 + 1, s[1]])
		d.queue_free()
		await frames(60)
		i2 += 1
	get_tree().quit()
