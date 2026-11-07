class_name Bumper
extends Node2D
## A pinball bumper: anything that touches it (players, enemies, launched bodies) is knocked straight back, faster than
## it came. Players are flung in a fast jump they can act out of; enemies are launched (and the combo carries on).

const R := 34.0
const COL := Color(2.0, 0.5, 1.4)

var _cd: Dictionary = {}
var _pulse := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("hazards")
	z_index = 1


func _centre() -> Vector2:
	return global_position + Vector2(0, -R)


func _physics_process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta
		if float(_cd[k]) <= 0.0:
			_cd.erase(k)
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Actor):
			continue
		var a := n as Actor
		if not a.is_alive() or a.state == "dead" or a.state == "downed" or a.state == "grabbed" or _cd.has(a.get_instance_id()):
			continue
		var to := (a.global_position + Vector2(0, -45.0)) - _centre()
		if to.length() < R + 24.0:
			_bounce(a, to)


func _bounce(a: Actor, to: Vector2) -> void:
	_cd[a.get_instance_id()] = 0.35
	_pulse = 1.0
	var dir := to.normalized() if to.length() > 1.0 else Vector2(1, -1).normalized()
	var speed := maxf(820.0, minf(a.velocity.length() * 1.05, 1500.0))
	var v := dir * speed
	v.y = minf(v.y, -240.0)  # always some lift: the bounce reads as a launch, not a slide
	var by: Actor = a
	if a.team == "enemy" and a.last_hitter != null and is_instance_valid(a.last_hitter):
		by = a.last_hitter
	a.thrown(v, by)
	if a.team == "enemy":
		Coop.bonus_hit(a.last_hitter as Actor, a, 0.0)  # keeps a combo alive
	Fx.ring(get_parent(), _centre(), COL, 90.0, 0.25)
	Fx.sparks(get_parent(), _centre() + dir * R, COL, 8, dir)
	Sfx.play("hit2", 1.5)
	Juice.shake(0.12)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0, -R)
	var sq := 1.0 + 0.22 * _pulse
	var glow := 0.6 + 0.4 * _pulse + 0.1 * sin(_t * 5.0)
	draw_rect(Rect2(-R * 0.7, -6.0, R * 1.4, 8.0), Color(0.1, 0.03, 0.1))  # base
	draw_circle(c, R * sq + 8.0, Color(COL.r, COL.g, COL.b, 0.12 + 0.2 * _pulse))
	draw_circle(c, R * sq, Color(0.12, 0.03, 0.12))
	draw_arc(c, R * sq, 0.0, TAU, 32, Color(COL.r * glow, COL.g * glow, COL.b * glow), 4.0, true)
	draw_arc(c, R * 0.62 * sq, 0.0, TAU, 28, Color(COL.r * glow, COL.g * glow, COL.b * glow, 0.8), 3.0, true)
	for i in 6:
		var a := float(i) * TAU / 6.0 + _t * 0.6
		draw_line(c + Vector2.from_angle(a) * R * 0.2, c + Vector2.from_angle(a) * R * 0.55, Color(COL.r, COL.g, COL.b, 0.7), 2.5, true)
	draw_circle(c, R * 0.16, Color(2.6, 2.6, 2.6))
