extends Node
## Buying a move in a door shop opens the button picker, and it is drawn.   Godot --path . res://tests/doorshop_test.tscn [-- <out_prefix>]

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	RunState.start_run(11)
	RunState.coins = 500
	RunState.current = {"type": "fight", "seed": 3, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	await frames(20)
	lv.encounters = []
	var door: Door = null
	for n in lv.get_children():
		if n is Door and (n as Door).kind == "shop":
			door = n
	if door == null:
		# make sure there is a shop door
		door = Door.new()
		door.kind = "shop"
		door.level = lv
		door.position = Vector2(500.0, lv.ground_top(500.0))
		lv.add_child(door)
	lv.enter_room(door)
	await frames(30)
	var room: DoorRoom = lv._room
	check(room != null and lv.in_room, "the shop room is open")
	var p: Fighter = lv.fighters[0]
	var item: Dictionary = {}
	for it in room._items:
		if String(it["kind"]) == "move":
			item = it
			break
	check(not item.is_empty(), "the shop sells a move")
	if not item.is_empty():
		p.global_position = Vector2(float(item["x"]), lv.ground_y - 1.0)
		await frames(5)
		Inp.players[0].script_set(Vector2.ZERO, [PlayerInput.Btn.INTERACT])
		await frames(4)
		Inp.players[0].script_set(Vector2.ZERO, [])
		await frames(10)
		check(room._pickers[0].active, "buying a move opens the button picker for that player")
		# the picker must really be on screen: the overlay control has to be redrawn while the game is paused
		var ui: Control = room._ui_layer.get_child(0)
		var drawn := [false]  # an array: lambdas capture plain variables by value
		ui.draw.connect(func() -> void: drawn[0] = true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(drawn[0], "the overlay (with the picker) is redrawn every frame while the picker is open, even though the game is paused")
		if args.size() > 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[0] + "_picker.png")
	print("door shop test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
