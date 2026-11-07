class_name SlotPicker
extends RefCounted
## Assigning a freshly picked move to a button slot, for one player: a 3 x 4 grid (X / Y / B rows, neutral / up / side /
## down columns). Used by the reward screen, the shop and the door rooms, so the choice is made right when the move is
## picked up. Stick = move, A = confirm, B = cancel (calls on_done with "").

const ROWS := ["X", "Y", "B"]
const SUFFIX := ["", "_UP", "_SIDE", "_DOWN"]
const COLS := ["NEUTRAL", "UP", "SIDE", "DOWN"]

var active := false
var player := 0
var move_id := ""
var row_lock := -1  ## universal -> X row, adaptive -> Y row, weapon -> B row; -1 = any (legacy fighters)
var slot := 0
var on_done: Callable = Callable()
var _last := Vector2i.ZERO


static func row_for(id: String, class_id: String) -> int:
	if class_id == "":
		return -1
	match ClassData.tier_of(id):
		"universal":
			return 0
		"adaptive":
			return 1
		"weapon":
			return 2
	return -1


func slot_name(s: int) -> String:
	return ROWS[s / 4] + SUFFIX[s % 4]


func start(p: int, id: String, done: Callable) -> void:
	active = true
	player = p
	move_id = id
	on_done = done
	var cls: String = String(RunState.classes[p])
	row_lock = row_for(id, cls)
	var row0 := maxi(row_lock, 0)
	slot = row0 * 4
	var lo: Dictionary = RunState.loadouts[p]
	for s in 12:
		if row_lock >= 0 and s / 4 != row_lock:
			continue
		if not lo.has(slot_name(s)) or String(lo[slot_name(s)]) == "":
			slot = s
			break
	_last = Vector2i(9, 9)  # ignore the stick direction held when the picker opened


## Call every physics step with the player's input. Returns true while the picker is open.
func update(inp: PlayerInput) -> bool:
	if not active:
		return false
	var d := inp.digital_dir()
	if d != _last and d != Vector2i.ZERO:
		Sfx.play("ui")
		var col := slot % 4
		var row := slot / 4
		col = posmod(col + d.x, 4)
		row = posmod(row + d.y, 3)
		if row_lock >= 0:
			row = row_lock
		slot = row * 4 + col
	_last = d
	if inp.pressed(PlayerInput.Btn.JUMP):
		active = false
		if on_done.is_valid():
			on_done.call(slot_name(slot))
	elif inp.pressed(PlayerInput.Btn.B):
		active = false
		if on_done.is_valid():
			on_done.call("")
	return true


## Draw the picker inside `r` (about 560 x 240 fits). `c` is any CanvasItem being drawn.
func paint(c: CanvasItem, r: Rect2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	c.draw_rect(r, Color(0.05, 0.03, 0.12, 0.97))
	c.draw_rect(r, col, false, 3.0)
	var m := MoveDB.get_move(move_id)
	var nm: String = m.name.to_upper() if m != null else move_id
	c.draw_string(f, r.position + Vector2(16, 28), "P%d: PUT  %s  ON A BUTTON" % [player + 1, nm], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 180.0, 20, col)
	c.draw_string(f, r.position + Vector2(16, 48), "Stick: choose    A: confirm    B: cancel", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 180.0, 13, Color(1, 1, 1, 0.6))
	MovePreview.draw(c, move_id, String(RunState.classes[player]), player, Rect2(r.end.x - 170.0, r.position.y + 6.0, 160.0, 110.0))
	var lo: Dictionary = RunState.loadouts[player]
	var cw := (r.size.x - 200.0) / 4.0
	for ci in 4:
		c.draw_string(f, Vector2(r.position.x + 74.0 + ci * cw, r.position.y + 72.0), COLS[ci], HORIZONTAL_ALIGNMENT_CENTER, cw - 6.0, 11, Color(1, 1, 1, 0.55))
	for s in 12:
		var cx := s % 4
		var cy := s / 4
		var cell := Rect2(r.position.x + 74.0 + cx * cw, r.position.y + 78.0 + cy * 50.0, cw - 6.0, 44.0)
		var sel := s == slot
		var allowed := row_lock < 0 or cy == row_lock
		c.draw_rect(cell, Color(0.1, 0.07, 0.18) if allowed else Color(0.07, 0.05, 0.12))
		c.draw_rect(cell, col if sel else Color(1, 1, 1, 0.18 if allowed else 0.07), false, 4.0 if sel else 1.5)
		var id: String = String(lo.get(slot_name(s), ""))
		var label := "(empty)"
		if id != "":
			var mm := MoveDB.get_move(id)
			label = mm.short if mm != null else id
		c.draw_string(f, cell.position + Vector2(0, 27), label, HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 14, Color(1, 1, 1, 0.9 if id != "" else 0.35) if allowed else Color(1, 1, 1, 0.25))
	for ri in 3:
		c.draw_string(f, Vector2(r.position.x + 16.0, r.position.y + 106.0 + ri * 50.0), String(ROWS[ri]), HORIZONTAL_ALIGNMENT_LEFT, 40.0, 22, col if (row_lock < 0 or ri == row_lock) else Color(1, 1, 1, 0.25))
	var cur: String = String(lo.get(slot_name(slot), ""))
	if cur != "":
		c.draw_string(f, r.position + Vector2(16, r.size.y - 12.0), "replaces  %s" % MoveDB.get_move(cur).name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32.0, 14, Color(1.0, 0.7, 0.4))
