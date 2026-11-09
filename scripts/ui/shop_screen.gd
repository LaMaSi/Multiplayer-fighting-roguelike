class_name ShopScreen
extends Node2D
## In-run shop (map node "shop"). One shared wallet, but every player shops on their own: each moves a cursor
## (Left/Right) and presses A on a card to buy it FOR THEMSELVES (off-hand and adaptive moves can be bought by both,
## weapon moves only by that class). A bought move asks right away which button it goes on. Leaving needs both players. The two player stickfigures stand in a thinking pose, eyes on the cards.
## Layout and look: see docs/STYLEGUIDE.md and tests/mock_screens.gd.

const SLOT_ORDER := ["X", "X_UP", "X_SIDE", "X_DOWN", "Y", "Y_UP", "Y_SIDE", "Y_DOWN", "B", "B_UP", "B_SIDE", "B_DOWN"]
const CARD_W := 190.0
const CARD_H := 270.0
const CARD_X := 240.0
const CARD_Y := 150.0
const REROLL_BASE := 40
const LIFE_PRICE := 300
const THINK := [
	{"lean": 0.05, "head": -0.12, "th_f": 0.18, "kn_f": 0.2, "th_b": -0.22, "kn_b": 0.25, "ua_f": 1.0, "la_f": 2.64, "ua_b": 0.45, "la_b": 2.3},
	{"lean": 0.0, "head": 0.14, "th_f": 0.05, "kn_f": 0.1, "th_b": 0.3, "kn_b": 0.35, "ua_f": 1.0, "la_f": 2.64, "ua_b": 0.7, "la_b": 2.0},
]

class View extends Control:
	var shop: ShopScreen

	func _draw() -> void:
		if shop != null:
			shop.paint(self)


var stock: Array = []  ## 4 item dictionaries (see _make_item)
var cursor: Array[int] = [0, 0]  ## 0..4 cards, 5 reroll, 6 leave
var vote: Array[int] = [-1, -1]  ## only used for LEAVE (both must agree)
var _pickers: Array[SlotPicker] = [SlotPicker.new(), SlotPicker.new()]
var _refund: Array[int] = [0, 0]  ## price to give back when a button step is cancelled
var rerolls := 0

var _rng := RandomNumberGenerator.new()
var _view: View
var _figs: Array[StickFigure] = []
var _last: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var _t := 0.0
var _flash := ""
var _flash_t := 0.0
var _backdrop: Backdrop
var _cam: Camera2D


func _ready() -> void:
	Engine.time_scale = 1.0
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_intensity = 0.22
	e.glow_strength = 0.6
	e.glow_hdr_threshold = 1.7
	env.environment = e
	add_child(env)
	# sky, backdrop, ground (world space = screen space, camera fixed in the middle)
	var sky := Node2D.new()
	sky.z_index = -100
	sky.draw.connect(func():
		Backdrop.paint_synth_sky(sky, -400.0, 2080.0, -300.0, 570.0)
		sky.draw_rect(Rect2(-400, 570, 2080, 400), Pal.BG_GROUND)
		sky.draw_line(Vector2(-400, 570), Vector2(1680, 570), Pal.terrain(), 3.0, true))
	add_child(sky)
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	add_child(_cam)
	_backdrop = Backdrop.new()
	_backdrop.setup(Backdrop.default_theme(), 1280.0, 570.0)
	_backdrop.cam = _cam
	add_child(_backdrop)
	# UI layers: dim, figures, drawn UI
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	for i in 2:
		var f := StickFigure.new()
		f.color = UiKit.player_color(i)
		f.arm_scale = 1.22
		f.leg_scale = 1.2
		f.eyes = true
		f.aim = Vector2(0.95, -0.3)
		f.position = Vector2(70.0 + i * 100.0, 668)
		f.scale = Vector2(1.7, 1.7)
		f.set_target(THINK[i], true)
		layer.add_child(f)
		_figs.append(f)
	_view = View.new()
	_view.shop = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_view)
	Dbg._hint.visible = false
	_rng.seed = int(RunState.current.get("seed", 1)) if not RunState.current.is_empty() else 1
	stock = generate_stock()


# ------------------------------------------------------------------ stock

func _first_free_slot(player: int) -> String:
	var lo: Dictionary = RunState.loadouts[player]
	for s in SLOT_ORDER:
		if String(lo.get(s, "")) == "":
			return s
	return ""


func _make_item(kind: String, player := -1, extra := {}) -> Dictionary:
	var it := {"kind": kind, "player": player, "sold": false}
	it.merge(extra, true)
	return it


## Five items: an off-hand move and an adaptive move (either player can buy them, each for themselves), a weapon move for
## each class in play (only that class), and one team item.
func generate_stock() -> Array:
	var out: Array = []
	var taken: Array = []
	for tier_pool in [ClassData.X_POOL, ClassData.Y_POOL]:
		var pool: Array = []
		for id in tier_pool:
			var owned_both := true
			for p in 2:
				if not (id in (RunState.loadouts[p] as Dictionary).values()):
					owned_both = false
			if not owned_both and not (id in taken):
				pool.append(id)
		if pool.size() > 0:
			var sid: String = pool[_rng.randi() % pool.size()]
			taken.append(sid)
			out.append(_move_item(sid, ""))
	for p in 2:
		var cid: String = RunState.classes[p]
		if cid == "":
			continue
		var owned2: Array = (RunState.loadouts[p] as Dictionary).values()
		var bp: Array = []
		for id in (ClassData.get_class_data(cid)["b_pool"] as Array):
			if not (id in owned2) and not (id in taken):
				bp.append(id)
		if bp.size() > 0:
			var bid: String = bp[_rng.randi() % bp.size()]
			taken.append(bid)
			out.append(_move_item(bid, cid))
	var team := _rng.randi() % 4
	if team == 0:
		out.append(_make_item("life", -1, {"name": "EXTRA LIFE", "desc": "+1 shared life for the rest of the run", "tag": "TEAM", "price": LIFE_PRICE}))
	elif team == 1:
		out.append(_make_item("hp", -1, {"name": "+20 MAX HP", "desc": "Both players grow and heal 20", "tag": "TEAM", "price": 140}))
	elif team == 2:
		out.append(_make_item("heal", -1, {"name": "TEAM HEAL", "desc": "Both players restore all health", "tag": "TEAM", "price": 90}))
	else:
		out.append(_make_item("power", -1, {"name": "POWER-UP", "desc": "Buyer: +25% damage on a random equipped move", "tag": "EMPOWER", "price": 120}))
	return out


func _move_item(id: String, cid: String) -> Dictionary:
	var m := MoveDB.get_move(id)
	var tag := "FOR BOTH" if cid == "" else "%s MOVE" % cid.to_upper()
	return _make_item("move", -1, {"id": id, "class": cid, "name": m.name, "desc": m.desc, "tag": tag, "price": 110 if cid == "" else 130, "sold_by": [false, false]})


func reroll_cost() -> int:
	return REROLL_BASE + 20 * rerolls


# ------------------------------------------------------------------ purchase

func can_afford(it: Dictionary) -> bool:
	return RunState.coins >= int(it["price"])


## Why player p cannot take this item, or "" when they can.
func _can_take(it: Dictionary, p: int) -> String:
	if String(it["kind"]) == "move":
		if String(it["class"]) != "" and String(it["class"]) != String(RunState.classes[p]):
			return "OTHER CLASS"
		if bool((it["sold_by"] as Array)[p]):
			return "YOU BOUGHT IT"
		if String(it["id"]) in (RunState.loadouts[p] as Dictionary).values():
			return "ALREADY EQUIPPED"
		return ""
	return "SOLD OUT" if bool(it["sold"]) else ""


func _is_sold(it: Dictionary) -> bool:
	if String(it["kind"]) == "move":
		for p in 2:
			if _can_take(it, p) == "":
				return false
		return true
	return bool(it["sold"])


func _view_player(it: Dictionary) -> int:
	for p in 2:
		if String(it.get("class", "")) == String(RunState.classes[p]):
			return p
	return 0


## Player p buys item idx for themselves. A move asks right away which button it goes on (cancelling refunds it).
func buy(idx: int, p: int) -> bool:
	var it: Dictionary = stock[idx]
	var why := _can_take(it, p)
	if why != "":
		_say(why, Color(1.0, 0.45, 0.45))
		return false
	if not can_afford(it):
		return false
	var price := int(it["price"])
	match String(it["kind"]):
		"move":
			RunState.coins -= price
			(it["sold_by"] as Array)[p] = true
			_pickers[p].start(p, String(it["id"]), func(slot: String) -> void:
				if slot == "":
					RunState.coins += price  # cancelled: money back
					(it["sold_by"] as Array)[p] = false
					return
				(RunState.loadouts[p] as Dictionary)[slot] = it["id"]
				Sfx.play("pickup"))
			return true
		"power":
			var eq: Array = []
			for id in (RunState.loadouts[p] as Dictionary).values():
				if String(id) != "" and not (id in eq):
					eq.append(id)
			if eq.is_empty():
				return false
			RunState.apply_card(p, {"kind": "up", "id": eq[_rng.randi() % eq.size()], "stat": "dmg"})
		"hp":
			for i in 2:
				RunState.apply_card(i, {"kind": "hp"})
		"heal":
			for i in 2:
				RunState.apply_card(i, {"kind": "mend"})
		"life":
			RunState.bonus_revives += 1
	RunState.coins -= price
	it["sold"] = true
	return true


func _act(v: int, p: int) -> void:
	if v >= 0 and v <= 4:
		if v >= stock.size() or _is_sold(stock[v]):
			return
		if buy(v, p):
			Sfx.play("pickup")
			_say("P%d BOUGHT  %s" % [p + 1, String(stock[v]["name"])], UiKit.player_color(p))
		elif _can_take(stock[v], p) == "":
			Sfx.play("ui")
			_say("NOT ENOUGH COINS", Color(1.0, 0.45, 0.45))
		else:
			Sfx.play("ui", 0.7)
	elif v == 5:
		if RunState.coins >= reroll_cost():
			RunState.coins -= reroll_cost()
			rerolls += 1
			stock = generate_stock()
			Sfx.play("relay")
			_say("STOCK REROLLED", UiKit.PINK)
		else:
			Sfx.play("ui")
			_say("NOT ENOUGH COINS", Color(1.0, 0.45, 0.45))
	elif v == 6:
		vote[p] = -1 if vote[p] == 6 else 6
		Sfx.play("ui")


func leave() -> void:
	if RunState.active:
		RunState.shop_done()
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _say(t: String, col: Color) -> void:
	_flash = t
	_flash_t = 1.6
	_flash_col = col


var _flash_col := Color.WHITE


# ------------------------------------------------------------------ input

## Input is read in the physics step (right after Inp polls) so a button edge is never missed.
func _physics_process(_delta: float) -> void:
	for i in 2:
		var p: PlayerInput = Inp.players[i]
		if _pickers[i].active:
			_pickers[i].update(p)
			continue
		var d := p.digital_dir()
		if d != _last[i] and d.x != 0:
			cursor[i] = clampi(cursor[i] + d.x, 0, 6)
			Sfx.play("ui")
		_last[i] = d
		if p.pressed(PlayerInput.Btn.JUMP):
			_act(cursor[i], i)
		elif p.pressed(PlayerInput.Btn.B):
			vote[i] = -1
	if RunState.solo:
		vote[1] = vote[0]
	if vote[0] == 6 and vote[1] == 6 and not _pickers[0].active and not _pickers[1].active:
		leave()


func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	# gentle breathing on the thinking figures
	for i in _figs.size():
		var pose: Dictionary = (THINK[i] as Dictionary).duplicate()
		pose["lean"] = float(pose["lean"]) + sin(_t * 1.7 + i) * 0.015
		_figs[i].set_target(pose)
		_figs[i].aim = Vector2(0.95, -0.15 - 0.15 * float(cursor[i]) / 6.0 + 0.1 * sin(_t * 0.9 + i))
	_view.queue_redraw()


# ------------------------------------------------------------------ drawing

func _fit(f: Font, t: String, size: int, width: float) -> int:
	var s := size
	while s > 12 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:
		s -= 1
	return s


func _wrap(f: Font, t: String, size: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in t.split(" "):
		var test := w if cur == "" else cur + " " + w
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


func _icon(c: Control, kind: String, pos: Vector2, col: Color) -> void:
	match kind:
		"move":
			c.draw_arc(pos + Vector2(-6, 6), 30.0, -2.4, 0.3, 16, col, 7.0, true)
			c.draw_arc(pos + Vector2(-6, 6), 20.0, -2.0, 0.0, 12, Color(col.r, col.g, col.b, 0.5), 4.0, true)
		"up":
			c.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -28), pos + Vector2(24, 0), pos + Vector2(8, 0), pos + Vector2(8, 24), pos + Vector2(-8, 24), pos + Vector2(-8, 0), pos + Vector2(-24, 0)]), col)
		"life":
			UiKit.head_icon(c, pos, 18.0, col)
			c.draw_line(pos + Vector2(22, -22), pos + Vector2(22, -8), col, 4.0)
			c.draw_line(pos + Vector2(15, -15), pos + Vector2(29, -15), col, 4.0)
		"hp":
			c.draw_rect(Rect2(pos.x - 7, pos.y - 26, 14, 52), col)
			c.draw_rect(Rect2(pos.x - 26, pos.y - 7, 52, 14), col)
		"heal":
			c.draw_arc(pos, 24.0, 0.0, TAU, 24, col, 5.0, true)
			c.draw_rect(Rect2(pos.x - 4, pos.y - 14, 8, 28), col)
			c.draw_rect(Rect2(pos.x - 14, pos.y - 4, 28, 8), col)


func paint(c: Control) -> void:
	var head := UiKit.head()
	var body := UiKit.body()
	# title and wallet
	c.draw_set_transform_matrix(UiKit.italic(Vector2(40, 70), -0.02))
	for k in 3:
		UiKit.txt(c, head, Vector2(0, 0), "SHOP", 52, Color(2.0, 0.7, 1.2, 0.16), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8 + k * 8, Color(2.0, 0.7, 1.2, 0.08))
	UiKit.txt(c, head, Vector2(0, 0), "SHOP", 52, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color(0.05, 0.0, 0.1))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	UiKit.txt(c, body, Vector2(44, 100), "EACH PLAYER SHOPS FOR THEMSELVES", 18, UiKit.PINK)
	UiKit.panel(c, Rect2(980, 30, 260, 64), 12.0, UiKit.AMBER, 3.0, 0.85)
	UiKit.coin(c, Vector2(1014, 62), 17.0)
	UiKit.txt(c, body, Vector2(1040, 52), "SHARED WALLET", 14, UiKit.DIM_TEXT)
	UiKit.txt(c, head, Vector2(1040, 84), str(RunState.coins), 30, UiKit.AMBER)
	# cards
	for idx in stock.size():
		_paint_card(c, idx)
	# info strip
	var vr := Rect2(CARD_X, 458, 1014, 40)
	c.draw_colored_polygon(UiKit.chamfer(vr, 10.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.8))
	var line := "STICK: MOVE    A: BUY FOR YOURSELF    LEAVING NEEDS BOTH PLAYERS"
	var lcol := UiKit.TEXT
	if vote[0] == 6 or vote[1] == 6:
		line = "LEAVE THE SHOP?  WAITING FOR P%d" % (2 if vote[0] == 6 else 1)
		lcol = UiKit.PINK
	if _flash_t > 0.0:
		line = _flash
		lcol = _flash_col
	UiKit.txt(c, body, Vector2(CARD_X + 16, 485), line, 22, lcol)
	# buttons
	_paint_button(c, Rect2(CARD_X, 516, 220, 44), 5, "REROLL STOCK", reroll_cost())
	_paint_button(c, Rect2(CARD_X + 1014.0 - 220.0, 516, 220, 44), 6, "LEAVE SHOP", -1)
	# the button pickers (a bought move asks right away where it goes)
	for pp in 2:
		if _pickers[pp].active:
			_pickers[pp].paint(c, Rect2(40.0 + pp * 630.0, 440.0, 600.0, 252.0), UiKit.player_color(pp))
	# thought bubbles
	for i in 2:
		var bc := Vector2(86 + i * 100, 372 + i * 6 + sin(_t * 1.6 + i) * 3.0)
		var col := UiKit.player_color(i)
		c.draw_circle(bc + Vector2(-26, 52), 5.0, Color(col.r, col.g, col.b, 0.8))
		c.draw_circle(bc + Vector2(-16, 36), 8.0, Color(col.r, col.g, col.b, 0.8))
		c.draw_circle(bc, 30.0, UiKit.INK)
		c.draw_arc(bc, 30.0, 0.0, TAU, 28, col, 3.0, true)
		UiKit.txt(c, head, bc + Vector2(-30, 14), "?", 40, col, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


func _vote_line(target: int) -> String:
	if target >= 0 and target <= 3:
		var it: Dictionary = stock[target]
		if bool(it["sold"]):
			return "SOLD OUT"
		return "BUY  %s  FOR  %d?" % [String(it["name"]), int(it["price"])]
	if target == 4:
		return "REROLL THE STOCK FOR %d?" % reroll_cost()
	return "LEAVE THE SHOP?"


func _cursor_tabs(c: Control, idx: int, r: Rect2) -> void:
	for i in 2:
		if cursor[i] != idx:
			continue
		var col := UiKit.player_color(i)
		var voted := vote[i] == idx
		var tab := Rect2(r.position.x + 6 if i == 0 else r.end.x - 90, r.position.y - 26, 84, 22)
		if voted:
			c.draw_colored_polygon(UiKit.chamfer(tab, 6.0), col)
			UiKit.txt(c, UiKit.head(), Vector2(tab.position.x + 8, tab.position.y + 16), "P%d" % (i + 1), 12, UiKit.INK)
			UiKit.check(c, Vector2(tab.position.x + 50, tab.position.y + 12), UiKit.INK)
		else:
			c.draw_colored_polygon(UiKit.chamfer(tab, 6.0), Color(col.r, col.g, col.b, 0.25))
			UiKit.poly_line(c, UiKit.chamfer(tab, 6.0), col, 2.0)
			UiKit.txt(c, UiKit.head(), Vector2(tab.position.x + 8, tab.position.y + 16), "P%d" % (i + 1), 12, col)


func _paint_card(c: Control, idx: int) -> void:
	var it: Dictionary = stock[idx]
	var r := Rect2(CARD_X + idx * (CARD_W + 16.0), CARD_Y, CARD_W, CARD_H)
	var sold := _is_sold(it)
	var afford := can_afford(it) and not sold
	var hot := cursor[0] == idx or cursor[1] == idx
	var both := vote[0] == idx and vote[1] == idx
	var outline := Color(0.8, 0.8, 1.0, 0.55) if afford else Color(0.8, 0.8, 1.0, 0.2)
	if hot:
		outline = UiKit.TEXT
	c.draw_colored_polygon(UiKit.chamfer(r, 16.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.88 if afford else 0.7))
	UiKit.poly_line(c, UiKit.chamfer(r, 16.0), outline, 5.0 if hot else 2.5)
	var ic := UiKit.AMBER if afford else Color(0.5, 0.5, 0.6)
	if it.has("id") and (String(it["kind"]) == "move" or String(it["kind"]) == "up"):
		var pl := _view_player(it)
		MovePreview.draw(c, String(it["id"]), String(RunState.classes[pl]), pl, Rect2(r.position.x + 14, r.position.y + 8, CARD_W - 28, 106))
		UiKit.charge_chip(c, Rect2(r.position.x + 18, r.position.y + 12, 28.0, 28.0), MoveDB.get_move(String(it["id"])))
	else:
		_icon(c, String(it["kind"]), Vector2(r.position.x + CARD_W * 0.5, r.position.y + 72), ic)
	var tag_col := Color(0.85, 0.85, 1.0)
	var tag_text := String(it["tag"])
	c.draw_rect(Rect2(r.position.x + (CARD_W - 150.0) * 0.5, r.position.y + 118, 150, 20), Color(1, 1, 1, 0.12))
	UiKit.txt(c, UiKit.head(), Vector2(r.position.x, r.position.y + 133), tag_text, 10, tag_col, HORIZONTAL_ALIGNMENT_CENTER, CARD_W)
	var name_s := String(it["name"]).to_upper()
	var ns := _fit(UiKit.body(), name_s, 24, CARD_W - 16.0)
	UiKit.txt(c, UiKit.body(), Vector2(r.position.x, r.position.y + 166), name_s, ns, UiKit.TEXT if afford else Color(0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER, CARD_W)
	var lines := _wrap(UiKit.body(), String(it["desc"]), 15, CARD_W - 24.0)
	for li in mini(lines.size(), 3):
		UiKit.txt(c, UiKit.body(), Vector2(r.position.x, r.position.y + 192 + li * 17), lines[li], 15, Color(0.78, 0.78, 0.9) if afford else Color(0.5, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER, CARD_W)
	var pr := Rect2(r.position.x + 36, r.end.y - 40, CARD_W - 72, 30)
	c.draw_colored_polygon(UiKit.chamfer(pr, 8.0), Color(0.12, 0.08, 0.02, 0.9) if afford else Color(0.2, 0.05, 0.08, 0.9))
	UiKit.coin(c, pr.position + Vector2(18, 15), 9.0)
	UiKit.txt(c, UiKit.head(), pr.position + Vector2(30, 22), str(it["price"]), 18, UiKit.AMBER if afford else Color(1.0, 0.35, 0.35))
	if sold:
		c.draw_set_transform_matrix(UiKit.italic(r.get_center() + Vector2(0, 40), -0.18, 1.0, 0.0))
		UiKit.txt(c, UiKit.head(), Vector2(-90, 0), "SOLD", 40, Color(UiKit.AMBER.r, UiKit.AMBER.g, UiKit.AMBER.b, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 5, Color(0, 0, 0, 0.8))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	elif not can_afford(it):
		UiKit.txt(c, UiKit.body(), Vector2(r.position.x, r.end.y + 22), "NOT ENOUGH COINS", 14, Color(1.0, 0.45, 0.45), HORIZONTAL_ALIGNMENT_CENTER, CARD_W)
	if both:
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		UiKit.poly_line(c, UiKit.chamfer(r.grow(4.0), 16.0), Color(1.0, 0.8, 0.3, 0.5 + 0.5 * pulse), 4.0)
	_cursor_tabs(c, idx, r)
	for bp in 2:
		if String(it["kind"]) == "move" and bool((it["sold_by"] as Array)[bp]):
			UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 10.0 + bp * 70.0, r.end.y - 52.0), "P%d OWNS" % (bp + 1), 11, UiKit.player_color(bp))


func _paint_button(c: Control, r: Rect2, idx: int, label: String, cost: int) -> void:
	var hot := cursor[0] == idx or cursor[1] == idx
	c.draw_colored_polygon(UiKit.chamfer(r, 10.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.85))
	UiKit.poly_line(c, UiKit.chamfer(r, 10.0), UiKit.TEXT if hot else Color(0.8, 0.8, 1.0, 0.6), 4.0 if hot else 2.5)
	if cost >= 0:
		UiKit.txt(c, UiKit.body(), Vector2(r.position.x, r.position.y + 30), label, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 160.0)
		UiKit.coin(c, Vector2(r.position.x + 168, r.position.y + 22), 9.0)
		UiKit.txt(c, UiKit.head(), Vector2(r.position.x + 180, r.position.y + 29), str(cost), 16, UiKit.AMBER if RunState.coins >= cost else Color(1.0, 0.35, 0.35))
	else:
		UiKit.txt(c, UiKit.body(), Vector2(r.position.x, r.position.y + 30), label, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var tab_x := r.position.x + 6.0
	for i in 2:
		if cursor[i] == idx:
			var col := UiKit.player_color(i)
			var tab := Rect2(tab_x, r.position.y - 22, 60, 18)
			var voted := vote[i] == idx
			c.draw_colored_polygon(UiKit.chamfer(tab, 5.0), col if voted else Color(col.r, col.g, col.b, 0.25))
			UiKit.txt(c, UiKit.head(), Vector2(tab.position.x, tab.position.y + 14), "P%d" % (i + 1) + (" OK" if voted else ""), 11, UiKit.INK if voted else col, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
			tab_x += 66.0
