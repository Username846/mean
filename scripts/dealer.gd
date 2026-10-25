extends Node2D
## Night-time cutscene: you sneak out and buy the Mega Blaster 9000 (a foam
## dart blaster) from a shady dealer under a streetlight.

const Bro = preload("res://scripts/bro.gd")
const FX = preload("res://scripts/fx.gd")
const FLOOR := 640.0
const DEALER := Vector2(850, FLOOR)

var t := 0.0
var kid: Bro
var dealer_anchor: Node2D
var coat := 0.0              ## 0 closed .. 1 open
var prize := 0.0             ## blaster travelling from the coat to you
var shine := 0.0
var ui: CanvasLayer
var done := false


func _ready() -> void:
	Game.play_music("night")
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var skip := Button.new()
	skip.text = "Skip >"
	skip.position = Vector2(1150, 16)
	skip.pressed.connect(_got_it)
	ui.add_child(skip)
	dealer_anchor = Node2D.new()
	dealer_anchor.position = DEALER + Vector2(0, -250)
	add_child(dealer_anchor)
	kid = Bro.new()
	kid.position = Vector2(-120, FLOOR)
	kid.scale = Vector2(0.75, 0.75)
	kid.shirt_col = Color("#ff8a1c")
	kid.cap_col = Color("#e8303a")
	kid.look_at_mouse = false
	kid.look = Vector2(1, 0)
	kid.set_mood("angry")
	add_child(kid)
	var tw := create_tween()
	tw.tween_property(kid, "position:x", 600.0, 3.0)
	tw.tween_callback(func(): _dealer_says("dealer_1"))
	tw.tween_interval(3.4)
	tw.tween_callback(func(): kid.say("kid_buy"))
	tw.tween_interval(3.2)
	tw.tween_callback(func():
		Game.sfx("rustle", 0.0)
		create_tween().tween_property(self, "coat", 1.0, 0.5)
		_dealer_says("dealer_2"))
	tw.tween_interval(4.6)
	tw.tween_callback(func():
		kid.set_mood("smug")
		kid.say("kid_deal"))
	tw.tween_interval(2.6)
	tw.tween_property(self, "prize", 1.0, 0.6)
	tw.tween_callback(_got_it)


func _dealer_says(id: String) -> void:
	var info := Game.voice(id)
	add_child(FX.Bubble.new(dealer_anchor, info[1], info[2], Vector2(0, -60), Color("#e8e8f0")))


func _got_it() -> void:
	if done:
		return
	done = true
	Game.has_blaster = true
	Game.seen_revenge = true
	Game.save_game()
	prize = 1.0
	kid.arm_l = 2.9
	kid.arm_r = 2.9
	kid.elbow_l = 0.4
	kid.elbow_r = 0.4
	kid.set_mood("happy")
	Game.sfx("itemget", 0.0)
	Game.voice("got_blaster")
	create_tween().tween_property(self, "shine", 1.0, 0.5)
	for c in ui.get_children():
		c.queue_free()
	var panel := PanelContainer.new()
	panel.position = Vector2(290, 40)
	panel.custom_minimum_size = Vector2(700, 0)
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var l := Game.make_label("You got the MEGA BLASTER 9000!", 38, Color("#ffde3b"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var l2 := Game.make_label("Tap the blaster button (bottom-right) in any location to equip it.", 22)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(660, 0)
	v.add_child(l2)
	var b := Button.new()
	b.text = "Back to the map"
	b.pressed.connect(func():
		Game.sfx("click")
		Game.goto("menu"))
	v.add_child(b)


func _process(dt: float) -> void:
	t += dt
	if kid.position.x < 590:
		kid.position.y = FLOOR - absf(sin(t * 7)) * 6
	queue_redraw()


func _draw() -> void:
	var top := Color("#05061a")
	var bot := Color("#1a1440")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, FLOOR), Vector2(0, FLOOR)]),
		PackedColorArray([top, top, bot, bot]))
	draw_circle(Vector2(1100, 100), 46, Color("#fff4c4"))
	draw_circle(Vector2(1084, 90), 44, Color("#05061a"))
	for i in 40:
		draw_circle(Vector2(fmod(i * 191.0, 1280), fmod(i * 73.0, 300)), 1.5, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 2 + i)))
	# buildings
	for b in [[0, 220, 260], [250, 300, 200], [470, 180, 240], [1000, 260, 300]]:
		draw_rect(Rect2(b[0], FLOOR - b[1] - 200, b[2], b[1] + 200), Color("#151230"))
		for wy in range(int(FLOOR - b[1] - 170), int(FLOOR - 40), 60):
			for wx in range(int(b[0] + 20), int(b[0] + b[2] - 30), 50):
				if (wx + wy) % 3 == 0:
					draw_rect(Rect2(wx, wy, 24, 30), Color("#ffd870"))
	# street
	draw_rect(Rect2(0, FLOOR, 1280, 80), Color("#2a2a35"))
	draw_rect(Rect2(0, FLOOR, 1280, 10), Color("#4a4a58"))
	# streetlamp + light cone
	var flicker := 0.85 + 0.15 * sin(t * 37) * sin(t * 13)
	draw_colored_polygon(PackedVector2Array([Vector2(760, 150), Vector2(620, FLOOR + 20), Vector2(1000, FLOOR + 20)]), Color(1, 0.85, 0.4, 0.13 * flicker))
	draw_line(Vector2(780, FLOOR), Vector2(780, 140), Color("#333"), 10)
	draw_line(Vector2(780, 140), Vector2(740, 140), Color("#333"), 8)
	draw_circle(Vector2(745, 152), 16, Color(1, 0.9, 0.5, flicker))
	# dealer: trench coat, hat, sunglasses
	var d := DEALER
	var coat_pts_l := PackedVector2Array([d + Vector2(-60, -200), d + Vector2(0, -200), d + Vector2(-10 - coat * 80, 0), d + Vector2(-80 - coat * 30, 0)])
	var coat_pts_r := PackedVector2Array([d + Vector2(0, -200), d + Vector2(60, -200), d + Vector2(80 + coat * 30, 0), d + Vector2(10 + coat * 80, 0)])
	if coat > 0.05:
		draw_rect(Rect2(d + Vector2(-60, -200), Vector2(120, 200)), Color("#3a2a5a"))
		for k in 4:
			FX.draw_blaster(self, d + Vector2(-26 + (k % 2) * 52, -160 + (k / 2) * 80), 0.45, 0.2 * (k % 2 * 2 - 1))
	draw_colored_polygon(coat_pts_l, Color("#8a6a3a"))
	draw_colored_polygon(coat_pts_r, Color("#7a5a2a"))
	draw_circle(d + Vector2(0, -230), 34, Color("#c99a7a"))
	draw_rect(Rect2(d + Vector2(-30, -240), Vector2(60, 14)), Color("#111"))
	draw_rect(Rect2(d + Vector2(-52, -262), Vector2(104, 10)), Color("#2a2030"))
	draw_rect(Rect2(d + Vector2(-34, -296), Vector2(68, 36)), Color("#2a2030"))
	draw_line(d + Vector2(-14, -206), d + Vector2(12, -210), Color("#3a1a10"), 4)
	# the prize
	if prize > 0.0:
		var p := (d + Vector2(0, -140)).lerp(kid.position + Vector2(40, -110), prize)
		if shine > 0.0:
			p = kid.position + Vector2(0, -290)   # held up overhead
			for k in 12:
				var a := t + k * TAU / 12
				draw_line(p, p + Vector2.from_angle(a) * 160 * shine, Color(1, 0.9, 0.3, 0.35), 8)
		FX.draw_blaster(self, p, 0.9 + shine * 0.5)
