extends Node
## Pause menu must be openable and navigable with controller input.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	var lv: Node = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var p: PlayerInput = Inp.players[0]
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.START])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	await frames(3)
	check("start opens the pause menu", lv.menu.open)
	p.script_set(Vector2(0, 1))
	await frames(3)
	p.script_set(Vector2.ZERO)
	await frames(3)
	check("stick down moves the selection", lv.menu._sel == 1)
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	await frames(3)
	check("B closes the menu", not lv.menu.open)
	# both players press Start in the same step: the menu opens (it used to open and close again)
	await frames(25)
	var p2: PlayerInput = Inp.players[1]
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.START])
	p2.script_set(Vector2.ZERO, [PlayerInput.Btn.START])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("both pressing Start opens the menu once", lv.menu.open)
	await frames(25)
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.BACK])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	await frames(3)
	check("Back on the open menu jumps to the loadout screen", lv.menu.open and lv.menu._page == "loadout")
	await frames(25)
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.BACK])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	await frames(3)
	check("Back again closes the menu", not lv.menu.open)
	await frames(25)
	p2.script_set(Vector2.ZERO, [PlayerInput.Btn.BACK])
	await frames(3)
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("Back while playing opens only that player's loadout panel", lv.menu._lv.open[1] and not lv.menu._lv.open[0])
	check("the game is not paused and the pause menu stays closed", not lv.menu.open and not get_tree().paused)
	var f1: Fighter = Coop.fighters[0]
	var f2: Fighter = Coop.fighters[1]
	check("that player's fighter gets no input meanwhile, the other keeps theirs", f2.input != Inp.players[1] and f1.input == Inp.players[0])
	# P2 moves the panel cursor: the fighter must not walk; P1 walks freely at the same time
	f2.global_position.x = f1.global_position.x - 300.0  # apart, so P1 walking does not nudge P2
	await frames(2)
	var x1 := f1.global_position.x
	var x2 := f2.global_position.x
	var cur: int = lv.menu._lv.cursor[1]
	p2.script_set(Vector2(1, 0))
	p.script_set(Vector2(1, 0))
	await frames(20)
	p2.script_set(Vector2.ZERO)
	p.script_set(Vector2.ZERO)
	await frames(3)
	check("the stick moves the panel cursor, not the fighter (%.0f px)" % absf(f2.global_position.x - x2), lv.menu._lv.cursor[1] == cur + 1 and absf(f2.global_position.x - x2) < 2.0)
	check("the other player keeps playing (%.0f px)" % (f1.global_position.x - x1), f1.global_position.x > x1 + 30.0)
	p2.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	await frames(3)
	check("B closes the panel, and held B does not reach the fighter", not lv.menu._lv.open[1] and f2.input != Inp.players[1] and f2.state != "attack")
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("the fighter has its controls back after the button is released", f2.input == Inp.players[1])
	# solo-style check of the other side: P1's Back opens the left panel
	await frames(25)
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.BACK])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	await frames(3)
	check("P1's Back opens P1's panel", lv.menu._lv.open[0] and not lv.menu._lv.open[1])
	p.script_set(Vector2.ZERO, [PlayerInput.Btn.START])
	await frames(3)
	p.script_set(Vector2.ZERO, [])
	await frames(3)
	check("Start pauses, closes the panel and frees the fighter", lv.menu.open and not lv.menu._lv.any_open() and f1.input == Inp.players[0])
	get_tree().quit()
