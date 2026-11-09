class_name WhipFx
extends Node2D
## A tether / whip from the character's hand: it cracks out to the move's full range (so you can see how far the Pull Hook
## reaches even when nothing is hit), holds a moment, and snaps back. When it hooks something the tip stays on the target
## and follows it while it is dragged in.

const EXTEND := 0.09
const HOLD := 0.10
const RETRACT := 0.13

var actor: Actor
var reach := 325.0  ## how far out the tip goes
var height := -73.0  ## tip height above the feet
var _t := 0.0
var _hooked: Node2D = null
var _hold_extra := 0.0


func _ready() -> void:
	top_level = true  # world coordinates
	z_index = 7


## The whip caught something: the tip sticks to it and follows it in.
func hook(target: Node2D) -> void:
	_hooked = target
	_hold_extra = 0.25


func _process(delta: float) -> void:
	_t += delta
	if actor == null or not is_instance_valid(actor) or _t > EXTEND + HOLD + _hold_extra + RETRACT:
		queue_free()
		return
	queue_redraw()


func _hand() -> Vector2:
	var h := actor.figure.to_global(actor.figure.hand_f_pos)
	if is_nan(h.x) or is_nan(h.y):
		h = actor.global_position + Vector2(float(actor.facing) * 28.0, -62.0)  # a broken pose must never break the tether
	return h


func _tip(ext: float) -> Vector2:
	var hand := _hand()
	if _hooked != null and is_instance_valid(_hooked):
		var tp := _hooked.global_position + Vector2(0.0, -60.0)
		return hand.lerp(tp, ext) if ext < 1.0 else tp
	var full := actor.global_position + Vector2(float(actor.facing) * reach, height)
	return hand.lerp(full, ext)


func _draw() -> void:
	if actor == null:
		return
	var ext := 0.0
	var snap := 0.0  # how much the whip is still whipping around (right after it is thrown)
	if _t < EXTEND:
		ext = ease(_t / EXTEND, 0.4)
		snap = 1.0 - ext
	elif _t < EXTEND + HOLD + _hold_extra:
		ext = 1.0
	else:
		ext = 1.0 - ease((_t - EXTEND - HOLD - _hold_extra) / RETRACT, 2.0)
	var hand := _hand()
	var tip := _tip(ext)
	var col: Color = actor.figure.color
	var dir := tip - hand
	if dir.length() < 2.0:
		return
	var perp := dir.orthogonal().normalized()
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var u := float(i) / float(n)
		var wave := sin(u * PI * 3.0 - _t * 60.0) * 30.0 * snap * sin(u * PI)  # the crack of the whip
		var sag := sin(u * PI) * 8.0 * (1.0 - ext) * 0.0
		pts.append(hand + dir * u + perp * (wave + sag))
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.22), 9.0, true)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.95), 3.0, true)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.55), 1.2, true)
	# the hook at the tip: a small ring, gold when it holds something
	var hooked := _hooked != null and is_instance_valid(_hooked)
	var hc := Color(2.2, 1.8, 0.4) if hooked else col
	draw_arc(tip, 7.0, 0.0, TAU, 14, hc, 3.0, true)
	draw_circle(tip, 3.0, Color(hc.r, hc.g, hc.b, 0.9))
