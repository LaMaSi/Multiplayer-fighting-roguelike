extends Node
## Screenshot: the projectile shapes side by side and a burning enemy.  Godot --path . res://tests/shot_fx.tscn -- <out.png>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "fx.png"
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	for i in 30:
		await get_tree().process_frame
	var f: Fighter = Coop.fighters[0]
	Coop.fighters[1].global_position = f.global_position + Vector2(-600, 0)
	f.global_position = Vector2(1000, 599)
	for n in get_tree().get_nodes_in_group("hurt_enemy"):
		if n is Enemy:
			n.queue_free()
	var shapes := ["fireball", "spark", "dart", "blade", "quake", "orb"]
	var i := 0
	for s in shapes:
		var p := Projectile.new()
		p.owner_actor = f
		p.shape = s
		p.radius = 14.0
		p.col = f.figure.color
		p.vel = Vector2(1.0, 0.0)  # near-static: just for drawing
		p.life = 99.0
		p.global_position = Vector2(1060 + i * 90, 520 if s != "quake" else 590)
		p.set_physics_process(false)
		lv.add_child(p)
		p.queue_redraw()
		i += 1
	var d: Enemy = lv.spawn_enemy("thug", Vector2(1650, 599))
	d.set_physics_process(false)
	var hi := HitInfo.new()
	hi.team = "player"
	hi.dmg = 1.0
	hi.ignite = 5.0
	hi.color = f.figure.color
	hi.kb = Vector2(5, 0)
	d.invuln = 0.0
	d.take_hit(hi)
	for k in 30:
		await get_tree().process_frame
		d._tick_burn(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
