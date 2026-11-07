extends Node
## Screenshots of the screens around the levels: main menu, run map, reward.
##   godot --path . res://tests/menu_shots.tscn -- <out_dir>


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	var list := [["main_menu", "res://scenes/main_menu.tscn"], ["run_map", "res://scenes/run_map.tscn"], ["reward", "res://scenes/reward.tscn"]]
	for e in list:
		RunState.start_run(11)
		RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
		if e[0] == "reward":
			RunState.level_cleared()
		var inst: Node = load(e[1]).instantiate()
		add_child(inst)
		await frames(15)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [out, e[0]])
		inst.queue_free()
		await frames(3)
	get_tree().quit()
