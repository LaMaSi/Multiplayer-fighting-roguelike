extends CanvasLayer
## Post-processing presets. F10 cycles them while playing. Preset 0 = off.

const PRESETS := [
	{"name": "Off", "p": {}},
	{"name": "CRT", "p": {"curvature": 0.12, "scanline": 0.28, "mask": 0.18, "chroma": 1.3, "vignette": 0.4, "bloom": 0.5}},
	{"name": "Pixel", "p": {"pixel": 4.0}},
	{"name": "Pixel + dither", "p": {"pixel": 3.0, "levels": 6.0, "dither": 1.0, "vignette": 0.2}},
	{"name": "Polish", "p": {"vignette": 0.35, "chroma": 0.7, "grain": 0.03, "bloom": 0.6}},
]
const PARAMS := ["pixel", "curvature", "scanline", "mask", "chroma", "vignette", "grain", "levels", "dither", "bloom"]

var index := 0
var _rect: ColorRect
var _mat: ShaderMaterial
var _label: Label
var _toast := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/post.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_label = Label.new()
	_label.position = Vector2(540, 690)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	add_child(_label)
	set_preset(0)


func set_preset(i: int, toast := false) -> void:
	index = posmod(i, PRESETS.size())
	var p: Dictionary = PRESETS[index]["p"]
	for k in PARAMS:
		_mat.set_shader_parameter(k, float(p.get(k, 0.0)))
	_rect.visible = index != 0
	if toast:
		_label.text = "Post FX: %s" % PRESETS[index]["name"]
		_label.visible = true
		_toast = 1.5


func _process(delta: float) -> void:
	if _toast > 0.0:
		_toast -= delta
		if _toast <= 0.0:
			_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		set_preset(index + 1, true)
