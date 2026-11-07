class_name ScreenBackdrop
extends Node2D
## Synthwave sky, skyline and ground in screen space (fixed camera) for menu screens: start screen,
## shop and run map overlays. Add it as the first child of a screen.

var ground_y := 570.0
var show_ground := true
var _cam: Camera2D


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.22
	e.glow_strength = 0.6
	e.glow_hdr_threshold = 1.7
	env.environment = e
	add_child(env)
	var sky := Node2D.new()
	sky.z_index = -100
	sky.draw.connect(func():
		Backdrop.paint_synth_sky(sky, -400.0, 2080.0, -300.0, ground_y)
		if show_ground:
			sky.draw_rect(Rect2(-400, ground_y, 2080, 400), Pal.BG_GROUND)
			sky.draw_line(Vector2(-400, ground_y), Vector2(1680, ground_y), Pal.terrain(), UiKit.LINE, true))
	add_child(sky)
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	add_child(_cam)
	var bd := Backdrop.new()
	bd.setup(Backdrop.default_theme(), 1280.0, ground_y)
	bd.cam = _cam
	add_child(bd)
