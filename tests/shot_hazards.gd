extends Node
## Screenshot: spikes, bumper, spring in the training room.  Godot --path . res://tests/shot_hazards.tscn -- <out.png>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "hazards.png"
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	for i in 30:
		await get_tree().process_frame
	for n in get_tree().get_nodes_in_group("hazards"):
		n.queue_free()
	await get_tree().process_frame
	var sp := SpikeTrap.new()
	sp.position = Vector2(780, 600)
	lv.add_child(sp)
	var bp := Bumper.new()
	bp.position = Vector2(960, 600)
	lv.add_child(bp)
	lv.spawn_prop("spring", Vector2(1100, 599))
	var f: Fighter = Coop.fighters[0]
	f.global_position = Vector2(660, 599)
	Coop.fighters[1].global_position = Vector2(600, 599)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
