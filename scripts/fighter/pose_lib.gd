class_name PoseLib
extends RefCounted
## Procedural poses for locomotion and reactions. Attack poses live in MoveDB as keyframes.


static func idle(t: float) -> Dictionary:
	var br := breath(t)
	var b: float = br["b"]
	var sh: float = br["x"]
	var p := {
		"lean": 0.03 + float(br["down"]) * 0.03 + sh * 0.006, "head": -0.02, "root_x": sh,
		"ua_f": 0.95 + b, "la_f": 1.55, "ua_b": 0.55 - b, "la_b": 1.85,
	}
	p.merge(stance(13.0 - sh, -13.0 - sh, 37.0 - float(br["dip"])), true)
	return p


## Put both feet at the same height (standing poses only). The leg that would reach lower gets an
## extra knee bend, so neither foot floats and the stance reads as stable.
static func level_feet(p: Dictionary) -> Dictionary:
	const T := StickFigure.THIGH
	const S := StickFigure.SHIN
	var th_f: float = p["th_f"]
	var th_b: float = p["th_b"]
	var drop_f := T * cos(th_f) + S * cos(th_f - float(p["kn_f"]))
	var drop_b := T * cos(th_b) + S * cos(th_b - float(p["kn_b"]))
	var d := minf(drop_f, drop_b)
	var out := p.duplicate()
	if drop_f > d + 0.01:
		out["kn_f"] = th_f + acos(clampf((d - T * cos(th_f)) / S, -1.0, 1.0))
	elif drop_b > d + 0.01:
		out["kn_b"] = th_b + acos(clampf((d - T * cos(th_b)) / S, -1.0, 1.0))
	return out


## True for the neutral idle pose (used to swap in the class base pose at the end of a move).
static func is_idle(p: Dictionary) -> bool:
	var i0 := idle(0.0)
	for k in ["ua_f", "la_f", "th_f", "th_b"]:
		if absf(float(p.get(k, -9.0)) - float(i0[k])) > 0.001:
			return false
	return true


## Slouchy enemy stance.
static func idle_enemy(t: float) -> Dictionary:
	var b := sin(t * 2.2) * 0.04
	return {
		"lean": 0.18 + b, "head": 0.1,
		"th_f": 0.2, "kn_f": 0.3, "th_b": -0.2, "kn_b": 0.3,
		"ua_f": 0.3 + b, "la_f": 0.9, "ua_b": 0.1 - b, "la_b": 0.8,
	}


static func walk(phase: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	return {
		"lean": 0.16, "head": -0.08,
		"th_f": s * 0.80, "kn_f": 0.20 + maxf(0.0, c) * 0.95,
		"th_b": -s * 0.80, "kn_b": 0.20 + maxf(0.0, -c) * 0.95,
		"ua_f": 0.85 - s * 0.25, "la_f": 1.5,
		"ua_b": 0.55 + s * 0.25, "la_b": 1.8,
	}


## Run cycle after the classic "run on 6s" sheet: contact, down, passing, up (flight), with a big lean, big arm swing,
## the trailing heel kicked up and a little vertical bob. phase: 0 = front-leg contact, TAU = one full cycle (two steps).
const RUN_TH := [0.85, 0.40, -0.05, -0.60, -0.85, -0.45, 0.25, 0.75]
const RUN_KN := [0.15, 0.55, 0.30, 0.20, 0.45, 1.95, 2.10, 1.00]


static func _run_key(tbl: Array, ph: float) -> float:
	var x := fposmod(ph, TAU) / (TAU / 8.0)
	var i := int(floorf(x)) % 8
	var f: float = x - floorf(x)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(float(tbl[i]), float(tbl[(i + 1) % 8]), f)


static func run(phase: float) -> Dictionary:
	var cs := cos(phase)
	return {
		"lean": 0.34, "head": -0.16,
		"th_f": _run_key(RUN_TH, phase), "kn_f": _run_key(RUN_KN, phase),
		"th_b": _run_key(RUN_TH, phase + PI), "kn_b": _run_key(RUN_KN, phase + PI),
		"ua_f": 0.5 - 0.95 * cs, "la_f": 1.55 + 0.2 * cs,
		"ua_b": 0.5 + 0.95 * cs, "la_b": 1.55 - 0.2 * cs,
		"root_y": -6.0 * (0.5 - 0.5 * cos(2.0 * (phase - PI * 0.25))),
	}


static func walk_enemy(phase: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	return {
		"lean": 0.22, "head": 0.1,
		"th_f": s * 0.7, "kn_f": 0.2 + maxf(0.0, c) * 0.8,
		"th_b": -s * 0.7, "kn_b": 0.2 + maxf(0.0, -c) * 0.8,
		"ua_f": -s * 0.5, "la_f": 0.5, "ua_b": s * 0.5, "la_b": 0.5,
	}


## Jump keyframes (after the classic standing-jump sheet): launch = stretched, arms straight up, legs together;
## apex = tucked, knees up, arms down in front; fall = stretched again, arms thrown up, legs trailing apart.
const AIR_STRETCH_UP := {"lean": 0.04, "th_f": 0.12, "kn_f": 0.1, "th_b": -0.12, "kn_b": 0.2, "ua_f": 2.7, "la_f": 0.12, "ua_b": 2.4, "la_b": 0.2}
const AIR_TUCK := {"lean": 0.22, "th_f": 1.45, "kn_f": 1.75, "th_b": 1.0, "kn_b": 1.65, "ua_f": 0.75, "la_f": 1.1, "ua_b": 0.35, "la_b": 1.0}
const AIR_STRETCH_DOWN := {"lean": -0.03, "th_f": 0.55, "kn_f": 0.35, "th_b": -0.55, "kn_b": 0.5, "ua_f": 2.65, "la_f": 0.3, "ua_b": 2.3, "la_b": 0.4}


## vy: vertical speed (negative = rising). Blends launch -> tuck -> fall by speed, with a little flutter.
static func air(vy: float, t: float) -> Dictionary:
	var a: Dictionary
	var b: Dictionary
	var k: float
	if vy < 0.0:
		a = AIR_TUCK
		b = AIR_STRETCH_UP
		k = smoothstep(-80.0, -520.0, vy)  # near the apex: tucked; fast upward: stretched
	else:
		a = AIR_TUCK
		b = AIR_STRETCH_DOWN
		k = smoothstep(60.0, 520.0, vy)
	var out := {}
	for key in a:
		out[key] = lerpf(float(a[key]), float(b[key]), k)
	var w := sin(t * 14.0) * 0.08 * k
	out["ua_f"] += w
	out["ua_b"] -= w
	out["th_b"] -= w * 0.8
	out["th_f"] += w * 0.5
	return out


static func rise(vy := -400.0, t := 0.0) -> Dictionary:
	return air(minf(vy, -1.0), t)


static func fall(vy := 300.0, t := 0.0) -> Dictionary:
	return air(maxf(vy, 1.0), t)


static func land() -> Dictionary:
	# recovery: deep crouch, arms swung down in front toward the ground
	return {
		"lean": 0.5,
		"th_f": 1.15, "kn_f": 1.95, "th_b": -0.7, "kn_b": 1.8,
		"ua_f": 0.9, "la_f": 0.7, "ua_b": 0.2, "la_b": 0.9,
	}


static func hurt() -> Dictionary:
	return {
		"lean": -0.4, "head": -0.5,
		"th_f": 0.25, "kn_f": 0.5, "th_b": -0.35, "kn_b": 0.5,
		"ua_f": -0.5, "la_f": 0.5, "ua_b": -0.8, "la_b": 0.4,
	}


static func launched() -> Dictionary:
	return {
		"lean": -0.2, "head": -0.3,
		"th_f": 0.9, "kn_f": 0.4, "th_b": -0.7, "kn_b": 0.4,
		"ua_f": 2.4, "la_f": 0.3, "ua_b": -2.0, "la_b": 0.3,
	}


static func down() -> Dictionary:
	return {
		"lie": 1.0, "lean": 0.0,
		"th_f": 0.1, "kn_f": 0.1, "th_b": -0.1, "kn_b": 0.1,
		"ua_f": 0.35, "la_f": 0.2, "ua_b": -0.35, "la_b": 0.2,
	}


static func getup() -> Dictionary:
	return {
		"lie": 0.4, "lean": 0.6,
		"th_f": 1.0, "kn_f": 1.6, "th_b": -0.5, "kn_b": 1.6,
		"ua_f": 0.8, "la_f": 0.4, "ua_b": 0.2, "la_b": 0.4,
	}


## Crouch: deep knees (the hip drops by itself), torso forward, guard up.
static func crouch() -> Dictionary:
	return {
		"lean": 0.42, "head": -0.1,
		"th_f": 1.25, "kn_f": 2.3, "th_b": -0.55, "kn_b": 1.75,
		"ua_f": 1.2, "la_f": 1.8, "ua_b": 0.9, "la_b": 2.0,
	}


## Blend two poses (missing keys in `a` use `b`'s value).
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = lerpf(float(a.get(k, b[k])), float(b[k]), t)
	return out


static func guard() -> Dictionary:
	return {
		"lean": 0.22, "head": 0.05,
		"th_f": 0.4, "kn_f": 0.7, "th_b": -0.3, "kn_b": 0.5,
		"ua_f": 1.35, "la_f": 1.9, "ua_b": 1.15, "la_b": 2.1,
	}


static func grabbed() -> Dictionary:
	return {
		"lean": 0.1, "th_f": 0.3, "kn_f": 0.5, "th_b": -0.2, "kn_b": 0.5,
		"ua_f": 2.6, "la_f": 0.2, "ua_b": 2.3, "la_b": 0.2,
	}


## Carrying a crate / barrel / vase: both arms stretched up and a little apart, the hands under the object (the held prop
## is placed on the hands, see Fighter._update_visuals).
static func carry_prop() -> Dictionary:
	return {
		"lean": -0.04, "th_f": 0.3, "kn_f": 0.4, "th_b": -0.3, "kn_b": 0.4,
		"ua_f": 2.8, "la_f": 0.3, "ua_b": 3.5, "la_b": -0.3,
	}


static func carry() -> Dictionary:
	return {
		"lean": -0.05, "th_f": 0.3, "kn_f": 0.4, "th_b": -0.3, "kn_b": 0.4,
		"ua_f": 3.0, "la_f": 0.1, "ua_b": 2.9, "la_b": 0.1,
	}


## Two-bone IK for a firm stance: both feet planted level at x = front_x / back_x (relative to the hip) and
## `drop` below the hip. Knees always bend forward. Returns th_/kn_ keys for both legs.
static func stance(front_x: float, back_x: float, drop: float) -> Dictionary:
	const T := StickFigure.THIGH
	const S := StickFigure.SHIN
	var out := {}
	for leg in [["f", front_x], ["b", back_x]]:
		var x: float = leg[1]
		var d := minf(sqrt(x * x + drop * drop), T + S - 0.5)
		var phi := atan2(x, drop)  # direction hip -> foot, 0 = straight down
		var alpha := acos(clampf(d / (T + S), 0.0, 1.0))  # equal bones: the knee sits this far off the line
		out["th_" + leg[0]] = phi + alpha
		out["kn_" + leg[0]] = 2.0 * alpha
	return out


## Four-beat idle loop on planted feet: breathe in (up), out (down + weight to the RIGHT), in (up),
## out (down + weight to the LEFT). x = hip shift (px), dip = hip lowering (px, knees bend), b = chest / arm lift.
static func breath(t: float) -> Dictionary:
	var ph := t * 15.0  # one breath = PI of phase, ~0.21 s (quick, lively)
	var down := (1.0 - cos(ph)) * 0.5  # 0 = in / up, 1 = out / down
	return {"x": sin(ph * 0.5) * 4.0, "dip": down * 3.5, "b": cos(ph) * 0.04, "down": down}


## Hanging from a ledge: both arms straight up, legs dangling.
static func hang() -> Dictionary:
	return {
		"lean": 0.0, "head": 0.0,
		"th_f": 0.2, "kn_f": 0.25, "th_b": -0.12, "kn_b": 0.35,
		"ua_f": 3.05, "la_f": 0.05, "ua_b": 3.0, "la_b": 0.1,
	}
