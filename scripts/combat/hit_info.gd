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
var color := Color(1.6, 1.6, 1.6)
var shake := 0.12
var punch := 0.0
var prop_power := 1.0
var pull_speed := 900.0
var reset_juggle := false  ## a launched victim gets a full-strength launch again (Lance Skyhook)
var sky_relay := false  ## a relay hit made while the attacker is airborne
