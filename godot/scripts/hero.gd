## Neon hero — port of game/hero.js: dark capsules with a hot rim light, IK
## legs and bent arms, scarf trailing behind.
class_name HeroModel
extends RefCounted

const BODY := "#070b14"
const RIM := "#f2feff"
const RW := 2.2

const STYLES := {
	"hoodie": {"head": "hood", "torso": "hoodie", "boot": "shoe",
		"accent": "#5ef2ff", "scarf": 1, "scarfCol": "#ff2d95",
		"glowCol": "#5ef2ff", "core": "none"},
	"droid": {"head": "visor", "torso": "armor", "boot": "plate",
		"accent": "#ffd24a", "scarf": 0, "glowCol": "#ffd24a", "core": "chest"},
	"ninja": {"head": "wrap", "torso": "kimono", "boot": "tabi",
		"accent": "#ff4d6d", "scarf": 1, "scarfCol": "#ff4d6d",
		"glowCol": "#ff4d6d", "core": "none", "blade": 1},
	"racer": {"head": "helmet", "torso": "jacket", "boot": "boot",
		"accent": "#b06bff", "scarf": 0, "glowCol": "#b06bff", "core": "none"},
}

var pen: Pen
var A := Color.WHITE
var glow_col := Color.WHITE
var scarf_col := Color.WHITE


func _init(p: Pen) -> void:
	pen = p


func _bone(x1: float, y1: float, x2: float, y2: float, w: float, fill := Color(BODY)) -> void:
	pen.line(Vector2(x1, y1), Vector2(x2, y2), pen_color(RIM), w + RW * 2.0)
	pen.line(Vector2(x1, y1), Vector2(x2, y2), fill, w)


func pen_color(hex: String) -> Color:
	return Color(hex)


func _shape(pts: PackedVector2Array, fill := Color(BODY), glow := 0.0) -> void:
	if glow > 0.0:
		pen.glow_polyline(pts, glow_col, RW * 2.0, glow, true)
	pen.polyline(pts, pen_color(RIM), RW * 2.0, true)
	pen.polygon(pts, fill)


func _dot(x: float, y: float, r: float, col: Color) -> void:
	pen.circle(Vector2(x, y), r, col)


## thigh + shin, knee bends forward (canvas coordinates, y down)
func _leg(hx: float, hy: float, ang: float, length: float, w: float) -> Dictionary:
	var fx := hx + sin(ang) * length
	var fy := hy + cos(ang) * length
	var l1 := length * 0.52
	var l2 := length * 0.5
	var dx := fx - hx
	var dy := fy - hy
	var d := minf(sqrt(dx * dx + dy * dy), l1 + l2 - 0.01)
	if d < 0.01:
		d = 0.01
	var a := (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var ux := dx / d
	var uy := dy / d
	var kx := hx + ux * a + uy * h
	var ky := hy + uy * a - ux * h
	_bone(hx, hy, kx, ky, w)
	_bone(kx, ky, fx, fy, w * 0.92)
	return {"fx": fx, "fy": fy, "kx": kx, "ky": ky, "ang": ang}


func _foot(f: Dictionary, w: float, kind: String) -> void:
	pen.save()
	pen.translate(Vector2(f["fx"], f["fy"]))
	pen.rotate(clampf(-float(f["ang"]) * 0.6, -0.5, 0.5))
	pen.circle(Vector2.ZERO, w * 0.5, Color(A.r, A.g, A.b, 0.10))
	match kind:
		"plate":
			pen.rect(Rect2(-w * 0.35, -2, w * 0.9, 4), A)
		"tabi":
			pen.ellipse(Vector2(1, 0), w * 0.45, 3.4, A)
		"boot":
			pen.rect(Rect2(-w * 0.4, -3, w * 1.0, 6), A)
		_:
			pen.polygon(PackedVector2Array([
				Vector2(-w * 0.45, -2.5), Vector2(w * 0.5, -1),
				Vector2(w * 0.55, 2.5), Vector2(-w * 0.45, 2.5)]), A)
	pen.restore()


func _arm(sx: float, sy: float, ang: float, length: float, w: float, bend: float) -> Dictionary:
	var ex := sx + sin(ang) * length * 0.55
	var ey := sy + cos(ang) * length * 0.55
	var a2 := ang + bend
	var hx := ex + sin(a2) * length * 0.45
	var hy := ey + cos(a2) * length * 0.45
	_bone(sx, sy, ex, ey, w)
	_bone(ex, ey, hx, hy, w * 0.88)
	return {"hx": hx, "hy": hy}


func _hand(x: float, y: float, r: float) -> void:
	pen.circle(Vector2(x, y), r * 1.5, Color(A.r, A.g, A.b, 0.16))
	_dot(x, y, r, A)


func _torso(w: float, h: float, hip_y: float, kind: String) -> Dictionary:
	var hw := w * 0.5
	var sw := w * 0.62
	var top := hip_y - h
	var p := PackedVector2Array()
	p.append(Vector2(-hw * 0.92, hip_y + 2))
	p.append_array(Pen.quad_pts(Vector2(-hw * 0.92, hip_y + 2), Vector2(-hw * 1.06, hip_y - h * 0.35), Vector2(-sw, top + h * 0.16), 6))
	p.append_array(Pen.quad_pts(Vector2(-sw, top + h * 0.16), Vector2(-sw * 0.72, top - h * 0.06), Vector2(0, top - h * 0.04), 5))
	p.append_array(Pen.quad_pts(Vector2(0, top - h * 0.04), Vector2(sw * 0.72, top - h * 0.06), Vector2(sw, top + h * 0.16), 5))
	p.append_array(Pen.quad_pts(Vector2(sw, top + h * 0.16), Vector2(hw * 1.06, hip_y - h * 0.35), Vector2(hw * 0.92, hip_y + 2), 6))
	_shape(p, Color(BODY), 10.0)

	match kind:
		"hoodie":
			var c := PackedVector2Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				c.append(Vector2(cos(a) * sw * 0.78, top + h * 0.06 + sin(a) * h * 0.16))
			_shape(c, Color("#0d1424"))
		"armor":
			for i in range(1, 3):
				var yy := hip_y - h * (0.28 + i * 0.26)
				pen.glow_line(Vector2(-hw * 0.75, yy), Vector2(hw * 0.75, yy), A, 1.6, 12.0)
		"kimono":
			pen.glow_line(Vector2(-hw * 0.6, top + h * 0.3), Vector2(hw * 0.5, hip_y - h * 0.05), A, 2.0, 10.0)
			pen.glow_line(Vector2(-hw, hip_y - h * 0.28), Vector2(hw, hip_y - h * 0.28), A, 2.0, 10.0)
		"jacket":
			pen.glow_line(Vector2(0, top), Vector2(0, hip_y - h * 0.12), A, 2.0, 10.0)
	return {"top": top, "sw": sw, "hw": hw}


func _head(kind: String, cx: float, cy: float, r: float, t: float) -> void:
	pen.save()
	pen.translate(Vector2(cx, cy))
	match kind:
		"hood":
			var p := PackedVector2Array()
			p.append(Vector2(-r * 0.95, r * 0.5))
			p.append_array(Pen.quad_pts(Vector2(-r * 0.95, r * 0.5), Vector2(-r * 1.15, -r * 1.15), Vector2(r * 0.1, -r * 1.1), 6))
			p.append_array(Pen.quad_pts(Vector2(r * 0.1, -r * 1.1), Vector2(r * 1.15, -r * 1.0), Vector2(r * 0.95, r * 0.35), 6))
			p.append_array(Pen.quad_pts(Vector2(r * 0.95, r * 0.35), Vector2(r * 0.55, r * 0.72), Vector2(0, r * 0.72), 4))
			p.append_array(Pen.quad_pts(Vector2(0, r * 0.72), Vector2(-r * 0.6, r * 0.7), Vector2(-r * 0.95, r * 0.5), 4))
			_shape(p, Color(BODY), 14.0)
			pen.polygon(PackedVector2Array([
				Vector2(r * 0.05, -r * 0.3), Vector2(r * 1.02, -r * 0.16),
				Vector2(r * 0.98, r * 0.2), Vector2(r * 0.05, r * 0.12)]), A)
		"visor":
			var p := PackedVector2Array()
			p.append(Vector2(-r * 0.9, -r * 0.75))
			p.append_array(Pen.quad_pts(Vector2(-r * 0.9, -r * 0.75), Vector2(0, -r * 1.05), Vector2(r * 0.9, -r * 0.75), 5))
			p.append_array(Pen.quad_pts(Vector2(r * 0.9, -r * 0.75), Vector2(r * 1.05, 0), Vector2(r * 0.78, r * 0.62), 5))
			p.append_array(Pen.quad_pts(Vector2(r * 0.78, r * 0.62), Vector2(0, r * 0.95), Vector2(-r * 0.78, r * 0.62), 5))
			p.append_array(Pen.quad_pts(Vector2(-r * 0.78, r * 0.62), Vector2(-r * 1.05, 0), Vector2(-r * 0.9, -r * 0.75), 5))
			_shape(p, Color(BODY), 16.0)
			pen.rect(Rect2(-r * 0.72, -r * 0.28, r * 1.66, r * 0.42), A)
			pen.line(Vector2(-r * 0.35, -r * 0.95), Vector2(-r * 0.7, -r * 1.55 + sin(t * 6.0) * 1.4), pen_color(RIM), 1.8)
		"wrap":
			pen.polygon(_circle_pts(Vector2.ZERO, r), Color(BODY))
			pen.polyline(_circle_pts(Vector2.ZERO, r), pen_color(RIM), RW * 2.0, true)
			pen.rect(Rect2(-r * 0.1, -r * 0.22, r * 1.05, r * 0.3), A)
			var q := Pen.quad_pts(Vector2(-r * 0.8, -r * 0.62), Vector2(0, -r * 1.15), Vector2(r * 0.72, -r * 0.5), 8)
			pen.line(q[0], q[q.size() - 1], pen_color(RIM), 1.2)
			pen.polyline(q, pen_color(RIM), 1.2)
		_:
			var p := PackedVector2Array()
			p.append(Vector2(-r * 0.92, r * 0.62))
			p.append_array(Pen.quad_pts(Vector2(-r * 0.92, r * 0.62), Vector2(-r * 1.18, -r * 0.55), Vector2(-r * 0.2, -r * 1.05), 5))
			p.append_array(Pen.quad_pts(Vector2(-r * 0.2, -r * 1.05), Vector2(r * 0.95, -r * 1.15), Vector2(r * 1.0, -r * 0.1), 5))
			p.append_array(Pen.quad_pts(Vector2(r * 1.0, -r * 0.1), Vector2(r * 1.02, r * 0.72), Vector2(0, r * 0.78), 5))
			_shape(p, Color(BODY), 16.0)
			pen.polygon(PackedVector2Array([
				Vector2(r * 0.02, -r * 0.42), Vector2(r * 1.0, -r * 0.3),
				Vector2(r * 0.94, r * 0.3), Vector2(r * 0.02, r * 0.16)]), A)
			pen.polyline(Pen.quad_pts(Vector2(-r * 0.2, -r * 1.02), Vector2(r * 0.1, -r * 1.32), Vector2(r * 0.55, -r * 1.05), 6), pen_color(RIM), 1.6)
	pen.restore()


func _circle_pts(c: Vector2, r: float, seg := 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _scarf(nx: float, ny: float, t: float, speed: float, col: Color) -> void:
	var k := minf(1.4, 0.6 + speed * 0.5)
	var wob := sin(t * 9.5) * 2.4 * k
	var wob2 := sin(t * 7.2 + 1.3) * 3.2 * k
	var pts := Pen.cubic_pts(
		Vector2(nx - 2, ny),
		Vector2(nx - 12, ny - 3 + wob),
		Vector2(nx - 22, ny + 4 + wob2),
		Vector2(nx - 33 - 3 * k, ny + 1 + wob2 * 0.6), 12)
	pen.glow_polyline(pts, col, 5.2, 14.0)
	pen.polyline(pts, Color(1, 1, 1, 0.75), 2.2)


## P: hipY, legH, legW, bodyW, bodyH, armH, armW, headR,
##    legA, legB, legLiftA, legLiftB, armA, armB, t, speed, accent
func draw(style_name: String, P: Dictionary) -> void:
	var st: Dictionary = STYLES.get(style_name, STYLES["hoodie"])
	A = P.get("accent", Color(st["accent"]))
	glow_col = P.get("glowCol", Color(st["glowCol"]))
	scarf_col = P.get("scarfCol", Color("#f2feff"))

	var hip_y: float = P["hipY"]
	var body_w: float = P.get("bodyW", 27.0)
	var body_h: float = P.get("bodyH", 25.0)
	var arm_w: float = P.get("armW", 7.5)
	var leg_w: float = P.get("legW", 9.5)
	var leg_h: float = P.get("legH", 32.0)
	var arm_h: float = P.get("armH", 26.0)
	var head_r: float = P.get("headR", 10.5)
	var t: float = P.get("t", 0.0)
	var spd: float = P.get("speed", 1.0)

	var sho_y := hip_y - body_h * 0.94
	var neck_y := sho_y - body_h * 0.06
	var head_cy := neck_y - head_r * 1.02

	pen.save()
	# far arm / far leg behind the torso
	pen.alpha = 0.86
	var back_arm := _arm(-1.5, sho_y + 2, P.get("armB", 0.0), arm_h, arm_w * 0.9, 0.75)
	_hand(back_arm["hx"], back_arm["hy"], arm_w * 0.44)
	var bk: float = P.get("legLiftB", 0.0)
	var fk: float = P.get("legLiftA", 0.0)
	var back_leg := _leg(-1.5, hip_y, P.get("legB", 0.0), leg_h * (1.0 - bk * 0.4), leg_w * 0.95)
	_foot(back_leg, leg_w + 4.0, st["boot"])
	pen.alpha = 1.0

	_torso(body_w, body_h, hip_y, st["torso"])
	var front_leg := _leg(1.8, hip_y, P.get("legA", 0.0), leg_h * (1.0 - fk * 0.4), leg_w)
	_foot(front_leg, leg_w + 4.5, st["boot"])
	var front_arm := _arm(1.8, sho_y + 2, P.get("armA", 0.0), arm_h, arm_w, 0.8)
	_hand(front_arm["hx"], front_arm["hy"], arm_w * 0.46)
	if st.get("core", "none") == "chest":
		pen.glow_circle(Vector2(0, sho_y + body_h * 0.32), body_w * 0.14, A, 18.0)
	if int(st.get("scarf", 0)) == 1:
		_scarf(-2, sho_y - body_h * 0.02, t, spd, scarf_col)
	_head(st["head"], 0, head_cy, head_r, t)
	if int(st.get("blade", 0)) == 1:
		pen.glow_line(Vector2(-body_w * 0.5, sho_y + 3), Vector2(-body_w * 0.95, hip_y - 4), A, 2.4, 12.0)
	pen.restore()
