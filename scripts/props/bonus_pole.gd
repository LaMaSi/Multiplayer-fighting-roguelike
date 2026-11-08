class_name BonusPole
extends Node2D
## An optional bonus near the finish line: a vertical pole that slides up and down high above the ground, in the upper
## third of the screen. A normal jump cannot touch it: it takes a double jump (the low end of its travel) or a partner
## throw (the high end). Every hit pays coins, more the higher the pole is.

const LENGTH := 112.0
const LOW := 300.0  ## lowest height of the pole's BOTTOM above the ground (a single jump reaches about 180)
const HIGH := 410.0  ## highest height of the pole's bottom
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


## Current height of the pole's bottom above the ground.
func bottom_h() -> float:
	return lerpf(LOW, HIGH, 0.5 + 0.5 * sin(_t / PERIOD * TAU))


func is_targetable() -> bool:
	return hits < MAX_HITS


func get_hurt_rect() -> Rect2:
	var b := ground_y - bottom_h()
	return Rect2(global_position.x - 26.0, b - LENGTH, 52.0, LENGTH)


func take_hit(info: HitInfo) -> bool:
	if not is_targetable() or _cd > 0.0:
		return false
	_cd = 0.18  # one swing pays once
	hits += 1
	_flash = 1.0
	var frac := (bottom_h() - LOW) / (HIGH - LOW)
	var coins := 3 + int(round(frac * 5.0))  # 3 low, 8 at the top of the travel
	if RunState.active:
		RunState.coins += coins
	var c := Vector2(global_position.x, ground_y - bottom_h() - LENGTH * 0.5)
	Fx.sparks(get_parent(), c, Color(2.0, 1.7, 0.4), 12)
	Fx.ring(get_parent(), c, Color(2.0, 1.6, 0.4), 50.0, 0.25)
	Coop.say("+%d" % coins, Color(2.0, 1.7, 0.4), c + Vector2(0, -40.0))
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
	var gx := 0.0
	var gy := ground_y - global_position.y  # local y of the ground
	var done := hits >= MAX_HITS
	var col := Color(2.0, 1.6, 0.35) if not done else Color(0.5, 0.45, 0.2)
	# the guide rail the pole slides on, over its whole travel
	var rail_top := gy - HIGH - LENGTH - 20.0
	var rail_bot := gy - LOW + 14.0
	draw_line(Vector2(gx, rail_top), Vector2(gx, rail_bot), Color(col.r, col.g, col.b, 0.22), 3.0, true)
	for yy in [rail_top, rail_bot]:
		draw_line(Vector2(gx - 14.0, yy), Vector2(gx + 14.0, yy), Color(col.r, col.g, col.b, 0.5), 3.0, true)
	# the pole itself
	var b := gy - bottom_h()
	var top := b - LENGTH
	var glow := 0.6 + 0.4 * _flash
	draw_line(Vector2(gx, b), Vector2(gx, top), Color(col.r, col.g, col.b, 0.14 + 0.2 * _flash), 26.0, true)
	draw_line(Vector2(gx, b), Vector2(gx, top), Color(0.12, 0.09, 0.02), 16.0, true)
	draw_line(Vector2(gx, b), Vector2(gx, top), Color(col.r * glow, col.g * glow, col.b * glow), 5.0, true)
	for i in 4:  # stripes
		var yy := top + LENGTH * (float(i) + 0.5) / 4.0
		draw_line(Vector2(gx - 8.0, yy), Vector2(gx + 8.0, yy), Color(col.r, col.g, col.b, 0.85), 2.0, true)
	draw_circle(Vector2(gx, top - 12.0), 8.0 + 3.0 * _flash, col)
	draw_string(ThemeDB.fallback_font, Vector2(gx - 20.0, top - 22.0), "$", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 20, Color(0.1, 0.07, 0.0))
