extends Node
## The time scale option, and no GO sign inside a challenge room.   Godot --path . res://tests/timescale_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	check(is_equal_approx(Juice.user_time_scale, 1.0) and is_equal_approx(Engine.time_scale, 1.0), "the time scale starts at 1.0")
	var shown := ""
	for it in OptionsList.items():
		if it[0] == "timescale":
			shown = it[2]
	check(shown == "x1.00", "the options list has a TIME SCALE row ('%s')" % shown)
	OptionsList.adjust("timescale", 1)
	check(is_equal_approx(Engine.time_scale, 1.25), "adjusting up sets the engine time scale to 1.25 (%.2f)" % Engine.time_scale)
	OptionsList.adjust("timescale", -1)
	OptionsList.adjust("timescale", -1)
	OptionsList.adjust("timescale", -1)
	check(is_equal_approx(Engine.time_scale, 0.5), "three steps down give 0.5 (%.2f)" % Engine.time_scale)
	for i in 10:
		OptionsList.adjust("timescale", -1)
	check(is_equal_approx(Engine.time_scale, 0.1), "it stops at 0.1x (%.2f)" % Engine.time_scale)
	for i in 12:
		OptionsList.adjust("timescale", 1)
	check(is_equal_approx(Engine.time_scale, 2.0), "and at 2x (%.2f)" % Engine.time_scale)
	OptionsList.adjust("timescale", -1)
	OptionsList.adjust("timescale", -1)
	OptionsList.adjust("timescale", -1)
	check(is_equal_approx(Juice.user_time_scale, 1.0), "back at 1.0")
	# hit-stop slow motion multiplies the chosen scale and returns to it
	Juice.set_user_time_scale(0.5)
	Juice.slowmo(0.2, 0.05)
	check(is_equal_approx(Engine.time_scale, 0.1), "slow motion is relative to the chosen scale (%.2f)" % Engine.time_scale)
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 0.5), "and returns to it, not to 1.0 (%.2f)" % Engine.time_scale)
	Juice.reset_time()
	check(is_equal_approx(Engine.time_scale, 0.5), "a level or menu reset keeps the chosen scale")
	Juice.set_user_time_scale(1.0)
	# no GO sign inside a challenge room
	RunState.start_run(11)
	RunState.current = {"type": "fight", "seed": 3, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(lv)
	await frames(20)
	lv.encounters = []
	check(lv.hud.go_visible(), "the GO sign shows in the level")
	var door := Door.new()
	door.kind = "challenge"
	door.level = lv
	door.position = Vector2(500.0, lv.ground_top(500.0))
	lv.add_child(door)
	lv.enter_room(door)
	await frames(10)
	check(not lv.hud.go_visible(), "no GO sign inside a challenge room")
	lv.leave_room()
	await frames(10)
	check(lv.hud.go_visible(), "the GO sign is back after leaving it")
	var door2 := Door.new()
	door2.kind = "shop"
	door2.level = lv
	door2.position = Vector2(700.0, lv.ground_top(700.0))
	lv.add_child(door2)
	lv.enter_room(door2)
	await frames(10)
	check(lv.hud.go_visible(), "the shop room keeps its GO sign")
	print("time scale test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
