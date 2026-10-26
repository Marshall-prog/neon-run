## Game constants, levels, palettes — a 1:1 port of the constants block of the
## original index.html.
class_name Pal
extends RefCounted

const W := 480.0
const H := 800.0
const GY := 660.0

const GRAVITY := 2800.0
const JUMP_V := -1080.0
const DJUMP_V := -950.0
const SPEED0 := 300.0
const SPEED_MAX := 900.0
const SPEED_SQRT := 4.6
const PX_PER_M := 10.0
const DIFF_LEN := 2000.0
const DIFF_MAX := 9
const N_LEVELS := 10
const START_GATE_MAX := 0.9

const BTN_W := 300.0
const BTN_H := 60.0
const BTN_GAP := 12.0
const TITLE_BOTTOM := 300.0

const COIN_SKIN := ["coin", "coin", "coin", "coin", "coin",
	"coin_silver", "coin_silver", "coin_bronze", "coin_bronze", "coin"]
const GEM_SKIN := ["gem", "gem_green", "gem", "gem_green", "gem_green",
	"gem", "gem_red", "gem_yellow", "gem_red", "gem_yellow"]

const PALETTES := [
	{"neon": "#00fff0", "dim": "#0a3a3f", "glow": "#00c8d6"},
	{"neon": "#ff2bd6", "dim": "#3f0a34", "glow": "#d61eb0"},
	{"neon": "#b967ff", "dim": "#2d1045", "glow": "#9a4fe0"},
	{"neon": "#2bd6ff", "dim": "#0a2d3f", "glow": "#1eb0d6"},
	{"neon": "#7cff5a", "dim": "#123f0a", "glow": "#5fd647"},
	{"neon": "#8fe9ff", "dim": "#0b2a3a", "glow": "#5fc8e8"},
	{"neon": "#ff7a1a", "dim": "#3f1405", "glow": "#e85a10"},
	{"neon": "#ffd24a", "dim": "#3d2e08", "glow": "#e0a91e"},
	{"neon": "#ff4d6d", "dim": "#2a0713", "glow": "#d61e46"},
	{"neon": "#e8ff3a", "dim": "#1a2a06", "glow": "#b6d61e"},
]

const HAZARD := [
	{"neon": "#ffe9ee", "glow": "#ff2d55"},
	{"neon": "#e6fff4", "glow": "#22d98a"},
	{"neon": "#fff7e0", "glow": "#ffb020"},
	{"neon": "#fff0e6", "glow": "#ff7a1f"},
	{"neon": "#fff5fd", "glow": "#ff2bb0"},
	{"neon": "#fff0e6", "glow": "#ff5a1f"},
	{"neon": "#e0faff", "glow": "#20c8ff"},
	{"neon": "#e6ecff", "glow": "#4d6bff"},
	{"neon": "#e0fff9", "glow": "#14e0c0"},
	{"neon": "#fbf7ff", "glow": "#8a4dff"},
]

const LEVEL_NAMES := [
	"НЕОНОВЫЙ ГОРИЗОНТ", "ЗАКАТНЫЙ ГОРОД", "ЛУННЫЕ ГОРЫ", "СИНТВЕЙВ", "НЕОНОВЫЙ ЛЕС",
	"ЛЕДЯНОЙ КАНЬОН", "ВУЛКАН", "НЕОНОВАЯ ПУСТЫНЯ", "ПОДЗЕМЕЛЬЕ", "ЦИФРОВОЕ ЯДРО",
]

const MEDAL_COLS := ["#cd7f32", "#c0c0c0", "#ffd700", "#9fe8ff", "#7cff5a",
	"#bfe6ff", "#ff7a1a", "#ffd24a", "#ff4d6d", "#e8ff3a"]

const BG := "#05060f"


static func color(hex: String) -> Color:
	return Color(hex)


static func hex_rgba(hex: String, a: float) -> Color:
	var c := Color(hex)
	c.a = a
	return c


static func lerp_color(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


static func medal_target(i: int) -> float:
	return float(i + 1) * DIFF_LEN


static func medal_name(i: int) -> String:
	var base := ["Бронзовая", "Серебряная", "Золотая", "Платиновая", "Изумрудная",
		"Ледяная", "Огненная", "Песчаная", "Кристальная", "ЛЕГЕНДА"]
	if i < 0 or i >= base.size():
		return "Медаль"
	return base[i] + ("" if i == 9 else " медаль")


static func to_title_case(s: String) -> String:
	if s.is_empty():
		return s
	var out := ""
	var upper_next := true
	for i in s.length():
		var ch := s[i]
		if upper_next and ch != " " and ch != "-" and ch != "(" and ch != "[" and ch != "/":
			out += ch.to_upper()
			upper_next = false
		elif ch == " " or ch == "-" or ch == "(" or ch == "[" or ch == "/":
			out += ch
			upper_next = true
		else:
			out += ch.to_lower()
	return out
