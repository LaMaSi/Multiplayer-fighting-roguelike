class_name PoseLib
extends RefCounted
## Procedural poses for locomotion and reactions. Attack poses live in MoveDB as keyframes.


static func idle(t: float) -> Dictionary:
	var b := sin(t * 7.5) * 0.035  # fast rhythmic breathing, not a slow sway
	return level_feet({
		"lean": 0.03 + b, "head": -0.02,
		"th_f": 0.34, "kn_f": 0.45, "th_b": -0.30, "kn_b": 0.35,
		"ua_f": 0.95 + b, "la_f": 1.55, "ua_b": 0.55 - b, "la_b": 1.85,
		"root_y": sin(t * 15.0) * 1.2,  # light bounce on the toes, twice per breath
	})


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
	return absf(float(p.get("ua_f", -9.0)) - 0.95) < 0.001 and absf(float(p.get("la_f", -9.0)) - 1.55) < 0.001 \
		and absf(float(p.get("th_b", -9.0)) + 0.30) < 0.001 and absf(float(p.get("th_f", -9.0)) - 0.34) < 0.001


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


static func walk_enemy(phase: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	return {
		"lean": 0.22, "head": 0.1,
		"th_f": s * 0.7, "kn_f": 0.2 + maxf(0.0, c) * 0.8,
		"th_b": -s * 0.7, "kn_b": 0.2 + maxf(0.0, -c) * 0.8,
		"ua_f": -s * 0.5, "la_f": 0.5, "ua_b": s * 0.5, "la_b": 0.5,
	}


static func rise() -> Dictionary:
	return {
		"lean": 0.05,
		"th_f": 1.0, "kn_f": 1.3, "th_b": -0.35, "kn_b": 0.8,
		"ua_f": 1.9, "la_f": 0.5, "ua_b": 1.0, "la_b": 0.6,
	}


static func fall() -> Dictionary:
	return {
		"lean": 0.08,
		"th_f": 0.45, "kn_f": 0.35, "th_b": -0.45, "kn_b": 0.30,
		"ua_f": 1.5, "la_f": 0.3, "ua_b": 0.2, "la_b": 0.3,
	}


static func land() -> Dictionary:
	return {
		"lean": 0.35,
		"th_f": 0.8, "kn_f": 1.5, "th_b": -0.6, "kn_b": 1.4,
		"ua_f": 0.6, "la_f": 1.2, "ua_b": 0.3, "la_b": 1.2,
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
