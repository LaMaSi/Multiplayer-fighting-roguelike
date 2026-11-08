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
var air_variant := ""  ## id of the move performed instead when this slot is pressed in the air (Lance Thrust -> Air Thrust)
var hold := false
var hold_frame := 0
var hold_max := 600
var steer := 0.0  ## fraction of run speed the player can still steer with during the move
var enemy := false
var tele := false
var color := Color(1.6, 1.6, 1.6)
var land_wait := -1  ## frame at which to wait until the actor touches the floor (dive kick)
var tier := ""  ## "weapon" (B slots, class-locked), "adaptive" (Y, reshaped by the class), "universal" (X), "" = enemy / legacy
var class_id := ""  ## owning class for weapon moves; the applied class for an adaptive variant
var height := "mid"  ## "high" / "mid" / "low": the height of the first hit
var meter_cost := 0.0  ## reserved: Style meter cost of the LT version (super meter design pending)


func last_hit_end() -> int:
	var e := 0
	for h in hits:
		e = maxi(e, int(h["at"]) + int(h["dur"]))
	return e
