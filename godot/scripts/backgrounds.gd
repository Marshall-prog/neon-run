## Procedural backdrops: one permanent scene per difficulty level, ported 1:1
## from drawBackground() and its helpers.
class_name Bg
extends RefCounted

const GY := 660.0
const W := 480.0
const H := 800.0
const RIDGE_PITCH := 46.0


class Rng:
	var s: int
	func _init(seed: int) -> void:
		s = seed
	func next() -> float:
		s = (s * 16807) % 2147483647
		return float(s) / 2147483647.0


func make_ridges(seed: int, amp: float, base: float, count: int) -> PackedFloat32Array:
	var r := Rng.new(seed)
	var pts := PackedFloat32Array()
	for i in count + 1:
		pts.append(base - r.next() * amp)
	return pts


func make_buildings(seed: int, count: int, min_w: float, max_w: float, min_h: float, max_h: float, span: float) -> Dictionary:
	var r := Rng.new(seed)
	var list: Array = []
	var x := 0.0
	for i in count:
		var w := min_w + floorf(r.next() * (max_w - min_w))
		var h := min_h + floorf(r.next() * (max_h - min_h))
		list.append({"x": x, "w": w, "h": h, "seed": int(floorf(r.next() * 1e9))})
		x += w + 8.0 + floorf(r.next() * 30.0)
		if x > span:
			break
	return {"list": list, "span": span}


func make_trees(seed: int, count: int, min_h: float, max_h: float, span: float) -> Dictionary:
	var r := Rng.new(seed)
	var list: Array = []
	var x := 0.0
	for i in count:
		var h := min_h + floorf(r.next() * (max_h - min_h))
		var w := h * (0.55 + r.next() * 0.3)
		list.append({"x": x, "w": w, "h": h})
		x += w * 0.5 + 6.0 + floorf(r.next() * 26.0)
		if x > span:
			break
	return {"list": list, "span": span}


func make_gems(seed: int, count: int, span: float) -> Dictionary:
	var r := Rng.new(seed)
	var list: Array = []
	var x := 0.0
	for i in count:
		var h := 30.0 + floorf(r.next() * 110.0)
		var w := h * (0.3 + r.next() * 0.25)
		list.append({"x": x, "w": w, "h": h, "lean": (r.next() - 0.5) * 0.5})
		x += w + 24.0 + floorf(r.next() * 70.0)
		if x > span:
			break
	return {"list": list, "span": span}


# ------------------------------------------------------------------ world ---

var stars: Array = []
var ridges_far: PackedFloat32Array
var ridges_near: PackedFloat32Array
var ridges_moon: PackedFloat32Array
var ridges_ice: PackedFloat32Array
var ridges_lava: PackedFloat32Array
var ridges_dune: PackedFloat32Array
var dune_far: PackedFloat32Array
var city_far: Dictionary
var city_near: Dictionary
var trees_far: Dictionary
var trees_near: Dictionary
var crystals: Dictionary
var crystals_far: Dictionary
var pillars: Dictionary
var clouds: Array = []
var aurora: Array = []
var ash: Array = []
var data_cols: Array = []

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	for i in 90:
		stars.append({
			"x": _rng.randf() * W,
			"y": _rng.randf() * (GY - 120.0),
			"z": 0.15 + _rng.randf() * 0.35,
			"tw": _rng.randf() * PI * 2.0,
		})
	ridges_far = make_ridges(1234, 170, GY - 40, 32)
	ridges_near = make_ridges(777, 110, GY, 32)
	ridges_moon = make_ridges(999, 230, GY - 10, 30)
	ridges_ice = make_ridges(313, 300, GY - 30, 30)
	ridges_lava = make_ridges(464, 200, GY - 20, 30)
	ridges_dune = make_ridges(808, 90, GY - 10, 30)
	dune_far = make_ridges(151, 60, GY - 30, 34)
	city_far = make_buildings(42, 16, 44, 96, 80, 230, 1100)
	city_near = make_buildings(99, 12, 64, 132, 130, 330, 1100)
	trees_far = make_trees(55, 22, 46, 110, 1100)
	trees_near = make_trees(31, 14, 80, 180, 1100)
	crystals = make_gems(717, 20, 1100)
	crystals_far = make_gems(242, 26, 1100)
	pillars = make_buildings(606, 14, 30, 70, 120, 300, 1100)
	var r := Rng.new(2026)
	for i in 7:
		clouds.append({
			"x": r.next() * 1400.0,
			"y": 70.0 + r.next() * 240.0,
			"w": 90.0 + r.next() * 90.0,
			"z": 0.08 + r.next() * 0.12,
		})
	for i in 4:
		aurora.append({
			"y": 60.0 + i * 46.0,
			"amp": 22.0 + _rng.randf() * 26.0,
			"ph": _rng.randf() * PI * 2.0,
			"sp": 0.15 + _rng.randf() * 0.2,
			"w": 0.6 + _rng.randf() * 0.5,
		})
	for i in 46:
		ash.append({
			"x": _rng.randf() * W,
			"y": _rng.randf() * (GY - 80.0),
			"z": 0.2 + _rng.randf() * 0.6,
			"r": 1.0 + _rng.randf() * 2.2,
			"tw": _rng.randf() * 6.28,
		})
	for i in 22:
		data_cols.append({
			"x": _rng.randf() * W,
			"y": _rng.randf() * GY,
			"sp": 60.0 + _rng.randf() * 200.0,
			"len": 60.0 + _rng.randf() * 160.0,
		})


static func _cc(v: Variant) -> Color:
	if v is Color:
		return v
	return Color(String(v))


func draw(pen: Pen, pal: Dictionary, ti: int, dist: float, bg_t: float) -> void:
	var neon: Color = pal["neon"]
	var dim: Color = pal["dim"]
	var glow: Color = pal["glow"]

	# sky
	pen.vgrad(Rect2(-20, -20, W + 40, GY + 20), Color("05060f"), dim)

	# stars (parallax, twinkle)
	if ti != 3:
		for st in stars:
			var x := fposmod(st["x"] - dist * st["z"] * 0.05, W + 40.0) - 20.0
			var a := 0.25 + 0.25 * sin(bg_t * 2.0 + st["tw"])
			pen.rect(Rect2(roundf(x), roundf(st["y"]), 2, 2), Color(1, 1, 1, a))

	match ti:
		0:
			pen.alpha = 0.9
			var p1 := Pen.quad_pts(Vector2(-30, GY - 180), Vector2(W * 0.5, GY - 210), Vector2(W + 30, GY - 180), 24)
			pen.glow_polyline(p1, neon, 2.0, 10.0)
			pen.alpha = 0.4
			var p2 := Pen.quad_pts(Vector2(-30, GY - 178), Vector2(W * 0.5, GY - 206), Vector2(W + 30, GY - 178), 24)
			pen.polyline(p2, glow, 1.0)
			pen.alpha = 1.0
			draw_ridge(pen, ridges_near, 0.6, neon, Color("060814"), 0.9, dist)
		1:
			draw_sun(pen, pal, 0.55, W * 0.5, GY - 430, 80)
			draw_buildings(pen, city_far, 0.12, dim, glow, 0.6, pal, dist, false)
			draw_buildings(pen, city_near, 0.3, Color("070818"), neon, 0.95, pal, dist, false)
		2:
			draw_moon(pen, pal)
			draw_clouds(pen, pal, dist)
			draw_ridge(pen, ridges_moon, 0.35, glow, Color("070818"), 0.8, dist)
		3:
			draw_sky_grid(pen, pal, dist)
			draw_ringed_planet(pen, pal)
			draw_ridge(pen, ridges_near, 0.5, neon, Color("070818"), 0.75, dist)
		4:
			draw_planet(pen, pal)
			draw_trees(pen, trees_far, 0.12, glow, Color("070818"), 0.65, dist)
			draw_trees(pen, trees_near, 0.3, neon, Color("070818"), 0.95, dist)
		5:
			draw_aurora(pen, pal, bg_t)
			draw_ice_spikes(pen, ridges_ice, 0.25, glow, dim, 0.55, dist)
			draw_ice_spikes(pen, ridges_near, 0.5, neon, Color("061420"), 0.9, dist)
			draw_snow(pen, dist, bg_t)
		6:
			draw_volcano(pen, pal)
			draw_lava_ridge(pen, ridges_lava, 0.4, neon, Color("180704"), 0.9, dist)
			draw_ash(pen, dist, bg_t)
		7:
			draw_sun(pen, pal, 0.8, W * 0.3, GY - 360, 96)
			draw_dunes(pen, dune_far, 0.15, glow, dim, 0.5, dist)
			draw_pyramids(pen, pal, dist)
			draw_dunes(pen, ridges_dune, 0.4, neon, Color("241a05"), 0.9, dist)
		8:
			draw_cave(pen, pal, dist)
			draw_crystals(pen, crystals_far, 0.2, glow, 0.5, dist)
			draw_crystals(pen, crystals, 0.45, neon, 0.9, dist)
		9:
			draw_data_rain(pen, pal, dist, bg_t)
			draw_grid_floor(pen, pal)
			draw_core(pen, pal, bg_t)


# ---------------------------------------------------------------- helpers ---

func draw_aurora(pen: Pen, pal: Dictionary, bg_t: float) -> void:
	var neon: Color = pal["neon"]
	var glow: Color = pal["glow"]
	for a in aurora:
		var pts := PackedVector2Array()
		var x := -20.0
		while x <= W + 20.0:
			var y: float = a["y"] + sin(x * 0.012 + a["ph"] + bg_t * a["sp"]) * a["amp"]
			pts.append(Vector2(x, y))
			x += 20.0
		pen.alpha = 0.10 * a["w"]
		pen.polyline(pts, neon, 26.0)
		pen.alpha = 0.05 * a["w"]
		pen.polyline(pts, glow, 26.0)
	pen.alpha = 1.0


func draw_ice_spikes(pen: Pen, pts: PackedFloat32Array, par: float, line_col: Color, fill_col: Color, alpha: float, dist: float) -> void:
	var span := pts.size() * 46.0
	var off := fmod(dist * par * 0.1, span)
	pen.alpha = alpha
	for rep in range(-1, 2):
		var base := float(rep) * span - off
		var poly := PackedVector2Array([Vector2(base - 40, GY + 4)])
		for i in pts.size():
			var x := base + i * 46.0
			poly.append(Vector2(x, pts[i]))
			poly.append(Vector2(x + 23, GY + 4))
		poly.append(Vector2(base + pts.size() * 46.0 + 40, GY + 4))
		pen.polygon(poly, fill_col)
		pen.polyline(poly, line_col, 1.5)
	pen.alpha = 1.0


func draw_snow(pen: Pen, dist: float, bg_t: float) -> void:
	for st in stars:
		var y := fmod(st["y"] + bg_t * 26.0 * st["z"], GY - 40.0)
		var x := fposmod(st["x"] - dist * st["z"] * 0.05, W + 40.0) - 20.0
		pen.rect(Rect2(roundf(x), roundf(y), 2, 2), Color(1, 1, 1, 0.2 + st["z"]))


func draw_volcano(pen: Pen, pal: Dictionary) -> void:
	var neon: Color = pal["neon"]
	var cx := W * 0.66
	var cy := GY - 250.0
	pen.radial(Vector2(cx, cy), 260.0, Color(1.0, 0.352, 0.078, 0.28), Color(1, 0.35, 0.08, 0.0))
	var poly := PackedVector2Array([Vector2(cx - 210, GY), Vector2(cx - 28, cy)])
	poly.append_array(Pen.quad_pts(Vector2(cx - 28, cy), Vector2(cx, cy - 26), Vector2(cx + 28, cy), 10))
	poly.append(Vector2(cx + 210, GY))
	pen.polygon(poly, Color("120705"))
	pen.glow_line(Vector2(cx - 26, cy + 2), Vector2(cx + 26, cy + 2), neon, 3.0, 12.0)
	pen.alpha = 0.8
	for i in range(-2, 3):
		pen.line(Vector2(cx + i * 14.0, cy + 6), Vector2(cx + i * 42.0, GY), neon, 2.0)
	pen.alpha = 1.0


func draw_lava_ridge(pen: Pen, pts: PackedFloat32Array, par: float, line_col: Color, fill_col: Color, alpha: float, dist: float) -> void:
	var span := pts.size() * 40.0
	var off := fmod(dist * par * 0.1, span)
	pen.alpha = alpha
	for rep in range(-1, 2):
		var base := float(rep) * span - off
		var poly := PackedVector2Array([Vector2(base - 40, GY + 4)])
		for i in pts.size():
			poly.append(Vector2(base + i * 40.0, pts[i]))
		poly.append(Vector2(base + pts.size() * 40.0 + 40, GY + 4))
		pen.polygon(poly, fill_col)
		var top := PackedVector2Array()
		for i in pts.size():
			top.append(Vector2(base + i * 40.0, pts[i] + 4))
		pen.polyline(top, Color(line_col.r, line_col.g, line_col.b, 0.55), 2.0)
	pen.alpha = 1.0


func draw_ash(pen: Pen, dist: float, bg_t: float) -> void:
	for a in ash:
		var y := fposmod(a["y"] - bg_t * 40.0 * a["z"] - dist * a["z"] * 0.06, GY + 20.0)
		var x := fposmod(a["x"] - dist * a["z"] * 0.04, W + 20.0) - 10.0
		var col := Color("ff7a1a") if sin(bg_t * 2.0 + a["tw"]) > 0.0 else Color("8a6a5a")
		col.a = 0.25 + 0.35 * absf(sin(bg_t + a["tw"]))
		pen.rect(Rect2(roundf(x), roundf(y), a["r"], a["r"]), col)


func draw_dunes(pen: Pen, pts: PackedFloat32Array, par: float, line_col: Color, fill_col: Color, alpha: float, dist: float) -> void:
	var span := pts.size() * 34.0
	var off := fmod(dist * par * 0.1, span)
	pen.alpha = alpha
	for rep in range(-1, 2):
		var base := float(rep) * span - off
		var poly := PackedVector2Array([Vector2(base - 40, GY + 4)])
		var top := PackedVector2Array()
		for i in pts.size():
			var x := base + i * 34.0
			top.append_array(Pen.quad_pts(Vector2(x, pts[i]), Vector2(x + 17, pts[i] - 18), Vector2(x + 34, pts[i]), 6))
		poly.append_array(top)
		poly.append(Vector2(base + pts.size() * 34.0 + 40, GY + 4))
		pen.polygon(poly, fill_col)
		pen.polyline(top, Color(line_col.r, line_col.g, line_col.b, 0.7), 1.5)
	pen.alpha = 1.0


func draw_pyramids(pen: Pen, pal: Dictionary, dist: float) -> void:
	var off := fmod(dist * 0.15 * 0.1, 900.0)
	var neon: Color = pal["neon"]
	for rep in range(-1, 2):
		for p in [[120.0, 190.0, 150.0], [520.0, 130.0, 100.0], [780.0, 220.0, 180.0]]:
			var x: float = float(rep) * 900.0 - off + float(p[0])
			var pw: float = p[1]
			var ph: float = p[2]
			if x > W + 60.0 or x + pw < -60.0:
				continue
			var tri := PackedVector2Array([Vector2(x, GY), Vector2(x + pw * 0.5, GY - ph), Vector2(x + pw, GY)])
			pen.polygon(tri, Color("241a05"))
			pen.polyline(tri, Color(neon.r, neon.g, neon.b, 0.6), 1.5)


func draw_cave(pen: Pen, pal: Dictionary, dist: float) -> void:
	var glow: Color = pal["glow"]
	var span := 46.0 * 14.0
	var off := fmod(dist * 0.5 * 0.1, span)
	pen.alpha = 0.55
	for rep in range(-1, 2):
		for i in 14:
			var x := float(rep) * span - off + i * 46.0
			var h := 40.0 + float((i * 37) % 70)
			var tri := PackedVector2Array([Vector2(x, 0), Vector2(x + 22, 0), Vector2(x + 11, h)])
			pen.polygon(tri, Color("0b0409"))
			pen.polyline(tri, glow, 1.5)
	pen.alpha = 1.0


func draw_crystals(pen: Pen, g: Dictionary, par: float, col: Color, alpha: float, dist: float) -> void:
	var off := fmod(dist * par * 0.1, g["span"])
	for rep in range(-1, 2):
		var base: float = float(rep) * float(g["span"]) - off
		for c in g["list"]:
			var x: float = base + float(c["x"])
			if x > W + 40.0 or x + c["w"] < -40.0:
				continue
			pen.alpha = alpha
			var tri := PackedVector2Array([
				Vector2(x, GY + 2),
				Vector2(x + c["w"] * 0.5 + c["lean"] * 30.0, GY - c["h"]),
				Vector2(x + c["w"], GY + 2)])
			pen.polygon(tri, Color(10 / 255.0, 4 / 255.0, 12 / 255.0, 0.9))
			pen.polyline(tri, col, 1.5)
	pen.alpha = 1.0


func draw_data_rain(pen: Pen, pal: Dictionary, dist: float, bg_t: float) -> void:
	var neon: Color = pal["neon"]
	pen.alpha = 0.5
	for d in data_cols:
		var y := fmod(d["y"] + bg_t * d["sp"], GY + 200.0)
		var x := fposmod(d["x"] - dist * 0.02, W)
		pen.vgrad(Rect2(roundf(x), roundf(y - d["len"]), 3, d["len"]),
			Color(neon.r, neon.g, neon.b, 0.0), neon)
		pen.rect(Rect2(roundf(x), roundf(y), 3, 5), neon)
		for k in range(1, 6):
			var bit := "1" if (int(k + d["sp"]) % 2) == 1 else "0"
			pen.text(bit, Vector2(x + 8, y - k * 22), 10, Color(1, 1, 1, 0.55), "left", false, true)
	pen.alpha = 1.0


func draw_grid_floor(pen: Pen, pal: Dictionary) -> void:
	var hy := GY + 6.0
	pen.alpha = 0.5
	for i in range(-12, 13):
		pen.line(Vector2(W * 0.5 + i * 26.0, hy), Vector2(W * 0.5 + i * 220.0, GY + 300.0), pal["glow"], 1.5)
	pen.alpha = 1.0


func draw_core(pen: Pen, pal: Dictionary, bg_t: float) -> void:
	var cx := W * 0.72
	var cy := GY - 340.0
	var pulse := 1.0 + sin(bg_t * 2.4) * 0.08
	pen.radial_stops(Vector2(cx, cy), 130.0 * pulse,
		[Color(1, 1, 1, 1), pal["neon"], Color(1, 1, 1, 0)])
	for i in range(1, 4):
		pen.alpha = 0.5 / float(i)
		pen.ring(Vector2(cx, cy), 60.0 * i * pulse, pal["neon"], 2.0)
	pen.alpha = 1.0


func draw_sun(pen: Pen, pal: Dictionary, alpha: float, sx: float, sy: float, r: float) -> void:
	pen.alpha = alpha
	pen.radial(Vector2(sx, sy), r, pal["neon"], Color(pal["neon"].r, pal["neon"].g, pal["neon"].b, 0.0))
	pen.circle(Vector2(sx, sy), r * 0.42, pal["glow"])
	pen.alpha = 1.0


func draw_buildings(pen: Pen, b: Dictionary, par: float, fill_col: Color, line_col: Color, alpha: float, pal: Dictionary, dist: float, dim_win: bool) -> void:
	var off := fmod(dist * par * 0.1, b["span"])
	var neon: Color = pal["neon"]
	pen.alpha = alpha
	for rep in range(-1, 2):
		var base: float = float(rep) * float(b["span"]) - off
		for bl in b["list"]:
			var x: float = base + float(bl["x"])
			if x > W + 10.0 or x + bl["w"] < -10.0:
				continue
			pen.rect(Rect2(x, GY - bl["h"], bl["w"], bl["h"]), fill_col)
			pen.rect_outline(Rect2(x + 0.75, GY - bl["h"] + 0.75, bl["w"] - 1.5, bl["h"] - 1.5), line_col, 1.5)
			var r := Rng.new(int(bl["seed"]) if int(bl["seed"]) != 0 else 1)
			var chance := 0.16 if dim_win else 0.4
			var wy: float = GY - float(bl["h"]) + 9.0
			while wy < GY - 16.0:
				var wx: float = x + 7.0
				while wx < x + bl["w"] - 9.0:
					if r.next() < chance:
						pen.rect(Rect2(wx, wy, 5, 7), Color(neon.r, neon.g, neon.b, alpha * (0.3 + r.next() * 0.55)))
					wx += 13.0
				wy += 15.0
	pen.alpha = 1.0


func draw_trees(pen: Pen, t: Dictionary, par: float, line_col: Color, fill_col: Color, alpha: float, dist: float) -> void:
	var off := fmod(dist * par * 0.1, t["span"])
	pen.alpha = alpha
	for rep in range(-1, 2):
		var base: float = float(rep) * float(t["span"]) - off
		for tr in t["list"]:
			var x: float = base + float(tr["x"])
			if x > W + 20.0 or x + tr["w"] < -20.0:
				continue
			var tri := PackedVector2Array([
				Vector2(x, GY + 2),
				Vector2(x + tr["w"] * 0.5, GY - tr["h"]),
				Vector2(x + tr["w"], GY + 2)])
			pen.polygon(tri, fill_col)
			pen.glow_polyline(tri, line_col, 2.0, 8.0, true)
	pen.alpha = 1.0


func draw_moon(pen: Pen, pal: Dictionary) -> void:
	var mx := W * 0.68
	var my := GY - 380.0
	var r := 86.0
	pen.radial(Vector2(mx, my), r + 40.0, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0))
	pen.circle(Vector2(mx, my), r, pal["glow"])
	var cut := Color("05060f")
	cut.a = 0.92
	pen.circle(Vector2(mx - 34, my - 16), r * 0.88, cut)


func draw_clouds(pen: Pen, pal: Dictionary, dist: float) -> void:
	var glow: Color = pal["glow"]
	for c in clouds:
		var span := 1400.0
		var x := fposmod(c["x"] - dist * c["z"] * 0.1, span) - 200.0
		pen.alpha = 0.5
		pen.ellipse(Vector2(x, c["y"]), c["w"] * 0.5, 16.0, Color(1, 1, 1, 0.06))
		pen.ellipse_outline(Vector2(x, c["y"]), c["w"] * 0.5, 16.0, glow, 1.5)
		pen.ellipse(Vector2(x + c["w"] * 0.3, c["y"] - 10), c["w"] * 0.3, 13.0, Color(1, 1, 1, 0.06))
		pen.ellipse_outline(Vector2(x + c["w"] * 0.3, c["y"] - 10), c["w"] * 0.3, 13.0, glow, 1.5)
	pen.alpha = 1.0


func draw_sky_grid(pen: Pen, pal: Dictionary, dist: float) -> void:
	var glow: Color = pal["glow"]
	var hy := GY - 170.0
	pen.alpha = 0.3
	for i in range(-7, 8):
		pen.line(Vector2(W * 0.5, hy), Vector2(W * 0.5 + i * 120.0, GY), glow, 1.5)
	pen.alpha = 0.45
	var off := fmod(dist * 0.5, 26.0)
	for k in range(1, 13):
		var y := hy + k * k * 2.2 + off * (float(k) / 6.0)
		if y >= GY:
			break
		pen.line(Vector2(-20, y), Vector2(W + 20, y), glow, 1.5)
	pen.alpha = 1.0


func draw_ringed_planet(pen: Pen, pal: Dictionary) -> void:
	var cx := W * 0.3
	var cy := GY - 400.0
	var r := 74.0
	pen.alpha = 0.75
	pen.radial_stops(Vector2(cx - 20, cy - 20), r * 1.2, [pal["neon"], pal["glow"]])
	pen.circle(Vector2(cx, cy), r, Color(pal["neon"].r, pal["neon"].g, pal["neon"].b, 0.75))
	pen.alpha = 0.9
	pen.save()
	pen.translate(Vector2(cx, cy))
	pen.rotate(-0.42)
	pen.ellipse_outline(Vector2.ZERO, r + 46.0, 24.0, pal["neon"], 4.0)
	pen.restore()
	pen.alpha = 1.0


func draw_planet(pen: Pen, pal: Dictionary) -> void:
	var cx := W * 0.7
	var cy := GY - 430.0
	var r := 96.0
	pen.alpha = 0.8
	pen.radial(Vector2(cx - 30, cy - 30), r, pal["glow"], Color(pal["glow"].r, pal["glow"].g, pal["glow"].b, 0.0))
	pen.alpha = 0.6
	pen.ring(Vector2(cx, cy), r, pal["neon"], 2.0)
	var dark := Color("05060f")
	dark.a = 0.35
	pen.circle(Vector2(cx - 28, cy - 22), 22, dark)
	pen.circle(Vector2(cx + 34, cy + 18), 15, dark)
	pen.alpha = 1.0


func draw_ridge(pen: Pen, pts: PackedFloat32Array, par: float, line_col: Color, fill_col: Color, alpha: float, dist: float) -> void:
	var span := pts.size() * RIDGE_PITCH
	var off := fmod(dist * par * 0.1, span)
	var n := pts.size()
	pen.alpha = alpha
	var poly := PackedVector2Array([Vector2(-span - off - 40.0, GY + 4)])
	for rep in range(-1, 2):
		var base := float(rep) * span - off
		for i in n:
			poly.append(Vector2(base + i * RIDGE_PITCH, pts[i]))
	poly.append(Vector2(span - off + (n - 1) * RIDGE_PITCH + 40.0, GY + 4))
	pen.polygon(poly, fill_col)
	var edge := PackedVector2Array()
	for rep in range(-1, 2):
		var base := float(rep) * span - off
		for i in n:
			edge.append(Vector2(base + i * RIDGE_PITCH, pts[i]))
	pen.glow_polyline(edge, line_col, 2.0, 8.0)
	pen.alpha = 1.0
