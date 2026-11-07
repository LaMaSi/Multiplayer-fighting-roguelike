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
	check("Back while playing opens the loadout directly", lv.menu.open and lv.menu._page == "loadout")
	get_tree().quit()
