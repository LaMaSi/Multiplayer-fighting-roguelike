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
		Rect2(500, 450, 280, PLAT_H), Rect2(1000, 450, 240, PLAT_H),
		Rect2(1900, 450, 300, PLAT_H), Rect2(2300, 450, 260, PLAT_H),
		Rect2(3100, 450, 320, PLAT_H), Rect2(3550, 450, 260, PLAT_H),
		Rect2(4300, 450, 300, PLAT_H), Rect2(4700, 450, 300, PLAT_H),
		Rect2(5500, 450, 300, PLAT_H),
	]
	props_spec = [
		[420, "crate"], [510, "crate"], [620, "barrel", 450], [1100, "vase", 450], [1500, "barrel"], [1560, "crate"],
		[2000, "crate", 450], [2400, "barrel", 450], [2750, "vase"], [2800, "crate"],
		[3200, "barrel", 450], [3650, "crate", 450], [3950, "barrel"], [4000, "vase"],
		[4400, "crate", 450], [4800, "barrel", 450], [5200, "crate"], [5250, "vase"], [5600, "barrel", 450], [5900, "crate"],
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
	level_w = {"fight": 6200.0, "elite": 8000.0, "treasure": 5000.0, "boss": 2800.0}.get(t, 3800.0)
	enemy_hp_mult = (1.0 + 0.12 * depth) * (1.35 if t == "elite" else 1.0)
	enemy_dmg_mult = 1.0 + 0.06 * depth
	if t != "boss":
		exit_x = level_w - 260.0
	objective = {"fight": "Break through to the exit", "elite": "Defeat the elite guard, then reach the exit",
		"treasure": "Smash the loot, then reach the exit", "boss": "Take down the boss"}.get(t, "Reach the exit")

	# encounters first: their arenas stay flat, everything between them is terrain
	match t:
		"fight":
			encounters = [_enc(rng, 1700.0, depth, 0), _enc(rng, 3900.0, depth, 1)]
		"elite":
			encounters = [_enc(rng, 1600.0, depth, 1), _enc(rng, 3800.0, depth, 2), _enc(rng, 6000.0, depth, 3)]
		"boss":
			encounters = [{"x": 800.0, "boss": true, "waves": [[["boss_street", 1]]]}]
		_:
			encounters = []  # treasure: loot room, just walk to the exit
	_gen_terrain(rng, t)


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
		waves.append(_wave(rng, depth, bonus, w))
	return {"x": x, "waves": waves}


## Few and tanky is the norm (1-2 brutes/heavies plus a couple of small ones); about one wave in five is a swarm of
## small enemies for variety.
func _wave(rng: RandomNumberGenerator, depth: int, bonus: int, w: int) -> Array:
	var tally := {}
	if rng.randf() < 0.2:
		for i in 5 + depth / 2 + w:
			var k := _pick(rng, [["thug", 60], ["thrower", 25], ["biker", 15]])
			tally[k] = int(tally.get(k, 0)) + 1
	else:
		var tanks := 1 + (1 if (depth + bonus + w) >= 3 else 0)
		for i in tanks:
			var k2 := _pick(rng, [["brute", 65], ["heavy", 20 + depth * 5]])
			tally[k2] = int(tally.get(k2, 0)) + 1
		for i in rng.randi_range(0, 2):
			var k3 := _pick(rng, [["thug", 50], ["thrower", 30], ["biker", 20]])
			tally[k3] = int(tally.get(k3, 0)) + 1
	var wave: Array = []
	for k in tally:
		wave.append([k, tally[k]])
	return wave


# ------------------------------------------------------------------ terrain

const GAP_MIN := 180.0
const GAP_MAX := 300.0  # one jump + run clears ~380 px, keep a margin
const STEP_MAX := 100.0  # a jump rises ~178 px, enemies must be able to follow a step up


## Ground pieces, pits, steps, platforms (tiers 150 / 270 px above the local ground, the high tier reached from
## the low one) and props. Encounter arenas (and the start / exit) stay flat at the base height.
func _gen_terrain(rng: RandomNumberGenerator, t: String) -> void:
	var flats: Array = [Vector2(0.0, 400.0), Vector2(level_w - 600.0, level_w)]
	for e in encounters:
		flats.append(Vector2(float(e["x"]) - 800.0, float(e["x"]) + 800.0))
	flats.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	ground_segs = []
	platforms = []
	var base := ground_y
	var x := 0.0
	var top := base
	var seg_x := 0.0
	var fi := 0
	var gap_islands: Array = []
	while x < level_w:
		# next flat zone at or after x
		while fi < flats.size() and (flats[fi] as Vector2).y <= x:
			fi += 1
		var zone: Vector2 = flats[fi] if fi < flats.size() else Vector2(level_w + 1.0, level_w + 1.0)
		if x >= zone.x:
			# inside a flat zone: make sure we are at base height, then run to the zone end
			if top != base:
				ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
				seg_x = x
				top = base
			x = minf(zone.y, level_w)
			continue
		var room := zone.x - x  # transit space before the next arena
		if room < 260.0:
			x = zone.x
			continue
		var pick := rng.randf()
		if pick < 0.30:
			x += rng.randf_range(220.0, 420.0)  # flat run
		elif pick < 0.55 and room > 640.0 and top == base:
			# raised (or sunken) ground block: step, run, step back
			var h := rng.randf_range(50.0, STEP_MAX) * (1.0 if rng.randf() < 0.6 else -1.0)  # negative = sunken block
			ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
			seg_x = x
			top = base - h
			x += rng.randf_range(300.0, 480.0)
			ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
			seg_x = x
			top = base
		elif pick < 0.85 and room > 520.0:
			# pit
			var gw := rng.randf_range(GAP_MIN, GAP_MAX)
			ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
			x += gw
			seg_x = x
			x += rng.randf_range(260.0, 380.0)
		elif room > 760.0:
			# wide pit with an island platform in the middle (reached with one jump from each side)
			var gw2 := rng.randf_range(360.0, 440.0)
			ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
			gap_islands.append(Rect2(x + gw2 * 0.5 - 70.0, top - 110.0, 140.0, PLAT_H))
			x += gw2
			seg_x = x
			x += rng.randf_range(260.0, 380.0)
		else:
			x += 260.0
	ground_segs.append(Rect2(seg_x, top, minf(x, level_w) - seg_x, 700.0))
	# make the last piece reach the level's end wall
	var last: Rect2 = ground_segs[ground_segs.size() - 1]
	ground_segs[ground_segs.size() - 1] = Rect2(last.position.x, last.position.y, level_w - last.position.x, 700.0)
	platforms.append_array(gap_islands)

	# platforms above solid ground: low tier 150 px up, sometimes a second, high tier 270 px up beside it
	for g: Rect2 in ground_segs:
		if g.size.x < 420.0 or rng.randf() > 0.7:
			continue
		var w := rng.randf_range(250.0, 320.0)
		var px := g.position.x + rng.randf_range(30.0, maxf(31.0, g.size.x - w - 30.0))
		var low := Rect2(px, g.position.y - 150.0, w, PLAT_H)
		platforms.append(low)
		if rng.randf() < 0.4 and low.end.x + 260.0 < g.end.x:
			var hw := rng.randf_range(200.0, 260.0)
			platforms.append(Rect2(low.end.x + 70.0, g.position.y - 270.0, hw, PLAT_H))

	# containers: on solid ground or on a platform, never over a pit
	var n_props: int = {"fight": 10, "elite": 12, "treasure": 22, "boss": 5}.get(t, 10)
	for i in n_props:
		var kind := _pick(rng, [["crate", 50], ["barrel", 30], ["vase", 20]])
		if rng.randf() < 0.35 and platforms.size() > 0:
			var pl: Rect2 = platforms[rng.randi() % platforms.size()]
			props_spec.append([pl.position.x + rng.randf_range(30.0, pl.size.x - 30.0), kind, pl.position.y])
		else:
			for tries in 12:
				var px2 := rng.randf_range(300.0, level_w - 400.0)
				if is_safe_ground(Vector2(px2, ground_at(px2))):
					props_spec.append([px2, kind])
					break
