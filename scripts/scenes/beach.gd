extends "res://scripts/minigame.gd"
## Beach: Bro is sunbathing. Pour sand on him until he's buried, then
## introduce him to a crab. Watch out for waves washing the sand away.

const SAND_Y := 380.0
const ZONES := [Vector2(0, -40), Vector2(0, -95), Vector2(0, -150)]
const TOOLS := [["shovel", "Sand Shovel"], ["crab", "Crab"], ["bucket", "Sea Water"]]

var level := [0.0, 0.0, 0.0]
var tool := "shovel"
var mouse := Vector2.ZERO
var down := false
var buried := 0.0
var annoyed := false
var pinch_cd := 0.0
var sand_sfx := 0.0
var wave := 0.0
var wave_t := 14.0
var gull_x := -200.0
var gull_t := 6.0
var anchor: Node2D
var tool_buttons := {}


func _init() -> void:
	scene_id = "beach"


func hint() -> String:
	return ""


func idle_lines() -> Array:
	return ["relax"] if not annoyed else ["letmeout", "leavemealone"]


func setup() -> void:
	spawn_bro(Vector2(990, 540), 1.0)
	bro.rotation = -PI / 2
	bro.set_mood("sleep")
	bro.bob = false
	bro.arm_l = 0.08
	bro.arm_r = 0.08
	bro.elbow_l = 0.0
	bro.elbow_r = 0.0
	bro.look_at_mouse = false
	anchor = Node2D.new()
	add_child(anchor)
	bro.bubble_target = anchor
	bro.bubble_offset = Vector2(0, -110)
	hint_label.visible = false
	var row := HBoxContainer.new()
	row.position = Vector2(20, 654)
	row.add_theme_constant_override("separation", 10)
	hud.add_child(row)
	for t in TOOLS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = t[0] == tool
		b.add_theme_stylebox_override("pressed", Game._box(Color("#3bb0ff"), 14, Color("#fff6b0"), 4))
		b.pressed.connect(_select.bind(t[0]))
		row.add_child(b)
		tool_buttons[t[0]] = b
	var tip := Game.make_label("Hold the shovel over him to bury him. Then bring the crab!", 20)
	tip.position = Vector2(520, 662)
	hud.add_child(tip)


func _select(t: String) -> void:
	tool = t
	Game.sfx("click")
	for k in tool_buttons:
		tool_buttons[k].button_pressed = k == t


func debug_state(n: int) -> void:
	level = [1.0, 0.9, 0.6]
	if n == 2:
		level = [1.0, 1.0, 1.0]
		tool = "crab"
		mouse = bro.head_pos() + Vector2(40, 0)


func _zone(i: int) -> Vector2:
	return bro.to_global(ZONES[i])


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		down = e.pressed
		if e.pressed:
			match tool:
				"crab":
					_pinch(e.position)
				"bucket":
					_splash(e.position)


func _wake_up() -> void:
	if not annoyed:
		annoyed = true
		bro.set_mood("surprised", 1.5)
		bro.base_mood = "angry"
		bro.say("hey")


func _pinch(p: Vector2) -> void:
	if pinch_cd > 0:
		return
	var hp := bro.head_pos()
	var feet := bro.to_global(Vector2(0, -10))
	var target := hp if p.distance_to(hp) < p.distance_to(feet) else feet
	if p.distance_to(target) > 80:
		return
	pinch_cd = 1.0
	_wake_up()
	Game.sfx("pinch")
	bro.set_mood("hurt", 1.2)
	bro.shake(0.8)
	bro.say("crab", false)
	shake(6)
	var mult := 1.6 if buried > 0 else 1.0
	add_rage(7.0 * mult, p, "PINCHED & STUCK!" if buried > 0 else "PINCH!")


func _splash(p: Vector2) -> void:
	if p.distance_to(bro.to_global(Vector2(0, -130))) > 170:
		return
	_wake_up()
	Game.sfx("splash")
	burst(p, 30, [Color(0.5, 0.8, 1, 0.9), Color(0.85, 0.95, 1)], 350, 6, 900, 0.8)
	bro.wet = minf(1.0, bro.wet + 0.35)
	bro.set_mood("surprised", 1.0)
	if randf() < 0.6:
		bro.say(["splashed", "cold"].pick_random(), false)
	add_rage(5.0 if buried > 0 else 3.0, p, "SPLASH")


func tick(dt: float) -> void:
	anchor.position = bro.head_pos()
	pinch_cd -= dt
	sand_sfx -= dt
	bro.wet = maxf(0.0, bro.wet - dt * 0.04)
	# shoveling
	if tool == "shovel" and down:
		for i in 3:
			if mouse.distance_to(_zone(i)) < 85:
				level[i] = minf(1.0, level[i] + dt * 0.7)
				if randf() < 0.5:
					burst(mouse + Vector2(0, -30), 3, [Color("#f0d080"), Color("#e0bc60")], 80, 4, 700, 0.5, 0.6, PI / 2)
				if sand_sfx <= 0:
					sand_sfx = 0.35
					Game.sfx("sand", 0.2, -6)
				if level[i] > 0.4:
					_wake_up()
	# struggling
	if buried > 0:
		buried -= dt
		bro.flail(0.1)
		if buried <= 0:
			for i in 3:
				level[i] = 0.15
			burst(bro.to_global(Vector2(0, -110)), 60, [Color("#f0d080"), Color("#e0bc60")], 500, 7, 900, 1.0)
			Game.sfx("whoosh")
			bro.say("revenge")
			bro.set_mood("angry")
	else:
		var decay := 0.12 if annoyed else 0.02
		for i in 3:
			level[i] = maxf(0.0, level[i] - dt * decay)
		if level.min() >= 0.9:
			buried = 7.0
			Game.sfx("levelup", 0.0, -4)
			bro.say("letmeout")
			bro.set_mood("angry")
			add_rage(14.0, bro.to_global(Vector2(0, -110)) + Vector2(0, -80), "BURIED!")
	# waves
	wave_t -= dt
	if wave_t <= 0:
		wave_t = randf_range(15, 22)
		Game.sfx("wave")
		create_tween().tween_property(self, "wave", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
		get_tree().create_timer(1.4).timeout.connect(func():
			if buried <= 0:
				for i in 3:
					level[i] *= 0.4
			create_tween().tween_property(self, "wave", 0.0, 1.6).set_trans(Tween.TRANS_SINE))
	# seagull
	gull_t -= dt
	if gull_t <= 0:
		gull_t = randf_range(12, 20)
		gull_x = -100
		Game.sfx("seagull", 0.1, -6)
	gull_x += dt * 220


func _draw() -> void:
	sky(Color("#4fb0ff"), Color("#bfe6ff"), 260)
	draw_circle(Vector2(160, 90), 60, Color("#fff4a0"))
	# sea
	var sea_edge := 300.0 + wave * 260.0
	draw_rect(Rect2(0, 230, 1280, 200), Color("#2a8ad6"))
	for i in 14:
		var x := fmod(i * 120 + time * 30, 1400) - 60
		draw_arc(Vector2(x, 270 + (i % 3) * 30), 26, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.5), 3)
	# sand
	draw_rect(Rect2(0, SAND_Y, 1280, 340), Color("#f4d58a"))
	for i in 40:
		draw_circle(Vector2(fmod(i * 97.0, 1280), SAND_Y + 20 + fmod(i * 53.0, 300)), 3, Color("#e8c470"))
	# wave wash
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 325))
	for i in 17:
		var x := i * 80.0
		pts.append(Vector2(x, sea_edge + sin(x * 0.02 + time * 2) * 12 + 60))
	pts.append(Vector2(1280, 325))
	draw_colored_polygon(pts, Color(0.2, 0.55, 0.85, 0.85))
	draw_polyline(pts.slice(1, pts.size() - 1), Color(1, 1, 1, 0.7), 5)
	# umbrella + towel
	draw_line(Vector2(560, 560), Vector2(520, 300), Color("#eee"), 6)
	var c := Vector2(520, 300)
	for k in 6:
		var a0 := PI + k * PI / 6
		var a1 := a0 + PI / 6
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0) * 170, sin(a0) * 80), c + Vector2(cos(a1) * 170, sin(a1) * 80)]),
			Color("#ff4a6a") if k % 2 == 0 else Color.WHITE)
	rrect(Rect2(640, 470, 400, 140), Color("#3bb0ff"), 10)
	for k in 5:
		draw_rect(Rect2(640 + k * 80, 470, 40, 140), Color("#ffde3b"))
	# sandcastle
	draw_rect(Rect2(150, 520, 120, 80), Color("#e0bc60"))
	for k in 3:
		draw_rect(Rect2(150 + k * 44, 490, 32, 40), Color("#e0bc60"))
	draw_line(Vector2(210, 490), Vector2(210, 440), Color("#555"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(210, 440), Vector2(250, 452), Vector2(210, 464)]), Color("#ff4a6a"))


func _foreground(ci: CanvasItem) -> void:
	# sunglasses while relaxing
	if not annoyed:
		var hp := bro.head_pos()
		for s: int in [-1, 1]:
			var e := bro.to_global(Vector2(s * 18, -242))
			ci.draw_circle(e, 14, Color("#1a1a2a"))
		ci.draw_line(bro.to_global(Vector2(-6, -244)), bro.to_global(Vector2(6, -244)), Color("#1a1a2a"), 4)
		ci.draw_string(ThemeDB.fallback_font, hp + Vector2(40, -70) + Vector2(0, sin(time * 2) * 6), "z z z", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	# sand mounds
	for i in 3:
		var l: float = level[i]
		if l < 0.03:
			continue
		var z := _zone(i)
		var col := Color("#e8c470").lerp(Color("#d9b055"), float(i) / 3.0)
		ci.draw_colored_polygon(FX.ellipse(z + Vector2(0, 8), 30 + l * 40, 14 + l * 48, 24), Color(col, minf(1.0, l * 1.6)))
		for k in int(l * 6):
			ci.draw_circle(z + Vector2(-35 + k * 14, -l * 30 + (k % 2) * 8), 5, Color("#c9a24a"))
	if buried > 0:
		ci.draw_string(ThemeDB.fallback_font, bro.to_global(Vector2(0, -110)) + Vector2(-70, -120), "STUCK! %.0f" % buried,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#ffde3b"))
	# seagull
	if gull_x < 1400:
		var g := Vector2(gull_x, 150 + sin(gull_x * 0.02) * 30)
		var flap := sin(time * 10) * 14
		ci.draw_polyline(PackedVector2Array([g + Vector2(-34, -flap), g + Vector2(-12, 0), g, g + Vector2(12, 0), g + Vector2(34, -flap)]), Color("#f4f4f4"), 6)
		ci.draw_circle(g, 8, Color.WHITE)
	# tool cursor
	match tool:
		"shovel":
			ci.draw_line(mouse + Vector2(30, -60), mouse + Vector2(0, -10), Color("#8a5a3c"), 8)
			ci.draw_colored_polygon(PackedVector2Array([mouse + Vector2(-20, -16), mouse + Vector2(16, -4), mouse + Vector2(0, 18), mouse + Vector2(-26, 6)]), Color("#bbb"))
		"crab":
			_draw_crab(ci, mouse)
		"bucket":
			ci.draw_colored_polygon(PackedVector2Array([mouse + Vector2(-28, -30), mouse + Vector2(28, -30), mouse + Vector2(20, 24), mouse + Vector2(-20, 24)]), Color("#ff4a6a"))
			ci.draw_colored_polygon(FX.ellipse(mouse + Vector2(0, -30), 28, 8), Color("#4ab0ff"))
			ci.draw_arc(mouse + Vector2(0, -30), 30, PI, TAU, 12, Color("#555"), 3)


func _draw_crab(ci: CanvasItem, p: Vector2) -> void:
	var snap := sin(time * 14) * 0.3
	ci.draw_colored_polygon(FX.ellipse(p, 34, 22), Color("#ff5a3a"))
	for s: int in [-1, 1]:
		for k in 3:
			ci.draw_line(p + Vector2(s * 24, 4 + k * 6), p + Vector2(s * 46, 14 + k * 8), Color("#e04a2a"), 4)
		var claw := p + Vector2(s * 44, -26)
		ci.draw_line(p + Vector2(s * 24, -8), claw, Color("#ff5a3a"), 7)
		ci.draw_colored_polygon(PackedVector2Array([claw, claw + Vector2(s * 18, -14).rotated(snap * s), claw + Vector2(s * 20, 2)]), Color("#ff5a3a"))
		ci.draw_circle(p + Vector2(s * 10, -22), 7, Color.WHITE)
		ci.draw_circle(p + Vector2(s * 10, -22), 3, Color.BLACK)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))
