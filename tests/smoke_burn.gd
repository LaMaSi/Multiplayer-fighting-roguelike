extends Node
## Burning: ignite sets burn_t, burning targets take +30%, burn ticks damage.

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	print(("  PASS  " if ok else "  FAIL  "), name)


func _hit(dmg: float, ignite: float) -> HitInfo:
	var i := HitInfo.new()
	i.team = "player"
	i.dmg = dmg
	i.ignite = ignite
	i.kb = Vector2(10, 0)
	return i


func _ready() -> void:
	var lv: LevelBase = load("res://scenes/training.tscn").instantiate()
	add_child(lv)
	await frames(30)
	var d: Enemy = lv.spawn_enemy("dummy", Vector2(1500, 600))
	await frames(5)
	d.hp = d.max_hp
	d.take_hit(_hit(10.0, 0.0))
	var plain := d.max_hp - d.hp
	await frames(60)
	d.hp = d.max_hp
	d.take_hit(_hit(10.0, 2.0))
	check("ignite applies burning", d.burn_t > 0.0)
	await frames(60)
	d.hp = d.max_hp
	d.burn_t = 3.0
	d.take_hit(_hit(10.0, 0.0))
	var burning := d.max_hp - d.hp
	check("burning target takes +30%% (%.1f vs %.1f)" % [burning, plain], absf(burning - plain * 1.3) < 0.6)
	var hp0 := d.hp
	await frames(70)
	check("burn ticks damage", d.hp < hp0)
	# crates burn down; a burning TNT crate goes off
	var cr: Prop = lv.spawn_prop("crate", Vector2(1200, 599))
	await frames(10)
	var bi := HitInfo.new()
	bi.team = "player"
	bi.dmg = 1.0
	bi.ignite = 2.0
	bi.kb = Vector2(10, 0)
	bi.color = Color(0.3, 1.5, 1.8)
	cr.take_hit(bi)
	check("a hit with fire sets a crate burning", cr.burn_t > 0.0)
	await frames(330)
	check("the burning crate burns down", not is_instance_valid(cr) or cr.state == "dead")
	var tnt: Prop = lv.spawn_prop("explosive", Vector2(1500, 599))
	var bystander: Enemy = lv.spawn_enemy("thug", Vector2(1540, 599))
	await frames(60)
	var bh := bystander.hp
	tnt.take_hit(bi)
	await frames(300)
	check("a burning TNT crate eventually explodes and hurts neighbours", not is_instance_valid(bystander) or bystander.state == "dead" or bystander.hp < bh)
	# shock arcs, frost slows and freezes
	var s1: Enemy = lv.spawn_enemy("brute", Vector2(2200, 599))
	var s2: Enemy = lv.spawn_enemy("brute", Vector2(2300, 599))
	await frames(80)
	s1.max_hp = 99999.0
	s1.hp = 99999.0
	s2.max_hp = 99999.0
	s2.hp = 99999.0
	s1.invuln = 0.0
	s2.invuln = 0.0
	var h2 := s2.hp
	var shi := HitInfo.new()
	shi.team = "player"
	shi.dmg = 10.0
	shi.shock = 3.0
	shi.kb = Vector2(10, 0)
	s1.take_hit(shi)
	check("shock applies to the target", s1.shock_t > 0.0)
	await frames(40)
	var plain2 := HitInfo.new()
	plain2.team = "player"
	plain2.dmg = 10.0
	plain2.kb = Vector2(10, 0)
	s1.take_hit(plain2)
	await frames(5)
	check("a hit on a shocked enemy arcs to its neighbour (%.1f lost)" % (h2 - s2.hp), s2.hp < h2)
	var fz: Enemy = s2
	for i in 3:
		fz.invuln = 0.0
		var fi := HitInfo.new()
		fi.team = "player"
		fi.dmg = 1.0
		fi.frost = 2.0
		fi.kb = Vector2(5, 0)
		fz.take_hit(fi)
		await frames(30)
	check("three chilling hits freeze an enemy solid", fz.frozen_t > 0.0)
	fz.invuln = 0.0
	var fh := fz.hp
	fz.take_hit(plain2)
	check("a hit shatters the ice for extra damage and unfreezes", fz.frozen_t == 0.0 and fh - fz.hp > 11.0)
	get_tree().quit()
