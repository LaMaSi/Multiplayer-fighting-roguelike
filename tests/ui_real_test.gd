extends Node
## Real HUD + level complete screenshots from the actual level scene with fake state.
##   godot --path . res://tests/ui_real_test.tscn -- <level_scene> <out_dir>


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	RunState.start_run(3)
	RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
	RunState.coins = 140
	var level: LevelBase = load(String(args[0])).instantiate()
	add_child(level)
	await frames(10)
	Dbg._hint.visible = false
	level.fighters[0].global_position = Vector2(560, 599)
	level.fighters[1].global_position = Vector2(660, 599)
	level.fighters[0].meter = 62.0
	level.fighters[1].meter = 100.0
	level.fighters[1].hp = 58.0
	Coop.combo = 18
	Coop.combo_t = 1.5
	Coop.hits_by = [11, 7]
	Coop.relay = 3
	Coop.combo_changed.emit()
	await frames(14)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/real_hud_combo.png" % args[1])
	# level complete with believable stats
	Coop.best_combo = 35
	Coop.stat_damage = 24.0
	Coop.stat_relay_hits = 14
	Coop.stat_rescues = 1
	Coop.stat_containers = 9
	Coop.stat_containers_total = 10
	Coop.stat_time = 102.0
	level._complete()
	await get_tree().create_timer(2.6, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/real_complete.png" % args[1])
	print("coins now: ", RunState.coins, "  rank: ", level.result_stats["rank"], "  score: ", level.result_stats["score"])
	if args.size() > 2:
		var before := float(RunState.hp[0])
		level.finish_level()  # continue: saves state, heals, loads the reward scene
		print("hp before/after continue: ", before, " / ", RunState.hp[0], "  queue: ", RunState.queue.size())
		await get_tree().create_timer(1.0, true, false, true).timeout
		print("flow ok")
	get_tree().quit()
