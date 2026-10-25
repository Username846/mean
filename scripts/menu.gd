extends Node2D
## The map: pick one of the ten places to bug your brother.

const Bro = preload("res://scripts/bro.gd")
const FX = preload("res://scripts/fx.gd")

var t := 0.0
var bro: Bro


func _ready() -> void:
	Game.play_music("menu")
	var head := Game.make_label("Choose a place to bug your brother!", 40, Color("#ffde3b"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.size = Vector2(1280, 50)
	head.position = Vector2(0, 14)
	add_child(head)
	var info := Game.make_label("Total mean points: %d    Rank: %s    Stars: %d / 10" % [
		Game.total_mean, Game.rank_title(), Game.star_count()], 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.size = Vector2(1280, 30)
	info.position = Vector2(0, 66)
	add_child(info)

	for i in Game.SCENES.size():
		var s: Dictionary = Game.SCENES[i]
		var col := i % 5
		var row := i / 5
		var card := _card(s)
		card.position = Vector2(40 + col * 244, 112 + row * 262)
		add_child(card)

	var foot := HBoxContainer.new()
	foot.position = Vector2(40, 650)
	foot.add_theme_constant_override("separation", 14)
	add_child(foot)
	var mus := Button.new()
	mus.text = "Music: On" if Game.music_on else "Music: Off"
	mus.pressed.connect(func(): mus.text = "Music: On" if Game.toggle_music() else "Music: Off")
	foot.add_child(mus)
	var reset := Button.new()
	reset.text = "Reset progress"
	reset.pressed.connect(func():
		if reset.text == "Really reset?":
			Game.reset_save()
			Game.goto("menu")
		else:
			reset.text = "Really reset?")
	foot.add_child(reset)
	if Game.star_count() >= 10:
		var end := Button.new()
		end.text = "  The Ending  "
		end.add_theme_stylebox_override("normal", Game._box(Color("#d63bff")))
		end.pressed.connect(func(): Game.goto("ending"))
		foot.add_child(end)

	bro = Bro.new()
	bro.position = Vector2(1190, 900)
	bro.scale = Vector2(0.5, 0.5)
	bro.set_mood("smug")
	bro.z_index = 5
	add_child(bro)

	get_tree().create_timer(0.5).timeout.connect(func():
		if Game.star_count() >= 10 and not Game.seen_ending:
			Game.goto("ending")
		elif not Game.voice_busy():
			Game.voice("choose"))


func _card(s: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(224, 246)
	b.size = Vector2(224, 246)
	var c: Color = s.col
	b.add_theme_stylebox_override("normal", Game._box(c.darkened(0.15), 20, Color(0, 0, 0, 0.4), 4))
	b.add_theme_stylebox_override("hover", Game._box(c, 20, Color("#fff6b0"), 5))
	b.add_theme_stylebox_override("pressed", Game._box(c.darkened(0.3), 20, Color("#fff6b0"), 5))
	b.pivot_offset = Vector2(112, 123)
	b.mouse_entered.connect(func():
		Game.sfx("pop", 0.1, -6)
		b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.06, 0.1))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.pressed.connect(func():
		Game.sfx("click")
		Game.goto(s.id))
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(0, 0)
	icon.size = Vector2(224, 130)
	icon.draw.connect(func(): draw_icon(icon, s.id, Vector2(112, 72), t))
	b.add_child(icon)
	var name := Game.make_label(s.name, 24)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(0, 132)
	name.size = Vector2(224, 30)
	b.add_child(name)
	var desc := Game.make_label(s.desc, 16, Color(1, 1, 1, 0.95))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_constant_override("outline_size", 6)
	desc.position = Vector2(10, 164)
	desc.size = Vector2(204, 44)
	b.add_child(desc)
	var starred: bool = Game.stars.get(s.id, false)
	var st := Game.make_label(("STAR!  " if starred else "no star  ") + "best %d" % Game.best.get(s.id, 0), 16,
		Color("#fff36a") if starred else Color(1, 1, 1, 0.6))
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.position = Vector2(0, 212)
	st.size = Vector2(224, 24)
	b.add_child(st)
	if starred:
		var star := Control.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.position = Vector2(190, 6)
		star.size = Vector2(30, 30)
		star.draw.connect(func(): draw_star(star, Vector2(14, 16), 16, Color("#ffe14a")))
		b.add_child(star)
	return b


func _process(dt: float) -> void:
	t += dt
	bro.position.y = lerpf(bro.position.y, 795, 0.05)
	for c in get_children():
		if c is Button:
			for k in c.get_children():
				if k is Control:
					k.queue_redraw()


func _draw() -> void:
	var top := Color("#2d1b52")
	var bot := Color("#6b2f7a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([top, top, bot, bot]))
	for i in 40:
		var p := Vector2(fmod(i * 337.0, 1280), fmod(i * 191.0, 720))
		draw_circle(p, 2 + (i % 3), Color(1, 1, 1, 0.12 + 0.1 * sin(t * 2 + i)))


static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.3, 0.15, 0), 2)


static func draw_icon(ci: CanvasItem, id: String, c: Vector2, t: float) -> void:
	var ink := Color(0.12, 0.08, 0.16)
	var bob := sin(t * 3) * 4
	match id:
		"living_room":
			FX.rounded_rect(ci, Rect2(c + Vector2(-70, -10), Vector2(140, 50)), Color("#b5482f"), 14)
			FX.rounded_rect(ci, Rect2(c + Vector2(-80, -30), Vector2(30, 70)), Color("#9a3a25"), 12)
			FX.rounded_rect(ci, Rect2(c + Vector2(50, -30), Vector2(30, 70)), Color("#9a3a25"), 12)
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, -30 + bob), 30, 14), Color("#ff6f86"))
			ci.draw_circle(c + Vector2(0, -30 + bob), 6, Color("#ffb3c0"))
		"kitchen":
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, 14), 60, 22), Color("#c98b4a"))
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, 2), 56, 20), Color("#fff6e6"))
			for i in 5:
				ci.draw_circle(c + Vector2(-40 + i * 20, -6 + bob * 0.5), 10, Color.WHITE)
			ci.draw_circle(c + Vector2(0, -18 + bob), 9, Color("#d42033"))
		"backyard":
			var p := c + Vector2(0, bob)
			ci.draw_colored_polygon(FX.ellipse(p, 36, 44), Color("#5ad1ff"))
			ci.draw_circle(p + Vector2(-12, -16), 9, Color(1, 1, 1, 0.6))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 44), p + Vector2(6, 44), p + Vector2(0, 52)]), Color("#3aa9d6"))
		"bedroom":
			ci.draw_set_transform(c, -0.6 + sin(t * 2) * 0.1, Vector2.ONE)
			FX.rounded_rect(ci, Rect2(-14, -60, 28, 100), Color("#2a2a35"), 8)
			FX.rounded_rect(ci, Rect2(-14, -60, 28, 26), Color("#e03a3a"), 8)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-14, 40), Vector2(14, 40), Vector2(0, 62)]), Color("#f2c79b"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"game_room":
			FX.rounded_rect(ci, Rect2(c + Vector2(-60, -28), Vector2(120, 56)), Color("#3a3a48"), 26)
			ci.draw_rect(Rect2(c + Vector2(-42, -6), Vector2(28, 10)), Color("#ddd"))
			ci.draw_rect(Rect2(c + Vector2(-33, -15), Vector2(10, 28)), Color("#ddd"))
			ci.draw_circle(c + Vector2(30, -8), 8, Color("#ff5a4f"))
			ci.draw_circle(c + Vector2(44, 6), 8, Color("#5ad16a"))
			ci.draw_line(c + Vector2(0, -28), c + Vector2(20 + bob * 3, -60), ink, 4)
		"cafeteria":
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, 26), 64, 16), Color("#e3b06a"))
			ci.draw_rect(Rect2(c + Vector2(-60, 8), Vector2(120, 10)), Color("#6bd14a"))
			ci.draw_rect(Rect2(c + Vector2(-56, -2), Vector2(112, 10)), Color("#c94a3a"))
			ci.draw_rect(Rect2(c + Vector2(-58, -12), Vector2(116, 10)), Color("#f7d84a"))
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, -22), 64, 20), Color("#e3b06a"))
			ci.draw_arc(c + Vector2(20, -50 + bob), 12, 0, PI, 8, Color("#ff7ab0"), 6)
		"snow_park":
			ci.draw_circle(c + Vector2(0, 26), 40, Color.WHITE)
			ci.draw_circle(c + Vector2(0, -26), 28, Color.WHITE)
			ci.draw_circle(c + Vector2(-9, -30), 4, ink)
			ci.draw_circle(c + Vector2(9, -30), 4, ink)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -24), c + Vector2(0, -18), c + Vector2(22, -21)]), Color("#ff8a2a"))
			ci.draw_circle(c + Vector2(60, -20 + bob), 14, Color("#e6f4ff"))
		"beach":
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(0, 10), 40, 26), Color("#ff5a3a"))
			for s: int in [-1, 1]:
				ci.draw_line(c + Vector2(s * 30, 0), c + Vector2(s * 56, -30 + bob), Color("#ff5a3a"), 8)
				ci.draw_circle(c + Vector2(s * 58, -34 + bob), 12, Color("#ff5a3a"))
				ci.draw_circle(c + Vector2(s * 12, -14), 7, Color.WHITE)
				ci.draw_circle(c + Vector2(s * 12, -14), 3, ink)
		"attic":
			var p := c + Vector2(0, bob)
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(PI, TAU, i / 12.0)
				pts.append(p + Vector2(cos(a) * 40, sin(a) * 40 - 6))
			for i in 7:
				pts.append(p + Vector2(40 - i * 13.3, 44 + (8 if i % 2 == 0 else -4)))
			ci.draw_colored_polygon(pts, Color("#f2f0ff"))
			ci.draw_colored_polygon(FX.ellipse(p + Vector2(-14, -10), 7, 10), ink)
			ci.draw_colored_polygon(FX.ellipse(p + Vector2(14, -10), 7, 10), ink)
			ci.draw_colored_polygon(FX.ellipse(p + Vector2(0, 16), 10, 12), ink)
		"carnival":
			for i in 4:
				ci.draw_circle(c, 50 - i * 12, Color("#ff5a4f") if i % 2 == 0 else Color.WHITE)
			ci.draw_line(c + Vector2(60, -40 + bob), c + Vector2(10, -6), ink, 4)
			ci.draw_circle(c + Vector2(64, -44 + bob), 10, Color("#ffde3b"))
