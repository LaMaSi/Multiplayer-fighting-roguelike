extends Node
## Start opens the pause menu, a second Start closes it and the menu really disappears.
##   Godot --path . res://tests/pause_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(btn: int) -> void:
	Inp.players[0].script_set(Vector2.ZERO, [btn])
	await frames(3)
	Inp.players[0].script_set(Vector2.ZERO, [])
	await frames(20)  # past the toggle lockout


func _ready() -> void:
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var menu: PauseMenu = lv.menu
	await _press(PlayerInput.Btn.START)
	check(menu.open and get_tree().paused, "Start opens the pause menu and pauses the game")
	await get_tree().process_frame
	await get_tree().process_frame
	check(menu._canvas.last_drawn_open, "the menu is drawn while paused")
	await _press(PlayerInput.Btn.START)
	check(not menu.open and not get_tree().paused, "a second Start closes the menu and continues the game")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not menu._canvas.last_drawn_open, "the menu is no longer drawn after closing it")
	check(lv.hud.visible, "the HUD is back")
	# from a sub page too
	await _press(PlayerInput.Btn.START)
	menu._go("lab", 0)
	await frames(3)
	await _press(PlayerInput.Btn.START)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not menu.open and not menu._canvas.last_drawn_open, "Start also closes the menu from a sub page, and it disappears")
	print("pause test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
