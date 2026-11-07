extends Node
## Autoload "Sfx": all sound effects are synthesized in code at startup (no audio files).

const RATE := 22050
const POOL := 14

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
	# name: dur, f0, f1, wave(0 sine,1 square,2 saw,3 noise), vol, noise mix, decay, attack
	_make("hit", 0.14, 220.0, 70.0, 1, 0.55, 0.45, 3.0)
	_make("hit2", 0.12, 340.0, 110.0, 2, 0.5, 0.5, 3.5)
	_make("heavy", 0.32, 130.0, 38.0, 1, 0.7, 0.6, 2.5)
	_make("whoosh", 0.18, 900.0, 200.0, 3, 0.25, 0.9, 1.4, 0.04)
	_make("block", 0.1, 900.0, 600.0, 1, 0.35, 0.3, 4.0)
	_make("parry", 0.35, 1200.0, 1800.0, 0, 0.5, 0.0, 2.0)
	_make("jump", 0.12, 240.0, 520.0, 1, 0.22, 0.0, 2.5)
	_make("land", 0.1, 140.0, 60.0, 3, 0.3, 0.5, 3.0)
	_make("shoot", 0.2, 800.0, 200.0, 2, 0.35, 0.1, 2.5)
	_make("pickup", 0.22, 520.0, 1040.0, 1, 0.3, 0.0, 2.0)
	_make("break", 0.3, 300.0, 80.0, 3, 0.6, 0.9, 2.5)
	_make("boom", 0.5, 100.0, 30.0, 3, 0.8, 0.7, 2.0)
	_make("relay", 0.4, 500.0, 1500.0, 0, 0.5, 0.0, 2.2)
	_make("heal", 0.4, 400.0, 800.0, 0, 0.4, 0.0, 1.5)
	_make("buff", 0.35, 200.0, 700.0, 2, 0.3, 0.0, 1.8)
	_make("death", 0.5, 400.0, 40.0, 2, 0.5, 0.4, 2.0)
	_make("ui", 0.06, 700.0, 900.0, 1, 0.25, 0.0, 3.0)
	_make("throw", 0.2, 300.0, 700.0, 2, 0.35, 0.2, 2.5)
	_make("tp", 0.25, 1400.0, 200.0, 0, 0.4, 0.1, 2.0)
	_make("revive", 0.6, 300.0, 900.0, 0, 0.5, 0.0, 1.2)


func _make(id: String, dur: float, f0: float, f1: float, wave: int, vol: float, noise: float, decay: float, attack := 0.003) -> void:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := f0 * pow(f1 / f0, t)
		phase += f / RATE
		var s := 0.0
		match wave:
			0: s = sin(TAU * phase)
			1: s = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
			2: s = fposmod(phase, 1.0) * 2.0 - 1.0
			_: s = randf() * 2.0 - 1.0
		if wave != 3 and noise > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, noise)
		var env := minf(1.0, t * dur / attack) * pow(1.0 - t, decay)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_sounds[id] = w


func play(id: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sounds.has(id) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[id]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.volume_db = vol_db - 6.0
	p.play()
