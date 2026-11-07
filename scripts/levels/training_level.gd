class_name TrainingLevel
extends LevelBase
## Training room: a dummy, crates, platforms. The pause menu has spawn tools and the Move Lab.


func _setup() -> void:
	level_name = "Training Room"
	level_w = 3200.0
	platforms = [
		Rect2(400, 470, 260, PLAT_H), Rect2(800, 360, 260, PLAT_H), Rect2(1250, 470, 300, PLAT_H),
		Rect2(1700, 330, 300, PLAT_H), Rect2(2100, 450, 320, PLAT_H), Rect2(2600, 350, 260, PLAT_H),
	]
	props_spec = [[700, "crate"], [760, "barrel"], [1500, "vase"], [1560, "crate"], [2300, "barrel"], [1800, "crate", 330]]


func _ready() -> void:
	super._ready()
	spawn_enemy("dummy", Vector2(900, ground_y - 1.0))
