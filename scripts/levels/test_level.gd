extends Node2D
## M0 test level: ground, one-way platforms, walls, two players, shared camera.
## Everything is built in code so levels stay data-driven.

const LEVEL_W := 3200.0
const GROUND_Y := 600.0
const PLAT_H := 16.0
## x, y(top), width
const PLATFORMS := [
	Rect2(400, 470, 260, PLAT_H),
	Rect2(800, 360, 260, PLAT_H),
	Rect2(1250, 470, 300, PLAT_H),
	Rect2(1700, 330, 300, PLAT_H),
	Rect2(2100, 450, 320, PLAT_H),
	Rect2(2600, 350, 260, PLAT_H),
]

var fighters: Array[Fighter] = []
var cam: CameraRig

const NEON_PLAT := Color(2.0, 0.6, 1.3)
const NEON_GROUND := Color(0.5, 1.4, 2.0)


func _ready() -> void:
	_build_environment()
	_build_world()
	_spawn_players()
	_build_camera()
	queue_redraw()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


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
	_make_body(Rect2(-300, GROUND_Y, LEVEL_W + 600, 400), 1)
	_make_body(Rect2(-100, -1500, 100, 3000), 1)  # left wall
	_make_body(Rect2(LEVEL_W, -1500, 100, 3000), 1)  # right wall
	for r: Rect2 in PLATFORMS:
		var b := _make_body(r, 2, true)
		b.set_meta("bottom_y", r.end.y)


func _spawn_players() -> void:
	for i in 2:
		var f := Fighter.new()
		f.player_index = i
		f.position = Vector2(300 + i * 90, GROUND_Y - 1)
		f.kill_y = GROUND_Y + 700.0
		add_child(f)
		fighters.append(f)


func _build_camera() -> void:
	cam = CameraRig.new()
	cam.limit_left = 0
	cam.limit_right = int(LEVEL_W)
	cam.limit_top = -500
	cam.limit_bottom = int(GROUND_Y + 130.0)
	for f in fighters:
		cam.targets.append(f)
	add_child(cam)
	cam.snap()


func _draw() -> void:
	# sky bands
	var top := Color(0.02, 0.01, 0.06)
	var horizon := Color(0.20, 0.05, 0.24)
	var y0 := -1500.0
	var bands := 48
	var h := (GROUND_Y - y0) / bands
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(-1500, y0 + h * i, LEVEL_W + 3000, h + 1.0), top.lerp(horizon, pow(t, 2.2)))
	# ground
	draw_rect(Rect2(-1500, GROUND_Y, LEVEL_W + 3000, 600), Color(0.05, 0.03, 0.10))
	draw_line(Vector2(-1500, GROUND_Y), Vector2(LEVEL_W + 1500, GROUND_Y), NEON_GROUND, 3.0, true)
	var gx := -1500.0
	while gx < LEVEL_W + 1500.0:
		draw_line(Vector2(gx, GROUND_Y), Vector2(gx - 40, GROUND_Y + 200), Color(NEON_GROUND.r, NEON_GROUND.g, NEON_GROUND.b, 0.12), 1.5)
		gx += 80.0
	for dy in [28.0, 70.0, 130.0]:
		draw_line(Vector2(-1500, GROUND_Y + dy), Vector2(LEVEL_W + 1500, GROUND_Y + dy), Color(NEON_GROUND.r, NEON_GROUND.g, NEON_GROUND.b, 0.10), 1.5)
	# walls
	draw_rect(Rect2(-1500, -1500, 1500, 3000), Color(0.01, 0.0, 0.03))
	draw_rect(Rect2(LEVEL_W, -1500, 1500, 3000), Color(0.01, 0.0, 0.03))
	draw_line(Vector2(0, -1500), Vector2(0, GROUND_Y), NEON_GROUND, 3.0)
	draw_line(Vector2(LEVEL_W, -1500), Vector2(LEVEL_W, GROUND_Y), NEON_GROUND, 3.0)
	# platforms
	for r: Rect2 in PLATFORMS:
		draw_rect(r, Color(0.08, 0.03, 0.14))
		draw_line(r.position, Vector2(r.end.x, r.position.y), NEON_PLAT, 3.5, true)
		draw_line(Vector2(r.position.x, r.end.y), r.end, Color(NEON_PLAT.r, NEON_PLAT.g, NEON_PLAT.b, 0.3), 2.0, true)
