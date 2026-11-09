class_name OptionsList
## The game options shared by the start screen and the pause menu. Each item is
## [id, label, value text]; adjust() changes one (dx = -1 / +1, A counts as +1).

static func items() -> Array:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return [
		["fullscreen", "FULLSCREEN", "ON" if fs else "OFF"],
		["ff", "FRIENDLY FIRE", "ON" if Coop.friendly_fire else "OFF"],
		["ffscale", "FRIENDLY FIRE DAMAGE", "%d%%" % int(Coop.ff_scale * 100.0)],
		["moves", "SHOW MOVE GRID", "ON" if Hud.show_moves else "OFF"],
		["timescale", "TIME SCALE", "x%.2f" % Juice.user_time_scale],
		["impact", "HIT EXPLOSION SIZE", "%d%%" % int(Fx.impact_scale * 100.0)],
		["post", "SCREEN EFFECT", String(Post.PRESETS[Post.index]["name"]).to_upper()],
		["back", "BACK", ""],
	]


static func adjust(id: String, dx: int) -> void:
	match id:
		"fullscreen":
			Dbg.toggle_fullscreen()
		"ff":
			Coop.friendly_fire = not Coop.friendly_fire
		"ffscale":
			var opts := [0.25, 0.5, 0.75, 1.0]
			var i := opts.find(Coop.ff_scale)
			Coop.ff_scale = opts[posmod(i + dx, opts.size())]
		"moves":
			Hud.show_moves = not Hud.show_moves
		"timescale":
			# for experimenting with timings: 0.1x to 2x, applied to everything (hit-stop slow motion included)
			var steps: Array = Juice.TIME_STEPS
			var best := 0
			for k in steps.size():
				if absf(float(steps[k]) - Juice.user_time_scale) < absf(float(steps[best]) - Juice.user_time_scale):
					best = k
			Juice.set_user_time_scale(float(steps[clampi(best + dx, 0, steps.size() - 1)]))
		"impact":
			Fx.impact_scale = clampf(snappedf(Fx.impact_scale + 0.25 * dx, 0.25), 0.0, 3.0)
		"post":
			Post.set_preset(Post.index + dx, true)
