extends Node
## Screenshot of a generated level next to its first pit.  Godot --path . res://tests/shot_gaps.tscn -- <out.png> [seed]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "gaps.png"
	var sd: int = int(args[1]) if args.size() > 1 else 7
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": sd, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: Node = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	for i in 20:
		await get_tree().process_frame
	var segs: Array = lv.ground_segs
	var px := 600.0
	for i in range(1, segs.size()):
		var a: Rect2 = segs[i - 1]
		var b: Rect2 = segs[i]
		if b.position.x - a.end.x > 1.0:
			px = a.end.x - 120.0
			lv.fighters[0].global_position = Vector2(px, a.position.y - 1.0)
			lv.fighters[1].global_position = Vector2(px - 60.0, a.position.y - 1.0)
			break
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
