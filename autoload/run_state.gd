extends Node
## Autoload "RunState": one run = a branching node map through the Streets biome.
## Holds what persists between levels: both players' loadouts, max HP / HP, move upgrades,
## the map position and the queue of reward picks. Reward card creation / application lives here
## too so it can be tested without any UI.

const TYPE_NAMES := {"fight": "FIGHT", "elite": "ELITE", "treasure": "LOOT", "rest": "REST", "mystery": "???", "boss": "BOSS", "shop": "SHOP"}
const LAYER_SIZES := [2, 3, 3, 3, 2, 1]  ## the last layer is the boss
const UP_MULT := {"dmg": 1.25, "spd": 1.2, "kb": 1.3}
const UP_TEXT := {"dmg": "+25% damage", "spd": "+20% attack speed (shorter recovery)", "kb": "+30% knockback"}

var active := false
var coins := 0  ## one shared wallet for the whole run
var bonus_revives := 0  ## extra shared lives bought in shops (added to every level)
var map: Array = []  ## layers of node dictionaries {layer, idx, type, seed, next: [idx], done}
var pos := Vector2i(-1, 0)  ## (-1, 0) = before the first layer
var current: Dictionary = {}
var levels_cleared := 0
var loadouts: Array = [{}, {}]
var max_hp: Array = [100.0, 100.0]
var hp: Array = [100.0, 100.0]
var upgrades: Array = [{}, {}]  ## per player: move_id -> {dmg, spd, kb}
var picker := 0  ## who picks first this round (alternates every level)
var queue: Array = []  ## [{player, kind: "move" | "level"}]
var finished := false
var won := false
var best_combo := 0
var _rng := RandomNumberGenerator.new()


func start_run(seed_value := -1) -> void:
	active = true
	finished = false
	won = false
	levels_cleared = 0
	coins = 0
	bonus_revives = 0
	pos = Vector2i(-1, 0)
	current = {}
	loadouts = [MoveDB.STARTER.duplicate(), MoveDB.STARTER.duplicate()]
	max_hp = [100.0, 100.0]
	hp = [100.0, 100.0]
	upgrades = [{}, {}]
	picker = 0
	queue.clear()
	best_combo = 0
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_generate()


func end_run() -> void:
	active = false


# ------------------------------------------------------------------ map

func _roll_type(layer: int) -> String:
	var weights := {"fight": 5.0, "treasure": 1.5, "rest": 1.2, "mystery": 1.5, "elite": 1.4 if layer >= 2 else 0.0, "shop": 1.6 if layer >= 1 else 0.0}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "fight"


func _generate() -> void:
	map = []
	for l in LAYER_SIZES.size():
		var layer: Array = []
		for i in LAYER_SIZES[l]:
			var t := "boss" if l == LAYER_SIZES.size() - 1 else ("fight" if l == 0 else _roll_type(l))
			layer.append({"layer": l, "idx": i, "type": t, "seed": _rng.randi(), "next": [], "done": false})
		map.append(layer)
	# guarantee a rest stop right before the boss
	var pen: Array = map[LAYER_SIZES.size() - 2]
	var has_rest := false
	for n in pen:
		if n["type"] == "rest":
			has_rest = true
	if not has_rest:
		pen[_rng.randi() % pen.size()]["type"] = "rest"
	# links to the next layer
	for l in LAYER_SIZES.size() - 1:
		var a: Array = map[l]
		var b: Array = map[l + 1]
		for n in a:
			var center := float(n["idx"]) / maxf(a.size() - 1, 1) * (b.size() - 1)
			var targets: Array = []
			var want := 1 + (1 if _rng.randf() < 0.45 else 0)
			var tries := 0
			while targets.size() < want and tries < 8:
				tries += 1
				var ti := clampi(int(round(center)) + _rng.randi_range(-1, 1), 0, b.size() - 1)
				if not (ti in targets):
					targets.append(ti)
			n["next"] = targets
		for m in b:
			var reached := false
			for n in a:
				if int(m["idx"]) in n["next"]:
					reached = true
			if not reached:
				var best: Dictionary = a[0]
				var bd := 99.0
				for n in a:
					var d := absf(float(n["idx"]) / maxf(a.size() - 1, 1) - float(m["idx"]) / maxf(b.size() - 1, 1))
					if d < bd:
						bd = d
						best = n
				best["next"].append(int(m["idx"]))


func available_next() -> Array:
	var out: Array = []
	if pos.x < 0:
		for n in map[0]:
			out.append(n)
	elif pos.x + 1 < map.size():
		for i in current["next"]:
			out.append(map[pos.x + 1][i])
	return out


## Enter a node. Mystery nodes reveal their real type here. Returns the node type.
func choose(node: Dictionary) -> String:
	if node["type"] == "mystery":
		var r := _rng.randf()
		node["type"] = "fight" if r < 0.4 else ("treasure" if r < 0.65 else ("elite" if r < 0.85 else "rest"))
		node["was_mystery"] = true
	pos = Vector2i(int(node["layer"]), int(node["idx"]))
	current = node
	return String(node["type"])


# ------------------------------------------------------------------ player state

func apply_to(f: Fighter) -> void:
	var i := f.player_index
	f.loadout = (loadouts[i] as Dictionary).duplicate()
	f.max_hp = max_hp[i]
	f.hp = clampf(hp[i], 1.0, max_hp[i])
	f.upgrades = (upgrades[i] as Dictionary).duplicate(true)


func save_from(fighters: Array) -> void:
	for f in fighters:
		var i: int = f.player_index
		loadouts[i] = f.loadout.duplicate()
		hp[i] = f.hp if (f.hp > 0.0 and f.state != "downed") else max_hp[i] * 0.3
	best_combo = maxi(best_combo, Coop.best_combo)


## Called when a level is cleared: partial heal, queue the rewards, alternate the first picker.
func level_cleared(bonus_heal := 0.0) -> void:
	levels_cleared += 1
	current["done"] = true
	for i in 2:
		hp[i] = minf(max_hp[i], hp[i] + max_hp[i] * 0.25 + bonus_heal)
	_queue_rewards(String(current["type"]))
	if current["type"] == "boss":
		finished = true
		won = true


## Leaving a shop: the node is done and no reward queue follows.
func shop_done() -> void:
	current["done"] = true
	queue.clear()


func rest_here() -> void:
	current["done"] = true
	for i in 2:
		hp[i] = minf(max_hp[i], hp[i] + max_hp[i] * 0.6)
	_queue_rewards("rest")


func _queue_rewards(type: String) -> void:
	queue.clear()
	var order := [picker, 1 - picker]
	match type:
		"fight":
			for p in order:
				queue.append({"player": p, "kind": "move" if _rng.randf() < 0.55 else "level"})
		"elite":
			for p in order:
				queue.append({"player": p, "kind": "move"})
			for p in order:
				queue.append({"player": p, "kind": "level"})
		"boss":
			for p in order:
				queue.append({"player": p, "kind": "move"})
			for p in order:
				queue.append({"player": p, "kind": "level"})
		_:
			for p in order:
				queue.append({"player": p, "kind": "level"})
	picker = 1 - picker


# ------------------------------------------------------------------ reward cards

func make_cards(player: int, kind: String) -> Array:
	var cards: Array = []
	if kind == "move":
		var owned: Array = (loadouts[player] as Dictionary).values()
		var pool: Array = []
		for id in MoveDB.POOL:
			if not (id in owned):
				pool.append(id)
		_shuffle(pool)
		for id in pool.slice(0, 3):
			var m := MoveDB.get_move(id)
			cards.append({"kind": "move", "id": id, "tag": "NEW MOVE", "title": m.name, "desc": m.desc,
				"extra": ", ".join(m.tags) if m.tags.size() > 0 else "melee"})
		return cards
	# level-up cards
	var eq: Array = []
	for id in (loadouts[player] as Dictionary).values():
		if not (id in eq):
			eq.append(id)
	_shuffle(eq)
	var kinds := ["hp", "dmg", "spd", "kb", "mend"]
	_shuffle(kinds)
	var eq_i := 0
	for k in kinds:
		if cards.size() >= 3:
			break
		match k:
			"hp":
				cards.append({"kind": "hp", "tag": "LEVEL UP", "title": "+20 MAX HP", "desc": "Your health bar grows and you heal 20.", "extra": ""})
			"mend":
				cards.append({"kind": "mend", "tag": "RECOVER", "title": "FULL HEAL", "desc": "Restore all of your health.", "extra": ""})
			_:
				if eq.is_empty():
					continue
				var id: String = eq[eq_i % eq.size()]
				eq_i += 1
				var m2 := MoveDB.get_move(id)
				cards.append({"kind": "up", "stat": k, "id": id, "tag": "EMPOWER", "title": m2.name, "desc": String(UP_TEXT[k]), "extra": ""})
	return cards


func apply_card(player: int, card: Dictionary, slot := "") -> void:
	match String(card["kind"]):
		"move":
			(loadouts[player] as Dictionary)[slot] = card["id"]
		"hp":
			max_hp[player] += 20.0
			hp[player] = minf(max_hp[player], hp[player] + 20.0)
		"mend":
			hp[player] = max_hp[player]
		"up":
			var u: Dictionary = upgrades[player]
			if not u.has(card["id"]):
				u[card["id"]] = {"dmg": 1.0, "spd": 1.0, "kb": 1.0}
			var s: String = card["stat"]
			u[card["id"]][s] = float(u[card["id"]][s]) * float(UP_MULT[s])


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
