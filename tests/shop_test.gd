extends Node
## Shop check: every player buys for themselves (no voting), shared moves can be bought by both, weapon moves only by
## their class, a bought move asks for a button right away (cancel refunds), leaving needs both players.
##   godot --path . res://tests/shop_test.tscn -- <out_dir>

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func tap(p: PlayerInput, btns: Array, dir := Vector2.ZERO) -> void:
	p.script_set(dir, btns)
	await frames(2)
	p.script_set(Vector2.ZERO, [])
	await frames(2)


func _ready() -> void:
	RunState.classes = ["sword", "hammer"]
	RunState.start_run(5)
	RunState.coins = 600
	RunState.current = {"seed": 5, "type": "shop", "layer": 0, "idx": 0, "next": [], "done": false}
	var shop: ShopScreen = load("res://scenes/shop.tscn").instantiate()
	add_child(shop)
	await frames(10)
	check("stock has 5 items (2 shared moves, 2 class moves, 1 team item)", shop.stock.size() == 5)
	var p1: PlayerInput = Inp.players[0]
	var p2: PlayerInput = Inp.players[1]
	var A := [PlayerInput.Btn.JUMP]
	var B := [PlayerInput.Btn.B]
	# P1 buys the first (shared) move on their own: no vote needed
	var before: int = RunState.coins
	var price: int = int(shop.stock[0]["price"])
	var id0: String = shop.stock[0]["id"]
	await tap(p1, A)
	check("one player buying is enough (coins %d -> %d)" % [before, RunState.coins], RunState.coins == before - price)
	check("a bought move opens the button picker for that player", shop._pickers[0].active and not shop._pickers[1].active)
	await tap(p1, A)  # confirm the default slot
	check("the move landed in P1's loadout", id0 in (RunState.loadouts[0] as Dictionary).values())
	check("the shared move is still for sale to P2", not shop._is_sold(shop.stock[0]))
	# P2 buys the same shared move for themselves, then cancels the button step: refund
	var before2: int = RunState.coins
	await tap(p2, A)
	check("P2 can buy the same shared move", shop._pickers[1].active and RunState.coins == before2 - price)
	await tap(p2, B)
	check("cancelling the button step refunds", RunState.coins == before2 and not shop.stock[0]["sold_by"][1])
	# weapon moves: P1 (sword) cannot buy the hammer card
	var hammer_idx := -1
	for i in shop.stock.size():
		if String(shop.stock[i]["kind"]) == "move" and String(shop.stock[i]["class"]) == "hammer":
			hammer_idx = i
	check("there is a hammer move in the stock", hammer_idx >= 0)
	if hammer_idx >= 0:
		check("P1 (sword) cannot take the hammer move", shop._can_take(shop.stock[hammer_idx], 0) == "OTHER CLASS")
		check("P2 (hammer) can", shop._can_take(shop.stock[hammer_idx], 1) == "")
	# leaving needs both players
	shop.cursor = [6, 6]
	await tap(p1, A)
	check("one player alone cannot leave", is_instance_valid(shop) and shop.vote[0] == 6 and shop.vote[1] != 6)
	print("RESULT: ", "ALL PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit()
