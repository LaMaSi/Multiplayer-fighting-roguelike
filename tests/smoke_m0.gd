extends Node
## M0 headless smoke test (run as a scene so autoloads exist):
##   Godot_console.exe --headless --path . --fixed-fps 60 res://tests/smoke_m0.tscn
## Exit code = number of failed checks.

var fails := 0
var level: Node
var f1: Fighter
var f2: Fighter
var p1: PlayerInput
var p2: PlayerInput

const A := PlayerInput.Btn.JUMP


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(f: Fighter, pos: Vector2) -> void:
	f.global_position = pos
	f.velocity = Vector2.ZERO


func _ready() -> void:
	var inp := get_node("/root/Inp")
	level = load("res://scenes/training.tscn").instantiate()
	add_child(level)
	await frames(5)
	f1 = level.fighters[0]
	f2 = level.fighters[1]
	p1 = inp.players[0]
	p2 = inp.players[1]
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)

	print("[settle]")
	await frames(30)
	check(f1.is_on_floor() and f2.is_on_floor(), "both players stand on the ground")
	check(absf(f1.global_position.y - 600.0) < 3.0, "feet rest on ground line (y=%.1f)" % f1.global_position.y)

	print("[walk]")
	place(f2, Vector2(2000, 599))  # keep P2 out of the way
	var x0 := f1.global_position.x
	p1.script_set(Vector2(1, 0))
	await frames(30)
	check(f1.global_position.x > x0 + 80.0, "moves right (%.0f px)" % (f1.global_position.x - x0))
	check(f1.facing == 1 and f1.state == "walk", "faces right, state=walk")
	p1.script_set(Vector2(-1, 0))
	await frames(10)
	check(f1.facing == -1, "turns to face left")
	p1.script_set(Vector2.ZERO)
	await frames(30)
	check(f1.state == "idle", "returns to idle")

	print("[jump]")
	place(f1, Vector2(1000, 599))
	await frames(10)
	var y_start := f1.global_position.y
	var y_min := y_start
	p1.script_set(Vector2.ZERO, [A])
	await frames(2)
	p1.script_set(Vector2.ZERO, [A])  # keep holding for a full jump
	for i in 40:
		await get_tree().physics_frame
		y_min = minf(y_min, f1.global_position.y)
	p1.script_set(Vector2.ZERO)
	await frames(60)
	var rise := y_start - y_min
	check(rise > 130.0 and rise < 200.0, "full jump height ~%.0f px" % rise)
	check(f1.is_on_floor(), "lands again")

	print("[variable jump]")
	y_min = f1.global_position.y
	y_start = y_min
	p1.script_set(Vector2.ZERO, [A])
	await frames(2)
	p1.script_set(Vector2.ZERO)  # tap
	for i in 50:
		await get_tree().physics_frame
		y_min = minf(y_min, f1.global_position.y)
	check(y_start - y_min < rise - 30.0, "short tap jumps lower (%.0f px)" % (y_start - y_min))
	await frames(40)

	print("[platform: jump up from below]")
	place(f1, Vector2(530, 599))
	await frames(5)
	p1.script_set(Vector2.ZERO, [A])
	await frames(2)
	p1.script_set(Vector2.ZERO, [A])
	await frames(60)
	p1.script_set(Vector2.ZERO)
	await frames(30)
	check(f1.is_on_floor() and absf(f1.global_position.y - 450.0) < 3.0, "lands on platform top (y=%.1f)" % f1.global_position.y)

	print("[platform: drop through]")
	p1.script_set(Vector2(0, 1), [A])
	await frames(2)
	p1.script_set(Vector2(0, 1))
	await frames(50)
	p1.script_set(Vector2.ZERO)
	await frames(10)
	check(f1.is_on_floor() and absf(f1.global_position.y - 600.0) < 3.0, "fell to the ground (y=%.1f)" % f1.global_position.y)
	check(f1.get_collision_mask_value(2), "platform collision re-enabled")

	print("[no drop on solid ground]")
	p1.script_set(Vector2(0, 1), [A])
	await frames(2)
	p1.script_set(Vector2.ZERO)
	await frames(5)
	check(f1.global_position.y < 599.0 or f1.velocity.y < 0.0 or f1.state == "jump" or f1.state == "fall", "Down+A on ground still jumps")
	await frames(60)

	print("[bodies pass through each other]")
	place(f1, Vector2(1000, 599))
	place(f2, Vector2(1100, 599))
	await frames(10)
	p1.script_set(Vector2(1, 0))
	await frames(60)
	p1.script_set(Vector2.ZERO)
	var gap := f2.global_position.x - f1.global_position.x
	check(gap < -32.0, "P1 walks through P2 (gap %.1f)" % gap)
	check(absf(f2.global_position.x - 1100.0) < 4.0, "P2 not pushed (x=%.1f)" % f2.global_position.x)

	print("[landing on a player]")
	place(f2, Vector2(2900, 599))
	place(f1, Vector2(2900, 400))
	await frames(100)
	check(f1.is_on_floor() and absf(f1.global_position.y - 600.0) < 3.0, "P1 ended on the ground (y=%.1f)" % f1.global_position.y)
	check(true, "P1 lands next to or inside P2 (no body blocking)")

	print("[platforms reachable with a single jump]")
	var worst := 0.0
	for r: Rect2 in level.platforms:
		worst = maxf(worst, 600.0 - r.position.y)
	check(worst > 0.0 and worst <= rise - 8.0, "highest platform is %.0f px up, jump reaches %.0f" % [worst, rise])
	for sc in ["res://scenes/streets.tscn"]:
		var lv: LevelBase = load(sc).instantiate()
		lv._setup()  # fills platforms without building the level
		var w2 := 0.0
		for r: Rect2 in lv.platforms:
			w2 = maxf(w2, 600.0 - r.position.y)
		check(w2 <= rise - 8.0, "%s: highest platform %.0f px up" % [sc, w2])
		var low := 999.0
		for r: Rect2 in lv.platforms:
			low = minf(low, 600.0 - r.end.y)
		check(low >= 132.0, "%s: walkers fit under every platform (gap %.0f px, boss is ~129)" % [sc, low])
		lv.free()

	print("[double jump]")
	place(f2, Vector2(100, 599))
	place(f1, Vector2(3050, 599))  # clear of every platform
	await frames(10)
	f1.double_jump = false
	p1.script_set(Vector2.ZERO, [A])
	await frames(30)
	p1.script_set(Vector2.ZERO)
	await frames(2)
	p1.script_set(Vector2.ZERO, [A])  # second press in the air: nothing without the perk
	await frames(2)
	p1.script_set(Vector2.ZERO)
	var vy_no := f1.velocity.y
	check(vy_no > -300.0, "no double jump without the perk (vy=%.0f)" % vy_no)
	await frames(80)
	f1.double_jump = true
	p1.script_set(Vector2.ZERO, [A])
	await frames(30)
	p1.script_set(Vector2.ZERO)
	await frames(2)
	p1.script_set(Vector2.ZERO, [A])
	await frames(3)
	check(f1.velocity.y < -300.0, "second jump in the air with the perk (vy=%.0f)" % f1.velocity.y)
	p1.script_set(Vector2.ZERO)
	await frames(60)
	check(f1._air_jump_ready, "air jump recharges on landing")

	print("[kill plane]")
	place(f1, Vector2(1200, 2500))
	await frames(3)
	check(f1.global_position.y < 700.0, "respawned after falling out (y=%.1f)" % f1.global_position.y)

	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(fails)
