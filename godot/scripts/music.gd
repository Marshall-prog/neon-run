extends Node
## One looping track per difficulty level, cross-faded on level change.

const TRACKS := 10
const FADE := 0.7

var on := true
var track := -1

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _front := true
var _tween: Tween
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	on = Store.music
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -80.0
		add_child(p)


func _stream(i: int) -> AudioStream:
	if _cache.has(i):
		return _cache[i]
	var path := "res://assets/music/lvl%02d.ogg" % (i + 1)
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[i] = s
	return s


func set_track(i: int) -> void:
	if not on:
		track = i
		return
	if track == i:
		return
	track = i
	var s := _stream(i)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var old := _a if _front else _b
	var new := _b if _front else _a
	_front = not _front
	new.stream = s
	new.volume_db = -80.0
	new.play()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(new, "volume_db", -7.0, FADE)
	if old.playing:
		_tween.tween_property(old, "volume_db", -80.0, FADE)
		_tween.chain().tween_callback(old.stop)


func stop() -> void:
	track = -1
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	for p in [_a, _b]:
		if p.playing:
			_tween.tween_property(p, "volume_db", -80.0, 0.35)
	_tween.chain().tween_callback(func():
		_a.stop()
		_b.stop())


func set_enabled(v: bool) -> void:
	on = v
	Store.music = v
	Store.save()
	if not v:
		stop()
