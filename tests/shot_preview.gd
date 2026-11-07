extends Node
## Screenshots of the reward and shop screens with the move previews.  Godot --path . res://tests/shot_preview.tscn -- <out_dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	RunState.classes = ["sword", "magic"]
	RunState.start_run(21)
	RunState.coins = 300
	RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
	RunState.level_cleared()
	var rw: Node = load("res://scenes/reward.tscn").instantiate()
	add_child(rw)
	for i in 70:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/reward.png")
	rw.queue_free()
	await get_tree().process_frame
	RunState.current = {"seed": 5, "type": "shop", "layer": 0, "idx": 0, "next": [], "done": false}
	var sh: Node = load("res://scenes/shop.tscn").instantiate()
	add_child(sh)
	for i in 70:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/shop.png")
	get_tree().quit()
