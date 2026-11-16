class_name SideRoom
extends DoorRoom
## A shop or challenge screen beside a Skyscraper battle floor. It is attached to the tower: the players walk in
## through the gate in the side wall and the screen scrolls over. A shop is left the same way at any time; a
## challenge closes the gate until it is cleared. Challenges start with three enemies and the rest drop in one by one.

var side := 1  ## 1 = to the right of the tower, -1 = to the left
var _bodies: Array[Node] = []


func setup_side(lv: LevelBase, k: String, sd: int, fy: float) -> SideRoom:
	level = lv
	kind = k
	side = sd
	floor_y = fy
	exit_by_door = false
	x0 = lv.level_w if sd > 0 else -ROOM_W
	exit_x = x0 + 50.0 if sd > 0 else x0 + ROOM_W - 50.0  # the doorway
	return self


const Z := -13  ## behind the tower's walls (-12), so the wall and its doorway look the same from both sides


func enter() -> void:
	super.enter()
	z_index = Z


func _place() -> void:
	var g := gy()
	_bodies.append(level._make_body(Rect2(x0, g, ROOM_W, 400.0), 1))
	_bodies.append(level._make_body(Rect2(x0 + ROOM_W if side > 0 else x0 - 100.0, g - 1500.0, 100.0, 3000.0), 1))


func _start_challenge() -> void:
	var far := x0 + ROOM_W * (0.72 if side > 0 else 0.28)
	var mid := x0 + ROOM_W * 0.5
	var tower := level as SkyscraperLevel
	tower.trickle_begin(["heavy", "brute", "brute", "brute", "heavy", "brute"], 3, 7.0, SkyscraperLevel.TRICKLE_CAP,
		[mid, far, (mid + far) * 0.5], gy(), 0.6)


func _challenge_tick(delta: float) -> void:
	if (level as SkyscraperLevel).trickle_tick(delta):
		_finish_challenge()


func leave() -> void:
	Coop.enemy_hp_mult = _hp_before
	level.get_tree().paused = false
	for b in _bodies:
		if is_instance_valid(b):
			b.queue_free()
	_bodies.clear()
	if _ui_layer != null:
		_ui_layer.queue_free()
		_ui_layer = null
		_ui = null
	get_tree().create_timer(1.2).timeout.connect(queue_free)  # stays in view while the screen scrolls back


func _draw_shell() -> void:
	var g := gy()
	var col := room_color()
	draw_rect(Rect2(x0, g - 1500.0, ROOM_W, 1900.0), Color(0.03, 0.015, 0.06))
	for i in 12:
		var px := x0 + 60.0 + i * 125.0
		draw_line(Vector2(px, g), Vector2(px, g - 620.0), Color(col.r, col.g, col.b, 0.10), 2.0)
	draw_rect(Rect2(x0, g, ROOM_W, 400.0), Color(0.05, 0.03, 0.10))
	draw_line(Vector2(x0, g), Vector2(x0 + ROOM_W, g), col, 3.0, true)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(x0, g - 470.0), "CHALLENGE" if kind == "challenge" else "MOVE SHOP", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 44, col)
	if kind == "challenge" and not cleared:
		draw_string(f, Vector2(x0, g - 422.0), "Defeat them all: more drop in one by one", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 22, Color(1, 1, 1, 0.8))
	if kind == "shop":
		draw_string(f, Vector2(x0, g - 422.0), "Stand at a pedestal and press RB to buy. Each player buys for themselves; the move goes on a button right away.", HORIZONTAL_ALIGNMENT_CENTER, ROOM_W, 17, Color(1, 1, 1, 0.75))
	# (the tower wall and its doorway are drawn by the tower itself, over this room); the sign above the way back
	var wx := x0 if side > 0 else x0 + ROOM_W - SkyscraperLevel.WALL_T
	var gh := SkyscraperLevel.GATE_H
	var ec := col if cleared else Color(col.r * 0.3, col.g * 0.3, col.b * 0.3)
	var back := ("<< BACK" if side > 0 else "BACK >>") if cleared else "LOCKED"
	draw_string(f, Vector2(wx - 40.0, g - gh - 40.0), back, HORIZONTAL_ALIGNMENT_CENTER, SkyscraperLevel.WALL_T + 80.0, 24, ec)
