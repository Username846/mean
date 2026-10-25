extends Node2D
## Shown once every location has a star.

const Bro = preload("res://scripts/bro.gd")
const FX = preload("res://scripts/fx.gd")

var bro: Bro
var t := 0.0
var conf_t := 0.0


func _ready() -> void:
	Game.seen_ending = true
	Game.save_game()
	Game.play_music("victory")
	bro = Bro.new()
	bro.position = Vector2(640, 640)
	bro.scale = Vector2(1.2, 1.2)
	bro.red = 1.0
	bro.set_mood("angry")
	bro.pie = 0.4
	bro.wet = 0.5
	bro.snow = 0.4
	bro.hair_up = 0.6
	add_child(bro)
	var title := Game.make_label("ALL 10 STARS!", 72, Color("#ffde3b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 90)
	title.position = Vector2(0, 30)
	add_child(title)
	var sub := Game.make_label("Total mean points: %d  -  Rank: %s" % [Game.total_mean, Game.rank_title()], 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 116)
	add_child(sub)
	var back := Button.new()
	back.text = "Back to the map"
	back.position = Vector2(540, 650)
	back.pressed.connect(func(): Game.goto("menu"))
	add_child(back)
	get_tree().create_timer(1.2).timeout.connect(func():
		bro.set_mood("sad")
		bro.red = 0.3
		bro.say("truce"))
	get_tree().create_timer(6.5).timeout.connect(func():
		bro.set_mood("happy")
		bro.red = 0.0
		bro.arm_r = 2.5
		bro.arm_l = 2.5
		Game.voice("ending")
		var thanks := Game.make_label("Thanks for playing!  (He's still your brother.)", 30, Color("#ffb3e6"))
		thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		thanks.size = Vector2(1280, 40)
		thanks.position = Vector2(0, 170)
		add_child(thanks))


func _process(dt: float) -> void:
	t += dt
	conf_t -= dt
	if conf_t <= 0:
		conf_t = 0.5
		add_child(FX.Burst.new(Vector2(randf_range(100, 1180), randf_range(200, 400)), 40,
			[Color("#ff5a4f"), Color("#ffde3b"), Color("#5ad1ff"), Color("#7dff6a"), Color("#ff6df0")], 500, 7, 600, 2.0))
	queue_redraw()


func _draw() -> void:
	var top := Color("#3b2463")
	var bot := Color("#ff7b39")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([top, top, bot, bot]))
	for i in 24:
		var a0 := TAU * i / 24.0 + t * 0.15
		var c := Vector2(640, 420)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 1400, c + Vector2.from_angle(a0 + TAU / 48) * 1400]),
			Color(1, 1, 1, 0.06))
	draw_rect(Rect2(0, 640, 1280, 80), Color("#2a1846"))
