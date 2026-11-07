class_name PoseLib
extends RefCounted
## Procedural poses for locomotion. Attack poses will be data (keyframes) from M1.


static func idle(t: float) -> Dictionary:
	var b := sin(t * 2.6) * 0.03
	return {
		"lean": 0.10 + b, "head": -0.05,
		"th_f": 0.30, "kn_f": 0.45, "th_b": -0.25, "kn_b": 0.35,
		"ua_f": 0.95 + b, "la_f": 1.55, "ua_b": 0.55 - b, "la_b": 1.85,
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
