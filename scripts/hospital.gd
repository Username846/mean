extends Node2D
## "Oh no!" cutscene after a serious accident: the ambulance races to the
## hospital, then Bro recovers in bed (bandaged up) while the doctor scolds you.

const Bro = preload("res://scripts/bro.gd")
const FX = preload("res://scripts/fx.gd")

var t := 0.0
var phase := "street"
var amb_x := -420.0
var bro: Bro
var amb_anchor: Node2D
var doc_anchor: Node2D
var beep_t := 0.0
var ui: CanvasLayer
var fade: ColorRect


func _ready() -> void:
	Game.stop_music()
	amb_anchor = Node2D.new()
	add_child(amb_anchor)
	doc_anchor = Node2D.new()
	doc_anchor.position = Vector2(270, 300)
	add_child(doc_anchor)
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var banner := Game.make_label("EMERGENCY! To the hospital!", 46, Color("#ff4a4a"))
	banner.add_theme_constant_override("outline_size", 14)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(1280, 60)
	banner.position = Vector2(0, 24)
	banner.name = "Banner"
	ui.add_child(banner)
	fade = ColorRect.new()
	fade.color = Color(1, 1, 1, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	Game.sfx("siren", 0.0)
	get_tree().create_timer(0.3).timeout.connect(func(): Game.voice("emergency"))
	get_tree().create_timer(3.4).timeout.connect(func():
		if phase == "street":
			Game.sfx("siren", 0.0))
	get_tree().create_timer(2.6).timeout.connect(func(): _say(amb_anchor, "medic", Vector2(0, -150)))
	create_tween().tween_property(self, "amb_x", 640.0, 4.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_interval(5.8)
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(_enter_room)
	tw.tween_property(fade, "color:a", 0.0, 0.6)


func _say(anchor: Node2D, id: String, off: Vector2) -> void:
	var info := Game.voice(id)
	add_child(FX.Bubble.new(anchor, info[1], info[2], off, Color("#e8f6ff")))


func _enter_room() -> void:
	phase = "room"
	ui.get_node("Banner").queue_free()
	Game.play_music("hospital")
	bro = Bro.new()
	bro.position = Vector2(700, 610)
	bro.sitting = true
	bro.hide_legs = true
	bro.look_at_mouse = false
	bro.look = Vector2(-0.6, 0)
	bro.set_mood("sad")
	bro.shirt_col = Color("#a8d0f0")
	match Game.hospital_from:
		"kitchen", "backyard", "snow_park", "game_room":
			bro.bandage = 1
		"bedroom":
			bro.bandage = 2
		"cafeteria":
			bro.puff = 0.35
		"living_room":
			bro.hair_up = 1.0
	add_child(bro)
	add_child(FX.Layer.new(_draw_blanket, 3))
	get_tree().create_timer(1.4).timeout.connect(func(): _say(doc_anchor, "doctor_ok", Vector2(40, -90)))
	get_tree().create_timer(5.0).timeout.connect(func():
		bro.set_mood("angry")
		bro.say("hosp_bro"))
	get_tree().create_timer(2.0).timeout.connect(_show_panel)


func _show_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(330, 568)
	panel.custom_minimum_size = Vector2(620, 0)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var d := Game.make_label("Diagnosis: " + Game.hospital_cause, 24, Color("#ff9a9a"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var c := Game.make_label("Hospital trips discovered: %d / 10" % Game.injuries.size(), 22, Color("#ffde3b"))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var map := Button.new()
	map.text = "Back to map"
	map.pressed.connect(func():
		Game.sfx("click")
		Game.goto("menu"))
	h.add_child(map)
	var info := Game.scene_info(Game.hospital_from)
	if not info.is_empty():
		var again := Button.new()
		again.text = "Back to the " + info.name
		again.pressed.connect(func():
			Game.sfx("click")
			Game.goto(Game.hospital_from))
		h.add_child(again)


func _process(dt: float) -> void:
	t += dt
	amb_anchor.position = Vector2(amb_x + 40, 420)
	if phase == "room":
		beep_t -= dt
		if beep_t <= 0:
			beep_t = 0.9
			Game.sfx("beep", 0.0, -12)
	queue_redraw()


func _draw() -> void:
	if phase == "street":
		_draw_street()
	else:
		_draw_room()


func _draw_street() -> void:
	var top := Color("#7fc4ff")
	var bot := Color("#d8efff")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 560), Vector2(0, 560)]),
		PackedColorArray([top, top, bot, bot]))
	# hospital
	draw_rect(Rect2(780, 130, 470, 430), Color("#f2f2f6"))
	for x in 4:
		for y in 3:
			draw_rect(Rect2(810 + x * 110, 230 + y * 90, 70, 55), Color("#9fd0f0"))
	draw_rect(Rect2(920, 440, 160, 120), Color("#7ab0d0"))
	draw_rect(Rect2(880, 140, 260, 60), Color("#e8303a"))
	draw_string(ThemeDB.fallback_font, Vector2(905, 186), "HOSPITAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	draw_rect(Rect2(1180, 60, 20, 70), Color("#e8303a"))
	draw_rect(Rect2(1155, 85, 70, 20), Color("#e8303a"))
	# road
	draw_rect(Rect2(0, 560, 1280, 160), Color("#4a4a55"))
	for i in 10:
		draw_rect(Rect2(fmod(i * 160 - t * 0, 1280), 630, 90, 10), Color("#f2e060"))
	# ambulance
	var a := Vector2(amb_x, 560)
	var bounce := sin(t * 30) * 2 if amb_x < 630 else 0.0
	draw_set_transform(Vector2(0, bounce), 0, Vector2.ONE)
	FX.rounded_rect(self, Rect2(a + Vector2(-190, -170), Vector2(300, 140)), Color.WHITE, 14, Color("#888"), 3)
	FX.rounded_rect(self, Rect2(a + Vector2(100, -130), Vector2(110, 100)), Color.WHITE, 14, Color("#888"), 3)
	draw_rect(Rect2(a + Vector2(130, -118), Vector2(60, 40)), Color("#9fd0f0"))
	draw_rect(Rect2(a + Vector2(-190, -95), Vector2(400, 18)), Color("#e8303a"))
	draw_rect(Rect2(a + Vector2(-70, -160), Vector2(20, 60)), Color("#e8303a"))
	draw_rect(Rect2(a + Vector2(-90, -140), Vector2(60, 20)), Color("#e8303a"))
	var on := fmod(t * 6, 2.0) < 1.0
	draw_circle(a + Vector2(-120, -180), 16, Color("#ff2030") if on else Color("#801018"))
	draw_circle(a + Vector2(-60, -180), 16, Color("#2050ff") if not on else Color("#102080"))
	if on:
		draw_circle(a + Vector2(-120, -180), 40, Color(1, 0.1, 0.1, 0.25))
	else:
		draw_circle(a + Vector2(-60, -180), 40, Color(0.1, 0.3, 1, 0.25))
	for wx in [-120.0, 130.0]:
		draw_circle(a + Vector2(wx, -20), 30, Color("#222"))
		draw_circle(a + Vector2(wx, -20), 12, Color("#bbb"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# speed lines
	if amb_x < 600:
		for i in 5:
			draw_line(a + Vector2(-230 - i * 20, -150 + i * 25), a + Vector2(-330 - i * 30, -150 + i * 25), Color(1, 1, 1, 0.7), 4)


func _draw_room() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#d8f0e4"))
	draw_rect(Rect2(0, 560, 1280, 160), Color("#c0d8e8"))
	# window
	FX.rounded_rect(self, Rect2(470, 70, 300, 200), Color("#9fd8ff"), 8, Color("#f4f4f4"), 10)
	draw_circle(Vector2(700, 130), 30, Color("#fff4a0"))
	# get well balloons
	for i in 3:
		var p := Vector2(1150 + i * 40, 180 + sin(t * 2 + i) * 8)
		draw_line(p + Vector2(0, 40), Vector2(1180, 470), Color("#666"), 2)
		draw_colored_polygon(FX.ellipse(p, 28, 36), [Color("#ff6f86"), Color("#ffde3b"), Color("#5ad1ff")][i])
	draw_string(ThemeDB.fallback_font, Vector2(1040, 120), "GET WELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#e8303a"))
	# heart monitor
	FX.rounded_rect(self, Rect2(880, 260, 220, 150), Color("#222"), 10)
	draw_rect(Rect2(892, 272, 196, 110), Color("#082010"))
	var pts := PackedVector2Array()
	for i in 50:
		var x := i * 4.0
		var ph := fmod(x / 196.0 * 2.0 + t * 1.1, 1.0)
		var y := 0.0
		if ph > 0.45 and ph < 0.5:
			y = -40 * sin((ph - 0.45) / 0.05 * PI)
		elif ph > 0.5 and ph < 0.53:
			y = 15
		pts.append(Vector2(892 + x, 330 + y))
	draw_polyline(pts, Color("#40ff70"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(900, 402), "HR 72", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#40ff70"))
	draw_line(Vector2(990, 410), Vector2(990, 560), Color("#888"), 6)
	# bed head + pillow
	FX.rounded_rect(self, Rect2(500, 330, 400, 90), Color("#9aa6b8"), 12)
	draw_colored_polygon(FX.ellipse(Vector2(700, 420), 170, 50), Color.WHITE)
	# doctor
	var d := Vector2(270, 300)
	FX.rounded_rect(self, Rect2(d + Vector2(-80, 70), Vector2(160, 330)), Color.WHITE, 30, Color("#ccc"), 3)
	draw_line(d + Vector2(0, 80), d + Vector2(0, 400), Color("#ddd"), 3)
	draw_rect(Rect2(d + Vector2(-14, 60), Vector2(28, 30)), Color("#c98f6a"))
	draw_circle(d, 62, Color("#c98f6a"))
	draw_arc(d + Vector2(0, -6), 64, PI * 0.9, PI * 1.1, 8, Color("#bbb"), 18)
	draw_arc(d + Vector2(0, -6), 64, -PI * 0.1, PI * 0.1, 8, Color("#bbb"), 18)
	for s: int in [-1, 1]:
		draw_arc(d + Vector2(s * 24, 0), 16, 0, TAU, 20, Color("#333"), 4)
		draw_circle(d + Vector2(s * 24, 0), 5, Color("#222"))
	draw_line(d + Vector2(-8, 0), d + Vector2(8, 0), Color("#333"), 4)
	draw_arc(d + Vector2(0, 26), 20, 0.3, PI - 0.3, 10, Color("#5a2010"), 5)
	draw_circle(d + Vector2(0, -50), 18, Color("#ddd"))
	draw_circle(d + Vector2(0, -50), 8, Color("#999"))
	draw_arc(d + Vector2(0, 140), 40, 0, PI, 12, Color("#333"), 5)
	draw_circle(d + Vector2(0, 180), 10, Color("#888"))


func _draw_blanket(ci: CanvasItem) -> void:
	if phase != "room":
		return
	FX.rounded_rect(ci, Rect2(470, 540, 460, 60), Color("#9aa6b8"), 10)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(480, 610), Vector2(500, 520), Vector2(700, 505), Vector2(900, 520), Vector2(920, 610)]),
		Color("#5a8ad6"))
	ci.draw_line(Vector2(500, 528), Vector2(900, 528), Color("#f4f4f4"), 14)
	ci.draw_rect(Rect2(500, 610, 20, 110), Color("#888"))
	ci.draw_rect(Rect2(880, 610, 20, 110), Color("#888"))
