extends Node
## Jump keyframes sheet.  Godot --path . res://tests/shot_jump.tscn -- <out_dir>
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var names := ["idle", "land", "rise fast", "rise slow", "apex", "fall slow", "fall fast"]
	var poses := [PoseLib.idle(0.0), PoseLib.land(), PoseLib.air(-800.0, 0.0), PoseLib.air(-250.0, 0.0), PoseLib.air(0.0, 0.0), PoseLib.air(250.0, 0.0), PoseLib.air(800.0, 0.0)]
	for i in poses.size():
		var f := StickFigure.new()
		f.position = Vector2(110 + i * 170, 330)
		f.scale = Vector2(1.6, 1.6)
		f.color = Color(0.15, 1.0, 1.28)
		add_child(f)
		f.set_target(poses[i], true)
		var l := Label.new()
		l.text = names[i]
		l.position = Vector2(60 + i * 170, 360)
		add_child(l)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/jump.png")
	get_tree().quit()
