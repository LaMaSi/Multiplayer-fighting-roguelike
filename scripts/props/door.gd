class_name Door
extends Node2D
## A door inside a level that leads to a single-screen room. Shape and colour say what is inside:
##   challenge = red hexagon (tough enemies, bigger reward), shop = gold arch (buy a move / power-up pick).
## Stand next to it and press interact (RB) to go in together.

const W := 92.0
const H := 168.0
const DEPTH := 100.0  ## the door stands this far behind the walking line, in the floor's back part (drawn smaller and higher)

var kind := "challenge"
var level: LevelBase
var used := false
var _t := 0.0


func _ready() -> void:
	add_to_group("doors")
	z_index = -8  # behind the containers (-1), the shadows (-5) and the fighters


func is_near(f: Actor) -> bool:
	return absf(f.global_position.x - global_position.x) < 80.0 and absf(f.global_position.y - global_position.y) < 80.0


func nearest_fighter() -> Fighter:
	if level == null:
		return null
	for f in level.fighters:
		if f.is_alive() and f.state != "downed" and is_near(f):
			return f
	return null


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Input edges are per physics tick (Inp polls there), so the interact check lives in the physics step.
func _physics_process(_delta: float) -> void:
	if used or level == null or level.in_room or level._locked or level._cleared:
		return
	for f in level.fighters:
		if f.is_alive() and is_near(f) and f.input.pressed(PlayerInput.Btn.INTERACT):
			level.enter_room(self)
			return


func main_color() -> Color:
	return Color(1.0, 0.2, 0.25) if kind == "challenge" else Pal.interact()


func _draw() -> void:
	# placed in depth: base and scale follow the shared depth camera, so the door sits further back than the walking line
	var cam := get_viewport().get_camera_2d()
	var ctr := cam.get_screen_center_position() if cam != null else global_position
	var vp := Vector2(ctr.x, ctr.y - DepthLayer.RISE) - global_position
	var sc := DepthLayer.EYE / (DepthLayer.EYE + DEPTH)
	var base := DepthLayer.P(Vector2.ZERO, DEPTH, vp)
	# a soft shadow where it stands
	draw_colored_polygon(DepthLayer._ellipse(base, W * 0.62, 9.0), Color(0.0, 0.0, 0.03, 0.35))
	draw_set_transform(base, 0.0, Vector2(sc, sc))
	var col := main_color()
	if used:
		col = Color(col.r * 0.4, col.g * 0.4, col.b * 0.4)
	var pulse := 0.8 + 0.2 * sin(_t * 4.0)
	var body := PackedVector2Array()
	if kind == "challenge":
		# hexagon: cut top corners, wide shoulders
		body = PackedVector2Array([Vector2(-W * 0.5, -H * 0.18), Vector2(-W * 0.32, -H), Vector2(W * 0.32, -H), Vector2(W * 0.5, -H * 0.18), Vector2(W * 0.5, 0), Vector2(-W * 0.5, 0)])
	else:
		# arch: straight sides with a round top
		body.append(Vector2(-W * 0.5, 0))
		body.append(Vector2(-W * 0.5, -H * 0.62))
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			body.append(Vector2(cos(a) * W * 0.5, -H * 0.62 + sin(a) * (H * 0.38)))
		body.append(Vector2(W * 0.5, 0))
	draw_colored_polygon(body, Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 1.0))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(col.r * pulse, col.g * pulse, col.b * pulse), 4.0, true)
	var glyph := "!" if kind == "challenge" else "$"
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-W * 0.5, -H * 0.42), glyph, HORIZONTAL_ALIGNMENT_CENTER, W, 54, col)
	var label := "CHALLENGE" if kind == "challenge" else "MOVE SHOP"
	draw_string(f, Vector2(-70, -H - 10.0), label if not used else "USED", HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # the prompts stay at the walking line, in front
	if not used and nearest_fighter() != null:
		draw_string(f, Vector2(-70, 24.0), "RB: ENTER", HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, Color(1, 1, 1, 0.9))
		if kind == "shop" and not used and RunState.active and nearest_fighter() != null:
			draw_string(f, Vector2(-70, 48.0), "COINS: %d" % RunState.coins, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20, UiKit.AMBER)
