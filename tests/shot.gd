extends Node
## Renders a level with the real renderer, scripts some play and saves screenshots.
##   Godot.exe --path . res://tests/shot.tscn -- <level_scene> <out_dir>

var level: LevelBase


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := String(args[0])
	var out := String(args[1])
	level = load(scene).instantiate()
	add_child(level)
	await frames(10)
	var inp := get_node("/root/Inp")
	var p1: PlayerInput = inp.players[0]
	var p2: PlayerInput = inp.players[1]
	var f1: Fighter = level.fighters[0]
	var f2: Fighter = level.fighters[1]
	f1.global_position = Vector2(1330, 599)
	f2.global_position = Vector2(1250, 599)
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)
	if args.size() > 2 and args[2] == "menu":
		await frames(20)
		p1.script_set(Vector2.ZERO, [PlayerInput.Btn.START])
		await frames(3)
		p1.script_set(Vector2.ZERO, [])
		await frames(5)
		await snap(out + "/m_pause.png")
		for i in 3:
			p1.script_set(Vector2(0, 1))
			await frames(3)
			p1.script_set(Vector2.ZERO)
			await frames(3)
		p1.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
		await frames(3)
		p1.script_set(Vector2.ZERO, [])
		await frames(3)
		for i in 3:
			p1.script_set(Vector2(0, 1))
			await frames(3)
			p1.script_set(Vector2.ZERO)
			await frames(3)
		p1.script_set(Vector2(1, 0))
		await frames(3)
		p1.script_set(Vector2.ZERO)
		await frames(5)
		await snap(out + "/m_lab.png")
		get_tree().quit()
		return
	await frames(100)
	await snap(out + "/a_start.png")
	# P1 runs in and fights
	for round in 6:
		p1.script_set(Vector2(1, 0))
		p2.script_set(Vector2(1, 0))
		await frames(40)
		p1.script_set(Vector2(0, -1), [PlayerInput.Btn.X])
		p2.script_set(Vector2.ZERO, [PlayerInput.Btn.X])
		await frames(2)
		p1.script_set(Vector2.ZERO, [])
		p2.script_set(Vector2.ZERO, [])
		await frames(14)
		if round == 2:
			await snap(out + "/b_fight.png")
	p1.script_set(Vector2.ZERO, [PlayerInput.Btn.JUMP])
	await frames(14)
	p1.script_set(Vector2.ZERO, [])
	p2.script_set(Vector2(0, -1), [PlayerInput.Btn.X])
	await frames(2)
	p2.script_set(Vector2.ZERO)
	await frames(8)
	await snap(out + "/c_air.png")
	await frames(100)
	await snap(out + "/d_later.png")
	get_tree().quit()
