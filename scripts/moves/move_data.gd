class_name MoveData
extends RefCounted
## One move, authored as data. All frame numbers are at 60 fps, counted from the start of the move.
## Coordinates are local to the attacker: +x forward, y up is negative, origin at the feet.
##
## kf      [[frame, pose], ...]       pose keyframes (pose = StickFigure joint dict)
## hits    [{at, dur, box:Rect2, dmg, stun, kb:Vector2, kind, stop, ...}]
## events  [{at, type, ...}]          vel, proj, guard, parry, reflect, invuln, armor, tp, throw ...
## spin    {at, dur, turns}           whole-body rotation (spin kicks, flips)
## drive   [{from, to, vx}]           constant forward speed over a frame range

var id := ""
var name := ""
var short := ""  ## <= 6 chars, shown in the HUD loadout grid
var desc := ""
var total := 30
var kf: Array = []
var hits: Array = []
var events: Array = []
var spin: Dictionary = {}
var drive: Array = []
var tags: Array = []  ## launcher, projectile, defensive, low, buff, utility, air, team, grab
var ground_only := false
var air_only := false
var chain_next := ""
var chain_from := 0
var cancel_from := -1  ## frame from which a connected move may be cancelled into another (-1 = after last hit)
var hold := false
var hold_frame := 0
var hold_max := 600
## Charging: with the button held at `hold_frame` the move waits, building charge for up to `charge_max` frames (180 = 3 s).
## A full charge multiplies damage by (1 + charge_dmg) and knockback by (1 + charge_kb); a tap plays the move normally.
var charge_max := 0
var charge_dmg := 1.0
var charge_kb := 0.8
var charge_move := 0.0  ## extra distance at full charge: lunges, drives and jumps of the move scale by (1 + this)
var charge_stretch := false  ## the hit window stretches with the charged movement (a lunge keeps hitting along its longer path)
var steer := 0.0  ## fraction of run speed the player can still steer with during the move
var enemy := false
var tele := false
var color := Color(1.6, 1.6, 1.6)
var land_wait := -1  ## frame at which to wait until the actor touches the floor (dive kick)
var tier := ""  ## "weapon" (B slots, class-locked), "adaptive" (Y, reshaped by the class), "universal" (X), "" = enemy / legacy
var class_id := ""  ## owning class for weapon moves; the applied class for an adaptive variant
var height := "mid"  ## "high" / "mid" / "low": the height of the first hit
var meter_cost := 0.0  ## reserved: Style meter cost of the LT version (super meter design pending)


func is_chargeable() -> bool:
	return charge_max > 0


## Seconds a full charge takes.
func charge_seconds() -> int:
	return int(round(float(charge_max) / 60.0))


## The two bonuses of a full charge, as shown on the attack cards.
func charge_bonus_text() -> String:
	var t := "+%d%% DMG  +%d%% KB" % [int(round(charge_dmg * 100.0)), int(round(charge_kb * 100.0))]
	if charge_move > 0.0:
		t += "  +DIST"
	return t


func last_hit_end() -> int:
	var e := 0
	for h in hits:
		e = maxi(e, int(h["at"]) + int(h["dur"]))
	return e
