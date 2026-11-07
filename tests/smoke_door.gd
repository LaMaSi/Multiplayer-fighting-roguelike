extends Node
## Doors: enter a challenge room, clear it, get paid, leave; shop room sells picks.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _find_seed(want_both: bool) -> int:
	for s in range(1, 200):
		var lv := StreetsLevel.new()
		lv._generated({"type": "fight", "seed": s}, 0)
		var kinds := {}
		for d in lv.doors_spec:
			kinds[d["kind"]] = true
		lv.free()
		if (want_both and kinds.size() == 2) or (not want_both and kinds.size() >= 1):
			return s
	return 1


func _ready() -> void:
	var seeds_with_doors := 0
	for s in range(1, 30):
		var lv0 := StreetsLevel.new()
		lv0._generated({"type": "fight", "seed": s}, 1)
		if lv0.doors_spec.size() > 0:
			seeds_with_doors += 1
		lv0.free()
	check("most generated fight levels contain a door (%d of 29)" % seeds_with_doors, seeds_with_doors >= 20)
	var sd := _find_seed(true)
	RunState.start_run(11)
	RunState.coins = 100
	RunState.current = {"type": "fight", "seed": sd, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []  # the test teleports past the arenas
	var doors := get_tree().get_nodes_in_group("doors")
	check("level spawned doors", doors.size() >= 1)
	print("  info  seed %d doors %s" % [sd, str(lv.doors_spec)])
	var ch: Door = null
	var sh: Door = null
	for d: Door in doors:
		if d.kind == "challenge":
			ch = d
		else:
			sh = d
	if sh == null:  # most seeds have a single door: add a shop door by hand
		sh = Door.new()
		sh.kind = "shop"
		sh.level = lv
		sh.position = Vector2(ch.position.x - 500.0, lv.ground_top(ch.position.x - 500.0))
		lv.add_child(sh)
	var f: Fighter = lv.fighters[0]
	var other: Fighter = lv.fighters[1]
	f.input.script_set(Vector2.ZERO)
	other.input.script_set(Vector2.ZERO)
	# ---- challenge room
	f.global_position = ch.global_position + Vector2(10, -1)
	other.global_position = ch.global_position + Vector2(-400, -1)
	await frames(5)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(5)
	check("pressing interact at the door enters the room", lv.in_room and f.global_position.x > lv.level_w)
	check("both players are teleported in", other.global_position.x > lv.level_w)
	check("challenge spawns tough enemies", lv.alive_enemies() >= 2)
	var coins0 := RunState.coins
	for i in 6:
		for n in lv._enemies:
			if is_instance_valid(n):
				n.queue_free()
		await frames(60)
	check("clearing both waves finishes the challenge", lv._room != null and lv._room.cleared)
	check("challenge pays coins (+%d)" % (RunState.coins - coins0), RunState.coins > coins0)
	# a move pick may pop up right in the room: both players take whatever the cursors are on
	for k in 14:
		if lv._room != null and lv._room._reward_layer != null:
			f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
			other.input.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
			await frames(2)
			f.input.script_set(Vector2.ZERO, [])
			other.input.script_set(Vector2.ZERO, [])
			await frames(3)
	f.global_position = Vector2(lv._room.exit_x, lv.ground_y - 1.0)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(5)
	check("the exit returns both players to the door", not lv.in_room and absf(f.global_position.x - ch.global_position.x) < 200.0)
	check("the door is used up", ch.used)
	# ---- shop room
	if sh != null:
		RunState.coins = 100
		f.global_position = sh.global_position + Vector2(10, -1)
		await frames(5)
		f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
		await frames(2)
		f.input.script_set(Vector2.ZERO, [])
		await frames(5)
		check("shop door opens the shop room", lv.in_room and lv._room.kind == "shop")
		RunState.classes = ["", ""]
		var it: Dictionary = lv._room._items[0]
		var price: int = int(it["price"])
		f.global_position = Vector2(float(it["x"]), lv.ground_y - 1.0)
		await frames(3)
		f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
		await frames(2)
		f.input.script_set(Vector2.ZERO, [])
		await frames(5)
		check("buying a move costs coins (%d -> %d) and opens the button picker at once" % [100, RunState.coins], RunState.coins == 100 - price and lv._room._pickers[0].active)
		check("the fighters are paused while choosing the button", lv.get_tree().paused)
		f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
		await frames(2)
		f.input.script_set(Vector2.ZERO, [])
		await frames(5)
		check("the move is in the loadout right away", String(it["id"]) in (RunState.loadouts[0] as Dictionary).values() and not lv.get_tree().paused)
	get_tree().quit()
