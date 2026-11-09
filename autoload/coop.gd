extends Node
## Autoload "Coop": everything the two players share. The combo counter and relay bonus,
## friendly-fire setting, revive budget, enemy attack tokens and level bounds.

signal combo_changed
signal combo_ended(count: int, relays: int)
signal message(text: String, color: Color)
signal summon_requested(by: Actor, count: int)
signal game_over
signal level_cleared

const RELAY_COLOR := Color(2.2, 1.9, 0.6)

var friendly_fire := true
var ff_scale := 0.5
var fighters: Array[Fighter] = []
var bounds := Rect2(0, -1000, 3200, 2000)

var combo := 0
var relay := 0
var combo_t := 0.0
var hits_by: Array[int] = [0, 0]
var best_combo := 0
var _last_scorer := -1  ## player whose hit last raised the counter (the counter only rises on a hand-off)

var revives_left := 3
var revives_max := 3

## per-level stats for the level complete screen
var stat_damage := 0.0
var stat_relay_hits := 0
var stat_combo_coins := 0
var last_hit_pos := Vector2.ZERO
const COMBO_WINDOW := 2.2  # seconds to land the next hit (was 1.7): easier to chain alone
var stat_rescues := 0
var stat_containers := 0
var stat_containers_total := 0
var stat_time := 0.0
var is_over := false

var enemy_hp_mult := 1.0
var enemy_dmg_mult := 1.0
var tokens_max := 2
var _tokens: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func reset_run() -> void:
	fighters.clear()
	combo = 0
	relay = 0
	combo_t = 0.0
	hits_by = [0, 0]
	best_combo = 0
	_last_scorer = -1
	revives_max = 3 + (RunState.bonus_revives if RunState.active else 0)
	revives_left = revives_max
	stat_damage = 0.0
	stat_relay_hits = 0
	stat_combo_coins = 0
	stat_rescues = 0
	stat_containers = 0
	stat_containers_total = 0
	stat_time = 0.0
	is_over = false
	enemy_hp_mult = 1.0
	enemy_dmg_mult = 1.0
	_tokens.clear()


func partner_of(a: Actor) -> Fighter:
	for f in fighters:
		if f != a and is_instance_valid(f):
			return f
	return null


func _process(delta: float) -> void:
	if combo > 0:
		combo_t -= delta
		if combo_t <= 0.0:
			var c := combo
			var r := relay
			combo = 0
			relay = 0
			hits_by = [0, 0]
			_last_scorer = -1
			_pay_combo(c, r)
			combo_ended.emit(c, r)
			combo_changed.emit()


## Damage multiplier of the running combo: +8 % per team hand-off (up to 15) and +25 % per relay (up to 4). Long team combos
## are what kills the tanky enemies quickly.
func combo_mult() -> float:
	if RunState.solo:
		return 1.0  # team combo bonus disabled while playtesting alone
	return 1.0 + 0.25 * minf(relay, 4) + 0.08 * minf(combo, 15)


## Coins for a finished combo (paid into the shared wallet once its timer runs out).
func combo_coins(count: int, relays: int) -> int:
	return int(maxf(0.0, count - 4.0) * 2.0) + relays * 3


func _pay_combo(count: int, relays: int) -> void:
	var n := combo_coins(count, relays)
	if n <= 0 or not RunState.active:
		return
	RunState.coins += n
	stat_combo_coins += n
	say("+%d COINS" % n, Color(2.0, 1.7, 0.4), last_hit_pos + Vector2(0, -150))


## Called before damage is applied: relay / alley-oop detection and combo damage scaling.
func pre_hit(info: HitInfo, victim: Actor) -> void:
	if info.no_combo or info.friendly or not (info.attacker is Fighter) or victim.team != "enemy":
		return
	var lh := victim.last_hitter
	if victim.state == "launched" and lh is Fighter and lh != info.attacker:
		info.relay = true
		info.dmg *= 1.5
		info.stop += 4
		info.color = RELAY_COLOR
		if info.kind == "spike":
			info.alley_oop = true
			info.dmg *= 1.5
			info.shake += 0.2
	info.dmg *= combo_mult()
	_aim_at_partner(info)


func post_hit(info: HitInfo, victim: Actor, dmg: float) -> void:
	if info.no_combo or info.friendly or not (info.attacker is Fighter) or victim.team != "enemy":
		return
	var atk := info.attacker as Fighter
	_count_hit(atk.player_index)
	hits_by[atk.player_index] += 1
	last_hit_pos = victim.global_position
	atk.meter = minf(100.0, atk.meter + dmg * 0.7)
	if info.relay:
		relay += 1
		stat_relay_hits += 1
		atk.meter = minf(100.0, atk.meter + 8.0)
		say("ALLEY-OOP!" if info.alley_oop else "RELAY x%d" % relay, RELAY_COLOR, victim.global_position + Vector2(0, -130))
		Juice.shake(0.25)
	combo_changed.emit()


## Extra damage that should still feed the combo (wall bounce, pinball ...).
func bonus_hit(attacker: Actor, victim: Actor, _dmg: float) -> void:
	if attacker is Fighter and victim.team == "enemy":
		_count_hit((attacker as Fighter).player_index)
		hits_by[(attacker as Fighter).player_index] += 1
		combo_changed.emit()


## Keywords and exclamations (PINBALL!, CLASH!, WALL BOUNCE! ...) never appear in the fighting scene: the HUD stacks them
## next to the combo counter, each with its own tilt.
signal callout_made(text: String, color: Color)


func callout(text: String, color: Color) -> void:
	callout_made.emit(text, color)


func say(text: String, color: Color, pos := Vector2.INF) -> void:
	message.emit(text, color)
	if pos != Vector2.INF and get_tree().current_scene != null:
		Fx.number(get_tree().current_scene, pos, text, color, 26)


# ---- enemy attack tokens (limits how many enemies attack at once) ----

func request_token(e: Node) -> bool:
	_tokens = _tokens.filter(func(x): return is_instance_valid(x))
	if e in _tokens:
		return true
	if _tokens.size() < tokens_max:
		_tokens.append(e)
		return true
	return false


func release_token(e: Node) -> void:
	_tokens.erase(e)


func check_game_over() -> void:
	if is_over or fighters.is_empty():
		return
	for f in fighters:
		if f.state != "downed" and f.state != "dead":
			return
	is_over = true
	game_over.emit()


## The counter is a TEAM counter: the first hit starts it, after that it only rises when a different player than the
## last scorer lands a hit. Solo hits (fireball spam) just keep the window alive.
func _count_hit(player: int) -> void:
	combo_t = COMBO_WINDOW
	if combo == 0 or player != _last_scorer:
		combo += 1
		_last_scorer = player
		best_combo = maxi(best_combo, combo)


## Predictable set-ups: a hit that knocks an enemy toward the other player is nudged (never more than -25 % / +35 %) so
## the enemy lands close in front of the partner. Position yourself so the partner is on the knockback side.
func _aim_at_partner(info: HitInfo) -> void:
	if info.kind == "pull" or absf(info.kb.x) < 60.0:
		return
	var p := partner_of(info.attacker as Actor)
	if p == null or not p.is_alive() or p.state == "downed":
		return
	var atk := info.attacker as Actor
	var d := p.global_position.x - atk.global_position.x
	if signf(d) != signf(info.kb.x) or absf(d) < 220.0 or absf(d) > 1100.0:
		return
	var air := 0.25
	if info.kb.y < -200.0:
		air = 2.0 * absf(info.kb.y) / 2300.0
	var travel := absf(info.kb.x) * air
	if travel < 40.0:
		return
	var want := absf(d) - 110.0  # land just in front of the partner
	info.kb.x *= clampf(want / travel, 0.75, 1.35)
