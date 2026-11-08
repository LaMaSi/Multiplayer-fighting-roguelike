class_name BonusPole
extends Node2D
## An optional bonus above the finish line: a round target that slides up and down high above the ground (there is no
## visible track), in the upper third of the screen. A normal jump cannot touch it: it takes a double jump (the low
## end of its travel) or a partner throw (the high end). Every hit pays coins, more the higher the target is.
## It hangs right above the finish strip, so crossing the line is the one try.

const RADIUS := 30.0
const LOW := 320.0  ## lowest height of the target's CENTRE above the ground (a single jump reaches about 180)
const HIGH := 440.0  ## highest height of its centre
const PERIOD := 3.4
const MAX_HITS := 12

var ground_y := 600.0
var hits := 0
var _t := 0.0
var _flash := 0.0
var _cd := 0.0


func _ready() -> void:
	add_to_group("hurt_enemy")  # player attacks and projectiles target it like a container
	z_index = -3


## Current height of the target's centre above the ground.
func center_h() -> float:
	return lerpf(LOW, HIGH, 0.5 + 0.5 * sin(_t / PERIOD * TAU))


func is_targetable() -> bool:
	return hits < MAX_HITS


func get_hurt_rect() -> Rect2:
	var c := ground_y - center_h()
	return Rect2(global_position.x - RADIUS, c - RADIUS, RADIUS * 2.0, RADIUS * 2.0)


func take_hit(info: HitInfo) -> bool:
	if not is_targetable() or _cd > 0.0:
		return false
	_cd = 0.18  # one swing pays once
	hits += 1
	_flash = 1.0
	var frac := (center_h() - LOW) / (HIGH - LOW)
	var coins := 3 + int(round(frac * 5.0))  # 3 low, 8 at the top of the travel
	if RunState.active:
		RunState.coins += coins
	var c := Vector2(global_position.x, ground_y - center_h())
	Fx.sparks(get_parent(), c, Color(2.0, 1.7, 0.4), 12)
	Fx.ring(get_parent(), c, Color(2.0, 1.6, 0.4), 50.0, 0.25)
	Coop.say("+%d" % coins, Color(2.0, 1.7, 0.4), c + Vector2(0, -44.0))
	Sfx.play("pickup", 1.0 + 0.04 * float(hits))
	if info.attacker is Actor:
		(info.attacker as Actor).freeze = maxi((info.attacker as Actor).freeze, 2)
	return true


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	_flash = maxf(0.0, _flash - delta * 4.0)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var done := hits >= MAX_HITS
	var col := Color(2.0, 1.6, 0.35) if not done else Color(0.5, 0.45, 0.2)
	var c := Vector2(0.0, ground_y - global_position.y - center_h())  # local position of the centre
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var r := RADIUS * (1.0 + 0.12 * _flash)
	# a bullseye: glow, dark disc, rings, centre
	draw_circle(c, r * 1.7, Color(col.r, col.g, col.b, 0.10 + 0.06 * pulse + 0.15 * _flash))
	draw_circle(c, r, Color(0.10, 0.07, 0.02))
	draw_arc(c, r, 0.0, TAU, 40, col, 4.0, true)
	draw_arc(c, r * 0.64, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.85), 3.0, true)
	draw_circle(c, r * 0.32, Color(col.r * (0.7 + 0.3 * pulse), col.g * (0.7 + 0.3 * pulse), col.b))
