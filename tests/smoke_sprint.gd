extends Node
## Double flick = sprint; solo hits do not raise the team counter.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	await get_tree().process_frame
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var f: Fighter = Coop.fighters[0]
	var inp: PlayerInput = f.input
	inp.script_set(Vector2.RIGHT, [])
	await frames(40)
	var walk := f.get_run_speed()
	check("holding right is a normal run", f._sprint == 0)
	inp.script_set(Vector2.ZERO, [])
	await frames(6)
	inp.script_set(Vector2.RIGHT, [])
	await frames(3)
	inp.script_set(Vector2.ZERO, [])
	await frames(6)
	inp.script_set(Vector2.RIGHT, [])
	await frames(10)
	check("double flick starts a sprint", f._sprint == 1)
	check("sprint is faster (%.0f vs %.0f)" % [f.get_run_speed(), walk], f.get_run_speed() > walk * 1.4)
	inp.script_set(Vector2.ZERO, [])
	await frames(5)
	check("letting go ends it", f._sprint == 0)
	get_tree().quit()
