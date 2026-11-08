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
var perks: Array = [{}, {}]  ## per player: perk id -> true (e.g. "double_jump")
## Chosen weapon class per player ("brawler" / "sword" / "hammer" / "magic", "" = legacy fists). Set on the main
## menu and kept across runs; it is not reset by start_run.
var classes: Array = ["brawler", "brawler"]  ## Brawler is the plain-fists class; "" (no class) is only the legacy fighter used by old tests
var magic_unlocked := true  ## Magic is unlocked from the start (meta progression is not built yet); can still be toggled on the main menu for testing
var picker := 0  ## who picks first this round (alternates every level)
var queue: Array = []  ## [{player, kind: "move" | "level"}]
var bonus_picks: Array = []  ## extra picks earned in door rooms: appended to the next reward queue
var reroll_tokens := 0  ## team resource: spend one on the reward screen to reroll the offered picks. Earned by clearing fights.
var setup_rerolls: Array[int] = [2, 2]  ## rerolls of the starting moves, per player (run setup)
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
	perks = [{}, {}]
	picker = 0
	queue.clear()
	bonus_picks.clear()
	best_combo = 0
	reroll_tokens = 0
	setup_rerolls = [2, 2]
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	# classes: 3 random starred B moves + 1 random X + 1 random Y each, no reroll; class HP
	for i in 2:
		var cid: String = classes[i]
		if cid != "":
			loadouts[i] = ClassData.roll_loadout(cid, _rng)
			max_hp[i] = float(ClassData.get_class_data(cid)["hp"])
			hp[i] = max_hp[i]
	_generate()


## Re-rolls one player's starting moves (run setup only). Returns false when none are left.
func reroll_loadout(p: int) -> bool:
	if setup_rerolls[p] <= 0 or classes[p] == "":
		return false
	setup_rerolls[p] -= 1
	loadouts[p] = ClassData.roll_loadout(classes[p], _rng)
	return true


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
	f.double_jump = bool((perks[i] as Dictionary).get("double_jump", false))
	f.infusion = String((perks[i] as Dictionary).get("infuse", ""))


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
			if _rng.randf() < 0.6:
				reroll_tokens += 1
				Coop.say("+1 REROLL", Color(1.8, 1.6, 2.2))
		"elite":
			reroll_tokens += 1
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
	queue.append_array(bonus_picks)  # picks bought or won in door rooms
	bonus_picks.clear()
	picker = 1 - picker


# ------------------------------------------------------------------ reward cards

func make_cards(player: int, kind: String) -> Array:
	var cards: Array = []
	var cid: String = classes[player]
	if kind == "move":
		var owned: Array = (loadouts[player] as Dictionary).values()
		var pool: Array = []
		if cid == "":
			for id in MoveDB.POOL:
				if not (id in owned):
					pool.append(id)
		else:
			# shared pick: off-hand (X, universal) and adaptive (Y) moves. B moves come from personal level-ups.
			for id in ClassData.X_POOL + ClassData.Y_POOL:
				if not (id in owned):
					pool.append(id)
		_shuffle(pool)
		for id in pool.slice(0, 3):
			cards.append(_move_card(id, cid))
		return cards
	# level-up cards
	var eq: Array = []
	for id in (loadouts[player] as Dictionary).values():
		if not (id in eq):
			eq.append(id)
	_shuffle(eq)
	var kinds := ["hp", "dmg", "spd", "kb", "mend"]
	_shuffle(kinds)
	if not bool((perks[player] as Dictionary).get("double_jump", false)):
		kinds.insert(_rng.randi_range(0, 2), "djump")  # always among the first three candidates
	if String((perks[player] as Dictionary).get("infuse", "")) == "":
		kinds.insert(_rng.randi_range(0, 3), "infuse")  # elemental infusion: every attack carries fire, shock or frost
	if cid != "":
		var owned_b: Array = (loadouts[player] as Dictionary).values()
		var left: Array = []
		for id in (ClassData.get_class_data(cid)["b_pool"] as Array):
			if not (id in owned_b):
				left.append(id)
		if not left.is_empty():
			_shuffle(left)
			cards.append(_move_card(left[0], cid))  # a new weapon move is always on offer in the personal level-up
	var eq_i := 0
	for k in kinds:
		if cards.size() >= 3:
			break
		match k:
			"hp":
				cards.append({"kind": "hp", "tag": "LEVEL UP", "title": "+20 MAX HP", "desc": "Your health bar grows and you heal 20.", "extra": ""})
			"mend":
				cards.append({"kind": "mend", "tag": "RECOVER", "title": "FULL HEAL", "desc": "Restore all of your health.", "extra": ""})
			"djump":
				cards.append({"kind": "djump", "tag": "ABILITY", "title": "DOUBLE JUMP", "desc": "Press jump again in the air.", "extra": ""})
			"infuse":
				var el: String = ["fire", "shock", "frost"][_rng.randi() % 3]
				var el_text := {"fire": "Every attack sets enemies on fire.", "shock": "Every attack shocks: hits on shocked enemies arc to a neighbour.", "frost": "Every attack chills: three hits freeze an enemy solid."}
				cards.append({"kind": "infuse", "element": el, "tag": "INFUSION", "title": el.to_upper() + " INFUSION", "desc": String(el_text[el]), "extra": ""})
			_:
				if eq.is_empty():
					continue
				var id: String = eq[eq_i % eq.size()]
				eq_i += 1
				var m2 := MoveDB.get_move(id)
				cards.append({"kind": "up", "stat": k, "id": id, "tag": "EMPOWER", "title": m2.name, "desc": String(UP_TEXT[k]), "extra": ""})
	return cards


## A move reward card. Tier decides the slot row: universal -> X, adaptive -> Y, weapon -> B.
func _move_card(id: String, class_id: String) -> Dictionary:
	var m := MoveDB.get_move_for(id, class_id)
	var tier := ClassData.tier_of(id)
	var tag := "NEW MOVE"
	var row := -1
	match tier:
		"universal":
			tag = "OFF-HAND  (same for all)"
			row = 0
		"adaptive":
			tag = "ADAPTS TO YOUR WEAPON"
			row = 1
		"weapon":
			tag = "WEAPON MOVE"
			row = 2
	var card := {"kind": "move", "id": id, "tag": tag, "title": m.name, "desc": m.desc,
		"extra": ", ".join(m.tags) if m.tags.size() > 0 else "melee"}
	if row >= 0:
		card["row"] = row
	return card


func apply_card(player: int, card: Dictionary, slot := "") -> void:
	match String(card["kind"]):
		"move":
			(loadouts[player] as Dictionary)[slot] = card["id"]
		"hp":
			max_hp[player] += 20.0
			hp[player] = minf(max_hp[player], hp[player] + 20.0)
		"mend":
			hp[player] = max_hp[player]
		"djump":
			(perks[player] as Dictionary)["double_jump"] = true
		"infuse":
			(perks[player] as Dictionary)["infuse"] = String(card["element"])
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
