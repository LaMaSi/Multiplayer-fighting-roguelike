class_name ChargeFx
extends Node2D
## What a charging move looks like: a ring that fills round the body (player colour, turning gold), energy motes streaming
## in, and a flash at full charge. It reads the progress from the AttackRunner and removes itself when the hold ends.

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
		Fx.ring(actor.get_parent(), actor.global_position + position, Color(2.4, 2.0, 0.5), 110.0, 0.35)
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
	var gold := Color(2.4, 1.9, 0.4)
	var col := base.lerp(gold, ct)
	var r := 52.0 + 6.0 * sin(_t * 12.0) * ct
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.16), 9.0, true)  # the empty track
	if ct > 0.0:
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * ct, 48, col, 5.0, true)
	# energy motes flying inwards
	for i in 6:
		var a := _t * 3.0 + float(i) * TAU / 6.0
		var k := fposmod(_t * 1.6 + float(i) * 0.17, 1.0)
		var d := lerpf(r + 40.0, 8.0, k)
		draw_circle(Vector2.from_angle(a) * d, 2.5 + 2.0 * ct, Color(col.r, col.g, col.b, (1.0 - k) * (0.4 + 0.5 * ct)))
	if ct >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 40, Color(gold.r, gold.g, gold.b, 0.4 + 0.5 * pulse), 4.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(-40.0, -r - 14.0), "MAX", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(2.4, 2.0, 0.6, 0.6 + 0.4 * pulse))
