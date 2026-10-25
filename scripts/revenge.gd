extends Node2D
## After every hospital trip has been found: Bro gets his revenge and trashes
## your room, then you walk in on the wreckage. Leads into the night-time
## pistol purchase (dealer.gd).

const Bro = preload("res://scripts/bro.gd")
const FX = preload("res://scripts/fx.gd")
const FLOOR := 650.0

var t := 0.0
var bro: Bro
var kid: Bro
var broken := {}
var bricks: Array = []
var shake := 0.0
var ui: CanvasLayer


func _ready() -> void:
	Game.play_music("revenge")
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var skip := Button.new()
	skip.text = "Skip >"
	skip.position = Vector2(1150, 16)
	skip.pressed.connect(func(): Game.goto("dealer"))
	ui.add_child(skip)
	bro = Bro.new()
	bro.position = Vector2(1400, FLOOR)
	bro.red = 1.0
	bro.set_mood("angry")
	bro.look_at_mouse = false
	add_child(bro)
	kid = Bro.new()
	kid.position = Vector2(1450, FLOOR)
	kid.scale = Vector2(0.75, 0.75)
	kid.shirt_col = Color("#ff8a1c")
	kid.cap_col = Color("#e8303a")
	kid.look_at_mouse = false
	add_child(kid)
	var tw := create_tween()
	tw.tween_property(bro, "position:x", 700.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		Game.sfx("thud", 0.0)
		shake = 8.0
		bro.say("rev_1"))
	tw.tween_interval(2.8)
	tw.tween_callback(func():
		bro.hop(60)
		bro.say("rev_2"))
	tw.tween_interval(2.0)
	for target in [["poster", 250.0, "rip"], ["bed", 300.0, "thud"], ["tv", 800.0, "crash"],
			["trophy", 1060.0, "clang"], ["castle", 1050.0, "crash"]]:
		tw.tween_property(bro, "position:x", target[1], 0.35)
		tw.tween_callback(_smash.bind(target[0], target[2]))
		tw.tween_interval(0.75)
	tw.tween_property(bro, "position:x", 560.0, 0.4)
	tw.tween_callback(func():
		bro.set_mood("smug")
		bro.say("rev_3"))
	tw.tween_interval(2.4)
	tw.tween_property(kid, "position:x", 1100.0, 0.8)
	tw.tween_callback(func():
		kid.set_mood("scared")
		kid.look = Vector2(-1, 0.3)
		kid.say("kid_room"))
	tw.tween_interval(2.6)
	tw.tween_callback(_finish)


func _smash(what: String, snd: String) -> void:
	broken[what] = true
	bro.hop(50)
	bro.flail(0.6)
	Game.sfx(snd, 0.1)
	Game.sfx("thud", 0.1, -6)
	shake = 12.0
	var at := {"poster": Vector2(250, 220), "bed": Vector2(240, 560), "tv": Vector2(800, 420),
		"trophy": Vector2(1080, 210), "castle": Vector2(1050, 600)}[what] as Vector2
	burst(at, 24, [Color("#ffde3b"), Color.WHITE, Color("#8a5a3c")], 450, 6)
	if what == "castle":
		for i in 40:
			bricks.append({"p": at + Vector2(randf_range(-30, 30), randf_range(-40, 0)),
				"v": Vector2(randf_range(-420, 420), randf_range(-620, -150)),
				"c": [Color("#e8303a"), Color("#2f7fe0"), Color("#ffde3b"), Color("#3bb04a")].pick_random(),
				"r": randf() * TAU})


func burst(at: Vector2, n: int, cols: Array, spd: float, size: float) -> void:
	add_child(FX.Burst.new(at, n, cols, spd, size, 900, 1.0))


func _finish() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 40)
	panel.custom_minimum_size = Vector2(500, 0)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var l := Game.make_label("Your room is DESTROYED.\nYour LEGO castle is GONE.", 30, Color("#ff8a8a"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var l2 := Game.make_label("Payback time...", 26, Color("#ffde3b"))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var b := Button.new()
	b.text = "Continue"
	b.pressed.connect(func():
		Game.sfx("click")
		Game.goto("dealer"))
	v.add_child(b)


func _process(dt: float) -> void:
	t += dt
	shake = maxf(0.0, shake - dt * 30.0)
	position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	for b in bricks:
		b.v.y += 1400 * dt
		b.p += b.v * dt
		b.r += dt * 8
		if b.p.y > FLOOR + 30:
			b.p.y = FLOOR + 30
			b.v = Vector2(b.v.x * 0.5, -b.v.y * 0.25)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-20, -20, 1320, 760), Color("#5a6ac8"))
	for i in 34:
		draw_rect(Rect2(i * 40, -20, 4, 690), Color("#5262bc"))
	draw_rect(Rect2(-20, FLOOR - 10, 1320, 120), Color("#a87444"))
	# door (right)
	draw_rect(Rect2(1170, 260, 120, 400), Color("#3a2416"))
	# poster
	if broken.has("poster"):
		draw_colored_polygon(PackedVector2Array([Vector2(160, 120), Vector2(240, 120), Vector2(220, 260), Vector2(160, 300)]), Color("#1a2050"))
		draw_colored_polygon(PackedVector2Array([Vector2(260, 140), Vector2(340, 120), Vector2(340, 360), Vector2(280, 330)]), Color("#1a2050"))
	else:
		FX.rounded_rect(self, Rect2(160, 120, 180, 240), Color("#1a2050"), 4)
		draw_circle(Vector2(250, 220), 40, Color("#ffde3b"))
		draw_string(ThemeDB.fallback_font, Vector2(185, 330), "SPACE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	# bed
	if broken.has("bed"):
		draw_set_transform(Vector2(240, 560), PI + 0.15, Vector2.ONE)
	else:
		draw_set_transform(Vector2(240, 560), 0, Vector2.ONE)
	FX.rounded_rect(self, Rect2(-180, -50, 360, 70), Color("#3bb0ff"), 10)
	FX.rounded_rect(self, Rect2(-180, -40, 90, 40), Color.WHITE, 12)
	draw_rect(Rect2(-180, 20, 20, 60), Color("#6b4428"))
	draw_rect(Rect2(160, 20, 20, 60), Color("#6b4428"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# desk + TV + console
	draw_rect(Rect2(690, 500, 230, 20), Color("#6b4428"))
	draw_rect(Rect2(700, 520, 14, 130), Color("#6b4428"))
	draw_rect(Rect2(896, 520, 14, 130), Color("#6b4428"))
	FX.rounded_rect(self, Rect2(720, 360, 170, 120), Color("#222"), 8)
	draw_rect(Rect2(730, 370, 150, 100), Color("#4a90e0") if not broken.has("tv") else Color("#111"))
	if broken.has("tv"):
		for k in 6:
			draw_line(Vector2(800, 420), Vector2(800, 420) + Vector2.from_angle(k * 1.1) * 70, Color("#ccc"), 2)
		draw_rect(Rect2(750, 600, 60, 30), Color("#ddd"))
	else:
		draw_rect(Rect2(760, 480, 60, 20), Color("#ddd"))
	# shelf + trophy
	draw_rect(Rect2(980, 250, 200, 14), Color("#6b4428"))
	if broken.has("trophy"):
		draw_colored_polygon(FX.ellipse(Vector2(1000, 640), 26, 10), Color("#e0b030"))
		draw_rect(Rect2(1030, 630, 30, 14), Color("#e0b030"))
	else:
		draw_rect(Rect2(1065, 200, 30, 50), Color("#e0b030"))
		draw_circle(Vector2(1080, 190), 26, Color("#ffd040"))
	# LEGO castle
	if not broken.has("castle"):
		var cols := [Color("#e8303a"), Color("#2f7fe0"), Color("#ffde3b"), Color("#3bb04a")]
		for row in 5:
			for col in 6:
				draw_rect(Rect2(980 + col * 24, 620 - row * 20, 22, 18), cols[(row + col) % 4])
		for k in 3:
			draw_rect(Rect2(980 + k * 60, 500, 22, 20), cols[k])
	for b in bricks:
		draw_set_transform(b.p, b.r, Vector2.ONE)
		draw_rect(Rect2(-11, -9, 22, 18), b.c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
