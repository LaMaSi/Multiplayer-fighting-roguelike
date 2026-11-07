extends Node
## Loads every scene for a short while so script errors show up in the log.
##   godot --path . res://tests/smoke_scenes.tscn      (grep the output for SCRIPT ERROR)

const SCENES := [
	"res://scenes/main_menu.tscn", "res://scenes/run_map.tscn", "res://scenes/reward.tscn", "res://scenes/shop.tscn",
	"res://scenes/training.tscn", "res://scenes/streets.tscn",
]


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	for path in SCENES:
		RunState.start_run(11)
		RunState.coins = 300
		if path.ends_with("streets.tscn") or path.ends_with("shop.tscn"):
			RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
		if path.ends_with("reward.tscn"):
			RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
			RunState.level_cleared()  # fills the reward queue like a cleared level
		var inst: Node = load(path).instantiate()
		add_child(inst)
		await frames(20)
		print("OK  ", path)
		inst.queue_free()
		await frames(3)
		RunState.end_run()
	# the run map with a shop node on it
	RunState.start_run(11)
	var has_shop := false
	for layer in RunState.map:
		for n in layer:
			if n["type"] == "shop":
				has_shop = true
	print("map has a shop node: ", has_shop)
	var with_shop := 0
	var total := 0
	for sd in 60:
		RunState.start_run(sd)
		var c := 0
		for layer in RunState.map:
			for n in layer:
				if n["type"] == "shop":
					c += 1
		total += c
		with_shop += 1 if c > 0 else 0
	print("runs with at least one shop: %d / 60, average %.2f per run" % [with_shop, total / 60.0])
	get_tree().quit()
