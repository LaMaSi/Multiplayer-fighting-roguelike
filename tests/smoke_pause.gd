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
	get_tree().quit()
