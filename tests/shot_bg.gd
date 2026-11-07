extends Node
## Renders the same spot of a level once per background style variant.
##   godot --path . res://tests/shot_bg.tscn -- <level_scene> <out_dir>


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for v in Backdrop.STYLES.size():
		Backdrop.variant = v
		var level: LevelBase = load(String(args[0])).instantiate()
		add_child(level)
		await frames(10)
		var f1: Fighter = level.fighters[0]
		var f2: Fighter = level.fighters[1]
		f1.global_position = Vector2(620, 469)
		f2.global_position = Vector2(700, 469)
		await frames(60)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/bg_v%d.png" % [args[1], v])
		level.queue_free()
		await frames(3)
	get_tree().quit()
