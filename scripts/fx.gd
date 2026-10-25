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
		var p := target.global_position + offset
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
		var tip := target.global_position + offset * 0.68 - global_position
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
