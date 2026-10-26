extends Node
## Sound effects generated at start-up as WAV buffers — the same oscillators and
## envelopes the original Web Audio synth used, so no audio files are needed.

const SR := 44100.0
const VOICES := 8

var muted := false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = Store.muted
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_build()


func _build() -> void:
	_streams["jump"] = _wav(_blip(300, 620, 0.12, "square", 0.16))
	_streams["djump"] = _wav(_blip(500, 950, 0.12, "square", 0.16))
	_streams["duck"] = _wav(_noise(0.08, 0.12))
	_streams["coin"] = _mix([_blip(900, 1400, 0.09, "sine", 0.22), _blip(1300, 1800, 0.12, "sine", 0.12, 0.0)])
	_streams["gem"] = _wav(_blip(700, 1600, 0.25, "triangle", 0.24))
	_streams["hit"] = _mix([_noise(0.25, 0.4), _blip(220, 40, 0.35, "sawtooth", 0.24)])
	_streams["thud"] = _mix([_noise(0.16, 0.33), _blip(90, 55, 0.18, "sine", 0.2)])
	_streams["ui"] = _wav(_blip(600, 800, 0.06, "square", 0.13))
	var rec := []
	var freqs := [523.0, 659.0, 784.0, 1047.0]
	for i in freqs.size():
		rec.append(_blip(freqs[i], freqs[i], 0.15, "square", 0.18, float(i) * 0.11))
	_streams["record"] = _mix(rec)
	var med := []
	var mf := [660.0, 880.0, 1100.0]
	for i in mf.size():
		med.append(_blip(mf[i], mf[i], 0.12, "triangle", 0.18, float(i) * 0.09))
	_streams["medal"] = _mix(med)


func play(id: String) -> void:
	if muted or not _streams.has(id):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[id]
	p.play()


func toggle() -> void:
	muted = not muted
	Store.muted = muted
	Store.save()


# ------------------------------------------------------------- synthesis ---

func _buf(dur: float) -> PackedFloat32Array:
	var n := int(ceil(dur * SR))
	var b := PackedFloat32Array()
	b.resize(n)
	return b


func _blip(f0: float, f1: float, dur: float, type: String, vol: float, at := 0.0) -> Dictionary:
	var b := _buf(dur + 0.02)
	var start := int(at * SR)
	var n := b.size()
	var phase := 0.0
	for i in range(start, n):
		var t := float(i - start) / SR
		var f := f0 * pow(maxf(1.0, f1) / maxf(1.0, f0), t / dur)
		phase += TAU * f / SR
		var s := 0.0
		match type:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle":
				s = asin(clampf(sin(phase), -1.0, 1.0)) * 0.6366197
			"sawtooth":
				s = 2.0 * (fposmod(phase, TAU) / TAU) - 1.0
			_:
				s = sin(phase)
		var env := 0.0 if t <= 0.0 else vol * pow(0.0001 / vol, t / dur)
		b[i] += s * env
	return {"buf": b, "at": 0.0}


func _noise(dur: float, vol: float) -> Dictionary:
	var b := _buf(dur)
	var n := b.size()
	for i in n:
		b[i] = (randf() * 2.0 - 1.0) * (1.0 - float(i) / float(n)) * vol
	return {"buf": b, "at": 0.0}


func _wav(p: Dictionary) -> AudioStreamWAV:
	return _to_wav(p["buf"])


func _mix(parts: Array) -> AudioStreamWAV:
	var total := 0
	for p in parts:
		total = maxi(total, (p["buf"] as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(total)
	for p in parts:
		var b: PackedFloat32Array = p["buf"]
		for i in b.size():
			out[i] += b[i]
	return _to_wav(out)


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(SR)
	w.stereo = false
	w.data = data
	return w
