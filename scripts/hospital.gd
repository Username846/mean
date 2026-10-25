extends Node2D
## "Oh no!" cutscene after a serious accident: the ambulance races to the
## hospital, then Bro recovers in bed (bandaged up) while the doctor scolds you.
## Tap an ambulance wheel on the way and it blows out, rolls, and a rescue
## helicopter has to fly him to another hospital instead.
##
## After the gunshot (Game.hospital_serious) he doesn't make it: the family
## waits outside surgery, the doctor comes out with the news, and the scene
## ends at his grave.

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
var family: Array[Bro] = []  ## dad, mom, you (the gunshot ending)
var story_tw: Tween
var doors := 0.0             ## surgery doors: 0 shut .. 1 swung open
var doc_x := 1050.0
var surgery_on := true
var light := 1.0             ## waiting-room fluorescent tube (dips when it flickers)
var flick_t := 1.0
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
	if Game.hospital_serious:
		_fade_to(_enter_waiting, 1.0)
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	tw.tween_callback(_enter_room)
	tw.tween_property(fade, "color:a", 0.0, 0.6)


## Fade through black into the next part of the story.
func _fade_to(next: Callable, dur := 1.6) -> void:
	fade.color = Color(0, 0, 0, fade.color.a)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, dur)
	tw.tween_callback(next)
	tw.tween_property(fade, "color:a", 0.0, dur)


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
	add_child(FX.Bubble.new(anchor, info[1], info[2], off, Color("#e8f6ff"), info[3]))


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
	if crashed:
		bro.bandage = maxi(bro.bandage, 1)
		bro.hair_up = 0.6
	add_child(bro)
	add_child(FX.Layer.new(_draw_blanket, 3))
	get_tree().create_timer(1.4).timeout.connect(func(): _say(doc_anchor, "doctor_twice" if crashed else "doctor_ok", Vector2(40, -90)))
	get_tree().create_timer(5.0).timeout.connect(func():
		bro.set_mood("angry")
		bro.say("hosp_bro"))
	get_tree().create_timer(2.0).timeout.connect(_show_panel)


# ------------------------------------------------- the gunshot: he doesn't make it

func _make_person(pos: Vector2, sc: float, shirt: Color, sit: bool, role: String) -> Bro:
	var p := Bro.new()
	p.position = pos
	p.scale = Vector2(sc, sc)
	p.shirt_col = shirt
	p.sitting = sit
	p.look_at_mouse = false
	p.look = Vector2(0.8, 0)
	add_child(p)
	family.append(p)
	match role:
		"mom":  # long hair, drawn behind her head
			var hair := FX.Layer.new(func(ci): ci.draw_colored_polygon(
				FX.ellipse(Vector2(0, _head_y(p) + 22), 60, 76), Bro.HAIR.darkened(0.25)))
			hair.show_behind_parent = true
			p.add_child(hair)
		"dad":
			p.add_child(FX.Layer.new(func(ci):
				for s: int in [-1, 1]:
					ci.draw_colored_polygon(FX.ellipse(Vector2(s * 11, _head_y(p) + 15), 14, 6), Bro.HAIR.darkened(0.3))))
	return p


## Local y of a puppet's head centre (matches bro.gd's breathing).
static func _head_y(p: Bro) -> float:
	return -240.0 + (60.0 if p.sitting else 0.0) - (sin(p.t * 2.2) * 3.0 if p.bob else 0.0)


## Where a puppet's hand is (mirrors the arm maths in bro.gd, ignoring breathing).
static func _hand(p: Bro, s: int) -> Vector2:
	var ang: float = p.arm_l if s < 0 else p.arm_r
	var el: float = p.elbow_l if s < 0 else p.elbow_r
	var shoulder := Vector2(s * 44, -166 + (60.0 if p.sitting else 0.0))
	var d1 := Vector2(sin(ang) * s, cos(ang))
	return p.to_global(shoulder + d1 * 48 + d1.rotated(-el * s) * 44)


func _caption(text: String, delay: float, hold := 3.0) -> void:
	var l := Game.make_label(text, 34, Color("#c8d0d8"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1280, 50)
	l.position = Vector2(0, 90)
	l.modulate.a = 0.0
	ui.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 1.0)
	tw.tween_interval(hold)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


## Part 1: the family waits outside surgery under a flickering light.
func _enter_waiting() -> void:
	phase = "waiting"
	ui.get_node("Banner").queue_free()
	Game.play_music("waiting")
	var skip := Button.new()
	skip.text = "Skip >"
	skip.name = "Skip"
	skip.position = Vector2(1150, 16)
	skip.pressed.connect(_skip_to_grave)
	ui.add_child(skip)
	var dad := _make_person(Vector2(430, 640), 1.05, Color("#4a5d78"), true, "dad")
	var mom := _make_person(Vector2(560, 640), 0.95, Color("#a0466a"), true, "mom")
	var you := _make_person(Vector2(690, 640), 0.75, Color("#ff8a1c"), true, "you")
	you.cap_col = Color("#e8303a")
	dad.set_mood("sad")
	mom.set_mood("sad")
	you.set_mood("scared")
	you.look = Vector2(0, 0.5)
	add_child(FX.Layer.new(_draw_over, 5))
	_caption("Hours pass...", 1.5)
	story_tw = create_tween()
	story_tw.tween_interval(5.5)
	story_tw.tween_callback(func(): _say(mom, "mom_please", Vector2(0, -250)))
	story_tw.tween_interval(5.0)
	story_tw.tween_callback(func():
		surgery_on = false
		Game.stop_music()
		Game.sfx("click", 0.0)
		for p in family:
			p.look = Vector2(1, -0.2)
			p.set_mood("scared"))
	story_tw.tween_interval(1.8)
	story_tw.tween_callback(_doctor_comes_out)


## Part 2: the doors swing open and the surgeon walks over.
func _doctor_comes_out() -> void:
	phase = "news"
	Game.sfx("thud", 0.0, -8, 0.7)
	story_tw = create_tween()
	story_tw.tween_property(self, "doors", 1.0, 0.9).set_ease(Tween.EASE_OUT)
	story_tw.tween_interval(0.8)
	story_tw.tween_callback(func():
		for p in family:
			p.sitting = false)
	story_tw.tween_property(self, "doc_x", 850.0, 2.8)
	story_tw.tween_interval(1.4)
	story_tw.tween_callback(func(): _say(doc_anchor, "doctor_sorry", Vector2(0, -40)))
	story_tw.tween_interval(2.6)
	story_tw.tween_callback(func():
		var mom: Bro = family[1]
		mom.sitting = true
		Game.sfx("thud", 0.0, -10, 0.8)
		for p in family:
			p.set_mood("sad")
			p.look = Vector2(0, 0.6))
	story_tw.tween_interval(5.0)
	story_tw.tween_callback(func(): _fade_to(_enter_grave, 2.0))


func _skip_to_grave() -> void:
	Game.sfx("click")
	if story_tw:
		story_tw.kill()
	_fade_to(_enter_grave, 0.4)


## Part 3: the graveyard, in the rain.
func _enter_grave() -> void:
	if phase == "grave":
		return
	phase = "grave"
	if ui.has_node("Skip"):
		ui.get_node("Skip").queue_free()
	for p in family:
		p.queue_free()
	family.clear()
	Game.play_music("grave")
	var dad := _make_person(Vector2(300, 612), 1.05, Color("#24262c"), false, "dad")
	var mom := _make_person(Vector2(430, 612), 0.95, Color("#2c2329"), false, "mom")
	var you := _make_person(Vector2(590, 622), 0.75, Color("#2b2e38"), false, "you")
	dad.bob = false  # holds the umbrella steady
	dad.arm_r = 2.6
	dad.elbow_r = 0.6
	for p in family:
		p.set_mood("sad")
		p.look = Vector2(0.7, 0.4)
	story_tw = create_tween()
	story_tw.tween_interval(4.0)
	story_tw.tween_callback(func(): you.say("kid_sorry"))
	story_tw.tween_interval(4.0)
	story_tw.tween_callback(_show_panel)


func _show_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(270, 560)
	panel.custom_minimum_size = Vector2(740, 0)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var cause := Game.hospital_cause + (" + an ambulance crash" if crashed else "")
	var d := Game.make_label(("Cause of death: " if Game.hospital_serious else "Diagnosis: ") + cause, 24, Color("#ff9a9a"))
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
	# (at the grave it sits up in the sky, clear of the family)
	panel.modulate.a = 0.0
	await get_tree().process_frame
	panel.reset_size()
	panel.position.y = 16.0 if phase == "grave" else 712.0 - panel.size.y
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
			beep_t = 0.9
			Game.sfx("beep", 0.0, -12)
	if phase in ["waiting", "news"]:
		doc_anchor.position = Vector2(doc_x, 300)
		flick_t -= dt
		if flick_t <= 0.0:
			if light < 1.0:
				light = 1.0
				flick_t = randf_range(0.5, 3.0)
			else:
				light = randf_range(0.15, 0.6)
				flick_t = randf_range(0.04, 0.2)
	queue_redraw()


func _draw() -> void:
	match phase:
		"street":
			_draw_street()
		"room":
			_draw_room()
		"waiting", "news":
			_draw_waiting()
		"grave":
			_draw_grave()


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
	_draw_doctor(Vector2(270, 700))


## The doctor, standing at `feet`. A `surgeon` wears scrubs, a cap and a
## pulled-down mask, and frowns instead of smiling.
func _draw_doctor(feet: Vector2, sc := 1.0, surgeon := false) -> void:
	draw_set_transform(feet, 0, Vector2(sc, sc))
	var d := Vector2(0, -400)
	var coat := Color("#4f8f8a") if surgeon else Color.WHITE
	FX.rounded_rect(self, Rect2(d + Vector2(-80, 70), Vector2(160, 330)), coat, 30, coat.darkened(0.2), 3)
	draw_line(d + Vector2(0, 80), d + Vector2(0, 400), coat.darkened(0.12), 3)
	draw_rect(Rect2(d + Vector2(-14, 60), Vector2(28, 30)), Color("#c98f6a"))
	draw_circle(d, 62, Color("#c98f6a"))
	draw_arc(d + Vector2(0, -6), 64, PI * 0.9, PI * 1.1, 8, Color("#bbb"), 18)
	draw_arc(d + Vector2(0, -6), 64, -PI * 0.1, PI * 0.1, 8, Color("#bbb"), 18)
	for s: int in [-1, 1]:
		draw_arc(d + Vector2(s * 24, 0), 16, 0, TAU, 20, Color("#333"), 4)
		draw_circle(d + Vector2(s * 24, 0), 5, Color("#222"))
	draw_line(d + Vector2(-8, 0), d + Vector2(8, 0), Color("#333"), 4)
	if surgeon:
		var cap := PackedVector2Array()
		for i in 13:
			var a := lerpf(PI, TAU, i / 12.0)
			cap.append(d + Vector2(cos(a) * 66, sin(a) * 62 - 14))
		draw_colored_polygon(cap, coat)
		for s: int in [-1, 1]:
			draw_line(d + Vector2(s * 10, -26), d + Vector2(s * 38, -20), Color("#6a6a6a"), 5)  # worried brows
		draw_arc(d + Vector2(0, 46), 18, PI + 0.5, TAU - 0.5, 10, Color("#5a2010"), 5)
		FX.rounded_rect(self, Rect2(d + Vector2(-38, 50), Vector2(76, 24)), Color("#cfe6ee"), 6)
		draw_line(d + Vector2(-38, 56), d + Vector2(-60, 10), Color("#cfe6ee"), 2)
		draw_line(d + Vector2(38, 56), d + Vector2(60, 10), Color("#cfe6ee"), 2)
	else:
		draw_arc(d + Vector2(0, 26), 20, 0.3, PI - 0.3, 10, Color("#5a2010"), 5)
		draw_circle(d + Vector2(0, -50), 18, Color("#ddd"))
		draw_circle(d + Vector2(0, -50), 8, Color("#999"))
		draw_arc(d + Vector2(0, 140), 40, 0, PI, 12, Color("#333"), 5)
		draw_circle(d + Vector2(0, 180), 10, Color("#888"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_waiting() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 640), Color("#4a5754"))
	draw_rect(Rect2(0, 420, 1280, 220), Color("#3a4542"))
	draw_rect(Rect2(0, 416, 1280, 8), Color("#2c3532"))
	draw_rect(Rect2(0, 640, 1280, 80), Color("#2a2f31"))
	for i in 9:
		draw_line(Vector2(i * 160 - 40, 640), Vector2(i * 190 - 160, 720), Color("#202527"), 2)
	# fluorescent tube
	draw_rect(Rect2(330, 0, 360, 22), Color("#7a817e"))
	draw_rect(Rect2(342, 22, 336, 10), Color("#555a58").lerp(Color("#f4f8e8"), light))
	draw_colored_polygon(PackedVector2Array([Vector2(342, 32), Vector2(678, 32), Vector2(860, 640), Vector2(160, 640)]),
		Color(0.9, 1, 0.9, 0.05 * light))
	# wall clock: the minute hand crawls round as the hours go by
	var c := Vector2(170, 200)
	draw_circle(c, 54, Color("#d8d8d0"))
	draw_arc(c, 54, 0, TAU, 32, Color("#222"), 6)
	for k in 12:
		var dir := Vector2.from_angle(k * TAU / 12)
		draw_line(c + dir * 42, c + dir * 50, Color("#333"), 3)
	draw_line(c, c + Vector2.from_angle(t * 0.05 - PI / 2) * 26, Color("#222"), 6)
	draw_line(c, c + Vector2.from_angle(t * 0.6 - PI / 2) * 40, Color("#222"), 4)
	draw_line(c, c + Vector2.from_angle(floorf(t) * TAU / 60 - PI / 2) * 44, Color("#c02020"), 2)
	# a dying pot plant
	FX.rounded_rect(self, Rect2(800, 570, 60, 70), Color("#6a4a3a"), 8)
	for k in 5:
		draw_line(Vector2(830, 572), Vector2(800 + k * 15, 500 + (k % 2) * 30), Color("#5a6a3a"), 4)
	for x in [300, 430, 560, 690]:
		_draw_chair(x)
	# surgery doors + sign
	draw_rect(Rect2(920, 262, 260, 378), Color("#5c6663"))
	draw_rect(Rect2(930, 272, 240, 368), Color("#0b0f10"))
	draw_rect(Rect2(1000, 290, 100, 8), Color(0.8, 1, 0.9, 0.2 * doors))
	var w := 120.0 * (1.0 - doors * 0.82)
	for s: int in [-1, 1]:
		var r := Rect2(930, 272, w, 368) if s < 0 else Rect2(1170 - w, 272, w, 368)
		draw_rect(r, Color("#8a9692").darkened(doors * 0.35))
		draw_rect(r, Color("#3c4542"), false, 3)
		draw_rect(Rect2(r.position.x + r.size.x * 0.25, 320, r.size.x * 0.5, 90), Color("#1a2224"))
	if surgery_on:
		draw_circle(Vector2(1050, 228), 80, Color(1, 0.1, 0.1, 0.1 + 0.05 * sin(t * 3)))
	FX.rounded_rect(self, Rect2(965, 205, 170, 46), Color("#161819"), 6)
	draw_string(font, Vector2(965, 237), "IN SURGERY", HORIZONTAL_ALIGNMENT_CENTER, 170, 24,
		Color("#ff3030") if surgery_on else Color("#3a1c1c"))
	if phase == "news":
		_draw_doctor(Vector2(doc_x, 640), 0.72, true)


func _draw_chair(x: float) -> void:
	var col := Color("#2d5f7a")
	FX.rounded_rect(self, Rect2(x - 50, 470, 100, 130), col, 12)
	draw_line(Vector2(x - 40, 606), Vector2(x - 46, 690), Color("#6a6e70"), 5)
	draw_line(Vector2(x + 40, 606), Vector2(x + 46, 690), Color("#6a6e70"), 5)
	FX.rounded_rect(self, Rect2(x - 58, 596, 116, 16), col.darkened(0.2), 6)


func _draw_grave() -> void:
	var font := ThemeDB.fallback_font
	var top := Color("#3c424a")
	var bot := Color("#6c727a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 470), Vector2(0, 470)]),
		PackedColorArray([top, top, bot, bot]))
	for i in 6:
		var cx := fmod(i * 310.0 + t * 8.0, 1600.0) - 160.0
		draw_colored_polygon(FX.ellipse(Vector2(cx, 50 + (i % 3) * 45), 180, 36), Color(0.2, 0.22, 0.26, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 470), Vector2(0, 420), Vector2(260, 390), Vector2(560, 425),
		Vector2(880, 380), Vector2(1280, 415), Vector2(1280, 470)]), Color("#3a4637"))
	var g1 := Color("#34422f")
	var g2 := Color("#1c2419")
	draw_polygon(PackedVector2Array([Vector2(0, 470), Vector2(1280, 470), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([g1, g1, g2, g2]))
	# iron fence
	draw_line(Vector2(0, 450), Vector2(1280, 450), Color("#1b1d20"), 3)
	draw_line(Vector2(0, 466), Vector2(1280, 466), Color("#1b1d20"), 3)
	for x in range(10, 1280, 34):
		draw_line(Vector2(x, 436), Vector2(x, 474), Color("#1b1d20"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 438), Vector2(x, 430), Vector2(x + 4, 438)]), Color("#1b1d20"))
	# bare tree
	var tc := Color("#1e1a18")
	draw_line(Vector2(1150, 600), Vector2(1140, 300), tc, 22)
	for b in [[Vector2(1142, 380), Vector2(1060, 300)], [Vector2(1140, 330), Vector2(1220, 250)],
			[Vector2(1100, 340), Vector2(1080, 270)], [Vector2(1180, 290), Vector2(1240, 300)],
			[Vector2(1141, 310), Vector2(1130, 230)]]:
		draw_line(b[0], b[1], tc, 7)
	# other graves
	for s in [[90.0, 505.0, 0.45], [210.0, 492.0, 0.35], [520.0, 486.0, 0.3], [990.0, 498.0, 0.4], [1240.0, 515.0, 0.45]]:
		_headstone(Vector2(s[0], s[1]), s[2], Color("#5d6168"))
	# his grave
	draw_colored_polygon(FX.ellipse(Vector2(800, 618), 135, 28), Color("#3e2c20"))
	draw_colored_polygon(FX.ellipse(Vector2(800, 610), 120, 18), Color("#4e3828"))
	_headstone(Vector2(800, 596), 1.0, Color("#8d9197"))
	var ink := Color("#3a3d42")
	draw_string(font, Vector2(720, 392), "IN LOVING MEMORY", HORIZONTAL_ALIGNMENT_CENTER, 160, 13, ink)
	draw_string(font, Vector2(720, 434), "BIG BROTHER", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, ink)
	draw_string(font, Vector2(720, 474), "Beloved son", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, ink)
	draw_string(font, Vector2(720, 498), "and brother", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, ink)
	draw_string(font, Vector2(720, 548), "Gone too soon", HORIZONTAL_ALIGNMENT_CENTER, 160, 15, ink)
	for k in 6:
		var f := Vector2(712 + k * 34, 612 + (k % 2) * 8)
		draw_line(f, f + Vector2(4, -22), Color("#3f6a32"), 3)
		draw_circle(f + Vector2(4, -24), 7, [Color("#e8e8e0"), Color("#b02030"), Color("#e8e8e0")][k % 3])


func _headstone(base: Vector2, sc: float, col: Color) -> void:
	var w := 80.0 * sc
	var h := 180.0 * sc
	draw_circle(base + Vector2(0, -h), w, col)
	draw_rect(Rect2(base + Vector2(-w, -h), Vector2(w * 2, h)), col)
	draw_arc(base + Vector2(0, -h), w, PI, TAU, 24, col.darkened(0.35), 3 * sc)
	draw_line(base + Vector2(-w, -h), base + Vector2(-w, 0), col.darkened(0.35), 3 * sc)
	draw_line(base + Vector2(w, -h), base + Vector2(w, 0), col.darkened(0.35), 3 * sc)
	draw_rect(Rect2(base + Vector2(-w - 12 * sc, -6 * sc), Vector2(w * 2 + 24 * sc, 18 * sc)), col.darkened(0.25))


## Drawn over everyone: the gloom and flicker in the waiting room, the rain
## and Dad's umbrella at the grave.
func _draw_over(ci: CanvasItem) -> void:
	var full := Rect2(0, 0, 1280, 720)
	if phase == "grave":
		ci.draw_rect(full, Color(0.05, 0.07, 0.1, 0.2))
		var h := Vector2(-1000, 0)
		if family.size() > 0 and is_instance_valid(family[0]):
			h = _hand(family[0], 1)
			var tip := h + Vector2(0, -125)
			ci.draw_line(h, tip, Color("#202126"), 4)
			ci.draw_arc(h + Vector2(-7, 2), 7, 0, PI, 8, Color("#202126"), 4)
			var canopy := PackedVector2Array()
			for i in 17:
				var a := lerpf(PI, TAU, i / 16.0)
				canopy.append(tip + Vector2(cos(a) * 150, 62 + sin(a) * 62))
			for i in 6:
				canopy.append(tip + Vector2(150 - (i + 0.5) * 50, 70))
			ci.draw_colored_polygon(canopy, Color("#121318"))
		for i in 160:
			var x := fmod(i * 97.3 + t * 140.0, 1340.0) - 30.0
			var y := fmod(i * 53.7 + t * 900.0, 760.0) - 40.0
			if absf(x - h.x) < 150 and y > h.y - 125 and y < 640:
				continue
			ci.draw_line(Vector2(x, y), Vector2(x - 6, y + 24), Color(0.75, 0.8, 0.9, 0.35), 2)
		return
	if phase in ["waiting", "news"]:
		ci.draw_rect(full, Color(0.02, 0.04, 0.06, 0.25 + (1.0 - light) * 0.45))
		for k in 6:
			ci.draw_arc(Vector2(640, 360), 560 + k * 50, 0, TAU, 48, Color(0, 0, 0, 0.12 + k * 0.05), 60)


func _draw_blanket(ci: CanvasItem) -> void:
	if phase != "room":
		return
	FX.rounded_rect(ci, Rect2(470, 540, 460, 60), Color("#9aa6b8"), 10)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(480, 610), Vector2(500, 520), Vector2(700, 505), Vector2(900, 520), Vector2(920, 610)]),
		Color("#5a8ad6"))
	ci.draw_line(Vector2(500, 528), Vector2(900, 528), Color("#f4f4f4"), 14)
	ci.draw_rect(Rect2(500, 610, 20, 110), Color("#888"))
	ci.draw_rect(Rect2(880, 610, 20, 110), Color("#888"))


## Test hooks: 1 = blow a tire right away, 2 = the gunshot ending,
## 3 = jump straight to its doctor scene, 4 = straight to the grave.
func debug_state(n: int) -> void:
	if n == 2:
		Game.hospital_serious = true
	if n == 1:
		_blowout(WHEELS[1].x)
	if n >= 3:
		Game.hospital_serious = true
		street_tw.kill()
		drive_tw.kill()
		_enter_waiting()
		story_tw.kill()
		if n == 3:
			surgery_on = false
			_doctor_comes_out()
		else:
			_enter_grave()


func _exit_tree() -> void:
	Game.hospital_serious = false
