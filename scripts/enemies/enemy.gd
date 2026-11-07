class_name Enemy
extends Actor
## Data-driven enemy. All attacks are MoveData played by the same AttackRunner as the players',
## each with a visible telegraph. A token system (Coop) limits how many attack at once.

signal defeated(e: Enemy)

const DEFS := {
	"dummy": {"name": "Training Dummy", "hp": 99999.0, "speed": 0.0, "color": Color(1.6, 1.6, 1.8), "style": "", "ai": "dummy", "attacks": []},
	"thug": {"name": "Thug", "hp": 55.0, "speed": 150.0, "color": Color(1.3, 0.3, 0.08), "style": "cap", "ai": "melee", "build": {"limb": 1.55, "head": 1.05, "fill": true, "square": true},
		"attacks": ["e_punch", "e_double"], "range": 62.0, "cd": 1.5},
	"biker": {"name": "Biker", "hp": 75.0, "speed": 200.0, "color": Color(1.4, 0.25, 0.1), "style": "helmet", "ai": "charger", "build": {"limb": 1.3, "head": 1.3, "fill": true, "square": false},
		"attacks": ["e_charge"], "range": 0.0, "cd": 2.2},
	"thrower": {"name": "Bottle Thrower", "hp": 40.0, "speed": 130.0, "color": Color(1.1, 0.1, 0.25), "style": "hood", "ai": "ranged", "build": {"limb": 0.8, "head": 0.9, "fill": false, "square": true},
		"attacks": ["e_throw"], "range": 0.0, "cd": 2.4},
	# few and tanky is the norm: brutes and heavies soak a long team combo; they still launch and juggle
	"brute": {"name": "Brute", "hp": 230.0, "speed": 110.0, "color": Color(1.35, 0.15, 0.35), "style": "helmet", "ai": "melee", "build": {"limb": 1.8, "head": 1.15, "fill": true, "square": true},
		"attacks": ["e_punch", "e_double"], "range": 72.0, "cd": 1.9, "scale": 1.25, "dmg": 1.35},
	"heavy": {"name": "Heavy", "hp": 340.0, "speed": 90.0, "color": Color(1.2, 0.2, 0.9), "style": "horns", "ai": "melee", "build": {"limb": 2.0, "head": 1.2, "fill": true, "square": true},
		"attacks": ["e_double", "e_punch"], "range": 78.0, "cd": 2.3, "scale": 1.4, "dmg": 1.6},
	"boss_street": {"name": "Big Boss", "hp": 750.0, "speed": 120.0, "color": Color(1.45, 0.08, 0.08), "style": "crown", "ai": "boss", "build": {"limb": 1.9, "head": 1.1, "fill": true, "square": true},
		"attacks": ["boss_swing", "boss_slam", "boss_charge"], "range": 100.0, "cd": 1.0, "scale": 1.5, "resist": true, "boss": true},
}

var kind := "thug"
var def: Dictionary = {}
var target: Fighter = null

var _cd := 1.0
var _has_token := false
var _strafe := 1.0
var _strafe_t := 0.0
var _drop_t := 0.0
var _regen_t := 0.0
var _summoned: Array[bool] = [false, false]
var _aggro := false


func _configure() -> void:
	def = DEFS[kind]
	team = "enemy"
	max_hp = float(def["hp"]) * Coop.enemy_hp_mult
	hp = max_hp
	run_speed = float(def["speed"])
	body_scale = float(def.get("scale", 1.0))
	launch_resist = bool(def.get("resist", false))
	no_grab = bool(def.get("boss", false))
	_cd = randf_range(0.6, 1.6)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	super._ready()
	figure.color = def["color"]
	figure.style = String(def["style"])
	var bd: Dictionary = def.get("build", {})
	figure.limb_scale = float(bd.get("limb", 1.0))
	figure.head_scale = float(bd.get("head", 1.0))
	figure.fill_torso = bool(bd.get("fill", false))
	figure.square_head = bool(bd.get("square", false))
	figure.set_target(PoseLib.idle_enemy(0.0), true)
	if def["ai"] != "dummy":
		invuln = 0.5
	if bool(def.get("boss", false)):
		add_to_group("boss")


func _loco_pose() -> Dictionary:
	if state == "walk":
		return PoseLib.walk_enemy(_walk_phase)
	return PoseLib.idle_enemy(Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 7))


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	queue_redraw()


func _draw() -> void:
	if def.get("ai", "") == "dummy" or hp >= max_hp * 0.999 or bool(def.get("boss", false)):
		return
	var w := 46.0 * body_scale
	var y := -body_h * body_scale - 16.0
	draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color(1.0, 0.35, 0.3))


func telegraph() -> void:
	figure.modulate = Color(1.5, 0.75, 0.75, figure.modulate.a)
	# the marker shows the attack height: amber "^" = HIGH (crouch under it), orange "v" = LOW (jump it), red "!" = MID
	var h := "mid"
	if attack.move != null and not attack.move.hits.is_empty():
		var h0: Dictionary = attack.move.hits[0]
		h = String(h0.get("height", "low" if bool(h0.get("low", false)) else "mid"))
	var mark := "!"
	var mc := Color(2.5, 0.5, 0.4)
	if h == "high":
		mark = "^"
		mc = Color(2.4, 2.0, 0.3)
	elif h == "low":
		mark = "v"
		mc = Color(2.4, 1.1, 0.3)
	Fx.number(get_parent(), global_position + Vector2(0, -body_h * body_scale - 14.0), mark, mc, 34)
	Sfx.play("ui", 0.6)


func on_attack_end(m: MoveData) -> void:
	super.on_attack_end(m)
	_release_token()
	figure.modulate = Color(1, 1, 1, figure.modulate.a)
	state = "idle"


func _release_token() -> void:
	if _has_token:
		_has_token = false
		Coop.release_token(self)


func _on_damaged(_info: HitInfo) -> void:
	_release_token()
	_aggro = true
	if def["ai"] == "dummy":
		_regen_t = 3.0


func _fell_out() -> void:
	_release_token()
	state = "dead"
	defeated.emit(self)
	queue_free()


func _on_defeated() -> void:
	_release_token()
	state = "dead"
	var parent := get_parent()
	var pos := global_position + Vector2(0, -45.0 * body_scale)
	Fx.shatter(parent, pos, figure.color, 26)
	Fx.impact(parent, pos, figure.color, 1.6)
	Sfx.play("death")
	Juice.shake(0.3 if not bool(def.get("boss", false)) else 0.8)
	if bool(def.get("boss", false)):
		Juice.slowmo(0.25, 0.5)
		Juice.zoom_punch(0.1)
		Pickup.spawn(parent, global_position, "hp_m")
		Pickup.spawn(parent, global_position, "hp_m")
		Pickup.spawn(parent, global_position, "meter")
	defeated.emit(self)
	queue_free()


# ------------------------------------------------------------------ AI

func _pick_target() -> void:
	var best: Fighter = null
	var bd := INF
	for f in Coop.fighters:
		if f.is_alive() and f.state != "downed":
			var d := absf(f.global_position.x - global_position.x) + absf(f.global_position.y - global_position.y)
			if d < bd:
				bd = d
				best = f
	target = best


func _control(delta: float) -> void:
	if def["ai"] == "dummy":
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		velocity.y = 50.0 if is_on_floor() else minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		state = "idle"
		_regen_t -= delta
		if _regen_t <= 0.0 and hp < max_hp:
			hp = max_hp
		return
	_pick_target()
	_cd -= delta
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(0.8, 2.0)
		_strafe = 1.0 if randf() < 0.5 else -1.0
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			set_collision_mask_value(2, true)

	var want_x := 0.0  # desired horizontal velocity
	if target != null:
		var dx := target.global_position.x - global_position.x
		var dy := target.global_position.y - global_position.y
		var adx := absf(dx)
		var dir := signf(dx) if dx != 0.0 else float(facing)
		facing = int(dir)
		match String(def["ai"]):
			"melee": want_x = _ai_melee(dir, adx, dy, delta)
			"charger": want_x = _ai_charger(dir, adx, dy)
			"ranged": want_x = _ai_ranged(dir, adx, dy)
			"boss": want_x = _ai_boss(dir, adx, dy)
		# vertical: jump up to platforms / drop down
		if is_on_floor() and state != "attack":
			if dy < -90.0 and adx < 170.0 and randf() < 0.03:
				velocity.y = -880.0
			elif dy > 110.0 and adx < 220.0 and _drop_t <= 0.0:
				_drop_t = 0.4
				set_collision_mask_value(2, false)
				global_position.y += 2.0
	if state == "attack":
		return
	want_x = clampf(want_x, -run_speed, run_speed) * crowd_mult()  # enemies pass each other (and the players), slowed while overlapping
	velocity.x = move_toward(velocity.x, want_x, 2200.0 * delta)
	if is_on_floor():
		velocity.y = 50.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	global_position.x = clampf(global_position.x, Coop.bounds.position.x + 20.0, Coop.bounds.end.x - 20.0)
	if absf(velocity.x) > 20.0:
		state = "walk"
		_walk_phase += absf(velocity.x) * 0.05 * delta
	else:
		state = "idle"


func _begin(id: String) -> void:
	var m := MoveDB.get_move(id)
	if m == null:
		return
	velocity.x = 0.0
	start_attack(m)


func _ai_melee(dir: float, adx: float, dy: float, _delta: float) -> float:
	var rng := float(def["range"])
	var level := absf(dy) < 60.0
	if _has_token or (_cd <= 0.0 and adx < 340.0 and Coop.request_token(self)):
		_has_token = true
		if adx > rng and level:
			return dir * run_speed
		if adx <= rng + 8.0 and level:
			var attacks: Array = def["attacks"]
			_begin(attacks[randi() % attacks.size()])
			_cd = float(def["cd"]) * randf_range(0.8, 1.3)
			return 0.0
		return dir * run_speed * 0.8
	# no token: hover at a distance and shuffle
	if adx > 260.0:
		return dir * run_speed * 0.8
	if adx < 150.0:
		return -dir * run_speed * 0.7
	return _strafe * run_speed * 0.35


func _ai_charger(dir: float, adx: float, dy: float) -> float:
	var aligned := absf(dy) < 50.0
	if _cd <= 0.0 and adx > 200.0 and adx < 620.0 and aligned and Coop.request_token(self):
		_has_token = true
		_begin("e_charge")
		_cd = float(def["cd"]) * randf_range(0.9, 1.4)
		return 0.0
	if adx < 260.0:
		return -dir * run_speed * 0.8
	if adx > 480.0:
		return dir * run_speed * 0.8
	return _strafe * run_speed * 0.3


func _ai_ranged(dir: float, adx: float, dy: float) -> float:
	if _cd <= 0.0 and adx > 240.0 and adx < 760.0 and Coop.request_token(self):
		_has_token = true
		_begin("e_throw")
		_cd = float(def["cd"]) * randf_range(0.9, 1.4)
		return 0.0
	if adx < 330.0:
		return -dir * run_speed
	if adx > 560.0:
		return dir * run_speed * 0.8
	return _strafe * run_speed * 0.3


func _ai_boss(dir: float, adx: float, _dy: float) -> float:
	var frac := hp / max_hp
	if _cd <= 0.0:
		if not _summoned[0] and frac < 0.66:
			_summoned[0] = true
			_begin("boss_summon")
			_cd = 2.0
			return 0.0
		if not _summoned[1] and frac < 0.33:
			_summoned[1] = true
			_begin("boss_summon")
			_cd = 2.0
			return 0.0
		var roll := randf()
		if adx < 190.0:
			_begin("boss_slam" if roll < 0.4 else "boss_swing")
			_cd = randf_range(0.9, 1.5)
			return 0.0
		if adx > 340.0:
			_begin("boss_charge")
			_cd = randf_range(1.4, 2.0)
			return 0.0
	if adx > 150.0:
		return dir * run_speed
	return -dir * run_speed * 0.3


func dmg_mult() -> float:
	return super.dmg_mult() * float(def.get("dmg", 1.0))
