extends Node
## Ledge grab: catching a pit edge pulls the player straight up; jump / down cannot drop them.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []  # no arena fights while the test teleports around
	var segs: Array = lv.ground_segs
	var edge := Vector2.ZERO
	for i in range(1, segs.size()):
		var a: Rect2 = segs[i - 1]
		var b: Rect2 = segs[i]
		if b.position.x - a.end.x > 1.0:
			edge = Vector2(b.position.x, b.position.y)  # left corner of the far side; we fall short into the pit
			break
	check("level has a pit with a grabbable corner", edge != Vector2.ZERO and lv.ledge_points().size() > 0)
	var f: Fighter = lv.fighters[0]
	var other: Fighter = lv.fighters[1]
	f.input.script_set(Vector2.ZERO)
	other.input.script_set(Vector2.ZERO)
	# fall short: start in the pit, left of the corner, hands just below the lip, falling
	f.facing = 1
	f.global_position = Vector2(edge.x - 20.0, edge.y + 70.0)
	f.velocity = Vector2(0, 60)
	other.global_position = Vector2(edge.x + 400.0, edge.y - 1.0)
	await frames(6)
	check("falling next to the edge grabs it", f.state == "ledge")
	# jump and down are held the whole way: neither may drop the player
	f.input.script_set(Vector2(0, 1), [PlayerInput.Btn.JUMP])
	await frames(30)
	f.input.script_set(Vector2.ZERO)
	check("climbs up at once (well under a second), no hanging", f.state != "ledge" and absf(f.global_position.y - (edge.y - 1.0)) < 6.0 and f.global_position.x > edge.x)
	get_tree().quit()
