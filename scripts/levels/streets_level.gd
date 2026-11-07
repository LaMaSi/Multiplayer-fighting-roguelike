class_name StreetsLevel
extends LevelBase
## Biome 1: Streets. Warm night, purple/orange neon. Thugs, bikers, bottle throwers, Big Boss.


func _setup() -> void:
	level_name = "Streets"
	level_w = 6800.0
	enemy_hp_mult = 1.0
	theme["sky_top"] = Color(0.12, 0.04, 0.26)
	theme["sky_bottom"] = Color(1.0, 0.36, 0.30)
	theme["neon_ground"] = Color(2.0, 0.7, 1.2)
	theme["neon_plat"] = Color(2.0, 1.2, 0.4)
	theme["bld_far"] = Color(0.45, 0.15, 0.40)
	theme["edge_mid"] = Color(2.0, 0.6, 0.3)
	theme["edge_near"] = Color(2.0, 0.4, 1.2)
	platforms = [
		Rect2(500, 470, 280, PLAT_H), Rect2(1000, 380, 240, PLAT_H),
		Rect2(1900, 470, 300, PLAT_H), Rect2(2300, 360, 260, PLAT_H),
		Rect2(3100, 470, 320, PLAT_H), Rect2(3550, 350, 260, PLAT_H),
		Rect2(4300, 470, 300, PLAT_H), Rect2(4700, 360, 300, PLAT_H),
		Rect2(5500, 460, 300, PLAT_H),
	]
	props_spec = [
		[420, "crate"], [470, "crate"], [620, "barrel", 470], [1100, "vase", 380], [1500, "barrel"], [1560, "crate"],
		[2000, "crate", 470], [2400, "barrel", 360], [2750, "vase"], [2800, "crate"],
		[3200, "barrel", 470], [3650, "crate", 350], [3950, "barrel"], [4000, "vase"],
		[4400, "crate", 470], [4800, "barrel", 360], [5200, "crate"], [5250, "vase"], [5600, "barrel", 460], [5900, "crate"],
	]
	encounters = [
		{"x": 1300.0, "waves": [[["thug", 2]], [["thug", 1], ["thrower", 1]]]},
		{"x": 2650.0, "waves": [[["thug", 2], ["biker", 1]], [["thrower", 1], ["thug", 1]]]},
		{"x": 3900.0, "waves": [[["biker", 2], ["thug", 1]], [["thrower", 2], ["thug", 2]]]},
		{"x": 5100.0, "waves": [[["thug", 3], ["biker", 1]], [["thrower", 2], ["biker", 1], ["thug", 1]]]},
		{"x": 6050.0, "boss": true, "waves": [[["boss_street", 1]]]},
	]
