class_name Prop
extends CharacterBody2D
## Destructible container (crate / barrel / vase). Can be smashed, launched by hits,
## picked up (RT) and thrown. Drops pickups when broken; more combo = better drops.

const GRAVITY := 2300.0
## The one colour used only for things you can interact with (containers, pickups, the exit).
const RIM := Color(2.0, 1.75, 0.25)

var kind := "crate"  ## crate, barrel, vase, explosive
var hp := 24.0
var burn_t := 0.0  ## burning crates burn down (and a burning TNT crate goes off), spread to neighbours and ignite what they hit
var shock_t := 0.0
var frost_t := 0.0
var frozen_t := 0.0
var body_scale := 1.0
var body_h := 46.0  ## (read by StatusFx)
var _status_fx: StatusFx = null
var state := "idle"  ## idle, held, flying, dead
var thrown_by: Actor = null
var guaranteed := ""  ## force a specific drop
var col := Pal.interact()
var w := 46.0
var h := 46.0

var _top: StaticBody2D = null  ## one-way platform on top of the container: players and enemies can stand on it
var _top_cs: CollisionShape2D = null
var _wobble := 0.0
var _squash := 0.0
var _spring_cd: Dictionary = {}
var _hit_set: Dictionary = {}
var _bounces := 0
var _wob_dir := 1.0


func setup(k: String) -> Prop:
	kind = k
	match k:
		"barrel":
			hp = 34.0
			col = Pal.interact()
			w = 40.0
			h = 54.0
		"spring":
			hp = 99999.0
			w = 44.0
			h = 30.0
			col = Pal.interact()
		"explosive":
			hp = 20.0
			col = Color(1.5, 0.35, 0.12)
		"vase":
			hp = 12.0
			col = Pal.interact()
			w = 34.0
			h = 50.0
		_:
			hp = 24.0
			col = Pal.interact()
	return self


func _ready() -> void:
	add_to_group("props")
	if kind != "spring":
		Coop.stat_containers_total += 1
	add_to_group("hurt_enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	cs.position = Vector2(0, -h * 0.5)
	add_child(cs)
	z_index = -1  # drawn behind fighters (so one standing on top is not covered); held and thrown ones go in front
	_make_top()


## A thin one-way platform on the top face. Only layer 2 (the platform layer), so it is landed on from above and ignored
## from the sides and below, exactly like the level's platforms. Off while the container is held, flying or dead.
func _make_top() -> void:
	if kind == "spring" or kind == "vase":
		return
	_top = StaticBody2D.new()
	_top.collision_layer = 0
	_top.set_collision_layer_value(2, true)
	_top.collision_mask = 0
	_top_cs = CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, 10.0)
	_top_cs.shape = sh
	_top_cs.position = Vector2(0, -h + 5.0)
	_top_cs.one_way_collision = true
	_top_cs.one_way_collision_margin = 6.0
	_top.add_child(_top_cs)
	add_child(_top)
	add_collision_exception_with(_top)


func _sync_top() -> void:
	if _top == null:
		return
	var solid := state == "idle"
	if _top_cs.disabled == solid:
		_top_cs.set_deferred("disabled", not solid)
	_top.set_meta("bottom_y", global_position.y)  # a player dropping through (down) is clear once below this
	z_index = 5 if (state == "held" or state == "flying") else -1


func is_targetable() -> bool:
	return state == "idle" or state == "flying"


func get_hurt_rect() -> Rect2:
	# generous: head-height punches must reach low containers
	return Rect2(global_position.x - w * 0.5 - 4.0, global_position.y - h - 34.0, w + 8.0, h + 34.0)


func can_be_grabbed() -> bool:
	return state == "idle"


func grab(_by: Node) -> void:
	state = "held"
	velocity = Vector2.ZERO
	rotation = 0.0


func release() -> void:
	if state == "held":
		state = "idle"
		velocity = Vector2(0, 0)


func thrown(vel: Vector2, by: Actor) -> void:
	state = "flying"
	velocity = vel
	thrown_by = by
	_hit_set.clear()
	_bounces = 0


func take_hit(info: HitInfo) -> bool:
	if not is_targetable():
		return false
	hp -= info.dmg
	_wobble = 0.25
	_wob_dir = signf(info.kb.x) if info.kb.x != 0.0 else 1.0
	Fx.impact(get_parent(), info.pos, col, 0.7, info.kb)
	Sfx.impact(info.dmg)
	if info.ignite > 0.0:
		_ignite(info.ignite * 1.6, info.color)
	if info.kind == "spike" or hp <= 0.0:
		_break(info.attacker as Actor)
		return true
	var power := info.kb.length() * info.prop_power
	if power > 320.0 or info.kind == "launch":
		state = "flying"
		thrown_by = info.attacker as Actor
		_hit_set.clear()
		_bounces = 0
		velocity = Vector2(info.kb.x * info.prop_power * 0.9, minf(info.kb.y * 0.5, -220.0))
	if info.attacker is Actor:
		(info.attacker as Actor).freeze = maxi((info.attacker as Actor).freeze, 2)
	return true


func _physics_process(delta: float) -> void:
	_wobble = maxf(0.0, _wobble - delta)
	_sync_top()
	if kind == "spring" and state == "idle":
		_spring_tick(delta)
	if burn_t > 0.0 and state != "dead":
		burn_t = maxf(0.0, burn_t - delta)
		hp -= 7.0 * delta
		if hp <= 0.0:
			_break(thrown_by)
			return
		if randf() < delta * 2.5:
			for o in get_tree().get_nodes_in_group("props"):
				if o != self and o is Prop and (o as Prop).state != "dead" and (o as Prop).burn_t <= 0.0 and o.global_position.distance_to(global_position) < 90.0:
					(o as Prop)._ignite(2.5, col)
					break
	if state == "held":
		return
	if state == "dead":
		return
	if state == "flying" or not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1700.0)
	else:
		velocity.y = 50.0
	if state == "idle":
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	var vx := velocity.x
	move_and_slide()
	if state == "flying":
		rotation += signf(velocity.x if velocity.x != 0.0 else 1.0) * 9.0 * delta
		for t in get_tree().get_nodes_in_group("hurt_enemy"):
			if t == self or _hit_set.has(t.get_instance_id()) or not (t is Actor) or not t.is_targetable():
				continue
			if get_hurt_rect().intersects(t.get_hurt_rect()):
				_hit_set[t.get_instance_id()] = true
				var info := HitInfo.new()
				info.attacker = thrown_by
				info.team = "player"
				info.dmg = 18.0
				if burn_t > 0.0:
					info.ignite = 2.5
					info.color = col
				info.kind = "launch"
				info.kb = Vector2(signf(vx if vx != 0.0 else 1.0) * 380.0, -420.0)
				info.stun = 28
				info.stop = 6
				info.source = "prop"
				info.shake = 0.3
				info.pos = get_hurt_rect().get_center()
				if t.take_hit(info):
					if kind == "spring":
						velocity.x *= -0.25
						continue
					_break(thrown_by)
					return
		if is_on_wall():
			if kind == "spring":
				velocity.x *= -0.3
			else:
				_break(thrown_by)
				return
		if is_on_floor() and kind == "spring":
			# a thrown spring lands and stays: it is now a spring pad
			state = "idle"
			velocity = Vector2.ZERO
			rotation = 0.0
			_squash = 1.0
			Sfx.play("land", 1.2)
			Fx.dust(get_parent(), global_position, 6)
			return
		if is_on_floor():
			_bounces += 1
			if _bounces >= 2 or absf(velocity.x) < 80.0:
				_break(thrown_by)
				return
			velocity.y = -260.0
	if global_position.y > 2200.0:
		queue_free()


func _break(by: Actor) -> void:
	if state == "dead":
		return
	state = "dead"
	Coop.stat_containers += 1
	var parent := get_parent()
	var pos := global_position + Vector2(0, -h * 0.5)
	Fx.shatter(parent, pos, col, 18)
	Fx.ring(parent, pos, col, 60.0, 0.25)
	Sfx.play("break")
	Juice.shake(0.15)
	if kind == "explosive":
		_explode(by, pos)
	else:
		_drop(parent, pos)
	queue_free()


## Explosive crate: a big blast that launches enemies (and hurts the players a little), and sets off nearby crates.
const BLAST_RADIUS := 175.0


func _explode(by: Actor, pos: Vector2) -> void:
	var parent := get_parent()
	Fx.ring(parent, pos, Color(2.2, 1.0, 0.3), BLAST_RADIUS, 0.45)
	Fx.ring(parent, pos, Color(2.2, 0.4, 0.15), BLAST_RADIUS * 0.6, 0.3)
	Fx.shatter(parent, pos, Color(2.2, 0.9, 0.2), 34)
	Fx.dust(parent, pos, 16, Color(1.4, 0.8, 0.3, 0.8))
	Sfx.play("boom", 0.7)
	Juice.shake(0.7)
	Juice.zoom_punch(0.08)
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Actor):
			continue
		var a := n as Actor
		if not a.is_targetable() or a.get_hurt_rect().get_center().distance_to(pos) > BLAST_RADIUS + 30.0:
			continue
		var info := HitInfo.new()
		info.attacker = by
		info.team = "player"
		info.source = "prop"
		info.kind = "launch"
		info.stun = 30
		info.stop = 7
		info.shake = 0.4
		info.color = Color(2.2, 0.9, 0.2)
		info.pos = pos
		var away := signf(a.global_position.x - pos.x)
		if away == 0.0:
			away = 1.0
		info.kb = Vector2(away * 520.0, -560.0)
		if a.team == "enemy":
			info.dmg = 38.0
		else:
			info.dmg = 14.0
			info.friendly = true
		a.take_hit(info)
	for n in get_tree().get_nodes_in_group("props"):
		if n != self and is_instance_valid(n) and n is Prop and (n as Prop).state != "dead" and n.global_position.distance_to(global_position) < BLAST_RADIUS:
			var pi := HitInfo.new()
			pi.attacker = by
			pi.dmg = 99.0
			pi.kind = "spike"
			pi.pos = n.global_position
			pi.kb = Vector2(0, 0)
			(n as Prop).take_hit(pi)


func _drop(parent: Node, pos: Vector2) -> void:
	var kinds: Array[String] = []
	if guaranteed != "":
		kinds.append(guaranteed)
	else:
		var chance := 0.55 + 0.012 * minf(Coop.combo, 30)
		if kind == "barrel":
			chance += 0.15
		if randf() < chance:
			var table := [["hp_s", 35], ["hp_m", 8], ["dmg", 12], ["speed", 12], ["shield", 10], ["meter", 15]]
			var total := 0
			for e in table:
				total += int(e[1])
			var roll := randi() % total
			for e in table:
				roll -= int(e[1])
				if roll < 0:
					kinds.append(String(e[0]))
					break
	for k in kinds:
		Pickup.spawn(parent, pos, k)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var wob := sin(_wobble * 50.0) * 0.12 * _wob_dir if _wobble > 0.0 else 0.0
	draw_set_transform(Vector2(0, -h * 0.5), wob)
	var r := Rect2(-w * 0.5, -h * 0.5, w, h)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0 + global_position.x * 0.01)
	var rim := Color(RIM.r, RIM.g, RIM.b, 0.35 + 0.25 * pulse)
	# the vanishing point of the depth camera, in this drawing space (the node may be rotated while it flies)
	var vp := to_local(DepthLayer.vanish_point(self, global_position)) + Vector2(0, h * 0.5)
	match kind:
		"vase":
			# a vase-shaped silhouette with a transparent surround (no filled rectangle behind it)
			var pts := PackedVector2Array([
				Vector2(-w * 0.3, -h * 0.5), Vector2(-w * 0.45, 0.0), Vector2(-w * 0.42, h * 0.3), Vector2(-w * 0.28, h * 0.5),
				Vector2(w * 0.28, h * 0.5), Vector2(w * 0.42, h * 0.3), Vector2(w * 0.45, 0.0), Vector2(w * 0.3, -h * 0.5)])
			draw_colored_polygon(pts, Color(0.06, 0.03, 0.1))
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, rim, UiKit.LINE * 2.0, true)
			draw_polyline(closed, col, UiKit.LINE, true)
		"explosive":
			var fuse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
			var fr := _draw_box(r, vp, Pal.interact(), rim, Color(0.22, 0.04, 0.03))  # yellow edges like every container, red body
			var fw := fr.size.x
			var fh := fr.size.y
			for k in [-1, 1]:
				draw_line(Vector2(fr.position.x, fr.get_center().y + k * fh * 0.36), Vector2(fr.end.x, fr.get_center().y + k * fh * 0.36), Color(col.r, col.g, col.b, 0.8), 4.0)
			draw_rect(Rect2(fr.get_center().x - fw * 0.34, fr.get_center().y - fh * 0.2, fw * 0.68, fh * 0.4), Color(0.06, 0.02, 0.02))
			draw_string(ThemeDB.fallback_font, Vector2(fr.position.x, fr.get_center().y + fh * 0.1), "TNT", HORIZONTAL_ALIGNMENT_CENTER, fw, 16, Color(2.0, 1.2, 0.4))
			draw_circle(Vector2(fr.get_center().x, fr.position.y - 5.0), 3.5 + 1.5 * fuse, Color(2.2, 1.3, 0.3))
		"spring":
			var sq := 1.0 - 0.45 * _squash
			var top := h * 0.5 - (h - 8.0) * sq
			draw_rect(Rect2(-w * 0.5, h * 0.5 - 6.0, w, 6.0), Color(0.06, 0.03, 0.1))
			draw_rect(Rect2(-w * 0.5, h * 0.5 - 6.0, w, 6.0), col, false, 2.5)
			var zig := PackedVector2Array()
			for i in 7:
				zig.append(Vector2((-w * 0.32) if i % 2 == 0 else (w * 0.32), lerpf(h * 0.5 - 6.0, top + 6.0, float(i) / 6.0)))
			draw_polyline(zig, col, 3.0, true)
			draw_rect(Rect2(-w * 0.5, top, w, 6.0), Color(0.06, 0.03, 0.1))
			draw_rect(Rect2(-w * 0.5, top, w, 6.0), rim, false, 3.0)
			draw_rect(Rect2(-w * 0.5, top, w, 6.0), col, false, 2.5)
		"barrel":
			_draw_barrel(r, vp, rim)
		_:
			var fr2 := _draw_box(r, vp, col, rim, Color(0.06, 0.03, 0.1))
			draw_line(fr2.position, fr2.end, col, UiKit.LINE)
			draw_line(Vector2(fr2.end.x, fr2.position.y), Vector2(fr2.position.x, fr2.end.y), col, UiKit.LINE)
	draw_set_transform(Vector2.ZERO, 0.0)


## A container as a real box in the shared depth camera (see DepthLayer): the visible top, the side that faces the camera
## and the front face. Returns the front face rectangle for decorations.
func _draw_box(r: Rect2, vp: Vector2, c: Color, rim: Color, fill: Color) -> Rect2:
	var d := w * 0.85  # depth of the box
	var b := DepthLayer.box(r, -6.0, d, vp)
	var side := Color(fill.r * 0.5, fill.g * 0.5, fill.b * 0.5)
	var lit := Color(c.r * 0.22, c.g * 0.22, c.b * 0.22)
	if vp.x < r.position.x:
		draw_colored_polygon(PackedVector2Array([b["f_tl"], b["b_tl"], b["b_bl"], b["f_bl"]]), side)
		draw_polyline(PackedVector2Array([b["f_bl"], b["f_tl"], b["b_tl"], b["b_bl"]]), Color(c.r, c.g, c.b, 0.6), 2.0, true)
	elif vp.x > r.end.x:
		draw_colored_polygon(PackedVector2Array([b["f_tr"], b["b_tr"], b["b_br"], b["f_br"]]), side)
		draw_polyline(PackedVector2Array([b["f_br"], b["f_tr"], b["b_tr"], b["b_br"]]), Color(c.r, c.g, c.b, 0.6), 2.0, true)
	if vp.y < r.position.y:
		var top := PackedVector2Array([b["b_tl"], b["b_tr"], b["f_tr"], b["f_tl"]])
		draw_colored_polygon(top, lit)
		var closed := top.duplicate()
		closed.append(top[0])
		draw_polyline(closed, Color(c.r, c.g, c.b, 0.85), 2.0, true)
	var fr := Rect2(b["f_tl"], b["f_br"] - b["f_tl"])
	draw_rect(fr, fill)
	draw_rect(fr.grow(3.0), rim, false, 3.0)
	draw_rect(fr, c, false, 3.0)
	return fr


## A barrel as a real cylinder in the depth camera: the hoops and the lower edge are arcs that follow the perspective,
## and the elliptical top is visible when the horizon is above it.
func _draw_barrel(r: Rect2, vp: Vector2, rim: Color) -> void:
	var rad := w * 0.5
	var zc := 14.0  # axis depth: the front of the barrel is at zc - rad
	var top_y := r.position.y
	var bot_y := r.end.y
	var upper := _circ(top_y, -PI * 0.5, PI * 0.5, 14, rad, zc, vp)
	var lower := _circ(bot_y, -PI * 0.5, PI * 0.5, 14, rad, zc, vp)
	var body := PackedVector2Array()
	body.append_array(upper)
	var lower_rev := lower.duplicate()
	lower_rev.reverse()
	body.append_array(lower_rev)
	# filled as a strip of quads (draw_colored_polygon failed to triangulate the curved outline)
	var fill_c := PackedColorArray([Color(0.06, 0.03, 0.1), Color(0.06, 0.03, 0.1), Color(0.06, 0.03, 0.1), Color(0.06, 0.03, 0.1)])
	for i in upper.size() - 1:
		draw_primitive(PackedVector2Array([upper[i], upper[i + 1], lower[i + 1], lower[i]]), fill_c, PackedVector2Array())
	# hoops follow the curved surface
	for f in [0.3, 0.7]:
		draw_polyline(_circ(lerpf(top_y, bot_y, f), -PI * 0.5, PI * 0.5, 14, rad, zc, vp), col, UiKit.LINE, true)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, rim, UiKit.LINE * 2.0, true)
	draw_polyline(outline, col, UiKit.LINE, true)
	if vp.y < top_y:
		var ell := _circ(top_y, -PI, PI, 28, rad, zc, vp)
		var tc := Color(col.r * 0.22, col.g * 0.22, col.b * 0.22)
		var ctr := (ell[0] + ell[ell.size() / 2]) * 0.5
		for i in ell.size() - 1:
			draw_primitive(PackedVector2Array([ctr, ell[i], ell[i + 1]]), PackedColorArray([tc, tc, tc]), PackedVector2Array())
		var closed := ell.duplicate()
		closed.append(ell[0])
		draw_polyline(closed, Color(col.r, col.g, col.b, 0.9), 2.0, true)


## Points of a horizontal circle (radius `rad`, axis at depth `zc`) at height `y`, from angle a0 to a1, projected into
## the depth camera. Angle 0 is the point nearest the camera: the visible front half is -PI/2 to PI/2.
func _circ(y: float, a0: float, a1: float, n: int, rad: float, zc: float, vp: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(DepthLayer.P(Vector2(rad * sin(a), y), zc - rad * cos(a), vp))
	return pts


## Set the crate on fire: flames in the igniter's colour, it burns down, spreads to neighbours and ignites what it hits.
func _ignite(secs: float, c: Color) -> void:
	if state == "dead":
		return
	burn_t = maxf(burn_t, maxf(secs, 6.0))  # a crate that catches fire burns until it is gone
	if _status_fx != null and is_instance_valid(_status_fx):
		_status_fx.col = c
		return
	_status_fx = StatusFx.new()
	_status_fx.actor = self
	_status_fx.col = c
	add_child(_status_fx)


## A deployed spring pad: whoever lands on or walks over it is launched high; players are flung in a fast jump they can
## act out of, enemies are launched (the combo carries on).
func _spring_tick(delta: float) -> void:
	_squash = maxf(0.0, _squash - delta * 5.0)
	for k in _spring_cd.keys():
		_spring_cd[k] = float(_spring_cd[k]) - delta
		if float(_spring_cd[k]) <= 0.0:
			_spring_cd.erase(k)
	var top := Rect2(global_position.x - w * 0.5, global_position.y - h - 10.0, w, 26.0)
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Actor):
			continue
		var a := n as Actor
		if not a.is_alive() or a.state == "dead" or a.state == "downed" or a.state == "grabbed" or _spring_cd.has(a.get_instance_id()):
			continue
		if a.team == "enemy" and (a._pinball_t > 0.0 or a._pinball_emit_t > 0.0):
			continue  # an enemy mid pinball chain is not launched again: no spring pinball loops
		var feet := Rect2(a.global_position.x - 12.0, a.global_position.y - 8.0, 24.0, 12.0)
		if top.intersects(feet) and a.velocity.y > 40.0 or (top.intersects(feet) and a.is_on_floor()):
			_spring_cd[a.get_instance_id()] = 3.0  # long enough to fly away; no bounce loops
			_squash = 1.0
			var sx := a.velocity.x * 0.8
			if absf(sx) < 240.0:
				sx = (signf(sx) if sx != 0.0 else float(a.facing)) * 300.0  # always carried sideways so it lands beside the spring
			var v := Vector2(sx, -1250.0)
			var by: Actor = a
			if a.team == "enemy" and a.last_hitter != null and is_instance_valid(a.last_hitter):
				by = a.last_hitter
			a.thrown(v, by)
			Fx.ring(get_parent(), global_position + Vector2(0, -h), col, 70.0, 0.25)
			Fx.dust(get_parent(), global_position, 8)
			Sfx.play("jump", 0.8)
			if a.team == "enemy":
				Coop.bonus_hit(a.last_hitter as Actor, a, 0.0)
