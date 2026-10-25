extends "res://scripts/minigame.gd"
## Living Room: Interactive-Buddy style ragdoll sandbox.
## Grab and fling him, poke him, tickle him, bonk him with balls, and hide a
## whoopee cushion for him to land on.

const FLOOR := 640.0
const GRAV := 1700.0
const SUB := 2
enum { HEAD, NECK, PELVIS, LEL, LHA, REL, RHA, LKN, LFT, RKN, RFT }
const STICKS := [[HEAD, NECK, 50.0], [NECK, PELVIS, 95.0], [HEAD, PELVIS, 145.0],
	[NECK, LEL, 46.0], [LEL, LHA, 44.0], [NECK, REL, 46.0], [REL, RHA, 44.0],
	[PELVIS, LKN, 50.0], [LKN, LFT, 48.0], [PELVIS, RKN, 50.0], [RKN, RFT, 48.0]]
const RADII := [48.0, 22.0, 26.0, 12.0, 14.0, 12.0, 14.0, 14.0, 16.0, 14.0, 16.0]
const TOOLS := [["hand", "Grab & Fling"], ["poke", "Poke"], ["feather", "Tickle"],
	["ball", "Bouncy Ball"], ["cushion", "Whoopee Cushion"]]

var pos: Array[Vector2] = []
var prev: Array[Vector2] = []
var grabbed := -1
var grab_off := Vector2.ZERO
var tool := "hand"
var stun := 0.0
var stand := 1.0
var dizzy := 0.0
var tickle := 0.0
var tickle_reward := 0.0
var hit_cd := 0.0
var mouse := Vector2.ZERO
var last_mouse := Vector2.ZERO
var mouse_down := false
var balls: Array = []
var cushion := Vector2(-200, FLOOR)
var cushion_squash := 0.0
var cushion_cd := 0.0
var tool_buttons := {}


func _init() -> void:
	scene_id = "living_room"


func hint() -> String:
	return ""


func idle_lines() -> Array:
	return ["tvtime", "whatdoing", "leavemealone", "ugh"]


func setup() -> void:
	bro = spawn_bro(Vector2(640, 600))
	bro.visible = false
	var base := Vector2(640, FLOOR)
	var rest := [Vector2(0, -241), Vector2(0, -191), Vector2(0, -96), Vector2(-34, -150),
		Vector2(-40, -106), Vector2(34, -150), Vector2(40, -106), Vector2(-16, -50),
		Vector2(-22, -16), Vector2(16, -50), Vector2(22, -16)]
	for p in rest:
		pos.append(base + p)
		prev.append(base + p)
	_build_toolbar()
	hint_label.visible = false


func _build_toolbar() -> void:
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
		b.pressed.connect(_select_tool.bind(t[0]))
		row.add_child(b)
		tool_buttons[t[0]] = b


func _select_tool(t: String) -> void:
	tool = t
	Game.sfx("click")
	for k in tool_buttons:
		tool_buttons[k].button_pressed = k == t


func debug_state(n: int) -> void:
	if n == 1:
		for i in pos.size():
			pos[i] += Vector2(-200, -150)
		stun = 2.0
		tickle = 1.0
	if n == 2:
		cushion = Vector2(500, FLOOR)
		balls.append({"p": Vector2(800, 300), "v": Vector2.ZERO, "r": 24.0, "c": Color("#ff5a4f"), "age": 0.0})
		rage = 85


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		mouse_down = e.pressed
		if e.pressed:
			# a touch starts here with no prior motion; don't treat the jump as a fling
			last_mouse = e.position
			_press(e.position)
		elif grabbed >= 0:
			_release()


func _nearest(p: Vector2, extra := 20.0) -> int:
	var best := -1
	var bd := 1e9
	for i in pos.size():
		var d: float = pos[i].distance_to(p) - RADII[i]
		if d < extra and d < bd:
			bd = d
			best = i
	if best == -1:
		# allow grabbing the torso anywhere along the spine
		var q := Geometry2D.get_closest_point_to_segment(p, pos[NECK], pos[PELVIS])
		if q.distance_to(p) < 45:
			best = NECK if q.distance_to(pos[NECK]) < q.distance_to(pos[PELVIS]) else PELVIS
	return best


func _press(p: Vector2) -> void:
	match tool:
		"hand":
			grabbed = _nearest(p, 25)
			if grabbed >= 0:
				grab_off = pos[grabbed] - p
				stun = 1.5
				Game.sfx("pop")
				dizzy = 0.0
				if randf() < 0.5:
					bro.say(["putmedown", "hey", "whoa"].pick_random(), false)
				bro.set_mood("surprised", 1.0)
		"poke":
			var i := _nearest(p, 15)
			if i >= 0:
				var dir := (pos[i] - p).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.UP
				prev[i] -= dir * 14.0
				stun = maxf(stun, 0.5)
				Game.sfx("poke")
				bro.set_mood("hurt", 0.6)
				add_rage(2.0 if i != HEAD else 3.0, p, "POKE")
				if randf() < 0.45:
					bro.say(["ow", "hey", "stop", "quit"].pick_random(), false)
		"ball":
			if balls.size() >= 6:
				balls.pop_front()
			var v := (mouse - last_mouse) * 30.0
			balls.append({"p": p, "v": v + Vector2(randf_range(-80, 80), 0), "r": 24.0,
				"c": [Color("#ff5a4f"), Color("#ffde3b"), Color("#5ad1ff"), Color("#7dff6a")].pick_random(), "age": 0.0})
			Game.sfx("boing", 0.2)
		"cushion":
			cushion = Vector2(clampf(p.x, 80, 1200), FLOOR)
			cushion_squash = 0.0
			Game.sfx("pop")


func _release() -> void:
	grabbed = -1
	if dizzy > 9.0:
		bro.set_mood("dizzy", 4.0)
		bro.say("dizzy")
		add_rage(6.0, pos[HEAD], "DIZZY!")
	elif dizzy > 3.0:
		bro.say("whoa", false)
	stun = 1.5
	dizzy = 0.0


# ------------------------------------------------------------------ physics

func _physics_process(dt: float) -> void:
	var h := dt / SUB
	var mvel := (mouse - last_mouse)
	if grabbed >= 0:
		dizzy += mvel.length() / 120.0 * (1.0 if mvel.length() > 25 else 0.0)
	for s in SUB:
		var target := last_mouse.lerp(mouse, float(s + 1) / SUB) + grab_off
		for i in pos.size():
			if i == grabbed:
				prev[i] = pos[i]
				pos[i] = target
				continue
			var v := (pos[i] - prev[i]) * 0.996
			prev[i] = pos[i]
			pos[i] += v + Vector2(0, GRAV * h * h)
		_muscles(h)
		for k in 5:
			for st in STICKS:
				_constrain(st[0], st[1], st[2])
		_collide()
	last_mouse = mouse
	_update_balls(dt)


func _constrain(a: int, b: int, length: float) -> void:
	var d := pos[b] - pos[a]
	var dist := d.length()
	if dist < 0.001:
		return
	var diff := (dist - length) / dist
	if a == grabbed:
		pos[b] -= d * diff
	elif b == grabbed:
		pos[a] += d * diff
	else:
		pos[a] += d * diff * 0.5
		pos[b] -= d * diff * 0.5


func _muscles(h: float) -> void:
	if grabbed >= 0 or stun > 0 or tickle > 0.2:
		return
	var k := 0.045 * stand
	var px := pos[PELVIS].x
	var sway := sin(time * 1.3) * 4.0
	var base := FLOOR
	var targets := {
		PELVIS: Vector2(px, base - 96), NECK: Vector2(px + sway, base - 191),
		HEAD: Vector2(px + sway * 1.5, base - 241), LKN: Vector2(px - 16, base - 50),
		RKN: Vector2(px + 16, base - 50), LFT: Vector2(px - 22, base - 16), RFT: Vector2(px + 22, base - 16),
		LEL: Vector2(px - 36 + sway, base - 150), REL: Vector2(px + 36 + sway, base - 150),
		LHA: Vector2(px - 42, base - 106), RHA: Vector2(px + 42, base - 106),
	}
	if bro.mood == "angry" or rage > 80:
		targets[LHA] = Vector2(px - 30, base - 140)
		targets[RHA] = Vector2(px + 30, base - 140)
	for i in targets:
		pos[i] += (targets[i] - pos[i]) * k


func _collide() -> void:
	for i in pos.size():
		var r: float = RADII[i]
		var v := pos[i] - prev[i]
		var hit := 0.0
		if pos[i].y > FLOOR - r:
			hit = maxf(hit, v.y)
			pos[i].y = FLOOR - r
			prev[i].y = pos[i].y + v.y * 0.35
			prev[i].x = pos[i].x - v.x * 0.75
		if pos[i].y < 60 + r:
			hit = maxf(hit, -v.y)
			pos[i].y = 60 + r
			prev[i].y = pos[i].y + v.y * 0.4
		if pos[i].x < r:
			hit = maxf(hit, -v.x)
			pos[i].x = r
			prev[i].x = pos[i].x + v.x * 0.4
		if pos[i].x > 1280 - r:
			hit = maxf(hit, v.x)
			pos[i].x = 1280 - r
			prev[i].x = pos[i].x + v.x * 0.4
		if hit * 60 * SUB > 1100 and hit_cd <= 0 and i != grabbed:
			_impact(i, hit * 60 * SUB)


func _impact(i: int, speed: float) -> void:
	hit_cd = 0.35
	stun = maxf(stun, 1.6)
	stand = 0.0
	var big := speed > 1900
	Game.sfx("thud" if big else "bonk", 0.15)
	shake(10.0 if big else 4.0)
	bro.set_mood("hurt", 1.2)
	add_rage(clampf(speed / 300.0, 2.0, 9.0), pos[i], "SMACK!" if big else "BONK")
	burst(pos[i], 10, [Color(1, 1, 1, 0.8), Color("#ffde3b")], 250, 5, 600, 0.5)
	if randf() < 0.6:
		bro.say(["ow", "ouch", "oof", "notfunny", "mom", "telling"].pick_random(), false)


func _update_balls(dt: float) -> void:
	for b in balls:
		b.age += dt
		b.v.y += GRAV * dt
		b.p += b.v * dt
		var r: float = b.r
		if b.p.y > FLOOR - r:
			b.p.y = FLOOR - r
			b.v.y *= -0.8
			b.v.x *= 0.98
		if b.p.x < r or b.p.x > 1280 - r:
			b.p.x = clampf(b.p.x, r, 1280 - r)
			b.v.x *= -0.85
		for i in pos.size():
			var d: Vector2 = pos[i] - b.p
			var min_d: float = RADII[i] + r
			if d.length() < min_d and d.length() > 0.01:
				var n := d.normalized()
				var pv := (pos[i] - prev[i]) * 60.0 * SUB
				var rel: float = (b.v - pv).dot(n)
				if rel > 0:
					b.v -= n * rel * 1.6
					prev[i] -= n * rel / (60.0 * SUB) * 0.6
					if rel > 420 and hit_cd <= 0:
						hit_cd = 0.25
						stun = maxf(stun, 0.8)
						Game.sfx("bonk", 0.2)
						bro.set_mood("hurt", 0.8)
						add_rage(3.0 if i == HEAD else 2.0, b.p, "BONK!")
						if randf() < 0.35:
							bro.say(["ow", "hey", "ohcomeon"].pick_random(), false)
				b.p = pos[i] - n * min_d


# ------------------------------------------------------------------ per-frame

func tick(dt: float) -> void:
	hit_cd -= dt
	cushion_cd -= dt
	cushion_squash = maxf(0.0, cushion_squash - dt * 0.6)
	var speed := 0.0
	for i in pos.size():
		speed += (pos[i] - prev[i]).length()
	if grabbed < 0 and speed < 3.0:
		stun -= dt
	if stun <= 0:
		stand = minf(1.0, stand + dt * 0.7)
	# tickling
	if tool == "feather" and mouse_down:
		var near := _nearest(mouse, 30) >= 0
		var mv := (mouse - last_mouse).length()
		if near and mv > 1.0:
			tickle = minf(tickle + dt * 2.5, 1.5)
			tickle_reward += dt
			if tickle_reward > 0.6:
				tickle_reward = 0.0
				add_rage(2.5, mouse, "TICKLE")
				Game.sfx("giggle", 0.2, -4)
			bro.set_mood("laugh", 0.5)
			if not Game.voice_busy() and randf() < 0.02:
				bro.say("tickle", false)
	tickle = maxf(0.0, tickle - dt)
	if tickle > 0.2:
		for i in [LHA, RHA, LFT, RFT]:
			prev[i] += Vector2(randf_range(-4, 4), randf_range(-4, 4))
	# whoopee cushion
	if cushion.x > 0 and cushion_cd <= 0:
		var p := pos[PELVIS]
		var v := (p - prev[PELVIS]).y
		if absf(p.x - cushion.x) < 60 and p.y > FLOOR - 75 and v > 0.5:
			cushion_cd = 2.5
			cushion_squash = 1.0
			Game.sfx("fart", 0.15)
			bro.set_mood("surprised", 2.0)
			add_rage(9.0, cushion + Vector2(0, -60), "PFFFRT!")
			burst(cushion + Vector2(0, -10), 18, [Color(0.75, 0.9, 0.5, 0.6)], 200, 10, -60, 1.2)
			get_tree().create_timer(0.5).timeout.connect(func(): bro.say("wasntme"))
	# keep the hidden Bro node over the head so speech bubbles follow
	bro.position = pos[HEAD] + Vector2(0, 250)
	bro.look_at_mouse = true


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	# wallpaper
	draw_rect(Rect2(0, 0, 1280, FLOOR), Color("#f3d9a4"))
	for i in 32:
		draw_rect(Rect2(i * 40, 0, 18, FLOOR), Color("#ecc98a"))
	draw_rect(Rect2(0, FLOOR - 40, 1280, 40), Color("#c98d55"))
	# window
	rrect(Rect2(140, 130, 260, 200), Color("#7a4a2a"), 8)
	draw_rect(Rect2(152, 142, 236, 176), Color("#8fd3ff"))
	draw_circle(Vector2(340, 190), 30, Color("#fff4a0"))
	draw_rect(Rect2(266, 142, 8, 176), Color("#7a4a2a"))
	draw_rect(Rect2(152, 226, 236, 8), Color("#7a4a2a"))
	# picture
	rrect(Rect2(560, 120, 160, 120), Color("#5a3418"), 6)
	draw_rect(Rect2(572, 132, 136, 96), Color("#bfe6b0"))
	Bro.draw_head(self, Vector2(615, 185), 22, "smug", Vector2.ZERO, false, 0)
	Bro.draw_head(self, Vector2(668, 192), 16, "sad", Vector2.ZERO, false, 0)
	# couch
	rrect(Rect2(60, 470, 360, 130), Color("#b5482f"), 26)
	rrect(Rect2(80, 420, 320, 90), Color("#c95a3d"), 26)
	rrect(Rect2(40, 470, 60, 140), Color("#9a3a25"), 22)
	rrect(Rect2(380, 470, 60, 140), Color("#9a3a25"), 22)
	# TV
	draw_rect(Rect2(960, 520, 240, 120), Color("#6b4428"))
	rrect(Rect2(950, 330, 260, 180), Color("#222"), 14)
	var tvc := Color.from_hsv(fmod(time * 0.1, 1.0), 0.5, 0.9)
	draw_rect(Rect2(966, 346, 228, 148), tvc)
	draw_circle(Vector2(1080, 420 + sin(time * 3) * 20), 24, tvc.inverted())
	# lamp
	draw_line(Vector2(860, FLOOR), Vector2(860, 380), Color("#444"), 6)
	draw_colored_polygon(PackedVector2Array([Vector2(820, 380), Vector2(900, 380), Vector2(880, 320), Vector2(840, 320)]), Color("#ffb347"))
	# floor + rug
	draw_rect(Rect2(0, FLOOR, 1280, 80), Color("#8b5a34"))
	for i in 9:
		draw_line(Vector2(i * 160, FLOOR), Vector2(i * 160 - 40, 720), Color("#6e4426"), 3)
	ellipse(Vector2(640, FLOOR + 22), 330, 26, Color("#5b8bd1"))
	ellipse(Vector2(640, FLOOR + 22), 280, 18, Color("#7ba7e6"))
	# cushion
	if cushion.x > 0:
		var sq := 1.0 - cushion_squash * 0.6
		ellipse(cushion + Vector2(0, -16 * sq), 56, 18 * sq + 4, Color("#ff6f86"))
		ellipse(cushion + Vector2(-50, -12 * sq), 10, 7, Color("#e04a6a"))
		draw_circle(cushion + Vector2(10, -24 * sq), 6, Color(1, 1, 1, 0.5))
	_draw_ragdoll()
	for b in balls:
		draw_circle(b.p, b.r, b.c)
		draw_circle(b.p + Vector2(-8, -8), b.r * 0.3, Color(1, 1, 1, 0.5))
		draw_arc(b.p, b.r, 0, TAU, 24, Color(0, 0, 0, 0.3), 3)
	_draw_cursor()


func _draw_ragdoll() -> void:
	var red := rage / 100.0
	var skin := Bro.SKIN
	var shirt := Bro.SHIRT
	var pants := Bro.PANTS
	for leg in [[LKN, LFT], [RKN, RFT]]:
		Bro.limb(self, pos[PELVIS], pos[leg[0]], 30, pants)
		Bro.limb(self, pos[leg[0]], pos[leg[1]], 28, pants)
		var d: Vector2 = (pos[leg[1]] - pos[leg[0]]).normalized()
		draw_set_transform(pos[leg[1]] + d * 8, d.angle() - PI / 2, Vector2.ONE)
		draw_colored_polygon(FX.ellipse(Vector2(0, 0), 20, 14), Bro.SHOE)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var along := (pos[PELVIS] - pos[NECK]).normalized()
	var perp := along.orthogonal()
	Bro.limb(self, pos[NECK] + along * 10, pos[PELVIS], 84, shirt)
	var mid := pos[NECK].lerp(pos[PELVIS], 0.45)
	draw_line(mid - perp * 38, mid + perp * 38, shirt.lightened(0.25), 14)
	Bro.limb(self, pos[PELVIS] - along * 6 - perp * 34, pos[PELVIS] - along * 6 + perp * 34, 14, pants.darkened(0.2))
	for arm in [[LEL, LHA, -1], [REL, RHA, 1]]:
		var sh: Vector2 = pos[NECK] + along * 18 - perp * 36 * arm[2]
		Bro.limb(self, sh, pos[arm[0]], 24, shirt)
		Bro.limb(self, pos[arm[0]], pos[arm[1]], 20, skin)
		draw_circle(pos[arm[1]], 14, skin)
	var up := (pos[HEAD] - pos[NECK])
	draw_set_transform(pos[HEAD], up.angle() + PI / 2, Vector2.ONE)
	Bro.draw_head(self, Vector2.ZERO, 48, bro.mood, bro.look, bro._blink > 0, red, {"t": time})
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_cursor() -> void:
	var m := mouse
	match tool:
		"hand":
			var closed := grabbed >= 0
			draw_circle(m, 16 if closed else 18, Color("#ffe0c0"))
			if not closed:
				for k in 4:
					draw_line(m + Vector2(-12 + k * 8, -10), m + Vector2(-14 + k * 9, -30), Color("#ffe0c0"), 8)
			draw_arc(m, 18, 0, TAU, 20, Color(0, 0, 0, 0.4), 2)
		"poke":
			draw_line(m + Vector2(30, 30), m, Color("#ffe0c0"), 12)
			draw_circle(m, 6, Color("#ffe0c0"))
			draw_circle(m + Vector2(34, 34), 16, Color("#ffe0c0"))
		"feather":
			var a := sin(time * 12) * 0.4 if mouse_down else 0.0
			draw_set_transform(m, -0.7 + a, Vector2.ONE)
			draw_colored_polygon(FX.ellipse(Vector2(0, -30), 12, 34, 16), Color("#b48cff"))
			draw_line(Vector2(0, 0), Vector2(0, -62), Color("#6a3fc2"), 3)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"ball":
			draw_arc(m, 24, 0, TAU, 24, Color(1, 1, 1, 0.8), 3)
		"cushion":
			ellipse(Vector2(m.x, FLOOR - 16), 56, 18, Color(1, 0.45, 0.55, 0.4))
