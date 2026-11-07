extends Node
## Generated levels: crossable gaps, reachable platforms, clearance, flat arenas, determinism.

func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _make(type: String, seed_v: int) -> StreetsLevel:
	var lv := StreetsLevel.new()
	lv._generated({"type": type, "seed": seed_v}, 1)
	return lv


func _ready() -> void:
	var rise := 170.0
	var bad_gap := 0
	var bad_step := 0
	var bad_reach := 0
	var bad_clear := 0
	var bad_arena := 0
	var total_plat := 0
	var gaps := 0
	for type in ["fight", "elite", "treasure", "boss"]:
		for s in range(1, 21):
			var lv := _make(type, s)
			var segs: Array = lv.ground_segs
			for i in range(1, segs.size()):
				var a: Rect2 = segs[i - 1]
				var b: Rect2 = segs[i]
				var gap := b.position.x - a.end.x
				if gap > 1.0:
					gaps += 1
					if gap > 445.0:
						bad_gap += 1
				if absf(b.position.y - a.position.y) > 100.5:
					bad_step += 1
			# platforms
			for p: Rect2 in lv.platforms:
				total_plat += 1
				var ok := false
				var surfaces: Array = []
				for g: Rect2 in segs:
					surfaces.append(Rect2(g.position.x, g.position.y, g.size.x, 0))
				for q: Rect2 in lv.platforms:
					if q != p:
						surfaces.append(Rect2(q.position.x, q.position.y, q.size.x, 0))
				for sfc: Rect2 in surfaces:
					var up: float = sfc.position.y - p.position.y
					var dx: float = maxf(0.0, maxf(sfc.position.x - p.end.x, p.position.x - sfc.end.x))
					if up <= rise - 8.0 and up >= -300.0 and dx < 200.0:
						ok = true
				if not ok:
					bad_reach += 1
				var gy: float = lv.ground_at(p.position.x + p.size.x * 0.5)
				if gy != INF and gy - p.end.y < 132.0 and gy - p.position.y > 20.0:
					bad_clear += 1
			for e in lv.encounters:
				var x := float(e["x"]) - 740.0
				while x <= float(e["x"]) + 740.0:
					if lv.ground_at(x) != lv.ground_y:
						bad_arena += 1
					x += 40.0
			lv.free()
	check("%d pits generated; none wider than an island jump" % gaps, gaps > 20 and bad_gap == 0)
	check("steps never exceed 100 px", bad_step == 0)
	check("%d platforms all reachable by a single jump chain" % total_plat, bad_reach == 0)
	check("platform undersides clear the boss", bad_clear == 0)
	check("encounter arenas are flat at the base height", bad_arena == 0)
	var a := _make("fight", 7)
	var b := _make("fight", 7)
	check("same seed gives the same terrain", a.ground_segs == b.ground_segs and a.platforms == b.platforms)
	var heights := {}
	for g: Rect2 in a.ground_segs:
		heights[g.position.y] = true
	print("  info  fight seed 7: %d ground pieces, %d platforms, heights %s" % [a.ground_segs.size(), a.platforms.size(), str(heights.keys())])
	get_tree().quit()
