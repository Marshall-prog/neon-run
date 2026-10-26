## The fifteen neon obstacles — a 1:1 port of the `OBS` table from the original
## Canvas2D game: dark bodies, a hot rim in the level colour, one live detail.
class_name Obs
extends RefCounted

const DARK := Color("050712")

const DEFS := {
	"n_block": {"w": 78.0, "h": 66.0, "hb": 0.86},
	"n_wall": {"w": 64.0, "h": 98.0, "hb": 0.88},
	"n_cone": {"w": 48.0, "h": 74.0, "hb": 0.5},
	"n_spikes": {"w": 120.0, "h": 40.0, "hb": 0.62, "wide": true},
	"n_crystal": {"w": 66.0, "h": 88.0, "hb": 0.66},
	"n_pylon": {"w": 56.0, "h": 92.0, "hb": 0.72},
	"n_saw": {"w": 76.0, "h": 76.0, "hb": 0.55, "move": 70.0, "spin": true},
	"n_ball": {"w": 54.0, "h": 54.0, "hb": 0.72, "hop": true},
	"n_drill": {"w": 52.0, "h": 74.0, "hb": 0.8, "drill": true, "noLoot": true},
	"n_bar": {"w": 126.0, "h": 36.0, "hb": 0.75, "fly": 64.0},
	"n_arc": {"w": 112.0, "h": 46.0, "hb": 0.6, "fly": 68.0, "bob": 8.0},
	"n_drone": {"w": 74.0, "h": 48.0, "hb": 0.7, "fly": 72.0, "bob": 12.0, "move": 60.0},
	"n_orb": {"w": 58.0, "h": 58.0, "hb": 0.65, "fly": 70.0, "bob": 14.0},
	"n_drop": {"w": 64.0, "h": 64.0, "hb": 0.8, "drop": true},
	"n_tramp": {"w": 66.0, "h": 28.0, "hb": 0.72, "bounce": true},
}

const LEVEL_ENEMIES := [
	[["n_block", 14], ["n_cone", 10], ["n_spikes", 8], ["n_bar", 8], ["n_drone", 7],
		["n_tramp", 6], ["n_crystal", 6]],
	[["n_wall", 12], ["n_block", 11], ["n_spikes", 8], ["n_drone", 8], ["n_orb", 7],
		["n_tramp", 6], ["n_crystal", 6]],
	[["n_crystal", 13], ["n_block", 11], ["n_arc", 8], ["n_ball", 8], ["n_spikes", 7],
		["n_tramp", 6], ["n_cone", 6]],
	[["n_block", 12], ["n_wall", 10], ["n_saw", 9], ["n_bar", 8], ["n_drone", 7],
		["n_ball", 7], ["n_tramp", 6]],
	[["n_crystal", 12], ["n_cone", 10], ["n_spikes", 8], ["n_orb", 8], ["n_ball", 8],
		["n_tramp", 7], ["n_arc", 6]],
	[["n_crystal", 12], ["n_spikes", 9], ["n_wall", 9], ["n_arc", 8], ["n_pylon", 7],
		["n_tramp", 6], ["n_drop", 6]],
	[["n_block", 12], ["n_pylon", 10], ["n_drill", 9], ["n_spikes", 8], ["n_ball", 8],
		["n_tramp", 6], ["n_drop", 6]],
	[["n_cone", 13], ["n_spikes", 9], ["n_crystal", 9], ["n_drone", 8], ["n_orb", 7],
		["n_tramp", 6], ["n_drop", 6]],
	[["n_crystal", 12], ["n_arc", 9], ["n_ball", 8], ["n_saw", 8], ["n_bar", 7],
		["n_tramp", 6], ["n_drop", 6]],
	[["n_saw", 11], ["n_block", 10], ["n_wall", 9], ["n_drill", 8], ["n_drone", 8],
		["n_bar", 7], ["n_tramp", 6], ["n_drop", 6]],
]


static func pick(level: int) -> String:
	var pool: Array = LEVEL_ENEMIES[clampi(level, 0, 9)]
	var total := 0.0
	for p in pool:
		total += float(p[1])
	var r := randf() * total
	for p in pool:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return pool[0][0]


static func hexagon(c: Vector2, rad: float, sq := 1.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + float(i) * PI / 3.0
		p.append(c + Vector2(cos(a) * rad, sin(a) * rad * sq))
	return p


static func dark(a := 0.92) -> Color:
	return Color(DARK.r, DARK.g, DARK.b, a)


# ------------------------------------------------------------------- drawing ---

static func draw(pen: Pen, name: String, ob: Dictionary, pal: Dictionary) -> void:
	var def: Dictionary = DEFS[name]
	var neon: Color = pal["neon"]
	var glow: Color = pal["glow"]
	var w: float = def["w"]
	var h: float = def["h"]
	var x: float = ob["x"]
	var gy: float = ob["y"]
	var t: float = ob.get("t", 0.0)
	match name:
		"n_block":
			_block(pen, x, gy, w, h, neon, glow, t)
		"n_wall":
			_wall(pen, x, gy, w, h, neon, glow)
		"n_cone":
			_cone(pen, x, gy, w, h, neon, glow)
		"n_spikes":
			_spikes(pen, x, gy, w, h, neon, glow, t)
		"n_crystal":
			_crystal(pen, x, gy, w, h, neon, glow, t)
		"n_pylon":
			_pylon(pen, x, gy, w, h, neon, glow, t)
		"n_saw":
			_saw(pen, x, gy, w, h, neon, glow, t, ob.get("spin", 0.0))
		"n_ball":
			_ball(pen, x, gy, w, h, neon, glow, t)
		"n_drill":
			_drill(pen, x, gy, w, h, neon, glow, t, ob.get("ext", 0.0))
		"n_bar":
			_bar(pen, x, gy, w, h, neon, glow, t)
		"n_arc":
			_arc(pen, x, gy, w, h, neon, glow, t)
		"n_drone":
			_drone(pen, x, gy, w, h, neon, glow, t)
		"n_orb":
			_orb(pen, x, gy, w, h, neon, glow, t)
		"n_drop":
			_drop(pen, x, gy, w, h, neon, glow, t)
		"n_tramp":
			_tramp(pen, x, gy, w, h, neon, glow)


static func _block(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cx := x + w * 0.5
	var cy := gy - h * 0.5
	var r := minf(w, h) * 0.5 - 3.0
	var outer := hexagon(Vector2(cx, cy), r, 0.94)
	pen.glow_polyline(outer, neon, 2.5, 14.0, true)
	pen.polygon(outer, dark(0.9))
	pen.polyline(outer, neon, 2.5, true)
	pen.polyline(hexagon(Vector2(cx, cy), r * 0.62), glow, 1.2, true)
	pen.polyline(PackedVector2Array([
		Vector2(cx - r * 0.5, cy - r * 0.16), Vector2(cx - r * 0.14, cy - r * 0.16),
		Vector2(cx, cy + r * 0.12), Vector2(cx + r * 0.14, cy - r * 0.16),
		Vector2(cx + r * 0.5, cy - r * 0.16)]), Color(glow.r, glow.g, glow.b, 0.6), 1.0)
	var p := 0.5 + 0.5 * sin(t * 3.4)
	pen.glow_circle(Vector2(cx, cy + r * 0.05), 2.5 + p * 2.5,
		Color(neon.r, neon.g, neon.b, 0.2 + p * 0.55), 12.0)


static func _wall(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color) -> void:
	var y := gy - h
	var r := Rect2(x + 5, y + 7, w - 10, h - 7)
	pen.glow_round_rect(r, neon, 12.0, 2.5, 5.0)
	pen.round_rect(r, dark(0.92))
	pen.round_rect_outline(r, neon, 2.5, 5.0)
	for i in range(1, 4):
		var sx := x + 5.0 + (w - 10.0) * float(i) / 4.0
		pen.line(Vector2(sx, y + 16), Vector2(sx, y + h - 16), Color(glow.r, glow.g, glow.b, 0.85), 1.2)
	pen.glow_round_rect(Rect2(x + 2, y, w - 4, 7), neon, 16.0, 1.0, 3.0)
	pen.round_rect(Rect2(x + 2, y, w - 4, 7), Color(neon.r, neon.g, neon.b, 0.9))
	pen.glow_line(Vector2(x + 8, gy), Vector2(x + 21, gy), neon, 2.0, 8.0)
	pen.glow_line(Vector2(x + w - 21, gy), Vector2(x + w - 8, gy), neon, 2.0, 8.0)


static func _cone(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color) -> void:
	var cx := x + w * 0.5
	var y := gy - h
	var tri := PackedVector2Array([Vector2(cx, y + 2), Vector2(x + w - 3, gy - 7), Vector2(x + 3, gy - 7)])
	pen.glow_polyline(tri, neon, 2.2, 12.0, true)
	pen.polygon(tri, dark(0.88))
	pen.polyline(tri, neon, 2.2, true)
	for i in range(-2, 5):
		var seg := Pen.clip_segment(Vector2(x + i * 12.0, gy), Vector2(x + i * 12.0 + 22.0, y), tri)
		if seg.size() == 2:
			pen.line(seg[0], seg[1], Color(glow.r, glow.g, glow.b, 0.8), 2.0)
	pen.glow_line(Vector2(x + 2, gy - 7), Vector2(x + w - 2, gy - 7), neon, 2.4, 10.0)
	pen.glow_line(Vector2(x + 2, gy), Vector2(x + w - 2, gy), neon, 2.4, 10.0)


static func _spikes(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var y := gy - h
	var n := 5
	var gap := w / float(n)
	for i in n:
		var sx := x + float(i) * gap
		var tri := PackedVector2Array([Vector2(sx + 3, gy - 6), Vector2(sx + gap * 0.5, y + 2), Vector2(sx + gap - 3, gy - 6)])
		pen.glow_polyline(tri, neon, 2.2, 12.0, true)
		pen.polygon(tri, dark(0.9))
		pen.polyline(tri, neon, 2.2, true)
	var p := 0.5 + 0.5 * sin(t * 4.0)
	for i in n:
		var sx := x + float(i) * gap + gap * 0.5
		pen.glow_circle(Vector2(sx, y + 3), 2.5 + p * 1.6, Color(neon.r, neon.g, neon.b, 0.35 + p * 0.5), 14.0)
	pen.glow_line(Vector2(x + 2, gy - 5), Vector2(x + w - 2, gy - 5), glow, 2.0, 8.0)


static func _shard(bx: float, bw: float, bh: float, skew: float, gy: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(bx + skew, gy), Vector2(bx + bw * 0.18, gy - bh),
		Vector2(bx + bw * 0.62, gy - bh * 0.72), Vector2(bx + bw, gy)])


static func _crystal(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var shards := [
		_shard(x + 2, 26, h * 0.62, 0, gy),
		_shard(x + 20, 30, h, 2, gy),
		_shard(x + 44, 20, h * 0.5, -1, gy),
	]
	for s in shards:
		pen.glow_polyline(s, neon, 2.2, 14.0, true)
		pen.polygon(s, dark(0.9))
		pen.polyline(s, neon, 2.2, true)
	pen.line(Vector2(x + 35, gy - h), Vector2(x + 35, gy), Color(glow.r, glow.g, glow.b, 0.8), 1.1)
	pen.line(Vector2(x + 20, gy - h * 0.62), Vector2(x + 35, gy - h * 0.72), Color(glow.r, glow.g, glow.b, 0.8), 1.1)
	var p := 0.5 + 0.5 * sin(t * 2.6)
	pen.glow_circle(Vector2(x + 35, gy - h * 0.8), 3.0 + p * 2.0, Color(neon.r, neon.g, neon.b, 0.2 + p * 0.45), 12.0)


static func _pylon(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var y := gy - h
	var body := PackedVector2Array([
		Vector2(x + 12, y + 12), Vector2(x + w - 12, y + 12),
		Vector2(x + w - 6, gy), Vector2(x + 6, gy)])
	pen.glow_polyline(body, neon, 2.4, 12.0, true)
	pen.polygon(body, dark(0.92))
	pen.polyline(body, neon, 2.4, true)
	for i in range(-2, 7):
		var seg := Pen.clip_segment(Vector2(x + i * 11.0, gy), Vector2(x + i * 11.0 + 20.0, y), body)
		if seg.size() == 2:
			pen.line(seg[0], seg[1], Color(glow.r, glow.g, glow.b, 0.75), 3.0)
	var p := 0.5 + 0.5 * sin(t * 3.2)
	pen.glow_circle(Vector2(x + w * 0.5, y + 7), 3.5 + p * 1.5, Color(neon.r, neon.g, neon.b, 0.35 + p * 0.6), 14.0)


static func _saw(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float, spin: float) -> void:
	var cx := x + w * 0.5
	var cy := gy - h * 0.5
	var r := minf(w, h) * 0.5 - 4.0
	pen.save()
	pen.translate(Vector2(cx, cy))
	pen.rotate(spin)
	var teeth := PackedVector2Array()
	for i in 10:
		var a0 := float(i) * PI / 5.0
		var a1 := a0 + PI / 10.0
		var a2 := a0 + PI / 5.0
		teeth.append(Vector2(cos(a0) * r * 0.82, sin(a0) * r * 0.82))
		teeth.append(Vector2(cos(a1) * r, sin(a1) * r))
		teeth.append(Vector2(cos(a2) * r * 0.82, sin(a2) * r * 0.82))
	pen.glow_polyline(teeth, neon, 2.2, 14.0, true)
	pen.polygon(teeth, dark(0.85))
	pen.polyline(teeth, neon, 2.2, true)
	pen.ring(Vector2.ZERO, r * 0.62, glow, 1.4)
	pen.ring(Vector2.ZERO, r * 0.26, glow, 1.4)
	pen.circle(Vector2.ZERO, 3.0, Color(neon.r, neon.g, neon.b, 0.55))
	pen.restore()


static func _ball(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cx := x + w * 0.5
	var cy := gy - h * 0.5
	var r := minf(w, h) * 0.5 - 3.0
	pen.line(Vector2(cx, cy + r), Vector2(cx, gy - 1), Color(glow.r, glow.g, glow.b, 0.5), 2.0)
	var p := 0.5 + 0.5 * sin(t * 6.0)
	var rr := r * (0.94 + p * 0.06)
	pen.glow_ring(Vector2(cx, cy), rr, neon, 2.4, 16.0)
	pen.circle(Vector2(cx, cy), rr, dark(0.7))
	pen.ring(Vector2(cx, cy), rr, neon, 2.4)
	pen.ring(Vector2(cx, cy), r * 0.5, Color(glow.r, glow.g, glow.b, 0.9), 1.3)
	pen.circle(Vector2(cx - r * 0.28, cy - r * 0.3), 2.6, Color(1, 1, 1, 0.5 + p * 0.4))


static func _drill(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float, ext: float) -> void:
	var cx := x + w * 0.5
	var base := Rect2(x + 1, gy - 9, w - 2, 9)
	pen.glow_round_rect(base, neon, 10.0, 2.0, 2.0)
	pen.round_rect(base, dark(0.9))
	pen.round_rect_outline(base, neon, 2.0, 2.0)
	if ext > 5.0:
		var shaft := Rect2(cx - 8, gy - ext, 16, ext)
		pen.glow_round_rect(shaft, neon, 10.0, 1.0, 3.0)
		pen.round_rect(shaft, dark(0.85))
		pen.round_rect_outline(shaft, neon, 1.0, 3.0)
		pen.save()
		pen.translate(Vector2(cx, gy - ext))
		pen.rotate(t * 7.0)
		pen.glow_polyline(PackedVector2Array([
			Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)]), neon, 2.0, 14.0, true)
		pen.restore()
		pen.glow_circle(Vector2(cx, gy - ext), 3.5, Color(neon.r, neon.g, neon.b, 0.55), 16.0)


static func _bar(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cy := gy - h * 0.5
	for r in [Rect2(x, cy - h * 0.5, 12, h), Rect2(x + w - 12, cy - h * 0.5, 12, h)]:
		pen.glow_round_rect(r, neon, 12.0, 2.2, 3.0)
		pen.round_rect(r, dark(0.9))
		pen.round_rect_outline(r, neon, 2.2, 3.0)
	pen.glow_line(Vector2(x + 10, cy), Vector2(x + w - 10, cy), neon, 4.0, 16.0)
	pen.line(Vector2(x + 10, cy), Vector2(x + w - 10, cy), Color(1, 1, 1, 0.7), 1.2)
	for i in 6:
		var f := fmod(t * 0.55 + float(i) / 6.0, 1.0)
		pen.circle(Vector2(x + 12 + f * (w - 24), cy), 2.2, Color(1, 1, 1, 0.85))


static func _arc(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cy := gy - h * 0.5
	for cx in [x + 8, x + w - 8]:
		pen.glow_circle(Vector2(cx, cy), 8.0, neon, 12.0)
		pen.circle(Vector2(cx, cy), 8.0, dark(0.9))
		pen.ring(Vector2(cx, cy), 8.0, neon, 2.2)
	var flick := 0.55 + 0.45 * sin(t * 21.0)
	var pts := PackedVector2Array()
	var seg := 7
	pts.append(Vector2(x + 8, cy))
	for i in range(1, seg + 1):
		var f := float(i) / float(seg)
		var jx := 0.0 if i == seg else sin(t * 17.0 + i * 2.7) * 7.0
		pts.append(Vector2(x + 8 + f * (w - 16) + jx, cy + jx * 0.4))
	pen.glow_polyline(pts, Color(neon.r, neon.g, neon.b, flick), 2.6, 14.0)


static func _drone(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cy := gy - h * 0.5
	for rx in [x + 16, x + w - 16]:
		pen.line(Vector2(rx - 9, cy - h * 0.5 + 2), Vector2(rx + 9, cy - h * 0.5 + 2), Color(glow.r, glow.g, glow.b, 0.85), 2.0)
	var body := PackedVector2Array([
		Vector2(x + 14, cy - 6), Vector2(x + w - 14, cy - 6),
		Vector2(x + w - 6, cy + 8), Vector2(x + 6, cy + 8)])
	pen.glow_polyline(body, neon, 2.4, 13.0, true)
	pen.polygon(body, dark(0.9))
	pen.polyline(body, neon, 2.4, true)
	var p := 0.5 + 0.5 * sin(t * 5.0)
	pen.glow_circle(Vector2(x + w - 18, cy), 3.4, Color("ff4d6d", 0.45 + p * 0.55), 14.0)
	pen.line(Vector2(x + 12, cy + 9), Vector2(x + 8, cy + 15), Color(glow.r, glow.g, glow.b, 0.7), 1.6)
	pen.line(Vector2(x + w - 12, cy + 9), Vector2(x + w - 8, cy + 15), Color(glow.r, glow.g, glow.b, 0.7), 1.6)


static func _orb(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cx := x + w * 0.5
	var cy := gy - h * 0.5
	var r := minf(w, h) * 0.5 - 3.0
	var p := 0.5 + 0.5 * sin(t * 3.6)
	for i in range(3, 0, -1):
		var f := float(i) / 3.0
		var col := neon if i == 1 else glow
		var a := (0.95 if i == 1 else 0.4) * (0.7 + p * 0.3)
		pen.ring(Vector2(cx, cy), r * (0.45 + f * 0.55) * (0.9 + p * 0.12),
			Color(col.r, col.g, col.b, a), 2.4 if i == 1 else 1.2)
	pen.glow_circle(Vector2(cx, cy), r * 0.34, Color(neon.r, neon.g, neon.b, 0.55 + p * 0.4), 16.0)


static func _drop(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color, t: float) -> void:
	var cx := x + w * 0.5
	var y := gy - h
	pen.line(Vector2(cx, y), Vector2(cx, 0), Color(glow.r, glow.g, glow.b, 0.7), 2.0)
	var r := Rect2(x + 4, y, w - 8, h)
	pen.glow_round_rect(r, neon, 14.0, 2.5, 6.0)
	pen.round_rect(r, dark(0.92))
	pen.round_rect_outline(r, neon, 2.5, 6.0)
	pen.line(Vector2(x + 14, y + 12), Vector2(x + w - 14, y + h - 12), Color(glow.r, glow.g, glow.b, 0.9), 1.5)
	pen.line(Vector2(x + w - 14, y + 12), Vector2(x + 14, y + h - 12), Color(glow.r, glow.g, glow.b, 0.9), 1.5)
	var p := 0.5 + 0.5 * sin(t * 6.0)
	pen.glow_circle(Vector2(cx, y + h * 0.5), 4.0 + p * 2.0, Color("ff4d6d", 0.35 + p * 0.6), 14.0)


static func _tramp(pen: Pen, x: float, gy: float, w: float, h: float, neon: Color, glow: Color) -> void:
	var y := gy - h
	var r := Rect2(x + 2, y + 6, w - 4, h - 6)
	pen.glow_round_rect(r, neon, 12.0, 2.2, 5.0)
	pen.round_rect(r, dark(0.9))
	pen.round_rect_outline(r, neon, 2.2, 5.0)
	for i in 3:
		var cy2 := y + h - 9 - i * 6.0
		pen.polyline(PackedVector2Array([
			Vector2(x + 11, cy2), Vector2(x + w * 0.5, cy2 - 5), Vector2(x + w - 11, cy2)]),
			Color(glow.r, glow.g, glow.b, 0.9 - i * 0.25), 1.6)
	pen.glow_line(Vector2(x + 4, gy), Vector2(x + w - 4, gy), neon, 2.2, 8.0)
