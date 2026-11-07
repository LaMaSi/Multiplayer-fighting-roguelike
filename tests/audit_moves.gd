extends SceneTree
## Prints a frame-data table of every player move, flagging very short / unclear ones.
func _init() -> void:
	var rows: Array = []
	for id in MoveDB.all_player_moves():
		var m: MoveData = MoveDB.get_move(id)
		if m == null:
			continue
		var first := 9999
		var last := 0
		var area := 0.0
		for h in m.hits:
			first = mini(first, int(h["at"]))
			last = maxi(last, int(h["at"]) + int(h["dur"]))
			var b: Rect2 = h["box"]
			area = maxf(area, b.size.x * b.size.y)
		var proj := false
		for e in m.events:
			if String(e.get("type", "")) == "proj":
				proj = true
		rows.append([id, m.total, first if first < 9999 else -1, last - first if last > 0 else 0, int(area), m.hits.size(), proj, m.tier])
	rows.sort_custom(func(a, b): return a[1] < b[1])
	print("id | total | first hit | active span | max box area | hits | projectile | tier")
	for r in rows:
		print("%s | %d | %d | %d | %d | %d | %s | %s" % r)
	quit()
