extends Node2D
## Title screen. The first click also unlocks web audio.

const Bro = preload("res://scripts/bro.gd")

var bro: Bro
var t := 0.0
var started := false
var title: Label
var prompt: Label


func _ready() -> void:
	bro = Bro.new()
	bro.position = Vector2(640, 640)
	bro.scale = Vector2(1.25, 1.25)
	bro.set_mood("smug")
	bro.arm_l = 0.1
	bro.arm_r = 2.4
	bro.elbow_r = 1.2
	add_child(bro)
	title = Game.make_label("BUG MY BROTHER!", 96, Color("#ffde3b"))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_outline_color", Color("#3b1060"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 120)
	title.position = Vector2(0, 40)
	title.pivot_offset = Vector2(640, 60)
	add_child(title)
	var sub := Game.make_label("10 places. 1 big brother. Endless revenge.", 28, Color("#ffb3e6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 160)
	add_child(sub)
	prompt = Game.make_label("Click anywhere to start!", 34)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(1280, 50)
	prompt.position = Vector2(0, 230)
	add_child(prompt)


func _process(dt: float) -> void:
	t += dt
	title.rotation = sin(t * 2.0) * 0.03
	title.scale = Vector2.ONE * (1.0 + sin(t * 3.3) * 0.03)
	prompt.modulate.a = 0.55 + 0.45 * sin(t * 4.0)
	bro.look = Vector2(sin(t), 0.2)
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if started:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed):
		started = true
		Game.play_music("menu")
		Game.voice("title")
		Game.sfx("powerup", 0.0)
		bro.set_mood("surprised", 1.0)
		bro.hop(50)
		get_tree().create_timer(1.6).timeout.connect(func(): Game.goto("menu"))


func _draw() -> void:
	var top := Color("#3b2463")
	var bot := Color("#e2557a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([top, top, bot, bot]))
	# sunburst
	for i in 24:
		var a0 := TAU * i / 24.0 + t * 0.1
		var a1 := a0 + TAU / 48.0
		var c := Vector2(640, 420)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 1400, c + Vector2.from_angle(a1) * 1400]),
			Color(1, 1, 1, 0.05))
	draw_rect(Rect2(0, 640, 1280, 80), Color("#2a1846"))
	# little doodles around: pies, balloons, snowballs
	var items := [[Vector2(180, 420), Color("#f7d9a8")], [Vector2(1100, 400), Color("#5ad1ff")],
		[Vector2(260, 580), Color("#ffffff")], [Vector2(1020, 580), Color("#ff6f86")]]
	for i in items.size():
		var p: Vector2 = items[i][0] + Vector2(0, sin(t * 2 + i) * 12)
		draw_circle(p, 34, items[i][1])
		draw_arc(p, 34, 0, TAU, 32, Color(0, 0, 0, 0.35), 4)
