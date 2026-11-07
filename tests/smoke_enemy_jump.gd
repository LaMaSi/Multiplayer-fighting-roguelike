extends Node
## Enemies jump pits, steps and platforms on their own while chasing.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	# find a generated level with a pit of 180-300 px
	var sd := 1
	var edge_l := 0.0
	var edge_r := 0.0
	for s in range(1, 120):
		var probe := StreetsLevel.new()
		probe._generated({"type": "fight", "seed": s}, 0)
		var found := false
		for i in range(1, probe.ground_segs.size()):
			var a: Rect2 = probe.ground_segs[i - 1]
			var b: Rect2 = probe.ground_segs[i]
			var gap := b.position.x - a.end.x
			if gap > 200.0 and gap < 290.0 and absf(a.position.y - b.position.y) < 1.0 and a.size.x > 300.0 and b.size.x > 300.0:
				sd = s
				edge_l = a.end.x
				edge_r = b.position.x
				found = true
				break
		probe.free()
		if found:
			break
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": sd, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []
	var f: Fighter = lv.fighters[0]
	var other: Fighter = lv.fighters[1]
	var gy: float = lv.ground_at(edge_l - 10.0)
	f.global_position = Vector2(edge_r + 200.0, gy - 1.0)
	other.global_position = Vector2(edge_r + 260.0, gy - 1.0)
	f.input.script_set(Vector2.ZERO)
	other.input.script_set(Vector2.ZERO)
	var e: Enemy = lv.spawn_enemy("thug", Vector2(edge_l - 220.0, gy - 1.0))
	e.max_hp = 9999.0
	e.hp = 9999.0
	for i in 480:
		await get_tree().physics_frame
		if e.global_position.x > edge_r + 20.0:
			break
	check("a thug jumps a %.0f px pit to reach its target (x %.0f, pit %.0f..%.0f)" % [edge_r - edge_l, e.global_position.x, edge_l, edge_r], is_instance_valid(e) and e.state != "dead" and e.global_position.x > edge_r - 5.0)
	# a pit too wide to cross: the enemy waits at the edge instead of falling in (find a wide one in another level)
	f.global_position = Vector2(100, gy - 1.0)
	other.global_position = Vector2(150, gy - 1.0)
	var wide_seed := 0
	var wl := 0.0
	var wr := 0.0
	for s in range(1, 200):
		var pr := StreetsLevel.new()
		pr._generated({"type": "fight", "seed": s}, 0)
		for i in range(1, pr.ground_segs.size()):
			var a2: Rect2 = pr.ground_segs[i - 1]
			var b2: Rect2 = pr.ground_segs[i]
			if b2.position.x - a2.end.x > 420.0 and a2.size.x > 300.0 and absf(a2.position.y - b2.position.y) < 1.0:
				wide_seed = s
				wl = a2.end.x
				wr = b2.position.x
				break
		pr.free()
		if wide_seed > 0:
			break
	check("found a wide pit level for the test", wide_seed > 0)
	if wide_seed > 0:
		lv.queue_free()
		await frames(5)
		RunState.current = {"type": "fight", "seed": wide_seed, "layer": 0, "idx": 0, "next": [], "done": false}
		var lv2: LevelBase = load("res://scenes/streets.tscn").instantiate()
		add_child(lv2)
		await frames(30)
		lv2.encounters = []
		var gy2: float = lv2.ground_at(wl - 10.0)
		lv2.fighters[0].global_position = Vector2(wr + 150.0, gy2 - 1.0)
		lv2.fighters[1].global_position = Vector2(wr + 210.0, gy2 - 1.0)
		var e3: Enemy = lv2.spawn_enemy("thug", Vector2(wl - 200.0, gy2 - 1.0))
		await frames(420)
		check("an enemy does not walk into a pit it cannot cross (x %.0f, pit %.0f..%.0f)" % [e3.global_position.x, wl, wr], is_instance_valid(e3) and e3.state != "dead" and e3.global_position.x < wl + 15.0 and e3.global_position.y < gy2 + 40.0)
	# hazards in the way: a bumper / spring between the enemy and its target is jumped over
	var lv3: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv3)
	await frames(30)
	for n in get_tree().get_nodes_in_group("hazards"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	await frames(3)
	var bmp := Bumper.new()
	bmp.position = Vector2(1500, 600)
	lv3.add_child(bmp)
	lv3.fighters[0].global_position = Vector2(1900, 599)
	lv3.fighters[1].global_position = Vector2(1960, 599)
	var eb: Enemy = lv3.spawn_enemy("thug", Vector2(1300, 599))
	for i in 420:
		await get_tree().physics_frame
		if eb.global_position.x > 1580.0:
			break
	check("an enemy gets past a bumper by jumping (x %.0f)" % eb.global_position.x, eb.global_position.x > 1560.0)
	get_tree().quit()
