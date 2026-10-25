extends Node2D
## Base class for the ten locations. Handles the HUD, rage meter, scoring,
## completion banner and shared helpers. Scenes extend this file and override
## `setup()`, `_draw()` (background) and `_process()`.

const FX = preload("res://scripts/fx.gd")
const Bro = preload("res://scripts/bro.gd")

var scene_id := ""
var rage := 0.0
var score := 0
var completed := false
var bro: Bro
var hud: CanvasLayer
var rage_bar: ProgressBar
var score_label: Label
var hint_label: Label
var _combo := 0
var _combo_t := 0.0
var _chatter_t := 6.0
var time := 0.0
var _shake := 0.0
var fx_layer: Node2D
var injured := false
var blaster_on := false
var blaster_btn: Button
var blaster_aim := Vector2(-100, -100)
var darts: Array = []        ## bullets: {from, to, t, age, hit}


func _ready() -> void:
	var info := Game.scene_info(scene_id)
	Game.play_music(scene_id)
	_build_hud(info)
	setup()
	fx_layer = Node2D.new()
	fx_layer.z_index = 45
	add_child(fx_layer)
	_build_blaster()
	get_tree().create_timer(0.4).timeout.connect(func(): Game.voice("s_" + scene_id))


## Override: build the scene.
func setup() -> void:
	pass


## Override: hint text for the bottom of the screen.
func hint() -> String:
	return ""


func _build_hud(info: Dictionary) -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.18, 0.78)
	sb.set_corner_radius_all(0)
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 56)
	hud.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var back := Button.new()
	back.text = "< Map"
	back.pressed.connect(func():
		Game.sfx("click")
		Game.save_game()
		Game.goto("menu"))
	row.add_child(back)
	var title := Game.make_label(info.get("name", scene_id), 28, info.get("col", Color.WHITE))
	title.custom_minimum_size = Vector2(250, 0)
	row.add_child(title)
	row.add_child(Game.make_label("BRO RAGE", 20, Color("#ff8a8a")))
	rage_bar = ProgressBar.new()
	rage_bar.custom_minimum_size = Vector2(330, 30)
	rage_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rage_bar.max_value = 100
	rage_bar.show_percentage = false
	row.add_child(rage_bar)
	score_label = Game.make_label("", 22, Color("#ffde3b"))
	score_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(score_label)
	var mus := Button.new()
	mus.text = "Music: On" if Game.music_on else "Music: Off"
	mus.pressed.connect(func(): mus.text = "Music: On" if Game.toggle_music() else "Music: Off")
	row.add_child(mus)
	hint_label = Game.make_label(hint(), 20, Color(1, 1, 1, 0.92))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(0, 684)
	hint_label.size = Vector2(1280, 30)
	hud.add_child(hint_label)
	_update_hud()


func _update_hud() -> void:
	rage_bar.value = rage
	var star := "  *STAR*" if Game.stars.get(scene_id, false) else ""
	score_label.text = "Mean pts: %d%s" % [score, star]


func set_hint(t: String) -> void:
	hint_label.text = t


## Core reward: makes Bro angrier and awards mean points.
func add_rage(amount: float, pos: Vector2, text := "") -> void:
	if amount <= 0:
		return
	_combo = _combo + 1 if _combo_t > 0 else 1
	_combo_t = 1.5
	var mult := 1 + mini(_combo - 1, 4) / 2.0 if _combo > 2 else 1.0
	var pts := int(amount * 10 * mult)
	score += pts
	Game.add_mean(pts)
	rage = minf(100.0, rage + amount)
	var label := "+%d" % pts
	if text != "":
		label = text + "  +%d" % pts
	FX.float_text(fx_layer if fx_layer else self, pos, label)
	if _combo == 3:
		FX.float_text(fx_layer if fx_layer else self, pos + Vector2(0, -50), "COMBO x%d!" % _combo, Color("#ff6df0"), 36)
		if not Game.voice_busy():
			Game.voice("combo")
	if Game.best.get(scene_id, 0) < score:
		Game.best[scene_id] = score
	if rage >= 100.0 and not completed:
		_complete()
	_update_hud()


func _complete() -> void:
	completed = true
	var first: bool = not Game.stars.get(scene_id, false)
	Game.stars[scene_id] = true
	Game.save_game()
	Game.sfx("levelup", 0.0)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(bro):
			bro.say("mom")
			bro.set_mood("angry")
			bro.hop(60))
	get_tree().create_timer(2.6).timeout.connect(func(): Game.voice("maxrage"))
	get_tree().create_timer(5.0).timeout.connect(func(): Game.voice("mom_stop"))
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 200)
	panel.size = Vector2(500, 0)
	hud.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var l1 := Game.make_label("MAXIMUM BROTHER RAGE!", 38, Color("#ff5a4f"))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Game.make_label("You earned a STAR for %s!" % Game.scene_info(scene_id).name if first
		else "Already starred - but he's still FURIOUS!", 22, Color("#ffde3b"))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var l3 := Game.make_label("Stars: %d / 10" % Game.star_count(), 22)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l3)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var keep := Button.new()
	keep.text = "Keep bugging him"
	keep.pressed.connect(func():
		Game.sfx("click")
		panel.queue_free())
	h.add_child(keep)
	var map := Button.new()
	map.text = "Back to map"
	map.pressed.connect(func():
		Game.sfx("click")
		Game.save_game()
		Game.goto("menu"))
	h.add_child(map)
	panel.pivot_offset = Vector2(250, 120)
	panel.scale = Vector2(0.2, 0.2)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst(Vector2(640, 300), 80, [Color("#ff5a4f"), Color("#ffde3b"), Color("#5ad1ff"), Color("#7dff6a"), Color("#ff6df0")], 700, 7, 700, 2.0)


func burst(pos: Vector2, count: int, colors: Array, speed := 300.0, size := 6.0, grav := 900.0,
		life := 1.0, spread := TAU, dir := -PI / 2) -> void:
	var b := FX.Burst.new(pos, count, colors, speed, size, grav, life, spread, dir)
	(fx_layer if fx_layer else self).add_child(b)


func shake(amount := 10.0) -> void:
	_shake = maxf(_shake, amount)


func spawn_bro(pos: Vector2, sc := 1.0) -> Bro:
	bro = Bro.new()
	bro.position = pos
	bro.scale = Vector2(sc, sc)
	add_child(bro)
	return bro


## Starts the "oh no, he's hurt" sequence: locks input, then after `delay`
## seconds shows the emergency banner and heads to the hospital cutscene.
func injure(cause: String, delay := 3.0) -> void:
	if injured:
		return
	injured = true
	set_process_unhandled_input(false)
	Game.injuries[scene_id] = true
	Game.hospital_from = scene_id
	Game.hospital_cause = cause
	Game.hospital_serious = false
	Game.save_game()
	get_tree().create_timer(delay).timeout.connect(_emergency)


func _emergency(text := "OH NO!\nHe's got to go to the HOSPITAL!", flashes := 8, wait := 3.8, mom_delay := 0.0) -> void:
	Game.stop_music()
	Game.sfx("siren", 0.0, -2)
	if mom_delay > 0.0:
		get_tree().create_timer(mom_delay).timeout.connect(func(): Game.voice("mom_ambulance"))
	else:
		Game.voice("mom_ambulance")
	var flash := ColorRect.new()
	flash.color = Color(1, 0, 0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tw := flash.create_tween().set_loops(flashes)
	tw.tween_property(flash, "color:a", 0.35, 0.22)
	tw.tween_property(flash, "color:a", 0.05, 0.22)
	var l := Game.make_label(text, 54, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#a00010"))
	l.add_theme_constant_override("outline_size", 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1280, 160)
	l.position = Vector2(0, 220)
	l.pivot_offset = Vector2(640, 80)
	hud.add_child(l)
	l.scale = Vector2(0.2, 0.2)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(wait).timeout.connect(func():
		while Game.voice_busy():  # let Mom finish her line first
			await get_tree().process_frame
		Game.goto("hospital"))


# ---------------------------------------------------------- 9mm pistol

func _build_blaster() -> void:
	if not Game.has_blaster:
		return
	blaster_btn = Button.new()
	blaster_btn.toggle_mode = true
	blaster_btn.custom_minimum_size = Vector2(116, 80)
	blaster_btn.position = Vector2(1150, 626)
	blaster_btn.add_theme_stylebox_override("pressed", Game._box(Color("#e8303a"), 14, Color("#fff6b0"), 4))
	blaster_btn.toggled.connect(func(on: bool):
		blaster_on = on
		Game.sfx("click"))
	hud.add_child(blaster_btn)
	var icon := FX.Layer.new(func(ci): FX.draw_blaster(ci, Vector2(55, 36), 0.62))
	blaster_btn.add_child(icon)
	hud.add_child(FX.Layer.new(_draw_blaster_fx, 10))


func _input(e: InputEvent) -> void:
	if not blaster_on or injured:
		return
	if e is InputEventMouseMotion:
		blaster_aim = e.position
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		blaster_aim = e.position
		if e.position.y < 70 or blaster_btn.get_global_rect().grow(6).has_point(e.position):
			return  # let the HUD buttons work
		get_viewport().set_input_as_handled()
		Game.sfx("blaster", 0.1)
		darts.append({"from": Vector2(1210, 700), "to": e.position, "t": 0.0, "age": 0.0, "hit": blaster_hits(e.position)})


## Override for locations where Bro isn't a plain standing puppet.
func blaster_hits(p: Vector2) -> bool:
	if not is_instance_valid(bro) or not bro.visible:
		return false
	if p.distance_to(bro.head_pos()) < 62.0 * absf(bro.scale.y):
		return true
	return Rect2(-50, -200, 100, 200).has_point(bro.to_local(p))


func _update_darts(dt: float) -> void:
	for d in darts:
		d.age += dt
		if d.t < 1.0:
			d.t = minf(1.0, d.t + dt / 0.05)
			if d.t >= 1.0:
				if d.hit and not injured:
					_blasted(d.to)
				elif not d.hit:
					Game.sfx("thud", 0.2, -10, 1.6)
					if randf() < 0.4:
						chat(["missed", "nyah", "tooslow"].pick_random())


func _draw_blaster_fx(ci: CanvasItem) -> void:
	for d in darts:
		var from: Vector2 = d.from
		var to: Vector2 = d.to
		var rot := (to - from).angle()
		FX.draw_muzzle_flash(ci, from, rot, 1.0 - d.age / 0.08)
		if d.t < 1.0:
			FX.draw_dart(ci, from.lerp(to, d.t), rot)
		elif not d.hit:
			FX.draw_bullet_hole(ci, to, clampf((3.0 - d.age) / 0.8, 0.0, 1.0))
	if blaster_on and not injured and blaster_aim.y > 70:
		ci.draw_arc(blaster_aim, 28, 0, TAU, 24, Color("#ff3b3b"), 3)
		ci.draw_circle(blaster_aim, 4, Color("#ff3b3b"))
		for k in 4:
			var dir := Vector2.from_angle(k * PI / 2)
			ci.draw_line(blaster_aim + dir * 16, blaster_aim + dir * 40, Color("#ff3b3b"), 3)


## Point-blank gunshot: the long, scary emergency.
func _blasted(p: Vector2) -> void:
	injured = true
	set_process_unhandled_input(false)
	blaster_on = false
	Game.hospital_from = scene_id
	Game.hospital_cause = "Shot point-blank with a 9mm pistol"
	Game.hospital_serious = true
	Game.sfx("crack", 0.0)
	Game.sfx("bonk", 0.0)
	shake(20)
	on_blasted(p)
	# white flash, then the world goes dark and red
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.4)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dark)
	dark.create_tween().tween_property(dark, "color:a", 0.55, 2.5)
	var red := ColorRect.new()
	red.color = Color(0.8, 0, 0, 0)
	red.set_anchors_preset(Control.PRESET_FULL_RECT)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(red)
	var pulse := red.create_tween().set_loops(12)
	pulse.tween_property(red, "color:a", 0.28, 0.5)
	pulse.tween_property(red, "color:a", 0.06, 0.5)
	get_tree().create_timer(0.6).timeout.connect(Game.stop_music)
	for k in 5:
		get_tree().create_timer(1.0 + k * (1.1 + k * 0.15)).timeout.connect(func(): Game.sfx("heartbeat", 0.0, 2))
	get_tree().create_timer(2.4).timeout.connect(func():
		Game.voice("whathaveyoudone")
		var l := Game.make_label("Oh no... what have you DONE?!", 50, Color("#ffb0b0"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(1280, 70)
		l.position = Vector2(0, 120)
		l.modulate.a = 0.0
		hud.add_child(l)
		l.create_tween().tween_property(l, "modulate:a", 1.0, 1.0))
	get_tree().create_timer(6.5).timeout.connect(func():
		Game.voice("code_red")
		_emergency("CODE RED!\nHe's SERIOUSLY hurt!", 14, 6.0, 1.6))


## Override to customise how Bro reacts to being shot.
func on_blasted(p: Vector2) -> void:
	bro.set_mood("hurt")
	bro.say("blasted")
	bro.flail(1.0)
	var standing := absf(bro.rotation) < 0.3 and bro.visible
	get_tree().create_timer(0.9).timeout.connect(func():
		bro.set_mood("ko")
		Game.sfx("thud", 0.0)
		if standing:
			bro.fall_over(-1.0 if p.x > bro.global_position.x else 1.0))


## Spreading cartoon blood puddle at `pos`.
## With z 0 it goes under Bro (drawn just before him); a higher z puts it on
## top of foreground layers such as the kitchen counter.
func blood(pos: Vector2, size := 90.0, z := 0) -> void:
	var p := FX.Puddle.new(pos, size, z)
	add_child(p)
	if z == 0 and is_instance_valid(bro):
		move_child(p, bro.get_index())


## Bro occasionally says something while idle. Override `idle_lines()`.
func idle_lines() -> Array:
	return ["whatdoing", "leavemealone", "ugh"]


func _process(dt: float) -> void:
	time += dt
	_combo_t -= dt
	if _shake > 0:
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - dt * 40.0)
		if _shake <= 0:
			position = Vector2.ZERO
	if is_instance_valid(bro) and not injured:
		bro.red = rage / 100.0
		_chatter_t -= dt
		if _chatter_t <= 0:
			_chatter_t = randf_range(9, 15)
			var lines := idle_lines()
			if lines.size() > 0:
				bro.say(lines.pick_random(), false)
	queue_redraw()
	_update_darts(dt)
	tick(dt)


## Override for per-frame logic (keeps base processing intact).
func tick(_dt: float) -> void:
	pass


## Bro says a line only if not already talking.
func chat(id: String) -> void:
	if is_instance_valid(bro):
		bro.say(id, false)
		_chatter_t = randf_range(9, 15)


# ---------------------------------------------------------- drawing helpers

func sky(top: Color, bottom: Color, h := 720.0) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, h), Vector2(0, h)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func rrect(r: Rect2, col: Color, radius := 12.0, border := Color(0, 0, 0, 0), bw := 0) -> void:
	FX.rounded_rect(self, r, col, radius, border, bw)


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(FX.ellipse(c, rx, ry, 28), col)
