extends Node
## Run cycle sheet: top row the full-speed run, bottom row the slow walk.  Godot --path . res://tests/shot_run_cycle.tscn -- <out_dir>
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	for row in 2:
		for i in 8:
			var f := StickFigure.new()
			f.position = Vector2(110 + i * 150, 300 + row * 300)
			f.scale = Vector2(1.4, 1.4)
			f.arm_scale = 1.22
			f.leg_scale = 1.2
			f.color = Color(0.15, 1.0, 1.28)
			add_child(f)
			var ph := TAU * float(i) / 8.0
			f.set_target(PoseLib.run(ph) if row == 0 else PoseLib.walk(ph), true)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/run.png")
	get_tree().quit()
