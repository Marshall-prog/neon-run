extends Node
## Persistent settings and records (localStorage in the original):
## best score, medal bitmask, audio switches, the first-run flag and the top-5.

const PATH := "user://neon-run.cfg"

var best := 0
var medals := 0
var muted := false
var music := true
var first_run := true
var scores: Array = []


func _ready() -> void:
	load_state()
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_state() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	best = int(cf.get_value("game", "best", 0))
	medals = int(cf.get_value("game", "medals", 0))
	muted = bool(cf.get_value("game", "muted", false))
	music = bool(cf.get_value("game", "music", true))
	first_run = bool(cf.get_value("game", "firstRun", true))
	var s = cf.get_value("game", "scores", [])
	scores = s if s is Array else []


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.set_value("game", "medals", medals)
	cf.set_value("game", "muted", muted)
	cf.set_value("game", "music", music)
	cf.set_value("game", "firstRun", first_run)
	cf.set_value("game", "scores", scores)
	cf.save(PATH)


## Adds a run to the local top-5 and returns its 1-based rank (0 = missed).
func add_score(m: int, coins: int, lv: int) -> int:
	var e := {"m": m, "c": coins, "lv": lv + 1, "d": int(Time.get_unix_time_from_system() * 1000.0)}
	var list: Array = scores.duplicate()
	list.append(e)
	list.sort_custom(func(a, b):
		if a["m"] != b["m"]:
			return a["m"] > b["m"]
		if a["c"] != b["c"]:
			return a["c"] > b["c"]
		return a["d"] < b["d"])
	var top := list.slice(0, 5)
	var rank := 0
	for i in top.size():
		if top[i] == e:
			rank = i + 1
			break
	scores = top
	save()
	return rank
