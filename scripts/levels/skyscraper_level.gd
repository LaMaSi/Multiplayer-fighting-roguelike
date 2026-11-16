class_name SkyscraperLevel
extends LevelBase
## Level set 2: Skyscraper. The level is one screen wide and scrolls UP. Rows of platforms (one-way platforms, solid
## blocks, lifts and movers) lead from the street to a goal block at the top. Thick walls close the sides.
## Every so often a battle floor locks the screen: a ceiling drops in, the camera stops, and everything that falls out
## of the bottom of the screen is a fall (players lose a little health, enemies are out for good). Enemies drop in one
## by one in the middle of the screen on a timer, so a team that passes them back and forth quickly only ever fights
## one or two at a time. After a battle a gate in the side wall may open: walk through it and the screen scrolls
## sideways into a shop or a challenge screen (SideRoom).
##
## Generation: each row of the climb is placed so that it does not overlap anything already there, keeps clear of the
## side walls, and can be reached from the row below; every stretch up to a battle floor or the goal is checked with
## a reach test (reach() / climbable()) and rolled again if it fails.

const W := 1500.0  ## level width = exactly one screen
const VIEW_H := 720.0 * W / 1280.0  ## world height of one screen at the fixed zoom
const WALL_IN := 50.0  ## the side walls reach this far into the screen
const PL := WALL_IN  ## left end of the playfield
const PR := W - WALL_IN  ## right end of the playfield
const WALL_T := 100.0  ## how far the walls reach outside the screen
const STEP := 150.0  ## height between two rows of the climb (a jump rises about 215 px)
const FLOOR_PAD := 80.0  ## a locked battle screen ends this far below its floor
const STAND_UP := 380.0  ## free climbing: the leader stands this far above the bottom of the screen
const CEIL_H := 730.0  ## underside of a battle ceiling above its floor (the row 4 steps up still has head room under it)
const GATE_H := 200.0  ## height of a side gate
const FLOOR_T := 56.0  ## thickness of solid blocks
const TRICKLE_CAP := 4  ## never more than this many enemies alive in a battle

## Reach (the jump is about 215 px high; ~0.5 s in the air at the air speed): what the generator and the tests accept.
const REACH_UP := 175.0  ## the highest step a jump safely lands on
const REACH_GAP := 160.0  ## widest edge-to-edge gap to a higher platform
const REACH_GAP_FLAT := 220.0  ## ... to one at about the same height or lower
## Placement rules
const WALL_CLEAR := 130.0  ## a platform either touches a side wall or keeps at least this much room to it
const ROW_GAP := 140.0  ## two platforms on one row keep at least this much room between them
const HEAD_ROOM := 110.0  ## free height between a surface and anything above it that overlaps it

var top_y := 0.0  ## the highest point of the tower (camera limit)
var goal := Rect2()  ## the goal block at the top (empty in the boss level)
var gates: Array = []  ## {floor, y, side (-1 left / 1 right), kind, pick, open, used, body}
var rows: Array = []  ## what was generated, bottom to top: {y, kind, rects: [Rect2], solid, moving}
var surfs: Array = []  ## every surface for the reach test: {x0, x1, y (leave from), by (board at), solid, box (space it takes)}
var _surf: Array[Rect2] = []  ## every fixed surface to stand on: platforms and solid blocks
var _stand: Array[float] = []  ## per fighter: the height the camera uses for them (their last footing)
var _kill := INF  ## while a battle is locked: falling below this line is a fall
var _lock_floor := 0.0
var _trickle: Dictionary = {}  ## the running enemy drip: {queue, burst, t, interval, cap, xs, y, next_x, total}
var _gate: Dictionary = {}  ## the gate whose room the players are in
var _overlay: Node2D
var _walls_node: Node2D  ## the walls' front faces
var _walls_back: Node2D  ## the walls' faces running back into the depth, the doorway passages and the gate signs


func _setup() -> void:
	level_name = "Skyscraper"
	level_w = W
	theme["sky_top"] = Color(0.05, 0.05, 0.20)
	theme["sky_bottom"] = Color(0.30, 0.45, 0.85)
	theme["neon_ground"] = Pal.terrain()
	theme["neon_plat"] = Pal.terrain()
	theme["seed"] = 11
	if RunState.active:
		_generated(RunState.current, RunState.levels_cleared)
	else:
		_generated({"type": "fight", "seed": 7}, 0)


func _ready() -> void:
	super._ready()
	Coop.bounds = _tower_bounds()
	hud.go_text = "GO UP"
	hud.go_pos = Vector2(640, 150)
	hud.set_go(true)
	var facade := Node2D.new()
	facade.z_index = -40
	facade.draw.connect(_paint_facade.bind(facade))
	add_child(facade)
	_overlay = Node2D.new()
	_overlay.z_index = -4  # above the platforms, below the shadows' owners
	_overlay.draw.connect(_paint_overlay)
	add_child(_overlay)
	# the walls work like the ground: a flat front face that cuts the screen edge cleanly, in front of everything, and an
	# inner face that runs back into the depth behind the platforms and the fighters
	_walls_back = Node2D.new()
	_walls_back.z_index = -12  # behind the platforms (-11), shadows and fighters; over the side rooms (SideRoom.Z)
	_walls_back.draw.connect(_paint_walls_back)
	add_child(_walls_back)
	_walls_node = Node2D.new()
	_walls_node.z_index = 5  # the front face: over the fighters (they never stand inside a wall)
	_walls_node.draw.connect(_paint_walls)
	add_child(_walls_node)


func _tower_bounds() -> Rect2:
	return Rect2(PL, top_y - 3000.0, PR - PL, ground_y - top_y + 6000.0)


func _par_seconds() -> float:
	var n := 0
	for e in encounters:
		n += (e["queue"] as Array).size()
	return 45.0 + (ground_y - top_y) / 45.0 + 8.0 * n


# ------------------------------------------------------------------ generation

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


## Tower built from a map node: type fight / elite / treasure / boss, seeded for reproducibility.
func _generated(node: Dictionary, depth: int) -> void:
	var t: String = node["type"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node["seed"])
	enemy_hp_mult = (1.0 + 0.12 * depth) * (1.35 if t == "elite" else 1.0)
	enemy_dmg_mult = 1.0 + 0.06 * depth
	objective = {"fight": "Climb to the goal at the top", "elite": "Beat the elite guard on the way to the top",
		"treasure": "Smash the loot on the way to the top", "boss": "Climb up and take down the boss"}.get(t, "Climb to the goal at the top")
	platforms = []
	solids = []
	moving_specs = []
	hazards_spec = []
	props_spec = []
	encounters = []
	gates = []
	rows = []
	surfs = []
	var n_fl: int = {"fight": 2, "elite": 3, "boss": 1}.get(t, 0)
	var types: Array = []
	for i in n_fl:
		types.append("semiblock" if t == "boss" else _pick(rng, [["semi", 25], ["block", 30], ["split", 25], ["semiblock", 20]]))
	# side gates (a shop or a challenge screen): one or two per fight / elite tower, on floors that reach the wall
	if t == "fight" or t == "elite":
		var ok: Array = []
		for i in n_fl:
			if types[i] != "block":
				ok.append(i)
		if ok.is_empty():
			types[0] = "semiblock"
			ok.append(0)
		var kinds: Array = ["challenge", "shop"] if rng.randf() < 0.5 else ["shop", "challenge"]
		var n_g := 1 + (1 if rng.randf() < 0.4 else 0)
		var last_floor := -1
		var last_side := 0
		for i in n_g:
			var fl: int = ok[rng.randi() % ok.size()]
			var side := -1 if rng.randf() < 0.5 else 1
			if fl == last_floor:
				side = -last_side  # two gates on one floor: one on each side
			gates.append({"floor": fl, "y": 0.0, "side": side, "kind": kinds[i % 2], "pick": rng.randf() < 0.4, "open": false, "used": false, "body": null})
			last_floor = fl
			last_side = side

	# the street is the first surface
	var street := _surface(Rect2(PL, ground_y, PR - PL, 400.0), true)
	surfs.append(street)
	var below: Array = [street]
	var y := ground_y
	for i in n_fl:
		var n := rng.randi_range(4, 5) if i == 0 else rng.randi_range(4, 6)
		if t == "boss":
			n = 3
		var f_y := y - STEP * float(n + 1)
		below = _climb(rng, below, y, n, String(types[i]), f_y)
		var fl_s := _floor(rng, f_y, String(types[i]), i, n_fl, depth, t)
		for g in gates:
			if int(g["floor"]) == i:
				g["y"] = f_y
		# the arena above the floor: a perch against each wall for the two players, something in the middle higher up
		var perch := _row(rng, f_y - STEP, "perch", [])
		var mid := _row(rng, f_y - STEP * 2.0, "arena_mid" if rng.randf() < 0.55 else "mover", [])
		below = mid if not mid.is_empty() else perch
		if below.is_empty():
			below = fl_s
		y = f_y - STEP * 2.0
	if t == "boss":
		top_y = y - CEIL_H
	else:
		var n2 := 12 if n_fl == 0 else rng.randi_range(4, 5)
		var g_y := y - STEP * float(n2 + 1)
		_climb(rng, below, y, n2, "goal", g_y)
		goal = Rect2(W * 0.5 - 260.0, g_y, 520.0, FLOOR_T)
		_add_rect(goal, true)
		rows.append({"y": g_y, "kind": "goal", "rects": [goal], "solid": true, "moving": false})
		top_y = g_y - 500.0
	_surf.clear()
	for r: Rect2 in platforms:
		_surf.append(r)
	for r: Rect2 in solids:
		_surf.append(r)
	_place_props(rng, t)


## A surface for the reach test. `r` is the collision rect; a moving platform passes its whole travel.
func _surface(r: Rect2, solid: bool, by := INF, sweep := Rect2()) -> Dictionary:
	return {"x0": r.position.x, "x1": r.end.x, "y": r.position.y, "by": r.position.y if by == INF else by, "solid": solid,
		"box": sweep if sweep.size != Vector2.ZERO else r}


func _add_rect(r: Rect2, solid: bool) -> Dictionary:
	if solid:
		solids.append(r)
	else:
		platforms.append(r)
	var s := _surface(r, solid)
	surfs.append(s)
	return s


## Can a fighter get from surface a onto surface b with one jump (or by dropping down)?
static func reach(a: Dictionary, b: Dictionary) -> bool:
	var rise: float = float(a["y"]) - float(b["by"])
	if rise > REACH_UP or rise < -420.0:
		return false
	var gap := maxf(0.0, maxf(float(b["x0"]) - float(a["x1"]), float(a["x0"]) - float(b["x1"])))
	if gap > (REACH_GAP if rise > 40.0 else REACH_GAP_FLAT):
		return false
	# a solid block is mounted from beside it, never from right underneath
	if bool(b["solid"]) and rise > 4.0 and float(a["x0"]) >= float(b["x0"]) - 30.0 and float(a["x1"]) <= float(b["x1"]) + 30.0:
		return false
	return true


## True when one of `targets` can be reached from one of `starts` over all the tower's surfaces.
func climbable(starts: Array, targets: Array) -> bool:
	var seen := {}
	var todo: Array = []
	for s in starts:
		var i := surfs.find(s)
		if i >= 0:
			seen[i] = true
			todo.append(i)
	var want := {}
	for t in targets:
		want[surfs.find(t)] = true
	while not todo.is_empty():
		var i: int = todo.pop_back()
		if want.has(i):
			return true
		for j in surfs.size():
			if not seen.has(j) and reach(surfs[i], surfs[j]):
				seen[j] = true
				todo.append(j)
	return false


## Would rect r (taking up the space `box`) fit: away from the walls unless touching them, clear of every other surface?
func _fits(r: Rect2, box: Rect2) -> bool:
	if r.position.x < PL - 0.5 or r.end.x > PR + 0.5:
		return false
	var lg := r.position.x - PL
	var rg := PR - r.end.x
	if (lg > 0.5 and lg < WALL_CLEAR) or (rg > 0.5 and rg < WALL_CLEAR):
		return false
	for s in surfs:
		var e: Rect2 = s["box"]
		var ox := minf(box.end.x, e.end.x) - maxf(box.position.x, e.position.x)
		if absf(box.position.y - e.position.y) < 20.0 or (box.position.y < e.end.y and e.position.y < box.end.y):
			# side by side (or crossing): keep a gap
			if ox > -ROW_GAP:
				return false
		elif ox > 4.0:
			# one above the other: head room between them
			var top := box if box.position.y < e.position.y else e
			var bot := e if top == box else box
			if bot.position.y - top.end.y < HEAD_ROOM:
				return false
	# nothing in a battle ceiling's squeeze band (between the ceiling and a fighter's head); rows hidden inside the
	# ceiling slab are fine, nobody is up there during the fight
	for enc in encounters:
		var cb: float = float(enc["y"]) - CEIL_H
		if box.position.y < cb + HEAD_ROOM and box.end.y > cb + 2.0:
			return false
	return true


## Clamps a platform of width w near x0 into the playfield, flush with a wall when it gets too close to one.
func _fit_x(x0: float, w: float) -> float:
	x0 = clampf(x0, PL, PR - w)
	if x0 - PL < WALL_CLEAR:
		x0 = PL if x0 - PL < WALL_CLEAR * 0.5 else PL + WALL_CLEAR
	if PR - (x0 + w) < WALL_CLEAR:
		x0 = PR - w if PR - (x0 + w) < WALL_CLEAR * 0.5 else PR - WALL_CLEAR - w
	return clampf(x0, PL, PR - w)


## Rows from `y0` up to just under a floor / the goal at `f_y` (n rows). The last row is the way onto the floor.
## Every attempt is checked with the reach test; a failed one is taken back and rolled again, and the last resort is a
## plain zigzag. Returns the last row's surfaces.
func _climb(rng: RandomNumberGenerator, below: Array, y0: float, n: int, end_kind: String, f_y: float) -> Array:
	var approach: String = {"semi": "any", "block": "edges", "split": "under", "semiblock": "pair", "goal": "pair"}.get(end_kind, "any")
	var target := _floor_probe(end_kind, f_y)
	for attempt in 16:
		var mark := [platforms.size(), solids.size(), moving_specs.size(), rows.size(), surfs.size()]
		var prev := below
		var last: Array = []
		var i := 1
		var kinds_used: Array = []
		while i <= n:
			var y := y0 - STEP * float(i)
			var kind := approach if (i == n and approach != "any") else ""
			if kind == "":
				kind = _pick(rng, [["step", 42], ["pair", 12], ["trio", 8], ["full", 7], ["block", 12], ["mover", 11], ["lift", 8]])
				if attempt >= 10:
					kind = "step"
				if kind in kinds_used.slice(-1) and kind != "step":
					kind = "step"
				if kind == "lift" and i >= n - 1:
					kind = "step"  # a lift takes two rows
			var got := _row(rng, y, kind, prev)
			if got.is_empty() and kind != "step":
				got = _row(rng, y, "step", prev)
			if got.is_empty():
				break
			kinds_used.append(kind)
			if kind == "lift":
				i += 1  # the lift rides up through the next row too
			prev = got
			last = got
			i += 1
		if i > n and climbable(below, target["surfs"]):
			_probe_cleanup(target)
			return last
		_rollback(mark)
	# last resort: a zigzag of plain steps (always climbable), ending in the approach row
	var prev2 := below
	for i in n:
		var y := y0 - STEP * float(i + 1)
		var w := 420.0
		var cx := W * (0.35 if i % 2 == 0 else 0.65)
		var r := Rect2(cx - w * 0.5, y, w, PLAT_H)
		if i == n - 1 and approach != "any":
			prev2 = _row(rng, y, approach, [])
			continue
		prev2 = [_add_rect(r, false)]
		rows.append({"y": y, "kind": "step", "rects": [r], "solid": false, "moving": false})
	_probe_cleanup(target)
	return prev2


## Stand-in surfaces of the floor / goal that ends a climb, used by the reach test while that climb is built.
func _floor_probe(kind: String, f_y: float) -> Dictionary:
	var out: Array = []
	match kind:
		"semi":
			out.append(_surface(Rect2(PL, f_y, PR - PL, PLAT_H), false))
		"block":
			out.append(_surface(Rect2(300.0, f_y, 900.0, FLOOR_T), true))
		"split":
			out.append(_surface(Rect2(680.0, f_y, 140.0, PLAT_H), false))
			out.append(_surface(Rect2(PL, f_y, 600.0 - PL, FLOOR_T), true))
			out.append(_surface(Rect2(900.0, f_y, PR - 900.0, FLOOR_T), true))
		"semiblock":
			out.append(_surface(Rect2(PL, f_y, 450.0 - PL, PLAT_H), false))
			out.append(_surface(Rect2(1050.0, f_y, PR - 1050.0, PLAT_H), false))
		_:
			out.append(_surface(Rect2(W * 0.5 - 260.0, f_y, 520.0, FLOOR_T), true))
	surfs.append_array(out)
	return {"surfs": out}


func _probe_cleanup(p: Dictionary) -> void:
	for s in p["surfs"]:
		surfs.erase(s)


func _rollback(mark: Array) -> void:
	# the probe surfaces sit before the mark: keep them, drop everything this attempt added after them
	platforms.resize(mark[0])
	solids.resize(mark[1])
	moving_specs.resize(mark[2])
	rows.resize(mark[3])
	surfs.resize(mark[4])


## One row of the climb at height `y`, reachable from one of the surfaces in `prev` (empty = no check, fixed rows).
## Returns its surfaces, or [] when nothing fitted.
func _row(rng: RandomNumberGenerator, y: float, kind: String, prev: Array) -> Array:
	var cands: Array = []  # each: [rects (Array of Rect2), solid, mover dict or {}]
	var tries := 8
	for k in tries:
		var rects: Array = []
		var solid := false
		var mover := {}
		match kind:
			"step":
				var a: Dictionary = prev[rng.randi() % prev.size()] if not prev.is_empty() else _surface(Rect2(W * 0.5 - 200.0, y + STEP, 400.0, PLAT_H), false)
				var w := rng.randf_range(300.0, 440.0)
				var ac := (float(a["x0"]) + float(a["x1"])) * 0.5
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var cx := ac + side * rng.randf_range(250.0, 430.0)
				if cx < PL + 160.0 or cx > PR - 160.0:
					cx = ac - side * rng.randf_range(250.0, 430.0)
				rects.append(Rect2(_fit_x(cx - w * 0.5, w), y, w, PLAT_H))
			"pair", "edges":
				var lo := 160.0 if kind == "edges" else 240.0
				var hi := 200.0 if kind == "edges" else 360.0
				rects.append(Rect2(PL, y, rng.randf_range(lo, hi), PLAT_H))
				var w2 := rng.randf_range(lo, hi)
				rects.append(Rect2(PR - w2, y, w2, PLAT_H))
			"trio":
				var w3 := rng.randf_range(220.0, 280.0)
				rects.append(Rect2(PL, y, w3, PLAT_H))
				rects.append(Rect2(PR - w3, y, w3, PLAT_H))
				var wc := rng.randf_range(300.0, 380.0)
				rects.append(Rect2(W * 0.5 - wc * 0.5, y, wc, PLAT_H))
			"full":
				rects.append(Rect2(PL, y, PR - PL, PLAT_H))
			"perch":
				rects.append(Rect2(PL, y, 280.0, PLAT_H))
				rects.append(Rect2(PR - 280.0, y, 280.0, PLAT_H))
			"arena_mid":
				rects.append(Rect2(W * 0.5 - 280.0, y, 560.0, PLAT_H))  # wide enough to reach from the perches
			"under":
				rects.append(Rect2(W * 0.5 - 130.0, y, 260.0, PLAT_H))
			"block":
				solid = true
				var bw := rng.randf_range(480.0, 640.0)
				rects.append(Rect2(W * 0.5 - bw * 0.5, y, bw, FLOOR_T))
			"mover":
				var mw := 170.0
				var tr := 250.0
				mover = {"rect": Rect2(W * 0.5 - mw * 0.5, y, mw, PLAT_H), "vertical": false, "travel": tr, "period": rng.randf_range(4.2, 5.2), "phase": rng.randf()}
			"lift":
				# a lift beside a platform of the row below: from just above that platform up to the row above this one
				if prev.is_empty():
					break
				var a2: Dictionary = prev[rng.randi() % prev.size()]
				var lw := 160.0
				var sd := -1.0 if rng.randf() < 0.5 else 1.0
				var lx := (float(a2["x0"]) - 60.0 - lw) if sd < 0.0 else (float(a2["x1"]) + 60.0)
				lx = _fit_x(lx, lw)
				if lx < float(a2["x1"]) + 30.0 and lx + lw > float(a2["x0"]) - 30.0:
					continue  # pushed against a wall and over its own platform: try another place
				var lo_top := float(a2["y"]) - 50.0
				var hi_top := y - STEP + 40.0
				var trv := (lo_top - hi_top) * 0.5
				mover = {"rect": Rect2(lx, (lo_top + hi_top) * 0.5, lw, PLAT_H), "vertical": true, "travel": trv, "period": rng.randf_range(3.8, 4.6), "phase": rng.randf(),
					"lo": lo_top, "hi": hi_top}
		# check
		var ok := true
		var new_s: Array = []
		for r: Rect2 in rects:
			if not _fits(r, r):
				ok = false
		var mbox := Rect2()
		if not mover.is_empty():
			var mr: Rect2 = mover["rect"]
			if bool(mover["vertical"]):
				mbox = Rect2(mr.position.x, float(mover["hi"]), mr.size.x, float(mover["lo"]) - float(mover["hi"]) + PLAT_H)
			else:
				mbox = Rect2(mr.position.x - float(mover["travel"]), mr.position.y, mr.size.x + float(mover["travel"]) * 2.0, PLAT_H)
			if not _fits(mbox, mbox) and kind != "lift":
				ok = false
			if kind == "lift" and not _fits_lift(mbox):
				ok = false
		if not ok:
			continue
		# reachable from the row below?
		var tmp: Array = []
		for r: Rect2 in rects:
			tmp.append(_surface(r, solid))
		if not mover.is_empty():
			if bool(mover["vertical"]):
				tmp.append({"x0": mbox.position.x, "x1": mbox.end.x, "y": float(mover["hi"]), "by": float(mover["lo"]), "solid": false, "box": mbox})
			else:
				tmp.append(_surface(mbox, false))
		if not prev.is_empty():
			var linked := false
			for a3 in prev:
				for s in tmp:
					if reach(a3, s):
						linked = true
			if not linked:
				continue
		# take it
		for r: Rect2 in rects:
			if solid:
				solids.append(r)
			else:
				platforms.append(r)
		if not mover.is_empty():
			var spec := mover.duplicate()
			spec.erase("lo")
			spec.erase("hi")
			moving_specs.append(spec)
		surfs.append_array(tmp)
		new_s = tmp
		rows.append({"y": y, "kind": kind, "rects": rects if mover.is_empty() else [mbox], "solid": solid, "moving": not mover.is_empty()})
		if kind == "lift":
			# the landing at the top of the lift, on the far side from where it started
			var land := _row_landing(rng, y - STEP, mbox)
			if land.is_empty():
				_rollback([platforms.size(), solids.size(), moving_specs.size() - 1, rows.size() - 1, surfs.size() - tmp.size()])
				return []
			return land
		return new_s
	return cands


## Fits for a lift's travel box: nothing above, below or beside its whole ride (the platform it starts beside sits 60 px
## to the side, below the box).
func _fits_lift(box: Rect2) -> bool:
	if box.position.x < PL - 0.5 or box.end.x > PR + 0.5:
		return false
	for s in surfs:
		var e: Rect2 = s["box"]
		var ox := minf(box.end.x, e.end.x) - maxf(box.position.x, e.position.x)
		if ox > 4.0 and e.position.y > box.position.y - HEAD_ROOM and e.position.y < box.end.y + HEAD_ROOM:
			return false  # something in its shaft
		if ox > -40.0 and e.position.y > box.position.y - HEAD_ROOM and e.position.y < box.end.y + 4.0:
			return false  # something right beside its ride
	return true


## The platform at the top of a lift (row y), beside its travel box.
func _row_landing(rng: RandomNumberGenerator, y: float, lift_box: Rect2) -> Array:
	for k in 6:
		var w := rng.randf_range(300.0, 420.0)
		var right := lift_box.get_center().x < W * 0.5
		if k >= 3:
			right = not right
		var x0 := (lift_box.end.x + 50.0) if right else (lift_box.position.x - 50.0 - w)
		var r := Rect2(_fit_x(x0, w), y, w, PLAT_H)
		if r.position.x < lift_box.end.x + 20.0 and r.end.x > lift_box.position.x - 20.0:
			continue
		if not _fits(r, r):
			continue
		var s := _add_rect(r, false)
		rows.append({"y": y, "kind": "lift_top", "rects": [r], "solid": false, "moving": false})
		return [s]
	return []


## A battle floor at height `y`. Types: "semi" one wide one-way platform (come up through it anywhere), "block" a
## solid block with a pit on each side (come up through the pits), "split" two solid halves with a pit and a small
## island in the middle, "semiblock" a solid block in the middle with one-way platforms on both sides (no pits).
## Returns its surfaces.
func _floor(rng: RandomNumberGenerator, y: float, type: String, idx: int, n_fl: int, depth: int, t: String) -> Array:
	var xs: Array = [W * 0.5 - 150.0, W * 0.5, W * 0.5 + 150.0]
	var safe := Vector2(W * 0.5, y)
	var out: Array = []
	match type:
		"semi":
			out.append(_add_rect(Rect2(PL, y, PR - PL, PLAT_H), false))
		"block":
			out.append(_add_rect(Rect2(300.0, y, 900.0, FLOOR_T), true))
		"split":
			out.append(_add_rect(Rect2(PL, y, 600.0 - PL, FLOOR_T), true))
			out.append(_add_rect(Rect2(900.0, y, PR - 900.0, FLOOR_T), true))
			out.append(_add_rect(Rect2(680.0, y, 140.0, PLAT_H), false))
			xs = [480.0, W * 0.5, 1020.0]
			safe = Vector2(300.0, y)
		_:
			out.append(_add_rect(Rect2(450.0, y, 600.0, FLOOR_T), true))
			out.append(_add_rect(Rect2(PL, y, 450.0 - PL, PLAT_H), false))
			out.append(_add_rect(Rect2(1050.0, y, PR - 1050.0, PLAT_H), false))
	rows.append({"y": y, "kind": "floor_" + type, "rects": [], "solid": false, "moving": false})
	# things to throw enemies into: a bumper floating at juggle height, sometimes a spring on the floor
	if t != "boss":
		if rng.randf() < 0.6:
			hazards_spec.append({"kind": "bumper", "x": W * 0.5 + (-1.0 if rng.randf() < 0.5 else 1.0) * rng.randf_range(190.0, 330.0), "y": y})
		if rng.randf() < 0.5:
			hazards_spec.append({"kind": "spring", "x": clampf(safe.x + rng.randf_range(-200.0, 200.0), PL + 80.0, PR - 80.0), "y": y})
	# the enemies of this battle, in the order they drop in
	var queue: Array = []
	if t == "boss":
		queue = ["boss_street"]
	else:
		var total := mini(9, 4 + idx + depth / 2 + (1 if t == "elite" else 0))
		for i in total:
			if rng.randf() < 0.42:
				queue.append(_pick(rng, [["brute", 65], ["heavy", 20 + depth * 5]]))
			else:
				queue.append(_pick(rng, [["thug", 50], ["thrower", 25], ["biker", 25]]))
	# the higher up (and the deeper into the run), the faster the next one arrives
	var climb := float(idx) / float(maxi(n_fl - 1, 1))
	var interval := maxf(3.5, lerpf(9.0, 5.5, climb) - 0.25 * depth)
	encounters.append({"x": W * 0.5, "y": y, "type": type, "queue": queue, "start": 1 + (1 if rng.randf() < 0.5 else 0), "interval": interval,
		"cap": TRICKLE_CAP, "boss": t == "boss", "xs": xs, "safe": safe, "ceiling": true})
	return out


## True for rows a battle ceiling comes down on (nothing loose may stand there).
func _in_ceiling_band(y: float) -> bool:
	for e in encounters:
		var f: float = e["y"]
		if y <= f - CEIL_H + HEAD_ROOM + 20.0 and y >= f - CEIL_H - 300.0:
			return true
	return false


func _place_props(rng: RandomNumberGenerator, t: String) -> void:
	var spots: Array = []
	for rw in rows:
		if bool(rw["moving"]) or String(rw["kind"]) in ["edges", "under", "goal"] or _in_ceiling_band(float(rw["y"])):
			continue
		for r: Rect2 in (rw["rects"] as Array):
			if r.size.x >= 120.0:
				spots.append(r)
	var n_props: int = {"fight": 10, "elite": 12, "treasure": 24, "boss": 4}.get(t, 10)
	for i in n_props:
		var kind := _pick(rng, [["crate", 42], ["barrel", 25], ["vase", 17], ["explosive", 16]])
		if spots.is_empty() or rng.randf() < 0.15:
			props_spec.append([rng.randf_range(PL + 90.0, PR - 90.0), kind])
		else:
			var r2: Rect2 = spots[rng.randi() % spots.size()]
			props_spec.append([r2.position.x + rng.randf_range(40.0, maxf(41.0, r2.size.x - 40.0)), kind, r2.position.y])
	if rng.randf() < 0.7:
		hazards_spec.append({"kind": "spring", "x": rng.randf_range(PL + 220.0, PR - 220.0), "y": ground_y})


# ------------------------------------------------------------------ world

## The two side walls, from far above the top down into the street, with a doorway cut out for each gate.
func _build_walls() -> void:
	for p in _wall_pieces():
		_make_body(p, 1)
	for g in gates:
		g["body"] = _make_body(_gate_rect(g), 1)


## Rects of the side walls without the gate doorways.
func _wall_pieces() -> Array:
	var out: Array = []
	var y0 := top_y - 3000.0
	var y1 := ground_y + 400.0
	for side in [-1, 1]:
		var x := -WALL_T if side < 0 else PR
		var cuts: Array = gates.filter(func(g: Dictionary) -> bool: return int(g["side"]) == side)
		cuts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
		var cur := y0
		for g in cuts:
			out.append(Rect2(x, cur, WALL_T + WALL_IN, float(g["y"]) - GATE_H - cur))
			cur = float(g["y"])  # the wall below the doorway is its sill
		out.append(Rect2(x, cur, WALL_T + WALL_IN, y1 - cur))
	return out


func _gate_rect(g: Dictionary) -> Rect2:
	return Rect2(-WALL_T if int(g["side"]) < 0 else PR, float(g["y"]) - GATE_H, WALL_T + WALL_IN, GATE_H)


func _spawn_players() -> void:
	var n := 1 if RunState.solo else 2
	for i in n:
		var f := Fighter.new()
		f.player_index = i
		# the two start well apart, one on each side of the middle
		f.position = Vector2(W * 0.5 + (0.0 if n == 1 else (-260.0 if i == 0 else 260.0)), ground_y - 1)
		f.kill_y = ground_y + 700.0
		add_child(f)
		fighters.append(f)
		_stand.append(ground_y)


func _build_camera() -> void:
	cam = CameraRig.new()
	cam.tower = true
	cam.tower_zoom = 1280.0 / W
	cam.limit_left = -int(DoorRoom.ROOM_W)
	cam.limit_right = int(W + DoorRoom.ROOM_W)
	cam.limit_top = int(top_y - 200.0)
	cam.limit_bottom = int(ground_y + 130.0)
	for f in fighters:
		cam.targets.append(f)
	cam.focus = Vector2(W * 0.5, ground_y + STAND_UP - VIEW_H * 0.5)
	add_child(cam)
	cam.snap()
	var b: Backdrop = get_meta("backdrop")
	b.cam = cam


func _spawn_hazards() -> void:
	for hz in hazards_spec:
		var p := Vector2(clampf(float(hz["x"]), PL + 80.0, PR - 80.0), float(hz["y"]))
		match String(hz["kind"]):
			"bumper":
				var bp := Bumper.new()
				bp.position = p + Vector2(0, -110.0)
				add_child(bp)
			"spring":
				spawn_prop("spring", p + Vector2(0, -1.0))


## The nearest surface at or just below `from_y` at x (INF = nothing within a short drop: a pit). Without a height
## it is the street level, as in flat levels.
func ground_at(x: float, from_y := -INF) -> float:
	if from_y == -INF:
		return super.ground_at(x)
	var best := INF
	for r: Rect2 in _surf:
		if x < r.position.x or x > r.end.x:
			continue
		var t := r.position.y
		if t < from_y - 30.0 or t > from_y + 300.0 or t >= best:
			continue
		if _locked and t > _lock_floor + 4.0:
			continue  # below a locked battle floor there is only the fall
		best = t
	if not _locked and ground_y >= from_y - 30.0 and ground_y <= from_y + 300.0:
		best = minf(best, ground_y)
	return best


func is_safe_ground(p: Vector2) -> bool:
	if in_room:
		return false
	if _locked and p.y > _lock_floor + 4.0:
		return false
	for r: Rect2 in _surf:
		if absf(p.y - r.position.y) < 4.0:
			var m := minf(60.0, r.size.x * 0.25)
			if p.x >= r.position.x + m and p.x <= r.end.x - m:
				return true
	return not _locked and super.is_safe_ground(p)


## Every free end of a platform or block can be grabbed (only used while the ledge grab is switched on in TESTING).
func ledge_points() -> Array:
	if not _ledges.is_empty():
		return _ledges
	for r: Rect2 in _surf:
		for end in 2:
			var c := Vector2(r.position.x if end == 0 else r.end.x, r.position.y)
			if c.x < PL + 2.0 or c.x > PR - 2.0:
				continue  # against the wall
			var joined := false
			for o: Rect2 in _surf:
				if o != r and absf(o.position.y - c.y) < 2.0 and c.x >= o.position.x - 2.0 and c.x <= o.end.x + 2.0:
					joined = true  # the floor simply goes on in another piece
			if not joined:
				_ledges.append({"p": c, "dir": 1 if end == 0 else -1})
	return _ledges


func _enemy_kill_y() -> float:
	if _locked:
		return _kill
	if in_room and not _gate.is_empty():
		return float(_gate["y"]) + 700.0
	return ground_y + 800.0


## Enemies must not step down through a battle floor: below it is only the fall.
func allow_drop(p: Vector2) -> bool:
	return not (_locked and p.y >= _lock_floor - 20.0)


func on_ring_out(e: Node2D) -> void:
	if not _locked:
		return
	Coop.callout("RING OUT!", Color(2.2, 1.7, 0.4))
	Sfx.play("boom", 1.3)
	Juice.shake(0.35)
	Fx.ring(self, Vector2(e.global_position.x, _lock_floor + FLOOR_PAD - 30.0), Color(2.2, 1.7, 0.4), 120.0, 0.35)


func _on_summon(by: Actor, count: int) -> void:
	for i in count:
		var x := clampf(by.global_position.x + (-1.0 if i % 2 == 0 else 1.0) * (150.0 + 60.0 * i), Coop.bounds.position.x + 40.0, Coop.bounds.end.x - 40.0)
		var e := spawn_enemy("thug", Vector2(x, by.global_position.y - 1.0))
		e.velocity.y = -400.0
		Fx.ring(self, Vector2(x, by.global_position.y - 20.0), Color(2.2, 0.5, 0.4), 80.0, 0.3)


# ------------------------------------------------------------------ battles

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _cleared:
		return
	_steer_camera()
	if in_room:
		_room_tick()


func _run_encounters(delta: float) -> void:
	if _locked:
		if trickle_tick(delta):
			_unlock()
		return
	_pull_up_stragglers()
	_check_gates()
	if in_room:
		return
	if _enc_idx < encounters.size():
		var enc: Dictionary = encounters[_enc_idx]
		var f_y: float = enc["y"]
		for f in fighters:
			if f.is_alive() and f.is_on_floor() and f.global_position.y <= f_y + 4.0 and f.global_position.y > f_y - CEIL_H:
				_lock(enc)
				return
	elif goal.size.x > 0.0:
		for f in fighters:
			if f.is_alive() and f.is_on_floor() and absf(f.global_position.y - goal.position.y) < 6.0 \
					and f.global_position.x >= goal.position.x and f.global_position.x <= goal.end.x:
				_complete()
				return


func _lock(enc: Dictionary) -> void:
	_locked = true
	_lock_floor = float(enc["y"])
	_kill = _lock_floor + FLOOR_PAD + 30.0  # above the row under the floor: a pit is a fall, not a ledge to land on
	_boss_fight = bool(enc["boss"])
	var safe: Vector2 = (enc["safe"] as Vector2) + Vector2(0, -1)
	var i := 0
	for f in fighters:
		f.kill_y = _kill
		f.spawn_point = safe
		if f.global_position.y > _lock_floor + 40.0:
			# still on the way up: the screen has closed below, so join the partner on the floor
			f.global_position = safe + Vector2(-50.0 + 100.0 * i, 0)
			f.velocity = Vector2.ZERO
			f.invuln = maxf(f.invuln, 1.0)
		if f.last_safe == Vector2.ZERO or f.last_safe.y > _lock_floor + 4.0:
			f.last_safe = safe
		i += 1
	_ceiling = ArenaCeiling.new()
	_ceiling.setup(PL, PR, _lock_floor - CEIL_H, theme["neon_plat"])
	add_child(_ceiling)
	_ceiling.appear()
	hud.set_go(false)
	hud.banner("BOSS!" if _boss_fight else "FIGHT!", Color(2.2, 0.5, 0.4) if _boss_fight else Color(2.0, 1.6, 0.5))
	Sfx.play("boom", 1.2)
	Juice.shake(0.3)
	# the first enemies drop in a moment later: time to take up positions on both sides
	trickle_begin(enc["queue"], int(enc["start"]), float(enc["interval"]), int(enc["cap"]), enc["xs"], _lock_floor, 1.1)


func _unlock() -> void:
	_locked = false
	_kill = INF
	for f in fighters:
		f.kill_y = ground_y + 700.0
	if _ceiling != null and is_instance_valid(_ceiling):
		_ceiling.leave()
	_ceiling = null
	for g in gates:
		if int(g["floor"]) == _enc_idx and not bool(g["used"]):
			_open_gate(g)
	_enc_idx += 1
	Sfx.play("pickup", 1.2)
	if _boss_fight:
		_complete()
	else:
		hud.set_go(true)


func is_final_kill() -> bool:
	if alive_enemies() != 0 or _trickle.is_empty():
		return false
	return (_trickle["queue"] as Array).is_empty() and (_locked or in_room)


## Starts dripping enemies in: `start_n` at once after `first_delay`, then one every `interval` seconds (at once when
## nobody is left), never more than `cap` alive. `xs` are the places they drop in above the floor at `floor_y`.
func trickle_begin(queue: Array, start_n: int, interval: float, cap: int, xs: Array, floor_y: float, first_delay := 0.0) -> void:
	_trickle = {"queue": queue.duplicate(), "burst": maxi(1, start_n), "t": first_delay, "interval": interval, "cap": cap,
		"xs": xs, "y": floor_y, "next_x": float(xs[xs.size() / 2]), "total": queue.size()}


## One physics step of the drip. Returns true once every enemy has dropped in and is defeated.
func trickle_tick(delta: float) -> bool:
	if _trickle.is_empty():
		return true
	var q: Array = _trickle["queue"]
	var alive := alive_enemies()
	if q.is_empty():
		if alive == 0:
			_trickle = {}
			return true
		return false
	var t: float = float(_trickle["t"]) - delta
	var burst: int = _trickle["burst"]
	if alive == 0 and burst == 0:
		t = minf(t, 0.7)  # the screen is empty: the next one comes right away
	if t <= 0.0 and alive < int(_trickle["cap"]):
		var xs: Array = _trickle["xs"]
		var n := mini(maxi(1, burst), q.size())
		for i in n:
			var x: float = float(_trickle["next_x"])
			if n > 1:
				x = float(xs[(i * maxi(1, xs.size() - 1)) % xs.size()])  # a group spreads over the drop points
			_drop_enemy(String(q.pop_front()), x + randf_range(-30.0, 30.0), float(_trickle["y"]))
		_trickle["burst"] = 0
		_trickle["next_x"] = float(xs[randi() % xs.size()])
		t = float(_trickle["interval"])
	_trickle["t"] = t
	return false


func _drop_enemy(kind: String, x: float, floor_y: float) -> void:
	var pos := Vector2(x, floor_y - (300.0 if kind.begins_with("boss") else 430.0))
	var e := spawn_enemy(kind, pos)
	e.velocity = Vector2.ZERO
	e.invuln = 0.7
	Fx.ring(self, pos + Vector2(0, -40.0), Color(2.2, 0.5, 0.4), 70.0, 0.3)
	Sfx.play("ui", 0.8)


# ------------------------------------------------------------------ camera and co-op climbing

func _steer_camera() -> void:
	var lead := INF
	for i in fighters.size():
		var f := fighters[i]
		var y := f.global_position.y
		if f.is_on_floor() or f.state == "ledge":
			_stand[i] = y
		else:
			_stand[i] = clampf(_stand[i], y - 40.0, y + 300.0)  # a long fall or a high fling drags the camera along
		if f.is_alive():
			lead = minf(lead, _stand[i])
	if lead == INF:
		lead = _stand[0]
	var c := Vector2(W * 0.5, lead + STAND_UP - VIEW_H * 0.5)
	if in_room and _room != null:
		c = Vector2(_room.x0 + DoorRoom.ROOM_W * 0.5, _room.gy() + FLOOR_PAD - VIEW_H * 0.5)
	elif _locked:
		c.y = _lock_floor + FLOOR_PAD - VIEW_H * 0.5
	cam.focus = c


## Between battles the camera follows whoever is highest. A partner who drops out of the bottom of the screen is
## brought up beside the leader, without damage.
func _pull_up_stragglers() -> void:
	if fighters.size() < 2:
		return
	var leader: Fighter = null
	for f in fighters:
		if f.is_alive() and f.state != "downed" and (leader == null or f.global_position.y < leader.global_position.y):
			leader = f
	if leader == null:
		return
	var bottom := cam.focus.y + VIEW_H * 0.5  # (the steered centre: the drawn one lags a frame behind at the start)
	for f in fighters:
		if f == leader or f.global_position.y - 100.0 < bottom + 60.0:
			continue
		var to := leader.global_position + Vector2(-float(leader.facing) * 50.0, -30.0)
		if leader.last_safe != Vector2.ZERO and absf(leader.last_safe.y - leader.global_position.y) < 320.0:
			to = leader.last_safe + Vector2(-float(leader.facing) * 50.0, -2.0)
		to.x = clampf(to.x, PL + 40.0, PR - 40.0)
		if f.is_alive() and f.state != "downed":
			f.respawn()
		f.global_position = to
		f.velocity = Vector2.ZERO
		Fx.ring(self, to + Vector2(0, -50.0), UiKit.player_color(f.player_index), 70.0, 0.3)


# ------------------------------------------------------------------ side gates and rooms

func _open_gate(g: Dictionary) -> void:
	if g["body"] != null and is_instance_valid(g["body"]):
		(g["body"] as Node).queue_free()
	g["body"] = null
	g["open"] = true


func _close_gate(g: Dictionary) -> void:
	g["open"] = false
	if g["body"] == null:
		g["body"] = _make_body(_gate_rect(g), 1)


## How far a point is through the wall on the gate's side (positive = outside the tower).
func _past(g: Dictionary, p: Vector2) -> float:
	return p.x - W if int(g["side"]) > 0 else -p.x


func _check_gates() -> void:
	if in_room:
		return
	for g in gates:
		if not bool(g["open"]) or bool(g["used"]):
			continue
		for f in fighters:
			if f.is_alive() and _past(g, f.global_position) > 30.0 and absf(f.global_position.y - float(g["y"])) < GATE_H + 20.0:
				_enter_side(g)
				return


func _enter_side(g: Dictionary) -> void:
	in_room = true
	_gate = g
	var side := int(g["side"])
	var room := SideRoom.new().setup_side(self, String(g["kind"]), side, float(g["y"]))
	room.pick_move = bool(g["pick"])
	_room = room
	var edge := W if side > 0 else 0.0
	var i := 0
	for f in fighters:
		f.global_position = Vector2(edge + side * (150.0 + 70.0 * i), float(g["y"]) - 1.0)
		f.velocity = Vector2.ZERO
		f.last_safe = f.global_position
		i += 1
	if room.kind == "challenge":
		_close_gate(g)  # no way out until it is cleared
	Coop.bounds = Rect2(room.x0, top_y - 3000.0, DoorRoom.ROOM_W, ground_y - top_y + 6000.0)
	hud.set_go(false)
	room.enter()


func _room_tick() -> void:
	if _room == null or _gate.is_empty():
		return
	if _room.kind == "challenge" and not _room.cleared:
		return
	if _gate["body"] != null:
		_open_gate(_gate)  # cleared: the way back is open
		_gate["open"] = false
	for f in fighters:
		if f.is_alive() and _past(_gate, f.global_position) < -30.0:
			_leave_side()
			return


func _leave_side() -> void:
	var g := _gate
	var side := int(g["side"])
	var edge := PR if side > 0 else PL
	in_room = false
	g["used"] = true
	var i := 0
	for f in fighters:
		if _past(g, f.global_position) > -80.0:
			f.global_position = Vector2(edge - side * (90.0 + 70.0 * i), float(g["y"]) - 1.0)
			f.velocity = Vector2.ZERO
		f.last_safe = Vector2(edge - side * 200.0, float(g["y"]) - 1.0)
		i += 1
	_close_gate(g)
	if _room != null:
		_room.leave()
		_room = null
	_gate = {}
	_trickle = {}
	Coop.bounds = _tower_bounds()
	hud.set_go(true)


# ------------------------------------------------------------------ drawing

func _process(_delta: float) -> void:
	if _overlay != null:
		_overlay.queue_redraw()
	if _walls_node != null:
		_walls_node.queue_redraw()
		_walls_back.queue_redraw()


func _paint_sky(c: CanvasItem) -> void:
	super._paint_sky(c)
	var top: Color = theme["sky_top"]
	if Backdrop.variant == 5:
		top = Pal.SYNTH_SKY[0]
	elif Backdrop.variant == 4:
		top = Pal.BG_SKY[0]
	var y0 := top_y - 3000.0
	c.draw_rect(Rect2(-2500.0, y0, W + 5000.0, -1790.0 - y0), top)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 220:
		var p := Vector2(rng.randf_range(0.0, W), rng.randf_range(top_y - 800.0, -200.0))
		var s := rng.randf_range(1.5, 3.0)
		c.draw_rect(Rect2(p, Vector2(s, s)), Color(0.85, 0.85, 1.0, rng.randf_range(0.15, 0.6)))
	# outside the tower
	c.draw_rect(Rect2(-6000.0, y0, 6000.0, ground_y + 1400.0 - y0), Color(0.01, 0.0, 0.03))
	c.draw_rect(Rect2(W, y0, 6000.0, ground_y + 1400.0 - y0), Color(0.01, 0.0, 0.03))


## The tower's own facade behind the playfield: a dark wall with floor lines and a few lit windows.
func _paint_facade(c: CanvasItem) -> void:
	var y0 := top_y - 3000.0
	c.draw_rect(Rect2(PL, y0, PR - PL, ground_y - y0), Color(0.035, 0.02, 0.08, 0.62))
	var ng: Color = theme["neon_ground"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var y := ground_y - 250.0
	while y > top_y - 900.0:
		c.draw_line(Vector2(PL, y), Vector2(PR, y), Color(ng.r, ng.g, ng.b, 0.05), 2.0)
		for col in 9:
			var roll := rng.randf()
			var r := Rect2(PL + 60.0 + col * 155.0, y + 60.0, 46.0, 110.0)
			if roll < 0.16:
				c.draw_rect(r, Color(Pal.BG_WINDOW.r, Pal.BG_WINDOW.g, Pal.BG_WINDOW.b, 0.10 + roll))
			else:
				c.draw_rect(r, Color(0.0, 0.0, 0.02, 0.22))
		y -= 250.0


func _paint_ground(c: CanvasItem) -> void:
	super._paint_ground(c)


## How far the walls' inner faces run back into the depth (the same as the ground's surface).
const WALL_DEPTH := DepthLayer.FLOOR_BACK


## The back part of the walls, drawn like the ground's surface: from the inner edge of each wall a face runs back toward
## the vanishing point, behind the platforms and the fighters. At a doorway the sill and the lintel run back the same
## way (a passage through the wall). The gate signs hang here too.
func _paint_walls_back() -> void:
	var c := _walls_back
	var cam2 := get_viewport().get_camera_2d()
	var ctr := cam2.get_screen_center_position() if cam2 != null else Vector2(W * 0.5, ground_y)
	var vp := Vector2(ctr.x, ctr.y - DepthLayer.RISE)
	var vy0 := ctr.y - VIEW_H
	var vy1 := ctr.y + VIEW_H
	var ng: Color = theme["neon_ground"]
	var tint := Color(minf(ng.r, 1.0), minf(ng.g, 1.0), minf(ng.b, 1.0))
	var base: Color = Pal.BG_GROUND
	var near := base.lerp(tint, 0.20)
	var far := base.lerp(tint, 0.07)
	for p: Rect2 in _wall_pieces():
		var y0 := maxf(p.position.y, vy0)
		var y1 := minf(p.end.y, vy1)
		if y1 <= y0:
			continue
		var ix := p.end.x if p.position.x < 0.0 else p.position.x  # the inner edge
		var a := Vector2(ix, y0)
		var d := Vector2(ix, y1)
		var b := DepthLayer.P(a, WALL_DEPTH, vp)
		var e := DepthLayer.P(d, WALL_DEPTH, vp)
		c.draw_polygon(PackedVector2Array([a, b, e, d]), PackedColorArray([near, far, far, near]))
		# lines running into the distance (one per lamp) and two along it, like the ground's grid
		var ly := y0 - fmod(y0, 140.0) + 70.0
		while ly < y1:
			c.draw_line(Vector2(ix, ly), DepthLayer.P(Vector2(ix, ly), WALL_DEPTH, vp), Color(ng.r, ng.g, ng.b, 0.13), 1.5)
			ly += 140.0
		for dd: float in [WALL_DEPTH * 0.33, WALL_DEPTH * 0.66]:
			c.draw_line(DepthLayer.P(a, dd, vp), DepthLayer.P(d, dd, vp), Color(ng.r, ng.g, ng.b, 0.09), 1.5)
		c.draw_line(b, e, Color(ng.r, ng.g, ng.b, 0.30), 2.0, true)
	# doorways: the sill (a strip of floor) and the lintel's underside run back through the wall
	for g in gates:
		var dr := _gate_rect(g)
		if dr.end.y < vy0 or dr.position.y > vy1:
			continue
		for yy: float in [dr.end.y, dr.position.y]:
			var l := Vector2(dr.position.x, yy)
			var r := Vector2(dr.end.x, yy)
			var col_n := near if yy == dr.end.y else near.darkened(0.4)
			var col_f := far if yy == dr.end.y else far.darkened(0.4)
			c.draw_polygon(PackedVector2Array([l, r, DepthLayer.P(r, WALL_DEPTH, vp), DepthLayer.P(l, WALL_DEPTH, vp)]), PackedColorArray([col_n, col_n, col_f, col_f]))
		# the passage's far wall is open: the room beyond shows through; a soft glow while the gate is open
		if bool(g["open"]):
			var gc := Color(1.0, 0.2, 0.25) if String(g["kind"]) == "challenge" else Pal.interact()
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
			c.draw_rect(dr, Color(gc.r, gc.g, gc.b, 0.08 + 0.06 * pulse))
	_paint_gate_signs(c, vy0, vy1)


## The side walls' front faces, in the look of a battle ceiling's front: a flat dark body that cuts the screen edge
## cleanly, with a lit inner edge and lamp strips, drawn in front of everything. Each gate is a lit doorway cut into
## the wall: a door panel while shut, a bright frame and arrows once open.
func _paint_walls() -> void:
	var c := _walls_node
	var cam2 := get_viewport().get_camera_2d()
	var ctr := cam2.get_screen_center_position() if cam2 != null else Vector2(W * 0.5, ground_y)
	var vy0 := ctr.y - VIEW_H
	var vy1 := ctr.y + VIEW_H
	var neon: Color = theme["neon_plat"]
	var body := Color(0.035, 0.02, 0.07)
	for p: Rect2 in _wall_pieces():
		var r := Rect2(p.position.x, maxf(p.position.y, vy0), p.size.x, minf(p.end.y, vy1) - maxf(p.position.y, vy0))
		if r.size.y <= 0.0:
			continue
		c.draw_rect(r, body)
		# a slightly lighter band along the inside, like the ceiling's front face
		var band := Rect2(r.end.x - 22.0, r.position.y, 22.0, r.size.y) if r.position.x < 0.0 else Rect2(r.position.x, r.position.y, 22.0, r.size.y)
		c.draw_rect(band, Color(neon.r * 0.16, neon.g * 0.16, neon.b * 0.16))
		# the ends of a piece at a doorway: lit lintel and sill edges
		for ey in [p.position.y, p.end.y]:
			if ey > vy0 and ey < vy1 and ey > top_y - 2900.0 and ey < ground_y + 300.0:
				c.draw_line(Vector2(r.position.x, ey), Vector2(r.end.x, ey), neon, 3.0, true)
		# the lit inner edge and lamp strips running up the inner face
		var ix := r.end.x if r.position.x < 0.0 else r.position.x
		c.draw_line(Vector2(ix, r.position.y), Vector2(ix, r.end.y), neon, 3.0, true)
		var ly := r.position.y - fmod(r.position.y, 140.0) + 70.0
		var lx := ix - 16.0 if r.position.x < 0.0 else ix + 16.0
		while ly < r.end.y - 20.0:
			c.draw_line(Vector2(lx, ly), Vector2(lx, ly + 36.0), Color(1.6, 1.5, 1.2, 0.75), 4.0, true)
			c.draw_line(Vector2(lx, ly), Vector2(lx, ly + 36.0), Color(1.6, 1.5, 1.2, 0.15), 12.0, true)
			ly += 140.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	for g in gates:
		var gy0 := float(g["y"])
		if gy0 < vy0 - 300.0 or gy0 > vy1 + 300.0:
			continue
		var dc := _gate_color(g, pulse)
		var dr := _gate_rect(g)
		if not bool(g["open"]):
			# a shut door panel with bars, flush with the front face
			c.draw_rect(dr, Color(0.01, 0.0, 0.02))
			c.draw_rect(dr.grow(-6.0), Color(dc.r * 0.18, dc.g * 0.18, dc.b * 0.18))
			var by := dr.position.y + 26.0
			while by < dr.end.y - 10.0:
				c.draw_line(Vector2(dr.position.x + 8.0, by), Vector2(dr.end.x - 8.0, by), Color(dc.r, dc.g, dc.b, 0.55), 3.0)
				by += 30.0
		# the lit frame: lintel bar and the inner jamb
		c.draw_rect(Rect2(dr.position.x, dr.position.y - 10.0, dr.size.x, 10.0), dc)
		var inner := dr.end.x if int(g["side"]) < 0 else dr.position.x
		c.draw_line(Vector2(inner, dr.position.y - 10.0), Vector2(inner, dr.end.y), dc, 6.0, true)
		c.draw_line(Vector2(inner, dr.position.y - 10.0), Vector2(inner, dr.end.y), Color(dc.r, dc.g, dc.b, 0.25), 18.0, true)


func _gate_color(g: Dictionary, pulse: float) -> Color:
	var col := Color(1.0, 0.2, 0.25) if String(g["kind"]) == "challenge" else Pal.interact()
	var k := (0.8 + 0.2 * pulse) if bool(g["open"]) else (0.25 if bool(g["used"]) else 0.6)
	return Color(col.r * k, col.g * k, col.b * k)


## The arrows in an open doorway and the sign above every gate (behind the fighters, who walk through).
func _paint_gate_signs(c: CanvasItem, vy0: float, vy1: float) -> void:
	var f := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	for g in gates:
		var side := int(g["side"])
		var gy0 := float(g["y"])
		if gy0 < vy0 - 300.0 or gy0 > vy1 + 300.0:
			continue
		var col := Color(1.0, 0.2, 0.25) if String(g["kind"]) == "challenge" else Pal.interact()
		var open := bool(g["open"])
		var used := bool(g["used"])
		var dr := _gate_rect(g)
		var dc := _gate_color(g, pulse)
		if open:
			# chevrons pointing out of the tower
			for j in 3:
				var cx := dr.get_center().x + side * (float(j) - 1.0) * 34.0
				var cy := gy0 - GATE_H * 0.5
				var a := 0.35 + 0.65 * clampf(sin(Time.get_ticks_msec() / 1000.0 * 6.0 - j * 0.9), 0.0, 1.0)
				c.draw_polyline(PackedVector2Array([Vector2(cx - side * 12.0, cy - 22.0), Vector2(cx + side * 12.0, cy), Vector2(cx - side * 12.0, cy + 22.0)]),
					Color(col.r, col.g, col.b, a), 5.0, true)
		# the sign above it, inside the tower
		var label := "CHALLENGE" if String(g["kind"]) == "challenge" else "MOVE SHOP"
		var sub := "CLOSED" if used else ("WALK IN" if open else "OPENS AFTER THE FIGHT")
		if open:
			sub = ("+%d COINS%s" % [DoorRoom.challenge_coins(), "  +  MOVE" if bool(g["pick"]) else ""]) if String(g["kind"]) == "challenge" else "MOVES  +  HEAL"
			label = (label + "  >>") if side > 0 else ("<<  " + label)
		var tx := PR - 330.0 if side > 0 else PL + 30.0
		var al := HORIZONTAL_ALIGNMENT_RIGHT if side > 0 else HORIZONTAL_ALIGNMENT_LEFT
		c.draw_string_outline(f, Vector2(tx, gy0 - GATE_H - 40.0), label, al, 300.0, 28, 6, Color(0, 0, 0, 0.85))
		c.draw_string(f, Vector2(tx, gy0 - GATE_H - 40.0), label, al, 300.0, 28, dc)
		c.draw_string_outline(f, Vector2(tx, gy0 - GATE_H - 16.0), sub, al, 300.0, 16, 4, Color(0, 0, 0, 0.85))
		c.draw_string(f, Vector2(tx, gy0 - GATE_H - 16.0), sub, al, 300.0, 16, Color(1, 1, 1, 0.8 if open else 0.5))


## The goal and the "next enemy" timer.
func _paint_overlay() -> void:
	var c := _overlay
	var f := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	if goal.size.x > 0.0:
		var done := _enc_idx >= encounters.size()
		var gc := Color(1.3, 1.8, 2.2) if done else Color(0.5, 0.6, 0.75)
		var n := 13
		var cw := goal.size.x / float(n)
		for i in n:
			var cc := Color(1.7, 1.7, 2.0) if i % 2 == 0 else Color(0.03, 0.02, 0.06)
			if not done:
				cc = cc.darkened(0.55)
			c.draw_rect(Rect2(goal.position.x + cw * i, goal.position.y + 3.0, cw, 12.0), cc)
		c.draw_string_outline(f, Vector2(goal.position.x, goal.position.y - 150.0 - 6.0 * pulse), "GOAL", HORIZONTAL_ALIGNMENT_CENTER, goal.size.x, 46, 6, Color(0, 0, 0, 0.8))
		c.draw_string(f, Vector2(goal.position.x, goal.position.y - 150.0 - 6.0 * pulse), "GOAL", HORIZONTAL_ALIGNMENT_CENTER, goal.size.x, 46, gc)
		if done:
			var gx := goal.get_center().x
			c.draw_rect(Rect2(gx - 150.0, goal.position.y - 900.0, 300.0, 900.0), Color(gc.r, gc.g, gc.b, 0.04 + 0.03 * pulse))
	if _locked and not _trickle.is_empty():
		# how many are still to come, and when the next one drops (and where)
		var q: Array = _trickle["queue"]
		var y := _lock_floor - CEIL_H + 44.0
		var left := q.size()
		for i in left:
			c.draw_circle(Vector2(W * 0.5 + (float(i) - float(left - 1) * 0.5) * 22.0, y), 6.0, Color(2.2, 0.5, 0.4, 0.9))
		if left > 0:
			var frac := clampf(float(_trickle["t"]) / maxf(float(_trickle["interval"]), 0.01), 0.0, 1.0)
			c.draw_rect(Rect2(W * 0.5 - 120.0, y + 16.0, 240.0, 6.0), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(W * 0.5 - 120.0, y + 16.0, 240.0 * (1.0 - frac), 6.0), Color(2.2, 0.5, 0.4, 0.9))
			if float(_trickle["t"]) < 1.3 and int(_trickle["burst"]) == 0:
				var nx: float = _trickle["next_x"]
				var a := 0.4 + 0.6 * pulse
				c.draw_colored_polygon(PackedVector2Array([Vector2(nx - 16.0, y + 40.0), Vector2(nx + 16.0, y + 40.0), Vector2(nx, y + 66.0)]), Color(2.2, 0.5, 0.4, a))
