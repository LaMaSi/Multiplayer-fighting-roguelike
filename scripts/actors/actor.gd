class_name Actor
extends CharacterBody2D
## Shared base for fighters and enemies: HP, hit reactions (hurt / launched / down / get-up),
## juggling, grabs, attack playback, buffs and the stickfigure visuals.
## Origin = feet. Collision layers: 1 ground, 2 platforms, 3 players, 4 enemies.

const GRAVITY := 2300.0
const MAX_FALL := 1700.0
const NO_GRAB_STATES := ["launched", "down", "dead", "grabbed", "tossed", "getup", "downed"]

var team := "enemy"
var max_hp := 100.0
var hp := 100.0
var burn_t := 0.0  ## seconds of burning left: ticks damage, and burning targets take BURN_BONUS more from everything
var shock_t := 0.0  ## shocked: hits on this target arc to a neighbour (40 % damage)
var frost_t := 0.0  ## chilled: slowed; three chilling hits freeze it solid
var frost_stacks := 0
var frozen_t := 0.0  ## frozen solid: cannot act; the next hit shatters the ice for +40 % damage
var infusion := ""  ## "fire" | "shock" | "frost": every attack of this fighter carries the element (level-up card)
var status_col := Color(2.2, 0.9, 0.3)
var _burn_tick := 0.0
const BURN_BONUS := 1.3
var facing := 1
var state := "idle"
var freeze := 0
var stun_frames := 0
var invuln := 0.0
var armor_t := 0.0
var guard_t := 0
var parry_t := 0
var reflect_t := 0
var flash_t := 0.0
var run_speed := 330.0
var move_input_x := 0.0
var body_w := 34.0
var body_h := 86.0
var body_scale := 1.0
var launch_resist := false
var no_grab := false
var kill_y := 2200.0

var figure: StickFigure
var attack: AttackRunner
var last_hitter: Actor = null
var juggle_hits := 0
var hit_chain := 0  ## hits taken back to back without getting to act (enemies): feeds the combo breaker
var _chain_t := 0.0
const LAND_STAGGER := 18  ## frames an enemy reels after landing from a launch (it is not knocked down)
const MIN_HITSTOP := 3 ## frames every involved character holds still when a hit connects
const CHAIN_BREAK := 14  # after this many hits in a row the enemy breaks out (short invulnerability + shove)
var buffs: Dictionary = {}
var upgrades: Dictionary = {}  ## move_id -> {dmg, spd, kb} multipliers earned from rewards
var squash := Vector2.ONE
var holder: Node = null
var thrown_by: Actor = null
const TRAIL_RED := Color(1.7, 0.3, 0.22)
var _trail: LaunchTrail = null  ## ribbon behind a flying enemy
var _trail_col := TRAIL_RED
var debug_hit_rect := Rect2()
var dying := false

var _launch_t := 0.0
var _down_t := 0.0
var _getup_t := 0.0
var _tumble := 1.0
var _bumped: Dictionary = {}
var _pinball_gen := 0  ## how many enemy-into-enemy bounces deep this launch is (a throw or a hit by a player = 0)
var _pinball_t := 0.0  ## seconds during which this enemy cannot be pinballed again
const PINBALL_MAX_GEN := 2
var _pinball_emit_t := 0.0  ## after knocking into someone, this body cannot pinball again for a moment
const PINBALL_COOLDOWN := 1.0
var _bounced := false
var _wallbounce := false
var _ground_fx := ""  ## spike landing: "stop" (dead stop) or "bounce" (rebound), set by the hit that launched us

## Stun meter: every hit fills it; when full the actor is dazed (state "stunned") for STUN_TIME seconds or until it is hit.
## Enemies have one too (not drawn: you see the stars). Friendly hits wake a stunned partner without damage.
const STUN_MAX := 100.0
const STUN_TIME := 5.0
const STUN_PER_DMG := 1.5  ## meter gained per point of damage taken
const STUN_DECAY := 14.0  ## meter lost per second once STUN_HOLD seconds passed without a hit
const STUN_HOLD := 2.5
const EDGE_PAD := 26.0  ## launched bodies rebound off the sides of the fixed fighting screen this far inside its edge
var stun_meter := 0.0
var stunned_t := 0.0
var _stun_hold := 0.0
var _stun_pending := false
var _stun_fx: Node2D = null
var _victim_freeze := false
var _walk_phase := 0.0


func _configure() -> void:
	pass


func _ready() -> void:
	_configure()
	attack = AttackRunner.new(self)
	add_to_group("actors")
	add_to_group("hurt_" + team)
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(1, true)
	set_collision_mask_value(2, true)
	set_collision_mask_value(5, true)  # barriers (Bulwark Plant) block bodies but not projectiles; actors never block each other (see crowd_mult)
	floor_snap_length = 8.0
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = body_w * 0.5 * body_scale
	cap.height = body_h * body_scale
	cs.shape = cap
	cs.position = Vector2(0, -body_h * body_scale * 0.5)
	add_child(cs)
	figure = StickFigure.new()
	add_child(figure)
	figure.set_target(PoseLib.idle(0.0), true)


# ------------------------------------------------------------------ queries

func is_targetable() -> bool:
	return state != "down" and state != "dead"


func is_alive() -> bool:
	return hp > 0.0 and state != "dead"


func get_hurt_rect() -> Rect2:
	var w := body_w * body_scale
	var h := body_h * body_scale
	var r := Rect2(global_position.x - w * 0.5, global_position.y - h, w, h)
	if team == "enemy":
		r = r.grow_individual(14.0, 12.0, 14.0, 0.0)  # generous enemy hurtboxes: swings that visibly touch should connect
	return r


func center() -> Vector2:
	return global_position + Vector2(0, -body_h * body_scale * 0.5)


func hit_targets() -> Array:
	var out: Array = []
	if team == "player":
		for n in get_tree().get_nodes_in_group("hurt_enemy"):
			if n.is_targetable():
				out.append(n)
		# players can always stagger each other (no damage, see AttackRunner._connect)
		for n in get_tree().get_nodes_in_group("hurt_player"):
			if n != self and n.is_targetable():
				out.append(n)
	else:
		for n in get_tree().get_nodes_in_group("hurt_player"):
			if n.is_targetable():
				out.append(n)
	return out


func nearest_target(max_dist: float) -> Actor:
	var best: Actor = null
	var bd := max_dist
	for t in hit_targets():
		if t is Actor and (t as Actor).team != team:
			var d := absf(t.global_position.x - global_position.x) + absf(t.global_position.y - global_position.y) * 0.5
			if d < bd:
				bd = d
				best = t
	return best


func is_btn_held(_b: int) -> bool:
	return false


func has_buff(n: String) -> bool:
	return buffs.has(n)


func add_buff(n: String, dur: float) -> void:
	buffs[n] = dur


func dmg_mult() -> float:
	var m := 1.0
	if has_buff("rage"):
		m *= 1.5
	if has_buff("dmg"):
		m *= 1.5
	if has_buff("boost"):
		m *= 2.0
	return m


func take_mult() -> float:
	return 1.3 if has_buff("rage") else 1.0


## Reward upgrades for a move (chain parts jab2/jab3 count as "jab").
func upgrade_mult(move_id: String, stat: String) -> float:
	var u: Dictionary = upgrades.get(move_id.rstrip("0123456789"), {})
	return float(u.get(stat, 1.0))


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func telegraph() -> void:
	pass


func on_attack_end(_m: MoveData) -> void:
	if state == "attack":
		state = "idle"
		figure.set_target(PoseLib.idle(0.0))


func on_hit_landed(_info: HitInfo, _target: Node) -> void:
	if has_buff("boost"):
		buffs.erase("boost")


func _filter_hit(_info: HitInfo) -> bool:
	return false


func _on_damaged(_info: HitInfo) -> void:
	pass


func _on_defeated() -> void:
	pass


# ------------------------------------------------------------------ taking hits

## Override: true if this actor avoids the hit entirely (e.g. a crouching player vs a HIGH attack).
func _dodges(_info: HitInfo) -> bool:
	return false


func take_hit(info: HitInfo) -> bool:
	if not is_targetable() or invuln > 0.0:
		return false
	if _hit_while_grabbing(info):
		return true
	if _dodges(info):
		return false
	if _filter_hit(info):
		return true
	if state == "stunned":
		_end_stun()  # any hit wakes a dazed actor (a friendly one does so without damage)
	_apply_dir(info)
	if team == "enemy" and not info.friendly:
		if _chain_t <= 0.0:
			hit_chain = 0
		if hit_chain >= CHAIN_BREAK and hp > 0.0:
			_combo_break(info)
			return false
		hit_chain += 1
		_chain_t = 0.7
	Coop.pre_hit(info, self)
	if info.source != "pinball" and info.source != "thrown":
		_pinball_gen = 0  # a real hit starts a fresh chain
	var atk := info.attacker as Actor
	var dmg := info.dmg * take_mult()
	apply_infusion(info)
	if burn_t > 0.0:
		dmg *= BURN_BONUS
		Fx.sparks(get_parent(), global_position + Vector2(0, -50), info.color, 4)
	var shattered := false
	if frozen_t > 0.0 and info.frost <= 0.0:
		dmg *= 1.4  # frozen solid: a hit shatters the ice
		frozen_t = 0.0
		shattered = true
	var arc_from_shock := shock_t > 0.0 and info.source != "chain"
	if info.friendly:
		dmg *= Coop.ff_scale
	hp = maxf(hp - dmg, 1.0 if info.friendly else 0.0)
	if self is Fighter:
		Coop.stat_damage += dmg
	if info.ignite > 0.0 and hp > 0.0:
		burn_t = maxf(burn_t, info.ignite)
		_ensure_status_fx(info.color)
	if shattered:
		_shatter_ice(info.color)
	if info.shock > 0.0 and hp > 0.0:
		shock_t = maxf(shock_t, info.shock)
		_ensure_status_fx(info.color)
	if info.frost > 0.0 and hp > 0.0:
		_apply_frost(info)
	if arc_from_shock and hp > 0.0:
		_shock_arc(info, dmg)
	if atk != null and atk.team != team:
		last_hitter = atk
	var lethal := hp <= 0.0
	if not info.friendly and not lethal:
		_gain_stun(dmg * info.stun_mult)
	var armored := armor_t > 0.0 and not lethal
	if attack.active and not armored:
		attack.interrupt()
	if state == "grabbed" and holder != null:
		holder = null

	var was_launched := state == "launched"
	var launch := info.kind in ["launch", "spike", "trip"] or lethal or was_launched or not is_on_floor() or info.kb.length() > 760.0
	if launch_resist and not lethal and not was_launched:
		launch = false
	if atk != null and absf(atk.global_position.x - global_position.x) > 2.0 and not armored:
		facing = 1 if atk.global_position.x > global_position.x else -1

	if armored:
		velocity.x += info.kb.x * 0.08
	elif info.kind == "pull" and atk != null:
		state = "hurt"
		stun_frames = _prorated_stun(info.stun)
		velocity = Vector2(clampf((atk.global_position.x - global_position.x) * 5.0, -info.pull_speed, info.pull_speed), 0)
	elif launch:
		_start_launch(info, lethal)
		if info.meteor and not info.friendly:
			Coop.callout("METEOR!", Color(2.2, 1.6, 0.5))
	else:
		state = "hurt"
		stun_frames = _prorated_stun(info.stun)
		velocity = Vector2(info.kb.x, 0)
	_wallbounce = info.wallbounce if launch else _wallbounce

	freeze = maxi(info.stop, MIN_HITSTOP) if info.stop > 0 else 0  # every connecting hit holds the victim's pose
	_victim_freeze = true
	flash_t = clampf(0.08 + dmg * 0.006, 0.1, 0.2)  # heavier blows hold the white flash longer
	var sq := clampf(dmg / 20.0, 0.3, 0.6)
	if absf(info.kb.y) > absf(info.kb.x) * 1.2:
		squash = Vector2(1.0 + sq, 1.0 - sq * 0.9)  # vertical blow (uppercut / spike): flattened
	else:
		squash = Vector2(1.0 - sq * 0.55, 1.0 + sq * 0.5)  # horizontal blow: compressed along it, stretched up, then rebounds
	_hit_feedback(info, dmg)
	Coop.post_hit(info, self, dmg)
	_on_damaged(info)
	if lethal:
		dying = true
	return true


## A player who is holding something (enemy, prop or partner) and gets hit: the held one takes the blow instead,
## the grab ends and the holder is briefly invincible.
func _hit_while_grabbing(info: HitInfo) -> bool:
	if team != "player" or info.friendly:
		return false
	var g: Node = null
	if attack.active and attack.grabbed != null:
		g = attack.grabbed  # grab-throw: an enemy or the partner
		attack.grabbed = null
		attack.aiming = false
		attack.interrupt()
		state = "idle"
		figure.set_target(PoseLib.idle(0.0))
		velocity.x = 0.0
	elif get("held") != null:
		g = get("held")  # a carried crate / prop
		set("held", null)
	else:
		return false
	invuln = maxf(invuln, 0.8)
	if is_instance_valid(g):
		if g.has_method("release"):
			g.release()
		if g.has_method("take_hit"):
			if g is Node2D:
				info.pos = (g as Node2D).global_position + Vector2(0, -50)
			g.take_hit(info)
	Fx.ring(get_parent(), global_position + Vector2(0, -45), Color(1.9, 1.9, 2.2), 70.0, 0.25)
	return true


func _start_launch(info: HitInfo, lethal: bool) -> void:
	var kb := info.kb
	var was_launched := state == "launched"
	var sc := maxf(0.6, 1.0 - 0.06 * juggle_hits) if was_launched else 1.0  # solo juggles last longer (weaker launches, not none)
	if info.kind == "spike":
		velocity = Vector2(kb.x * 0.3, absf(kb.y))
	else:
		velocity = Vector2(kb.x, kb.y * sc if kb.y < 0.0 else -260.0)
		if info.sends:
			# flat sends still leave the floor (a low liner), and a send behind the attacker arcs over their head
			velocity.y = minf(velocity.y, -440.0 if info.ang > 135.0 else -260.0)
		if info.kind == "trip":
			velocity.y = minf(velocity.y, -240.0)
		if lethal and velocity.y > -320.0:
			velocity.y = -380.0
		if lethal and absf(velocity.x) < 160.0:
			velocity.x = 160.0 * (-1 if facing > 0 else 1)
	juggle_hits = juggle_hits + 1 if was_launched else 0
	_trail_col = _trail_color_for(info.attacker)
	_ground_fx = info.ground_fx if info.kind == "spike" else ""
	state = "launched"
	_launch_t = 0.0
	_bounced = false
	_bumped.clear()
	_tumble = -signf(kb.x) if kb.x != 0.0 else 1.0


func _hit_feedback(info: HitInfo, dmg: float) -> void:
	var parent := get_parent()
	var power := clampf(dmg / 6.0, 0.9, 3.0)
	var dir := info.kb.normalized() if info.kb != Vector2.ZERO else Vector2(facing, -0.3)
	Fx.impact(parent, info.pos, info.color, power, dir)
	var pitch := 1.0 + minf(Coop.combo, 24) * 0.025
	if info.relay:
		Sfx.play("relay", 1.0 + minf(Coop.relay, 6) * 0.08)
	# strength decides the sound: heavier blows are lower, longer and fatter (combo only lifts the pitch a little)
	Sfx.impact(maxf(dmg, 24.0) if info.kind == "spike" else dmg, 1.0 + (pitch - 1.0) * 0.5)
	if not info.no_combo and not info.friendly:
		var txt := "%d" % int(round(dmg))
		var col := Color(1.0, 0.95, 0.5) if info.relay else Color(1.0, 1.0, 1.0)
		Fx.number(parent, global_position + Vector2(randf_range(-14, 14), -body_h * body_scale - 6.0), txt, col, int(clampf(18.0 + dmg * 0.9, 18.0, 40.0)))
	elif info.friendly and dmg >= 0.5:
		Fx.number(parent, global_position + Vector2(0, -body_h - 6.0), "%d" % int(round(dmg)), Color(0.7, 0.7, 0.7), 16)
	Juice.shake(info.shake * (1.4 if info.relay else 1.0))
	# camera: directional kick toward the blow, zoom punch and a flash of slow motion on heavy hits
	if not info.friendly:
		Juice.kick(dir * clampf(dmg * 3.2, 12.0, 68.0))
		var zp := clampf((dmg - 5.0) / 80.0, 0.0, 0.14)
		if info.punch > 0.0 or info.relay or zp > 0.0:
			Juice.zoom_punch(maxf(maxf(info.punch, zp), 0.05 if info.relay else 0.0))
		if (dmg >= 12.0 or hp <= 0.0 or info.relay) and Engine.time_scale > 0.9 * Juice.normal_scale():
			Juice.slowmo(0.22, 0.12 if hp > 0.0 else 0.22)


func apply_direct_damage(amount: float, label := "") -> void:
	hp = maxf(0.0, hp - amount)
	Fx.number(get_parent(), global_position + Vector2(0, -body_h * body_scale - 6.0), "%d" % int(amount), Color(1.0, 0.8, 0.4), 22)
	if label != "":
		Coop.callout(label, Color(1.0, 0.8, 0.4))
	if hp <= 0.0:
		dying = true


# ------------------------------------------------------------------ send directions, clashes, stun

## Down-angled hits (DOWN / DOWN-BACK / DOWN-FORWARD) are meteor strikes when the target or the attacker is in the air:
## the victim is sent straight to the floor (or down a pit) and takes extra damage. Used on two grounded fighters they only
## press the victim into the floor: a longer stagger, no launch.
func _apply_dir(info: HitInfo) -> void:
	if info.sends:
		# A player's spike (-90 degrees). In the air (target or attacker): a meteor, straight into the floor, which bounces
		# the target back up. On the ground: the blow pops the target straight up off the floor. Either way it stays in
		# play for the partner; nothing is pinned down.
		if info.kind != "spike" or info.friendly:
			return
		var by := info.attacker as Actor
		if not is_on_floor() or state == "launched" or (by != null and not by.is_on_floor()):
			info.meteor = true
			info.kb = Vector2(info.kb.x * 0.25, maxf(info.kb.length(), 900.0))
			info.dmg *= 1.35
			info.stop += 2
		else:
			info.kind = "launch"
			info.kb = Vector2(0.0, -clampf(info.kb.length() * 0.8, 600.0, 860.0))
			squash = Vector2(1.5, 0.6)
			Fx.ring(get_parent(), global_position + Vector2(0, -4), Color(1.8, 1.4, 0.6), 80.0, 0.25)
		return
	if info.dir < 5 or info.dir > 7 or info.friendly or info.kind == "pull":
		return
	var atk := info.attacker as Actor
	var aerial := not is_on_floor() or state == "launched" or (atk != null and not atk.is_on_floor())
	if info.kind == "trip" and not aerial:
		return  # a down-arrow trip is allowed to trip a grounded target
	if aerial:
		info.kind = "spike"
		info.meteor = true
		info.kb = Vector2(info.kb.x * 0.25, maxf(info.kb.length(), 900.0))
		info.dmg *= 1.35
		info.stop += 2
	else:
		info.kind = "normal"
		info.kb = Vector2(info.kb.x * 0.3, 0.0)
		info.stun = maxi(info.stun, 30)
		squash = Vector2(1.5, 0.6)


## Stun meter: damage fills it; a full meter dazes the actor as soon as it can act again (after hit-stun / getting up).
func _gain_stun(dmg: float) -> void:
	_stun_hold = STUN_HOLD
	if state == "stunned":
		return
	stun_meter += dmg * STUN_PER_DMG * (0.5 if launch_resist else 1.0)
	if stun_meter >= STUN_MAX:
		stun_meter = 0.0
		_stun_pending = true


func _check_stun() -> void:
	if _stun_pending and hp > 0.0 and state == "idle":
		_begin_stun()
	_stun_pending = _stun_pending and hp > 0.0


func _begin_stun() -> void:
	_stun_pending = false
	state = "stunned"
	stunned_t = STUN_TIME
	velocity.x = 0.0
	if attack.active:
		attack.interrupt()
	if _stun_fx == null or not is_instance_valid(_stun_fx):
		_stun_fx = StunFx.new()
		(_stun_fx as StunFx).actor = self
		add_child(_stun_fx)
	Coop.callout("STUNNED!", Color(2.2, 2.0, 0.5))
	Sfx.play("block", 0.6)


func _end_stun() -> void:
	stunned_t = 0.0
	stun_meter = 0.0
	_stun_pending = false


func _st_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	velocity.y = 50.0 if is_on_floor() else minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	stunned_t -= delta
	if stunned_t <= 0.0:
		_end_stun()
		state = "idle"


## Two swings trading at once: the enemy loses the clash. It is cut off mid-swing and staggered for a moment.
func clash_stagger(winner: Actor) -> void:
	if attack.active:
		attack.interrupt()
	armor_t = 0.0
	state = "hurt"
	stun_frames = 22 if launch_resist else 40
	var away := signf(global_position.x - winner.global_position.x)
	velocity = Vector2((away if away != 0.0 else float(-facing)) * 150.0, 0.0)
	freeze = 6
	_victim_freeze = true
	flash_t = 0.1
	squash = Vector2(1.35, 0.75)
	clash_fx(get_parent(), center())


static func clash_fx(parent: Node, pos: Vector2) -> void:
	Fx.ring(parent, pos, Color(2.2, 2.0, 1.0), 90.0, 0.25)
	Fx.sparks(parent, pos, Color(2.2, 2.0, 1.0), 10)
	Coop.callout("CLASH!", Color(2.2, 2.0, 1.0))
	Sfx.play("parry", 1.3)
	Juice.shake(0.3)


# ------------------------------------------------------------------ grabs / throws

func can_be_grabbed() -> bool:
	return not no_grab and not (state in NO_GRAB_STATES) and is_alive()


func grab(by: Node) -> void:
	if attack.active:
		attack.interrupt()
	_end_stun()  # grabbing a dazed partner (or enemy) wakes it: no damage, ready to be thrown
	state = "grabbed"
	holder = by
	velocity = Vector2.ZERO
	invuln = maxf(invuln, 0.0)


func release() -> void:
	figure.rot = 0.0
	if state == "grabbed":
		state = "hurt"
		stun_frames = 12
		holder = null
		velocity = Vector2.ZERO


func thrown(vel: Vector2, by: Actor) -> void:
	_end_stun()
	state = "launched"
	holder = null
	velocity = vel
	thrown_by = by
	_trail_col = _trail_color_for(by)
	last_hitter = by if by.team != team else last_hitter
	juggle_hits = 0
	_launch_t = 0.0
	_bounced = true
	_bumped.clear()
	_tumble = -signf(vel.x) if vel.x != 0.0 else 1.0
	global_position.y -= 6.0


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if freeze > 0:
		freeze -= 1
		figure.frozen = true  # hold the pose on impact
		figure.jitter = clampf(1.5 + float(freeze) * 0.35, 2.0, 5.0) if _victim_freeze else 0.0  # longer stop = harder rattle
		figure.self_modulate = Color(1.9, 1.9, 1.9) if flash_t > 0.0 else Color.WHITE
		return
	figure.jitter = 0.0
	figure.frozen = false
	_victim_freeze = false
	_tick_timers(delta)
	match state:
		"hurt": _st_hurt(delta)
		"launched": _st_launched(delta)
		"down": _st_down(delta)
		"getup": _st_getup(delta)
		"stunned": _st_stunned(delta)
		"grabbed": _st_grabbed(delta)
		"attack": _st_attack(delta)
		"dead": pass
		_: _control(delta)
	if global_position.y > kill_y:
		_fell_out()
	_separate_from_others(delta)
	_update_visuals(delta)


## Soft body collision: characters may overlap a little, but are eased apart so they never stand in the same spot.
const SEP_DIST := 38.0  ## centre-to-centre distance below which bodies are pushed apart
const SEP_SPEED := 260.0  ## px/s of push at full overlap


func _separate_from_others(delta: float) -> void:
	if state in ["launched", "grabbed", "down", "dead", "downed", "getup"] or not is_alive():
		return
	for o in get_tree().get_nodes_in_group("actors"):
		if o == self or not (o is Actor):
			continue
		var a := o as Actor
		if not a.is_alive() or a.state in ["launched", "grabbed", "down", "dead", "downed"]:
			continue
		if absf(a.global_position.y - global_position.y) > 45.0:
			continue  # one is in the air / on another level
		var dx := global_position.x - a.global_position.x
		var min_d := SEP_DIST * 0.5 * (body_scale + a.body_scale)
		if absf(dx) >= min_d:
			continue
		var dir := signf(dx)
		if dir == 0.0:
			dir = 1.0 if get_instance_id() > a.get_instance_id() else -1.0
		var push := (1.0 - absf(dx) / min_d) * SEP_SPEED * delta * 0.5
		var motion := Vector2(dir * maxf(push, 0.4), 0.0)
		if not test_move(global_transform, motion):
			global_position += motion


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	armor_t = maxf(0.0, armor_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	_pinball_t = maxf(0.0, _pinball_t - delta)
	_pinball_emit_t = maxf(0.0, _pinball_emit_t - delta)
	_chain_t = maxf(0.0, _chain_t - delta)
	_stun_hold = maxf(0.0, _stun_hold - delta)
	if _stun_hold <= 0.0 and stun_meter > 0.0 and state != "stunned":
		stun_meter = maxf(0.0, stun_meter - STUN_DECAY * delta)
	_tick_burn(delta)
	shock_t = maxf(0.0, shock_t - delta)
	frost_t = maxf(0.0, frost_t - delta)
	frozen_t = maxf(0.0, frozen_t - delta)
	if guard_t > 0 and guard_t < 99999:
		guard_t -= 1
	parry_t = maxi(0, parry_t - 1)
	reflect_t = maxi(0, reflect_t - 1)
	for k in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if float(buffs[k]) <= 0.0:
			buffs.erase(k)


func _control(_delta: float) -> void:
	pass


func _fell_out() -> void:
	apply_direct_damage(hp)
	state = "dead"




func start_attack(m: MoveData, btn := -1) -> void:
	state = "attack"
	attack.start(m, btn)


## Hook: poses may be adapted to the state of the actor (e.g. legs in mid-air).
func adapt_pose(kf: Dictionary, _airborne: bool) -> Dictionary:
	return kf


func _st_attack(delta: float) -> void:
	_attack_extra(delta)
	if state != "attack":
		return
	if not attack.active:  # safety net: an interrupted move whose follow-up failed must never leave the actor frozen
		state = "idle"
		return
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 50.0
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	attack.tick()
	move_and_slide()


func _attack_extra(_delta: float) -> void:
	pass


func _st_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	if is_on_floor():
		velocity.y = 50.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	stun_frames -= 1
	if stun_frames <= 0:
		state = "idle"
		_check_stun()


## The trail colour: the player who sent the enemy flying, red for everything else (enemies, hazards, explosions).
## An object thrown by a player carries that player as its attacker, so its trail has the thrower's colour.
func _trail_color_for(src: Variant) -> Color:
	if src is Fighter:
		return (src as Fighter).figure.color
	return TRAIL_RED


func _trail_tick() -> void:
	if team != "enemy" or velocity.length() < 140.0:
		return
	if _trail == null or not is_instance_valid(_trail):
		_trail = LaunchTrail.new()
		_trail.owner_actor = self
		get_parent().add_child(_trail)
	_trail.col = _trail_col
	_trail.push(global_position + Vector2(0.0, -46.0))


func _st_launched(delta: float) -> void:
	_trail_tick()
	_launch_t += delta
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)
	var vx_before := velocity.x
	var vy_before := velocity.y
	move_and_slide()
	figure.rot += _tumble * facing * 10.0 * delta
	# the sides of the fixed fighting screen are walls too: launched bodies rebound off them
	var edge_n := Vector2.ZERO
	var lo := Coop.bounds.position.x + EDGE_PAD
	var hi := Coop.bounds.end.x - EDGE_PAD
	if global_position.x <= lo and vx_before < -230.0:
		edge_n = Vector2.RIGHT
	elif global_position.x >= hi and vx_before > 230.0:
		edge_n = Vector2.LEFT
	if edge_n != Vector2.ZERO:
		global_position.x = clampf(global_position.x, lo, hi)
	if (is_on_wall() and absf(vx_before) > 230.0) or edge_n != Vector2.ZERO:
		var n := get_wall_normal() if edge_n == Vector2.ZERO else edge_n
		velocity.x = n.x * absf(vx_before) * (0.45 if edge_n == Vector2.ZERO else 0.6)
		Fx.impact(get_parent(), global_position + Vector2(-n.x * 14.0, -50.0), Color(1.6, 1.6, 1.6), 0.9, n)
		Sfx.impact(18.0 + absf(vx_before) * 0.02)
		Juice.shake(0.3)
		if _wallbounce:
			_wallbounce = false
			apply_direct_damage(10.0, "WALL BOUNCE!")
			Juice.shake(0.4)
			Coop.bonus_hit(last_hitter, self, 10.0)
		elif team == "enemy" and absf(vx_before) > 450.0:
			apply_direct_damage(3.0, "SPLAT")
	_launch_collisions()
	if is_on_floor() and vy_before >= 0.0 and _launch_t > 0.06:
		_land_from_launch(vy_before)


func _launch_collisions() -> void:
	if team != "enemy" or velocity.length() < 280.0:
		return
	var credit: Actor = thrown_by if thrown_by != null else last_hitter
	if credit == null:
		return
	if _pinball_gen >= PINBALL_MAX_GEN or _pinball_emit_t > 0.0:
		return  # enemies knocked into each other stop knocking each other after a couple of bounces
	for t in get_tree().get_nodes_in_group("hurt_enemy"):
		if t == self or _bumped.has(t.get_instance_id()) or not t.has_method("take_hit"):
			continue
		if t.has_method("is_targetable") and not t.is_targetable():
			continue
		if t is Actor and (t as Actor)._pinball_t > 0.0:
			continue
		if get_hurt_rect().intersects(t.get_hurt_rect()):
			_bumped[t.get_instance_id()] = true
			_pinball_emit_t = PINBALL_COOLDOWN
			if t is Actor:
				(t as Actor)._pinball_t = 1.2
				(t as Actor)._pinball_gen = _pinball_gen + 1
			var info := HitInfo.new()
			info.attacker = credit
			info.team = "player"
			info.dmg = 12.0 if thrown_by != null else 8.0
			info.kind = "normal"
			info.kb = Vector2(signf(velocity.x) * 320.0, -240.0)
			info.stun = 24
			info.stop = 6
			info.source = "thrown" if thrown_by != null else "pinball"
			info.pos = get_hurt_rect().intersection(t.get_hurt_rect()).get_center()
			info.shake = 0.3
			if t.take_hit(info):
				velocity.x *= 0.6
				Coop.callout("PINBALL!" if thrown_by == null else "STRIKE!", Color(1.8, 1.4, 0.4))


func _land_from_launch(vy: float) -> void:
	var parent := get_parent()
	Fx.dust(parent, global_position, 8 + int(vy / 300.0))
	squash = Vector2(1.3, 0.7)
	var fx := _ground_fx
	_ground_fx = ""
	if team == "enemy" and fx == "stop":
		fx = "bounce"  # no hard knockdowns on enemies: a spiked enemy rebounds and stays in play
	if fx == "stop" and vy > 500.0 and not dying:
		# spiked straight down: a dead stop on the floor, no rebound (big slam, long enough on the ground to finish)
		apply_direct_damage(minf(vy / 180.0, 8.0), "SLAM")
		Fx.ring(parent, global_position + Vector2(0, -4), Color(1.8, 1.4, 0.6), 110.0, 0.35)
		Sfx.play("boom", 1.2)
		Juice.shake(0.5)
		Juice.zoom_punch(0.05)
		velocity = Vector2.ZERO
		if hp > 0.0:
			state = "down"
			_down_t = 0.85
		else:
			_on_defeated()
		juggle_hits = 0
		thrown_by = null
		_bumped.clear()
		figure.rot = fmod(figure.rot + PI, TAU) - PI
		return
	if (vy > 850.0 or (fx == "bounce" and vy > 500.0)) and not _bounced and not dying:
		# spiked: bounce back up for the next hit
		_bounced = true
		velocity = Vector2(velocity.x * 0.5, -vy * 0.4)
		apply_direct_damage(minf(vy / 250.0, 5.0), "SLAM")
		Fx.ring(parent, global_position + Vector2(0, -4), Color(1.8, 1.4, 0.6), 90.0, 0.3)
		Sfx.play("boom", 1.4)
		Juice.shake(0.45)
		Juice.zoom_punch(0.05)
		return
	Sfx.play("land", 0.8)
	Juice.shake(clampf(vy / 3000.0, 0.05, 0.3))
	juggle_hits = 0
	thrown_by = null
	_bumped.clear()
	figure.rot = fmod(figure.rot + PI, TAU) - PI
	if hp <= 0.0:
		_on_defeated()
		return
	if team == "enemy":
		# Enemies are never knocked flat: they skid to their feet, reeling for a moment and still open to the next hit
		# (lying down made them untouchable and stopped the rally between the two players).
		state = "hurt"
		stun_frames = LAND_STAGGER
		velocity.x *= 0.55
		figure.rot = 0.0
		return
	state = "down"
	_down_t = 0.55


func _st_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL) if not is_on_floor() else 50.0
	move_and_slide()
	_down_t -= delta
	if _down_t <= 0.0:
		state = "getup"
		_getup_t = 0.3
		invuln = maxf(invuln, 0.3)  # only while rising; it used to outlast the getup animation by 0.3 s


func _st_getup(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 50.0 if is_on_floor() else minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	_getup_t -= delta
	if _getup_t <= 0.0:
		state = "idle"
		_check_stun()


func _st_grabbed(_delta: float) -> void:
	if holder == null or not is_instance_valid(holder):
		release()
		return
	var h := holder as Actor
	if h != null:
		# Grab & Throw: lifted overhead (held flat like a press) once the lift animation has started
		if h.attack.active and h.attack.move != null and h.attack.move.id == "grab_throw" and h.attack.frame >= 8:
			global_position = h.global_position + Vector2(h.facing * 4.0, -118.0)
			figure.rot = lerpf(figure.rot, float(h.facing) * 1.45, 0.35)
		else:
			global_position = h.global_position + Vector2(h.facing * 30.0, -26.0)
	velocity = Vector2.ZERO


# ------------------------------------------------------------------ visuals

func _loco_pose() -> Dictionary:
	return PoseLib.idle(Time.get_ticks_msec() / 1000.0)


func _update_visuals(delta: float) -> void:
	if not attack.active:
		figure.zeta = 0.32 if (state == "hurt" or state == "launched" or state == "getup") else 1.0
	match state:
		"hurt":
			figure.set_target(PoseLib.hurt())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"launched":
			figure.set_target(PoseLib.launched())
		"down", "downed":
			figure.set_target(PoseLib.down())
			figure.rot = lerpf(figure.rot, -PI * 0.5, 0.35)
		"getup":
			figure.set_target(PoseLib.getup())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"grabbed":
			figure.set_target(PoseLib.grabbed())
			figure.rot = lerpf(figure.rot, 0.0, 0.3)
		"stunned":
			figure.set_target(PoseLib.hurt())
			figure.rot = lerpf(figure.rot, sin(Time.get_ticks_msec() / 260.0) * 0.14, 0.2)
		"attack":
			pass
		_:
			var p := _loco_pose()
			if not p.is_empty():
				figure.set_target(p)
			if state != "tossed":
				figure.rot = lerpf(figure.rot, 0.0, 0.3)
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	figure.scale = Vector2(facing * squash.x * body_scale, squash.y * body_scale)
	figure.self_modulate = Color(2.6, 2.6, 2.6) if flash_t > 0.0 else Color.WHITE


## Burning: a little damage over time, flames on the body, and +30% damage from every source (synergy hook).
func _tick_burn(delta: float) -> void:
	if burn_t <= 0.0:
		return
	burn_t = maxf(0.0, burn_t - delta)
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		if not dying and hp > 0.0:
			apply_direct_damage(2.0, "")


## Characters never block each other: they walk through, but are slowed while their bodies overlap
## (the cost of squeezing past a crowd). 1.0 = free, CROWD_SLOW = overlapping another body.
const CROWD_SLOW := 0.5


func crowd_mult() -> float:
	var me := get_hurt_rect().grow(-6.0)
	for o in get_tree().get_nodes_in_group("actors"):
		if o == self or not (o is Actor):
			continue
		var a := o as Actor
		if not a.is_alive() or a.state == "downed" or a.state == "dead" or a.state == "grabbed":
			continue
		if me.intersects(a.get_hurt_rect().grow(-6.0)):
			return CROWD_SLOW
	return 1.0


## Hitstun shrinks along a long chain (35 % floor), so no single enemy can be stunlocked forever.
func _prorated_stun(frames: int) -> int:
	if team != "enemy":
		return frames
	return maxi(3, int(round(float(frames) * maxf(0.35, 1.0 - 0.05 * float(hit_chain)))))


## Combo breaker: after CHAIN_BREAK hits in a row the enemy shrugs the next hit off, is shoved away and is briefly
## untouchable, so a combo can end instead of looping forever.
func _combo_break(info: HitInfo) -> void:
	hit_chain = 0
	_chain_t = 0.0
	invuln = 0.7
	var atk := info.attacker as Node2D
	var away := signf(global_position.x - atk.global_position.x) if atk != null else float(-facing)
	if away == 0.0:
		away = float(-facing)
	velocity = Vector2(away * 420.0, -160.0)
	state = "idle"
	stun_frames = 0
	Fx.ring(get_parent(), global_position + Vector2(0, -50), Color(2.0, 1.7, 1.9), 70.0, 0.3)
	Coop.callout("BREAK!", Color(2.0, 1.7, 1.9))
	Sfx.play("parry", 0.9)


var _status_fx: StatusFx = null


## Look of burning / shocked / chilled / frozen targets, in the colour of whoever applied the status.
func _ensure_status_fx(c: Color) -> void:
	status_col = c
	if _status_fx != null and is_instance_valid(_status_fx):
		_status_fx.col = c
		return
	_status_fx = StatusFx.new()
	_status_fx.actor = self
	_status_fx.col = c
	add_child(_status_fx)


# ------------------------------------------------------------------ elemental statuses (fire / shock / frost)

## An infused fighter's attacks carry its element unless the move already has one.
func apply_infusion(info: HitInfo) -> void:
	if infusion == "" or team != "player" or info.ignite > 0.0 or info.shock > 0.0 or info.frost > 0.0 or info.source == "chain":
		return
	match infusion:
		"fire":
			info.ignite = 2.0
		"shock":
			info.shock = 3.0
		"frost":
			info.frost = 2.5


func _apply_frost(info: HitInfo) -> void:
	frost_t = maxf(frost_t, info.frost)
	frost_stacks += 1
	_ensure_status_fx(info.color)
	if frost_stacks >= 3 and frozen_t <= 0.0 and not launch_resist:
		frost_stacks = 0
		frozen_t = 1.6
		if attack.active:
			attack.interrupt()
		Fx.ring(get_parent(), global_position + Vector2(0, -50), info.color, 80.0, 0.35)
		Coop.callout("FROZEN", info.color)
		Sfx.play("block", 0.7)


func _shatter_ice(c: Color) -> void:
	Fx.shatter(get_parent(), global_position + Vector2(0, -50), c, 24)
	Coop.callout("SHATTER!", c)
	Sfx.play("break", 1.3)
	Juice.shake(0.2)


## A hit on a shocked target arcs to the nearest other enemy within reach for 40 % damage (and shocks it a little).
func _shock_arc(info: HitInfo, dmg: float) -> void:
	var best: Actor = null
	var bd := 190.0
	for n in get_tree().get_nodes_in_group("hurt_" + team):
		if n == self or not (n is Actor) or not (n as Actor).is_targetable():
			continue
		var d := (n as Actor).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n as Actor
	if best == null:
		return
	var a := Vector2(global_position.x, global_position.y - 55.0)
	var b := Vector2(best.global_position.x, best.global_position.y - 55.0)
	Fx.beam(get_parent(), a, b, info.color, 0.18)
	Sfx.play("hit1", 1.5)
	var arc := HitInfo.new()
	arc.attacker = info.attacker
	arc.team = info.team
	arc.dmg = dmg * 0.4 / maxf(take_mult(), 0.01)
	arc.stun = 14
	arc.kind = "normal"
	arc.stop = 2
	arc.source = "chain"
	arc.shock = 2.0
	arc.color = info.color
	arc.pos = b
	arc.kb = Vector2(signf(b.x - a.x) * 120.0, 0.0)
	best.take_hit(arc)
