extends Node
## Finds a generated level with a tunnel and photographs the way through, the way over, and a battle screen with its ceiling.
##   Godot --path . res://tests/shot_tunnel.tscn -- <out_prefix>

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make(seed_: int) -> LevelBase:
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": seed_, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	return lv


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "tunnel"
	var found := 0
	var with_tunnel := -1
	var lv: LevelBase = null
	for sd in range(1, 41):
		lv = _make(sd)
		await frames(2)
		if lv.tunnel_roofs.size() > 0:
			found += 1
			if with_tunnel < 0:
				with_tunnel = sd
				break
		lv.queue_free()
		await frames(2)
	check(with_tunnel > 0, "a tunnel appears within 40 seeds (first at seed %d)" % with_tunnel)
	if with_tunnel < 0:
		get_tree().quit(1)
		return
	await frames(20)
	var roof: Rect2 = lv.tunnel_roofs[0]
	var gy := lv.ground_top(roof.get_center().x)
	check(absf((gy - roof.position.y) - 150.0) < 1.0, "the roof is at the low platform tier (150 px)")
	check(not lv.platforms.any(func(r: Rect2) -> bool: return r != roof and r.position.x < roof.end.x and r.end.x > roof.position.x), "no other platform overlaps the tunnel")
	lv.encounters = []
	var a: Fighter = lv.fighters[0]
	var b: Fighter = lv.fighters[1]
	# the way through: both walk the ground under the roof (the roof is one-way, nothing blocks them)
	a.global_position = Vector2(roof.get_center().x - 120.0, gy - 1.0)
	b.global_position = Vector2(roof.get_center().x + 120.0, gy - 1.0)
	await frames(60)
	check(a.is_on_floor() and absf(a.global_position.y - gy) < 3.0, "a player stands at ground level inside the tunnel")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_through.png")
	# the way over: both on top of the roof
	a.global_position = Vector2(roof.get_center().x - 100.0, roof.position.y - 4.0)
	b.global_position = Vector2(roof.get_center().x + 100.0, roof.position.y - 4.0)
	await frames(80)
	check(a.is_on_floor() and absf(a.global_position.y - roof.position.y) < 4.0, "a player stands on the roof (y=%.1f, roof=%.1f)" % [a.global_position.y, roof.position.y])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_over.png")
	# the battle screen: the ceiling drops in and stops jumps
	lv.queue_free()
	await frames(3)
	# ceilings are a variation: across seeds some arenas have one and some do not
	var with_c := 0
	var without_c := 0
	var ceil_seed := -1
	var ceil_idx := -1
	for sd4 in range(1, 11):
		if is_instance_valid(lv):
			lv.queue_free()
		await frames(2)
		lv = _make(sd4)
		await frames(2)
		for ei in lv.encounters.size():
			if bool(lv.encounters[ei].get("ceiling", false)):
				with_c += 1
				if ceil_seed < 0:
					ceil_seed = sd4
					ceil_idx = ei
			else:
				without_c += 1
	check(with_c > 0 and without_c > 0 and with_c < without_c + with_c, "ceilings are a variation, not on every arena (%d with, %d without, over 10 seeds)" % [with_c, without_c])
	if is_instance_valid(lv):
		lv.queue_free()
	await frames(3)
	lv = _make(ceil_seed)
	await frames(10)
	check(lv.encounters.size() > 0, "the level has battle screens")
	var enc: Dictionary = lv.encounters[ceil_idx]
	var ex := float(enc["x"])
	for f in lv.fighters:
		f.global_position = Vector2(ex + (-60.0 if f == lv.fighters[0] else 60.0), lv.ground_top(ex) - 1.0)
	await frames(70)
	check(lv._ceiling != null, "an arena flagged with a ceiling has one while locked")
	var cs := lv._ceiling._spikes
	check(cs.size() >= 2, "the arena ceiling carries spike clusters (%d)" % cs.size())
	var low := 1.0e9
	for st in cs:
		low = minf(low, lv.ground_y - (st.global_position.y + SpikeTrap.H))
	check(low >= SpikeTrap.AIR_MIN_H, "every ceiling spike tip is at least half a screen up (lowest tip %.0f px, minimum %.0f)" % [low, SpikeTrap.AIR_MIN_H])
	var e: Enemy = lv.spawn_enemy("dummy", Vector2(ex, lv.ground_y - 200.0))
	await frames(3)
	e.thrown(Vector2(0.0, -4200.0), lv.fighters[0])  # flung straight up, much higher than any arena
	var min_y := 99999.0
	for i in 60:
		await get_tree().physics_frame
		min_y = minf(min_y, e.global_position.y)
	var ceil_bottom := lv.ground_y - LevelBase.ARENA_CEILING
	check(min_y >= ceil_bottom, "an enemy flung upward stops at the ceiling (highest feet y %.0f, ceiling underside %.0f)" % [min_y, ceil_bottom])
	check(min_y < lv.ground_y - 300.0, "...but still flies high first (feet reached y %.0f)" % min_y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "_arena.png")
	# doors: nothing on the ground within DOOR_CLEAR of a door or the exit
	var bad := 0
	for sd2 in range(1, 13):
		lv.queue_free()
		await frames(2)
		lv = _make(sd2)
		await frames(6)
		for pr in get_tree().get_nodes_in_group("props"):
			var pp := (pr as Node2D).global_position
			if absf(pp.y - lv.ground_top(pp.x)) < 70.0 and lv.near_door(pp.x):  # on the ground (platform containers are higher up)
				bad += 1
				print('VIOLATION seed ', sd2, ' prop ', (pr as Prop).kind, ' at ', pp)
		for hz in lv.get_children():
			if hz is SpikeTrap and not (hz as SpikeTrap).ceiling and lv.near_door((hz as Node2D).position.x):
				bad += 1
	check(bad == 0, "no ground props or spikes within the clear zone of any door, across 12 seeds (%d violations)" % bad)
	print("tunnel test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
