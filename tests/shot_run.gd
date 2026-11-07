extends Node
## Screenshots of the run map, reward cards and slot picker.
##   Godot.exe --path . res://tests/shot_run.tscn -- <out_dir>

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	var inp := get_node("/root/Inp")
	RunState.start_run(8)
	var m = load("res://scenes/run_map.tscn").instantiate()
	add_child(m)
	await frames(8)
	await snap(out + "/r1_map.png")
	m.queue_free()
	await frames(2)
	RunState.current = RunState.map[0][0]
	RunState.pos = Vector2i(0, 0)
	RunState.levels_cleared = 2
	RunState.hp = [64.0, 88.0]
	RunState.apply_card(0, {"kind": "up", "stat": "dmg", "id": "jab"})
	RunState.queue = [{"player": 0, "kind": "move"}, {"player": 1, "kind": "level"}]
	var r = load("res://scenes/reward.tscn").instantiate()
	add_child(r)
	await frames(8)
	await snap(out + "/r2_cards.png")
	inp.players[0].script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
	await frames(3)
	inp.players[0].script_set(Vector2.ZERO)
	await frames(6)
	await snap(out + "/r3_slot.png")
	get_tree().quit()
