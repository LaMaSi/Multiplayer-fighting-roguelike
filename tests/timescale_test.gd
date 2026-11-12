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
	check(is_equal_approx(Engine.time_scale, Juice.GAME_SPEED) and Engine.physics_ticks_per_second == roundi(60 * Juice.GAME_SPEED), "a level runs at the game speed with matching physics ticks (x%.2f, %d ticks)" % [Engine.time_scale, Engine.physics_ticks_per_second])
	# the pose spring stays stable with big frame steps (it used to explode above x1.25 and the models flew away)
	var fig := StickFigure.new()
	add_child(fig)
	fig.follow_speed = 52.0
	fig.zeta = 0.5
	fig.set_target(PoseLib.idle(0.0), true)
	fig.set_target({"root_x": 30.0, "ua_f": 2.0})
	var worst := 0.0
	for i in 120:
		fig._process(1.0 / 12.0)
		worst = maxf(worst, absf(float(fig.pose["root_x"])))
	check(worst < 60.0 and absf(float(fig.pose["root_x"]) - 30.0) < 0.5, "the pose spring settles at 12 fps steps (peak %.1f, end %.2f)" % [worst, float(fig.pose["root_x"])])
	fig.queue_free()
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
