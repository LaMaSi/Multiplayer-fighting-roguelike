extends Node
## Renders pink-terrain vs amber-terrain with enemies, props and pickups in view.
##   godot --path . res://tests/shot_terrain.tscn -- <level_scene> <out_dir>


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for pink in [true, false]:
		Pal.terrain_pink = pink
		Backdrop.variant = 2
		var level: LevelBase = load(String(args[0])).instantiate()
		add_child(level)
		await frames(10)
		level.fighters[0].global_position = Vector2(560, 469)
		level.fighters[1].global_position = Vector2(640, 469)
		for k in ["thug", "biker", "thrower"]:
			level.spawn_enemy(k, Vector2(1180 if k == "thug" else (1050 if k == "biker" else 900), 599))
		for k in ["hp_m", "dmg", "speed", "shield", "meter"]:
			Pickup.spawn(level, Vector2(760 + ["hp_m", "dmg", "speed", "shield", "meter"].find(k) * 44, 440), k)
		level.spawn_prop("barrel", Vector2(840, 469))
		level.spawn_prop("vase", Vector2(1150, 379))
		await frames(40)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/terrain_%s.png" % [args[1], "pink" if pink else "amber"])
		level.queue_free()
		await frames(3)
	get_tree().quit()
