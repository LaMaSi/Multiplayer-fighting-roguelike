class_name LoadoutView
extends RefCounted
## Loadout screen logic and drawing, shared by the pause menu and the run map. Both players edit
## their own 3x4 grid (rows X / Y / B, columns neutral / up / side / down) at the same time:
## stick moves the cursor, A lifts a move, A on another slot drops it (the two moves swap), B cancels.
## Slot rules follow the classes: X = universal moves, Y = adaptive moves, B = the player's own
## weapon moves, so a move can only be dropped on a slot of its own kind. Upgrades belong to the
## move, so they travel with it.
##
## The owner supplies four callables so the same view works in a level (fighters) and on the map
## (RunState): get_loadout(p) -> live Dictionary, set_slot(p, slot, id), get_class(p) -> String,
## get_upgrades(p) -> Dictionary.

const SLOTS: Array = ["X", "X_UP", "X_SIDE", "X_DOWN", "Y", "Y_UP", "Y_SIDE", "Y_DOWN", "B", "B_UP", "B_SIDE", "B_DOWN"]
const COLS := ["NEUTRAL", "UP", "SIDE", "DOWN"]
const ROWS := ["X", "Y", "B"]
const TIER_LABEL := {"universal": "OFF-HAND", "adaptive": "ADAPTS", "weapon": "WEAPON"}
const STAT_LABEL := {"dmg": "DAMAGE", "spd": "SPEED", "kb": "KNOCKBACK"}

var get_loadout: Callable
var set_slot: Callable
var get_class: Callable
var get_upgrades: Callable

var cursor: Array[int] = [0, 0]
var holding: Array[String] = ["", ""]  ## slot the move was lifted from
var close_requested := false
var t := 0.0

var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _flash: Array[String] = ["", ""]
var _flash_t: Array[float] = [0.0, 0.0]


func _init(p_get_loadout: Callable, p_set_slot: Callable, p_get_class: Callable, p_get_upgrades: Callable) -> void:
	get_loadout = p_get_loadout
	set_slot = p_set_slot
	get_class = p_get_class
	get_upgrades = p_get_upgrades


func reset() -> void:
	cursor = [0, 0]
	holding = ["", ""]
	close_requested = false
	_last = [Vector2i.ZERO, Vector2i.ZERO]


# ------------------------------------------------------------------ rules

func class_label(p: int) -> String:
	var cid: String = get_class.call(p)
	return "FISTS" if cid == "" else String(ClassData.get_class_data(cid)["name"]).to_upper()


func accepts(p: int, slot: String, move_id: String) -> bool:
	if move_id == "":
		return true
	var cid: String = get_class.call(p)
	if cid == "":
		return true  # legacy fighter without a class: any move anywhere
	return move_id in ClassData.pool_for_slot(slot, cid)


func _reason(p: int, slot: String) -> String:
	match slot.substr(0, 1):
		"X":
			return "X TAKES OFF-HAND MOVES ONLY"
		"Y":
			return "Y TAKES ADAPTIVE MOVES ONLY"
	return "B TAKES %s MOVES ONLY" % class_label(p)


## Lifts or drops the move under player p's cursor. Returns true when a swap happened.
func press(p: int) -> bool:
	var slot: String = SLOTS[cursor[p]]
	var lo: Dictionary = get_loadout.call(p)
	var cur: String = lo.get(slot, "")
	if holding[p] == "":
		if cur == "":
			_say(p, "NOTHING HERE")
			return false
		holding[p] = slot
		Sfx.play("ui")
		return false
	var from: String = holding[p]
	if slot == from:
		holding[p] = ""
		Sfx.play("ui", 0.8)
		return false
	var moving: String = lo.get(from, "")
	if not accepts(p, slot, moving):
		_say(p, _reason(p, slot))
		Sfx.play("ui", 0.6)
		return false
	if not accepts(p, from, cur):
		_say(p, _reason(p, from))
		Sfx.play("ui", 0.6)
		return false
	set_slot.call(p, slot, moving)
	set_slot.call(p, from, cur)
	holding[p] = ""
	Sfx.play("pickup")
	return true


func _say(p: int, text: String) -> void:
	_flash[p] = text
	_flash_t[p] = 1.4


## Call from the owner's _physics_process (right after Inp polls, so button edges are never missed).
func update(delta: float) -> void:
	t += delta
	for p in 2:
		_flash_t[p] = maxf(0.0, _flash_t[p] - delta)
		var inp: PlayerInput = Inp.players[p]
		var d := inp.digital_dir()
		if d != _last[p] and d != Vector2i.ZERO:
			var col := cursor[p] % 4
			var row := cursor[p] / 4
			col = clampi(col + d.x, 0, 3)
			row = clampi(row + d.y, 0, 2)
			var ni := row * 4 + col
			if ni != cursor[p]:
				cursor[p] = ni
				Sfx.play("ui")
		_last[p] = d
		if inp.pressed(PlayerInput.Btn.JUMP):
			press(p)
		elif inp.pressed(PlayerInput.Btn.B):
			if holding[p] != "":
				holding[p] = ""
				Sfx.play("ui", 0.8)
			elif holding[1 - p] == "":
				close_requested = true


# ------------------------------------------------------------------ drawing

func _move(p: int, id: String) -> MoveData:
	var cid: String = get_class.call(p)
	return MoveDB.get_move_for(id, cid) if cid != "" else MoveDB.get_move(id)


func _tier_text(p: int, id: String) -> String:
	var cid: String = get_class.call(p)
	if cid != "":
		return String(TIER_LABEL.get(ClassData.tier_of(id), "MELEE"))
	var m := MoveDB.get_move(id)
	return String(m.tags[0]).to_upper() if m.tags.size() > 0 else "MELEE"


static func _wrap(f: Font, s: String, size: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in s.split(" "):
		var test: String = w if cur == "" else cur + " " + w
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


## Whole screen: title, both players' panels and the key hints (drawn over a dimmed backdrop).
func paint_screen(c: Control) -> void:
	c.draw_set_transform_matrix(UiKit.italic(Vector2(40, 74), -0.02))
	for k in 3:
		UiKit.txt(c, UiKit.head(), Vector2.ZERO, "LOADOUT", 48, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, UiKit.head(), Vector2.ZERO, "LOADOUT", 48, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	UiKit.txt(c, UiKit.body(), Vector2(40, 104), "SWAP MOVES BETWEEN BUTTONS  ·  BOTH PLAYERS AT ONCE", 18, UiKit.PINK)
	paint_player(c, 0, Rect2(30, 126, 605, 470))
	paint_player(c, 1, Rect2(645, 126, 605, 470))
	UiKit.txt(c, UiKit.body(), Vector2(30, 640), "A  LIFT / DROP (SWAPS)      B  CANCEL / BACK", 16, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)


func paint_player(c: Control, p: int, r: Rect2) -> void:
	var col := UiKit.player_color(p)
	var lo: Dictionary = get_loadout.call(p)
	var cur_slot: String = SLOTS[cursor[p]]
	var hold: String = holding[p]
	var holding_id: String = String(lo.get(hold, "")) if hold != "" else ""
	c.draw_colored_polygon(UiKit.chamfer(r, 18.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.82))
	UiKit.poly_line(c, UiKit.chamfer(r, 18.0), Color(col.r, col.g, col.b, 0.9), 3.0)
	var tag := Rect2(r.position.x + 18, r.position.y + 14, 54, 26)
	c.draw_colored_polygon(UiKit.chamfer(tag, 7.0), col)
	UiKit.txt(c, UiKit.head(), tag.position + Vector2(0, 19), "P%d" % (p + 1), 15, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x)
	UiKit.txt(c, UiKit.head(), r.position + Vector2(86, 34), class_label(p), 18, UiKit.TEXT)
	var sub := "DROP IT ON A SLOT" if holding_id != "" else "LIFT A MOVE"
	var sub_col := col if holding_id != "" else UiKit.DIM_TEXT
	if _flash_t[p] > 0.0:
		sub = _flash[p]
		sub_col = Color(1.0, 0.45, 0.45)
	UiKit.txt(c, UiKit.body(), Vector2(r.position.x + 200.0, r.position.y + 32), sub, 15, sub_col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 218.0)
	var cw := 118.0
	var gx := r.position.x + 64.0
	var gy := r.position.y + 84.0
	for ci in 4:
		UiKit.txt(c, UiKit.body(), Vector2(gx + ci * (cw + 8.0), gy - 8), COLS[ci], 13, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
	for ri in 3:
		var cy := gy + ri * 66.0
		c.draw_circle(Vector2(r.position.x + 36, cy + 28), 17.0, UiKit.INK)
		c.draw_arc(Vector2(r.position.x + 36, cy + 28), 17.0, 0.0, TAU, 24, Color(0.9, 0.9, 1.0, 0.8), 3.0, true)
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 18, cy + 35), ROWS[ri], 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 36.0)
		for ci in 4:
			var slot: String = SLOTS[ri * 4 + ci]
			var id: String = lo.get(slot, "")
			var cell := Rect2(gx + ci * (cw + 8.0), cy, cw, 56)
			var poly := UiKit.chamfer(cell, 10.0)
			var is_from := slot == hold and hold != ""
			if id != "" and not is_from:
				c.draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.14))
				UiKit.poly_line(c, poly, Color(col.r, col.g, col.b, 0.7), 3.0)
				UiKit.txt(c, UiKit.body(), cell.position + Vector2(0, 26), _move(p, id).short.to_upper(), 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
				UiKit.txt(c, UiKit.body(), cell.position + Vector2(0, 45), _tier_text(p, id), 12, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
			elif is_from:
				UiKit.poly_line(c, poly, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, 0.5), 3.0)
				UiKit.txt(c, UiKit.body(), cell.position + Vector2(0, 34), "LIFTED", 15, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, cw)
			else:
				UiKit.poly_line(c, poly, Color(1, 1, 1, 0.14), 3.0)
				UiKit.txt(c, UiKit.body(), cell.position + Vector2(0, 34), "EMPTY", 14, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, cw)
			if slot == cur_slot:
				UiKit.poly_line(c, UiKit.chamfer(cell.grow(4.0), 12.0), col, 4.0)
				if holding_id != "":
					var gh := Rect2(cell.position.x + 6, cell.position.y - 20, cw - 12, 26)
					c.draw_colored_polygon(UiKit.chamfer(gh, 7.0), UiKit.AMBER)
					UiKit.txt(c, UiKit.head(), gh.position + Vector2(0, 19), _move(p, holding_id).short.to_upper(), 14, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, gh.size.x)
	# details of the lifted move, or of the slot under the cursor
	var shown: String = holding_id if holding_id != "" else String(lo.get(cur_slot, ""))
	var dy := gy + 3 * 66.0 + 8.0
	var dr := Rect2(r.position.x + 18, dy, r.size.x - 36, r.end.y - dy - 16.0)
	c.draw_rect(Rect2(dr.position.x, dr.position.y - 4, dr.size.x, 2), Color(1, 1, 1, 0.12))
	if shown == "":
		UiKit.txt(c, UiKit.body(), dr.position + Vector2(0, 40), "EMPTY SLOT", 20, Color(1, 1, 1, 0.4))
		return
	var m := _move(p, shown)
	UiKit.txt(c, UiKit.head(), dr.position + Vector2(0, 30), m.name.to_upper(), 22, UiKit.TEXT)
	var chips: Array = [_tier_text(p, shown)]
	for tg in m.tags:
		chips.append(String(tg).to_upper())
	var tx := dr.position.x
	for tg in chips:
		var w := UiKit.body().get_string_size(String(tg), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
		var chip := Rect2(tx, dr.position.y + 40, w, 20)
		c.draw_colored_polygon(UiKit.chamfer(chip, 5.0), Color(1, 1, 1, 0.12))
		UiKit.txt(c, UiKit.body(), chip.position + Vector2(0, 15), String(tg), 13, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
		tx += w + 6.0
		if tx > dr.end.x - 150.0:
			break
	var lines := _wrap(UiKit.body(), m.desc, 17, dr.size.x - 170.0)
	for li in mini(lines.size(), 3):
		UiKit.txt(c, UiKit.body(), dr.position + Vector2(0, 84 + li * 20), lines[li], 17, Color(0.85, 0.85, 1.0))
	# upgrades the move carries (they stay with the move)
	var ups: Dictionary = get_upgrades.call(p)
	if ups.has(shown):
		var yy := 0.0
		UiKit.txt(c, UiKit.body(), dr.position + Vector2(dr.size.x - 140, 22), "UPGRADES", 13, UiKit.DIM_TEXT)
		for stat in ["dmg", "spd", "kb"]:
			var v: float = float((ups[shown] as Dictionary).get(stat, 1.0))
			if v > 1.001:
				var rr := Rect2(dr.end.x - 140, dr.position.y + 30 + yy, 140, 24)
				UiKit.panel(c, rr, 6.0, UiKit.AMBER, 3.0, 0.85)
				UiKit.txt(c, UiKit.body(), rr.position + Vector2(0, 18), "+%d%% %s" % [int(round((v - 1.0) * 100.0)), STAT_LABEL[stat]], 14, UiKit.AMBER, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
				yy += 28.0


## Small read-only grid for the pause status panel.
func paint_mini(c: Control, p: int, r: Rect2) -> void:
	var col := UiKit.player_color(p)
	var lo: Dictionary = get_loadout.call(p)
	UiKit.panel(c, r, 14.0, col, 3.0, 0.85)
	UiKit.txt(c, UiKit.head(), r.position + Vector2(18, 30), "P%d" % (p + 1), 18, col)
	UiKit.txt(c, UiKit.body(), r.position + Vector2(66, 28), class_label(p), 16, UiKit.DIM_TEXT)
	for ci in 4:
		UiKit.txt(c, UiKit.body(), Vector2(r.position.x + 58 + ci * 78, r.position.y + 54), COLS[ci], 11, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 74.0)
	for ri in 3:
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 18, r.position.y + 100 + ri * 48), ROWS[ri], 16, UiKit.TEXT)
		for ci in 4:
			var slot: String = SLOTS[ri * 4 + ci]
			var id: String = lo.get(slot, "")
			var cell := Rect2(r.position.x + 58 + ci * 78, r.position.y + 70 + ri * 48, 74, 40)
			if id != "":
				c.draw_colored_polygon(UiKit.chamfer(cell, 7.0), Color(col.r, col.g, col.b, 0.16))
				UiKit.poly_line(c, UiKit.chamfer(cell, 7.0), Color(col.r, col.g, col.b, 0.8), 3.0)
				UiKit.txt(c, UiKit.body(), cell.position + Vector2(0, 26), _move(p, id).short.to_upper(), 17, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x)
			else:
				UiKit.poly_line(c, UiKit.chamfer(cell, 7.0), Color(1, 1, 1, 0.15), 3.0)
