extends Node
## Ledge grab: hang at a pit edge, 3 s to climb alone, instant with the partner's help, drop with Down.

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
	var t0 := Time.get_ticks_msec()
	await frames(100)
	check("still hanging after ~1.7 s alone", f.state == "ledge")
	await frames(100)
	check("alone: climbs up after 3 s", f.state != "ledge" and absf(f.global_position.y - (edge.y - 1.0)) < 6.0 and f.global_position.x > edge.x)
	# assisted: grab again, partner nearby presses interact
	f.facing = 1
	f.global_position = Vector2(edge.x - 20.0, edge.y + 70.0)
	f.velocity = Vector2(0, 60)
	f._ledge_cd = 0.0
	other.global_position = Vector2(edge.x + 60.0, edge.y - 1.0)
	await frames(6)
	check("grabs again", f.state == "ledge")
	other.input.script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
	await frames(2)
	other.input.script_set(Vector2.ZERO, [])
	await frames(20)
	check("partner help: up immediately (well under 3 s)", f.state != "ledge" and f.global_position.x > edge.x)
	# drop
	f.facing = 1
	f.global_position = Vector2(edge.x - 20.0, edge.y + 70.0)
	f.velocity = Vector2(0, 60)
	f._ledge_cd = 0.0
	other.global_position = Vector2(edge.x + 900.0, edge.y - 1.0)
	await frames(6)
	f.input.script_set(Vector2(0, 1))
	await frames(5)
	check("Down drops from the ledge", f.state != "ledge")
	get_tree().quit()
