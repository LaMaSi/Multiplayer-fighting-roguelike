class_name GravityZone
extends Node2D
## Magic's Gravity Well: a lasting zone that drags enemies toward its centre for a few seconds (and keeps them
## flinching), so the team can gather a crowd for a big hit. Drawn as rings that keep collapsing inwards.

var team := "player"
var owner_actor: Actor = null
var radius := 200.0
var life := 4.0
var col := Color(1.6, 1.0, 2.0)
var pull_speed := 440.0

var _t := 0.0
var _tick := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	var group := "hurt_enemy" if team == "player" else "hurt_player"
	for n in get_tree().get_nodes_in_group(group):
		if not (n is Actor):
			continue
		var a := n as Actor
		if not a.is_targetable() or a.state == "dead":
			continue
		var to := global_position - (a.global_position + Vector2(0, -45.0))
		if to.length() > radius:
			continue
		var pull := clampf(absf(to.x), 0.0, pull_speed * delta)
		if a.state == "launched":
			a.velocity.x += signf(to.x) * 900.0 * delta
			a.velocity.y += signf(to.y) * 500.0 * delta
		elif not a.attack.active:
			a.global_position.x += signf(to.x) * pull
		if _tick <= 0.0:
			var info := HitInfo.new()
			info.attacker = owner_actor
			info.team = team
			info.dmg = 2.0
			info.stun = 10
			info.kind = "normal"
			info.stop = 0
			info.source = "zone"
			info.shake = 0.0
			info.color = col
			info.pos = a.global_position + Vector2(0, -50)
			info.kb = Vector2.ZERO
			a.take_hit(info)
	if _tick <= 0.0:
		_tick = 0.5
	queue_redraw()


func _draw() -> void:
	var fade := clampf(life / 0.6, 0.0, 1.0)
	var c := Vector2(0, 0)
	for k in 4:
		var ph := fmod(_t * 0.9 + float(k) / 4.0, 1.0)
		var r := radius * (1.0 - ph)
		draw_arc(c, r, _t * 2.0 + float(k), _t * 2.0 + float(k) + TAU * 0.72, 28, Color(col.r, col.g, col.b, (0.15 + 0.55 * ph) * fade), 3.0, true)
	draw_circle(c, 10.0 + 3.0 * sin(_t * 8.0), Color(col.r, col.g, col.b, 0.8 * fade))
	draw_circle(c, 4.5, Color(2.6, 2.6, 2.6, fade))
	for i in 8:
		var a := float(i) * TAU / 8.0 + _t * 1.5
		var rr := radius * (0.25 + 0.75 * fmod(_t * 0.7 + float(i) * 0.137, 1.0))
		draw_circle(Vector2.from_angle(a) * rr, 2.5, Color(col.r, col.g, col.b, 0.7 * fade))
