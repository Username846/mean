extends "res://scripts/minigame.gd"
## Carnival: hit the bullseye to drop Bro into the dunk tank.
## Your aim wobbles, and the target starts moving as he gets madder.

const TANK := Rect2(860, 430, 330, 220)
const SEAT_Y := 445.0
const TARGET_BASE := Vector2(720, 300)

var balls: Array = []
var target := TARGET_BASE
var mouse := Vector2(640, 360)
var aim := Vector2.ZERO
var dunked := false
var lights_t := 0.0
var lever := 0.0


func _init() -> void:
	scene_id = "carnival"


func hint() -> String:
	return "Click to throw! Hit the bullseye to dunk him."


func idle_lines() -> Array:
	return ["taunt", "taunt2", "nyah"] if not dunked else []


func setup() -> void:
	spawn_bro(Vector2(1030, SEAT_Y), 0.9)
	bro.sitting = true
	bro.set_mood("smug")
	bro.arm_l = 0.7
	bro.arm_r = 2.6
	bro.elbow_r = 1.4
	get_tree().create_timer(1.6).timeout.connect(func(): chat("taunt"))


func debug_state(n: int) -> void:
	rage = 50
	if n == 2:
		_dunk(true)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		balls.append({"from": Vector2(180, 760), "to": aim, "t": 0.0})
		Game.sfx("throw")


func tick(dt: float) -> void:
	lights_t += dt
	lever = move_toward(lever, 0.0, dt * 2)
	var wob := 10.0 + rage * 0.15
	aim = mouse + Vector2(sin(time * 2.3) + sin(time * 5.1) * 0.5, cos(time * 1.9) + sin(time * 4.3) * 0.5) * wob
	var amp := clampf(rage - 15, 0, 60) * 1.4
	target = TARGET_BASE + Vector2(sin(time * 1.1) * amp, sin(time * 1.7) * amp * 0.4)
	for b in balls.duplicate():
		b.t += dt / 0.45
		if b.t >= 1.0:
			balls.erase(b)
			_land(b.to)


func _land(p: Vector2) -> void:
	var d := p.distance_to(target)
	if d < 62 and not dunked:
		Game.sfx("bell")
		lever = 1.0
		_dunk(d < 20)
	elif d < 62:
		Game.sfx("bonk", 0.1, -4)
	else:
		Game.sfx("thud", 0.2, -8)
		burst(p, 8, [Color("#ffde3b")], 200, 4, 900, 0.4)
		if not dunked and randf() < 0.5:
			bro.set_mood("smug", 1.5)
			chat(["taunt2", "missed", "nyah", "taunt"].pick_random())


func _dunk(perfect: bool) -> void:
	dunked = true
	bro.set_mood("surprised")
	bro.flail(1.0)
	var tw := create_tween()
	tw.tween_property(bro, "position:y", 640.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Game.sfx("splash")
		Game.sfx("bubbles", 0.1, -4)
		bro.wet = 1.0
		bro.say("dunked")
		shake(12)
		burst(Vector2(bro.position.x, TANK.position.y + 30), 60, [Color(0.5, 0.8, 1, 0.9), Color(0.85, 0.95, 1)], 600, 8, 900, 1.2, PI, -PI / 2)
		add_rage(18.0 if perfect else 12.0, Vector2(bro.position.x, 300), "BULLSEYE!" if perfect else "DUNKED!")
		if perfect:
			Game.voice("perfect"))
	tw.tween_interval(2.4)
	tw.tween_callback(func():
		bro.set_mood("angry")
		Game.sfx("splash", 0.2, -8, 1.4))
	tw.tween_property(bro, "position:y", SEAT_Y, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		dunked = false
		bro.set_mood("smug")
		chat(["revenge", "taunt", "grr"].pick_random()))


func _draw() -> void:
	sky(Color("#160c3a"), Color("#5a2a7a"), 520)
	for i in 30:
		draw_circle(Vector2(fmod(i * 191.0, 1280), fmod(i * 67.0, 300)), 2, Color(1, 1, 1, 0.5 + 0.5 * sin(time + i)))
	# ferris wheel
	var fw := Vector2(250, 300)
	for k in 12:
		var a := time * 0.3 + k * TAU / 12
		draw_line(fw, fw + Vector2.from_angle(a) * 190, Color("#ffde3b", 0.5), 3)
		draw_circle(fw + Vector2.from_angle(a) * 190, 14, Color.from_hsv(k / 12.0, 0.7, 1.0))
	draw_arc(fw, 190, 0, TAU, 48, Color("#ffde3b", 0.6), 4)
	draw_line(fw, fw + Vector2(-80, 240), Color("#888"), 8)
	draw_line(fw, fw + Vector2(80, 240), Color("#888"), 8)
	# tents
	for t in [[Vector2(560, 520), Color("#ff5a4f")], [Vector2(1180, 500), Color("#3bb0ff")]]:
		var c: Vector2 = t[0]
		for k in 6:
			var x0 := c.x - 150 + k * 50
			draw_colored_polygon(PackedVector2Array([Vector2(c.x, c.y - 220), Vector2(x0, c.y), Vector2(x0 + 50, c.y)]),
				t[1] if k % 2 == 0 else Color.WHITE)
	# ground
	draw_rect(Rect2(0, 520, 1280, 200), Color("#3a2a4a"))
	draw_rect(Rect2(0, 650, 1280, 70), Color("#2a1f36"))
	# string lights
	for k in 26:
		var x := k * 52.0
		var y := 80 + sin(k * 0.6) * 20
		var on := fmod(lights_t * 3 + k, 3.0) < 2.0
		draw_circle(Vector2(x, y), 6, Color.from_hsv(fmod(k * 0.13, 1.0), 0.7, 1.0 if on else 0.4))
	# target pole + bullseye
	draw_line(Vector2(target.x, target.y + 60), Vector2(target.x, 640), Color("#bbb"), 10)
	for i in 4:
		draw_circle(target, 62 - i * 15, Color("#ff3b3b") if i % 2 == 0 else Color.WHITE)
	draw_circle(target, 10, Color("#ffde3b"))
	# lever arm to tank
	draw_line(Vector2(target.x + 30, 420), Vector2(TANK.position.x, 420 + lever * 30), Color("#888"), 8)
	# tank back + seat
	draw_rect(Rect2(TANK.position, TANK.size), Color("#1e5a8a"))
	draw_rect(Rect2(TANK.position.x - 10, 150, 20, TANK.end.y - 150), Color("#aaa"))
	draw_rect(Rect2(TANK.end.x - 10, 150, 20, TANK.end.y - 150), Color("#aaa"))
	rrect(Rect2(TANK.position.x - 20, 140, TANK.size.x + 40, 50), Color("#ff5a4f"), 8)
	draw_string(ThemeDB.fallback_font, Vector2(TANK.position.x + 40, 178), "DUNK THE BRO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	var seat_drop := 0.0 if not dunked else 1.0
	draw_set_transform(Vector2(TANK.position.x + 10, SEAT_Y - 30), seat_drop * 1.2, Vector2.ONE)
	draw_rect(Rect2(0, 0, 230, 16), Color("#8a5a3c"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _foreground(ci: CanvasItem) -> void:
	# water + glass in front of Bro
	var wl := TANK.position.y + 40 + sin(time * 3) * 4
	var pts := PackedVector2Array([Vector2(TANK.position.x, TANK.end.y)])
	for i in 12:
		pts.append(Vector2(TANK.position.x + i * TANK.size.x / 11.0, wl + sin(time * 4 + i) * 5))
	pts.append(TANK.end)
	ci.draw_colored_polygon(pts, Color(0.3, 0.65, 1.0, 0.6))
	ci.draw_rect(Rect2(TANK.position, TANK.size), Color(0.8, 0.95, 1, 0.12))
	ci.draw_rect(Rect2(TANK.position, TANK.size), Color("#cfe8ff"), false, 6)
	ci.draw_line(TANK.position + Vector2(30, 30), TANK.position + Vector2(30, 180), Color(1, 1, 1, 0.4), 6)
	# balls in flight
	for b in balls:
		var t: float = b.t
		var p: Vector2 = (b.from as Vector2).lerp(b.to, t) + Vector2(0, -sin(t * PI) * 180)
		ci.draw_circle(p, lerpf(26, 14, t), Color("#ffde3b"))
		ci.draw_arc(p, lerpf(26, 14, t), 0, TAU, 16, Color("#c9a020"), 3)
	# wobbly crosshair
	ci.draw_arc(aim, 24, 0, TAU, 24, Color(1, 1, 1, 0.9), 3)
	ci.draw_circle(aim, 4, Color(1, 0.3, 0.3))
	ci.draw_line(aim + Vector2(-34, 0), aim + Vector2(-16, 0), Color.WHITE, 3)
	ci.draw_line(aim + Vector2(34, 0), aim + Vector2(16, 0), Color.WHITE, 3)
	ci.draw_line(aim + Vector2(0, -34), aim + Vector2(0, -16), Color.WHITE, 3)
	ci.draw_line(aim + Vector2(0, 34), aim + Vector2(0, 16), Color.WHITE, 3)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))
