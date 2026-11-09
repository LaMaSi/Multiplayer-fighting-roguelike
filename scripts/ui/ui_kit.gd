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
const HEART := Color(1.0, 0.25, 0.48)
## One line weight for every outline and detail line in the world and the UI (selection states may be thicker).
const LINE := 3.0

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
## The badge on an attack card for a move that can be charged: only an icon, a simplified hourglass (two triangles meeting at
## their tips) in a small gold-edged tile. Drawn only for chargeable moves; `r` is the tile (about 28 px square).
static func charge_chip(c: CanvasItem, r: Rect2, m: MoveData) -> void:
	if m == null or not m.is_chargeable():
		return
	var gold := Color(2.0, 1.55, 0.35)
	c.draw_colored_polygon(chamfer(r, 5.0), Color(0.14, 0.09, 0.0, 0.94))
	poly_line(c, chamfer(r, 5.0), gold, 2.0)
	var ctr := r.get_center()
	var hw := r.size.x * 0.26
	var hh := r.size.y * 0.30
	c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x - hw, ctr.y - hh), Vector2(ctr.x + hw, ctr.y - hh), ctr]), gold)  # upper triangle, tip down
	c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x - hw, ctr.y + hh), Vector2(ctr.x + hw, ctr.y + hh), ctr]), gold)  # lower triangle, tip up


static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut), r.end, Vector2(r.position.x + cut, r.end.y), Vector2(r.position.x, r.end.y - cut)])


## Chamfered panel: dark fill plus a solid outline.
static func panel(c: CanvasItem, r: Rect2, cut: float, outline: Color, width := 3.0, fill_a := 0.85) -> void:
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


## Neon heart for shared lives: a bright filled heart with a soft halo; a lost life is a dark
## empty outline. r is roughly the half width.
static func heart(c: CanvasItem, pos: Vector2, r: float, on := true) -> void:
	var pts := PackedVector2Array()
	var k := r / 17.0
	for i in 40:
		var t := TAU * float(i) / 40.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(pos + Vector2(x, y + 1.0) * k)
	if on:
		for g in 3:
			var o := Geometry2D.offset_polygon(pts, (2.0 + g * 3.5) * maxf(k, 0.6))
			if o.size() > 0:
				c.draw_colored_polygon(o[0], Color(HEART.r, HEART.g, HEART.b, 0.16 - g * 0.04))
		c.draw_colored_polygon(pts, HEART)
		poly_line(c, pts, Color(1.0, 0.7, 0.8), 2.0)
	else:
		c.draw_colored_polygon(pts, Color(INK.r, INK.g, INK.b, 0.6))
		poly_line(c, pts, Color(HEART.r, HEART.g, HEART.b, 0.3), 2.0)


## Menu button: chamfered, glowing and thicker when selected, with a pink arrow. `value` is drawn at the
## right (with < > around it when arrows is true and the button is selected).
static func button(c: CanvasItem, r: Rect2, label: String, selected: bool, value := "", arrows := false) -> void:
	var col := TEXT if selected else Color(0.8, 0.8, 1.0, 0.45)
	var p := chamfer(r, 12.0)
	if selected:
		glow_poly(c, p, GLOW_PINK, 0.28)
	c.draw_colored_polygon(p, Color(0.12, 0.05, 0.2, 0.92) if selected else Color(INK.r, INK.g, INK.b, 0.8))
	poly_line(c, p, col, 4.0 if selected else LINE)
	if selected:
		var my := r.position.y + r.size.y * 0.5
		c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 26, my - 12), Vector2(r.position.x - 8, my), Vector2(r.position.x - 26, my + 12)]), PINK)
	txt(c, head(), r.position + Vector2(22, r.size.y * 0.5 + 8), label, 20 if selected else 18, TEXT if selected else Color(0.8, 0.8, 0.95))
	if value != "":
		var t := ("<  %s  >" % value) if (arrows and selected) else value
		txt(c, body(), r.position + Vector2(0, r.size.y * 0.5 + 7), t, 17, AMBER if selected else DIM_TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0)


static func check(c: CanvasItem, pos: Vector2, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([pos, pos + Vector2(5, 6), pos + Vector2(16, -7)]), col, 3.0, true)


## Italic (skewed) transform used by titles and the combo counter.
static func italic(pos: Vector2, tilt := 0.0, scale := 1.0, skew := -0.25) -> Transform2D:
	return Transform2D(Vector2(1, 0), Vector2(skew, 1), pos).rotated_local(tilt).scaled_local(Vector2(scale, scale))
