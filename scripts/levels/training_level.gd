class_name TrainingLevel
extends LevelBase
## Training room: a dummy, crates, platforms. The pause menu has spawn tools and the Move Lab.


func _setup() -> void:
	level_name = "Training Room"
	level_w = 3200.0
	platforms = [
		Rect2(300, 470, 460, PLAT_H), Rect2(820, 410, 400, PLAT_H), Rect2(1280, 350, 360, PLAT_H),
		Rect2(1700, 470, 480, PLAT_H), Rect2(2240, 410, 420, PLAT_H), Rect2(2700, 350, 380, PLAT_H),
	]
	hazards_spec = [{"kind": "bumper", "x": 1950.0}, {"kind": "spring", "x": 1200.0}, {"kind": "spring", "x": 2450.0}]
	props_spec = [[700, "crate"], [760, "barrel"], [1500, "vase"], [1560, "crate"], [2300, "barrel"], [1800, "crate", 470], [1050, "explosive"], [1650, "explosive"]]


func _ready() -> void:
	super._ready()
	spawn_enemy("dummy", Vector2(900, ground_y - 1.0))
