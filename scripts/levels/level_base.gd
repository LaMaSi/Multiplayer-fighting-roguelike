class_name LevelBase
extends Node2D
## Builds a side-scrolling level in code: ground, one-way platforms, props, two players,
## shared camera, HUD, pause menu, and runs arena-lock encounters.
## Subclasses override _setup() to fill in the data.

const PLAT_H := 16.0
const SPRING_REACH := 250.0  ## a spring flings you about 263 px up: the highest platforms sit this far above the ground
const ARENA_CEILING := 470.0  ## height of a battle screen's ceiling above the level's base ground
const ARENA_CEILING_BOSS := 560.0

var level_w := 3200.0
var ground_y := 600.0
var platforms: Array = []  ## Rect2 (top-left, size)
var tunnel_roofs: Array = []  ## the Rect2s in `platforms` that are tunnel roofs: drawn thick with a dark interior; walk through under them or jump over
var ground_segs: Array = []  ## Rect2 (x, top_y, width, depth) pieces of ground; empty = one flat ground. Gaps between pieces are pits.
var moving_specs: Array = []  ## {rect: Rect2, vertical: bool, travel: float (half), period: float, phase: float}
var doors_spec: Array = []  ## {x, kind: "challenge" | "shop"}
var hazards_spec: Array = []  ## {kind: "spikes" | "bumper" | "spring", x}  or  {kind: "ceiling_spikes", x, y (the underside of what they hang from), w}; ceiling spikes must have their tips at least SpikeTrap.AIR_MIN_H above the ground
var in_room := false  ## the players are inside a door room (the level itself is paused in place)
var _room: DoorRoom = null
var _room_door: Door = null
var props_spec: Array = []  ## [x, kind, (y)]
var encounters: Array = []  ## {x, waves: [[["thug", 2], ...], ...], boss: bool}
var enemy_hp_mult := 1.0
var enemy_dmg_mult := 1.0
var exit_x := -1.0  ## reaching this x (after all encounters) completes the level; -1 = none
var level_name := "Level"
var theme := {
	"sky_top": Color(0.10, 0.05, 0.28), "sky_bottom": Color(0.85, 0.28, 0.62),
	"ground": Color(0.05, 0.03, 0.10), "neon_ground": Color(1.5, 0.6, 2.2), "neon_plat": Color(2.0, 0.6, 1.3),
	"bld_far": Color(0.34, 0.14, 0.50), "edge_far": Color(0.9, 0.35, 1.2),
	"bld_mid": Color(0.17, 0.07, 0.30), "edge_mid": Color(1.4, 0.5, 1.5),
	"bld_near": Color(0.08, 0.03, 0.16), "edge_near": Color(1.6, 0.5, 1.4), "window": Color(1.8, 1.3, 0.5), "seed": 3,
}

var par_time := 120.0  ## seconds for an S on the time stat
var result_stats: Dictionary = {}
var fighters: Array[Fighter] = []
var cam: CameraRig
var hud: Hud
var objective := ""  ## one-line goal for the HUD (set by the level before _ready finishes)
var menu: PauseMenu

var _enc_idx := 0
var _locked := false
var _wave_idx := 0
var _lock_walls: Array[Node] = []
var _ceiling: ArenaCeiling = null
var _enemies: Array[Enemy] = []
var _boss_fight := false
var _cleared := false
var _arena := Vector2.ZERO


func _setup() -> void:
	pass


func _ready() -> void:
	Coop.reset_run()
	_setup()
	par_time = 45.0 + level_w / 70.0
	Coop.enemy_hp_mult = enemy_hp_mult
	Coop.enemy_dmg_mult = enemy_dmg_mult
	Coop.bounds = Rect2(0, -1200, level_w, 2400)
	_build_environment()
	_make_scenery()
	_add_backdrop()
	_build_world()
	_spawn_players()
	_build_camera()
	_spawn_props()
	_spawn_doors()
	_spawn_hazards()
	_spawn_bonus_pole()
	hud = Hud.new()
	hud.level = self
	hud.objective = objective
	add_child(hud)
	menu = PauseMenu.new()
	menu.level = self
	add_child(menu)
	if exit_x > 0.0:
		hud.set_go(true)
	Coop.summon_requested.connect(_on_summon)
	Coop.game_over.connect(_on_game_over)
	queue_redraw()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_strength = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.7
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _add_backdrop() -> void:
	var b := Backdrop.new()
	b.setup(theme, level_w, ground_y)
	add_child(b)
	set_meta("backdrop", b)


func _make_body(rect: Rect2, layer: int, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(layer, true)
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.one_way_collision = one_way
	if one_way:
		cs.one_way_collision_margin = 6.0
	body.add_child(cs)
	add_child(body)
	return body


func _build_world() -> void:
	for g: Rect2 in _ground_rects():
		_make_body(Rect2(g.position.x, g.position.y, g.size.x, 400.0), 1)
	_make_body(Rect2(-100, -1500, 100, 3000), 1)
	_make_body(Rect2(level_w, -1500, 100, 3000), 1)
	for r: Rect2 in platforms:
		var b := _make_body(r, 2, true)
		b.set_meta("bottom_y", r.end.y)
	for m: Dictionary in moving_specs:
		var mp := MovingPlatform.new()
		add_child(mp)
		mp.setup(m["rect"], bool(m["vertical"]), float(m["travel"]), float(m["period"]), float(m["phase"]), Pal.terrain())


## The ground pieces, with the first and last stretched past the level edges. Legacy levels: one flat slab.
func _ground_rects() -> Array:
	if ground_segs.is_empty():
		return [Rect2(-2500, ground_y, level_w + 5000, 700)]
	var out: Array = []
	for i in ground_segs.size():
		var g: Rect2 = ground_segs[i]
		var x0 := g.position.x - (2500.0 if i == 0 else 0.0)
		var x1 := g.end.x + (2500.0 if i == ground_segs.size() - 1 else 0.0)
		out.append(Rect2(x0, g.position.y, x1 - x0, 700.0))
	return out


## Top of the ground at x, or INF over a pit.
func ground_at(x: float) -> float:
	for g: Rect2 in _ground_rects():
		if x >= g.position.x and x <= g.end.x:
			return g.position.y
	return INF


## Ground top for placing things: over a pit falls back to the base ground line.
func ground_top(x: float) -> float:
	var y := ground_at(x)
	return ground_y if y == INF else y


## True on solid ground at least 60 px in from a pit edge: where a fallen player respawns.
func is_safe_ground(p: Vector2) -> bool:
	for g: Rect2 in _ground_rects():
		if p.x >= g.position.x + 60.0 and p.x <= g.end.x - 60.0 and absf(p.y - g.position.y) < 4.0:
			return true
	return false


func _spawn_players() -> void:
	for i in (1 if RunState.solo else 2):
		var f := Fighter.new()
		f.player_index = i
		f.position = Vector2(260 + i * 90, ground_y - 1)
		f.kill_y = ground_y + 700.0
		add_child(f)
		fighters.append(f)


func _build_camera() -> void:
	cam = CameraRig.new()
	cam.limit_top = -500
	cam.limit_bottom = int(ground_y + (300.0 if not ground_segs.is_empty() else 130.0))  # pits and sunken ground need room below
	cam.set_bounds(0.0, level_w)
	cam.min_zoom = 0.45
	for f in fighters:
		cam.targets.append(f)
	add_child(cam)
	cam.snap()
	var b: Backdrop = get_meta("backdrop")
	b.cam = cam


## Nothing is placed on the ground within this distance of a door (props, spikes, springs, bumpers): the doorway stays clear.
const DOOR_CLEAR := 190.0


func near_door(x: float) -> bool:
	for d in doors_spec:
		if absf(x - float(d["x"])) < DOOR_CLEAR:
			return true
	return false


## Nothing at all is placed within half a screen of the finish line.
const FINISH_CLEAR := 1280.0 / CameraRig.MAX_ZOOM * 0.5  ## about 753 px


func near_finish(x: float) -> bool:
	return exit_x > 0.0 and absf(x - exit_x) < FINISH_CLEAR


## Half-widths of the things that are placed on a surface, to keep them from overlapping each other.
const OBJECT_R := {"crate": 23.0, "explosive": 23.0, "barrel": 20.0, "vase": 17.0, "spring": 24.0, "spikes": 52.0, "bumper": 38.0}
const PLACE_GAP := 28.0  ## free space kept between two placed objects
var _placed: Array = []  ## {x, y, r}: what already stands on each surface


func _spot_free(x: float, y: float, r: float) -> bool:
	for pl in _placed:
		if absf(float(pl["y"]) - y) < 70.0 and absf(float(pl["x"]) - x) < r + float(pl["r"]) + PLACE_GAP:
			return false
	return true


## A free place for an object of half-width `r` standing on the surface at height `y`, as close to `x` as possible
## (nudged in steps, up to about 300 px). INF when there is none. A platform keeps the object within its edges; on the
## ground it must be on solid ground away from the edges.
func _free_x(x: float, y: float, r: float, plat: Rect2) -> float:
	for k in 9:
		for sgn in ([1.0] if k == 0 else [1.0, -1.0]):
			var cx: float = x + sgn * float(k) * 36.0
			if plat.size.x > 0.0:
				if cx - r < plat.position.x + 6.0 or cx + r > plat.end.x - 6.0:
					continue
			elif not is_safe_ground(Vector2(cx, y)):
				continue
			if near_finish(cx):
				continue
			if plat.size.x <= 0.0 and near_door(cx):
				continue
			if _spot_free(cx, y, r):
				return cx
	return INF


func _platform_at(x: float, y: float) -> Rect2:
	for r: Rect2 in platforms:
		if absf(r.position.y - y) < 2.0 and x >= r.position.x - 2.0 and x <= r.end.x + 2.0:
			return r
	return Rect2()


func _spawn_props() -> void:
	for s in props_spec:
		var kind := String(s[1])
		var x0 := float(s[0])
		var y: float = s[2] if s.size() > 2 else ground_top(x0)
		var plat := _platform_at(x0, y) if s.size() > 2 else Rect2()
		var r: float = OBJECT_R.get(kind, 23.0)
		var x := _free_x(x0, y, r, plat)
		if x == INF:
			continue  # no free place nearby: leave this one out rather than stack it on another
		_placed.append({"x": x, "y": y, "r": r})
		spawn_prop(kind, Vector2(x, y - 1.0))


func _spawn_hazards() -> void:
	for hz in hazards_spec:
		var x := float(hz["x"])
		var kind := String(hz["kind"])
		if kind != "ceiling_spikes":
			var r: float = OBJECT_R.get(kind, 40.0)
			var gy := ground_top(x)
			var fx := _free_x(x, gy, r, Rect2())  # free on the ground (a bumper floats, but its post is on the ground too)
			if fx == INF:
				continue  # nothing on the ground around a door, in the finish zone, or on top of another object
			x = fx
			_placed.append({"x": x, "y": gy, "r": r})
		var pos := Vector2(x, ground_top(x))
		match kind:
			"spikes":
				pass  # ground spikes were removed from the game (ceiling spikes stay)
			"ceiling_spikes":
				var tip_h := ground_top(x) - (float(hz["y"]) + SpikeTrap.H)
				if tip_h < SpikeTrap.AIR_MIN_H:
					push_warning("ceiling spikes skipped: tips %.0f px above the ground, minimum is %.0f (half the screen)" % [tip_h, SpikeTrap.AIR_MIN_H])
					continue
				var cs := SpikeTrap.new()
				cs.ceiling = true
				cs.w = float(hz.get("w", 100.0))
				cs.position = Vector2(x, float(hz["y"]))  # the underside of a platform
				add_child(cs)
			"bumper":
				var bp := Bumper.new()
				bp.position = pos + Vector2(0, -110.0)  # floats at juggle height: a pinball target for launched bodies, not a ground obstacle
				add_child(bp)
			"spring":
				spawn_prop("spring", pos + Vector2(0, -1.0))


func spawn_prop(kind: String, pos: Vector2, guaranteed := "") -> Prop:
	var p := Prop.new().setup(kind)
	p.position = pos
	p.guaranteed = guaranteed
	add_child(p)
	return p


func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.position = pos
	e.kill_y = ground_y + 800.0
	add_child(e)
	_enemies.append(e)
	return e


## True when the enemy that just fell was the last one of the battle: the final wave of an arena encounter or of a
## challenge room. Called after the enemy's state is "dead". Drives the slow-motion finish.
func is_final_kill() -> bool:
	if alive_enemies() != 0:
		return false
	if in_room:
		return _room != null and _room.kind == "challenge" and _room.is_last_wave()
	if _locked and _enc_idx < encounters.size():
		return _wave_idx >= (encounters[_enc_idx]["waves"] as Array).size()
	return false


func alive_enemies() -> int:
	_enemies = _enemies.filter(func(x): return is_instance_valid(x) and x.state != "dead")
	return _enemies.size()


# ------------------------------------------------------------------ encounters

func _physics_process(delta: float) -> void:
	if _cleared:
		return
	Coop.stat_time += delta
	if in_room:
		return  # encounters and the exit wait while the players are in a door room
	if not _locked and exit_x > 0.0 and _enc_idx >= encounters.size():
		var sum := 0.0
		var n := 0
		for f in fighters:
			if f.is_alive():
				sum += f.global_position.x
				n += 1
		if n > 0 and sum / n >= exit_x:
			_complete()
			return
	if not _locked:
		if _enc_idx < encounters.size():
			var enc: Dictionary = encounters[_enc_idx]
			var lead := -INF
			for f in fighters:
				if f.is_alive():
					lead = maxf(lead, f.global_position.x)
			if lead >= float(enc["x"]):
				_start_encounter(enc)
	else:
		var enc2: Dictionary = encounters[_enc_idx]
		var waves: Array = enc2["waves"]
		if _wave_idx < waves.size():
			if _wave_idx == 0 or alive_enemies() <= 1:
				_spawn_wave(waves[_wave_idx])
				_wave_idx += 1
		elif alive_enemies() == 0:
			_end_encounter(enc2)


func _start_encounter(enc: Dictionary) -> void:
	_locked = true
	_wave_idx = 0
	var mn := INF
	var mx := -INF
	for f in fighters:
		mn = minf(mn, f.global_position.x)
		mx = maxf(mx, f.global_position.x)
	var center := (mn + mx) * 0.5
	var half := maxf(760.0, (mx - mn) * 0.5 + 320.0)
	var left := maxf(0.0, center - half)
	var right := minf(level_w, center + half)
	_arena = Vector2(left, right)
	cam.set_bounds(left, right)
	Coop.bounds = Rect2(left, -1200, right - left, 2400)
	for x in [left - 50.0, right + 50.0]:
		var w := _make_body(Rect2(x - 50.0, -1500, 100, 3000), 1)
		_lock_walls.append(w)
	# a ceiling over the fight: a solid slab (jumps and launches stop against it) that drops in with the walls
	if bool(enc.get("ceiling", false)):  # only some battle screens have one
		var ceil_h := ARENA_CEILING_BOSS if bool(enc.get("boss", false)) else ARENA_CEILING
		_ceiling = ArenaCeiling.new()
		_ceiling.setup(left - 100.0, right + 100.0, ground_y - ceil_h, theme["neon_plat"])
		add_child(_ceiling)
		_ceiling.appear()
	_boss_fight = bool(enc.get("boss", false))
	hud.set_go(false)
	hud.banner("BOSS!" if _boss_fight else "FIGHT!", Color(2.2, 0.5, 0.4) if _boss_fight else Color(2.0, 1.6, 0.5))
	Sfx.play("boom", 1.2)
	Juice.shake(0.3)
	for f in fighters:
		f.spawn_point = Vector2(center, ground_y - 1)


func _spawn_wave(wave: Array) -> void:
	# enemies appear BETWEEN the players (dropping in), so they can be juggled between the two right away
	var xs: Array[float] = []
	for f in Coop.fighters:
		if is_instance_valid(f) and f.is_alive():
			xs.append(f.global_position.x)
	var mid := (_arena.x + _arena.y) * 0.5
	if xs.size() > 0:
		mid = 0.0
		for v in xs:
			mid += v
		mid /= xs.size()
	var spread := 60.0 + (absf(xs[0] - xs[xs.size() - 1]) * 0.4 if xs.size() > 1 else 120.0)
	var n := 0
	for entry in wave:
		n += int(entry[1])
	var k := 0
	for entry in wave:
		var kind: String = entry[0]
		for i in int(entry[1]):
			var off := ((float(k) + 0.5) / float(maxi(n, 1)) - 0.5) * 2.0 * spread
			k += 1
			var x := clampf(mid + off, _arena.x + 90.0, _arena.y - 90.0)
			var e := spawn_enemy(kind, Vector2(x, ground_top(x) - 260.0))
			e.velocity = Vector2(0, 0)
			e.invuln = 0.7


func _end_encounter(enc: Dictionary) -> void:
	_locked = false
	for w in _lock_walls:
		w.queue_free()
	_lock_walls.clear()
	if _ceiling != null and is_instance_valid(_ceiling):
		_ceiling.leave()
	_ceiling = null
	cam.set_bounds(0.0, level_w)
	Coop.bounds = Rect2(0, -1200, level_w, 2400)
	_enc_idx += 1
	Sfx.play("pickup", 1.2)
	if _boss_fight:
		_complete()
	else:
		hud.set_go(true)


func _complete() -> void:
	_cleared = true
	hud.set_go(false)
	hud.banner("LEVEL CLEAR!", Color(2.0, 1.8, 0.6))
	result_stats = LevelStats.compute(fighters, par_time)
	if RunState.active:
		RunState.coins += int(result_stats["coins"])
	hud.show_result("LEVEL CLEAR", true, result_stats)
	Sfx.play("relay")
	Coop.level_cleared.emit()


## Called from the result screen: runs go on to the reward screen, standalone levels return to the menu.
func finish_level() -> void:
	if RunState.active:
		RunState.save_from(fighters)
		RunState.level_cleared(float(result_stats.get("heal_bonus", 0.0)))
		get_tree().paused = false
		Juice.reset_time()
		get_tree().change_scene_to_file("res://scenes/reward.tscn")
	else:
		to_menu()


func _on_summon(by: Actor, count: int) -> void:
	for i in count:
		var x := clampf(by.global_position.x + (-1.0 if i % 2 == 0 else 1.0) * (150.0 + 60.0 * i), Coop.bounds.position.x + 40.0, Coop.bounds.end.x - 40.0)
		var e := spawn_enemy("thug", Vector2(x, ground_y - 1.0))
		e.velocity.y = -400.0
		Fx.ring(self, Vector2(x, ground_y - 20.0), Color(2.2, 0.5, 0.4), 80.0, 0.3)


func _on_game_over() -> void:
	hud.show_result("GAME OVER", false)


func restart() -> void:
	get_tree().paused = false
	Juice.reset_time()
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	Juice.reset_time()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ------------------------------------------------------------------ drawing

func _make_scenery() -> void:
	var sky := Node2D.new()
	sky.z_index = -100
	sky.draw.connect(_paint_sky.bind(sky))
	add_child(sky)
	var gr := Node2D.new()
	gr.z_index = -10
	gr.draw.connect(_paint_ground.bind(gr))
	add_child(gr)
	var dl := DepthLayer.new()
	dl.level = self
	add_child(dl)
	sky.queue_redraw()
	gr.queue_redraw()


func _paint_sky(c: CanvasItem) -> void:
	var top: Color = theme["sky_top"]
	var horizon: Color = theme["sky_bottom"]
	var y0 := -300.0
	if Backdrop.variant == 5:
		Backdrop.paint_synth_sky(c, -2500.0, level_w + 5000.0, y0, ground_y)
		c.draw_rect(Rect2(-2500, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))
		c.draw_rect(Rect2(level_w, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))
		return
	if Backdrop.variant == 4:
		var span := ground_y - y0
		var b1 := y0 + span * float(Pal.BG_SKY_SPLIT[0])
		var b2 := y0 + span * float(Pal.BG_SKY_SPLIT[1])
		c.draw_rect(Rect2(-2500, -1800, level_w + 5000, b1 + 1800), Pal.BG_SKY[0])
		c.draw_rect(Rect2(-2500, b1, level_w + 5000, b2 - b1), Pal.BG_SKY[1])
		c.draw_rect(Rect2(-2500, b2, level_w + 5000, ground_y - b2 + 2), Pal.BG_SKY[2])
		c.draw_rect(Rect2(-2500, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))
		c.draw_rect(Rect2(level_w, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))
		return
	c.draw_rect(Rect2(-2500, -1800, level_w + 5000, 1800 + y0 + 2), top)
	var bands := 40
	var h := (ground_y - y0) / bands
	for i in bands:
		var t := float(i) / float(bands - 1)
		c.draw_rect(Rect2(-2500, y0 + h * i, level_w + 5000, h + 1.0), top.lerp(horizon, t * t))
	# outside the level
	c.draw_rect(Rect2(-2500, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))
	c.draw_rect(Rect2(level_w, -1800, 2500, 3200), Color(0.01, 0.0, 0.03))


func _paint_ground(c: CanvasItem) -> void:
	var ng: Color = theme["neon_ground"]
	var gcol: Color = Pal.BG_GROUND if Backdrop.variant >= 4 else theme["ground"]
	for g0: Rect2 in _ground_rects():
		# the walkable surface (DepthLayer) reaches FLOOR_FRONT below the walking line; the solid front face starts there
		var g := Rect2(g0.position.x, g0.position.y + DepthLayer.FLOOR_FRONT, g0.size.x, g0.size.y - DepthLayer.FLOOR_FRONT)
		c.draw_rect(g, gcol)
		c.draw_rect(Rect2(g.position.x, g.position.y, g.size.x, 20.0), gcol.lerp(Color(minf(ng.r, 1.0), minf(ng.g, 1.0), minf(ng.b, 1.0)), 0.10))
		c.draw_line(g.position, Vector2(g.end.x, g.position.y), ng, 3.0, true)
		var gx := g.position.x - fmod(g.position.x, 80.0)
		while gx < g.end.x:
			c.draw_line(Vector2(maxf(gx, g.position.x), g.position.y), Vector2(gx - 40, g.position.y + 200), Color(ng.r, ng.g, ng.b, 0.12), 1.5)
			gx += 80.0
		for dy in [28.0, 70.0, 130.0]:
			c.draw_line(Vector2(g.position.x, g.position.y + dy), Vector2(g.end.x, g.position.y + dy), Color(ng.r, ng.g, ng.b, 0.10), 1.5)
		if not ground_segs.is_empty():
			# lit side walls: pit edges and steps read clearly
			c.draw_line(g.position, Vector2(g.position.x, g.position.y + 700.0), Color(ng.r, ng.g, ng.b, 0.55), 3.0, true)
			c.draw_line(Vector2(g.end.x, g.position.y), Vector2(g.end.x, g.position.y + 700.0), Color(ng.r, ng.g, ng.b, 0.55), 3.0, true)
	c.draw_line(Vector2(0, -1500), Vector2(0, ground_y), ng, 3.0)
	c.draw_line(Vector2(level_w, -1500), Vector2(level_w, ground_y), ng, 3.0)
	# (the finish line is drawn by DepthLayer)
	var np: Color = theme["neon_plat"]
	for r: Rect2 in platforms:
		if Backdrop.variant == 0:
			c.draw_rect(r, Color(0.08, 0.03, 0.14))
			c.draw_line(r.position, Vector2(r.end.x, r.position.y), np, 3.5, true)
			c.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(np.r, np.g, np.b, 0.3), 2.0, true)
			continue
		# (variants 1+: platforms are drawn as 3D boxes by DepthLayer)


# ------------------------------------------------------------------ ledges

var _ledges: Array = []


## Corners a falling player can grab: {p: corner position, dir: +1 when the standable surface extends to the right of
## the corner (a left edge), -1 for a right edge}. Pit edges, steps down and both ends of every platform.
func ledge_points() -> Array:
	if not _ledges.is_empty() or (ground_segs.is_empty() and platforms.is_empty()):
		return _ledges
	var n := ground_segs.size()
	for i in n:
		var g: Rect2 = ground_segs[i]
		if i > 0:
			var prev: Rect2 = ground_segs[i - 1]
			if g.position.x - prev.end.x > 1.0 or prev.position.y > g.position.y + 10.0:
				_ledges.append({"p": g.position, "dir": 1})
		if i < n - 1:
			var nxt: Rect2 = ground_segs[i + 1]
			if nxt.position.x - g.end.x > 1.0 or nxt.position.y > g.position.y + 10.0:
				_ledges.append({"p": Vector2(g.end.x, g.position.y), "dir": -1})
	for r: Rect2 in platforms:
		# platform ends are only grabbable over a pit; above solid ground you just drop down
		if ground_at(r.position.x) == INF:
			_ledges.append({"p": r.position, "dir": 1})
		if ground_at(r.end.x) == INF:
			_ledges.append({"p": Vector2(r.end.x, r.position.y), "dir": -1})
	return _ledges


# ------------------------------------------------------------------ doors and rooms

func _spawn_doors() -> void:
	for d in doors_spec:
		var door := Door.new()
		door.kind = String(d["kind"])
		door.pick_move = bool(d.get("pick", false))
		door.level = self
		var x := float(d["x"])
		door.position = Vector2(x, ground_top(x))
		add_child(door)


## The optional bonus pole near the finish line (only levels that have one).
func _spawn_bonus_pole() -> void:
	if exit_x <= 0.0:
		return
	var pole := BonusPole.new()
	var px := exit_x + 50.0  # right above the middle of the finish strip: crossing the line is the one try
	pole.ground_y = ground_top(px)
	pole.position = Vector2(px, pole.ground_y)
	add_child(pole)


func enter_room(door: Door) -> void:
	if in_room or _locked or _cleared:
		return
	in_room = true
	_room_door = door
	_room = DoorRoom.new().setup(self, door.kind)
	_room.pick_move = door.pick_move
	_room.enter()


func leave_room() -> void:
	if not in_room:
		return
	in_room = false
	var door := _room_door
	door.used = true
	if _room != null:
		_room.leave()
		_room = null
	cam.set_bounds(0.0, level_w)
	cam.min_zoom = 0.45
	Coop.bounds = Rect2(0, -1200, level_w, 2400)
	var i := 0
	for f in fighters:
		f.global_position = door.global_position + Vector2(-70.0 + i * 70.0, -1.0)
		f.velocity = Vector2.ZERO
		f.last_safe = f.global_position
		i += 1
	cam.snap()
