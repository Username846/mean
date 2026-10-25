extends "res://scripts/minigame.gd"
## Bedroom: draw on Bro's face while he sleeps. Keep the noise down,
## especially when he stirs! Then wake him up and hand him a mirror.

const HC := Vector2(560, 360)
const R := 150.0
const STAMPS := ["mustache", "glasses", "whiskers", "unibrow"]

var strokes: Array = []
var cur: Dictionary = {}
var tool := "black"
var drawing := false
var noise := 0.0
var ink := 0.0
var state := "sleep"
var snore_t := 2.0
var stir_t := 10.0
var stirring := 0.0
var mouse := Vector2.ZERO
var last := Vector2.ZERO
var anchor: Node2D
var mirror := 0.0
var tool_buttons := {}
var wake_btn: Button
var wash_btn: Button
var zzz: Array = []
var writhe := 0.0


func _init() -> void:
	scene_id = "bedroom"


func hint() -> String:
	return "Draw on his face! Stay quiet when he stirs. Then press WAKE HIM UP."


func idle_lines() -> Array:
	return []


func setup() -> void:
	bro = spawn_bro(Vector2(-500, -500))
	bro.visible = false
	bro.set_mood("sleep")
	anchor = Node2D.new()
	anchor.position = HC
	add_child(anchor)
	bro.bubble_target = anchor
	bro.bubble_offset = Vector2(0, -R - 60)
	var row := HBoxContainer.new()
	row.position = Vector2(930, 90)
	row.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.position = Vector2(1000, 120)
	col.add_theme_constant_override("separation", 8)
	hud.add_child(col)
	for t in [["black", "Black Marker"], ["red", "Red Marker"], ["mustache", "Mustache"],
			["glasses", "Glasses"], ["whiskers", "Whiskers"], ["unibrow", "Unibrow"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = t[0] == tool
		b.add_theme_stylebox_override("pressed", Game._box(Color("#3bb0ff"), 14, Color("#fff6b0"), 4))
		b.pressed.connect(_select.bind(t[0]))
		col.add_child(b)
		tool_buttons[t[0]] = b
	wake_btn = Button.new()
	wake_btn.text = "WAKE HIM UP!"
	wake_btn.add_theme_stylebox_override("normal", Game._box(Color("#e83a5a")))
	wake_btn.pressed.connect(_wake.bind(false))
	col.add_child(wake_btn)
	wash_btn = Button.new()
	wash_btn.text = "Next night"
	wash_btn.visible = false
	wash_btn.pressed.connect(_new_night)
	col.add_child(wash_btn)


func _select(t: String) -> void:
	tool = t
	Game.sfx("click")
	for k in tool_buttons:
		tool_buttons[k].button_pressed = k == t


func debug_state(n: int) -> void:
	for i in 3:
		var pts := PackedVector2Array()
		for k in 12:
			pts.append(Vector2(-0.6 + k * 0.1, -0.5 + i * 0.4 + sin(k) * 0.1))
		strokes.append({"pts": pts, "col": Color.BLACK, "w": 0.05})
	_stamp("mustache", Vector2(0, 0.35))
	_stamp("glasses", Vector2(0, -0.05))
	noise = 40
	if n == 2:
		_wake(false)


# ------------------------------------------------------------------ input

func _to_local(p: Vector2) -> Vector2:
	return (p - HC) / R


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
		if drawing and state == "sleep":
			var spd: float = e.relative.length()
			_make_noise(spd * 0.05)
			_add_point(e.position)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		if state == "awake" and e.pressed and not tool in STAMPS:
			# drawing on his open eyes
			for s: int in [-1, 1]:
				if _to_local(e.position).distance_to(Vector2(s * 0.38, -0.05)) < 0.3:
					_scratch_eyes(_to_local(e.position))
					return
		if state != "sleep":
			return
		if e.pressed:
			if tool in STAMPS:
				var lp := _to_local(e.position)
				if lp.length() < 1.0:
					_stamp(tool, lp)
					_make_noise(9.0)
					Game.sfx("squeak", 0.2, -6)
			else:
				drawing = true
				cur = {"pts": PackedVector2Array(), "col": Color("#16131c") if tool == "black" else Color("#e0202a"), "w": 0.045}
				strokes.append(cur)
				_add_point(e.position)
		else:
			drawing = false


func _add_point(p: Vector2) -> void:
	var lp := _to_local(p)
	if lp.length() > 0.98:
		# leaving the face ends the stroke
		if cur.pts.size() > 0:
			cur = {"pts": PackedVector2Array(), "col": cur.col, "w": cur.w}
			strokes.append(cur)
		return
	var pts: PackedVector2Array = cur.pts
	if pts.size() > 0:
		var d := pts[pts.size() - 1].distance_to(lp)
		if d < 0.01:
			return
		ink += d
	pts.append(lp)
	cur.pts = pts
	if randf() < 0.15:
		Game.sfx("marker", 0.3, -12)


func _stamp(kind: String, c: Vector2) -> void:
	var col := Color("#16131c")
	var add := func(pts: Array, w := 0.045):
		var pv := PackedVector2Array()
		for p in pts:
			pv.append(c + p)
		strokes.append({"pts": pv, "col": col, "w": w})
	match kind:
		"mustache":
			for s: int in [-1, 1]:
				var pts := []
				for i in 10:
					var t := i / 9.0
					pts.append(Vector2(s * t * 0.42, -0.02 + sin(t * PI) * 0.08 - t * t * 0.15 + (0.05 if t > 0.85 else 0.0)))
				add.call(pts, 0.08)
		"glasses":
			for s: int in [-1, 1]:
				var pts := []
				for i in 17:
					pts.append(Vector2(s * 0.38, 0) + Vector2.from_angle(TAU * i / 16.0) * 0.22)
				add.call(pts)
			add.call([Vector2(-0.16, 0), Vector2(0.16, 0)])
		"whiskers":
			for s: int in [-1, 1]:
				for k in 3:
					add.call([Vector2(s * 0.25, 0.05 * (k - 1)), Vector2(s * 0.7, -0.12 + 0.12 * k)], 0.03)
			add.call([Vector2(-0.05, -0.02), Vector2(0.05, -0.02), Vector2(0, 0.06), Vector2(-0.05, -0.02)], 0.06)
		"unibrow":
			var pts := []
			for i in 11:
				pts.append(Vector2(lerpf(-0.6, 0.6, i / 10.0), -0.05 + absf(i - 5) * 0.012 + sin(i * 2.0) * 0.02))
			add.call(pts, 0.1)
	ink += 1.6


func _make_noise(n: float) -> void:
	noise += n * (4.0 if stirring > 0 else 1.0)
	if noise >= 100 and state == "sleep":
		_wake(true)


func _wake(caught: bool) -> void:
	if state != "sleep":
		return
	state = "awake"
	drawing = false
	wake_btn.disabled = true
	Game.sfx("alarm" if not caught else "creak", 0.0)
	bro.set_mood("surprised")
	bro.say("whosthere")
	var score := clampf(ink * 2.2, 3.0, 55.0)
	if caught:
		score *= 0.5
	get_tree().create_timer(1.8).timeout.connect(func():
		create_tween().tween_property(self, "mirror", 1.0, 0.5)
		Game.sfx("sting", 0.0, -6))
	get_tree().create_timer(2.6).timeout.connect(func():
		if injured:
			return
		bro.set_mood("angry")
		shake(8)
		if caught:
			bro.say("getout")
		else:
			bro.say("myface")
		add_rage(score, HC + Vector2(0, -R - 20), "CAUGHT!" if caught else ("MASTERPIECE!" if ink > 15 else "ART!"))
		wash_btn.visible = true)


func _scratch_eyes(at: Vector2) -> void:
	writhe = 8.0
	for k in 3:
		var pts := PackedVector2Array([at + Vector2(-0.15, -0.1 + k * 0.08), at + Vector2(0.15, -0.02 + k * 0.08)])
		strokes.append({"pts": pts, "col": Color("#c0101e"), "w": 0.03})
	Game.sfx("marker", 0.0)
	Game.sfx("sting", 0.0, -4)
	shake(10)
	bro.set_mood("eyes")
	bro.say("myeyes")
	wash_btn.visible = false
	get_tree().create_timer(2.6).timeout.connect(func(): bro.say("scream"))
	get_tree().create_timer(4.6).timeout.connect(func(): bro.say("myeyes"))
	injure("Scratched eyes with a marker", 6.0)


func _new_night() -> void:
	Game.sfx("splash", 0.1, -6)
	strokes.clear()
	ink = 0
	noise = 0
	mirror = 0
	state = "sleep"
	bro.set_mood("sleep")
	wake_btn.disabled = false
	wash_btn.visible = false
	stir_t = randf_range(8, 13)


func tick(dt: float) -> void:
	noise = maxf(0.0, noise - dt * 10.0)
	writhe = maxf(0.0, writhe - dt)
	if state == "sleep":
		snore_t -= dt
		if snore_t <= 0:
			snore_t = 3.2
			Game.sfx("snore", 0.1, -8)
			zzz.append({"p": HC + Vector2(R * 0.6, -R * 0.8), "a": 1.0})
		stir_t -= dt
		if stir_t <= 0:
			stir_t = randf_range(8, 14)
			stirring = 2.2
			bro.say(["sleeptalk", "mumble"].pick_random())
		stirring = maxf(0.0, stirring - dt)
	for z in zzz:
		z.p += Vector2(20, -40) * dt
		z.a -= dt * 0.5
	zzz = zzz.filter(func(z): return z.a > 0)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	sky(Color("#1b1640"), Color("#2c2460"))
	# window + moon
	rrect(Rect2(90, 90, 230, 200), Color("#0e0b26"), 6, Color("#6b5ab0"), 8)
	draw_circle(Vector2(230, 160), 40, Color("#fff4c4"))
	draw_circle(Vector2(214, 150), 36, Color("#0e0b26"))
	for i in 12:
		draw_circle(Vector2(110 + fmod(i * 73.0, 200), 110 + fmod(i * 41.0, 160)), 2, Color(1, 1, 1, 0.6 + 0.4 * sin(time * 3 + i)))
	# poster
	rrect(Rect2(780, 90, 150, 200), Color("#e05a4a"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(796, 180), "KEEP", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(796, 224), "OUT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	# bed
	rrect(Rect2(150, 280, 820, 460), Color("#6b4a8a"), 30)
	ellipse(HC + Vector2(0, 60), 300, 110, Color("#e8e4ff"))
	var jit := Vector2(sin(time * 30), cos(time * 23)) * 4.0 * minf(stirring, 1.0)
	jit += Vector2(sin(time * 17) * 30, cos(time * 13) * 10) * minf(writhe, 1.0)
	var hc := HC + jit
	var mood := bro.mood
	Bro.draw_head(self, hc, R, mood, bro.look * 0.3, false, rage / 100.0 if state == "awake" else 0.0, {"t": time})
	_draw_ink(hc, R, 1.0)
	# blanket
	var pts := PackedVector2Array([Vector2(150, 720), Vector2(150, 560), Vector2(330, 520), Vector2(560, 545 + sin(time * 1.4) * 6),
		Vector2(800, 520), Vector2(970, 560), Vector2(970, 720)])
	draw_colored_polygon(pts, Color("#ff8fb0"))
	for i in 6:
		draw_line(Vector2(190 + i * 140, 560), Vector2(170 + i * 140, 720), Color("#ff6f98"), 6)
	# noise meter
	var nr := Rect2(30, 600, 260, 28)
	rrect(nr.grow(4), Color(0, 0, 0, 0.5), 10)
	var nc := Color("#7dff6a").lerp(Color("#ff3b3b"), noise / 100.0)
	rrect(Rect2(nr.position, Vector2(nr.size.x * clampf(noise / 100.0, 0, 1), nr.size.y)), nc, 8)
	draw_string(ThemeDB.fallback_font, Vector2(36, 590), "NOISE" + ("  - HE'S STIRRING! FREEZE!" if stirring > 0 else ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ff8a8a") if stirring > 0 else Color.WHITE)
	for z in zzz:
		draw_string(ThemeDB.fallback_font, z.p, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, z.a))
	# mirror reveal
	if mirror > 0.01:
		var mc := Vector2(190, 400 + (1.0 - mirror) * 400)
		draw_line(mc + Vector2(0, 110), mc + Vector2(0, 260), Color("#b07a3a"), 22)
		draw_circle(mc, 118, Color("#d9a54a"))
		draw_circle(mc, 104, Color("#bfe9ff"))
		draw_set_transform(mc, 0, Vector2(-1, 1))
		Bro.draw_head(self, Vector2.ZERO, 70, mood, Vector2.ZERO, false, rage / 100.0, {"t": time})
		_draw_ink(Vector2.ZERO, 70, 1.0)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# marker cursor
	if state == "sleep":
		draw_set_transform(mouse, -0.6, Vector2.ONE)
		rrect(Rect2(-9, -90, 18, 80), Color("#2a2a35"), 6)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(0, 4)]),
			Color("#e0202a") if tool == "red" else Color("#16131c"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_ink(c: Vector2, r: float, a: float) -> void:
	for s in strokes:
		var pts: PackedVector2Array = s.pts
		if pts.size() == 0:
			continue
		var col: Color = s.col
		col.a = a
		var w: float = s.w * r
		if pts.size() == 1:
			draw_circle(c + pts[0] * r, w / 2, col)
			continue
		var sp := PackedVector2Array()
		for p in pts:
			sp.append(c + p * r)
		draw_polyline(sp, col, w, true)
		draw_circle(sp[0], w / 2, col)
		draw_circle(sp[sp.size() - 1], w / 2, col)


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	_wake(false)
	_scratch_eyes(Vector2(0.38, -0.05))
