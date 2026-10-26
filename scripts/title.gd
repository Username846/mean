extends Node2D
## Title screen. The first click also unlocks web audio.
## After the gunshot ending he's gone: no brother, dimmer colours, quiet music.

const Bro = preload("res://scripts/bro.gd")

var bro: Bro
var t := 0.0
var started := false
var title: Label
var prompt: Label
var fs_btn: Button
var vol_btn: Button
var vol_panel: PanelContainer
var vol_slider: HSlider
var vol_label: Label


func _ready() -> void:
	if Game.bro_dead:
		_build_empty()
		return
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
	prompt = Game.make_label("Click or tap anywhere to start!", 34)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(1280, 50)
	prompt.position = Vector2(0, 230)
	add_child(prompt)
	_build_buttons()


func _build_empty() -> void:
	title = Game.make_label("I MISS MY BROTHER", 96, Color("#9aa3b5"))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_outline_color", Color("#1c1f2a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 120)
	title.position = Vector2(0, 40)
	title.pivot_offset = Vector2(640, 60)
	add_child(title)
	var sub := Game.make_label("10 places. No big brother anymore.", 28, Color("#c8ccd6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 160)
	add_child(sub)
	prompt = Game.make_label("Click or tap anywhere to continue", 34, Color("#c8ccd6"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(1280, 50)
	prompt.position = Vector2(0, 230)
	add_child(prompt)
	_build_buttons()


func _build_buttons() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	# fullscreen, bottom-left
	fs_btn = Button.new()
	fs_btn.text = "Fullscreen"
	fs_btn.custom_minimum_size = Vector2(190, 64)
	fs_btn.position = Vector2(20, 636)
	fs_btn.add_theme_font_size_override("font_size", 26)
	# act on press, so the browser still sees it as part of the click/tap
	fs_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	fs_btn.pressed.connect(func():
		Game.sfx("click")
		Game.toggle_fullscreen())
	fs_btn.visible = Game.fullscreen_supported()
	ui.add_child(fs_btn)
	# volume, top-right
	vol_btn = Button.new()
	vol_btn.custom_minimum_size = Vector2(76, 64)
	vol_btn.position = Vector2(1184, 20)
	vol_btn.pressed.connect(func():
		vol_panel.visible = not vol_panel.visible
		Game.sfx("click"))
	ui.add_child(vol_btn)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(76, 64)
	icon.draw.connect(func(): _draw_speaker(icon))
	vol_btn.add_child(icon)
	vol_panel = PanelContainer.new()
	vol_panel.position = Vector2(880, 96)
	vol_panel.custom_minimum_size = Vector2(380, 0)
	vol_panel.visible = false
	ui.add_child(vol_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	vol_panel.add_child(v)
	vol_label = Game.make_label("", 26)
	vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(vol_label)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.step = 1
	vol_slider.value = Game.volume * 100
	vol_slider.custom_minimum_size = Vector2(340, 48)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("#ff7b39")
	grab.content_margin_top = 10
	grab.content_margin_bottom = 10
	grab.set_corner_radius_all(8)
	vol_slider.add_theme_stylebox_override("slider", Game._box(Color(0.1, 0.06, 0.15), 8))
	vol_slider.add_theme_stylebox_override("grabber_area", grab)
	vol_slider.add_theme_stylebox_override("grabber_area_highlight", grab)
	vol_slider.add_theme_icon_override("grabber", _knob(Color("#ffde3b")))
	vol_slider.add_theme_icon_override("grabber_highlight", _knob(Color("#fff3a0")))
	vol_slider.value_changed.connect(func(val: float):
		Game.set_volume(val / 100.0)
		_update_volume())
	vol_slider.drag_ended.connect(func(_changed: bool):
		Game.save_game()
		Game.sfx("pop", 0.0))
	v.add_child(vol_slider)
	_update_volume()


func _knob(col: Color) -> ImageTexture:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 40:
			var d := Vector2(x - 19.5, y - 19.5).length()
			if d < 19.0:
				img.set_pixel(x, y, Color(0.25, 0.1, 0.05) if d > 15.5 else col)
	return ImageTexture.create_from_image(img)


func _update_volume() -> void:
	vol_label.text = "Volume: %d%%" % roundi(Game.volume * 100) if Game.volume > 0.001 else "Volume: Muted"
	vol_btn.get_child(0).queue_redraw()


func _draw_speaker(ci: Control) -> void:
	var c := Vector2(30, 32)
	var col := Color.WHITE
	ci.draw_rect(Rect2(c + Vector2(-14, -8), Vector2(10, 16)), col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -8), c + Vector2(8, -18), c + Vector2(8, 18), c + Vector2(-6, 8)]), col)
	if Game.volume <= 0.001:
		ci.draw_line(c + Vector2(16, -9), c + Vector2(32, 9), Color("#ff5a4f"), 5)
		ci.draw_line(c + Vector2(16, 9), c + Vector2(32, -9), Color("#ff5a4f"), 5)
		return
	var waves := 1 + int(Game.volume * 2.99)
	for i in waves:
		ci.draw_arc(c + Vector2(8, 0), 10 + i * 8, -0.8, 0.8, 10, col, 4)


func _process(dt: float) -> void:
	t += dt
	prompt.modulate.a = 0.55 + 0.45 * sin(t * 4.0)
	if is_instance_valid(bro):
		title.rotation = sin(t * 2.0) * 0.03
		title.scale = Vector2.ONE * (1.0 + sin(t * 3.3) * 0.03)
		bro.look = Vector2(sin(t), 0.2)
	if fs_btn.visible:
		fs_btn.text = "Exit Fullscreen" if Game.is_fullscreen() else "Fullscreen"
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if started:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed):
		if vol_panel.visible:
			vol_panel.visible = false
			return
		started = true
		if Game.bro_dead:
			Game.play_music("grave")
			Game.sfx("click")
			Game.goto("menu")
			return
		Game.play_music("menu")
		Game.voice("title")
		Game.sfx("powerup", 0.0)
		bro.set_mood("surprised", 1.0)
		bro.hop(50)
		get_tree().create_timer(1.6).timeout.connect(func(): Game.goto("menu"))


func _draw() -> void:
	if Game.bro_dead:
		var dt := Color("#1c1f2a")
		var db := Color("#3d4250")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([dt, dt, db, db]))
		draw_rect(Rect2(0, 640, 1280, 80), Color("#15171f"))
		return
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
