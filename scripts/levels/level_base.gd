class_name LevelBase
extends Node2D
## Builds a side-scrolling level in code: ground, one-way platforms, props, two players,
## shared camera, HUD, pause menu, and runs arena-lock encounters.
## Subclasses override _setup() to fill in the data.

const PLAT_H := 16.0

var level_w := 3200.0
var ground_y := 600.0
var platforms: Array = []  ## Rect2 (top-left, size)
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
	_make_body(Rect2(-300, ground_y, level_w + 600, 400), 1)
	_make_body(Rect2(-100, -1500, 100, 3000), 1)
	_make_body(Rect2(level_w, -1500, 100, 3000), 1)
	for r: Rect2 in platforms:
		var b := _make_body(r, 2, true)
		b.set_meta("bottom_y", r.end.y)


func _spawn_players() -> void:
	for i in 2:
		var f := Fighter.new()
		f.player_index = i
		f.position = Vector2(260 + i * 90, ground_y - 1)
		f.kill_y = ground_y + 700.0
		add_child(f)
		fighters.append(f)


func _build_camera() -> void:
	cam = CameraRig.new()
	cam.limit_top = -500
	cam.limit_bottom = int(ground_y + 130.0)
	cam.set_bounds(0.0, level_w)
	cam.min_zoom = 0.62
	for f in fighters:
		cam.targets.append(f)
	add_child(cam)
	cam.snap()
	var b: Backdrop = get_meta("backdrop")
	b.cam = cam


func _spawn_props() -> void:
	for s in props_spec:
		var y: float = s[2] if s.size() > 2 else ground_y
		spawn_prop(String(s[1]), Vector2(float(s[0]), y - 1.0))


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


func alive_enemies() -> int:
	_enemies = _enemies.filter(func(x): return is_instance_valid(x) and x.state != "dead")
	return _enemies.size()


# ------------------------------------------------------------------ encounters

func _physics_process(delta: float) -> void:
	if _cleared:
		return
	Coop.stat_time += delta
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
	_boss_fight = bool(enc.get("boss", false))
	hud.set_go(false)
	hud.banner("BOSS!" if _boss_fight else "FIGHT!", Color(2.2, 0.5, 0.4) if _boss_fight else Color(2.0, 1.6, 0.5))
	Sfx.play("boom", 1.2)
	Juice.shake(0.3)
	for f in fighters:
		f.spawn_point = Vector2(center, ground_y - 1)


func _spawn_wave(wave: Array) -> void:
	for entry in wave:
		var kind: String = entry[0]
		var count: int = entry[1]
		for i in count:
			var side := 1.0 if randf() < 0.5 else -1.0
			var x := (_arena.y - 70.0) if side > 0.0 else (_arena.x + 70.0)
			x += randf_range(-30.0, 30.0) * -side
			var e := spawn_enemy(kind, Vector2(x, ground_y - 1.0))
			e.velocity = Vector2(-side * 120.0, 0)


func _end_encounter(enc: Dictionary) -> void:
	_locked = false
	for w in _lock_walls:
		w.queue_free()
	_lock_walls.clear()
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
		Engine.time_scale = 1.0
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
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
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
	c.draw_rect(Rect2(-2500, ground_y, level_w + 5000, 700), Pal.BG_GROUND if Backdrop.variant >= 4 else theme["ground"])
	c.draw_line(Vector2(-2500, ground_y), Vector2(level_w + 2500, ground_y), ng, 3.0, true)
	var gx := -2500.0
	while gx < level_w + 2500.0:
		c.draw_line(Vector2(gx, ground_y), Vector2(gx - 40, ground_y + 200), Color(ng.r, ng.g, ng.b, 0.12), 1.5)
		gx += 80.0
	for dy in [28.0, 70.0, 130.0]:
		c.draw_line(Vector2(-2500, ground_y + dy), Vector2(level_w + 2500, ground_y + dy), Color(ng.r, ng.g, ng.b, 0.10), 1.5)
	c.draw_line(Vector2(0, -1500), Vector2(0, ground_y), ng, 3.0)
	c.draw_line(Vector2(level_w, -1500), Vector2(level_w, ground_y), ng, 3.0)
	if exit_x > 0.0:
		var door := Rect2(exit_x, ground_y - 190.0, 120.0, 190.0)
		c.draw_rect(door, Color(0.1, 0.07, 0.02))
		c.draw_rect(door, Pal.interact(), false, 4.0)
		c.draw_rect(Rect2(door.position + Vector2(14, 14), door.size - Vector2(28, 14)), Color(1.0, 0.8, 0.2, 0.18))
		c.draw_string(ThemeDB.fallback_font, door.position + Vector2(0, -12), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, door.size.x, 26, Pal.interact())
	var np: Color = theme["neon_plat"]
	for r: Rect2 in platforms:
		if Backdrop.variant == 0:
			c.draw_rect(r, Color(0.08, 0.03, 0.14))
			c.draw_line(r.position, Vector2(r.end.x, r.position.y), np, 3.5, true)
			c.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(np.r, np.g, np.b, 0.3), 2.0, true)
			continue
		# readable "solid": soft shadow below, a lit slab body, a bright top edge and a dark underside
		for i in 3:
			c.draw_rect(Rect2(r.position.x + 6 + i * 3, r.end.y + 2 + i * 6, r.size.x - 12 - i * 6, 6), Color(0, 0, 0, 0.22 - i * 0.06))
		c.draw_rect(r, Color(np.r * 0.16, np.g * 0.16, np.b * 0.16, 1.0))
		c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.45), Color(np.r * 0.3, np.g * 0.3, np.b * 0.3, 1.0))
		c.draw_rect(Rect2(r.position.x, r.end.y - 4.0, r.size.x, 4.0), Color(0.02, 0.01, 0.04, 0.9))
		c.draw_line(r.position, Vector2(r.end.x, r.position.y), np, UiKit.LINE, true)
		c.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Color(np.r, np.g, np.b, 0.55), UiKit.LINE, true)
		c.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(np.r, np.g, np.b, 0.55), UiKit.LINE, true)
