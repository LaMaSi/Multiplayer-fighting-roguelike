class_name PoseLib
extends RefCounted
## Procedural poses for locomotion and reactions. Attack poses live in MoveDB as keyframes.


static func idle(t: float) -> Dictionary:
	var b := sin(t * 2.6) * 0.03
	return {
		"lean": 0.10 + b, "head": -0.05,
		"th_f": 0.30, "kn_f": 0.45, "th_b": -0.25, "kn_b": 0.35,
		"ua_f": 0.95 + b, "la_f": 1.55, "ua_b": 0.55 - b, "la_b": 1.85,
	}


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
