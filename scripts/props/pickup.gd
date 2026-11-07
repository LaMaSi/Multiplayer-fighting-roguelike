class_name Pickup
extends CharacterBody2D
## Health / power-up dropped by containers. Walk into it to collect.

const COLORS := {
	"hp_s": Color(2.0, 1.7, 1.9), "hp_m": Color(2.0, 1.7, 1.9), "dmg": Color(2.2, 0.8, 0.3),
	"speed": Color(1.7, 1.0, 2.2), "shield": Color(1.9, 1.9, 2.2), "meter": Color(2.0, 1.8, 0.5),
}
const GLYPH := {"hp_s": "+", "hp_m": "+", "dmg": "!", "speed": ">", "shield": "O", "meter": "*"}

var kind := "hp_s"
var life := 18.0
var _t := 0.0


static func spawn(parent: Node, pos: Vector2, k: String) -> Pickup:
	var p := Pickup.new()
	p.kind = k
	p.global_position = pos
	p.velocity = Vector2(randf_range(-120, 120), -420)
	parent.call_deferred("add_child", p)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	cs.shape = c
	cs.position = Vector2(0, -12)
	add_child(cs)
	z_index = 8
	add_to_group("pickups")


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		velocity.y = 50.0
	else:
		velocity.y = minf(velocity.y + 2000.0 * delta, 1500.0)
	move_and_slide()
	if is_on_floor() and velocity.y > 200.0:
		velocity.y = -velocity.y * 0.4
	if _t > 0.35:
		for f in Coop.fighters:
			if not f.is_alive() or f.state == "downed":
				continue
			if (kind == "hp_s" or kind == "hp_m") and f.hp >= f.max_hp:
				continue
			var d := f.global_position + Vector2(0, -40) - (global_position + Vector2(0, -12))
			if absf(d.x) < 38.0 and absf(d.y) < 56.0:
				f.apply_pickup(kind)
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	if life < 4.0 and int(life * 6.0) % 2 == 0:
		return
	var c: Color = COLORS[kind]
	var bob := sin(_t * 5.0) * 3.0
	var r := 13.0 if kind == "hp_m" else 10.0
	draw_circle(Vector2(0, -16 + bob), r + 6.0, Color(c.r, c.g, c.b, 0.15))
	draw_circle(Vector2(0, -16 + bob), r, Color(0.05, 0.03, 0.1))
	draw_arc(Vector2(0, -16 + bob), r, 0.0, TAU, 20, c, 3.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-5, -10 + bob), GLYPH[kind], HORIZONTAL_ALIGNMENT_CENTER, 10.0, 16, c)
