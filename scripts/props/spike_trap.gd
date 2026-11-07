class_name SpikeTrap
extends Node2D
## Floor spikes. Anyone who steps on them is hurt a little (players and enemies alike); an enemy that is THROWN or
## launched into them takes a big hit and is popped up for the follow-up, and the combo carries on (the damage is
## credited to whoever last hit or threw it).

const W := 100.0
const H := 18.0
const COL := Color(2.2, 0.35, 0.3)

var _cd: Dictionary = {}  # actor instance id -> seconds until it can be hurt again
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("hazards")
	z_index = 1


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta
		if float(_cd[k]) <= 0.0:
			_cd.erase(k)
	var zone := Rect2(global_position.x - W * 0.5, global_position.y - H - 6.0, W, H + 12.0)
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Actor):
			continue
		var a := n as Actor
		if not a.is_alive() or a.state == "dead" or a.state == "downed" or _cd.has(a.get_instance_id()):
			continue
		var feet := Rect2(a.global_position.x - 14.0, a.global_position.y - 14.0, 28.0, 18.0)
		if zone.intersects(feet):
			_hurt(a)


func _hurt(a: Actor) -> void:
	_cd[a.get_instance_id()] = 0.7
	_flash = 1.0
	var info := HitInfo.new()
	info.source = "hazard"
	info.color = COL
	info.pos = a.global_position + Vector2(0, -20)
	info.stop = 5
	info.shake = 0.25
	var airborne := a.state == "launched" or a.velocity.y > 300.0
	if a.team == "enemy":
		info.team = "player"
		var credit: Node = a.last_hitter if (a.last_hitter != null and is_instance_valid(a.last_hitter)) else a.thrown_by
		info.attacker = credit
		info.dmg = 34.0 if airborne else 12.0
		info.kind = "launch"
		info.stun = 30
		info.kb = Vector2(signf(a.velocity.x) * 120.0, -620.0 if airborne else -380.0)
	else:
		info.team = "enemy"
		info.dmg = 8.0
		info.kind = "normal"
		info.stun = 12
		info.kb = Vector2(0.0, -280.0)
	Fx.sparks(get_parent(), global_position + Vector2(0, -10), COL, 10)
	Sfx.play("hit2", 0.8)
	a.take_hit(info)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var n := 8
	var step := W / float(n)
	var glow := 0.55 + 0.45 * _flash
	draw_rect(Rect2(-W * 0.5, -4.0, W, 6.0), Color(0.12, 0.03, 0.04))
	for i in n:
		var x := -W * 0.5 + step * (float(i) + 0.5)
		var tri := PackedVector2Array([Vector2(x - step * 0.45, -3.0), Vector2(x, -H - 3.0 * _flash), Vector2(x + step * 0.45, -3.0)])
		draw_colored_polygon(tri, Color(COL.r * 0.25, COL.g * 0.25, COL.b * 0.25))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color(COL.r * glow, COL.g * glow, COL.b * glow), 2.5, true)
	draw_line(Vector2(-W * 0.5, -3.0), Vector2(W * 0.5, -3.0), Color(COL.r, COL.g, COL.b, 0.8), 2.0, true)
