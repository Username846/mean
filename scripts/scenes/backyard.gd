extends "res://scripts/minigame.gd"
## Backyard: pull back the slingshot and lob water balloons at Bro.
## He wanders around and sometimes pops open an umbrella.

const GROUND := 640.0
const ANCHOR := Vector2(190, 520)
const GRAV := 900.0

var dragging := false
var pull := Vector2.ZERO
var balloons: Array = []
var puddles: Array = []
var target_x := 950.0
var walk_t := 2.0
var umbrella := 0.0
var umbrella_t := 0.0
var mouse := Vector2.ZERO
var branch := {}
var clouds := [Vector2(200, 120), Vector2(620, 80), Vector2(1000, 150)]


func _init() -> void:
	scene_id = "backyard"


func hint() -> String:
	return "Drag back from the slingshot and let go to launch a water balloon!"


func idle_lines() -> Array:
	return ["nyah", "whatdoing", "leavemealone", "tooslow"]


func setup() -> void:
	spawn_bro(Vector2(950, GROUND), 0.8)


func debug_state(n: int) -> void:
	dragging = true
	pull = Vector2(-120, 60)
	bro.wet = 0.6
	umbrella = 1.0 if n == 2 else 0.0
	umbrella_t = 5.0 if n == 2 else 0.0
	puddles.append({"x": 700.0, "a": 1.0})


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
		if dragging:
			pull = (e.position - ANCHOR).limit_length(160)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		if e.pressed and e.position.distance_to(ANCHOR) < 160:
			dragging = true
			pull = (e.position - ANCHOR).limit_length(160)
			Game.sfx("squeak", 0.1, -4)
		elif not e.pressed and dragging:
			dragging = false
			if pull.length() > 25:
				var v := -pull * 7.5
				balloons.append({"p": ANCHOR + pull, "v": v, "c": [Color("#5ad1ff"), Color("#ff6fb0"), Color("#ffde3b"), Color("#7dff6a")].pick_random()})
				Game.sfx("boing", 0.1, -2, 1.3)
			pull = Vector2.ZERO


func tick(dt: float) -> void:
	_update_branch(dt)
	if injured:
		umbrella = move_toward(umbrella, 0.0, dt * 5)
		bro.arm_r = 0.25
		_update_balloons_only(dt)
		return
	# bro wandering
	walk_t -= dt
	var speed := 120.0 + rage * 2.0
	bro.position.x = move_toward(bro.position.x, target_x, speed * dt)
	if walk_t <= 0:
		walk_t = randf_range(1.5, 3.5)
		target_x = randf_range(620, 1180)
		if randf() < 0.3 and rage > 10:
			umbrella_t = randf_range(2.0, 3.5)
			if randf() < 0.5:
				chat("umbrella")
	umbrella_t -= dt
	umbrella = move_toward(umbrella, 1.0 if umbrella_t > 0 else 0.0, dt * 5)
	bro.arm_r = lerpf(0.25, 2.8, umbrella)
	bro.elbow_r = lerpf(0.3, 0.2, umbrella)
	bro.wet = maxf(0.0, bro.wet - dt * 0.03)
	for i in clouds.size():
		clouds[i].x = fmod(clouds[i].x + dt * 15, 1500)
	# balloons
	for b in balloons.duplicate():
		b.v.y += GRAV * dt
		b.p += b.v * dt
		var hp := bro.head_pos()
		var hr := 48.0 * 0.8
		var umb_c := hp + Vector2(30, -80)
		if umbrella > 0.8 and b.p.distance_to(umb_c) < 110 and b.p.y < umb_c.y + 10:
			_pop(b, false)
			Game.sfx("splash", 0.1, -4)
			bro.set_mood("smug", 1.2)
			chat("umbrella")
			continue
		if b.p.distance_to(hp) < hr + 18:
			_pop(b, true)
			bro.wet = minf(1.0, bro.wet + 0.35)
			add_rage(10.0, b.p, "HEADSHOT!")
			bro.set_mood("angry", 1.5)
			bro.say(["soaked", "cold", "grr", "mom", "notfunny"].pick_random(), false)
			continue
		var body := Rect2(bro.position.x - 45, hp.y + hr, 90, GROUND - hp.y - hr)
		if body.has_point(b.p):
			_pop(b, true)
			bro.wet = minf(1.0, bro.wet + 0.2)
			add_rage(6.0, b.p, "SPLOOSH")
			bro.set_mood("surprised", 1.2)
			if randf() < 0.5:
				bro.say(["soaked", "cold", "hey"].pick_random(), false)
			continue
		if branch.is_empty() and (b.p.distance_to(Vector2(1200, 230)) < 110 or b.p.distance_to(Vector2(1120, 280)) < 70):
			_pop(b, false)
			_snap_branch(b.p)
			continue
		if b.p.y > GROUND - 8 or b.p.x > 1320 or b.p.x < -40:
			_pop(b, false)
			if b.p.x < 1280:
				puddles.append({"x": b.p.x, "a": 1.0})
			if randf() < 0.3:
				chat(["missed", "nyah"].pick_random())
	for p in puddles:
		p.a -= dt * 0.1
	puddles = puddles.filter(func(p): return p.a > 0)


func _update_balloons_only(dt: float) -> void:
	for b in balloons.duplicate():
		b.v.y += GRAV * dt
		b.p += b.v * dt
		if b.p.y > GROUND - 8 or b.p.x > 1320:
			_pop(b, false)


## A balloon in the leaves snaps a branch off; it falls straight down.
func _snap_branch(p: Vector2) -> void:
	Game.sfx("crack", 0.0)
	burst(p, 20, [Color("#3f9a3a"), Color("#4caf45")], 250, 6, 500, 1.2)
	branch = {"x": clampf(p.x, 1060.0, 1190.0), "y": 300.0, "vy": 0.0, "rot": 0.0, "done": false}


func _update_branch(dt: float) -> void:
	if branch.is_empty() or branch.done:
		return
	branch.vy += GRAV * dt
	branch.y += branch.vy * dt
	branch.rot += dt * 2.5
	var hp := bro.head_pos()
	if not injured and absf(hp.x - branch.x) < 110 and branch.y > hp.y - 50:
		branch.done = true
		branch.y = hp.y - 40
		Game.sfx("crack", 0.0)
		Game.sfx("thud", 0.0)
		shake(14)
		bro.set_mood("hurt")
		bro.say("aaah")
		burst(hp + Vector2(0, -30), 20, [Color("#ffe14a"), Color.WHITE], 300, 6, 800, 0.7)
		injure("Cracked skull from a falling tree branch", 4.0)
		get_tree().create_timer(0.9).timeout.connect(func():
			bro.set_mood("ko")
			bro.fall_over(-1.0)
			Game.sfx("thud", 0.1, -4)
			branch.y = GROUND - 20.0
			get_tree().create_timer(0.6).timeout.connect(func():
				blood(bro.head_pos() + Vector2(0, 40), 100)))
	elif branch.y >= GROUND - 20:
		branch.y = GROUND - 20
		branch.done = true
		Game.sfx("thud", 0.1, -4)
		if not injured:
			bro.set_mood("smug", 1.5)
			chat("missed")
			get_tree().create_timer(3.0).timeout.connect(func():
				if not injured:
					branch = {})


func _pop(b: Dictionary, hit: bool) -> void:
	balloons.erase(b)
	Game.sfx("splash", 0.15, 0 if hit else -4)
	burst(b.p, 30 if hit else 18, [Color(0.55, 0.85, 1, 0.9), Color(0.8, 0.95, 1, 0.9), b.c], 380, 6, 900, 0.8)
	if hit:
		shake(5)


func _draw() -> void:
	sky(Color("#5fb8ff"), Color("#cdeeff"), GROUND)
	draw_circle(Vector2(1150, 100), 50, Color("#fff4a0"))
	for c in clouds:
		var p: Vector2 = c - Vector2(100, 0)
		for k in 4:
			draw_circle(p + Vector2(k * 34, sin(k * 1.7) * 8), 32, Color(1, 1, 1, 0.9))
	# house corner + fence
	draw_rect(Rect2(0, 220, 300, GROUND - 220), Color("#d88a5a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 220), Vector2(320, 220), Vector2(150, 120)]), Color("#8a3a2a"))
	draw_rect(Rect2(60, 300, 90, 90), Color("#8fd3ff"))
	for i in 30:
		var x := 300 + i * 34
		draw_rect(Rect2(x, 440, 26, 200), Color("#f2e3c6"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, 440), Vector2(x + 26, 440), Vector2(x + 13, 424)]), Color("#f2e3c6"))
	draw_rect(Rect2(300, 480, 1000, 12), Color("#d8c4a0"))
	# tree
	draw_rect(Rect2(1180, 260, 40, 380), Color("#7a4a2a"))
	draw_circle(Vector2(1200, 230), 110, Color("#3f9a3a"))
	draw_circle(Vector2(1120, 280), 70, Color("#4caf45"))
	# grass
	draw_rect(Rect2(0, GROUND, 1280, 80), Color("#58b947"))
	for i in 64:
		var x := i * 20 + 6
		draw_line(Vector2(x, GROUND), Vector2(x - 4, GROUND - 10), Color("#4aa23b"), 3)
	for p in puddles:
		ellipse(Vector2(p.x, GROUND + 10), 60, 10, Color(0.45, 0.75, 1, 0.6 * p.a))
	# kiddie pool
	ellipse(Vector2(560, GROUND + 26), 110, 26, Color("#ff7aa8"))
	ellipse(Vector2(560, GROUND + 22), 92, 18, Color("#8fdcff"))


func _foreground(ci: CanvasItem) -> void:
	if not branch.is_empty():
		var c := Vector2(branch.x, branch.y)
		ci.draw_set_transform(c, branch.rot if not branch.done else 0.1, Vector2.ONE)
		ci.draw_line(Vector2(-80, 0), Vector2(80, 0), Color("#6a3f22"), 16)
		ci.draw_line(Vector2(20, 0), Vector2(60, -40), Color("#6a3f22"), 9)
		for k in 6:
			ci.draw_circle(Vector2(-70 + k * 30, -14 + (k % 2) * 20), 22, Color("#3f9a3a"))
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# umbrella above bro
	if umbrella > 0.05:
		var hp := bro.head_pos()
		var c := hp + Vector2(30, -80 + (1.0 - umbrella) * 60)
		var pts := PackedVector2Array()
		for i in 17:
			var a := lerpf(PI, TAU, i / 16.0)
			pts.append(c + Vector2(cos(a) * 110 * umbrella, sin(a) * 70 * umbrella))
		ci.draw_colored_polygon(pts, Color("#ff4a6a"))
		for i in 4:
			var a := lerpf(PI, TAU, (i + 0.5) / 4.0)
			ci.draw_line(c, c + Vector2(cos(a) * 110, sin(a) * 70) * umbrella, Color("#c42a4a"), 3)
		ci.draw_line(c, c + Vector2(0, 100), Color("#333"), 5)
	# slingshot
	var a := ANCHOR
	ci.draw_line(a + Vector2(0, 120), a + Vector2(0, 30), Color("#7a4a2a"), 18)
	ci.draw_line(a + Vector2(0, 40), a + Vector2(-40, -20), Color("#7a4a2a"), 14)
	ci.draw_line(a + Vector2(0, 40), a + Vector2(40, -20), Color("#7a4a2a"), 14)
	var pouch := a + pull
	ci.draw_line(a + Vector2(-40, -20), pouch, Color("#3a2a20"), 6)
	ci.draw_line(a + Vector2(40, -20), pouch, Color("#3a2a20"), 6)
	ci.draw_colored_polygon(FX.ellipse(pouch, 20, 24), Color(0.35, 0.8, 1, 0.95))
	ci.draw_circle(pouch + Vector2(-6, -8), 6, Color(1, 1, 1, 0.6))
	# aim preview
	if dragging and pull.length() > 25:
		var p := pouch
		var v := -pull * 7.5
		for i in 14:
			v.y += GRAV * 0.05
			p += v * 0.05
			ci.draw_circle(p, 5 - i * 0.25, Color(1, 1, 1, 0.8 - i * 0.05))
	for b in balloons:
		var ang: float = (b.v as Vector2).angle()
		ci.draw_set_transform(b.p, ang, Vector2.ONE)
		ci.draw_colored_polygon(FX.ellipse(Vector2.ZERO, 24, 19), b.c)
		ci.draw_circle(Vector2(6, -6), 5, Color(1, 1, 1, 0.6))
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	bro.position.x = 1120.0
	target_x = 1120.0
	_snap_branch(Vector2(1150, 260))
