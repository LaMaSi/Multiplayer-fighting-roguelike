extends Node
## RT dash phases through enemies / players; LB grabs.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _ready() -> void:
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(40)
	var f: Fighter = Coop.fighters[0]
	var other: Fighter = Coop.fighters[1]
	other.global_position = f.global_position + Vector2(-600, 0)
	f.facing = 1
	var d: Enemy = lv.spawn_enemy("dummy", f.global_position + Vector2(55, 0))
	await frames(20)
	var dx := d.global_position.x
	var x0 := f.global_position.x
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.DASH])
	await get_tree().physics_frame
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(6)
	await frames(24)
	check("dash phases through an enemy (x %.0f > %.0f)" % [f.global_position.x, dx], f.global_position.x > dx + 5.0)
	check("collisions restored afterwards", f.get_collision_mask_value(5))
	# grab with LB
	f.facing = 1
	await frames(30)
	d.global_position = Vector2(f.global_position.x + 35, f.global_position.y)
	await frames(5)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(14)
	check("LB starts the grab move", f.attack.move != null and f.attack.move.id == "grab_throw")
	check("enemy is grabbed", d.state == "grabbed")
	await frames(25)
	check("the grab holds until you throw (aiming)", f.attack.active and f.attack.aiming and d.state == "grabbed")
	f.input.script_set(Vector2(0, -1))
	await frames(3)
	f.input.script_set(Vector2(0, -1), [PlayerInput.Btn.X])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(3)
	check("pressing a button throws in the aimed direction (up: vy %.0f)" % d.velocity.y, d.state == "launched" and d.velocity.y < -300.0)

	# hit while grabbing: the grabbed enemy takes the blow, the grab ends, the grabber is invincible
	f.attack.interrupt()
	f.state = "idle"
	f.hp = f.max_hp
	f.invuln = 0.0
	f.facing = 1
	await frames(120)  # the thrown dummy lands and gets up
	d.state = "idle"
	d.velocity = Vector2.ZERO
	d.hit_chain = 0
	d.global_position = Vector2(f.global_position.x + 35, f.global_position.y)
	d.hp = d.max_hp
	await frames(5)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(30)
	check("(setup) grabbing the enemy again", f.attack.grabbed == d and d.state == "grabbed")
	var hp_f := f.hp
	var hp_d := d.hp
	var hi := HitInfo.new()
	hi.team = "enemy"
	hi.dmg = 10.0
	hi.kb = Vector2(-200, 0)
	hi.pos = f.global_position
	var took := f.take_hit(hi)
	check("the hit is absorbed", took)
	check("the grabber takes no damage", f.hp == hp_f)
	check("the grabbed enemy took the hit instead", d.hp < hp_d)
	check("the grab has ended", f.attack.grabbed == null and not f.attack.active and d.state != "grabbed")
	check("the grabber is invincible for a moment", f.invuln > 0.5)
	check("a second hit during the i-frames does nothing", not f.take_hit(hi) and f.hp == hp_f)

	# a KO'd player is not an obstacle
	other._on_defeated()
	check("downed player is non-solid", not other.get_collision_layer_value(3))
	other.revive()
	check("revived player is solid again", other.get_collision_layer_value(3))
	# batting an enemy projectile back
	f.attack.interrupt()
	f.state = "idle"
	await frames(40)
	var e := {"kind": "bottle", "pos": Vector2(0, -60), "vel": Vector2.ZERO, "dmg": 6.0, "stun": 12, "kb": Vector2(100, 0), "life": 3.0, "radius": 12.0, "color": Color.RED}
	Projectile.launch(d, e)
	var pr: Projectile = null
	for n in get_tree().get_nodes_in_group("projectiles"):
		pr = n
	pr.global_position = f.global_position + Vector2(f.facing * 40, -80)
	pr.vel = Vector2.ZERO
	pr.gravity = 0.0
	check("enemy projectile starts hostile", pr.team == "enemy")
	f.start_attack(MoveDB.get_move_for("jab", f.class_id), PlayerInput.Btn.B)
	await frames(14)
	check("swing bats the projectile back", pr.reflected and pr.team == "player")
	# LB picks up a crate and LB throws it
	f.state = "idle"
	f.attack.interrupt()
	f.facing = 1
	other.global_position = Vector2(f.global_position.x - 800.0, f.global_position.y)
	var crate := lv.spawn_prop("crate", Vector2(f.global_position.x + 30.0, f.global_position.y))
	await frames(15)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(5)
	check("LB picks up a crate", f.held == crate)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(3)
	var crate_vx: float = crate.velocity.x if is_instance_valid(crate) else 9999.0  # it may already have smashed into something
	check("LB throws it again (vx %.0f)" % crate_vx, f.held == null and crate_vx > 1000.0)
	# grab and throw the partner: a fast jump you can act out of
	f.state = "idle"
	f.attack.interrupt()
	f.facing = 1
	other.global_position = Vector2(f.global_position.x + 34.0, f.global_position.y)
	other.hp = other.max_hp
	await frames(10)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(40)
	check("LB grabs the partner", other.state == "grabbed" and f.attack.aiming)
	f.input.script_set(Vector2(1, 0))
	await frames(3)
	f.input.script_set(Vector2(1, 0), [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(4)
	check("LB again throws (partner flung, state %s, vx %.0f)" % [other.state, other.velocity.x], other._flung_t > 0.0 and other.velocity.x > 500.0)
	check("a flung partner is not falling helplessly", other.state in ["jump", "fall"])
	other.input.script_set(Vector2.ZERO, [PlayerInput.Btn.X])
	await frames(3)
	other.input.script_set(Vector2.ZERO, [])
	await frames(2)
	check("the flung partner can attack out of the motion", other.state == "attack")
	# a plain throw (no attacks) travels far enough to clear a pit
	for b in lv.get_children():
		if b is StaticBody2D and (b.collision_layer & 2) != 0:
			b.queue_free()  # no platforms in the way of the measurement
	other.attack.interrupt()
	other.input.script_set(Vector2.ZERO)
	await frames(120)
	f.state = "idle"
	f.attack.interrupt()
	f.facing = 1
	f.global_position = Vector2(500, 599)
	f.velocity = Vector2.ZERO
	other.global_position = Vector2(534, 599)
	other.velocity = Vector2.ZERO
	other.state = "idle"
	await frames(10)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	await frames(40)
	f.input.script_set(Vector2.ZERO, [PlayerInput.Btn.LB])
	await frames(2)
	f.input.script_set(Vector2.ZERO, [])
	var landed := 0
	for i in 220:
		await get_tree().physics_frame
		if other.is_on_floor() and i > 20:
			landed += 1
			if landed > 3:
				break
	check("a thrown partner travels far (%.0f px)" % (other.global_position.x - 534.0), other.global_position.x - 534.0 > 550.0)
	get_tree().quit()
