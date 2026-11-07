class_name StreetsLevel
extends LevelBase
## Biome 1: Streets. Warm night, purple/orange neon. Thugs, bikers, bottle throwers, Big Boss.
## In a run the level is generated from the map node (type, seed) and the run difficulty;
## launched on its own it is the long hand-built "full" level.


func _setup() -> void:
	level_name = "Streets"
	theme["sky_top"] = Color(0.12, 0.04, 0.26)
	theme["sky_bottom"] = Color(1.0, 0.36, 0.30)
	theme["neon_ground"] = Pal.terrain()
	theme["neon_plat"] = Pal.terrain()
	theme["bld_far"] = Color(0.45, 0.15, 0.40)
	theme["edge_mid"] = Color(2.0, 0.6, 0.3)
	theme["edge_near"] = Color(2.0, 0.4, 1.2)
	if RunState.active:
		_generated(RunState.current, RunState.levels_cleared)
	else:
		_full()


func _full() -> void:
	objective = "Clear the street and take down the boss"
	level_w = 6800.0
	platforms = [
		Rect2(500, 510, 280, PLAT_H), Rect2(1000, 450, 240, PLAT_H),
		Rect2(1900, 510, 300, PLAT_H), Rect2(2300, 450, 260, PLAT_H),
		Rect2(3100, 510, 320, PLAT_H), Rect2(3550, 450, 260, PLAT_H),
		Rect2(4300, 510, 300, PLAT_H), Rect2(4700, 450, 300, PLAT_H),
		Rect2(5500, 505, 300, PLAT_H),
	]
	props_spec = [
		[420, "crate"], [510, "crate"], [620, "barrel", 510], [1100, "vase", 450], [1500, "barrel"], [1560, "crate"],
		[2000, "crate", 510], [2400, "barrel", 450], [2750, "vase"], [2800, "crate"],
		[3200, "barrel", 510], [3650, "crate", 450], [3950, "barrel"], [4000, "vase"],
		[4400, "crate", 510], [4800, "barrel", 450], [5200, "crate"], [5250, "vase"], [5600, "barrel", 505], [5900, "crate"],
	]
	encounters = [
		{"x": 1300.0, "waves": [[["thug", 2]], [["thug", 1], ["thrower", 1]]]},
		{"x": 2650.0, "waves": [[["thug", 2], ["biker", 1]], [["thrower", 1], ["thug", 1]]]},
		{"x": 3900.0, "waves": [[["biker", 2], ["thug", 1]], [["thrower", 2], ["thug", 2]]]},
		{"x": 5100.0, "waves": [[["thug", 3], ["biker", 1]], [["thrower", 2], ["biker", 1], ["thug", 1]]]},
		{"x": 6050.0, "boss": true, "waves": [[["boss_street", 1]]]},
	]


## Level built from a map node: type fight / elite / treasure / boss, seeded for reproducibility.
func _generated(node: Dictionary, depth: int) -> void:
	var t: String = node["type"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node["seed"])
	level_w = {"fight": 3800.0, "elite": 4600.0, "treasure": 3300.0, "boss": 2800.0}.get(t, 3800.0)
	enemy_hp_mult = (1.0 + 0.12 * depth) * (1.35 if t == "elite" else 1.0)
	enemy_dmg_mult = 1.0 + 0.06 * depth
	if t != "boss":
		exit_x = level_w - 260.0
	objective = {"fight": "Break through to the exit", "elite": "Defeat the elite guard, then reach the exit",
		"treasure": "Smash the loot, then reach the exit", "boss": "Take down the boss"}.get(t, "Reach the exit")

	# platforms
	var n_plat := int(level_w / 720.0)
	for i in n_plat:
		var x := 420.0 + i * 720.0 + rng.randf_range(-70.0, 70.0)
		var y := 510.0 if rng.randf() < 0.55 else 450.0  # jump apex is ~168px: top platforms must stay within reach
		platforms.append(Rect2(x, y, rng.randf_range(250.0, 320.0), PLAT_H))

	# containers
	var n_props: int = {"fight": 8, "elite": 9, "treasure": 17, "boss": 5}.get(t, 8)
	for i in n_props:
		var kind := _pick(rng, [["crate", 50], ["barrel", 30], ["vase", 20]])
		if rng.randf() < 0.35 and platforms.size() > 0:
			var pl: Rect2 = platforms[rng.randi() % platforms.size()]
			props_spec.append([pl.position.x + rng.randf_range(30.0, pl.size.x - 30.0), kind, pl.position.y])
		else:
			props_spec.append([rng.randf_range(300.0, level_w - 400.0), kind])

	# encounters
	match t:
		"fight":
			encounters = [_enc(rng, 1150.0, depth, 0), _enc(rng, 2350.0, depth, 1)]
		"elite":
			encounters = [_enc(rng, 1100.0, depth, 1), _enc(rng, 2200.0, depth, 2), _enc(rng, 3300.0, depth, 3)]
		"boss":
			encounters = [{"x": 800.0, "boss": true, "waves": [[["boss_street", 1]]]}]
		_:
			encounters = []  # treasure: loot room, just walk to the exit


func _pick(rng: RandomNumberGenerator, table: Array) -> String:
	var total := 0
	for e in table:
		total += int(e[1])
	var r := rng.randi() % total
	for e in table:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return String(table[0][0])


func _enc(rng: RandomNumberGenerator, x: float, depth: int, bonus: int) -> Dictionary:
	var waves: Array = []
	for w in 2:
		var count := 2 + depth / 2 + bonus / 2 + w
		var tally := {}
		for i in count:
			var k := _pick(rng, [["thug", 55], ["biker", 20 + depth * 3], ["thrower", 25]])
			tally[k] = int(tally.get(k, 0)) + 1
		var wave: Array = []
		for k in tally:
			wave.append([k, tally[k]])
		waves.append(wave)
	return {"x": x, "waves": waves}
