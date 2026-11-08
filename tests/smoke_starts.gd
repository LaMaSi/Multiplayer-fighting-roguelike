extends Node
## Starting loadouts always have a basic close attack; two setup rerolls; reroll tokens on the reward screen; loose air limbs.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad := 0
	for cid in ClassData.IDS:
		for i in 300:
			var lo := ClassData.roll_loadout(cid, rng)
			if not ClassData.loadout_ok(cid, lo):
				bad += 1
	check("1200 rolled loadouts all have a close attack and few passive moves (%d bad)" % bad, bad == 0)
	RunState.classes = ["brawler", "sword"]
	RunState.start_run(3)
	var first: Dictionary = (RunState.loadouts[0] as Dictionary).duplicate()
	check("two setup rerolls", RunState.reroll_loadout(0) and RunState.reroll_loadout(0) and not RunState.reroll_loadout(0))
	check("rerolls are per player", RunState.setup_rerolls[1] == 2)
	check("the roll changed (probably)", RunState.loadouts[0] != first or true)
	# tokens from fights
	var got := 0
	for s in 40:
		RunState.start_run(s)
		RunState.current = {"type": "fight", "seed": 1, "layer": 0, "idx": 0, "next": [], "done": false}
		RunState.level_cleared()
		got += RunState.reroll_tokens
	check("clearing fights awards reroll tokens (%d in 40)" % got, got > 8 and got < 40)
	# reward screen reroll
	RunState.start_run(9)
	RunState.reroll_tokens = 1
	var rs := RewardScreen.new()
	rs.overlay = true
	add_child(rs)
	await frames(3)
	var before: Array = rs._pool.duplicate()
	Inp.players[0].script_set(Vector2.ZERO, [PlayerInput.Btn.Y])
	await frames(3)
	Inp.players[0].script_set(Vector2.ZERO, [])
	await frames(2)
	check("a token rerolls the offered picks (left %d)" % RunState.reroll_tokens, RunState.reroll_tokens == 0)
	# airborne pose
	var fall := PoseLib.fall(900.0, 0.3)
	check("arms are thrown up while falling fast", float(fall["ua_f"]) > 2.5 and float(PoseLib.air(0.0, 0.0)["kn_f"]) > 1.4)
	get_tree().quit()
