extends Node
## Regression: answering the result screen twice in one physics tick (a press spans several frames, or both players
## press) used to call finish_level() on a level that had already left the tree, and counted the level twice.
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/finish_twice_test.tscn

func _ready() -> void:
	RunState.start_run(4)
	RunState.biome = "skyscraper"
	RunState.current = {"type": "fight", "seed": 9, "layer": 0, "idx": 0, "next": [], "done": false}
	var lv: LevelBase = load(RunState.level_scene()).instantiate()
	add_child(lv)
	for i in 10:
		await get_tree().physics_frame
	var tree := get_tree()  # (finish_level swaps the scene: this test node leaves the tree with it)
	lv._complete()
	var before := RunState.levels_cleared
	lv.finish_level()
	lv.finish_level()  # the second call must do nothing
	var ok := RunState.levels_cleared == before + 1
	print(("  PASS  " if ok else "  FAIL  "), "finishing twice counts the level once (%d -> %d) and does not crash" % [before, RunState.levels_cleared])
	print("RESULT: %s" % ("OK" if ok else "FAILED"))
	tree.quit(0 if ok else 1)
