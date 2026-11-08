extends Node
## Containers are standable, ceiling spikes only hurt flying enemies.
##   Godot --path . res://tests/props_test.tscn            (screenshots: add  -- <out_prefix>)

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []
	var gy := lv.ground_top(300.0)
	# 1. a crate and a barrel: a player dropped above them lands on top and stays
	var crate := lv.spawn_prop("crate", Vector2(300.0, gy - 1.0))
	var barrel := lv.spawn_prop("barrel", Vector2(730.0, gy - 1.0))
	await frames(20)
	var p: Fighter = lv.fighters[0]
	p.global_position = Vector2(300.0, gy - crate.h - 160.0)
	p.velocity = Vector2.ZERO
	await frames(70)
	check(p.is_on_floor(), "player lands on the crate (on floor)")
	check(absf(p.global_position.y - (gy - crate.h)) < 6.0, "player stands at the top of the crate (y=%.1f, top=%.1f)" % [p.global_position.y, gy - crate.h])
	var q: Fighter = lv.fighters[1]
	q.global_position = Vector2(730.0, gy - barrel.h - 160.0)
	q.velocity = Vector2.ZERO
	await frames(70)
	check(absf(q.global_position.y - (gy - barrel.h)) < 6.0, "second player stands on the barrel (y=%.1f, top=%.1f)" % [q.global_position.y, gy - barrel.h])
	# 2. a player on the ground inside a crate's footprint is not pushed up or blocked (the sides are not solid)
	p.global_position = Vector2(300.0, gy - 1.0)
	p.velocity = Vector2.ZERO
	await frames(30)
	check(absf(p.global_position.y - gy) < 4.0, "a player standing at the crate's side stays on the ground (y=%.1f, ground=%.1f)" % [p.global_position.y, gy])
	# 3. breaking the crate under a player drops them
	p.global_position = Vector2(300.0, gy - crate.h - 2.0)
	p.velocity = Vector2.ZERO
	await frames(10)
	var py0 := p.global_position.y
	crate._break(null)
	await frames(40)
	check(p.global_position.y > py0 + 20.0, "player falls when the crate is destroyed")
	# 4. ceiling spikes: never lower than half a screen; a walking enemy is unharmed, a flung one is hit, players never
	check(SpikeTrap.AIR_MIN_H >= 420.0, "ceiling spikes must keep their tips >= %.0f px above the ground (half a screen)" % SpikeTrap.AIR_MIN_H)
	var before := lv.get_children().filter(func(n: Node) -> bool: return n is SpikeTrap and (n as SpikeTrap).ceiling).size()
	lv.hazards_spec = [{"kind": "ceiling_spikes", "x": 1400.0, "y": gy - 150.0, "w": 100.0}]  # far too low: must be refused
	lv._spawn_hazards()
	var after := lv.get_children().filter(func(n: Node) -> bool: return n is SpikeTrap and (n as SpikeTrap).ceiling).size()
	check(after == before, "ceiling spikes hanging at 150 px are refused")
	var tip_y := gy - SpikeTrap.AIR_MIN_H - 10.0
	lv.hazards_spec = [{"kind": "ceiling_spikes", "x": 1400.0, "y": tip_y - SpikeTrap.H, "w": 100.0}]
	lv._spawn_hazards()
	var spike: SpikeTrap = null
	for n in lv.get_children():
		if n is SpikeTrap and (n as SpikeTrap).ceiling:
			spike = n
	check(spike != null, "ceiling spikes high enough are accepted")
	if spike != null:
		var e: Enemy = lv.spawn_enemy("thug", Vector2(spike.position.x, gy - 1.0))
		await frames(20)
		var hp0 := e.hp
		await frames(40)
		check(e.hp >= hp0, "a walking enemy is not hurt")
		e.global_position = Vector2(spike.position.x, spike.position.y + 60.0)
		e.thrown(Vector2(0.0, -400.0), lv.fighters[0])
		await frames(8)
		check(e.hp < hp0, "an enemy flung up into the ceiling spikes is hurt (hp %.0f -> %.0f)" % [hp0, e.hp])
		var ph := lv.fighters[1].hp
		lv.fighters[1].global_position = Vector2(spike.position.x, spike.position.y + 60.0)
		lv.fighters[1].velocity = Vector2(0.0, -300.0)
		await frames(10)
		check(lv.fighters[1].hp >= ph, "a player is not hurt by them")
	if args.size() > 0:
		# screenshot: crate, barrel with a player on top, ceiling spikes
		var seg := lv.ground_top(300.0)
		lv.spawn_prop("crate", Vector2(380.0, seg - 1.0))
		lv.spawn_prop("explosive", Vector2(460.0, seg - 1.0))
		lv.fighters[0].global_position = Vector2(380.0, seg - 48.0)
		lv.fighters[1].global_position = Vector2(520.0, seg - 1.0)
		if spike != null:
			lv.fighters[1].global_position = Vector2(spike.position.x - 120.0, seg - 1.0)
		await frames(80)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0] + "_props.png")
	print("props test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
