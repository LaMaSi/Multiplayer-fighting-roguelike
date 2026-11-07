extends CanvasLayer
## Autoload "Dbg": F1 toggles the debug overlay (FPS, per-player state, controllers, hitboxes).

var enabled := false

var _label: Label
var _hint: Label
var _hint_time := 12.0


func _ready() -> void:
	layer = 100
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])

	_label = Label.new()
	_label.position = Vector2(12, 10)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.visible = false
	add_child(_label)

	_hint = Label.new()
	_hint.position = Vector2(12, 668)
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.modulate = Color(1, 1, 1, 0.75)
	_hint.text = "F1 debug | F11 fullscreen | P1: pad or WASD+Space, F/G/H=X/Y/B | P2: pad or Arrows+Shift, , . /=X/Y/B | Down+A on a platform = drop through"
	add_child(_hint)


func toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		toggle_fullscreen()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		enabled = not enabled
		_label.visible = enabled
	# impact size: [ smaller, ] bigger (while the overlay is on; also a slider in Testing Options later)
	if enabled and event is InputEventKey and event.pressed and event.physical_keycode == KEY_BRACKETLEFT:
		Fx.impact_scale = maxf(0.0, Fx.impact_scale - 0.25)
	if enabled and event is InputEventKey and event.pressed and event.physical_keycode == KEY_BRACKETRIGHT:
		Fx.impact_scale = minf(3.0, Fx.impact_scale + 0.25)


func _process(delta: float) -> void:
	_hint_time -= delta
	if _hint_time < 0.0:
		_hint.modulate.a = maxf(0.0, _hint.modulate.a - delta)
	if not enabled:
		return
	var t := "FPS %d   pads: %s   impact scale %.2f ([ ])\n" % [Engine.get_frames_per_second(), str(Input.get_connected_joypads()), Fx.impact_scale]
	for n in get_tree().get_nodes_in_group("fighters"):
		t += (n as Fighter).debug_text() + "\n"
	_label.text = t
