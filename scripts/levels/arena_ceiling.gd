class_name ArenaCeiling
extends Node2D
## The ceiling of a battle screen: a solid slab (layer 1) that drops in when the arena locks and lifts away when it is
## cleared. Jumps and launched bodies stop against it, so enemies bounce back down into the fight. Drawn in the shared depth
## camera (DepthLayer): you see its dark underside with light strips from below.

const THICK := 3500.0  ## it reaches up past the top of the screen: its upper side is never visible
const SLIDE := 520.0  ## how far above its place it waits

var x0 := 0.0
var x1 := 0.0
var bottom := 0.0  ## y of the underside
var neon := Color(2.0, 0.6, 1.3)
var _drop := 1.0  ## 1 = lifted away, 0 = in place
var _body: StaticBody2D
var _spikes: Array[SpikeTrap] = []  ## enemy-only spikes hanging from the underside, high above everyone's head


func setup(left: float, right: float, bottom_y: float, col: Color) -> void:
	x0 = left
	x1 = right
	bottom = bottom_y
	neon = col
	z_index = -2  # above the ground and the backdrop, behind fighters and props
	_body = StaticBody2D.new()
	_body.collision_layer = 0
	_body.set_collision_layer_value(1, true)
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(x1 - x0, 240.0)
	cs.shape = shape
	_body.add_child(cs)
	_body.position = Vector2((x0 + x1) * 0.5, bottom - 120.0 - SLIDE)
	add_child(_body)
	# spike clusters along the underside; the tips are at least half a screen above the ground (SpikeTrap.AIR_MIN_H)
	var n := maxi(2, int(round((x1 - x0) / 520.0)))
	for i in n:
		var st := SpikeTrap.new()
		st.ceiling = true
		st.w = 110.0
		st.enabled = false
		st.position = Vector2(x0 + (float(i) + 0.5) * (x1 - x0) / float(n), bottom + DepthLayer.PLAT_LIP - SLIDE)
		add_child(st)
		_spikes.append(st)


func appear() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_drop", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_body, "position:y", bottom - 120.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		Juice.shake(0.2)
		for st in _spikes:
			st.enabled = true)


func leave() -> void:
	for st in _spikes:
		st.enabled = false
	_body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_body.queue_free()
	var tw := create_tween()
	tw.tween_property(self, "_drop", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	for st in _spikes:
		st.position.y = bottom + DepthLayer.PLAT_LIP - _drop * SLIDE  # slides with the slab
	queue_redraw()


func _draw() -> void:
	var off := -_drop * SLIDE
	var slab := Rect2(x0, bottom - THICK + off, x1 - x0, THICK)
	var cam := get_viewport().get_camera_2d()
	var ctr := cam.get_screen_center_position() if cam != null else Vector2(x0, bottom)
	var vp := Vector2(ctr.x, ctr.y - DepthLayer.RISE) - global_position
	# the inside of the ceiling is a dark, near-black body like the night behind it (only the lit lower edge and the lamps glow)
	var f := DepthLayer.draw_platform(self, slab, neon, vp, false, 150.0, Color(0.035, 0.02, 0.07))
	# the lit lower edge and light strips along the underside
	draw_line(Vector2(f.position.x, f.end.y), Vector2(f.end.x, f.end.y), neon, 3.0, true)
	var yb := slab.end.y + DepthLayer.PLAT_LIP
	var lx := x0 - fmod(x0, 130.0) + 130.0
	while lx < x1:
		var a := DepthLayer.P(Vector2(lx - 18.0, yb), 40.0, vp)
		var b := DepthLayer.P(Vector2(lx + 18.0, yb), 40.0, vp)
		var c1 := DepthLayer.P(Vector2(lx - 18.0, yb), 110.0, vp)
		var c2 := DepthLayer.P(Vector2(lx + 18.0, yb), 110.0, vp)
		draw_line(a, b, Color(1.6, 1.5, 1.2, 0.8), 4.0, true)
		draw_line(c1, c2, Color(1.6, 1.5, 1.2, 0.5), 3.0, true)
		draw_line(a, c1, Color(neon.r, neon.g, neon.b, 0.18), 1.5)
		draw_line(b, c2, Color(neon.r, neon.g, neon.b, 0.18), 1.5)
		lx += 130.0
