extends Node
## Screenshots of the 2.5D depth effect from several places in a level.
## Godot --path . res://tests/shot_depth.tscn -- <out_prefix> [seed]   writes <prefix>_pit.png, _platform.png, _start.png

func _snap(out: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "depth"
	var sd: int = int(args[1]) if args.size() > 1 else 7
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": sd, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: Node = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	for i in 20:
		await get_tree().process_frame
	lv.encounters = []
	# 1. level start
	for i in 40:
		await get_tree().process_frame
	await _snap(out + "_start.png")
	# 2. beside a pit
	var segs: Array = lv.ground_segs
	for i in range(1, segs.size()):
		var a: Rect2 = segs[i - 1]
		var b: Rect2 = segs[i]
		if b.position.x - a.end.x > 1.0:
			lv.fighters[0].global_position = Vector2(a.end.x - 140.0, a.position.y - 1.0)
			lv.fighters[1].global_position = Vector2(a.end.x - 200.0, a.position.y - 1.0)
			break
	for i in 100:
		await get_tree().process_frame
	await _snap(out + "_pit.png")
	# 3. on a platform
	if lv.platforms.size() > 0:
		var r: Rect2 = lv.platforms[min(2, lv.platforms.size() - 1)]
		lv.fighters[0].global_position = Vector2(r.position.x + r.size.x * 0.5, r.position.y - 4.0)
		lv.fighters[1].global_position = Vector2(r.position.x + r.size.x * 0.3, r.position.y - 4.0)
		for i in 100:
			await get_tree().process_frame
		await _snap(out + "_platform.png")
	get_tree().quit()
