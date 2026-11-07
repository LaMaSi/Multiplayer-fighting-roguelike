extends Node
## NEW RUN flow: weapon choice (with Random and a locked Magic), the rolled-move reveal and back-out.
##   godot --path . res://tests/run_setup_test.tscn -- <out_dir>

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func tap(p: int, d := Vector2.ZERO, btns: Array = []) -> void:
	Inp.players[p].script_set(d, btns)
	await frames(3)
	Inp.players[p].script_set(Vector2.ZERO, [])
	await frames(3)


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	var A := [PlayerInput.Btn.JUMP]
	var B := [PlayerInput.Btn.B]
	RunState.magic_unlocked = false
	RunState.classes = ["brawler", "brawler"]
	RunSetup.mode = "run"
	var went: Array = []
	var s: RunSetup = load("res://scenes/run_setup.tscn").instantiate()
	s.scene_changer = func(path: String) -> void: went.append(path)
	add_child(s)
	await frames(10)
	check("starts on the pick phase with Brawler under the cursor", s.phase == "pick" and s.cursor[0] == 0 and s.cursor[1] == 0)
	# P1 -> Sword, P2 -> hover Hammer for a screenshot
	await tap(0, Vector2(0, 1))
	check("down moves the cursor to Sword", RunSetup.OPTIONS[s.cursor[0]] == "sword")
	for i in 2:
		await tap(1, Vector2(0, 1))
	await frames(4)
	await snap(out + "/setup_pick.png")
	# P2 on Hammer -> down to Magic (locked): refused
	await tap(1, Vector2(0, 1))
	check("Magic is under P2's cursor", RunSetup.OPTIONS[s.cursor[1]] == "magic")
	await tap(1, Vector2.ZERO, A)
	check("a locked class cannot be chosen", not s.locked[1])
	# P2 -> Random
	await tap(1, Vector2(0, 1))
	await tap(0, Vector2.ZERO, A)
	check("A locks P1 in as Sword", s.locked[0] and s.choice[0] == "sword")
	await tap(0, Vector2.ZERO, B)
	check("B unlocks again", not s.locked[0])
	await tap(0, Vector2.ZERO, A)
	await tap(1, Vector2.ZERO, A)
	check("both locked starts the run (reveal phase)", s.phase == "reveal" and RunState.active)
	check("Random resolved to a real, available class", s.was_random[1] and s.choice[1] in ["brawler", "sword", "hammer"])
	check("RunState has the chosen classes", RunState.classes[0] == "sword" and RunState.classes[1] == s.choice[1])
	# which moves were rolled
	var slots_ok := true
	for p in 2:
		var lo: Dictionary = RunState.loadouts[p]
		var keys := lo.keys()
		keys.sort()
		var want := ["B", "B_SIDE", "B_UP", "X", "Y"]
		if keys != want:
			slots_ok = false
			print("   P%d keys: %s" % [p + 1, keys])
	check("each player gets exactly B, UP+B, SIDE+B, X and Y (no UP+Y)", slots_ok)
	var sword_b: Array = ClassData.get_class_data("sword")["b_pool"]
	var lo0: Dictionary = RunState.loadouts[0]
	check("P1's B moves come from the Sword pool", lo0["B"] in sword_b and lo0["B_UP"] in sword_b and lo0["B_SIDE"] in sword_b)
	check("X is an off-hand move and Y an adaptive move", lo0["X"] in ClassData.X_POOL and lo0["Y"] in ClassData.Y_POOL)
	await frames(30)
	await snap(out + "/setup_roll.png")
	await tap(0, Vector2.ZERO, A)  # skip the roll
	await frames(6)
	check("A during the roll skips it", s.reveal_t >= RunSetup.REVEAL_END)
	await snap(out + "/setup_reveal.png")
	await tap(0, Vector2.ZERO, A)
	check("one ready player does not start the run", s.ready_flags[0] and not s._leaving)
	await snap(out + "/setup_waiting.png")
	await tap(1, Vector2.ZERO, A)
	check("both ready leaves for the run map", went == ["res://scenes/run_map.tscn"])
	s.queue_free()
	await frames(3)
	# training mode skips the reveal
	RunState.end_run()
	RunSetup.mode = "training"
	var went2: Array = []
	var t: RunSetup = load("res://scenes/run_setup.tscn").instantiate()
	t.scene_changer = func(path: String) -> void: went2.append(path)
	add_child(t)
	await frames(8)
	await tap(0, Vector2.ZERO, A)
	await tap(1, Vector2.ZERO, A)
	check("training mode goes straight to the training room", went2 == ["res://scenes/training.tscn"] and not RunState.active)
	# B with nothing locked goes back to the main menu
	var went3: Array = []
	var u: RunSetup = load("res://scenes/run_setup.tscn").instantiate()
	u.scene_changer = func(path: String) -> void: went3.append(path)
	add_child(u)
	await frames(8)
	await tap(0, Vector2.ZERO, B)
	check("B with nobody locked goes back to the main menu", went3 == ["res://scenes/main_menu.tscn"])
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
