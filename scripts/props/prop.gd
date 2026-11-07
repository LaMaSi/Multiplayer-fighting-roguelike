class_name Prop
extends CharacterBody2D
## Destructible container (crate / barrel / vase). Can be smashed, launched by hits,
## picked up (RT) and thrown. Drops pickups when broken; more combo = better drops.

const GRAVITY := 2300.0
## The one colour used only for things you can interact with (containers, pickups, the exit).
const RIM := Color(2.0, 1.75, 0.25)

var kind := "crate"  ## crate, barrel, vase
var hp := 24.0
var state := "idle"  ## idle, held, flying, dead
var thrown_by: Actor = null
var guaranteed := ""  ## force a specific drop
var col := Pal.interact()
var w := 46.0
var h := 46.0

var _wobble := 0.0
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
	z_index = 5


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
	Sfx.play("hit", 0.8)
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
				info.dmg = 14.0
				info.kind = "launch"
				info.kb = Vector2(signf(vx if vx != 0.0 else 1.0) * 380.0, -420.0)
				info.stun = 28
				info.stop = 6
				info.source = "prop"
				info.shake = 0.3
				info.pos = get_hurt_rect().get_center()
				if t.take_hit(info):
					_break(thrown_by)
					return
		if is_on_wall():
			_break(thrown_by)
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
	_drop(parent, pos)
	queue_free()


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
	match kind:
		"vase":
			# a vase-shaped silhouette with a transparent surround (no filled rectangle behind it)
			var pts := PackedVector2Array([
				Vector2(-w * 0.3, -h * 0.5), Vector2(-w * 0.45, 0.0), Vector2(-w * 0.42, h * 0.3), Vector2(-w * 0.28, h * 0.5),
				Vector2(w * 0.28, h * 0.5), Vector2(w * 0.42, h * 0.3), Vector2(w * 0.45, 0.0), Vector2(w * 0.3, -h * 0.5)])
			draw_colored_polygon(pts, Color(0.06, 0.03, 0.1))
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, rim, 6.0, true)
			draw_polyline(closed, col, 3.0, true)
		"barrel":
			draw_rect(r, Color(0.06, 0.03, 0.1))
			draw_rect(r.grow(3.0), rim, false, 3.0)
			draw_rect(r, col, false, 3.0)
			draw_line(Vector2(-w * 0.5, -h * 0.2), Vector2(w * 0.5, -h * 0.2), col, 2.0)
			draw_line(Vector2(-w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.2), col, 2.0)
		_:
			draw_rect(r, Color(0.06, 0.03, 0.1))
			draw_rect(r.grow(3.0), rim, false, 3.0)
			draw_rect(r, col, false, 3.0)
			draw_line(r.position, r.end, Color(col.r, col.g, col.b, 0.7), 2.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(col.r, col.g, col.b, 0.7), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)
