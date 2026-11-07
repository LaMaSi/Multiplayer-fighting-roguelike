class_name Projectile
extends Node2D
## Orbs, discs, ground waves and thrown bottles. Hits the opposing team, can be reflected.

var team := "player"
var owner_actor: Actor = null
var vel := Vector2.ZERO
var dmg := 8.0
var stun := 16
var kb := Vector2(150, 0)
var kind := "normal"
var shape := "orb"  ## orb, disc, wave, bottle
var life := 1.5
var radius := 12.0
var col := Color(2.2, 1.0, 0.3)
var pierce := false
var ground := false
var gravity := 0.0
var returns := 0.0
var reflected := false
var height := "mid"
var ignite := 0.0
var splash := 0.0  ## blast radius: neighbours of the first victim take half damage (fireball)
var _trail_t := 0.0

var _age := 0.0
var _done: Dictionary = {}
var _turned := false
var _spin := 0.0


## `e` is a "proj" event dictionary from MoveData.
static func launch(a: Actor, e: Dictionary) -> void:
	var p := Projectile.new()
	p.owner_actor = a
	p.team = a.team
	p.shape = String(e["kind"])
	p.dmg = float(e["dmg"]) * a.dmg_mult() * (a.upgrade_mult(a.attack.move.id, "dmg") if a.attack.move != null else 1.0)
	p.stun = int(e["stun"])
	p.kb = e["kb"]
	p.kind = String(e.get("pkind", "normal"))
	p.life = float(e["life"])
	p.radius = float(e["radius"])
	p.col = a.figure.color if a.team == "player" else e["color"]  # player shots wear their owner's colour
	p.pierce = bool(e.get("pierce", false))
	p.ground = bool(e.get("ground", false))
	p.returns = float(e.get("returns", 0.0))
	p.ignite = float(e.get("ignite", 0.0))
	p.splash = float(e.get("splash", 0.0))
	p.height = String(e.get("height", "low" if p.ground else ("high" if p.shape == "bottle" else "mid")))
	var off: Vector2 = e["pos"]
	p.global_position = a.global_position + Vector2(off.x * a.facing, off.y)
	if bool(e.get("aim", false)):
		var tgt := a.nearest_target(1400.0)
		var t_pos := (tgt.global_position + Vector2(0, -50)) if tgt != null else a.global_position + Vector2(a.facing * 300.0, -40.0)
		var flight := clampf(absf(t_pos.x - p.global_position.x) / 420.0, 0.6, 1.2)
		p.gravity = 900.0
		p.vel = Vector2((t_pos.x - p.global_position.x) / flight, (t_pos.y - p.global_position.y - 0.5 * p.gravity * flight * flight) / flight)
	else:
		var v: Vector2 = e["vel"]
		p.vel = Vector2(v.x * a.facing, v.y)
		if p.shape == "bottle":
			p.gravity = 900.0
	p.add_to_group("projectiles")
	p.z_index = 20
	a.get_parent().add_child(p)
	if String(e.get("sfx", "shoot")) != "":
		Sfx.play(String(e.get("sfx", "shoot")))


func _physics_process(delta: float) -> void:
	_age += delta
	_spin += delta * 14.0
	if _age >= life:
		queue_free()
		return
	if returns > 0.0 and not _turned and _age >= returns:
		_turned = true
		_done.clear()
	if _turned and owner_actor != null and is_instance_valid(owner_actor):
		var to := (owner_actor.global_position + Vector2(0, -55)) - global_position
		vel = vel.move_toward(to.normalized() * 620.0, 2400.0 * delta)
		if to.length() < 24.0:
			queue_free()
			return
	vel.y += gravity * delta
	var old := global_position
	global_position += vel * delta
	if ground:
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -60), global_position + Vector2(0, 80), 3)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			global_position.y = (r["position"] as Vector2).y - radius * 0.6
	elif gravity > 0.0 or shape == "bottle":
		var space2 := get_world_2d().direct_space_state
		var q2 := PhysicsRayQueryParameters2D.create(old, global_position, 1)
		var r2 := space2.intersect_ray(q2)
		if not r2.is_empty():
			_shatter()
			return
	elif shape != "bottle":
		var space3 := get_world_2d().direct_space_state
		var q3 := PhysicsRayQueryParameters2D.create(old, global_position, 1)
		if not space3.intersect_ray(q3).is_empty():
			Fx.impact(get_parent(), global_position, col, 0.5)
			queue_free()
			return
	if shape == "mine":
		_mine_tick()
		queue_redraw()
		return
	for b in get_tree().get_nodes_in_group("barriers"):
		if team != b.team and b.get_rect().intersects(_rect()):
			Fx.sparks(get_parent(), global_position, col, 8)
			Sfx.play("block", 1.2)
			queue_free()
			return
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = ProjectileFx.trail(get_parent(), shape, global_position, vel.normalized() if vel.length() > 1.0 else Vector2(1, 0), radius, col)
	_check_reflect()
	_check_hits()
	queue_redraw()


## Pocket Mine: sits on the ground, arms after a short delay, blows up when an enemy steps near.
func _mine_tick() -> void:
	if _age < 0.45:
		return
	var group := "hurt_enemy" if team == "player" else "hurt_player"
	var trigger := Rect2(global_position.x - 50.0, global_position.y - 70.0, 100.0, 90.0)
	for t in get_tree().get_nodes_in_group(group):
		if t.is_targetable() and trigger.intersects(t.get_hurt_rect()):
			_explode(group)
			return


func _explode(group: String) -> void:
	var blast := Rect2(global_position.x - 110.0, global_position.y - 130.0, 220.0, 170.0)
	for t in get_tree().get_nodes_in_group(group):
		if not t.is_targetable() or not blast.intersects(t.get_hurt_rect()):
			continue
		var info := HitInfo.new()
		info.attacker = owner_actor
		info.team = team
		info.dmg = dmg
		info.stun = stun
		info.kind = "launch"
		var away := signf(t.global_position.x - global_position.x)
		info.kb = Vector2((away if away != 0.0 else 1.0) * absf(kb.x), kb.y)
		info.stop = 6
		info.source = "proj"
		info.ignite = ignite
		info.color = col
		info.pos = global_position
		info.shake = 0.3
		if t.take_hit(info) and is_instance_valid(owner_actor) and owner_actor is Actor and team == "player":
			owner_actor.on_hit_landed(info, t)
	Fx.ring(get_parent(), global_position, col, 130.0, 0.3)
	Fx.impact(get_parent(), global_position, col, 1.2)
	Sfx.play("boom")
	queue_free()


func _shatter() -> void:
	Fx.sparks(get_parent(), global_position, col, 10)
	Sfx.play("break", 1.4)
	queue_free()


func _rect() -> Rect2:
	return Rect2(global_position.x - radius, global_position.y - radius, radius * 2.0, radius * 2.0)


func _check_reflect() -> void:
	if reflected or team == "player":
		return
	for f in Coop.fighters:
		if f.reflect_t > 0 and f.is_targetable():
			var shield := Rect2(f.global_position.x + (f.facing * 30.0 - 40.0), f.global_position.y - 110.0, 80.0, 120.0)
			if shield.intersects(_rect()):
				reflect_by(f)
				return


## Send this projectile back at its owner team (shield reflect, or a melee swing connecting with it).
func reflect_by(f: Actor, power := 1.0) -> void:
	if reflected or team == "player":
		return
	team = "player"
	reflected = true
	owner_actor = f
	vel = Vector2(f.facing * absf(vel.x) * 1.4 + 60.0 * f.facing, -vel.y * 0.2)
	gravity = 0.0
	dmg *= 1.6 * power
	kb = Vector2(absf(kb.x) * f.facing, kb.y)
	col = f.figure.color
	pierce = true
	_done.clear()
	life = _age + 1.6
	Sfx.play("parry", 1.2)
	Fx.impact(get_parent(), global_position, col, 1.0)
	Coop.say("REFLECT!", col, global_position + Vector2(0, -40))


func _check_hits() -> void:
	var group := "hurt_enemy" if team == "player" else "hurt_player"
	var r := _rect()
	for t in get_tree().get_nodes_in_group(group):
		if _done.has(t.get_instance_id()) or not t.is_targetable():
			continue
		if r.intersects(t.get_hurt_rect()):
			_done[t.get_instance_id()] = true
			var info := HitInfo.new()
			info.attacker = owner_actor
			info.team = team
			info.dmg = dmg
			info.stun = stun
			info.kind = kind
			info.height = height
			info.kb = Vector2(kb.x * signf(vel.x if vel.x != 0.0 else 1.0), kb.y)
			info.stop = 3
			info.source = "proj"
			info.ignite = ignite
			info.color = col
			info.pos = global_position
			info.shake = 0.1
			if t.take_hit(info):
				if is_instance_valid(owner_actor) and owner_actor is Actor and team == "player":
					owner_actor.on_hit_landed(info, t)
				ProjectileFx.hit(get_parent(), shape, global_position, col, splash)
				if splash > 0.0:
					_splash_hit(t, group)
				if not pierce:
					queue_free()
					return


func _draw() -> void:
	match shape:
		"fireball":
			ProjectileFx.fireball(self, vel, radius, col, _age)
		"spark":
			ProjectileFx.spark(self, vel, radius, col, _age)
		"dart":
			ProjectileFx.dart(self, vel, radius, col)
		"blade":
			ProjectileFx.blade(self, radius, col, _spin)
		"quake":
			ProjectileFx.quake(self, vel, radius, col, _age)
		"mine":
			var armed := _age >= 0.45
			var blink := 0.5 + 0.5 * sin(_age * (10.0 if armed else 3.0))
			draw_rect(Rect2(-radius, -5, radius * 2.0, 8), Color(0.15, 0.1, 0.1))
			draw_rect(Rect2(-radius, -5, radius * 2.0, 8), col, false, 2.0)
			draw_circle(Vector2(0, -7), 4.0, Color(col.r, col.g, col.b, 0.3 + 0.7 * blink) if armed else Color(0.5, 0.5, 0.5))
		"crescent":
			# a thin curved blade of wind, pointed at both ends
			var ang := atan2(vel.y, vel.x)
			draw_set_transform(Vector2.ZERO, ang)
			draw_arc(Vector2(-radius * 0.6, 0), radius * 1.4, -0.95, 0.95, 14, Color(col.r, col.g, col.b, 0.25), 9.0, true)
			draw_arc(Vector2(-radius * 0.6, 0), radius * 1.4, -0.95, 0.95, 14, col, 4.0, true)
			draw_set_transform(Vector2.ZERO, 0.0)
		"disc":
			draw_circle(Vector2.ZERO, radius + 5.0, Color(col.r, col.g, col.b, 0.15))
			for i in 3:
				var a := _spin + i * TAU / 3.0
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * radius, col, 3.5, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, col, 3.0, true)
		"wave":
			var pts := PackedVector2Array([Vector2(-radius, 4), Vector2(0, -radius * 1.6), Vector2(radius, 4)])
			draw_polyline(pts, col, 4.0, true)
			draw_circle(Vector2(0, -4), radius * 0.6, Color(col.r, col.g, col.b, 0.35))
		"bottle":
			draw_set_transform(Vector2.ZERO, _spin)
			draw_rect(Rect2(-4, -9, 8, 18), col)
			draw_rect(Rect2(-2, -14, 4, 6), col)
			draw_set_transform(Vector2.ZERO, 0.0)
		_:
			draw_circle(Vector2.ZERO, radius + 7.0, Color(col.r, col.g, col.b, 0.15))
			draw_circle(Vector2.ZERO, radius, col)
			draw_circle(Vector2.ZERO, radius * 0.5, Color(2.5, 2.5, 2.5))


## Fireball blast: neighbours of the first victim take half damage and catch fire too.
func _splash_hit(first: Node, group: String) -> void:
	for n in get_tree().get_nodes_in_group(group):
		if n == first or _done.has(n.get_instance_id()) or not n.is_targetable():
			continue
		if n.global_position.distance_to(global_position) > splash:
			continue
		_done[n.get_instance_id()] = true
		var info := HitInfo.new()
		info.attacker = owner_actor
		info.team = team
		info.dmg = dmg * 0.5
		info.stun = stun
		info.kind = kind
		var away := signf(n.global_position.x - global_position.x)
		info.kb = Vector2(kb.x * (away if away != 0.0 else 1.0), kb.y)
		info.stop = 3
		info.source = "proj"
		info.ignite = ignite
		info.color = col
		info.pos = n.global_position
		n.take_hit(info)
