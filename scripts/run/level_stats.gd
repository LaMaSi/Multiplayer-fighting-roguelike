class_name LevelStats
## Turns the per-level counters in Coop into the level complete screen data: one row per stat with
## its own S..D rank, a team rank, a team score, the coins earned and a heart-link heal bonus.
## Pure data, no UI. Thresholds are in one place so they are easy to tune.

const LETTERS := ["D", "C", "B", "A", "S"]
const COIN_MULT := {"S": 1.25, "A": 1.1, "B": 1.0, "C": 0.9, "D": 0.8}
const HEAL_BONUS := {"S": 10.0, "A": 5.0, "B": 0.0, "C": 0.0, "D": 0.0}  ## extra HP on top of the normal 25% clear heal


static func _rank_high(v: float, s: float, a: float, b: float, c: float) -> int:
	return 4 if v >= s else (3 if v >= a else (2 if v >= b else (1 if v >= c else 0)))


static func _rank_low(v: float, s: float, a: float, b: float, c: float) -> int:
	return 4 if v <= s else (3 if v <= a else (2 if v <= b else (1 if v <= c else 0)))


static func fmt_time(sec: float) -> String:
	var t := int(sec)
	return "%d:%02d" % [t / 60, t % 60]


## fighters: Array[Fighter], par: seconds for an S on time.
static func compute(fighters: Array, par: float) -> Dictionary:
	var max_total := 0.0
	for f in fighters:
		max_total += f.max_hp
	var dmg_frac := Coop.stat_damage / maxf(max_total, 1.0)
	var cont_total := maxi(Coop.stat_containers_total, 0)
	var cont_frac := 1.0 if cont_total == 0 else float(Coop.stat_containers) / float(cont_total)
	var combo := Coop.best_combo

	var r_combo := _rank_high(combo, 30, 20, 12, 6)
	var r_dmg := _rank_low(dmg_frac, 0.10, 0.25, 0.45, 0.70)
	var r_time := _rank_low(Coop.stat_time, par, par * 1.25, par * 1.6, par * 2.2)
	var r_cont := 3 if cont_total == 0 else _rank_high(cont_frac, 0.9, 0.7, 0.5, 0.3)
	var r_relay := _rank_high(Coop.stat_relay_hits, 12, 8, 4, 1)

	var rows: Array = [
		{"label": "COMBO PEAK", "value": "x%d" % combo, "rank": LETTERS[r_combo]},
		{"label": "DAMAGE TAKEN", "value": "%d%%" % int(round(dmg_frac * 100.0)), "rank": LETTERS[r_dmg]},
		{"label": "TIME  (PAR %s)" % fmt_time(par), "value": fmt_time(Coop.stat_time), "rank": LETTERS[r_time]},
		{"label": "CONTAINERS", "value": "%d / %d" % [Coop.stat_containers, cont_total], "rank": LETTERS[r_cont]},
		{"label": "RELAY HITS", "value": "%d" % Coop.stat_relay_hits, "rank": LETTERS[r_relay]},
		{"label": "RESCUES", "value": "%d" % Coop.stat_rescues, "rank": "+" if Coop.stat_rescues > 0 else "-"},
	]
	var avg := float(r_combo + r_dmg + r_time + r_cont + r_relay) / 5.0
	var team: String = LETTERS[0 if avg < 1.0 else (1 if avg < 1.8 else (2 if avg < 2.6 else (3 if avg < 3.4 else 4)))]
	var score := combo * 20 + Coop.stat_relay_hits * 50 + Coop.stat_rescues * 150 + Coop.stat_containers * 30
	score += int(maxf(par * 2.0 - Coop.stat_time, 0.0) * 5.0) + int(maxf(1.0 - dmg_frac, 0.0) * 1000.0)
	var coins := int(round((100.0 + float(score) / 50.0) * float(COIN_MULT[team])))
	return {"rows": rows, "rank": team, "score": score, "coins": coins, "heal_bonus": float(HEAL_BONUS[team]), "rank_mult": float(COIN_MULT[team])}
