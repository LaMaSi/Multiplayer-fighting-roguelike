class_name LaunchTrail
extends Node2D
## A subtle ribbon behind an enemy that is flying: in the colour of the player who sent it flying, or red when an enemy,
## a hazard or an explosion did. It lives in the level (world space) so it can fade out after the body has landed or died.

const LIFE := 0.5  ## seconds a trail point stays
const MAX_POINTS := 28

var col := Color(1.7, 0.3, 0.22)
var owner_actor: Node = null
var _pts: Array = []  # {p: Vector2, t: float}


func _ready() -> void:
	top_level = true  # draw in world coordinates whatever the parent does
	z_index = -1


func push(p: Vector2) -> void:
	if not _pts.is_empty() and (_pts[_pts.size() - 1]["p"] as Vector2).distance_to(p) < 5.0:
		return
	_pts.append({"p": p, "t": 0.0})
	if _pts.size() > MAX_POINTS:
		_pts.pop_front()


func _process(delta: float) -> void:
	for d: Dictionary in _pts:
		d["t"] = float(d["t"]) + delta
	while not _pts.is_empty() and float((_pts[0] as Dictionary)["t"]) > LIFE:
		_pts.pop_front()
	if _pts.is_empty() and (owner_actor == null or not is_instance_valid(owner_actor)):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in range(1, _pts.size()):
		var a: Dictionary = _pts[i - 1]
		var b: Dictionary = _pts[i]
		var k := 1.0 - clampf(float(b["t"]) / LIFE, 0.0, 1.0)  # 1 = fresh, 0 = gone
		var width := 2.0 + 9.0 * k
		draw_line(a["p"], b["p"], Color(col.r, col.g, col.b, 0.10 * k), width * 2.4, true)
		draw_line(a["p"], b["p"], Color(col.r, col.g, col.b, 0.34 * k), width, true)
