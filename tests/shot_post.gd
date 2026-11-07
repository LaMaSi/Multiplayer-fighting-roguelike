extends Node
## Renders the same spot once per post-process preset.
##   godot --path . res://tests/shot_post.tscn -- <level_scene> <out_dir>


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level: LevelBase = load(String(args[0])).instantiate()
	add_child(level)
	await frames(10)
	level.fighters[0].global_position = Vector2(620, 469)
	level.fighters[1].global_position = Vector2(700, 469)
	await frames(60)
	for i in Post.PRESETS.size():
		Post.set_preset(i)
		await frames(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/post_%d.png" % [args[1], i])
	get_tree().quit()
