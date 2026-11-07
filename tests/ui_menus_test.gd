extends Node
## Loadout swap rules (PASS/FAIL) and screenshots of the new start screen, pause menu, loadout screen
## and run-map loadout.   godot --path . res://tests/ui_menus_test.tscn -- <out_dir>

var fails := 0
var lv: LoadoutView


func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _physics_process(delta: float) -> void:
	if lv != null:
		lv.update(delta)


func snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	RunState.classes = ["brawler", "sword"]
	RunState.start_run(4)
	RunState.current = {"type": "fight", "seed": 7, "layer": 0, "idx": 0, "next": [], "done": false}
	var lo: Dictionary = RunState.loadouts[0]
	var b_ids: Array = ClassData.get_class_data("brawler")["b_pool"]
	lo.clear()
	lo.merge({"X": "off_hand_jab", "X_UP": "spark_shot", "Y": "uppercut", "Y_UP": "sweep", "B": b_ids[0], "B_SIDE": b_ids[1]}, true)
	RunState.upgrades[0] = {"uppercut": {"dmg": 1.25, "spd": 1.0, "kb": 1.3}}
	lv = LoadoutView.new(
		func(p: int) -> Dictionary: return RunState.loadouts[p],
		func(p: int, slot: String, id: String) -> void:
			if id == "":
				(RunState.loadouts[p] as Dictionary).erase(slot)
			else:
				(RunState.loadouts[p] as Dictionary)[slot] = id,
		func(p: int) -> String: return RunState.classes[p],
		func(p: int) -> Dictionary: return RunState.upgrades[p])
	var s := lv.SLOTS
	# --- rules, called directly
	lv.cursor[0] = s.find("X")
	lv.press(0)
	check("lifting a move holds it", lv.holding[0] == "X")
	lv.cursor[0] = s.find("X_UP")
	check("dropping on another X slot swaps", lv.press(0) and lo["X"] == "spark_shot" and lo["X_UP"] == "off_hand_jab")
	lv.cursor[0] = s.find("X")
	lv.press(0)
	lv.cursor[0] = s.find("Y_UP")
	check("an X move cannot go on a Y slot", not lv.press(0) and lo["X"] == "spark_shot" and lv.holding[0] == "X")
	lv.cursor[0] = s.find("X_DOWN")
	check("dropping on an empty slot of its own kind moves it", lv.press(0) and lo["X_DOWN"] == "spark_shot" and not lo.has("X"))
	lv.cursor[0] = s.find("B")
	lv.press(0)
	lv.cursor[0] = s.find("Y")
	check("a weapon move cannot go on a Y slot", not lv.press(0) and lo["B"] == b_ids[0])
	lv.cursor[0] = s.find("B_DOWN")
	check("a weapon move can move to an empty B slot", lv.press(0) and lo["B_DOWN"] == b_ids[0] and not lo.has("B"))
	lv.cursor[0] = s.find("Y")
	lv.press(0)
	lv.cursor[0] = s.find("Y_SIDE")
	lv.press(0)
	check("Y move to an empty Y slot, upgrades stay with the move", lo["Y_SIDE"] == "uppercut" and (RunState.upgrades[0] as Dictionary).has("uppercut"))
	lv.cursor[0] = s.find("X")
	check("lifting from an empty slot does nothing", not lv.press(0) and lv.holding[0] == "")
	# the user's example: B and up+B swap, and rows never mix (also for a legacy no-class fighter)
	lv.cursor[0] = s.find("B_DOWN")
	lv.press(0)
	lv.cursor[0] = s.find("B_UP")
	check("a B move can move to up+B (same button, new direction)", lv.press(0) and lo["B_UP"] == b_ids[0] and not lo.has("B_DOWN"))
	var legacy := LoadoutView.new(
		func(_p: int) -> Dictionary: return {"X": "jab", "Y": "fireball"},
		func(_p: int, _slot: String, _id: String) -> void: pass,
		func(_p: int) -> String: return "",
		func(_p: int) -> Dictionary: return {})
	legacy.cursor[0] = s.find("X")
	legacy.press(0)
	legacy.cursor[0] = s.find("Y")
	check("even a no-class fighter cannot move X onto Y", not legacy.press(0) and legacy.holding[0] == "X")
	# the other player is independent
	lv.cursor[1] = s.find("X")
	lv.press(1)
	check("players lift independently", lv.holding[1] == "X" and lv.holding[0] == "")
	lv.holding[1] = ""
	# --- input driven: lift with A, move right, drop with A
	lv.reset()
	var p1: PlayerInput = Inp.players[0]
	var A := [PlayerInput.Btn.JUMP]
	lv.cursor[0] = s.find("Y_UP")  # sweep
	p1.script_set(Vector2.ZERO, A)
	await frames(3)
	p1.script_set(Vector2.ZERO, [])
	await frames(3)
	check("A lifts through real input", lv.holding[0] == "Y_UP")
	p1.script_set(Vector2(1, 0))
	await frames(3)
	p1.script_set(Vector2.ZERO)
	await frames(3)
	check("stick moves the cursor", lv.cursor[0] == s.find("Y_SIDE"))
	p1.script_set(Vector2.ZERO, A)
	await frames(3)
	p1.script_set(Vector2.ZERO, [])
	await frames(3)
	check("A drops and swaps through real input", lo["Y_UP"] == "uppercut" or lo["Y_SIDE"] == "sweep")
	lv = null
	if fails > 0:
		print("DONE fails=%d" % fails)
		get_tree().quit(1)
		return
	# --- screenshots
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await frames(15)
	await snap(out + "/ui_start.png")
	menu._page = "options"
	menu._sel = 1
	await frames(4)
	await snap(out + "/ui_start_options.png")
	menu._page = "meta"
	menu._sel = 0
	await frames(4)
	await snap(out + "/ui_start_unlocks.png")
	menu.queue_free()
	await frames(3)
	# run map with the loadout overlay
	var rm: Control = load("res://scenes/run_map.tscn").instantiate()
	add_child(rm)
	await frames(10)
	Inp.players[0].script_set(Vector2.ZERO, [PlayerInput.Btn.Y])
	await frames(3)
	Inp.players[0].script_set(Vector2.ZERO, [])
	await frames(6)
	check("Y opens the loadout on the run map", rm._lv_open)
	await snap(out + "/ui_map_loadout.png")
	rm.queue_free()
	await frames(3)
	# pause menu in a level
	var level: LevelBase = load("res://scenes/streets.tscn").instantiate()
	add_child(level)
	await frames(12)
	Dbg._hint.visible = false
	level.menu._toggle()
	await frames(5)
	await snap(out + "/ui_pause.png")
	level.menu._go("loadout", 0)
	var lifted := ""
	for sl in ["B", "B_UP", "B_SIDE", "B_DOWN"]:
		if Coop.fighters[0].loadout.has(sl):
			lifted = sl
			break
	level.menu._lv.holding[0] = lifted
	level.menu._lv.cursor[0] = LoadoutView.SLOTS.find("B_UP" if lifted != "B_UP" else "B_DOWN")
	await frames(5)
	await snap(out + "/ui_pause_loadout.png")
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
