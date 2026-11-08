extends Node
## Run cycle sheet.  Godot --path . res://tests/shot_run_cycle.tscn -- <out_dir>
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	for i in 8:
		var f := StickFigure.new()
		f.position = Vector2(110 + i * 150, 330)
		f.scale = Vector2(1.4, 1.4)
		f.color = Color(0.15, 1.0, 1.28)
		add_child(f)
		f.set_target(PoseLib.run(TAU * float(i) / 8.0), true)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/run.png")
	get_tree().quit()
