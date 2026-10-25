extends RefCounted
## Small reusable visual effects. Use via `const FX = preload("res://scripts/fx.gd")`.


## A Node2D that renders through a callable: `FX.Layer.new(func(ci): ...)`.
class Layer extends Node2D:
	var fn: Callable

	func _init(f: Callable = Callable(), z := 0) -> void:
		fn = f
		z_index = z

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## Speech bubble that follows a target node.
class Bubble extends Node2D:
	var target: Node2D
	var offset := Vector2(0, -300)
	var text := ""
	var life := 2.0
	var age := 0.0
	var label: Label
	var size := Vector2.ZERO
	var tint := Color.WHITE
	var follow: Callable     ## optional: returns where the bubble sits
	var tip_at: Callable     ## optional: returns where the tail points

	func _init(t: Node2D, txt: String, dur: float, off: Vector2, col := Color.WHITE) -> void:
		target = t
		text = txt
		life = dur + 0.9
		offset = off
		tint = col
		top_level = true
		z_index = 50
		label = Label.new()
		label.text = txt
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.16))
		label.add_theme_constant_override("outline_size", 0)
		var w := clampf(txt.length() * 13.0, 90.0, 320.0)
		label.custom_minimum_size = Vector2(w, 0)
		label.size = Vector2(w, 0)
		add_child(label)

	func _process(dt: float) -> void:
		age += dt
		if not is_instance_valid(target):
			queue_free()
			return
		size = label.get_combined_minimum_size() + Vector2(24, 16)
		label.size = size - Vector2(24, 16)
		label.position = -size / 2.0 + Vector2(12, 8)
		var p: Vector2 = follow.call() if follow.is_valid() else target.global_position + offset
		p.x = clampf(p.x, size.x / 2 + 8, 1280 - size.x / 2 - 8)
		p.y = clampf(p.y, size.y / 2 + 70, 720 - size.y / 2 - 8)
		global_position = p
		var pop := minf(age * 8.0, 1.0)
		scale = Vector2.ONE * (0.6 + 0.4 * pop)
		modulate.a = clampf((life - age) * 3.0, 0.0, 1.0)
		if age > life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-size / 2, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint
		sb.set_corner_radius_all(16)
		sb.border_color = Color(0.12, 0.08, 0.16)
		sb.set_border_width_all(3)
		var aim: Vector2 = tip_at.call() if tip_at.is_valid() else target.global_position + offset * 0.68
		var tip := aim - global_position
		tip = tip.limit_length(size.y / 2 + 40)
		var base_y := size.y / 2 - 2
		if tip.y < 0:
			base_y = -base_y
		draw_colored_polygon(PackedVector2Array([Vector2(-14, base_y), Vector2(14, base_y), tip]), tint)
		draw_polyline(PackedVector2Array([Vector2(-14, base_y), tip, Vector2(14, base_y)]),
			Color(0.12, 0.08, 0.16), 3)
		draw_style_box(sb, r)


## Particle burst of circles (splat, water, sand, confetti, ...).
class Burst extends Node2D:
	var parts: Array = []
	var gravity := 900.0
	var age := 0.0

	func _init(pos: Vector2, count: int, colors: Array, speed := 300.0, size := 6.0,
			grav := 900.0, life := 1.0, spread := TAU, dir := -PI / 2) -> void:
		position = pos
		gravity = grav
		z_index = 40
		for i in count:
			var a := dir + randf_range(-spread / 2, spread / 2)
			var v := Vector2.from_angle(a) * randf_range(speed * 0.3, speed)
			parts.append({"p": Vector2.ZERO, "v": v, "c": colors.pick_random(),
				"s": randf_range(size * 0.5, size * 1.3), "l": randf_range(life * 0.6, life),
				"rot": randf() * TAU, "sq": randf() < 0.4})

	func _process(dt: float) -> void:
		age += dt
		var alive := false
		for p in parts:
			p.v.y += gravity * dt
			p.v *= 0.99
			p.p += p.v * dt
			p.rot += dt * 6
			if age < p.l:
				alive = true
		if not alive:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for p in parts:
			if age >= p.l:
				continue
			var c: Color = p.c
			c.a *= clampf((p.l - age) * 3.0, 0, 1)
			if p.sq:
				draw_set_transform(p.p, p.rot, Vector2.ONE)
				draw_rect(Rect2(-p.s, -p.s * 0.5, p.s * 2, p.s), c)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				draw_circle(p.p, p.s, c)


## Cartoon blood puddle that spreads out from a point.
class Puddle extends Node2D:
	var size := 0.0
	var max_size := 90.0
	var age := 0.0

	func _init(pos: Vector2, max_rx := 90.0, z := 0) -> void:
		position = pos
		max_size = max_rx
		z_index = z

	func _process(dt: float) -> void:
		age += dt
		size = max_size * (1.0 - exp(-age * 0.9))
		queue_redraw()

	func _draw() -> void:
		var col := Color("#b0101e")
		draw_colored_polygon(FX_ellipse(Vector2.ZERO, size, size * 0.28), col)
		for i in 5:
			var o := Vector2(cos(i * 1.9) * size * 0.8, sin(i * 1.3) * size * 0.2)
			draw_circle(o, size * 0.18, col)
		draw_colored_polygon(FX_ellipse(Vector2(-size * 0.25, -size * 0.06), size * 0.3, size * 0.06), Color(1, 0.5, 0.5, 0.45))

	static func FX_ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24
			pts.append(c + Vector2(cos(a) * maxf(rx, 1), sin(a) * maxf(ry, 1)))
		return pts


## A 9mm semi-automatic pistol in side view, muzzle pointing right: steel slide
## with rear serrations and sights, black polymer frame, stippled grip.
static func draw_blaster(ci: CanvasItem, pos: Vector2, sc := 1.0, rot := 0.0) -> void:
	var line := Color("#060607")
	var frame := Color("#1c1d20")
	var steel := Color("#3a3d43")
	ci.draw_set_transform(pos, rot, Vector2(sc, sc))
	# grip (raked back) + beavertail
	var grip := PackedVector2Array([Vector2(-44, -6), Vector2(-12, -6), Vector2(-14, 4), Vector2(-21, 46),
		Vector2(-46, 46), Vector2(-48, 40), Vector2(-42, 6), Vector2(-54, -2)])
	ci.draw_colored_polygon(grip, frame)
	for gy in range(6, 42, 5):
		for gx in range(-44, -16, 5):
			var p := Vector2(gx + (gy % 2) * 2.5 + (gy - 6) * -0.18, gy)
			if Geometry2D.is_point_in_polygon(p, grip):
				ci.draw_circle(p, 1.1, Color("#2c2e33"))
	ci.draw_polyline(grip + PackedVector2Array([grip[0]]), line, 2.0, true)
	# magazine baseplate
	ci.draw_rect(Rect2(-48, 45, 29, 6), Color("#101113"))
	ci.draw_rect(Rect2(-48, 45, 29, 6), line, false, 1.5)
	# frame / dust cover with accessory rail
	ci.draw_rect(Rect2(-14, -6, 74, 10), frame)
	for k in 4:
		ci.draw_line(Vector2(30 + k * 7, 0), Vector2(30 + k * 7, 4), line, 1.5)
	ci.draw_rect(Rect2(-14, -6, 74, 10), line, false, 2.0)
	# trigger guard + trigger
	var guard := PackedVector2Array([Vector2(14, 4), Vector2(14, 12), Vector2(10, 19), Vector2(-2, 20), Vector2(-15, 17)])
	ci.draw_polyline(guard, frame, 6.0, true)
	ci.draw_polyline(guard, line, 1.5, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(1, 4), Vector2(5, 4), Vector2(3, 11), Vector2(-1, 16),
		Vector2(-3, 15), Vector2(0, 10)]), Color("#0c0c0e"))
	# slide
	var slide := PackedVector2Array([Vector2(-52, -26), Vector2(62, -26), Vector2(64, -23), Vector2(64, -6),
		Vector2(-50, -6), Vector2(-54, -12)])
	ci.draw_colored_polygon(slide, steel)
	ci.draw_rect(Rect2(-50, -25, 113, 3), Color("#6b7079"))      # top highlight
	ci.draw_rect(Rect2(-50, -10, 114, 4), Color("#2a2c31"))      # lower shadow
	for k in 6:
		ci.draw_line(Vector2(-46 + k * 3.5, -22), Vector2(-46 + k * 3.5, -9), Color("#1b1c20"), 1.6)
	ci.draw_rect(Rect2(2, -23, 20, 9), Color("#0e0f11"))         # ejection port
	ci.draw_rect(Rect2(4, -21, 16, 2), Color("#8a8f98"))         # barrel hood
	ci.draw_polyline(slide + PackedVector2Array([slide[0]]), line, 2.0, true)
	# muzzle, sights, slide stop, takedown
	ci.draw_rect(Rect2(62, -21, 3, 12), Color("#121315"))
	ci.draw_rect(Rect2(55, -30, 5, 4), Color("#101113"))
	ci.draw_rect(Rect2(-49, -31, 12, 5), Color("#101113"))
	ci.draw_rect(Rect2(-44.5, -31, 3, 2.5), steel)               # rear-sight notch
	ci.draw_circle(Vector2(57.5, -29), 1.0, Color("#d8e0e8"))
	ci.draw_rect(Rect2(-18, -6, 16, 4), Color("#141518"))
	ci.draw_circle(Vector2(18, -1), 2.2, Color("#141518"))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## A bullet in flight: a copper slug with a faint streak behind it.
static func draw_dart(ci: CanvasItem, pos: Vector2, rot: float, sc := 1.0) -> void:
	ci.draw_set_transform(pos, rot, Vector2(sc, sc))
	ci.draw_line(Vector2(-90, 0), Vector2(-6, 0), Color(1, 0.85, 0.55, 0.35), 3)
	ci.draw_rect(Rect2(-8, -2.5, 7, 5), Color("#b87333"))
	ci.draw_circle(Vector2(-1, 0), 2.5, Color("#c9874a"))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Muzzle flash at `pos` pointing along `rot`; `k` runs 1 (fresh) .. 0 (gone).
static func draw_muzzle_flash(ci: CanvasItem, pos: Vector2, rot: float, k: float) -> void:
	if k <= 0.0:
		return
	ci.draw_set_transform(pos, rot, Vector2.ONE * (0.6 + 0.6 * k))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + PI * i / 9.0
		var r := 22.0 if i % 2 == 0 else 10.0
		var stretch := 1.0 + 1.6 * maxf(0.0, cos(a))
		outer.append(Vector2.from_angle(a) * r * stretch)
		inner.append(Vector2.from_angle(a) * r * stretch * 0.5)
	ci.draw_colored_polygon(outer, Color(1, 0.62, 0.15, 0.85 * k))
	ci.draw_colored_polygon(inner, Color(1, 0.95, 0.7, k))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Bullet hole where a shot missed; fades out with `alpha`.
static func draw_bullet_hole(ci: CanvasItem, pos: Vector2, alpha: float) -> void:
	for k in 5:
		var dir := Vector2.from_angle(k * 1.3 + pos.x * 0.01)
		ci.draw_line(pos + dir * 5, pos + dir * (11 + k % 3 * 4), Color(0.1, 0.1, 0.1, 0.5 * alpha), 1.5)
	ci.draw_circle(pos, 6, Color(0.25, 0.22, 0.2, 0.6 * alpha))
	ci.draw_circle(pos, 3.5, Color(0.04, 0.04, 0.05, alpha))


## "+25 MEAN!" style floating text.
static func float_text(parent: Node, pos: Vector2, text: String, col := Color("#ffde3b"), size := 30) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.1))
	l.z_index = 60
	l.position = Vector2(clampf(pos.x, 90, 1130), clampf(pos.y, 110, 680)) - Vector2(60, 20)
	l.pivot_offset = Vector2(60, 20)
	parent.add_child(l)
	l.scale = Vector2(0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.15, 0.12)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - 70, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


static func ellipse(c: Vector2, rx: float, ry: float, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func rounded_rect(ci: CanvasItem, r: Rect2, col: Color, radius := 12.0, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	ci.draw_style_box(sb, r)
