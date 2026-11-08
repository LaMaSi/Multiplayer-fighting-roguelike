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
		{"x": 1300.0, "waves": [[["thug", 1]], [["thug", 1], ["thrower", 1]]]},
		{"x": 2650.0, "waves": [[["thug", 1], ["biker", 1]], [["thrower", 1]]]},
		{"x": 3900.0, "waves": [[["biker", 1], ["thug", 1]], [["thrower", 1], ["thug", 1]]]},
		{"x": 5100.0, "waves": [[["thug", 2]], [["biker", 1], ["thrower", 1]]]},
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
	if rng.randf() < 0.1:
		for i in 3 + depth / 3 + w:
			var k := _pick(rng, [["thug", 60], ["thrower", 25], ["biker", 15]])
			tally[k] = int(tally.get(k, 0)) + 1
	else:
		var tanks := 1 + (1 if (depth + bonus + w) >= 6 else 0)
		for i in tanks:
			var k2 := _pick(rng, [["brute", 65], ["heavy", 20 + depth * 5]])
			tally[k2] = int(tally.get(k2, 0)) + 1
		for i in rng.randi_range(0, 1):
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
	var pits: Array = []  # Vector3(x, width, ground top)
	var tunnels: Array = []  # Vector2(x of the tunnel, length): a roofed walk-through passage with a route over the roof
	var max_tunnels := 0 if t == "boss" else (2 if level_w > 7500.0 else 1)
	tunnel_roofs = []
	moving_specs = []
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
		if tunnels.size() < max_tunnels and room > 820.0 and top == base and rng.randf() < 0.55:
			# a tunnel on flat ground: walk through it, or jump up and cross over the roof
			var tl := rng.randf_range(460.0, minf(640.0, room - 260.0))
			var tx := x + 130.0
			tunnels.append(Vector2(tx, tl))
			x = tx + tl + 130.0
			continue
		var pick := rng.randf()
		if pick < 0.16:
			x += rng.randf_range(220.0, 420.0)  # flat run
		elif pick < 0.38 and room > 1000.0 and top == base:
			# staircase: two steps up, a landing, then back down in one go
			var h1 := rng.randf_range(50.0, 85.0)
			var h2 := h1 + rng.randf_range(50.0, 85.0)
			ground_segs.append(Rect2(seg_x, top, x - seg_x, 700.0))
			seg_x = x
			x += rng.randf_range(160.0, 240.0)
			ground_segs.append(Rect2(seg_x, base - h1, x - seg_x, 700.0))
			seg_x = x
			x += rng.randf_range(200.0, 320.0)
			ground_segs.append(Rect2(seg_x, base - h2, x - seg_x, 700.0))
			seg_x = x
			x += rng.randf_range(160.0, 240.0)
			ground_segs.append(Rect2(seg_x, base - h1, x - seg_x, 700.0))
			seg_x = x
			top = base
			x += 40.0
			ground_segs.append(Rect2(seg_x, base, x - seg_x, 700.0))
			seg_x = x
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
			pits.append(Vector3(x, gw, top))
			x += gw
			seg_x = x
			x += rng.randf_range(260.0, 380.0)
		elif room > 760.0:
			# wide pit with an island platform in the middle (reached with one jump from each side)
			var gw2 := rng.randf_range(360.0, 440.0)
			pits.append(Vector3(x, gw2, -top))  # negative top: this one already has its island
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

	# moving platforms: bridges that glide across pits, bobbing lifts, and floating stairs in the air
	for pt: Vector3 in pits:
		if pt.z < 0.0:
			continue
		if rng.randf() < 0.55:
			var pw := 130.0
			moving_specs.append({"rect": Rect2(pt.x + pt.y * 0.5 - pw * 0.5, pt.z - 30.0, pw, PLAT_H), "vertical": false, "travel": maxf(30.0, pt.y * 0.5 - pw * 0.5 - 40.0), "period": rng.randf_range(3.6, 5.0), "phase": rng.randf()})
	for g3: Rect2 in ground_segs:
		if g3.size.x < 520.0:
			continue
		var roll := rng.randf()
		if roll < 0.3:
			# lift: a platform bobbing between 90 and 330 px above the ground, high stuff to reach
			var lx := g3.position.x + rng.randf_range(60.0, g3.size.x - 200.0)
			moving_specs.append({"rect": Rect2(lx, g3.position.y - 210.0, 120.0, PLAT_H), "vertical": true, "travel": 110.0, "period": rng.randf_range(3.4, 4.6), "phase": rng.randf()})
		elif roll < 0.6 and g3.size.x > 700.0:
			# floating stairs high in the air
			var sx := g3.position.x + rng.randf_range(40.0, g3.size.x - 640.0)
			for si in 3:
				platforms.append(Rect2(sx + si * 190.0, g3.position.y - 150.0 - si * 100.0, 150.0, PLAT_H))
		elif roll < 0.8:
			# a mover patrolling above the ground
			var mx0 := g3.position.x + rng.randf_range(160.0, maxf(161.0, g3.size.x - 240.0))
			moving_specs.append({"rect": Rect2(mx0, g3.position.y - 180.0, 150.0, PLAT_H), "vertical": false, "travel": 140.0, "period": rng.randf_range(3.6, 5.0), "phase": rng.randf()})
	# every arena gets its own mix of platforms so battles use height
	for e in encounters:
		var ax := float(e["x"])
		if t == "boss":
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		platforms.append(Rect2(ax + side * 330.0 - 110.0, ground_y - 150.0, 220.0, PLAT_H))
		platforms.append(Rect2(ax + side * 530.0 - 90.0, ground_y - 260.0, 180.0, PLAT_H))
		moving_specs.append({"rect": Rect2(ax - side * 120.0 - 75.0, ground_y - 200.0, 150.0, PLAT_H), "vertical": rng.randf() < 0.4, "travel": 130.0, "period": rng.randf_range(3.6, 4.8), "phase": rng.randf()})

	# tunnels: clear other platforms from the tunnel and add the roof (a normal one-way platform at the low tier, so the
	# ledge grab, the enemy climbing and the shadows all treat it like any platform)
	for tn: Vector2 in tunnels:
		var span := Rect2(tn.x - 80.0, -2000.0, tn.y + 160.0, 4000.0)
		platforms = platforms.filter(func(pl2: Rect2) -> bool: return not (pl2.position.x < span.end.x and pl2.end.x > span.position.x))
		moving_specs = moving_specs.filter(func(m: Dictionary) -> bool: return not ((m["rect"] as Rect2).position.x - float(m["travel"]) < span.end.x and (m["rect"] as Rect2).end.x + float(m["travel"]) > span.position.x))
		var roof := Rect2(tn.x, ground_top(tn.x + tn.y * 0.5) - 150.0, tn.y, PLAT_H)
		platforms.append(roof)
		tunnel_roofs.append(roof)

	# doors: one or two per fight / elite level on solid ground between the arenas (challenge room or move shop)
	doors_spec = []
	if t == "fight" or t == "elite":
		var cands: Array = []
		for g2: Rect2 in ground_segs:
			var cx := g2.position.x + g2.size.x * 0.5
			var in_flat := false
			for z: Vector2 in flats:
				if cx >= z.x and cx <= z.y:
					in_flat = true
			var in_tunnel := false
			for tn2: Rect2 in tunnel_roofs:
				if cx >= tn2.position.x - 160.0 and cx <= tn2.end.x + 160.0:
					in_tunnel = true
			if g2.size.x >= 300.0 and not in_flat and not in_tunnel:
				cands.append(cx)
		if cands.is_empty():
			cands.append(level_w - 540.0)  # always at least one door: in the flat stretch before the exit
		var kinds: Array = ["challenge", "shop"] if rng.randf() < 0.5 else ["shop", "challenge"]
		var n_doors := 1 + (1 if rng.randf() < 0.4 else 0)
		for i in mini(n_doors, cands.size()):
			var ci := rng.randi() % cands.size()
			doors_spec.append({"x": cands[ci], "kind": kinds[i % 2]})
			cands.remove_at(ci)

	# floor hazards: spike traps, bumpers and throwable springs inside every arena (so enemies can be thrown into them),
	# plus the odd spike trap on the road between arenas
	hazards_spec = []
	for e in encounters:
		var ex := float(e["x"])
		var sgn := -1.0 if rng.randf() < 0.5 else 1.0
		hazards_spec.append({"kind": "spikes", "x": ex + sgn * rng.randf_range(260.0, 520.0)})
		if rng.randf() < 0.6:
			hazards_spec.append({"kind": "bumper", "x": ex - sgn * rng.randf_range(220.0, 480.0)})
		if rng.randf() < 0.5:
			hazards_spec.append({"kind": "spring", "x": ex + rng.randf_range(-150.0, 150.0)})
	for i in 2:
		for tries in 10:
			var hx := rng.randf_range(400.0, level_w - 600.0)
			if is_safe_ground(Vector2(hx, ground_at(hx))):
				hazards_spec.append({"kind": "spikes" if rng.randf() < 0.7 else "spring", "x": hx})
				break

	# ceiling spikes: hang under a few raised platforms, but only where the underside is at launch height above the local
	# ground. They hurt enemies only (an anvil for thrown bodies), so they are never a jumping hazard for the players.
	var ceil_cands: Array = []
	for pl: Rect2 in platforms:
		var under_h := ground_top(pl.get_center().x) - pl.end.y
		if pl.size.x >= 140.0 and under_h >= SpikeTrap.AIR_MIN_H and under_h <= SpikeTrap.AIR_MAX_H and not tunnel_roofs.has(pl):
			ceil_cands.append(pl)
	var n_ceil := 0
	while n_ceil < 3 and not ceil_cands.is_empty():
		var ci2 := rng.randi() % ceil_cands.size()
		var cp: Rect2 = ceil_cands[ci2]
		ceil_cands.remove_at(ci2)
		if rng.randf() < 0.7:
			var cw := minf(cp.size.x * 0.6, 120.0)
			hazards_spec.append({"kind": "ceiling_spikes", "x": cp.get_center().x + rng.randf_range(-cp.size.x * 0.12, cp.size.x * 0.12), "y": cp.end.y + DepthLayer.PLAT_LIP, "w": cw})
			n_ceil += 1

	# in a tunnel: sometimes ceiling spikes under the roof (throw enemies into them), always a few containers on the roof
	for roof2: Rect2 in tunnel_roofs:
		if rng.randf() < 0.6:
			hazards_spec.append({"kind": "ceiling_spikes", "x": roof2.get_center().x + rng.randf_range(-roof2.size.x * 0.2, roof2.size.x * 0.2), "y": roof2.end.y + DepthLayer.TUNNEL_EXTRA + DepthLayer.PLAT_LIP, "w": 120.0})

	# containers: on solid ground or on a platform, never over a pit
	var n_props: int = {"fight": 10, "elite": 12, "treasure": 22, "boss": 5}.get(t, 10)
	for i in n_props:
		var kind := _pick(rng, [["crate", 42], ["barrel", 25], ["vase", 17], ["explosive", 16]])
		if rng.randf() < 0.35 and platforms.size() > 0:
			var pl: Rect2 = platforms[rng.randi() % platforms.size()]
			props_spec.append([pl.position.x + rng.randf_range(30.0, pl.size.x - 30.0), kind, pl.position.y])
		else:
			for tries in 12:
				var px2 := rng.randf_range(300.0, level_w - 400.0)
				if is_safe_ground(Vector2(px2, ground_at(px2))):
					props_spec.append([px2, kind])
					break
	# the way over the tunnel is the rewarding one: containers on the roof, and one inside for the way through
	for roof3: Rect2 in tunnel_roofs:
		for i in 3:
			props_spec.append([roof3.position.x + roof3.size.x * (0.2 + 0.3 * i) + rng.randf_range(-30.0, 30.0), _pick(rng, [["crate", 45], ["barrel", 30], ["explosive", 25]]), roof3.position.y])
		props_spec.append([roof3.get_center().x + rng.randf_range(-120.0, 120.0), "crate"])
