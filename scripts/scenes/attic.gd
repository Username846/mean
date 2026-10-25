extends "res://scripts/minigame.gd"
## Haunted Attic: hide in the dark and jump-scare Bro as he creeps past with
## his flashlight. Get close for a bigger scare - but don't get spotted!

const FLOOR := 610.0
const SC := 0.85
const SPOTS := [{"name": "Box", "x": 260.0}, {"name": "Wardrobe", "x": 640.0}, {"name": "Old Sheet", "x": 1020.0}]
const DARK_SHADER := """
shader_type canvas_item;
uniform vec2 light_pos;
uniform vec2 light_dir;
uniform float cone = 0.38;
uniform float reach = 560.0;
uniform float flash = 0.0;
varying vec2 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	vec2 d = wp - light_pos;
	float dist = length(d);
	float ang = acos(clamp(dot(normalize(d), normalize(light_dir)), -1.0, 1.0));
	float lit = smoothstep(cone, cone * 0.55, ang) * smoothstep(reach, reach * 0.4, dist);
	lit = max(lit, smoothstep(170.0, 0.0, dist) * 0.55);
	float moon = smoothstep(230.0, 0.0, length(wp - vec2(640.0, 150.0))) * 0.45;
	float a = 0.94 * (1.0 - max(max(lit, moon), flash));
	COLOR = vec4(0.02, 0.01, 0.06, a);
}
"""

var spot := 1
var dir := 1.0
var state := "walk"   # walk, look, scared, gone, alert
var state_t := 0.0
var suspicion := 0.0
var cooldown := 0.0
var flash := 0.0
var dark: Node2D
var mat: ShaderMaterial
var light_pos := Vector2.ZERO
var light_dir := Vector2.RIGHT
var boo_btn: Button
var sweep := 0.0


func _init() -> void:
	scene_id = "attic"


func hint() -> String:
	return "Click a hiding spot to hide there. Press BOO! (or Space) when he's close!"


func idle_lines() -> Array:
	return ["creepy", "hello"] if state == "walk" else []


func setup() -> void:
	spawn_bro(Vector2(-80, FLOOR), SC)
	bro.look_at_mouse = false
	bro.arm_r = 1.4
	bro.elbow_r = 0.2
	dark = Node2D.new()
	dark.z_index = 20
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DARK_SHADER
	mat.shader = sh
	dark.material = mat
	dark.draw.connect(func(): dark.draw_rect(Rect2(-40, -40, 1360, 800), Color.WHITE))
	add_child(dark)
	var eyes := FX.Layer.new(_draw_eyes, 25)
	add_child(eyes)
	boo_btn = Button.new()
	boo_btn.text = "   BOO!   "
	boo_btn.add_theme_font_size_override("font_size", 34)
	boo_btn.add_theme_stylebox_override("normal", Game._box(Color("#8a3ac2"), 18, Color("#ffde3b"), 4))
	boo_btn.add_theme_stylebox_override("hover", Game._box(Color("#a24ae0"), 18, Color("#ffde3b"), 4))
	boo_btn.position = Vector2(1070, 600)
	boo_btn.pressed.connect(_boo)
	hud.add_child(boo_btn)
	hint_label.position.y = 690
	get_tree().create_timer(2.0).timeout.connect(func(): chat("creepy"))


func debug_state(n: int) -> void:
	bro.position.x = 520
	dir = 1.0
	if n == 2:
		_boo()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE:
		_boo()
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in SPOTS.size():
			if absf(e.position.x - SPOTS[i].x) < 120 and e.position.y > 300 and i != spot:
				spot = i
				Game.sfx("creak", 0.2, -6)
				if state == "walk" and absf(bro.position.x - SPOTS[i].x) < 260:
					suspicion = minf(1.0, suspicion + 0.5)


func _boo() -> void:
	if cooldown > 0 or state == "heart":
		return
	if state in ["scared", "gone"]:
		# scared again while still fleeing: too much for his heart
		if bro.position.x > 0 and bro.position.x < 1280:
			_heart_attack()
		return
	cooldown = 1.0
	var sx: float = SPOTS[spot].x
	var dist := absf(bro.position.x - sx)
	if state == "alert" or bro.position.x < -40 or bro.position.x > 1320:
		Game.sfx("boo", 0.1, -6)
		bro.set_mood("smug", 2.0)
		chat(["notscared", "nyah"].pick_random())
		return
	if dist > 460:
		Game.sfx("boo", 0.1, -6)
		bro.set_mood("surprised", 1.0)
		chat("hello")
		return
	var power := 1.0 - dist / 460.0
	Game.sfx("sting", 0.0)
	Game.sfx("boo", 0.0)
	flash = 1.0
	shake(10 + power * 12)
	state = "scared"
	state_t = 1.4
	bro.set_mood("scared")
	bro.hair_up = 1.0
	bro.hop(60 + power * 110)
	bro.flail(1.5)
	bro.say("scream")
	var label := "BOO!"
	var r := 6.0 + power * 26.0
	if dist < 110:
		label = "PERFECT SCARE!"
		r += 8.0
		get_tree().create_timer(1.6).timeout.connect(func(): Game.voice("perfect"))
	elif power > 0.6:
		label = "TERRIFYING!"
	add_rage(r, bro.head_pos() + Vector2(0, -80), label)


func _heart_attack() -> void:
	state = "heart"
	Game.sfx("sting", 0.0)
	Game.sfx("boo", 0.0)
	flash = 1.0
	shake(16)
	bro.set_mood("scared")
	bro.hair_up = 1.0
	bro.arm_l = -0.5
	bro.arm_r = -0.5
	bro.elbow_l = -1.5
	bro.elbow_r = -1.5
	bro.say("heart")
	injure("Heart attack from a double scare", 4.5)
	get_tree().create_timer(1.6).timeout.connect(func():
		bro.set_mood("ko")
		bro.fall_over(dir, 30.0)
		Game.sfx("thud", 0.0))


func tick(dt: float) -> void:
	cooldown -= dt
	state_t -= dt
	flash = maxf(0.0, flash - dt * 3)
	bro.hair_up = maxf(0.0, bro.hair_up - dt * 0.25)
	sweep += dt
	var sx: float = SPOTS[spot].x
	match state:
		"walk", "alert":
			bro.position.x += dir * (80.0 + rage) * dt
			if bro.position.x > 1380:
				dir = -1.0
				_reset_walk()
			elif bro.position.x < -100:
				dir = 1.0
				_reset_walk()
			if state == "walk" and randf() < dt * 0.15:
				state = "look"
				state_t = randf_range(1.0, 2.0)
				Game.sfx("creak", 0.3, -10)
			if state == "alert" and state_t <= 0:
				state = "walk"
		"look":
			if state_t <= 0:
				state = "walk"
		"scared":
			if state_t <= 0:
				state = "gone"
				state_t = 4.0
				dir = -dir
		"gone":
			bro.position.x += dir * 520 * dt
			if state_t <= 0:
				state = "walk"
				bro.position.x = -90.0 if dir > 0 else 1370.0
				bro.set_mood("smug")
				bro.say("notscared")
	bro.scale.x = SC * (1.0 if dir > 0 else -1.0)
	bro.position.y = FLOOR + (absf(sin(time * 8)) * -4 if state in ["walk", "alert"] else 0.0)
	# flashlight
	var hand := bro.position + Vector2(dir * 50, -150) * SC
	var sw := sin(sweep * (2.5 if state == "look" else 1.2)) * (0.9 if state == "look" else 0.35)
	light_pos = hand
	light_dir = Vector2(dir, 0.18).normalized().rotated(sw * dir)
	if state == "scared" or state == "gone":
		light_dir = Vector2.from_angle(time * 9)
	mat.set_shader_parameter("light_pos", light_pos)
	mat.set_shader_parameter("light_dir", light_dir)
	mat.set_shader_parameter("flash", flash)
	dark.queue_redraw()
	# spotting
	if state in ["walk", "look"]:
		var to_me := Vector2(sx, 520) - light_pos
		var in_cone := absf(light_dir.angle_to(to_me)) < 0.32 and to_me.length() < 520
		if in_cone:
			suspicion += dt * (1.6 if state == "look" else 0.9)
		else:
			suspicion = maxf(0.0, suspicion - dt * 0.5)
		if suspicion >= 1.0:
			suspicion = 0.0
			state = "alert"
			state_t = 4.0
			bro.set_mood("smug", 3.0)
			bro.say("seeyou")
			Game.sfx("buzzer", 0.0, -8)


func _reset_walk() -> void:
	if state == "alert":
		state = "walk"
	bro.set_mood("normal")
	suspicion = 0.0


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#4a3428"))
	# roof slope + beams
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(640, 0), Vector2(0, 400)]), Color("#3a281e"))
	draw_colored_polygon(PackedVector2Array([Vector2(1280, 0), Vector2(640, 0), Vector2(1280, 400)]), Color("#3a281e"))
	for i in 6:
		draw_line(Vector2(i * 110, 0), Vector2(0, 400 - i * 70), Color("#2a1c14"), 10)
		draw_line(Vector2(1280 - i * 110, 0), Vector2(1280, 400 - i * 70), Color("#2a1c14"), 10)
	# round window
	draw_circle(Vector2(640, 150), 70, Color("#1a2a5a"))
	draw_circle(Vector2(660, 130), 26, Color("#fff4c4"))
	draw_line(Vector2(570, 150), Vector2(710, 150), Color("#2a1c14"), 8)
	draw_line(Vector2(640, 80), Vector2(640, 220), Color("#2a1c14"), 8)
	# floor
	draw_rect(Rect2(0, FLOOR, 1280, 110), Color("#5a3e2c"))
	for i in 12:
		draw_line(Vector2(0, FLOOR + i * 10), Vector2(1280, FLOOR + i * 10), Color("#4a3020"), 2)
	# cobwebs
	for c in [Vector2(0, 0), Vector2(1280, 0)]:
		for k in 5:
			var a := PI / 2 * k / 4.0
			var d := Vector2(cos(a), sin(a)) * (1 if c.x == 0 else -1) * Vector2(1, 1)
			if c.x > 0:
				d = Vector2(-cos(a), sin(a))
			draw_line(c, c + d * 160, Color(1, 1, 1, 0.3), 2)
		for r in [50, 90, 130]:
			draw_arc(c, r, 0 if c.x == 0 else PI / 2, PI / 2 if c.x == 0 else PI, 8, Color(1, 1, 1, 0.25), 2)
	# rocking horse + junk
	ellipse(Vector2(450, FLOOR - 10), 60, 12, Color("#7a4a2a"))
	draw_circle(Vector2(1180, FLOOR - 40), 40, Color("#6a5a4a"))
	# hiding spots
	var box := Rect2(SPOTS[0].x - 110, FLOOR - 170, 220, 170)
	rrect(box, Color("#b08050"), 6, Color("#7a5030"), 4)
	draw_line(box.position + Vector2(0, 40), box.position + Vector2(220, 40), Color("#7a5030"), 4)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(40, 110), "XMAS STUFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#5a3010"))
	var wr := Rect2(SPOTS[1].x - 100, FLOOR - 330, 200, 330)
	rrect(wr, Color("#6a3a2a"), 8, Color("#3a1a10"), 5)
	draw_line(Vector2(SPOTS[1].x, wr.position.y + 10), Vector2(SPOTS[1].x, FLOOR - 10), Color("#3a1a10"), 4)
	draw_circle(Vector2(SPOTS[1].x - 14, FLOOR - 170), 6, Color("#d0a040"))
	draw_circle(Vector2(SPOTS[1].x + 14, FLOOR - 170), 6, Color("#d0a040"))
	var sx: float = SPOTS[2].x
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI, TAU, i / 12.0)
		pts.append(Vector2(sx, FLOOR - 200) + Vector2(cos(a) * 100, sin(a) * 90))
	for i in 9:
		pts.append(Vector2(sx + 100 - i * 25, FLOOR + (6 if i % 2 == 0 else -10)))
	draw_colored_polygon(pts, Color("#d8d4e8"))


func _draw_eyes(ci: CanvasItem) -> void:
	# your glowing eyes peeking out (always visible, above the darkness)
	var sx: float = SPOTS[spot].x
	var p := Vector2(sx, FLOOR - 120)
	if spot == 1:
		p = Vector2(sx + 20, FLOOR - 200)
	elif spot == 0:
		p = Vector2(sx, FLOOR - 185)
	var blink := fmod(time, 3.0) < 0.12
	for s: int in [-1, 1]:
		if blink:
			ci.draw_line(p + Vector2(s * 16 - 8, 0), p + Vector2(s * 16 + 8, 0), Color("#fff36a"), 3)
		else:
			ci.draw_colored_polygon(FX.ellipse(p + Vector2(s * 16, 0), 9, 6, 12), Color("#fff36a"))
	for i in SPOTS.size():
		var lbl: String = SPOTS[i].name + (" (you)" if i == spot else "")
		ci.draw_string(ThemeDB.fallback_font, Vector2(SPOTS[i].x - 110, FLOOR + 40), lbl, HORIZONTAL_ALIGNMENT_CENTER, 220, 20,
			Color("#ffde3b") if i == spot else Color(1, 1, 1, 0.5))
	if suspicion > 0.05 and state in ["walk", "look"]:
		ci.draw_string(ThemeDB.fallback_font, bro.head_pos() + Vector2(-12, -70), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30 + int(suspicion * 30),
			Color(1, 0.9, 0.3, 0.5 + suspicion * 0.5))
	if state == "alert":
		ci.draw_string(ThemeDB.fallback_font, bro.head_pos() + Vector2(-60, -80), "SPOTTED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ff5a4f"))
	# proximity meter
	var dist := absf(bro.position.x - sx)
	var power := clampf(1.0 - dist / 460.0, 0, 1)
	FX.rounded_rect(ci, Rect2(20, 610, 280, 30), Color(0, 0, 0, 0.6), 10)
	FX.rounded_rect(ci, Rect2(20, 610, 280 * power, 30), Color("#7a3ac2").lerp(Color("#ff3bd0"), power), 10)
	ci.draw_string(ThemeDB.fallback_font, Vector2(24, 600), "SCARE POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	bro.position.x = 700.0
	state = "gone"
	_heart_attack()
