extends "res://scripts/minigame.gd"
## Kitchen: throw cream pies at Bro while he dodges behind the counter.
## He ducks and sometimes blocks with a frying pan.

const COUNTER_Y := 470.0

var pies: Array = []
var splats: Array = []
var cooldown := 0.0
var target_x := 640.0
var state := "walk"
var state_t := 2.0
var duck := 0.0
var pan := 0.0
var wipe_t := 0.0
var mouse := Vector2(640, 360)


func _init() -> void:
	scene_id = "kitchen"


func hint() -> String:
	return "Click to throw a pie at his face! Watch out for the frying pan."


func idle_lines() -> Array:
	return ["kitchen_hi", "nyah", "tooslow", "whatdoing"]


func setup() -> void:
	spawn_bro(Vector2(640, 520), 0.95)
	bro.hide_legs = true
	get_tree().create_timer(1.8).timeout.connect(func(): chat("kitchen_hi"))


func debug_state(n: int) -> void:
	bro.pie = 0.8
	bro.set_mood("angry")
	rage = 60
	splats.append({"p": Vector2(300, 260), "a": 1.0})
	if n == 2:
		pan = 2.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		if cooldown <= 0:
			cooldown = 0.35
			pies.append({"from": Vector2(640 + randf_range(-60, 60), 780), "to": e.position, "t": 0.0, "spin": randf_range(-4, 4)})
			Game.sfx("throw")


func tick(dt: float) -> void:
	cooldown -= dt
	_bro_ai(dt)
	for p in pies.duplicate():
		p.t += dt / 0.42
		if p.t >= 1.0:
			pies.erase(p)
			_land(p.to)
	for s in splats:
		s.a -= dt * 0.08
	splats = splats.filter(func(s): return s.a > 0)
	if bro.pie > 0:
		wipe_t += dt
		if wipe_t > 4.0:
			bro.pie = maxf(0.0, bro.pie - dt * 0.15)


func _bro_ai(dt: float) -> void:
	state_t -= dt
	var speed := 260.0 + rage * 4.0
	match state:
		"walk":
			bro.position.x = move_toward(bro.position.x, target_x, speed * dt)
			if absf(bro.position.x - target_x) < 4:
				target_x = randf_range(260, 1020)
			if state_t <= 0:
				var r := randf()
				if r < 0.35:
					state = "duck"
					state_t = randf_range(0.8, 1.5)
				elif r < 0.55 and rage > 15:
					state = "pan"
					state_t = randf_range(1.2, 2.0)
				else:
					state_t = randf_range(1.0, 2.5)
					target_x = randf_range(260, 1020)
		"duck", "pan":
			if state_t <= 0:
				state = "walk"
				state_t = randf_range(1.0, 2.5)
	duck = move_toward(duck, 1.0 if state == "duck" else 0.0, dt * 6)
	pan = move_toward(pan, 1.0 if state == "pan" else 0.0, dt * 8)
	bro.position.y = 520 + duck * 200
	bro.arm_r = lerpf(0.25, 2.6, pan)
	bro.elbow_r = lerpf(0.3, 1.6, pan)


func _pan_rect() -> Rect2:
	var hp := bro.head_pos()
	return Rect2(hp + Vector2(-70, -70), Vector2(140, 150))


func _land(p: Vector2) -> void:
	var hp := bro.head_pos()
	var head_hit := p.distance_to(hp) < 62 and duck < 0.5
	var body_hit := Rect2(bro.position.x - 50, hp.y + 40, 100, maxf(0.0, COUNTER_Y - hp.y - 40)).has_point(p) and duck < 0.5
	if pan > 0.7 and _pan_rect().has_point(p):
		Game.sfx("bonk", 0.1, 0, 1.6)
		burst(p, 14, [Color(1, 0.98, 0.9)], 300, 7, 900, 0.7)
		bro.set_mood("smug", 1.5)
		chat("tooslow")
		return
	if head_hit:
		Game.sfx("splat")
		bro.pie = minf(1.0, bro.pie + 0.3)
		wipe_t = 0.0
		bro.set_mood("angry" if rage > 40 else "surprised", 1.5)
		bro.shake(0.4)
		shake(6)
		var bonus := 2.0 if bro.pie >= 0.9 else 0.0
		add_rage(7.0 + bonus, p, "PIE FACE!" if bro.pie < 0.9 else "DOUBLE PIE!")
		burst(p, 26, [Color(1, 0.98, 0.9), Color(1, 0.9, 0.75), Color("#d42033")], 380, 7, 900, 0.8)
		if randf() < 0.6:
			bro.say(["pieface", "hey", "notfunny", "grr", "mom", "mmpie"].pick_random(), false)
	elif body_hit:
		Game.sfx("splat", 0.1, -3)
		add_rage(3.0, p, "SPLAT")
		burst(p, 16, [Color(1, 0.98, 0.9)], 300, 6, 900, 0.6)
		bro.set_mood("hurt", 0.8)
	else:
		Game.sfx("splat", 0.2, -6, 0.8)
		splats.append({"p": p, "a": 1.0})
		burst(p, 12, [Color(1, 0.98, 0.9)], 220, 5, 900, 0.5)
		if randf() < 0.35:
			bro.set_mood("smug", 1.2)
			chat(["missed", "nyah", "tooslow"].pick_random())


func _draw() -> void:
	# wall tiles
	draw_rect(Rect2(0, 0, 1280, 720), Color("#dff3f0"))
	for x in 33:
		for y in 13:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * 40, y * 40, 40, 40), Color("#c8e8e3"))
	# cabinets
	for i in 5:
		rrect(Rect2(60 + i * 180, 70, 160, 120), Color("#e88f5a"), 10, Color("#a85a30"), 4)
		draw_circle(Vector2(140 + i * 180, 170), 7, Color("#fff2c8"))
	# fridge
	rrect(Rect2(1010, 90, 220, 380), Color("#f4f7fb"), 18, Color("#9aa6b8"), 5)
	draw_line(Vector2(1010, 230), Vector2(1230, 230), Color("#9aa6b8"), 4)
	draw_rect(Rect2(1200, 140, 10, 60), Color("#9aa6b8"))
	draw_rect(Rect2(1200, 260, 10, 90), Color("#9aa6b8"))
	# drawings on the fridge
	draw_rect(Rect2(1040, 260, 70, 60), Color("#fff"))
	Bro.draw_head(self, Vector2(1075, 292), 18, "angry", Vector2.ZERO, false, 0.6)
	# window
	rrect(Rect2(380, 230, 260, 170), Color("#8fd3ff"), 8, Color("#e88f5a"), 10)
	# wall splats
	for s in splats:
		var c := Color(1, 0.97, 0.88, s.a)
		draw_circle(s.p, 34, c)
		for k in 7:
			draw_circle(s.p + Vector2.from_angle(k * 0.9) * 36, 12, c)
		draw_rect(Rect2(s.p.x - 6, s.p.y, 12, 50 * s.a), c)


func _foreground(ci: CanvasItem) -> void:
	# counter (in front of Bro)
	ci.draw_rect(Rect2(0, COUNTER_Y, 1280, 250), Color("#8a5a3c"))
	ci.draw_rect(Rect2(0, COUNTER_Y - 18, 1280, 26), Color("#f0e6d8"))
	for i in 8:
		FX.rounded_rect(ci, Rect2(20 + i * 160, COUNTER_Y + 40, 140, 160), Color("#a26d4b"), 8, Color("#6e4226"), 3)
	# frying pan
	if pan > 0.05:
		var hp := bro.head_pos()
		var c := hp + Vector2(10, 10 + (1.0 - pan) * 200)
		ci.draw_line(c + Vector2(40, 40), c + Vector2(110, 120), Color("#3a3030"), 14)
		ci.draw_circle(c, 78, Color("#2d2d33"))
		ci.draw_circle(c, 66, Color("#45454f"))
		ci.draw_arc(c + Vector2(-18, -18), 40, PI, PI * 1.4, 8, Color(1, 1, 1, 0.3), 6)
	# pies in flight
	for p in pies:
		var t: float = p.t
		var pos: Vector2 = (p.from as Vector2).lerp(p.to, t) + Vector2(0, -sin(t * PI) * 160)
		var s := lerpf(1.7, 0.9, t)
		ci.draw_set_transform(pos, t * float(p.spin), Vector2(s, s))
		ci.draw_colored_polygon(FX.ellipse(Vector2.ZERO, 46, 30), Color("#c98b4a"))
		ci.draw_colored_polygon(FX.ellipse(Vector2(0, -4), 40, 24), Color(1, 0.98, 0.9))
		ci.draw_circle(Vector2(0, -10), 7, Color("#d42033"))
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# crosshair
	ci.draw_arc(mouse, 26, 0, TAU, 24, Color(1, 0.2, 0.3, 0.8), 3)
	ci.draw_line(mouse + Vector2(-34, 0), mouse + Vector2(-14, 0), Color(1, 0.2, 0.3, 0.8), 3)
	ci.draw_line(mouse + Vector2(34, 0), mouse + Vector2(14, 0), Color(1, 0.2, 0.3, 0.8), 3)


func _enter_tree() -> void:
	var fg := FX.Layer.new(_foreground, 5)
	add_child(fg)
