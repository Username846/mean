extends "res://scripts/minigame.gd"
## Treehouse: Bro reads comics up in his treehouse and climbs down the rope
## ladder for snacks. Shake the tree, pelt him with acorns, or send a squirrel
## up after him. An acorn while he's on the ladder knocks him off it.

const GROUND := 640.0
const PLAT_Y := 330.0
const LADDER_X := 822.0
const READ_X := 760.0
const COOLER_X := 1060.0
const SQ_HOME := Vector2(455, 632)
const SC := 0.62
const TOOLS := [["tree_shake", "Shake Tree"], ["acorn", "Acorns"], ["squirrel", "Squirrel"]]

var tool := "tree_shake"
var tool_buttons := {}
var state := "read"   # read, down, walk_out, snack, walk_back, up, fall
var state_t := 8.0
var tree_shake := 0.0
var shake_cd := 0.0
var acorns: Array = []
var sq := {"p": SQ_HOME, "mode": "idle", "t": 0.0}
var sq_cd := 0.0
var mouse := Vector2.ZERO


func _init() -> void:
	scene_id = "treehouse"


func hint() -> String:
	return ""


func idle_lines() -> Array:
	return ["treehouse", "leavemealone", "whatdoing"] if state == "read" else []


func setup() -> void:
	spawn_bro(Vector2(READ_X, PLAT_Y), SC)
	bro.arm_l = -0.5
	bro.arm_r = -0.5
	bro.elbow_l = -1.2
	bro.elbow_r = -1.2
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
	get_tree().create_timer(1.6).timeout.connect(func(): chat("treehouse"))


func _select(t: String) -> void:
	tool = t
	Game.sfx("click")
	for k in tool_buttons:
		tool_buttons[k].button_pressed = k == t


func _on_ladder() -> bool:
	return state in ["down", "up"] and bro.position.y > PLAT_Y + 30 and bro.position.y < GROUND - 20


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	mouse = e.position
	match tool:
		"tree_shake":
			if Rect2(380, 60, 480, 590).has_point(e.position):
				_shake_tree()
		"acorn":
			acorns.append({"from": Vector2(640 + randf_range(-40, 40), 760), "to": e.position, "t": 0.0})
			Game.sfx("throw", 0.2)
		"squirrel":
			_send_squirrel()


func _shake_tree() -> void:
	tree_shake = minf(1.5, tree_shake + 0.4)
	Game.sfx("rustle", 0.2)
	burst(Vector2(randf_range(420, 720), randf_range(80, 200)), 8, [Color("#3f9a3a"), Color("#6cc05a")], 200, 6, 300, 1.4)
	if tree_shake > 0.9 and shake_cd <= 0 and state in ["read", "down", "up"]:
		shake_cd = 1.2
		bro.set_mood("scared", 1.2)
		bro.flail(0.8)
		if state == "read":
			add_rage(5.0, bro.head_pos() + Vector2(0, -40), "COMICS EVERYWHERE!")
			burst(bro.head_pos() + Vector2(0, 60), 12, [Color.WHITE, Color("#ffde3b"), Color("#ff6f86")], 300, 9, 500, 1.6)
			bro.say(["comics", "whoa", "hey"].pick_random(), false)
		else:
			add_rage(4.0, bro.head_pos() + Vector2(0, -40), "WHOA!")
			bro.say(["whoa", "stop"].pick_random(), false)


func _send_squirrel() -> void:
	if sq.mode != "idle" or sq_cd > 0:
		return
	sq.mode = "go"
	sq.t = 0.0
	Game.sfx("chitter", 0.1)


## Hit by an acorn while on the ladder: he falls off and breaks his arm.
func _fall() -> void:
	state = "fall"
	bro.set_mood("scared")
	bro.flail(1.0)
	bro.say("aaah")
	injure("Broken arm from falling off the treehouse ladder", 4.0)
	var tw := create_tween()
	tw.tween_property(bro, "position:y", GROUND, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Game.sfx("crack", 0.0)
		Game.sfx("thud", 0.0)
		shake(14)
		bro.set_mood("ko")
		bro.fall_over(1.0)
		burst(Vector2(bro.position.x, GROUND - 10), 20, [Color("#8a6a3a"), Color("#6cc05a")], 250, 6, 800, 0.8))


# ------------------------------------------------------------------ update

func tick(dt: float) -> void:
	tree_shake = maxf(0.0, tree_shake - dt * 0.9)
	shake_cd -= dt
	sq_cd -= dt
	var sx := sin(time * 40) * tree_shake * 10.0
	_update_acorns(dt)
	_update_squirrel(dt)
	if state == "fall":
		return
	state_t -= dt
	var climb := 120.0
	match state:
		"read":
			bro.position = Vector2(READ_X + sx, PLAT_Y)
			if state_t <= 0:
				state = "down"
				bro.position.x = LADDER_X
		"down":
			bro.position.x = LADDER_X + sx * 0.6
			bro.position.y = move_toward(bro.position.y, GROUND, climb * dt)
			if bro.position.y >= GROUND:
				state = "walk_out"
		"walk_out":
			bro.position.x = move_toward(bro.position.x, COOLER_X, 140 * dt)
			if bro.position.x >= COOLER_X:
				state = "snack"
				state_t = 2.0
				chat("snack")
		"snack":
			if state_t <= 0:
				state = "walk_back"
		"walk_back":
			bro.position.x = move_toward(bro.position.x, LADDER_X, 140 * dt)
			if bro.position.x <= LADDER_X:
				state = "up"
		"up":
			bro.position.x = LADDER_X + sx * 0.6
			bro.position.y = move_toward(bro.position.y, PLAT_Y, climb * dt)
			if bro.position.y <= PLAT_Y:
				state = "read"
				state_t = randf_range(8.0, 12.0)
				bro.set_mood("normal")
	var reading := state == "read"
	bro.arm_l = -0.5 if reading else (2.6 if state in ["down", "up"] else 0.25)
	bro.arm_r = bro.arm_l
	bro.elbow_l = -1.2 if reading else 0.3
	bro.elbow_r = bro.elbow_l


func _update_acorns(dt: float) -> void:
	for c in acorns.duplicate():
		c.t += dt / 0.38
		if c.t < 1.0:
			continue
		acorns.erase(c)
		if injured:
			continue
		var hp := bro.head_pos()
		var on_body := Rect2(-50, -200, 100, 200).has_point(bro.to_local(c.to))
		if _on_ladder() and (c.to.distance_to(hp) < 48 * SC + 18 or on_body):
			Game.sfx("bonk", 0.1)
			_fall()
		elif c.to.distance_to(hp) < 48 * SC + 18:
			Game.sfx("bonk", 0.1)
			bro.set_mood("hurt", 0.8)
			bro.shake(0.3)
			add_rage(5.0, c.to, "BONK!")
			if randf() < 0.5:
				bro.say(["ow", "ouch", "hey", "quit"].pick_random(), false)
		else:
			Game.sfx("thud", 0.2, -10, 1.5)
			burst(c.to, 6, [Color("#8a5a2a")], 150, 4, 900, 0.4)


func _update_squirrel(dt: float) -> void:
	match sq.mode:
		"go":
			sq.t += dt
			var target := bro.position + Vector2(0, -110 * SC)
			if sq.p.y > PLAT_Y + 10 and absf(sq.p.x - 560) < 80 and bro.position.y <= PLAT_Y + 5:
				sq.p = sq.p.move_toward(Vector2(560, PLAT_Y - 6), 260 * dt)   # up the trunk
				if sq.p.y <= PLAT_Y:
					sq.p.y = PLAT_Y - 6
			else:
				sq.p = sq.p.move_toward(target, 300 * dt)
			if sq.p.distance_to(target) < 12 and not injured:
				sq.mode = "on"
				sq.t = 0.0
				Game.sfx("chitter", 0.1)
				bro.set_mood("scared", 2.0)
				bro.flail(1.8)
				bro.say("squirrel", false)
				add_rage(10.0, bro.head_pos() + Vector2(0, -40), "SQUIRREL!")
		"on":
			sq.t += dt
			sq.p = bro.head_pos() + Vector2(sin(time * 9) * 30, -40 + cos(time * 7) * 20)
			if sq.t > 1.8:
				sq.mode = "home"
		"home":
			sq.p = sq.p.move_toward(SQ_HOME, 420 * dt)
			if sq.p.distance_to(SQ_HOME) < 4:
				sq.mode = "idle"
				sq_cd = 4.0


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	sky(Color("#7cc8ff"), Color("#d6f0ff"), GROUND)
	draw_circle(Vector2(1130, 100), 50, Color("#fff4a0"))
	# hills + ground
	draw_circle(Vector2(200, 760), 300, Color("#7cc06a"))
	draw_circle(Vector2(1150, 780), 320, Color("#7cc06a"))
	draw_rect(Rect2(0, GROUND, 1280, 80), Color("#58b947"))
	# trunk + canopy
	var sx := sin(time * 40) * tree_shake * 10.0
	draw_colored_polygon(PackedVector2Array([Vector2(490, GROUND), Vector2(630, GROUND), Vector2(600 + sx * 0.3, 120), Vector2(520 + sx * 0.3, 120)]), Color("#7a4a2a"))
	for c in [[Vector2(560, 110), 160.0, Color("#3f9a3a")], [Vector2(400, 180), 110.0, Color("#4caf45")], [Vector2(730, 170), 120.0, Color("#4caf45")], [Vector2(560, 40), 110.0, Color("#55b84c")]]:
		draw_circle(c[0] + Vector2(sx * 0.8, 0), c[1], c[2])
	# cooler
	rrect(Rect2(COOLER_X - 10, GROUND - 60, 110, 60), Color("#3bb0ff"), 8, Color("#1a6aa0"), 3)
	draw_rect(Rect2(COOLER_X - 10, GROUND - 66, 110, 14), Color.WHITE)
	# platform + house
	draw_set_transform(Vector2(sx, 0), 0, Vector2.ONE)
	draw_rect(Rect2(380, PLAT_Y, 470, 20), Color("#8a5a3c"))
	for k in 2:
		draw_line(Vector2(440 + k * 340, PLAT_Y + 20), Vector2(540 + k * 60, PLAT_Y + 120), Color("#6e4426"), 10)
	draw_rect(Rect2(420, 190, 300, 140), Color("#c98d55"))
	for k in 6:
		draw_line(Vector2(420, 190 + k * 24), Vector2(720, 190 + k * 24), Color("#b07a45"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(400, 192), Vector2(740, 192), Vector2(570, 108)]), Color("#b5482f"))
	rrect(Rect2(460, 222, 90, 64), Color("#8fd3ff"), 4, Color("#6e4426"), 5)
	draw_rect(Rect2(630, 236, 70, 94), Color("#3a2416"))
	draw_string(ThemeDB.fallback_font, Vector2(456, 316), "NO SIBLINGS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#5a1010"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# rope ladder
	var top := PLAT_Y + 10
	var bot := minf(GROUND, top + 300)
	var lx := LADDER_X + sx * 0.6
	draw_line(Vector2(lx - 18, top), Vector2(lx - 18, bot), Color("#c9a060"), 4)
	draw_line(Vector2(lx + 18, top), Vector2(lx + 18, bot), Color("#c9a060"), 4)
	var y := top + 20
	while y < bot:
		draw_line(Vector2(lx - 18, y), Vector2(lx + 18, y), Color("#a07a40"), 6)
		y += 34


func _foreground(ci: CanvasItem) -> void:
	# comic book in his hands
	if state == "read" and not injured and not absent:
		var c := bro.position + Vector2(0, -105 * SC)
		FX.rounded_rect(ci, Rect2(c + Vector2(-26, -18), Vector2(52, 34)), Color("#ff5a4f"), 3)
		ci.draw_rect(Rect2(c + Vector2(-20, -12), Vector2(18, 12)), Color("#ffde3b"))
		ci.draw_line(c + Vector2(0, -18), c + Vector2(0, 16), Color("#a02a2a"), 2)
	# squirrel
	var p: Vector2 = sq.p
	ci.draw_colored_polygon(FX.ellipse(p, 16, 11), Color("#a0602a"))
	ci.draw_arc(p + Vector2(-16, -14), 14, PI * 0.2, PI * 1.6, 12, Color("#b87a3a"), 10)
	ci.draw_circle(p + Vector2(14, -8), 9, Color("#a0602a"))
	ci.draw_circle(p + Vector2(17, -10), 2.5, Color.BLACK)
	ci.draw_circle(p + Vector2(10, -16), 3, Color("#a0602a"))
	if sq.mode == "idle" and tool == "squirrel":
		ci.draw_arc(p, 30 + sin(time * 6) * 3, 0, TAU, 24, Color(1, 0.9, 0.3, 0.8), 3)
	# acorns: brown nut under a darker cap with a little stem
	for c in acorns:
		var t: float = c.t
		var q: Vector2 = (c.from as Vector2).lerp(c.to, t) + Vector2(0, -sin(t * PI) * 120)
		var k := lerpf(1.6, 0.9, t)
		ci.draw_colored_polygon(FX.ellipse(q + Vector2(0, 3 * k), 8 * k, 10 * k), Color("#b9772f"))
		ci.draw_colored_polygon(FX.ellipse(q + Vector2(0, -5 * k), 10 * k, 6 * k), Color("#6e4a24"))
		ci.draw_line(q + Vector2(0, -10 * k), q + Vector2(2 * k, -15 * k), Color("#4a3018"), 2)
	if absent:
		return
	var tip := {"tree_shake": "Tap the tree to shake it!", "acorn": "Tap to throw an acorn!",
		"squirrel": "Tap to send the squirrel after him!"}
	ci.draw_string(ThemeDB.fallback_font, Vector2(760, 694), tip[tool], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	state = "down"
	bro.position = Vector2(LADDER_X, 470)
	_fall()


func on_blasted(p: Vector2) -> void:
	var on_ladder := _on_ladder()
	state = "fall"
	bro.set_mood("hurt")
	bro.say("blasted")
	bro.flail(1.0)
	if on_ladder:
		var tw := create_tween()
		tw.tween_property(bro, "position:y", GROUND, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Game.sfx("thud", 0.0)
			bro.set_mood("ko")
			bro.fall_over(1.0))
	else:
		get_tree().create_timer(0.9).timeout.connect(func():
			Game.sfx("thud", 0.0)
			bro.set_mood("ko")
			bro.fall_over(-1.0 if p.x > bro.position.x else 1.0))
