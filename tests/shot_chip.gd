extends Control
## Screenshot of the charge badge on a card-like panel.  Godot --path . res://tests/shot_chip.tscn -- <out.png>

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "chip.png"
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.03, 0.12))
	var ids := ["haymaker", "off_hand_jab", "uppercut", "guard_breaker", "fireball", "jab"]
	for i in ids.size():
		var r := Rect2(60.0 + float(i) * 200.0, 120.0, 190.0, 270.0)
		draw_rect(r, Color(0.09, 0.05, 0.17))
		draw_rect(r, Color(0.7, 0.9, 1.0, 0.4), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(12, 8), Vector2(166, 106)), Color(0.15, 0.1, 0.25))
		var m := MoveDB.get_move(String(ids[i]))
		UiKit.charge_chip(self, Rect2(r.position.x + 18.0, r.position.y + 12.0, 28.0, 28.0), m)
		UiKit.txt(self, UiKit.body(), Vector2(r.position.x, r.position.y + 166), m.name.to_upper(), 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 190.0)
		if not m.is_chargeable():
			UiKit.txt(self, UiKit.body(), Vector2(r.position.x, r.position.y + 70), "no badge", 14, UiKit.DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 190.0)
