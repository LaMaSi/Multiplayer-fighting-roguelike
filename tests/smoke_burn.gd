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
	get_tree().quit()
