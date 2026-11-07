class_name MovePreview
extends RefCounted
## A small picture of a move mid-animation (the stick figure in the strike pose, the first hit area and any projectile),
## shown next to the move's description so players can tell moves apart. Rendered once per (move, class, player) in a
## hidden SubViewport and cached; the textures are used like any other texture in the UI draw code.

const SIZE := Vector2i(220, 150)
const ORIGIN := Vector2(78.0, 128.0)  # feet of the figure inside the picture
const ZOOM := 0.9

static var _cache: Dictionary = {}


class Overlay extends Node2D:
	var box := Rect2()
	var has_box := false

	func _draw() -> void:
		if has_box:
			draw_rect(box, Color(1.0, 0.8, 0.3, 0.14))
			draw_rect(box, Color(1.0, 0.8, 0.3, 0.75), false, 2.0)


class ProjNode extends Node2D:
	var kind := "orb"
	var col := Color(1, 1, 1)

	func _draw() -> void:
		var vel := Vector2(1, 0)
		match kind:
			"fireball":
				ProjectileFx.fireball(self, vel, 13.0, col, 0.3)
			"spark":
				ProjectileFx.spark(self, vel, 12.0, col, 0.3)
			"dart":
				ProjectileFx.dart(self, vel, 11.0, col)
			"blade":
				ProjectileFx.blade(self, 14.0, col, 0.6)
			"quake":
				ProjectileFx.quake(self, vel, 13.0, col, 0.3)
			_:
				draw_circle(Vector2.ZERO, 11.0, Color(col.r, col.g, col.b, 0.9))
				draw_circle(Vector2.ZERO, 5.0, Color(2.5, 2.5, 2.5))


static func texture(move_id: String, class_id: String, player: int) -> Texture2D:
	var key := "%s|%s|%d" % [move_id, class_id, player]
	if _cache.has(key):
		return _cache[key]
	var tex := _make(move_id, class_id, player)
	_cache[key] = tex
	return tex


## Draw the preview inside `r` (keeps the picture's aspect, centred). Does nothing when the move is unknown.
static func draw(c: CanvasItem, move_id: String, class_id: String, player: int, r: Rect2) -> void:
	if move_id == "":
		return
	var tex := texture(move_id, class_id, player)
	if tex == null:
		return
	var aspect := float(SIZE.x) / float(SIZE.y)
	var w := minf(r.size.x, r.size.y * aspect)
	var h := w / aspect
	var dst := Rect2(r.position + (r.size - Vector2(w, h)) * 0.5, Vector2(w, h))
	c.draw_rect(dst, Color(1, 1, 1, 0.05))
	c.draw_texture_rect(tex, dst, false)


## The pose of the move at `frame`: linear blend between the surrounding keyframes.
static func pose_at(m: MoveData, frame: int) -> Dictionary:
	if m.kf.is_empty():
		return PoseLib.idle(0.0)
	var prev: Array = m.kf[0]
	var nxt: Array = m.kf[m.kf.size() - 1]
	for i in m.kf.size():
		var k: Array = m.kf[i]
		if int(k[0]) <= frame:
			prev = k
		else:
			nxt = k
			break
	var span := float(int(nxt[0]) - int(prev[0]))
	var t := 0.0 if span <= 0.0 else clampf(float(frame - int(prev[0])) / span, 0.0, 1.0)
	var a: Dictionary = StickFigure.NEUTRAL.merged(prev[1], true)
	var b: Dictionary = StickFigure.NEUTRAL.merged(nxt[1], true)
	var out := {}
	for key in a:
		out[key] = lerpf(float(a[key]), float(b.get(key, a[key])), t)
	return out


## The frame that shows the move best: the middle of the first hit, else the first projectile, else a bit into the move.
static func key_frame(m: MoveData) -> int:
	if not m.hits.is_empty():
		var h: Dictionary = m.hits[0]
		return int(h["at"]) + mini(2, int(h["dur"]) - 1)
	for e in m.events:
		if String(e.get("type", "")) == "proj":
			return int(e["at"]) + 2
	return int(float(m.total) * 0.35)


static func _make(move_id: String, class_id: String, player: int) -> Texture2D:
	var m: MoveData = MoveDB.get_move_for(move_id, class_id) if class_id != "" else MoveDB.get_move(move_id)
	if m == null:
		return null
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var col: Color = Fighter.PLAYER_COLORS[player % Fighter.PLAYER_COLORS.size()]
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := Node2D.new()
	holder.position = ORIGIN
	holder.scale = Vector2(ZOOM, ZOOM)
	vp.add_child(holder)
	var frame := key_frame(m)
	# overlay first (behind the figure): the first hit area and projectiles
	var ov := Overlay.new()
	if not m.hits.is_empty():
		var hb: Rect2 = (m.hits[0] as Dictionary)["box"]
		ov.box = hb
		ov.has_box = true
	holder.add_child(ov)
	var n_proj := 0
	for e in m.events:
		if String(e.get("type", "")) == "proj" and n_proj < 3:
			var pn := ProjNode.new()
			pn.kind = String(e.get("kind", "orb"))
			pn.col = col
			pn.position = e.get("pos", Vector2(40, -60))
			holder.add_child(pn)
			n_proj += 1
	var fig := StickFigure.new()
	fig.color = col
	fig.arm_scale = 1.22
	fig.leg_scale = 1.2
	fig.eyes = true
	if class_id != "":
		fig.weapon = String(ClassData.get_class_data(class_id)["weapon"])
	fig.set_target(pose_at(m, frame), true)
	fig.process_mode = Node.PROCESS_MODE_DISABLED  # the pose is frozen; only the first draw matters
	holder.add_child(fig)
	root.add_child(vp)
	# render a few frames, then stop updating (the last image stays)
	(loop as SceneTree).create_timer(0.5, true).timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()
