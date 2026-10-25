extends Node2D
## "Oh no!" cutscene after a serious accident: the ambulance races to the
## hospital, then Bro recovers in bed (bandaged up) while the doctor scolds you.
## Tap an ambulance wheel on the way and it blows out, rolls, and a rescue
## helicopter has to fly him to another hospital instead.

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
var drive_tw: Tween
var street_tw: Tween
var crashed := false
var popped := 0.0            ## local x of the blown wheel
var amb_rot := 0.0
var amb_dy := 0.0
var heli_x := -400.0
var heli_on := false
var rope := 0.0              ## 0 = stretcher at the helicopter, 1 = down at the wreck
var carrying := false
var smoke_t := 0.0
const AMB_PIVOT := Vector2(-40, -100)
const WHEELS := [Vector2(-120, -20), Vector2(130, -20)]


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
	get_tree().create_timer(2.6).timeout.connect(func():
		if not crashed:
			_say(amb_anchor, "medic", Vector2(0, -150)))
	drive_tw = create_tween()
	drive_tw.tween_property(self, "amb_x", 640.0, 4.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	street_tw = create_tween()
	street_tw.tween_interval(5.8)
	street_tw.tween_callback(_to_room)


func _to_room() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(_enter_room)
	tw.tween_property(fade, "color:a", 0.0, 0.6)


func _amb_xform() -> Transform2D:
	return Transform2D(amb_rot, Vector2(amb_x, 560 + amb_dy) + AMB_PIVOT) * Transform2D(0, -AMB_PIVOT)


func _unhandled_input(e: InputEvent) -> void:
	if phase != "street" or crashed:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for w in WHEELS:
			if (_amb_xform() * w).distance_to(e.position) < 48:
				_blowout(w.x)
				return


## A popped tire: skid, flip, roll... and call in the helicopter.
func _blowout(wheel_x: float) -> void:
	crashed = true
	popped = wheel_x
	drive_tw.kill()
	street_tw.kill()
	(ui.get_node("Banner") as Label).text = "OH NO! The tire blew!"
	Game.sfx("tirepop", 0.0)
	Game.voice("medic_crash")
	var dir := 1.0 if wheel_x > 0 else -1.0
	var tw := create_tween()
	# skid
	tw.tween_callback(func(): Game.sfx("skid", 0.0))
	tw.tween_property(self, "amb_x", amb_x + 150, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "amb_rot", 0.18 * dir, 0.8)
	# flip and roll
	tw.tween_callback(func():
		Game.sfx("crash", 0.0)
		(ui.get_node("Banner") as Label).text = "OH NO! The ambulance is ROLLING!")
	tw.tween_property(self, "amb_rot", TAU * 1.5 + 0.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "amb_x", minf(amb_x + 520, 1000.0), 1.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(k: float): amb_dy = -absf(sin(k * PI * 3.0)) * 120.0 * (1.0 - k) + k * 30.0, 0.0, 1.0, 1.6)
	tw.tween_callback(func():
		Game.sfx("crash", 0.0, -4)
		Game.sfx("thud", 0.0))
	tw.tween_interval(1.0)
	tw.tween_callback(_call_helicopter)
	get_tree().create_timer(1.2).timeout.connect(func(): Game.sfx("crash", 0.1, -6))
	get_tree().create_timer(1.8).timeout.connect(func(): Game.sfx("crash", 0.1, -8))


func _call_helicopter() -> void:
	heli_on = true
	(ui.get_node("Banner") as Label).text = "Calling AIR RESCUE!"
	Game.sfx("rotor", 0.0)
	var wreck_x := amb_x - 40
	var tw := create_tween()
	tw.tween_property(self, "heli_x", wreck_x, 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		Game.sfx("rotor", 0.0)
		_say(amb_anchor, "pilot", Vector2(0, -60)))
	tw.tween_property(self, "rope", 1.0, 1.2)
	tw.tween_callback(func(): carrying = true)
	tw.tween_interval(0.4)
	tw.tween_property(self, "rope", 0.0, 1.4)
	tw.tween_callback(func():
		Game.sfx("rotor", 0.0)
		(ui.get_node("Banner") as Label).text = "Off to ANOTHER hospital!")
	tw.tween_property(self, "heli_x", 1700.0, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_to_room)


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
		"kitchen", "backyard", "snow_park", "game_room", "living_room", "treehouse":
			bro.bandage = 1
		"bedroom":
			bro.bandage = 2
	if Game.hospital_serious:
		bro.bandage = 1
		bro.set_mood("hurt")
	if crashed:
		bro.bandage = maxi(bro.bandage, 1)
		bro.hair_up = 0.6
	add_child(bro)
	add_child(FX.Layer.new(_draw_blanket, 3))
	get_tree().create_timer(1.4).timeout.connect(func(): _say(doc_anchor, "doctor_serious" if Game.hospital_serious else ("doctor_twice" if crashed else "doctor_ok"), Vector2(40, -90)))
	get_tree().create_timer(5.0).timeout.connect(func():
		bro.set_mood("angry")
		bro.say("hosp_serious" if Game.hospital_serious else "hosp_bro"))
	get_tree().create_timer(2.0).timeout.connect(_show_panel)


func _show_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(270, 560)
	panel.custom_minimum_size = Vector2(740, 0)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var cause := Game.hospital_cause + (" + an ambulance crash" if crashed else "")
	var d := Game.make_label("Diagnosis: " + cause, 24, Color("#ff9a9a"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(700, 0)  # wrap width known up front, so the height is right
	v.add_child(d)
	var c := Game.make_label("Hospital trips discovered: %d / 10" % Game.injury_count(), 22, Color("#ffde3b"))
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
	# grow upward from the bottom edge so long diagnoses never push the buttons off-screen
	panel.modulate.a = 0.0
	await get_tree().process_frame
	panel.reset_size()
	panel.position.y = 712.0 - panel.size.y
	panel.modulate.a = 1.0


func _process(dt: float) -> void:
	t += dt
	amb_anchor.position = Vector2(heli_x, 260) if heli_on else Vector2(amb_x + 40, 420)
	if crashed and phase == "street":
		smoke_t -= dt
		if smoke_t <= 0:
			smoke_t = 0.12
			add_child(FX.Burst.new(Vector2(amb_x - 40, 470 + amb_dy), 3, [Color(0.4, 0.4, 0.45, 0.6), Color(0.6, 0.6, 0.65, 0.5)], 90, 22, -60, 1.6, 0.8))
	if phase == "room":
		beep_t -= dt
		if beep_t <= 0:
			beep_t = 0.45 if Game.hospital_serious else 0.9
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
	# ambulance (drawn in its own rotating frame so it can skid and roll)
	var a := Vector2.ZERO
	var bounce := sin(t * 30) * 2 if amb_x < 630 and not crashed else 0.0
	draw_set_transform_matrix(Transform2D(0, Vector2(0, bounce)) * _amb_xform())
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
	for w in WHEELS:
		if crashed and w.x == popped:
			draw_colored_polygon(FX.ellipse(a + w + Vector2(0, 12), 34, 14), Color("#222"))
		else:
			draw_circle(a + w, 30, Color("#222"))
			draw_circle(a + w, 12, Color("#bbb"))
			if not crashed and phase == "street":
				draw_arc(a + w, 38 + sin(t * 6) * 3, 0, TAU, 24, Color(1, 0.9, 0.3, 0.35), 3)
	if crashed and absf(amb_rot) > 1.0:
		for k in 3:
			draw_line(a + Vector2(-150 + k * 110, -150), a + Vector2(-110 + k * 110, -90), Color("#555"), 3)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if heli_on:
		_draw_heli()
	# speed lines
	if amb_x < 600 and not crashed:
		for i in 5:
			draw_line(a + Vector2(-230 - i * 20, -150 + i * 25), a + Vector2(-330 - i * 30, -150 + i * 25), Color(1, 1, 1, 0.7), 4)


func _draw_heli() -> void:
	var h := Vector2(heli_x, 170 + sin(t * 3) * 6)
	# rope + stretcher
	var ground_y := 520.0
	var sy := lerpf(h.y + 60, ground_y, rope)
	if rope > 0.01 or carrying:
		draw_line(h + Vector2(-20, 40), Vector2(h.x - 40, sy), Color("#333"), 3)
		draw_line(h + Vector2(20, 40), Vector2(h.x + 40, sy), Color("#333"), 3)
		FX.rounded_rect(self, Rect2(Vector2(h.x - 70, sy), Vector2(140, 26)), Color("#f4f4f4"), 6, Color("#e8303a"), 3)
		if carrying:
			Bro.draw_head(self, Vector2(h.x - 46, sy - 4), 18, "ko", Vector2.ZERO, false, 0.0, {"t": t, "bandage": 1})
			draw_rect(Rect2(Vector2(h.x - 28, sy - 6), Vector2(90, 14)), Color("#5a8ad6"))
	# body
	draw_line(h + Vector2(60, -10), h + Vector2(200, -24), Color("#d8303a"), 18)
	draw_circle(h + Vector2(200, -24), 10, Color("#d8303a"))
	var tr := sin(t * 60) * 22
	draw_line(h + Vector2(200, -24 - tr), h + Vector2(200, -24 + tr), Color("#222"), 4)
	draw_colored_polygon(FX.ellipse(h, 90, 48), Color("#e8303a"))
	draw_colored_polygon(FX.ellipse(h + Vector2(-40, -6), 40, 30), Color("#9fd0f0"))
	draw_rect(Rect2(h + Vector2(-6, -16), Vector2(12, 34)), Color.WHITE)
	draw_rect(Rect2(h + Vector2(-17, -5), Vector2(34, 12)), Color.WHITE)
	draw_line(h + Vector2(-70, 60), h + Vector2(70, 60), Color("#444"), 5)
	draw_line(h + Vector2(-40, 44), h + Vector2(-40, 60), Color("#444"), 4)
	draw_line(h + Vector2(40, 44), h + Vector2(40, 60), Color("#444"), 4)
	# spinning main rotor
	draw_line(h + Vector2(0, -48), h + Vector2(0, -60), Color("#333"), 6)
	var rl := absf(sin(t * 25)) * 150 + 30
	draw_line(h + Vector2(-rl, -60), h + Vector2(rl, -60), Color("#222"), 6)
	draw_line(h + Vector2(-180, -60), h + Vector2(180, -60), Color(0.2, 0.2, 0.2, 0.15), 10)


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
	if crashed:
		FX.rounded_rect(self, Rect2(40, 40, 330, 70), Color("#e8303a"), 10)
		draw_string(ThemeDB.fallback_font, Vector2(60, 90), "HOSPITAL #2", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
	# heart monitor
	FX.rounded_rect(self, Rect2(880, 260, 220, 150), Color("#222"), 10)
	draw_rect(Rect2(892, 272, 196, 110), Color("#082010"))
	var pts := PackedVector2Array()
	for i in 50:
		var x := i * 4.0
		var ph := fmod(x / 196.0 * 2.0 + t * (2.4 if Game.hospital_serious else 1.1), 1.0)
		var y := 0.0
		if ph > 0.45 and ph < 0.5:
			y = -40 * sin((ph - 0.45) / 0.05 * PI)
		elif ph > 0.5 and ph < 0.53:
			y = 15
		pts.append(Vector2(892 + x, 330 + y))
	draw_polyline(pts, Color("#40ff70"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(900, 402), "HR 140" if Game.hospital_serious else "HR 72", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
		Color("#ff5050") if Game.hospital_serious else Color("#40ff70"))
	if Game.hospital_serious:
		# IV drip
		draw_line(Vector2(440, 620), Vector2(440, 250), Color("#888"), 5)
		draw_line(Vector2(410, 250), Vector2(470, 250), Color("#888"), 5)
		FX.rounded_rect(self, Rect2(425, 255, 34, 56), Color(0.8, 0.9, 1, 0.85), 8, Color("#9ab"), 2)
		draw_line(Vector2(442, 311), Vector2(640, 470), Color(0.7, 0.8, 0.9), 2)
		FX.rounded_rect(self, Rect2(40, 120 if crashed else 40, 400, 70), Color("#c01020"), 10)
		draw_string(ThemeDB.fallback_font, Vector2(60, 170 if crashed else 90), "INTENSIVE CARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
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


## Test hook: 1 = blow a tire right away.
func debug_state(n: int) -> void:
	if n == 2:
		Game.hospital_serious = true
	if n == 1:
		_blowout(WHEELS[1].x)


func _exit_tree() -> void:
	Game.hospital_serious = false
