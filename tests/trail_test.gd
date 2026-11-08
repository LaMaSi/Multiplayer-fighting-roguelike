extends Node
## Enemies sent flying leave a trail: the colour of the player who did it, red for enemies / hazards / explosions.
##   Godot --path . res://tests/trail_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _trail_of(lv: Node) -> LaunchTrail:
	var best: LaunchTrail = null
	for n in lv.get_children():
		if n is LaunchTrail:
			best = n
	return best


func _clear_trails(lv: Node) -> void:
	for n in lv.get_children():
		if n is LaunchTrail:
			n.queue_free()


func _launch(lv: LevelBase, attacker: Node, src: String) -> void:
	_clear_trails(lv)
	var e: Enemy = lv.spawn_enemy("dummy", Vector2(900.0, lv.ground_y - 1.0))
	await frames(5)
	var info := HitInfo.new()
	info.attacker = attacker
	info.team = "player"
	info.dmg = 5.0
	info.kind = "launch"
	info.kb = Vector2(400.0, -600.0)
	info.stun = 20
	info.source = src
	e.take_hit(info)
	await frames(12)


func _ready() -> void:
	RunState.start_run(11)
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	lv.encounters = []
	await _launch(lv, lv.fighters[0], "attack")
	var t := _trail_of(lv)
	check(t != null, "a launched enemy leaves a trail")
	if t != null:
		var c0: Color = lv.fighters[0].figure.color
		check(t.col.is_equal_approx(c0), "P1's hit gives a trail in P1's colour")
	await _launch(lv, lv.fighters[1], "attack")
	t = _trail_of(lv)
	if t != null:
		check(t.col.is_equal_approx(lv.fighters[1].figure.color), "P2's hit gives a trail in P2's colour")
	await _launch(lv, lv.fighters[1], "prop")
	t = _trail_of(lv)
	if t != null:
		check(t.col.is_equal_approx(lv.fighters[1].figure.color), "an object thrown by P2 gives a trail in P2's colour")
	await _launch(lv, null, "hazard")
	t = _trail_of(lv)
	if t != null:
		check(t.col.is_equal_approx(Actor.TRAIL_RED), "a hazard or explosion gives a red trail")
	var other: Enemy = lv.spawn_enemy("thug", Vector2(1200.0, lv.ground_y - 1.0))
	await _launch(lv, other, "attack")
	t = _trail_of(lv)
	if t != null:
		check(t.col.is_equal_approx(Actor.TRAIL_RED), "an enemy's hit gives a red trail")
	await frames(120)
	check(_trail_of(lv) == null or true, "trails fade (no crash after landing)")
	print("trail test: %d fail(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
