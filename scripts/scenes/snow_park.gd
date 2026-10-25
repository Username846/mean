extends "res://scripts/minigame.gd"
## Snow Park: Bro pops up from behind snow forts. Peg him with snowballs!
## Don't waste throws on the snowmen, and wipe his snowballs off your screen.

const FORTS := [180.0, 420.0, 660.0, 900.0, 1120.0]
const BASE := 600.0
const SC := 0.72

var fort := 2
var state := "hidden"
var state_t := 1.0
var rise := 0.0
var throwing := false
var balls: Array = []
var incoming: Array = []
var splats: Array = []
var snowmen := {}
var flakes: Array = []
var mouse := Vector2.ZERO
var held := 0                ## 0 nothing, 1 snowball, 2 snowball with a rock inside
const PILE := Vector2(110, 655)
const ROCKS := [Vector2(330, 692), Vector2(560, 700), Vector2(820, 694), Vector2(1060, 700)]


func _init() -> void:
	scene_id = "snow_park"


func hint() -> String:
	return "Grab a snowball from the pile (lower left), then click Bro to throw it!"


func idle_lines() -> Array:
	return []


func setup() -> void:
	spawn_bro(Vector2(FORTS[fort], BASE + 260), SC)
	for i in 70:
		flakes.append(Vector2(randf() * 1280, randf() * 720))
	get_tree().create_timer(1.5).timeout.connect(func(): bro.say("snowfight"))
	hint_label.position.y = 64


func debug_state(n: int) -> void:
	state = "up"
	state_t = 99
	rise = 1.0
	bro.snow = 0.5
	snowmen[0] = 1.0
	splats.append({"p": Vector2(900, 300), "r": 120.0, "a": 1.0})
	if n == 2:
		throwing = true


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		for s in splats:
			if e.position.distance_to(s.p) < s.r:
				splats.erase(s)
				Game.sfx("wipe")
				burst(e.position, 14, [Color.WHITE], 250, 8, 900, 0.6)
				return
		if e.position.distance_to(PILE) < 80:
			held = 1
			Game.sfx("crunch", 0.1)
			FX.float_text(fx_layer, PILE + Vector2(60, -60), "Got a snowball!", Color.WHITE, 24)
			return
		for r in ROCKS:
			if e.position.distance_to(r) < 34:
				if held == 1:
					held = 2
					Game.sfx("click", 0.0)
					FX.float_text(fx_layer, r + Vector2(0, -50), "Rock packed inside...", Color("#c8c8d0"), 24)
				elif held == 0:
					FX.float_text(fx_layer, r + Vector2(0, -50), "Make a snowball first!", Color.WHITE, 22)
				return
		if held == 0:
			Game.sfx("click", 0.0, -6)
			FX.float_text(fx_layer, PILE + Vector2(80, -70), "Grab a snowball here!", Color("#ffde3b"), 26)
			return
		balls.append({"from": Vector2(640 + randf_range(-40, 40), 760), "to": e.position, "t": 0.0, "rock": held == 2})
		held = 0
		Game.sfx("throw", 0.2)


func _pick_fort() -> void:
	var choices := []
	for i in FORTS.size():
		if i != fort and not snowmen.has(i):
			choices.append(i)
	fort = choices.pick_random()
	bro.position.x = FORTS[fort]


func tick(dt: float) -> void:
	state_t -= dt
	var speed := 1.0 + rage / 80.0
	if injured:
		state = "hurt"
	match state:
		"hidden":
			rise = move_toward(rise, 0.0, dt * 6)
			if state_t <= 0 and rise <= 0:
				_pick_fort()
				state = "up"
				throwing = randf() < 0.3 + rage / 300.0
				state_t = randf_range(0.9, 1.7) / speed + (0.8 if throwing else 0.0)
				Game.sfx("crunch", 0.2, -8)
				bro.set_mood("smug" if not throwing else "angry")
				# sometimes a snowman pops up somewhere else
				if randf() < 0.45:
					var free := []
					for i in FORTS.size():
						if i != fort:
							free.append(i)
					snowmen[free.pick_random()] = 0.0
		"up":
			rise = move_toward(rise, 1.0, dt * 6)
			if throwing and state_t < 0.4:
				throwing = false
				incoming.append({"t": 0.0, "from": bro.head_pos() + Vector2(30, -20), "to": Vector2(randf_range(250, 1030), randf_range(180, 520))})
				Game.sfx("throw", 0.1, 0, 0.8)
			if state_t <= 0:
				_duck(randf_range(0.4, 1.2) / speed)
	if state != "hurt":
		bro.position.y = BASE + 260 * (1.0 - rise) + (sin(time * 8) * 3 if rise > 0.9 else 0.0)
	bro.arm_r = 2.8 if throwing else 0.3
	bro.elbow_r = 1.0 if throwing else 0.3
	bro.snow = maxf(0.0, bro.snow - dt * 0.05)
	for k in snowmen.keys():
		snowmen[k] += dt
		if snowmen[k] > 2.6:
			snowmen.erase(k)
	for b in balls.duplicate():
		b.t += dt / 0.28
		if b.t >= 1.0:
			balls.erase(b)
			_land(b.to, b.rock)
	for b in incoming.duplicate():
		b.t += dt / 0.6
		if b.t >= 1.0:
			incoming.erase(b)
			splats.append({"p": b.to, "r": randf_range(90, 130), "a": 1.0})
			Game.sfx("splat", 0.1, 0, 0.7)
			shake(8)
			bro.say(["gotcha", "nyah", "tooslow"].pick_random(), false)
	for i in flakes.size():
		flakes[i] += Vector2(sin(time + i) * 20, 60) * dt
		if flakes[i].y > 720:
			flakes[i] = Vector2(randf() * 1280, -10)


func _duck(wait: float) -> void:
	state = "hidden"
	state_t = wait
	throwing = false


func _land(p: Vector2, rock := false) -> void:
	burst(p, 14, [Color.WHITE, Color("#dff0ff")], 260, 6, 900, 0.5)
	Game.sfx("crunch", 0.2)
	# snowman?
	for k in snowmen.keys():
		var sp := Vector2(FORTS[k], BASE - 150 + _sm_offset(snowmen[k]))
		if p.distance_to(sp) < 70:
			snowmen.erase(k)
			burst(sp, 30, [Color.WHITE], 400, 9, 900, 0.8)
			FX.float_text(fx_layer, sp, "Just a snowman!", Color("#9fd8ff"), 26)
			if randf() < 0.5:
				chat("missed")
			return
	if state == "up" and rise > 0.5:
		var hp := bro.head_pos()
		var head := p.distance_to(hp) < 48 * SC + 14
		var body := Rect2(bro.position.x - 50 * SC, hp.y, 100 * SC, 140 * SC).has_point(p)
		if (head or body) and rock:
			_rock_hit(p)
			return
		if head or body:
			Game.sfx("bonk", 0.1, -3, 1.3)
			bro.snow = minf(1.0, bro.snow + 0.3)
			bro.set_mood("angry" if rage > 50 else "surprised", 1.2)
			bro.shake(0.3)
			add_rage(7.0 if head else 4.0, p, "HEADSHOT!" if head else "THWACK")
			if randf() < 0.55:
				bro.say(["brrr", "cold", "ow", "grr", "notfunny"].pick_random(), false)
			_duck(randf_range(0.5, 1.0))
			return


func _rock_hit(p: Vector2) -> void:
	state = "hurt"
	rise = 1.0
	bro.position.y = BASE
	throwing = false
	Game.sfx("crack", 0.0)
	Game.sfx("bonk", 0.0, 0, 0.7)
	shake(14)
	bro.set_mood("hurt")
	bro.say("aaah")
	burst(p, 24, [Color("#ffe14a"), Color.WHITE, Color("#8a8a92")], 320, 6, 900, 0.8)
	injure("Cracked head from a rock hidden in a snowball", 4.0)
	get_tree().create_timer(0.9).timeout.connect(func():
		bro.set_mood("ko")
		bro.fall_over(1.0, 130.0)
		Game.sfx("thud", 0.0, -4)
		get_tree().create_timer(0.6).timeout.connect(func():
			blood(bro.head_pos() + Vector2(10, 55), 75, 6)))


func _sm_offset(t: float) -> float:
	return (1.0 - clampf(minf(t * 5, (2.6 - t) * 5), 0, 1)) * 200


func _draw() -> void:
	sky(Color("#9ec8ee"), Color("#e8f3ff"), BASE)
	# mountains + trees
	draw_colored_polygon(PackedVector2Array([Vector2(0, 420), Vector2(220, 220), Vector2(420, 420)]), Color("#c6d8ee"))
	draw_colored_polygon(PackedVector2Array([Vector2(300, 420), Vector2(620, 160), Vector2(940, 420)]), Color("#b4cae6"))
	draw_colored_polygon(PackedVector2Array([Vector2(800, 420), Vector2(1080, 240), Vector2(1380, 420)]), Color("#c6d8ee"))
	draw_colored_polygon(PackedVector2Array([Vector2(560, 210), Vector2(620, 160), Vector2(680, 210)]), Color.WHITE)
	for i in 9:
		var x := 40.0 + i * 150
		draw_rect(Rect2(x - 8, 420, 16, 60), Color("#6b4a2a"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 50, 440), Vector2(x + 50, 440), Vector2(x, 330)]), Color("#2f7a4a"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 26, 370), Vector2(x + 26, 370), Vector2(x, 330)]), Color.WHITE)
	draw_rect(Rect2(0, 440, 1280, 280), Color("#f4f9ff"))
	# snowmen (behind the forts)
	for k in snowmen:
		var c := Vector2(FORTS[k], BASE - 150 + _sm_offset(snowmen[k]))
		draw_circle(c + Vector2(0, 70), 56, Color.WHITE)
		draw_circle(c, 40, Color.WHITE)
		draw_arc(c, 40, 0, TAU, 24, Color("#c8d8ea"), 3)
		draw_circle(c + Vector2(-13, -8), 5, Color.BLACK)
		draw_circle(c + Vector2(13, -8), 5, Color.BLACK)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2), c + Vector2(0, 12), c + Vector2(30, 7)]), Color("#ff8a2a"))
		draw_rect(Rect2(c + Vector2(-30, -48), Vector2(60, 10)), Color("#333"))
		draw_rect(Rect2(c + Vector2(-20, -84), Vector2(40, 38)), Color("#333"))


func _foreground(ci: CanvasItem) -> void:
	# forts
	for x in FORTS:
		ci.draw_colored_polygon(FX.ellipse(Vector2(x, BASE + 10), 120, 90), Color("#ffffff"))
		for k in 5:
			FX.rounded_rect(ci, Rect2(x - 110 + k * 44, BASE - 70, 40, 34), Color("#eef6ff"), 8, Color("#c8d8ea"), 2)
	ci.draw_rect(Rect2(0, BASE + 40, 1280, 200), Color("#f4f9ff"))
	for f in flakes:
		ci.draw_circle(f, 3, Color(1, 1, 1, 0.9))
	# snowball pile + rocks
	for k in 7:
		var o := Vector2([-40, 0, 40, -20, 20, 0, -60][k], [0, 0, 0, -30, -30, -58, 4][k])
		ci.draw_circle(PILE + o, 26, Color.WHITE)
		ci.draw_arc(PILE + o, 26, 0, TAU, 16, Color("#b0c4dc"), 2)
	for r in ROCKS:
		ci.draw_colored_polygon(FX.ellipse(r, 22, 14), Color("#7a7a84"))
		ci.draw_colored_polygon(FX.ellipse(r + Vector2(-6, -4), 8, 4), Color("#a0a0aa"))
	# what you're holding
	if held > 0:
		ci.draw_circle(mouse + Vector2(26, 26), 14, Color.WHITE)
		ci.draw_arc(mouse + Vector2(26, 26), 14, 0, TAU, 12, Color("#b0c4dc"), 2)
		if held == 2:
			ci.draw_circle(mouse + Vector2(29, 28), 5, Color("#7a7a84"))
	# my snowballs
	for b in balls:
		var t: float = b.t
		var p: Vector2 = (b.from as Vector2).lerp(b.to, t) + Vector2(0, -sin(t * PI) * 80)
		ci.draw_circle(p, lerpf(30, 12, t), Color.WHITE)
		ci.draw_arc(p, lerpf(30, 12, t), 0, TAU, 16, Color("#b0c4dc"), 2)
		if b.rock:
			ci.draw_circle(p + Vector2(4, 3) * lerpf(1, 0.4, t), lerpf(9, 4, t), Color("#7a7a84"))
	# his snowballs, flying at the screen
	for b in incoming:
		var t: float = b.t
		var p: Vector2 = (b.from as Vector2).lerp(b.to, t)
		var r := lerpf(10, 90, t * t)
		ci.draw_circle(p, r, Color.WHITE)
		ci.draw_arc(p, r, 0, TAU, 24, Color("#b0c4dc"), 3)
	for s in splats:
		var c: Vector2 = s.p
		var r: float = s.r
		for k in 9:
			ci.draw_circle(c + Vector2.from_angle(k * 0.7) * r * 0.65, r * 0.42, Color(1, 1, 1, 0.97))
		ci.draw_circle(c, r * 0.8, Color(1, 1, 1, 0.97))
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-50, 8), "click to wipe", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 0.6, 0.75))
	ci.draw_arc(mouse, 22, 0, TAU, 24, Color(0.9, 0.2, 0.3, 0.8), 3)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	state = "up"
	rise = 1.0
	_rock_hit(bro.head_pos())


## Only while he's popped up from behind a fort.
func blaster_hits(p: Vector2) -> bool:
	return state == "up" and rise > 0.5 and super(p)


func on_blasted(_p: Vector2) -> void:
	state = "hurt"
	rise = 1.0
	bro.position.y = BASE
	throwing = false
	bro.set_mood("hurt")
	bro.say("blasted")
	get_tree().create_timer(0.9).timeout.connect(func():
		bro.set_mood("ko")
		bro.fall_over(1.0, 130.0)
		Game.sfx("thud", 0.0, -4))
