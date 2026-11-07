class_name PlayerInput
extends RefCounted
## One player's input: left stick / D-pad direction plus buttons, from an Xbox
## controller and/or a keyboard set. Polled once per physics frame by the Inp autoload.
## Tests can switch it to "scripted" mode and feed fake input.

enum Btn { JUMP, X, Y, B, DASH, INTERACT, LB, RB, START, BACK, COUNT }

const DEADZONE := 0.35

const PAD_BTN := {
	Btn.JUMP: JOY_BUTTON_A,
	Btn.X: JOY_BUTTON_X,
	Btn.Y: JOY_BUTTON_Y,
	Btn.B: JOY_BUTTON_B,
	Btn.LB: JOY_BUTTON_LEFT_SHOULDER,
	Btn.RB: JOY_BUTTON_RIGHT_SHOULDER,
	Btn.START: JOY_BUTTON_START,
	Btn.BACK: JOY_BUTTON_BACK,
}

# Keyboard fallbacks (physical keys, so layout independent).
# P1: WASD + Space, F/G/H = X/Y/B, C = dash, V = interact, Q/E = LB/RB, Tab = loadout (pad: Back)
# P2: Arrows + Shift, , . / = X/Y/B, ; = dash, ' = interact, [ ] = LB/RB
const KB := [
	{
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"btn": {
			Btn.JUMP: KEY_SPACE, Btn.X: KEY_F, Btn.Y: KEY_G, Btn.B: KEY_H,
			Btn.DASH: KEY_C, Btn.INTERACT: KEY_V, Btn.LB: KEY_Q, Btn.RB: KEY_E, Btn.BACK: KEY_TAB,
		},
	},
	{
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"btn": {
			Btn.JUMP: KEY_SHIFT, Btn.X: KEY_COMMA, Btn.Y: KEY_PERIOD, Btn.B: KEY_SLASH,
			Btn.DASH: KEY_SEMICOLON, Btn.INTERACT: KEY_APOSTROPHE,
			Btn.LB: KEY_BRACKETLEFT, Btn.RB: KEY_BRACKETRIGHT, Btn.BACK: KEY_BACKSLASH,
		},
	},
]

var index := 0
var device := -1  ## joypad id, -1 = none connected for this player
var dir := Vector2.ZERO  ## movement direction, length <= 1, deadzone applied
var held: Array = []
var prev: Array = []

var scripted := false
var _s_dir := Vector2.ZERO
var _s_held: Array = []


func _init(player_index: int = 0) -> void:
	index = player_index
	held = _blank()
	prev = _blank()
	_s_held = _blank()


static func _blank() -> Array:
	var a: Array = []
	a.resize(Btn.COUNT)
	a.fill(false)
	return a


func poll() -> void:
	prev = held
	var nh := _blank()
	var d := Vector2.ZERO
	if scripted:
		d = _s_dir
		nh = _s_held.duplicate()
	else:
		var pads := Input.get_connected_joypads()
		device = pads[index] if index < pads.size() else -1
		if device >= 0:
			var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
			if v.length() >= DEADZONE:
				d = v
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
				d.x = -1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
				d.x = 1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
				d.y = -1.0
			if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
				d.y = 1.0
			for b in PAD_BTN:
				if Input.is_joy_button_pressed(device, PAD_BTN[b]):
					nh[b] = true
			# RT = dodge dash, RB = interact / grab (LT is reserved for empowered moves later)
			if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
				nh[Btn.DASH] = true
			if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
				nh[Btn.INTERACT] = true
		var k: Dictionary = KB[index]
		var kd := Vector2(
			float(Input.is_physical_key_pressed(k["right"])) - float(Input.is_physical_key_pressed(k["left"])),
			float(Input.is_physical_key_pressed(k["down"])) - float(Input.is_physical_key_pressed(k["up"])))
		if kd != Vector2.ZERO:
			d = kd
		var kb: Dictionary = k["btn"]
		for b in kb:
			if Input.is_physical_key_pressed(kb[b]):
				nh[b] = true
	if d.length() > 1.0:
		d = d.normalized()
	dir = d
	held = nh


## Test helper: take over this player and feed fake input.
func script_set(d: Vector2, buttons: Array = []) -> void:
	scripted = true
	_s_dir = d
	_s_held = _blank()
	for b in buttons:
		_s_held[b] = true


func is_held(b: int) -> bool:
	return held[b]


func pressed(b: int) -> bool:
	return held[b] and not prev[b]


func released(b: int) -> bool:
	return prev[b] and not held[b]


## Dominant stick direction as -1/0/1 per axis (only one axis set). Used later to pick move slots.
func digital_dir() -> Vector2i:
	if dir.length() < 0.5:
		return Vector2i.ZERO
	if absf(dir.x) >= absf(dir.y):
		return Vector2i(1 if dir.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if dir.y > 0.0 else -1)


func buttons_string() -> String:
	var names := ["A", "X", "Y", "B", "RT", "RB", "LB", "RB", "ST", "BK"]
	var s := ""
	for i in Btn.COUNT:
		if held[i]:
			s += names[i] + " "
	return s
