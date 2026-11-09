class_name HitInfo
extends RefCounted
## Everything a victim needs to know about one hit.

var attacker: Node = null
var team := "player"
var dmg := 5.0
var stun := 14  ## frames of hit-stun
var kb := Vector2.ZERO  ## world-space knockback velocity (px/s)
var kind := "normal"  ## normal, launch, spike, pull, trip, push
var stop := 3  ## hit-stop frames
var pos := Vector2.ZERO
var source := "melee"  ## melee, proj, thrown, prop, pinball
var low := false
var height := "mid"  ## "high" (ducked by crouching), "mid", "low"
var relay := false
var alley_oop := false
var wallbounce := false
var guard_break := false
var friendly := false
var no_combo := false
var heal_self := 0.0
var ignite := 0.0  ## seconds of burning to apply (burning targets take extra damage)
var shock := 0.0  ## seconds of shock to apply (hits on a shocked target arc to a neighbour)
var frost := 0.0  ## seconds of chill to apply (slow; three chilling hits freeze)
var dir := -1  ## send direction in the attacker's frame (0 F, 1 UF, 2 U, 3 UB, 4 B, 5 DB, 6 D, 7 DF; -1 = does not send), see MoveDB.DIR_VECS
var ground_fx := ""  ## down-angled spikes: "stop" (dead stop on the floor) or "bounce" (rebound for a follow-up)
var stun_mult := 1.0  ## multiplier on the stun-meter gain of this hit (low pokes and staggers fill it fast)
var meteor := false  ## set by the victim when a down-angled hit lands on an airborne target (or from the air)
var clash := false  ## struck while the victim was mid-swing: short stagger, no launch
var color := Color(1.6, 1.6, 1.6)
var shake := 0.12
var punch := 0.0
var prop_power := 1.0
var pull_speed := 900.0
