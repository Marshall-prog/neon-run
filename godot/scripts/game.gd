extends Node2D
## NEON RUN — the whole game: state machine, physics, spawning, UI.
## A 1:1 port of the original Canvas2D runner (game/index.html).

const W: float = Pal.W
const H: float = Pal.H
const GY: float = Pal.GY
const GRAVITY: float = Pal.GRAVITY
const JUMP_V: float = Pal.JUMP_V
const DJUMP_V: float = Pal.DJUMP_V
const SPEED0: float = Pal.SPEED0
const SPEED_MAX: float = Pal.SPEED_MAX
const SPEED_SQRT: float = Pal.SPEED_SQRT
const PX_PER_M: float = Pal.PX_PER_M
const DIFF_LEN: float = Pal.DIFF_LEN
const DIFF_MAX: int = Pal.DIFF_MAX
const STEP := 1.0 / 60.0

enum St { MENU, PLAY, DEAD, PAUSE }

const HAZARD: Array = Pal.HAZARD

var state := St.MENU
var menu_page := "main"

var player: Dictionary = {}
var obstacles: Array = []
var coins_arr: Array = []
var particles: Array = []
var floaties: Array = []

var dist := 0.0
var speed := SPEED0
var coins := 0
var spawn_at := 700.0
var next_is_pair := false
var dead_at := 0.0
var play_t := 0.0

var best := 0
var new_record := false
var record_flash := 0.0
var medal_flash := 0.0
var medal_flash_text := ""
var board_rank := 0

var shake := 0.0
var hit_stop := 0.0
var flash := 0.0
var slide_t := 0.0
var bg_t := 0.0

var shown_level := 0
var level_banner_t := 0.0
var level_banner_txt := ""
var mood := "normal"
var mood_t := 0.0

var cam_x := 0.0
var cam_y := 0.0
var cam_tx := 0.0
var cam_ty := 0.0
var last_on_ground := true

var pending_jump := false
var pending_t := 0.0
var press_y := 0.0
var pointer_down := false
var hover_id := ""

var jump_arc: Array = []
var jump_arc_span := 0.0

var pen: Pen
var bg: Bg
var hero: HeroModel
var _acc := 0.0
var _rng := RandomNumberGenerator.new()

# screenshot / automation hooks (debug builds only)
var _shot_path := ""
var _shot_frames := 4
var _frames := 0
var _auto := ""
var _turbo := 0
var _log_t := 0.0
var _js_hide_cb = null


func _ready() -> void:
	_rng.randomize()
	best = Store.best
	pen = Pen.new(self)
	var bold: Font = load("res://assets/fonts/DejaVuSans-Bold.ttf")
	pen.font = bold
	pen.mono = load("res://assets/fonts/DejaVuSansMono.ttf")
	bg = Bg.new()
	hero = HeroModel.new(pen)
	_build_jump_arc()
	reset()
	_parse_args()
	Music.on = Store.music
	_setup_web_pause()
	_apply_auto()


## Web не присылает уведомления о фокусе окна, поэтому подписываемся на
## visibilitychange/blur браузера: свернул вкладку — игра встаёт на паузу.
func _setup_web_pause() -> void:
	if not OS.has_feature("web"):
		return
	_js_hide_cb = JavaScriptBridge.create_callback(_on_web_hide)
	JavaScriptBridge.eval("""
		if (!window.__neonHideHooked) {
			window.__neonHideHooked = true;
			var fire = function () { if (window.__neonHide) window.__neonHide(); };
			document.addEventListener('visibilitychange', function () { if (document.hidden) fire(); });
			window.addEventListener('blur', fire);
		}
	""", true)
	JavaScriptBridge.get_interface("window").__neonHide = _js_hide_cb


func _on_web_hide(_args: Array) -> void:
	pause_game(true)


var _level_arg := -1


func _parse_args() -> void:
	var all: Array = OS.get_cmdline_user_args()
	all.append_array(OS.get_cmdline_args())
	for a in all:
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			_shot_frames = int(a.substr(9))
		elif a.begins_with("--auto="):
			_auto = a.substr(7)
		elif a.begins_with("--level="):
			_level_arg = int(a.substr(8)) - 1
		elif a.begins_with("--turbo="):
			_turbo = int(a.substr(8))


func _apply_auto() -> void:
	if _auto == "" and _level_arg < 0:
		return
	if _auto == "menu_board":
		menu_page = "board"
		return
	if _auto == "menu_howto":
		menu_page = "howto"
		return
	if _auto == "menu":
		return
	start_game()
	if _level_arg >= 0:
		dist = float(_level_arg) * PX_PER_M * DIFF_LEN + 300.0
	elif _auto == "lvl2":
		dist = PX_PER_M * DIFF_LEN + 300.0
	elif _auto == "lvl5":
		dist = PX_PER_M * DIFF_LEN * 4.0 + 300.0
	elif _auto == "lvl9":
		dist = PX_PER_M * DIFF_LEN * 8.0 + 300.0
	speed = minf(SPEED_MAX, SPEED0 + sqrt(dist / PX_PER_M) * SPEED_SQRT)
	shown_level = level_idx()
	if _level_arg >= 0 or _auto == "lvl2" or _auto == "lvl5" or _auto == "lvl9":
		spawn_at = dist + 1.0e9
		flash = 0.0
	match _auto:
		"dead":
			dist = 12345.0
			coins = 42
			die()
		"pause":
			pause_game()
			menu_page = "pause"
		"bot":
			pass
		_:
			pass


func _bot_think() -> void:
	var p := player
	if p["dead"]:
		return
	var need_duck := false
	if p["on_ground"] == false and p["ducking"]:
		need_duck = true
	for ob in obstacles:
		var d: Dictionary = ob["def"]
		var dx: float = float(ob["x"]) - float(p["x"])
		if dx < -220.0 or dx > 340.0:
			continue
		if d.has("drop") and String(ob["drop_state"]) != "landed":
			continue
		if d.has("fly") and dx < speed * 0.32 and dx + float(d["w"]) > -30.0:
			need_duck = true
	if need_duck:
		if not p["ducking"]:
			set_duck(true)
		elif slide_t < 0.14:
			set_duck(false)
			set_duck(true)
	else:
		set_duck(false)

	for ob in obstacles:
		var d: Dictionary = ob["def"]
		if d.has("fly"):
			continue
		var dx: float = float(ob["x"]) - float(p["x"])
		if dx < 0.0 or dx > 400.0:
			continue
		if d.has("drop") and String(ob["drop_state"]) != "landed":
			continue
		var jump_x: float = speed * jump_arc_span * 0.30 + 14.0
		if p["on_ground"] and dx < jump_x:
			do_jump()
			return
		if not p["on_ground"] and p["jumps"] < 2 and dx < speed * 0.10 and p["vy"] > 0.0:
			do_jump()
			return


# ------------------------------------------------------------- helpers ---

func level_idx() -> int:
	return clampi(int(floor(maxf(0.0, dist) / (PX_PER_M * DIFF_LEN))), 0, DIFF_MAX)


func pal() -> Dictionary:
	var p: Dictionary = Pal.PALETTES[level_idx()]
	return {"neon": Color(p["neon"]), "dim": Color(p["dim"]), "glow": Color(p["glow"])}


func hazard_palette() -> Dictionary:
	var i := level_idx()
	var j := mini(DIFF_MAX, i + 1)
	var h1: Dictionary = HAZARD[i]
	var h2: Dictionary = HAZARD[j]
	var m := fmod(dist / PX_PER_M, DIFF_LEN)
	var t := clampf(m / DIFF_LEN, 0.0, 1.0)
	return {
		"neon": Color(h1["neon"]).lerp(Color(h2["neon"]), t),
		"glow": Color(h1["glow"]).lerp(Color(h2["glow"]), t),
	}


func _title(s: String) -> String:
	return Pal.to_title_case(s)


func _build_jump_arc() -> void:
	jump_arc.clear()
	var vy := JUMP_V
	var y := 0.0
	var t := 0.0
	for i in 600:
		var g: float = 1.12 if vy > 0.0 else 1.0
		if absf(vy) < 120.0:
			g = 0.65
		vy += GRAVITY * g * STEP
		y += vy * STEP
		t += STEP
		jump_arc.append({"t": t, "h": -y})
		if y >= 0.0 and t > 0.05:
			break
	jump_arc_span = jump_arc[jump_arc.size() - 1]["t"]


func arc_height(f: float) -> float:
	var tt := f * jump_arc_span
	for i in range(1, jump_arc.size()):
		if jump_arc[i]["t"] >= tt:
			var a: Dictionary = jump_arc[i - 1]
			var b: Dictionary = jump_arc[i]
			var k: float = (tt - float(a["t"])) / maxf(0.0001, float(b["t"]) - float(a["t"]))
			return lerpf(a["h"], b["h"], k)
	return 0.0


func drop_profile(sp: float) -> Dictionary:
	var t := minf(0.62, 260.0 / maxf(1.0, sp))
	return {"T": t, "top": GY - 0.5 * GRAVITY * t * t}


# ------------------------------------------------------------------ state ---

func reset() -> void:
	player = {
		"x": 110.0, "y": GY, "vy": 0.0, "on_ground": true, "ducking": false,
		"jumps": 0, "coyote": 0.0, "buffer": 0.0, "anim": 0.0,
		"dead": false, "dead_t": 0.0, "land_t": 0.0, "stride": 80.0,
	}
	obstacles = []
	coins_arr = []
	particles = []
	floaties = []
	dist = 0.0
	speed = SPEED0
	coins = 0
	spawn_at = 700.0
	next_is_pair = false
	dead_at = 0.0
	play_t = 0.0
	new_record = false
	record_flash = 0.0
	shake = 0.0
	hit_stop = 0.0
	flash = 0.0
	slide_t = 0.0
	shown_level = 0
	level_banner_t = 0.0
	level_banner_txt = ""
	mood = "normal"
	mood_t = 0.0
	cam_x = 0.0
	cam_y = 0.0
	cam_tx = 0.0
	cam_ty = 0.0
	last_on_ground = true
	pending_jump = false
	board_rank = 0


func start_game() -> void:
	reset()
	Sfx.play("ui")
	state = St.PLAY
	Music.set_track(level_idx())


func to_menu() -> void:
	reset()
	state = St.MENU
	menu_page = "main"
	Sfx.play("ui")
	Music.stop()


func pause_game(silent := false) -> void:
	if state == St.PLAY:
		state = St.PAUSE
		menu_page = "pause"
		if not silent:
			Sfx.play("ui")
		Music.stop()


func resume_game() -> void:
	if state == St.PAUSE:
		state = St.PLAY
		_acc = 0.0
		Sfx.play("ui")
		Music.set_track(level_idx())


func open_menu() -> void:
	if state == St.PLAY:
		pause_game()
		menu_page = "pause"


func die() -> void:
	if player["dead"]:
		return
	if _auto == "bot":
		var near := ""
		for ob in obstacles:
			if absf(float(ob["x"]) - float(player["x"])) < 260.0:
				near += "%s@%d y=%d " % [ob["name"], int(ob["x"]), int(ob["y"])]
		print("BOT_DIE m=", int(dist / PX_PER_M), " vy=", int(player["vy"]), " near=", near)
	player["dead"] = true
	player["dead_t"] = 0.0
	state = St.DEAD
	dead_at = 0.0
	mood = "sad"
	mood_t = 0.0
	Sfx.play("hit")
	shake = 14.0
	hit_stop = 0.09
	flash = 0.5
	spawn_burst(player["x"], player["y"] - 30.0, 26)
	Music.stop()
	var m := int(floor(dist / PX_PER_M))
	board_rank = Store.add_score(m, coins, level_idx())
	if m > best:
		best = m
		Store.best = best
		Store.save()
		new_record = true
		record_flash = 2.2
	var mask := Store.medals
	var new_mask := mask
	for i in Pal.N_LEVELS:
		if m >= Pal.medal_target(i):
			new_mask |= (1 << i)
	if new_mask != mask:
		Store.medals = new_mask
		Store.save()
		var got := -1
		for i in Pal.N_LEVELS:
			if (new_mask & (1 << i)) != 0 and (mask & (1 << i)) == 0:
				got = i
				break
		medal_flash_text = Pal.medal_name(got)
		medal_flash = 2.5
	if Store.first_run:
		Store.first_run = false
		Store.save()


# ---------------------------------------------------------------- physics ---

func try_jump() -> void:
	if state == St.MENU:
		if menu_page == "main":
			start_game()
		else:
			menu_page = "main"
		return
	if state == St.DEAD:
		if dead_at > 0.4:
			start_game()
		return
	if state == St.PAUSE:
		resume_game()
		return
	if player["dead"]:
		return
	player["buffer"] = 0.13


func do_jump() -> void:
	var p := player
	if p["on_ground"] or p["coyote"] > 0.0:
		p["vy"] = JUMP_V
		p["on_ground"] = false
		p["coyote"] = 0.0
		p["jumps"] = 1
		p["ducking"] = false
		slide_t = 0.0
		Sfx.play("jump")
		spawn_puff(p["x"], GY, 6)
	elif p["jumps"] < 2:
		p["vy"] = DJUMP_V
		p["jumps"] = 2
		p["ducking"] = false
		slide_t = 0.0
		Sfx.play("djump")
		spawn_puff(p["x"], p["y"], 8)


func set_duck(on: bool) -> void:
	if state != St.PLAY or player["dead"]:
		return
	var p := player
	if on and not p["ducking"]:
		Sfx.play("duck")
		if p["on_ground"]:
			slide_t = 0.68
			p["ducking"] = true
		else:
			p["vy"] += 420.0
	elif not on:
		p["ducking"] = false


func player_hitbox() -> Dictionary:
	var p := player
	var duck: bool = p["ducking"] and p["on_ground"]
	var h := 50.0 if duck else 78.0
	var w := 62.0 if duck else 44.0
	return {"cx": p["x"], "cy": p["y"] - h * 0.5, "w": w, "h": h}


# ----------------------------------------------------------------- update ---

func _process(dt: float) -> void:
	dt = minf(dt, 0.25)
	if _turbo > 0:
		for i in 500:
			update(STEP)
			_turbo -= 1
			if _turbo <= 0 or state != St.PLAY:
				break
		if _turbo <= 0 or state != St.PLAY:
			print("BOT_END m=", int(dist / PX_PER_M), " coins=", coins, " level=", level_idx() + 1, " state=", state)
			_turbo = 0
			_shot_path = ""
			get_tree().quit()
		queue_redraw()
		return
	_acc += dt
	var n := 0
	while _acc >= STEP and n < 6:
		update(STEP)
		_acc -= STEP
		n += 1
	queue_redraw()
	_frames += 1
	_maybe_screenshot()


func update(dt: float) -> void:
	bg_t += dt
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 40.0)
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 1.8)
	if medal_flash > 0.0:
		medal_flash -= dt
	if record_flash > 0.0:
		record_flash -= dt
	if level_banner_t > 0.0:
		level_banner_t -= dt
	if level_banner_t <= 0.0 and level_banner_txt != "":
		pass
	if mood == "happy" and mood_t > 0.0:
		mood_t -= dt
		if mood_t <= 0.0:
			mood = "normal"

	if state == St.DEAD:
		dead_at += dt
		player["dead_t"] += dt
		for p in particles:
			p["x"] += p["vx"] * dt
			p["y"] += p["vy"] * dt
			p["vy"] += 900.0 * dt
			p["life"] -= dt
		particles = particles.filter(func(p): return p["life"] > 0.0)
		return
	if state != St.PLAY:
		return

	if _auto == "bot":
		_bot_think()

	if hit_stop > 0.0:
		hit_stop -= dt
		return

	if pending_jump:
		pending_t += dt
		if pending_t > 0.15:
			pending_jump = false
			try_jump()

	if slide_t > 0.0:
		slide_t -= dt
		if slide_t <= 0.0 and player["on_ground"]:
			player["ducking"] = false

	play_t += dt
	if _auto == "bot":
		_log_t += dt
		if _log_t >= 1.0:
			_log_t = 0.0
			print("BOT m=", int(dist / PX_PER_M), " speed=", int(speed), " obs=", obstacles.size(), " lvl=", level_idx() + 1)
	dist += speed * dt
	speed = minf(SPEED_MAX, SPEED0 + sqrt(dist / PX_PER_M) * SPEED_SQRT)

	var lvl := level_idx()
	if lvl != shown_level:
		shown_level = lvl
		if lvl > 0:
			level_banner_txt = "Уровень " + str(lvl + 1) + " • " + _title(Pal.LEVEL_NAMES[lvl])
			level_banner_t = 2.6
			flash = maxf(flash, 0.45)
			Sfx.play("medal")
			Music.set_track(lvl)

	var p := player
	var stride_len := 80.0 + speed * 0.28
	p["stride"] = stride_len
	p["anim"] = dist / stride_len
	if p["buffer"] > 0.0:
		p["buffer"] -= dt
	if p["buffer"] > 0.0 and (p["on_ground"] or p["coyote"] > 0.0 or p["jumps"] < 2):
		p["buffer"] = 0.0
		do_jump()
	if not p["on_ground"]:
		var g := 1.12 if p["vy"] > 0.0 else 1.0
		if absf(p["vy"]) < 120.0:
			g = 0.65
		if p["ducking"] and p["vy"] > 0.0:
			g = 2.2
		p["vy"] += GRAVITY * g * dt
		p["coyote"] -= dt
	p["y"] += p["vy"] * dt
	if p["y"] >= GY:
		if not p["on_ground"]:
			spawn_puff(p["x"], GY, 5)
			p["land_t"] = 0.14
		p["y"] = GY
		p["vy"] = 0.0
		p["on_ground"] = true
		p["jumps"] = 0
		p["coyote"] = 0.1
	elif p["on_ground"]:
		p["on_ground"] = false
		p["coyote"] = 0.1
	if p["land_t"] > 0.0:
		p["land_t"] -= dt
	if p["on_ground"] and _rng.randf() < dt * 14.0:
		spawn_puff(p["x"] - 14.0, GY, 1)

	update_spawning()

	for ob in obstacles:
		ob["x"] -= speed * dt
		ob["t"] += dt
		var d: Dictionary = ob["def"]
		if d.has("bob"):
			ob["y"] = ob["base_y"] + sin(ob["t"] * 4.0) * float(d["bob"])
		if d.has("move"):
			ob["x"] -= float(d["move"]) * dt
		if d.has("hop"):
			ob["vy"] += GRAVITY * 0.55 * dt
			ob["y"] += ob["vy"] * dt
			if ob["y"] >= GY:
				ob["y"] = GY
				ob["vy"] = -520.0
		if d.has("drop"):
			if ob["drop_state"] == "hang":
				if ob["x"] <= p["x"] + 180.0 + speed * ob["drop_t"]:
					ob["drop_state"] = "fall"
					ob["vy"] = 0.0
			elif ob["drop_state"] == "fall":
				ob["vy"] += GRAVITY * dt
				ob["y"] += ob["vy"] * dt
				if ob["y"] >= GY:
					ob["y"] = GY
					ob["vy"] = 0.0
					ob["drop_state"] = "landed"
					spawn_puff(ob["x"] + float(d["w"]) * 0.5, GY, 12)
					shake = maxf(shake, 5.0)
					Sfx.play("thud")
		if d.has("spin"):
			ob["spin"] += dt * 7.0
		if d.has("drill"):
			ob["ext"] = 37.0 + 37.0 * sin(ob["t"] * 2.2)
		if d.has("bounce") and not ob["spring"] and not p["dead"]:
			var pk2 := player_hitbox()
			var ow := float(d["w"]) * float(d["hb"])
			var oh := float(d["h"]) * float(d["hb"])
			var ox: float = float(ob["x"]) + (float(d["w"]) - ow) * 0.5
			var oy: float = float(ob["y"]) - oh
			if pk2["cx"] + pk2["w"] * 0.5 > ox and pk2["cx"] - pk2["w"] * 0.5 < ox + ow and pk2["cy"] + pk2["h"] * 0.5 > oy:
				ob["spring"] = true
				p["vy"] = JUMP_V * 0.92
				p["on_ground"] = false
				p["jumps"] = 1
				Sfx.play("jump")
				spawn_puff(ob["x"] + float(d["w"]) * 0.5, ob["y"], 8)
	obstacles = obstacles.filter(func(ob): return ob["x"] + float(ob["def"]["w"]) > -40.0)

	var pk := player_hitbox()
	for c in coins_arr:
		c["x"] -= speed * dt
		c["t"] += dt
		var is_gem: bool = String(c["kind"]).begins_with("gem")
		var cx: float = c["x"]
		var cy: float = c["y"] + sin(c["t"] * 5.0) * 4.0
		var rr := 30.0 if is_gem else 26.0
		if absf(cx - pk["cx"]) < rr + pk["w"] * 0.5 and absf(cy - pk["cy"]) < rr + pk["h"] * 0.5:
			c["taken"] = true
			var worth := 10 if is_gem else 1
			coins += worth
			if is_gem:
				Sfx.play("gem")
			else:
				Sfx.play("coin")
			mood = "happy"
			mood_t = 0.7
			floaties.append({"x": c["x"], "y": c["y"], "txt": "+" + str(worth), "life": 0.8})
			spawn_spark(c["x"], c["y"], Color("2bd6ff") if is_gem else Color("ffd21e"))
	coins_arr = coins_arr.filter(func(c): return not c.get("taken", false) and c["x"] > -60.0)

	if not p["dead"]:
		for ob in obstacles:
			var d: Dictionary = ob["def"]
			if d.has("bounce"):
				continue
			if d.has("drop") and ob["drop_state"] != "landed":
				continue
			var hb := float(d["hb"])
			var ow := float(d["w"]) * hb
			var oh := float(d["h"]) * hb
			var rx: float = ob["x"] + (float(d["w"]) - ow) * 0.5
			var ry: float = ob["y"] - oh
			if pk["cx"] + pk["w"] * 0.5 > rx and pk["cx"] - pk["w"] * 0.5 < rx + ow and pk["cy"] + pk["h"] * 0.5 > ry and pk["cy"] - pk["h"] * 0.5 < ry + oh:
				die()
				break
		if p["dead"]:
			return

	for pt in particles:
		pt["x"] += pt["vx"] * dt
		pt["y"] += pt["vy"] * dt
		pt["vy"] += 700.0 * dt
		pt["life"] -= dt
	particles = particles.filter(func(pt): return pt["life"] > 0.0)
	for f in floaties:
		f["y"] -= 50.0 * dt
		f["life"] -= dt
	floaties = floaties.filter(func(f): return f["life"] > 0.0)

	var m := int(floor(dist / PX_PER_M))
	if not new_record and m > best and best > 0:
		new_record = true
		best = m
		Store.best = best
		Store.save()
		record_flash = 2.0
		Sfx.play("record")


# --------------------------------------------------------------- spawning ---

func spawn_obstacle(name: String, x: float) -> void:
	var d: Dictionary = Obs.DEFS[name]
	var ob := {"name": name, "def": d, "x": x, "t": _rng.randf() * 10.0, "ext": 0.0,
		"y": GY, "base_y": GY, "vy": 0.0, "spring": false, "spin": 0.0,
		"drop_state": "hang", "drop_t": 0.0}
	if d.has("drop"):
		var dp := drop_profile(speed)
		ob["drop_t"] = dp["T"]
		ob["y"] = dp["top"]
		ob["drop_state"] = "hang"
	elif d.has("fly"):
		ob["base_y"] = GY - float(d["fly"])
		ob["y"] = ob["base_y"]
	else:
		ob["y"] = GY
	obstacles.append(ob)

	var arc_x := x
	if d.has("drop"):
		arc_x = x - speed * ob["drop_t"]
	if not d.has("fly") and not d.has("hop") and not d.has("noLoot") and _rng.randf() < 0.62:
		var span := speed * jump_arc_span
		var apex_x := arc_x + float(d["w"]) / 2.0
		var x0 := apex_x - span * 0.5
		var spacing := maxf(34.0, span * 0.14)
		var n := maxi(3, mini(7, int(floor(span * 0.8 / spacing)) + 1))
		var lvl := level_idx()
		var coin_skin: String = Pal.COIN_SKIN[lvl]
		var gem_skin: String = Pal.GEM_SKIN[lvl]
		var gem_at := int(floor(_rng.randf() * n)) if _rng.randf() < 0.18 else -1
		for i in n:
			var f := 0.12 + 0.76 * (float(i) / float(maxi(1, n - 1)))
			coins_arr.append({
				"kind": gem_skin if i == gem_at else coin_skin,
				"x": x0 + span * f,
				"y": GY - 34.0 - arc_height(f),
				"t": 0.0,
			})


func update_spawning() -> void:
	if dist < spawn_at:
		return
	var m := dist / PX_PER_M
	var name := Obs.pick(level_idx())
	spawn_obstacle(name, W + 60.0)
	if m > 1600.0 and not next_is_pair and _rng.randf() < 0.35:
		var ground := "n_block" if _rng.randf() < 0.5 else "n_spikes"
		var gap := 170.0 + float(Obs.DEFS[name]["w"])
		spawn_obstacle(ground, W + 60.0 + gap)
		next_is_pair = true
	else:
		next_is_pair = false
	var g := 300.0 + _rng.randf() * 240.0 + speed * (0.55 + _rng.randf() * 0.55)
	spawn_at = dist + g


# -------------------------------------------------------------- particles ---

func spawn_puff(x: float, y: float, n: int) -> void:
	var p := pal()
	for i in n:
		particles.append({
			"x": x, "y": y - 4.0,
			"vx": -speed * 0.15 - _rng.randf() * 80.0,
			"vy": -_rng.randf() * 90.0,
			"life": 0.4 + _rng.randf() * 0.3, "max": 0.7,
			"size": 2.0 + _rng.randf() * 3.0, "col": p["neon"],
		})


func spawn_burst(x: float, y: float, n: int) -> void:
	var p := pal()
	for i in n:
		var a := _rng.randf() * TAU
		var v := 120.0 + _rng.randf() * 320.0
		particles.append({
			"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v - 100.0,
			"life": 0.6 + _rng.randf() * 0.5, "max": 1.1,
			"size": 3.0 + _rng.randf() * 4.0,
			"col": p["neon"] if _rng.randf() < 0.5 else Color.WHITE,
		})


func spawn_spark(x: float, y: float, col: Color) -> void:
	for i in 8:
		var a := _rng.randf() * TAU
		var v := 60.0 + _rng.randf() * 160.0
		particles.append({
			"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v,
			"life": 0.35, "max": 0.35, "size": 2.0 + _rng.randf() * 2.0, "col": col,
		})


# ------------------------------------------------------------------ input ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			on_press(e.position)
		else:
			on_release()
	elif event is InputEventScreenDrag:
		on_drag((event as InputEventScreenDrag).position)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			return
		if k.pressed:
			on_key(k)
		elif k.keycode == KEY_DOWN or k.keycode == KEY_S:
			if state == St.PLAY:
				set_duck(false)
	elif event is InputEventMouseMotion:
		if state == St.MENU:
			var b := button_at((event as InputEventMouseMotion).position)
			hover_id = String(b.get("id", "")) if not b.is_empty() else ""


func on_press(pos: Vector2) -> void:
	pointer_down = true
	if state == St.MENU:
		var b := button_at(pos)
		if not b.is_empty():
			run_menu_button(b["id"])
		return
	if state == St.PAUSE:
		var b := button_at(pos)
		if not b.is_empty():
			run_menu_button(b["id"])
		return
	if state == St.PLAY and pos.x > W - 70.0 and pos.y < 80.0:
		open_menu()
		return
	if state == St.DEAD:
		var b := button_at(pos)
		if not b.is_empty():
			run_menu_button(b["id"])
			return
	if state == St.PLAY:
		press_y = pos.y
		pending_jump = true
		pending_t = 0.0
	else:
		try_jump()


func on_drag(pos: Vector2) -> void:
	if state != St.PLAY:
		return
	var dy := pos.y - press_y
	if pending_jump and dy > 16.0:
		pending_jump = false
		set_duck(true)
	elif pending_jump and dy < -16.0:
		pending_jump = false
		do_jump()


func on_release() -> void:
	pointer_down = false
	if pending_jump:
		pending_jump = false
		try_jump()


func on_key(k: InputEventKey) -> void:
	match k.keycode:
		KEY_SPACE, KEY_UP, KEY_W, KEY_ENTER:
			if state == St.MENU:
				if menu_page == "main":
					start_game()
				else:
					menu_page = "main"
			else:
				try_jump()
		KEY_DOWN, KEY_S:
			if state == St.PLAY:
				set_duck(true)
		KEY_ESCAPE, KEY_P:
			if state == St.PLAY:
				open_menu()
			elif state == St.PAUSE:
				menu_page = "main"
				resume_game()
			elif state == St.MENU and menu_page != "main":
				menu_page = "main"
			elif state == St.DEAD:
				to_menu()
		KEY_M:
			if state == St.MENU:
				Music.set_enabled(not Music.on)
			else:
				Sfx.toggle()
		KEY_B:
			if state == St.MENU:
				menu_page = "board" if menu_page != "board" else "main"
				Sfx.play("ui")


# -------------------------------------------------------------------- menu ---

func menu_buttons() -> Array:
	var rows: Array = []
	if state == St.DEAD:
		rows.append([["restart", "ЕЩЁ РАЗ", Pal.BTN_W]])
		rows.append([["menu", "В ГЛАВНОЕ МЕНЮ", Pal.BTN_W]])
	elif menu_page == "pause":
		rows.append([["resume", "ПРОДОЛЖИТЬ", Pal.BTN_W]])
		rows.append([["sfx", "ЗВУК: ВЫКЛ" if Sfx.muted else "ЗВУК: ВКЛ", Pal.BTN_W * 0.5 - 6.0],
			["mus", "МУЗЫКА: ВКЛ" if Music.on else "МУЗЫКА: ВЫКЛ", Pal.BTN_W * 0.5 - 6.0]])
		rows.append([["menu", "В ГЛАВНОЕ МЕНЮ", Pal.BTN_W]])
	elif menu_page == "main":
		rows.append([["start", "СТАРТ", Pal.BTN_W]])
		rows.append([["board", "ТАБЛИЦА ЛИДЕРОВ", Pal.BTN_W]])
		rows.append([["howto", "КАК ИГРАТЬ", Pal.BTN_W]])
		rows.append([["sfx", "ЗВУК: ВЫКЛ" if Sfx.muted else "ЗВУК: ВКЛ", Pal.BTN_W * 0.5 - 6.0],
			["mus", "МУЗЫКА: ВКЛ" if Music.on else "МУЗЫКА: ВЫКЛ", Pal.BTN_W * 0.5 - 6.0]])
		rows.append([["exit", "ВЫХОД", Pal.BTN_W]])
	else:
		rows.append([["back", "НАЗАД", Pal.BTN_W]])

	var list: Array = []
	var total_h: float = rows.size() * Pal.BTN_H + (rows.size() - 1) * Pal.BTN_GAP
	var info_page := menu_page == "howto" or menu_page == "board"
	var area_top := (H - 40.0 - Pal.BTN_H) if info_page else Pal.TITLE_BOTTOM
	var area_bottom := H - 40.0
	var y := area_top if info_page else area_top + maxf(0.0, (area_bottom - area_top - total_h) * 0.5)
	for row in rows:
		var row_w := 0.0
		for r in row:
			row_w += float(r[2])
		row_w += (row.size() - 1) * Pal.BTN_GAP
		var x := W * 0.5 - row_w * 0.5
		for r in row:
			list.append({"id": r[0], "label": r[1], "x": x, "y": y, "w": float(r[2]), "h": Pal.BTN_H})
			x += float(r[2]) + Pal.BTN_GAP
		y += Pal.BTN_H + Pal.BTN_GAP
	return list


func button_at(pos: Vector2) -> Dictionary:
	for b in menu_buttons():
		if pos.x >= b["x"] and pos.x <= b["x"] + b["w"] and pos.y >= b["y"] and pos.y <= b["y"] + b["h"]:
			return b
	return {}


func run_menu_button(id: String) -> void:
	match id:
		"start":
			start_game()
		"restart":
			start_game()
		"board":
			menu_page = "board"
			Sfx.play("ui")
		"howto":
			menu_page = "howto"
			Sfx.play("ui")
		"back":
			menu_page = "main"
			Sfx.play("ui")
		"resume":
			menu_page = "main"
			resume_game()
		"menu":
			to_menu()
		"sfx":
			Sfx.toggle()
			Sfx.play("ui")
		"mus":
			Music.set_enabled(not Music.on)
			Sfx.play("ui")
		"exit":
			to_menu()
			if OS.get_name() == "Android":
				get_tree().quit()


# ------------------------------------------------------------------- draw ---

func _draw() -> void:
	var p := pal()
	pen.xf = Transform2D.IDENTITY
	pen.alpha = 1.0
	pen.rect(Rect2(-4, -4, W + 8, H + 8), Color("05060f"))

	var sx := 0.0
	var sy := 0.0
	if shake > 0.0:
		sx = (_rng.randf() - 0.5) * shake
		sy = (_rng.randf() - 0.5) * shake
	pen.translate(Vector2(sx, sy))

	bg.draw(pen, p, level_idx(), dist, bg_t)
	draw_ground(p)

	if state == St.PLAY and speed > 380.0:
		pen.alpha = 0.18
		for i in 5:
			var yy := 80.0 + fmod(float(i) * 137.0 + bg_t * 60.0 * speed * 0.3, GY - 160.0)
			var xx := fposmod(float(i) * 211.0 + bg_t * -speed * 1.2, W + 200.0) - 100.0
			pen.line(Vector2(xx, yy), Vector2(xx + 60.0, yy), p["neon"], 2.0)
		pen.alpha = 1.0

	for c in coins_arr:
		draw_coin(c)
	for ob in obstacles:
		Obs.draw(pen, ob["name"], ob, hazard_palette())
	draw_player(p)

	for pt in particles:
		pen.alpha = maxf(0.0, float(pt["life"]) / float(pt["max"]))
		var s := roundf(float(pt["size"]))
		pen.rect(Rect2(roundf(float(pt["x"]) - s * 0.5), roundf(float(pt["y"]) - s * 0.5), s, s), pt["col"])
	pen.alpha = 1.0

	for f in floaties:
		pen.alpha = minf(1.0, float(f["life"]) * 2.0)
		pen.text(String(f["txt"]), Vector2(f["x"], f["y"]), 22, Color("ffd21e"), "center", true)
	pen.alpha = 1.0

	if flash > 0.0:
		pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(1, 1, 1, flash * 0.5))

	if state == St.PLAY:
		draw_hud(p)
	if state == St.MENU:
		draw_menu(p)
	if state == St.PAUSE:
		draw_pause(p)
	if state == St.DEAD:
		draw_dead(p)
		draw_buttons(p)


func draw_ground(p: Dictionary) -> void:
	pen.rect(Rect2(-20, GY, W + 40, H - GY + 20), Color("070818"))
	pen.glow_line(Vector2(-20, GY + 1.5), Vector2(W + 20, GY + 1.5), p["neon"], 3.0, 12.0)
	pen.alpha = 0.8
	for i in range(-1, 9):
		var y := GY + 14.0 + float(i) * float(i) * 2.6 + 10.0
		if y > H:
			break
		pen.line(Vector2(-20, y), Vector2(W + 20, y), p["dim"], 1.5)
	pen.alpha = 0.5
	var vscroll := fmod(dist * 1.1, 80.0)
	for i in range(-1, 8):
		var x := float(i) * 80.0 - fmod(vscroll, 80.0)
		pen.line(Vector2(x, GY + 2.0), Vector2(x - 30.0, H), p["dim"], 1.5)
	pen.alpha = 1.0


func draw_coin(c: Dictionary) -> void:
	var y: float = c["y"] + sin(float(c["t"]) * 5.0) * 4.0
	var kind := String(c["kind"])
	var is_gem := kind.begins_with("gem")
	var col := Color("ffd21e")
	if is_gem:
		col = Color("2bd6ff")
		if kind == "gem_red":
			col = Color("ff4d6d")
		elif kind == "gem_yellow":
			col = Color("ffd24a")
		elif kind == "gem_green":
			col = Color("7cff5a")
	elif kind == "coin_silver":
		col = Color("d8e6ff")
	elif kind == "coin_bronze":
		col = Color("e0a86a")
	if is_gem:
		var pts := PackedVector2Array([
			Vector2(c["x"], y - 18), Vector2(c["x"] + 13, y),
			Vector2(c["x"], y + 18), Vector2(c["x"] - 13, y)])
		pen.glow_polyline(pts, col, 2.0, 18.0, true)
		pen.polygon(pts, Color(0.03, 0.05, 0.1, 0.8))
		pen.polyline(pts, col, 2.0, true)
		pen.polyline(PackedVector2Array([
			Vector2(c["x"], y - 7), Vector2(c["x"] + 5, y),
			Vector2(c["x"], y + 7), Vector2(c["x"] - 5, y)]), col, 1.0, true)
	else:
		var r := 15.0
		pen.glow_circle(Vector2(c["x"], y), r, col, 12.0)
		pen.circle(Vector2(c["x"], y), r, col)
		pen.circle(Vector2(c["x"], y), r * 0.58, Color(col.r * 0.55, col.g * 0.5, col.b * 0.3, 0.9))
		pen.ring(Vector2(c["x"], y), r * 0.78, Color(1, 1, 1, 0.55), 1.2)


func draw_player(p: Dictionary) -> void:
	var pl := player
	var duck: bool = pl["ducking"] and pl["on_ground"] and not pl["dead"]
	var air_duck: bool = pl["ducking"] and not pl["on_ground"] and not pl["dead"]

	var vy_n: float = pl["vy"] / 900.0
	if pl["on_ground"] and not last_on_ground and not pl["dead"]:
		cam_ty += 14.0
		for i in 6:
			var a := PI * 0.4 + (_rng.randf() - 0.5) * 0.6
			var v := 40.0 + _rng.randf() * 60.0
			particles.append({
				"x": pl["x"] + (_rng.randf() - 0.5) * 18.0, "y": GY,
				"vx": cos(a) * v - speed * 0.1, "vy": sin(a) * -v * 0.6,
				"life": 0.25 + _rng.randf() * 0.2, "max": 0.35,
				"size": 2.0 + _rng.randf() * 2.0, "col": p["neon"],
			})
	last_on_ground = pl["on_ground"]
	cam_tx = clampf(vy_n * 4.5, -6.0, 6.0)
	cam_ty = clampf((12.0 * pl["land_t"] / 0.18 if pl["land_t"] > 0.0 else 0.0) + (0.0 if pl["on_ground"] else vy_n * -8.0), -14.0, 20.0)
	cam_x += (cam_tx - cam_x) * 0.18
	cam_y += (cam_ty - cam_y) * 0.16

	var ph := fmod(float(pl["anim"]), 1.0) * TAU
	var bob_y := 0.0
	var lean := 0.0
	var sx := 1.0
	var sy := 1.0
	var leg_a := 0.0
	var leg_b := 0.0
	var arm_a := 0.0
	var arm_b := 0.0
	var lift_a := 0.0
	var lift_b := 0.0
	var crouch := 0.0
	var tuck := 0.0

	if pl["dead"]:
		lean = minf(float(pl["dead_t"]) * 3.0, 1.35)
		arm_a = -1.2
		arm_b = -1.5
		leg_a = 0.5
		leg_b = -0.4
		sx = 1.06
		sy = 0.94
	elif duck:
		crouch = 1.0
		var w := sin(bg_t * 6.0) * 0.06
		leg_a = 0.55 + w
		leg_b = -0.55 + w
		arm_a = 0.9
		arm_b = -0.6
		sx = 1.09
		sy = 0.86
		lean = 0.09
	elif air_duck:
		lean = -0.28
		tuck = 1.0
		leg_a = 0.5
		leg_b = -0.3
		arm_a = -1.5
		arm_b = -1.0
		sx = 0.93
		sy = 1.09
	elif not pl["on_ground"]:
		var up: bool = pl["vy"] < 0.0
		var v: float = pl["vy"] / 900.0
		lean = clampf(v, -0.36, 0.36) * 0.18
		var t := minf(1.0, absf(pl["vy"]) / 1100.0)
		if up:
			leg_a = 0.7
			leg_b = -0.5
			arm_a = -0.9
			arm_b = -1.4
			sx = 0.91
			sy = 1.15 - t * 0.04
		else:
			leg_a = -0.35
			leg_b = 0.45
			arm_a = 0.5
			arm_b = 0.9
			sx = 0.95
			sy = 1.10 - t * 0.07
	else:
		var s1 := sin(ph)
		var s2 := sin(ph + PI)
		leg_a = s1 * 0.62
		leg_b = s2 * 0.62
		lift_a = maxf(0.0, -cos(ph)) * 0.55
		lift_b = maxf(0.0, -cos(ph + PI)) * 0.55
		var lag := ph - 0.6
		arm_a = sin(lag + PI) * 0.72
		arm_b = sin(lag) * 0.72
		bob_y = -absf(sin(ph)) * 3.0
		lean = -0.09 - sin(ph * 2.0) * 0.035
		if pl["land_t"] > 0.0:
			var k := minf(1.0, float(pl["land_t"]) / 0.18)
			var ease := 1.0 - pow(1.0 - k, 3.0)
			sy = 1.0 - (0.20 * ease) * (1.0 - ease * 0.35)
			sx = 1.0 + (0.17 * ease) * (1.0 - ease * 0.35)
			lean += 0.07 * (1.0 - ease)
			bob_y -= 1.9 * (1.0 - ease)

	var crouch_k := crouch
	var leg_h := 32.0 * (1.0 - crouch_k * 0.26)
	var leg_w := 9.5
	var drop_a := (leg_h * cos(leg_a) + leg_w * sin(absf(leg_a))) * (1.0 - lift_a * 0.5)
	var drop_b := (leg_h * cos(leg_b) + leg_w * sin(absf(leg_b))) * (1.0 - lift_b * 0.5)

	pen.save()
	pen.translate(Vector2(pl["x"] + cam_x, pl["y"] + bob_y + cam_y))
	pen.rotate(lean * 0.8 + cam_x * 0.0012)
	pen.scale(Vector2(sx, sy))
	hero.draw("hoodie", {
		"hipY": -maxf(drop_a, drop_b),
		"legH": leg_h, "legW": leg_w,
		"bodyH": 25.0 * (1.0 - crouch_k * 0.20),
		"armH": 26.0 * (1.0 - crouch_k * 0.10),
		"headR": 10.5 * (1.0 - crouch_k * 0.10),
		"legA": leg_a, "legB": leg_b,
		"legLiftA": lift_a, "legLiftB": lift_b,
		"armA": arm_a, "armB": arm_b,
		"t": bg_t,
		"speed": minf(1.6, 0.55 + speed / 900.0),
		"accent": p["neon"],
		"glowCol": Color(p["neon"].r, p["neon"].g, p["neon"].b, 0.55),
		"scarfCol": Color(0.949, 0.996, 1.0, 0.95),
	})
	pen.restore()


# -------------------------------------------------------------------- HUD ---

func coin_icon(x: float, y: float, r: float) -> void:
	pen.glow_circle(Vector2(x + r, y), r, Color("ffd21e"), 10.0)
	pen.circle(Vector2(x + r, y), r, Color("ffd21e"))
	pen.circle(Vector2(x + r, y), r * 0.55, Color(0.47, 0.31, 0.0, 0.55))


func coin_count(x: float, y: float, size: float, count: int, col: Color, glow := false) -> void:
	var label := str(count)
	var tw := pen.text_width(label, size)
	var r := size * 0.42
	var total := r * 2.0 + 6.0 + tw
	var left := x - total
	coin_icon(left, y - size * 0.30, r)
	pen.text(label, Vector2(x, y), size, col, "right", glow)


func coin_row_centered(cx: float, y: float, size: float, count: int, col: Color, glow := false) -> void:
	var label := str(count)
	var tw := pen.text_width(label, size)
	var r := size * 0.42
	var total := r * 2.0 + 6.0 + tw
	var left := cx - total * 0.5
	coin_icon(left, y - size * 0.30, r)
	pen.text(label, Vector2(left + r * 2.0 + 6.0, y), size, col, "left", glow)


func draw_hud(p: Dictionary) -> void:
	var m := int(floor(dist / PX_PER_M))
	pen.text(str(m) + " м", Vector2(24, 52), 34, p["neon"], "left", true)
	pen.text("Рекорд " + str(best), Vector2(24, 82), 18, Color(1, 1, 1, 0.8), "left", true)
	var lvl := level_idx()
	pen.text("Уровень " + str(lvl + 1) + " • " + _title(Pal.LEVEL_NAMES[lvl]), Vector2(24, 112), 15, Color(1, 1, 1, 0.7), "left")
	if lvl < DIFF_MAX:
		var in_lvl := fmod(dist / PX_PER_M, DIFF_LEN)
		var pct := in_lvl / DIFF_LEN
		pen.rect(Rect2(24, 124, 150, 4), Color(1, 1, 1, 0.15))
		pen.rect(Rect2(24, 124, 150 * pct, 4), p["neon"])
	coin_count(W - 24.0, 116.0, 22.0, coins, Color("ffd21e"), true)

	pen.round_rect(Rect2(W - 62, 16, 46, 46), Color(1, 1, 1, 0.15))
	pen.rect(Rect2(W - 48, 28, 6, 22), Color.WHITE)
	pen.rect(Rect2(W - 36, 28, 6, 22), Color.WHITE)

	if record_flash > 0.0:
		var a := minf(1.0, record_flash)
		pen.alpha = a * (0.7 + 0.3 * sin(bg_t * 12.0))
		pen.text("НОВЫЙ РЕКОРД!", Vector2(W * 0.5, 160), 30, Color("ffd21e"), "center", true)
		pen.alpha = 1.0

	if Store.first_run:
		pen.alpha = 0.85
		pen.text("тап снизу — прыжок", Vector2(W * 0.5, H * 0.55), 22, Color.WHITE)
		pen.text("тап сверху / свайп вниз — приседание", Vector2(W * 0.5, H * 0.55 + 30.0), 18, Color(1, 1, 1, 0.7))
		pen.alpha = 1.0

	if level_banner_t > 0.0:
		var a := minf(1.0, level_banner_t / 0.5) * minf(1.0, (2.6 - level_banner_t) / 0.3)
		pen.alpha = maxf(0.0, a)
		pen.rect(Rect2(-20, H * 0.34, W + 40, 86), Color(0.02, 0.024, 0.06, 0.55))
		pen.text("Уровень " + str(shown_level + 1) + " • " + _title(Pal.LEVEL_NAMES[shown_level]), Vector2(W * 0.5, H * 0.34 + 38.0), 26, p["neon"], "center", true)
		pen.text(_title(Pal.LEVEL_NAMES[shown_level]), Vector2(W * 0.5, H * 0.34 + 68.0), 20, Color.WHITE, "center", true)
		pen.alpha = 1.0


func draw_button(b: Dictionary, p: Dictionary) -> void:
	var hot: bool = String(b["id"]) == hover_id
	var r := Rect2(b["x"], b["y"], b["w"], b["h"])
	pen.round_rect(r, Color(1, 1, 1, 0.14 if hot else 0.05))
	pen.glow_round_rect(r, Color.WHITE if hot else p["neon"], 22.0 if hot else 10.0, 3.0 if hot else 2.0, 12.0)
	pen.round_rect_outline(r, Color.WHITE if hot else p["neon"], 3.0 if hot else 2.0, 12.0)
	var size := float(b["h"]) * 0.46
	var max_w := float(b["w"]) - 28.0
	var tw := pen.text_width(String(b["label"]), size)
	if tw > max_w:
		size = maxf(11.0, size * (max_w / tw))
	pen.text(String(b["label"]), Vector2(float(b["x"]) + float(b["w"]) * 0.5, float(b["y"]) + float(b["h"]) * 0.5 + size * 0.36),
		size, Color.WHITE if hot else Color(1, 1, 1, 0.9), "center", hot)


func draw_buttons(p: Dictionary) -> void:
	for b in menu_buttons():
		draw_button(b, p)


func draw_menu(p: Dictionary) -> void:
	var bounce := sin(bg_t * 2.2) * 3.0
	if menu_page == "board":
		pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.024, 0.06, 0.9))
		pen.text("ТАБЛИЦА ЛИДЕРОВ", Vector2(W * 0.5, 120), 34, p["neon"], "center", true)
		draw_board_page(p)
		draw_buttons(p)
		return
	if menu_page == "howto":
		pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.024, 0.06, 0.9))
		pen.text("КАК ИГРАТЬ", Vector2(W * 0.5, 120), 34, p["neon"], "center", true)
		draw_howto_page(p)
		draw_buttons(p)
		return

	pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.024, 0.06, 0.55))
	pen.text("NEON RUN", Vector2(W * 0.5, 110), 56, p["neon"], "center", true)
	var br := sin(bg_t * 1.7) * 1.4
	var la := 0.10 + sin(bg_t * 1.7) * 0.015
	var lb := -0.09 - sin(bg_t * 1.7) * 0.015
	pen.save()
	pen.translate(Vector2(W * 0.5 - 66.0, 252.0 + bounce + br))
	pen.scale(Vector2(1.33, 1.33))
	hero.draw("hoodie", {
		"hipY": -maxf(32.0 * cos(la) + 9.5 * sin(absf(la)), 32.0 * cos(lb) + 9.5 * sin(absf(lb))),
		"legH": 32.0, "legA": la, "legB": lb,
		"legLiftA": 0.04, "legLiftB": 0.02,
		"armA": 0.16 + sin(bg_t * 1.7) * 0.05, "armB": -0.12,
		"speed": 0.5, "t": bg_t,
		"accent": p["neon"],
		"glowCol": Color(p["neon"].r, p["neon"].g, p["neon"].b, 0.55),
		"scarfCol": Color(0.949, 0.996, 1.0, 0.95),
	})
	pen.restore()
	pen.text("рекорд", Vector2(W * 0.5 + 54.0, 214), 18, Color(1, 1, 1, 0.55))
	pen.text(str(best) + " м", Vector2(W * 0.5 + 54.0, 250), 30, Color("ffd21e"), "center", true)
	draw_buttons(p)
	pen.text("тап/↑/пробел — прыжок   •   свайп вниз — подкат/скольжение", Vector2(W * 0.5, H - 20.0), 13, Color(1, 1, 1, 0.45))


func draw_board_page(p: Dictionary) -> void:
	var list: Array = Store.scores
	if list.is_empty():
		pen.text("пока пусто — стань первым!", Vector2(W * 0.5, 300), 22, Color(1, 1, 1, 0.6))
	else:
		var x0 := W * 0.5 - 210.0
		var y0 := 172.0
		var rh := 50.0
		for i in list.size():
			var e: Dictionary = list[i]
			var y := y0 + float(i) * rh
			var me: bool = i + 1 == board_rank
			pen.round_rect(Rect2(x0, y, 420, rh - 8.0), Color(1, 0.824, 0.118, 0.14) if me else Color(1, 1, 1, 0.04))
			pen.round_rect_outline(Rect2(x0, y, 420, rh - 8.0), Color("ffd21e") if me else Color(1, 1, 1, 0.12), 2.0 if me else 1.0, 8.0)
			pen.text(str(i + 1) + ".", Vector2(x0 + 26, y + 28), 22, Color("ffd21e") if me else Color(1, 1, 1, 0.5))
			pen.text(str(e.get("m", 0)) + " м", Vector2(x0 + 130, y + 29), 23, Color("ffd21e") if me else Color.WHITE, "left", me)
			pen.text("lvl " + str(e.get("lv", 1)), Vector2(x0 + 336, y + 29), 19, Color(1, 1, 1, 0.5), "left")
			coin_icon(x0 + 250, y + 19, 9.0)
			pen.text(str(e.get("c", 0)), Vector2(x0 + 268, y + 29), 19, Color(1, 1, 1, 0.7), "left")
	pen.text("сохраняется на этом устройстве", Vector2(W * 0.5, 452), 14, Color(1, 1, 1, 0.35))


func draw_howto_page(p: Dictionary) -> void:
	var lines := [
		["Прыжок", "тап или свайп вверх"],
		["Двойной прыжок", "тап в воздухе"],
		["Подкат/скольжение", "свайп вниз по земле"],
		["Монетка", "+1 очко"],
		["Алмаз", "+10 очков"],
		["Уровень", "2000 м, всего 10"],
		["Медаль", "за каждый уровень"],
		["Пауза", "кнопка ⏸ или ESC"],
	]
	var x0 := 42.0
	var y := 172.0
	for pair in lines:
		var kw := pen.text_width(pair[0], 21)
		pen.text(pair[0], Vector2(x0, y), 21, Color.WHITE, "left", true)
		pen.text("— " + pair[1], Vector2(x0 + kw + 12.0, y), 18, Color(1, 1, 1, 0.6), "left")
		y += 42.0


func draw_pause(p: Dictionary) -> void:
	pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.024, 0.06, 0.82))
	pen.text("ПАУЗА", Vector2(W * 0.5, 150), 46, p["neon"], "center", true)
	var m := int(floor(dist / PX_PER_M))
	pen.text(str(m) + " м", Vector2(W * 0.5 - 70.0, 196), 20, Color(1, 1, 1, 0.65))
	coin_count(W * 0.5 + 60.0, 196.0, 20.0, coins, Color(1, 1, 1, 0.65))
	draw_buttons(p)


func draw_medals(y: float) -> void:
	var mask := Store.medals
	var n := Pal.N_LEVELS
	var per_row := 5
	var r := 16.0
	var col_gap := 84.0
	var row_gap := 64.0
	for i in n:
		var row := int(floor(float(i) / float(per_row)))
		var col := i % per_row
		var in_row := mini(per_row, n - row * per_row)
		var x := W * 0.5 - float(in_row - 1) * col_gap * 0.5 + float(col) * col_gap
		var cy := y + float(row) * row_gap
		var earned := (mask & (1 << i)) != 0
		var col_c := Color(Pal.MEDAL_COLS[i])
		pen.alpha = 1.0 if earned else 0.22
		if earned:
			pen.glow_circle(Vector2(x, cy), r, col_c, 10.0)
		pen.circle(Vector2(x, cy), r, col_c)
		pen.text(str(int(Pal.medal_target(i) / 1000.0)) + "k", Vector2(x, cy + 4.0), 11, Color("05060f"))
		pen.alpha = 1.0


func draw_dead(p: Dictionary) -> void:
	pen.rect(Rect2(-20, -20, W + 40, H + 40), Color(0.02, 0.024, 0.06, 0.6))
	var m := int(floor(dist / PX_PER_M))
	if new_record:
		pen.alpha = 0.7 + 0.3 * sin(bg_t * 10.0)
		pen.text("НОВЫЙ РЕКОРД!", Vector2(W * 0.5, 250), 44, Color("ffd21e"), "center", true)
		pen.alpha = 1.0
	else:
		pen.text("ПРОВАЛ", Vector2(W * 0.5, 250), 48, p["neon"], "center", true)
	pen.text(str(m) + " м", Vector2(W * 0.5, 322), 56, Color.WHITE, "center", true)
	pen.text("рекорд: " + str(best) + " м", Vector2(W * 0.5, 362), 20, Color(1, 1, 1, 0.7))
	coin_row_centered(W * 0.5, 394.0, 22.0, coins, Color(1, 1, 1, 0.85), true)
	if board_rank > 0:
		pen.alpha = 0.75 + 0.25 * sin(bg_t * 8.0)
		pen.glow_circle(Vector2(W * 0.5 - 118.0, 421.0), 9.0, Color("ffd21e"), 10.0)
		pen.circle(Vector2(W * 0.5 - 118.0, 421.0), 9.0, Color("ffd21e"))
		pen.text("место в лидерах: " + str(board_rank), Vector2(W * 0.5 + 8.0, 428), 20, Color("ffd21e"), "center", true)
		pen.alpha = 1.0
	draw_medals(486.0)
	if medal_flash > 0.0:
		pen.alpha = minf(1.0, medal_flash)
		pen.text(medal_flash_text + "!", Vector2(W * 0.5, 618), 24, Color("ffd700"), "center", true)
		pen.alpha = 1.0
	if dead_at > 0.4:
		pen.alpha = 0.6 + 0.4 * sin(bg_t * 4.0)
		pen.text("ТАП/ENTER — ЕЩЁ РАЗ • ESC — В МЕНЮ", Vector2(W * 0.5, 728), 16, Color(1, 1, 1, 0.5), "center", true)
		pen.alpha = 1.0


# --------------------------------------------------------------- automation ---

func _maybe_screenshot() -> void:
	if _shot_path == "" or _frames < _shot_frames:
		return
	var path := _shot_path
	_shot_path = ""
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()


func _notification(what: int) -> void:
	# Автопауза: web/десктоп приходят оконным событием (window.blur),
	# мобильные платформы — событиями жизненного цикла приложения.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_game(true)
