class_name ChargeFx
extends Node2D
## What a charging move looks like: energy orbs gathering towards the body. There are only a few at first and more as the
## charge builds, and they turn from translucent white to the player's colour. A "MAX" flash and a burst of sparks mark a
## full charge. It reads the progress from the AttackRunner and removes itself when the hold ends.

const ORBS_MIN := 3
const ORBS_MAX := 15

var runner: AttackRunner
var actor: Actor
var _t := 0.0
var _full_shown := false


func _ready() -> void:
	z_index = 6
	position = Vector2(0.0, -52.0)


func _process(delta: float) -> void:
	_t += delta
	if runner == null or actor == null or not is_instance_valid(actor) or not runner.active or not runner.charging():
		queue_free()
		return
	var ct := runner.charge_t()
	if ct >= 1.0 and not _full_shown:
		_full_shown = true
		Fx.sparks(actor.get_parent(), actor.global_position + position, actor.figure.color, 16)
		Sfx.play("buff", 1.6)
		Juice.shake(0.25)
	# the body glows and trembles a little more as the charge builds
	actor.figure.modulate = Color(1.0 + 0.9 * ct, 1.0 + 0.6 * ct * (0.6 + 0.4 * sin(_t * 30.0)), 1.0 + 0.1 * ct)
	queue_redraw()


func _draw() -> void:
	if runner == null:
		return
	var ct := runner.charge_t()
	var base: Color = actor.figure.color
	var white := Color(1.0, 1.0, 1.0)
	var col := white.lerp(base, clampf(ct * 1.15, 0.0, 1.0))  # translucent white at first, the player's colour later
	var alpha := lerpf(0.55, 1.0, ct)
	var n_f := lerpf(float(ORBS_MIN), float(ORBS_MAX), ct)  # few orbs at first, more as it charges
	var reach := 96.0
	for i in ORBS_MAX:
		var weight := clampf(n_f - float(i), 0.0, 1.0)  # the newest orb fades in instead of popping
		if weight <= 0.0:
			break
		var a := _t * 2.6 + float(i) * 2.399  # spread by the golden angle so they never line up
		var k := fposmod(_t * 1.5 + float(i) * 0.137, 1.0)  # 0 = far, 1 = arrived
		var d := lerpf(reach, 6.0, k * k)
		var pos := Vector2.from_angle(a + k * 1.6) * d
		var fade := sin(k * PI)  # fades in far away and out as it arrives
		var rad := 3.4 + 2.8 * ct
		draw_circle(pos, rad * 2.2, Color(col.r, col.g, col.b, alpha * weight * fade * 0.22))
		draw_circle(pos, rad, Color(col.r, col.g, col.b, alpha * weight * fade))
	if ct >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -74.0), "MAX", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(base.r, base.g, base.b, 0.6 + 0.4 * pulse))
