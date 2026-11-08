extends Node
## Autoload "Sfx": all sound effects are synthesized in code at startup (no audio files).
## Chiptune style: pulse / triangle / LFSR-style noise voices, bit-crushed and gently low-passed
## so they stay punchy without being harsh. Hits come in power tiers: the stronger the blow, the lower,
## longer and heavier the sound.

const RATE := 22050
const POOL := 16
const HIT_TIERS := 6  ## "hit0" (light tap) .. "hit5" (crushing blow)

# voice kinds
const P12 := 0  ## 12.5% pulse (thin, bright)
const P25 := 1  ## 25% pulse
const P50 := 2  ## square
const TRI := 3  ## triangle (soft, 4-bit-ish)
const NOI := 4  ## sample-and-hold noise; pitch = how fast it changes (low = rumble)

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_hits()
	_build_misc()


## Voice dictionary helper: kind, start freq, end freq, volume, decay (higher = shorter tail), optional extras.
func _v(kind: int, f0: float, f1: float, vol: float, decay: float, extra := {}) -> Dictionary:
	var d := {"k": kind, "f0": f0, "f1": f1, "vol": vol, "decay": decay}
	d.merge(extra, true)
	return d


func _build_hits() -> void:
	for i in HIT_TIERS:
		var p := float(i) / float(HIT_TIERS - 1)  # 0 light .. 1 crushing
		var dur := lerpf(0.09, 0.42, p)
		var body_f := lerpf(330.0, 95.0, p)  # heavier = lower
		var layers: Array = [
			# the "crack": a burst of noise, rumblier (slower) for heavy hits
			_v(NOI, lerpf(9000.0, 3200.0, p), lerpf(2600.0, 500.0, p), lerpf(0.5, 0.62, p), lerpf(14.0, 5.0, p)),
			# the body: a pulse thump that falls in pitch
			_v(P25 if i < 3 else P50, body_f, body_f * lerpf(0.45, 0.2, p), 0.5, lerpf(7.0, 3.2, p)),
		]
		if i >= 2:  # weight: a triangle sub that gets deeper and longer with power
			layers.append(_v(TRI, lerpf(150.0, 62.0, p), lerpf(80.0, 28.0, p), lerpf(0.4, 0.8, p), lerpf(5.0, 2.4, p)))
		if i >= 4:  # the crunch of a really big hit: a second slower noise tail
			layers.append(_v(NOI, 1400.0, 260.0, 0.4, 3.0, {"delay": 0.03}))
		_make("hit%d" % i, dur, layers, 5, lerpf(0.55, 0.3, p))


func _build_misc() -> void:
	# swings: airy noise sweep; slow=heavy variants are made by pitching these down at play time
	_make("whoosh", 0.2, [_v(NOI, 7000.0, 1200.0, 0.3, 1.6, {"attack": 0.05}), _v(TRI, 700.0, 180.0, 0.18, 1.8, {"attack": 0.05})], 5, 0.4)
	_make("block", 0.11, [_v(NOI, 6000.0, 3000.0, 0.35, 8.0), _v(P50, 520.0, 380.0, 0.35, 6.0), _v(P12, 1040.0, 760.0, 0.18, 7.0)], 5, 0.45)
	_make("parry", 0.38, [_v(P12, 0.0, 0.0, 0.3, 2.6, {"notes": [1320.0, 1760.0, 2093.0, 2637.0]}), _v(NOI, 8000.0, 5000.0, 0.25, 12.0)], 5, 0.5)
	_make("jump", 0.14, [_v(P25, 220.0, 520.0, 0.3, 2.5), _v(TRI, 110.0, 260.0, 0.3, 2.5)], 5, 0.4)
	_make("land", 0.12, [_v(NOI, 2200.0, 500.0, 0.45, 6.0), _v(TRI, 120.0, 55.0, 0.6, 4.0)], 5, 0.35)
	_make("shoot", 0.22, [_v(P25, 900.0, 200.0, 0.32, 3.0), _v(NOI, 5000.0, 1500.0, 0.2, 9.0)], 5, 0.45)
	_make("pickup", 0.2, [_v(P25, 0.0, 0.0, 0.3, 1.6, {"notes": [660.0, 880.0, 1320.0]}), _v(TRI, 0.0, 0.0, 0.2, 1.6, {"notes": [330.0, 440.0, 660.0]})], 5, 0.5)
	_make("break", 0.34, [_v(NOI, 4500.0, 700.0, 0.6, 3.5), _v(P50, 240.0, 70.0, 0.3, 4.0), _v(TRI, 100.0, 40.0, 0.5, 3.0)], 5, 0.4)
	_make("boom", 0.65, [_v(NOI, 2200.0, 160.0, 0.75, 2.6), _v(TRI, 90.0, 28.0, 0.9, 2.2), _v(P50, 140.0, 35.0, 0.3, 4.0)], 5, 0.3)
	_make("relay", 0.4, [_v(P25, 0.0, 0.0, 0.3, 1.8, {"notes": [523.0, 659.0, 784.0, 1047.0, 1319.0]}), _v(TRI, 0.0, 0.0, 0.25, 1.8, {"notes": [262.0, 330.0, 392.0, 523.0, 659.0]})], 5, 0.5)
	_make("heal", 0.42, [_v(TRI, 0.0, 0.0, 0.5, 1.4, {"notes": [392.0, 494.0, 587.0, 784.0]}), _v(P12, 0.0, 0.0, 0.14, 1.8, {"notes": [784.0, 988.0, 1175.0, 1568.0]})], 5, 0.5)
	_make("buff", 0.36, [_v(P25, 200.0, 760.0, 0.28, 1.8), _v(TRI, 100.0, 380.0, 0.35, 1.8)], 5, 0.45)
	_make("death", 0.6, [_v(P50, 420.0, 40.0, 0.35, 2.0), _v(NOI, 3000.0, 300.0, 0.4, 2.5), _v(TRI, 160.0, 30.0, 0.5, 2.0)], 5, 0.4)
	_make("ui", 0.07, [_v(P50, 780.0, 980.0, 0.28, 3.0), _v(P12, 1560.0, 1960.0, 0.12, 3.0)], 5, 0.5)
	_make("throw", 0.22, [_v(P25, 300.0, 720.0, 0.28, 2.4), _v(NOI, 5500.0, 1800.0, 0.22, 4.0)], 5, 0.45)
	_make("tp", 0.28, [_v(P12, 0.0, 0.0, 0.28, 1.6, {"notes": [1760.0, 1320.0, 880.0, 660.0, 440.0, 330.0, 220.0]}), _v(NOI, 6000.0, 1000.0, 0.15, 3.0)], 5, 0.5)
	_make("revive", 0.65, [_v(P25, 0.0, 0.0, 0.3, 1.2, {"notes": [262.0, 330.0, 392.0, 523.0, 659.0, 784.0, 1047.0]}), _v(TRI, 0.0, 0.0, 0.3, 1.2, {"notes": [131.0, 165.0, 196.0, 262.0, 330.0, 392.0, 523.0]})], 5, 0.5)
	# legacy names still referenced in places: map onto the new tiers
	_sounds["hit"] = _sounds["hit1"]
	_sounds["heavy"] = _sounds["hit5"]


## Renders layered voices to a 16-bit stream. `bits` = bit-crush depth, `soft` = low-pass strength (0 raw .. 1 very dull).
func _make(id: String, dur: float, layers: Array, bits := 5, soft := 0.4) -> void:
	var n := int(RATE * dur)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for L: Dictionary in layers:
		var kind: int = L["k"]
		var delay_n := int(float(L.get("delay", 0.0)) * RATE)
		var attack := float(L.get("attack", 0.002))
		var duty: float = [0.125, 0.25, 0.5][kind] if kind <= P50 else 0.5
		var notes: Array = L.get("notes", [])
		var phase := 0.0
		var held := 0.0
		var len_n := n - delay_n
		for j in len_n:
			var t := float(j) / float(len_n)
			var f: float
			if notes.is_empty():
				f = float(L["f0"]) * pow(maxf(float(L["f1"]), 1.0) / maxf(float(L["f0"]), 1.0), t)
			else:
				f = float(notes[mini(int(t * notes.size()), notes.size() - 1)])
			phase += f / RATE
			var s: float
			match kind:
				TRI:
					var ph := fposmod(phase, 1.0)
					s = 4.0 * absf(ph - 0.5) - 1.0
					s = roundf(s * 7.5) / 7.5  # 4-bit stepped triangle, like old hardware
				NOI:
					if phase >= 1.0:
						phase = fposmod(phase, 1.0)
						held = randf() * 2.0 - 1.0
					s = held
				_:
					s = 1.0 if fposmod(phase, 1.0) < duty else -1.0
			var env := minf(1.0, float(j) / RATE / attack) * pow(1.0 - t, float(L["decay"]))
			mix[j + delay_n] += s * env * float(L["vol"])
	var levels := float(1 << bits) * 0.5
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var a := 1.0 - soft  # one-pole low-pass
	for i in n:
		var s := clampf(mix[i], -1.0, 1.0)
		s = roundf(s * levels) / levels  # bit-crush
		lp += (s - lp) * a
		data.encode_s16(i * 2, int(clampf(lp * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_sounds[id] = w


## Impact sound scaled by how hard the blow is (damage). Heavier = lower, longer, louder.
## `pitch` lets callers add a small lift (e.g. for combo counters) without losing the weight.
func impact(dmg: float, pitch := 1.0, vol_db := 0.0) -> void:
	var p := clampf((dmg - 2.0) / 28.0, 0.0, 1.0)
	var tier := clampi(int(round(p * float(HIT_TIERS - 1))), 0, HIT_TIERS - 1)
	play("hit%d" % tier, pitch * lerpf(1.08, 0.9, p), vol_db + lerpf(-3.0, 2.0, p))


## Swing sound for a move whose strongest hit does `dmg`: bigger swings are lower and rounder.
func swing(dmg: float, vol_db := 0.0) -> void:
	var p := clampf((dmg - 3.0) / 25.0, 0.0, 1.0)
	play("whoosh", lerpf(1.35, 0.6, p), vol_db + lerpf(-4.0, 0.0, p))


func play(id: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sounds.has(id) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[id]
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = vol_db - 6.0
	p.play()
