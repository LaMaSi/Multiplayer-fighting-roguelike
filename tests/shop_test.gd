extends Node
## Scripted shop check: both players vote for the same card, coins drop and the item is applied;
## a vote on an unaffordable card is refused; reroll costs coins. Prints PASS / FAIL lines and
## saves a screenshot.   godot --path . res://tests/shop_test.tscn -- <out_dir>

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	RunState.start_run(5)
	RunState.coins = 260
	RunState.current = {"seed": 5, "type": "shop", "layer": 0, "idx": 0, "next": [], "done": false}
	var shop: ShopScreen = load("res://scenes/shop.tscn").instantiate()
	add_child(shop)
	await frames(10)
	check("stock has 4 items", shop.stock.size() == 4)
	var p1: PlayerInput = Inp.players[0]
	var p2: PlayerInput = Inp.players[1]
	var A := [PlayerInput.Btn.JUMP]
	# both vote card 0
	var before: int = RunState.coins
	var price: int = int(shop.stock[0]["price"])
	p1.script_set(Vector2.ZERO, A)
	await frames(2)
	p1.script_set(Vector2.ZERO, [])
	await frames(2)
	check("one vote does not buy", RunState.coins == before and not shop.stock[0]["sold"])
	await frames(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/shop_one_vote.png")
	p2.script_set(Vector2.ZERO, A)
	await frames(2)
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("both votes buy the item", shop.stock[0]["sold"] and RunState.coins == before - price)
	if String(shop.stock[0]["kind"]) == "move":
		var slot: String = shop.stock[0]["slot"]
		check("move landed in the loadout", String(RunState.loadouts[int(shop.stock[0]["player"])].get(slot, "")) == String(shop.stock[0]["id"]))
	# move both cursors to the life card (index 3) and try to buy something unaffordable
	RunState.coins = 10
	for i in 3:
		p1.script_set(Vector2(1, 0))
		p2.script_set(Vector2(1, 0))
		await frames(2)
		p1.script_set(Vector2.ZERO)
		p2.script_set(Vector2.ZERO)
		await frames(2)
	check("cursors moved to card 3", shop.cursor[0] == 3 and shop.cursor[1] == 3)
	p1.script_set(Vector2.ZERO, A)
	p2.script_set(Vector2.ZERO, A)
	await frames(2)
	p1.script_set(Vector2.ZERO, [])
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("unaffordable item is refused", not shop.stock[3]["sold"] and RunState.coins == 10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/shop_refused.png")
	# reroll
	RunState.coins = 200
	var cost := shop.reroll_cost()
	p1.script_set(Vector2(1, 0))
	p2.script_set(Vector2(1, 0))
	await frames(2)
	p1.script_set(Vector2.ZERO)
	p2.script_set(Vector2.ZERO)
	await frames(2)
	p1.script_set(Vector2.ZERO, A)
	p2.script_set(Vector2.ZERO, A)
	await frames(2)
	p1.script_set(Vector2.ZERO, [])
	p2.script_set(Vector2.ZERO, [])
	await frames(3)
	check("reroll costs coins", RunState.coins == 200 - cost and shop.rerolls == 1)
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
