extends Node
## Renders two classes side by side (idle + a few attack frames) with the real renderer.
##   Godot.exe --path . res://tests/shot_classes.tscn -- <class_p1> <class_p2> <out_dir> [moveP1 moveP2]

var level: LevelBase


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	RunState.classes = [String(args[0]), String(args[1])]
	var out := String(args[2])
	level = load("res://scenes/training.tscn").instantiate()
	add_child(level)
	await frames(10)
	var inp := get_node("/root/Inp")
	var p1: PlayerInput = inp.players[0]
	var p2: PlayerInput = inp.players[1]
	var f1: Fighter = level.fighters[0]
	var f2: Fighter = level.fighters[1]
	f1.global_position = Vector2(1100, 599)
	f2.global_position = Vector2(1300, 599)
	f1.facing = 1
	f2.facing = -1
	if args.size() >= 5:
		f1.loadout["B"] = String(args[3])
		f2.loadout["B"] = String(args[4])
	await frames(40)
	await snap(out + "/idle.png")
	p1.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	p2.script_set(Vector2.ZERO, [PlayerInput.Btn.B])
	await frames(2)
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)
	for i in 4:
		await frames(9)
		await snap(out + "/atk%d.png" % i)
