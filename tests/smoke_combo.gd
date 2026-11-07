extends Node
## Combo damage scaling, combo money, tanky enemy waves.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	Coop.combo = 0
	Coop.relay = 0
	check("no combo: x1.0", is_equal_approx(Coop.combo_mult(), 1.0))
	Coop.combo = 30
	check("30-hit combo: x2.2", is_equal_approx(Coop.combo_mult(), 2.2))
	Coop.relay = 4
	check("30 hits + 4 relays: x3.2", is_equal_approx(Coop.combo_mult(), 3.2))
	Coop.combo = 0
	Coop.relay = 0
	check("short combo pays nothing", Coop.combo_coins(8, 0) == 0)
	check("20-hit combo with 2 relays pays coins", Coop.combo_coins(20, 2) == 15)
	# the combo ends -> coins
	var before := RunState.coins
	Coop.combo = 20
	Coop.relay = 2
	Coop.combo_t = 0.01
	await frames(5)
	check("coins are paid when the combo ends (+%d)" % (RunState.coins - before), RunState.coins - before == 15)
	# tanky enemies
	var tanks := 0
	var small := 0
	var swarm := 0
	var s := StreetsLevel.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		var wave: Array = s._wave(rng, 2, 1, 0)
		var n := 0
		var t := 0
		for e in wave:
			n += int(e[1])
			if e[0] in ["brute", "heavy"]:
				t += int(e[1])
		if t > 0:
			tanks += 1
		else:
			swarm += 1
		small += n - t
	check("most waves are tanky (%d of 200), some are swarms (%d)" % [tanks, swarm], tanks > 140 and swarm > 15)
	s.free()
	var b: Enemy = lv.spawn_enemy("brute", Vector2(1500, 599))
	var th: Enemy = lv.spawn_enemy("thug", Vector2(1700, 599))
	await frames(5)
	check("brute is much tankier than a thug (%.0f vs %.0f)" % [b.max_hp, th.max_hp], b.max_hp > th.max_hp * 3.5)
	check("brute hits harder", b.dmg_mult() > 1.2)
	get_tree().quit()
