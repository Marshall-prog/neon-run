## Low-level neon drawing helper: a tiny canvas-like API on top of CanvasItem.
##
## The original game draws everything with the Canvas2D API (translate/rotate/
## scale + stroke/fill + shadowBlur). Godot has no per-primitive transform stack
## and no shadow blur, so this class keeps its own Transform2D stack and bakes a
## cheap "bloom" out of a few wider, dimmer passes.
class_name Pen
extends RefCounted

const GLOW_STEPS := 3

var ci: CanvasItem
var xf: Transform2D = Transform2D.IDENTITY
var _stack: Array[Transform2D] = []
var font: Font
var mono: Font
var alpha := 1.0


func _init(canvas: CanvasItem) -> void:
	ci = canvas


# ---------------------------------------------------------------- transform ---

func save() -> void:
	_stack.push_back(xf)


func restore() -> void:
	if not _stack.is_empty():
		xf = _stack.pop_back()


func translate(p: Vector2) -> void:
	xf = xf * Transform2D(0.0, p)


func rotate(a: float) -> void:
	xf = xf * Transform2D(a, Vector2.ZERO)


func scale(s: Vector2) -> void:
	xf = xf * Transform2D(Vector2(s.x, 0.0), Vector2(0.0, s.y), Vector2.ZERO)


func set_origin(p: Vector2) -> void:
	xf.origin = p


func to_screen(p: Vector2) -> Vector2:
	return xf * p


func _w(width: float) -> float:
	var sx := xf.x.length()
	var sy := xf.y.length()
	return width * (sx + sy) * 0.5


func _c(col: Color, a: float = 1.0) -> Color:
	var out := col
	out.a *= a * alpha
	return out


func _pts(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		out[i] = xf * points[i]
	return out


# ------------------------------------------------------------------- shapes ---

func line(a: Vector2, b: Vector2, col: Color, width: float = 1.0) -> void:
	ci.draw_line(xf * a, xf * b, _c(col), maxf(1.0, _w(width)), true)


## Polyline through points; `closed` also joins last -> first.
func polyline(points: PackedVector2Array, col: Color, width: float = 1.0, closed := false) -> void:
	if points.size() < 2:
		return
	var p := _pts(points)
	if closed:
		p.append(p[0])
	var w := maxf(1.0, _w(width))
	ci.draw_polyline(p, _c(col), w, true)
	if w >= 4.0:
		# round caps/joins, canvas style
		for q in p:
			ci.draw_circle(q, w * 0.5, _c(col))


func polygon(points: PackedVector2Array, col: Color) -> void:
	var q := _clean(points)
	if q.size() < 3:
		return
	ci.draw_colored_polygon(_pts(q), _c(col))


func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.01:
			out.append(p)
	if out.size() > 2 and out[0].distance_to(out[out.size() - 1]) <= 0.01:
		out.remove_at(out.size() - 1)
	if out.size() < 3:
		return out
	# drop collinear runs that break triangulation
	var keep := PackedVector2Array()
	for i in out.size():
		var a := out[(i - 1 + out.size()) % out.size()]
		var b := out[i]
		var c := out[(i + 1) % out.size()]
		if absf((b - a).cross(c - b)) > 0.01:
			keep.append(b)
	if keep.size() < 3:
		return PackedVector2Array()
	return keep


func polygon_outline(points: PackedVector2Array, col: Color, width: float = 1.0) -> void:
	polyline(points, col, width, true)


func rect(r: Rect2, col: Color) -> void:
	var a := xf * r.position
	var b := xf * r.end
	ci.draw_rect(Rect2(a, b - a).abs(), _c(col), true)


func rect_outline(r: Rect2, col: Color, width: float = 1.0) -> void:
	var p := PackedVector2Array([
		xf * r.position,
		xf * Vector2(r.end.x, r.position.y),
		xf * r.end,
		xf * Vector2(r.position.x, r.end.y),
	])
	polyline(p, col, width, true)


func circle(center: Vector2, radius: float, col: Color) -> void:
	var s := (xf.x.length() + xf.y.length()) * 0.5
	ci.draw_circle(xf * center, radius * s, _c(col))


func ring(center: Vector2, radius: float, col: Color, width: float = 1.0, segments := 40) -> void:
	var p := PackedVector2Array()
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		p.append(center + Vector2(cos(a), sin(a)) * radius)
	polyline(p, col, width)


## Arc between two angles (radians), drawn as a polyline.
func arc(center: Vector2, radius: float, a0: float, a1: float, col: Color, width: float = 1.0, segments := 32) -> void:
	var p := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / float(segments))
		p.append(center + Vector2(cos(a), sin(a)) * radius)
	polyline(p, col, width)


func ellipse(center: Vector2, rx: float, ry: float, col: Color, segments := 40) -> void:
	var p := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(_pts(p), _c(col))


## Filled shape with a rounded (round-join) outline, canvas `shape()`-style.
func shape_outline(points: PackedVector2Array, fill: Color, rim: Color, rim_w: float = 2.0) -> void:
	if points.size() < 3:
		return
	polygon(points, fill)
	polyline(points, rim, rim_w, true)


## Quadratic bezier, returned as points (canvas quadraticCurveTo).
static func quad_pts(a: Vector2, c: Vector2, b: Vector2, steps := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var u := 1.0 - t
		out.append(u * u * a + 2.0 * u * t * c + t * t * b)
	return out


static func cubic_pts(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, steps := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var u := 1.0 - t
		out.append(u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b)
	return out


## Clips a segment against a convex polygon (canvas `clip()` stand-in for the
## hazard stripes). Returns [] or [a, b].
static func clip_segment(p0: Vector2, p1: Vector2, poly: PackedVector2Array) -> Array:
	var n := poly.size()
	if n < 3:
		return []
	var area := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var sgn := 1.0 if area > 0.0 else -1.0
	var pts: Array[Vector2] = [p0, p1]
	for i in n:
		if pts.size() < 2:
			return []
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var dir := (b - a)
		var inside := func(p: Vector2) -> bool:
			return sgn * dir.cross(p - a) >= -0.0001
		var ia: bool = inside.call(pts[0])
		var ib: bool = inside.call(pts[1])
		if ia and ib:
			continue
		if not ia and not ib:
			return []
		var p_in := pts[0] if ia else pts[1]
		var p_out := pts[1] if ia else pts[0]
		var d := p_out - p_in
		var denom := dir.cross(d)
		if absf(denom) < 0.000001:
			return []
		var t := dir.cross(a - p_in) / denom
		var hit := p_in + d * t
		pts = [hit, p_in] if ia else [p_in, hit]
	return [pts[0], pts[1]]


## Rounded rectangle path (canvas roundRect) as points.
static func round_rect_pts(r: Rect2, rad: float, steps := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rr := minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5, 0.0],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0, PI * 0.5],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5, PI],
		[Vector2(r.position.x + rr, r.position.y + rr), PI, PI * 1.5],
	]
	for c in cs:
		var center: Vector2 = c[0]
		for i in steps + 1:
			var a: float = lerpf(c[1], c[2], float(i) / float(steps))
			out.append(center + Vector2(cos(a), sin(a)) * rr)
	return out


func round_rect(r: Rect2, col: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	polygon(round_rect_pts(r, minf(6.0, minf(r.size.x, r.size.y) * 0.5)), col)


func round_rect_outline(r: Rect2, col: Color, width: float = 1.0, rad := 6.0) -> void:
	polygon_outline(round_rect_pts(r, rad), col, width)


# -------------------------------------------------------------------- glow ---
# Canvas `shadowBlur` stand-in: a few wider, dimmer passes under the real stroke.

func glow_line(a: Vector2, b: Vector2, col: Color, width: float = 1.0, blur: float = 12.0) -> void:
	for i in range(GLOW_STEPS, 0, -1):
		var f := float(i) / float(GLOW_STEPS)
		var halo := col
		halo.a = col.a * (0.10 + 0.06 * (1.0 - f))
		ci.draw_line(xf * a, xf * b, _c(halo), maxf(1.0, _w(width + blur * 0.5 * f)), true)
	line(a, b, col, width)


func glow_polyline(points: PackedVector2Array, col: Color, width: float = 1.0, blur: float = 12.0, closed := false) -> void:
	if points.size() < 2:
		return
	var p := _pts(points)
	if closed:
		p.append(p[0])
	for i in range(GLOW_STEPS, 0, -1):
		var f := float(i) / float(GLOW_STEPS)
		var halo := col
		halo.a = col.a * (0.11 + 0.07 * (1.0 - f))
		ci.draw_polyline(p, _c(halo), maxf(1.0, _w(width + blur * 0.55 * f)), true)
	polyline(points, col, width, closed)


func glow_circle(center: Vector2, radius: float, col: Color, blur: float = 12.0) -> void:
	for i in range(GLOW_STEPS, 0, -1):
		var f := float(i) / float(GLOW_STEPS)
		var halo := col
		halo.a = col.a * 0.10 * f
		circle(center, radius + blur * 0.35 * f, halo)
	circle(center, radius, col)


func glow_ring(center: Vector2, radius: float, col: Color, width: float = 1.0, blur: float = 12.0) -> void:
	for i in range(GLOW_STEPS, 0, -1):
		var f := float(i) / float(GLOW_STEPS)
		var halo := col
		halo.a = col.a * 0.13
		ring(center, radius, halo, width + blur * 0.5 * f)
	ring(center, radius, col, width)


func glow_round_rect(r: Rect2, col: Color, blur: float = 12.0, width: float = 2.0, rad := 6.0) -> void:
	var pts := round_rect_pts(r, rad)
	glow_polyline(pts, col, width, blur, true)


func glow_rect(r: Rect2, col: Color, blur: float = 12.0) -> void:
	for i in range(GLOW_STEPS, 0, -1):
		var f := float(i) / float(GLOW_STEPS)
		var halo := col
		halo.a = col.a * 0.12 * f
		var e := blur * 0.4 * f
		rect(Rect2(r.position - Vector2(e, e), r.size + Vector2(e, e) * 2.0), halo)
	rect(r, col)


# --------------------------------------------------------------- gradients ---

var _grad_cache := {}


func _lin_tex(a: Color, b: Color) -> GradientTexture2D:
	var key := "l%s%s" % [a.to_html(), b.to_html()]
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 256
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	_grad_cache[key] = t
	return t


## Vertical linear gradient in screen space (transform is ignored).
func vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_texture_rect(_lin_tex(top, bottom), r, false, _c(Color.WHITE))


func _radial_tex(inner: Color, outer: Color) -> GradientTexture2D:
	var key := "r%s%s" % [inner.to_html(), outer.to_html()]
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_grad_cache[key] = t
	return t


## Radial glow disc: solid `inner` at the centre fading into `outer` at `radius`.
func radial(center: Vector2, radius: float, inner: Color, outer: Color) -> void:
	var c := xf * center
	var s := (xf.x.length() + xf.y.length()) * 0.5
	var r := radius * s
	ci.draw_texture_rect(_radial_tex(inner, outer), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, _c(Color.WHITE))


## Radial disc with an extra middle stop (canvas addColorStop at 0.25 etc).
func radial_stops(center: Vector2, radius: float, stops: Array) -> void:
	var key := "rs"
	for c in stops:
		key += (c as Color).to_html()
	if not _grad_cache.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([stops[0], stops[stops.size() - 1]])
		for i in range(1, stops.size() - 1):
			g.add_point(float(i) / float(maxi(1, stops.size() - 1)), stops[i])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_grad_cache[key] = t
	var c := xf * center
	var s := (xf.x.length() + xf.y.length()) * 0.5
	var r := radius * s
	ci.draw_texture_rect(_grad_cache[key], Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, _c(Color.WHITE))


func ellipse_outline(center: Vector2, rx: float, ry: float, col: Color, width := 1.0, segments := 44) -> void:
	var p := PackedVector2Array()
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	polyline(p, col, width)


# --------------------------------------------------------------------- text ---

func text(txt: String, pos: Vector2, size: float, col: Color, align := "center", glow := false, use_mono := false) -> void:
	var f: Font = mono if (use_mono and mono != null) else font
	if f == null:
		f = ThemeDB.fallback_font
	var width := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var p := xf * pos
	match align:
		"left":
			pass
		"right":
			p.x -= width
		_:
			p.x -= width * 0.5
	if glow:
		for i in range(2, 0, -1):
			var halo := col
			halo.a = col.a * 0.20
			ci.draw_string(f, p + Vector2(0, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), _c(halo))
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), _c(col))


func text_width(txt: String, size: float) -> float:
	var f: Font = font if font != null else ThemeDB.fallback_font
	return f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
