class_name UiKit
## Shared look for every UI screen (HUD, level complete, shop): fonts, colour roles and small
## drawing helpers. Colours follow docs/STYLEGUIDE.md. UI colours stay at or below 1.0 (no glow)
## except the few things that are meant to glow (combo, rank letter, full super meter).

const P1 := Color(0.2, 0.9, 1.0)
const P2 := Color(0.55, 0.98, 0.2)
const PINK := Color(1.0, 0.4, 0.72)
const AMBER := Color(1.0, 0.72, 0.25)
const INK := Color(0.03, 0.02, 0.07)
const TEXT := Color(0.95, 0.95, 1.0)
const DIM_TEXT := Color(0.8, 0.8, 0.95)
const GLOW_PINK := Color(2.0, 0.7, 1.2)

static var _head: Font
static var _body: Font


static func player_color(i: int) -> Color:
	return P1 if i == 0 else P2


## Orbitron (headings, big numbers).
static func head() -> Font:
	if _head == null:
		var f: Font = load("res://assets/fonts/Orbitron.ttf")
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): 800}
		_head = fv
	return _head


## Rajdhani Bold (labels and body).
static func body() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/Rajdhani-Bold.ttf")
	return _body


static func txt(c: CanvasItem, f: Font, pos: Vector2, t: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, ocol := Color.BLACK) -> void:
	if outline > 0:
		c.draw_string_outline(f, pos, t, align, width, size, outline, ocol)
	c.draw_string(f, pos, t, align, width, size, col)


static func poly_line(c: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	c.draw_polyline(p, col, w, true)


## Rectangle with the top-right and bottom-left corners cut.
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut), r.end, Vector2(r.position.x + cut, r.end.y), Vector2(r.position.x, r.end.y - cut)])


## Chamfered panel: dark fill plus a solid outline.
static func panel(c: CanvasItem, r: Rect2, cut: float, outline: Color, width := 2.5, fill_a := 0.85) -> void:
	var p := chamfer(r, cut)
	c.draw_colored_polygon(p, Color(INK.r, INK.g, INK.b, fill_a))
	poly_line(c, p, outline, width)


static func glow_poly(c: CanvasItem, pts: PackedVector2Array, col: Color, alpha: float) -> void:
	for k in 3:
		var o := Geometry2D.offset_polygon(pts, 6.0 + k * 7.0)
		if o.size() > 0:
			c.draw_colored_polygon(o[0], Color(col.r, col.g, col.b, alpha * (0.6 - k * 0.15)))


static func coin(c: CanvasItem, pos: Vector2, r: float) -> void:
	c.draw_circle(pos, r, Color(0.05, 0.03, 0.02))
	c.draw_circle(pos, r - 2.0, AMBER)
	c.draw_arc(pos, r * 0.55, 0.0, TAU, 20, Color(0.45, 0.25, 0.05), 2.0, true)


## Little stickfigure head: shared lives / votes.
static func head_icon(c: CanvasItem, pos: Vector2, r: float, col: Color, on := true) -> void:
	if on:
		c.draw_arc(pos, r, 0.0, TAU, 20, col, 3.0, true)
		for s in [-1.0, 1.0]:
			c.draw_rect(Rect2(pos.x + s * r * 0.38 - r * 0.16, pos.y - r * 0.15, r * 0.32, r * 0.3), col)
	else:
		c.draw_arc(pos, r, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.25), 2.0, true)
		c.draw_line(pos + Vector2(-r * 0.4, -r * 0.4), pos + Vector2(r * 0.4, r * 0.4), Color(1, 0.3, 0.3, 0.5), 2.0)
		c.draw_line(pos + Vector2(r * 0.4, -r * 0.4), pos + Vector2(-r * 0.4, r * 0.4), Color(1, 0.3, 0.3, 0.5), 2.0)


static func check(c: CanvasItem, pos: Vector2, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([pos, pos + Vector2(5, 6), pos + Vector2(16, -7)]), col, 3.0, true)


## Italic (skewed) transform used by titles and the combo counter.
static func italic(pos: Vector2, tilt := 0.0, scale := 1.0, skew := -0.25) -> Transform2D:
	return Transform2D(Vector2(1, 0), Vector2(skew, 1), pos).rotated_local(tilt).scaled_local(Vector2(scale, scale))
