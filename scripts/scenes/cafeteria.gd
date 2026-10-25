extends "res://scripts/minigame.gd"
## Cafeteria: build Bro a "special" sandwich. Drag ingredients onto the plate.
## He checks the TOP layer - hide the gross stuff under something normal!

const PLATE := Vector2(620, 560)
const ITEMS := [
	{"id": "lettuce", "name": "Lettuce", "col": Color("#6bd14a"), "gross": 0, "hot": 0},
	{"id": "cheese", "name": "Cheese", "col": Color("#f7d84a"), "gross": 0, "hot": 0},
	{"id": "tomato", "name": "Tomato", "col": Color("#e8403a"), "gross": 0, "hot": 0},
	{"id": "ham", "name": "Ham", "col": Color("#f59aa8"), "gross": 0, "hot": 0},
	{"id": "hotsauce", "name": "Ghost Pepper Sauce", "col": Color("#ff3a10"), "gross": 0, "hot": 3},
	{"id": "worm", "name": "Gummy Worms", "col": Color("#ff7ab0"), "gross": 2, "hot": 0},
	{"id": "sock", "name": "Old Sock", "col": Color("#9a9a8a"), "gross": 4, "hot": 0},
	{"id": "sardine", "name": "Sardines", "col": Color("#8aa6c0"), "gross": 3, "hot": 0},
	{"id": "onion", "name": "Raw Onion", "col": Color("#e9d6f0"), "gross": 2, "hot": 1},
	{"id": "goo", "name": "Mystery Goo", "col": Color("#8be04a"), "gross": 3, "hot": 0},
]

var layers: Array = []
var drag := -1
var mouse := Vector2.ZERO
var state := "build"   # build, serve, eat, react
var sand_x := 0.0
var top_bread := false
var serve_btn: Button
var clear_btn: Button


func _init() -> void:
	scene_id = "cafeteria"


func hint() -> String:
	return "Drag gross stuff onto the sandwich... then HIDE it under a normal topping!"


func idle_lines() -> Array:
	return ["whatdoing", "yum"] if state == "build" else []


func setup() -> void:
	spawn_bro(Vector2(1070, 560), 0.95)
	bro.sitting = true
	bro.arm_l = 0.6
	bro.arm_r = 0.6
	bro.elbow_l = 1.2
	bro.elbow_r = 1.2
	var row := HBoxContainer.new()
	row.position = Vector2(470, 650)
	row.add_theme_constant_override("separation", 14)
	hud.add_child(row)
	serve_btn = Button.new()
	serve_btn.text = "Serve it!"
	serve_btn.add_theme_stylebox_override("normal", Game._box(Color("#3bb04a")))
	serve_btn.pressed.connect(_serve)
	row.add_child(serve_btn)
	clear_btn = Button.new()
	clear_btn.text = "Start over"
	clear_btn.pressed.connect(func():
		Game.sfx("click")
		layers.clear())
	row.add_child(clear_btn)
	hint_label.position.y = 610


func debug_state(n: int) -> void:
	layers = ["hotsauce", "sock", "worm", "lettuce"]
	if n == 2:
		_serve()


func _item_rect(i: int) -> Rect2:
	return Rect2(30 + (i % 2) * 160, 76 + (i / 2) * 88, 150, 82)


func _item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		if e.pressed and state == "build":
			for i in ITEMS.size():
				if _item_rect(i).has_point(e.position):
					drag = i
					Game.sfx("pop", 0.2, -4)
		elif not e.pressed and drag >= 0:
			if e.position.distance_to(PLATE + Vector2(0, -60)) < 170 and layers.size() < 7:
				layers.append(ITEMS[drag].id)
				Game.sfx("splat", 0.2, -6, 1.4)
				var it: Dictionary = ITEMS[drag]
				if it.gross > 0 or it.hot > 0:
					bro.look = Vector2(-1, 0.3)
			drag = -1


func _serve() -> void:
	if state != "build" or layers.is_empty():
		return
	Game.sfx("whoosh")
	state = "serve"
	top_bread = true
	var tw := create_tween()
	tw.tween_property(self, "sand_x", 250.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_inspect)


func _inspect() -> void:
	var top: Dictionary = _item(layers[layers.size() - 1])
	if top.gross > 0 or top.hot > 0:
		bro.set_mood("smug", 2.5)
		bro.say(["ugh", "notagain", "gross"].pick_random())
		FX.float_text(fx_layer, PLATE + Vector2(sand_x, -200), "He saw it! Hide it better!", Color("#ff8a8a"), 26)
		get_tree().create_timer(2.5).timeout.connect(_reset)
		state = "react"
		return
	state = "eat"
	bro.set_mood("happy")
	bro.say("yum")
	get_tree().create_timer(1.6).timeout.connect(_bite)


func _bite() -> void:
	Game.sfx("chomp")
	bro.hop(10)
	get_tree().create_timer(0.9).timeout.connect(_react)


func _react() -> void:
	state = "react"
	if "sardine" in layers:
		_allergy()
		return
	var gross := 0
	var hot := 0
	var worm := false
	var hidden := 0
	for id in layers:
		var it := _item(id)
		gross += it.gross
		hot += it.hot
		worm = worm or id == "worm"
		if it.gross > 0 or it.hot > 0:
			hidden += 1
	var r := gross * 2.5 + hot * 4.0 + (4.0 if worm else 0.0) + hidden * 1.5
	var mouth := bro.head_pos() + Vector2(0, 25)
	if hot >= 3:
		bro.set_mood("hot", 3.0)
		bro.say("hot")
		bro.flail(2.0)
		Game.sfx("fire")
		for k in 4:
			get_tree().create_timer(k * 0.25).timeout.connect(func():
				burst(mouth, 30, [Color("#ff3a10"), Color("#ffb020"), Color("#ffe060")], 500, 9, -100, 0.7, 0.8, PI))
	elif worm:
		bro.set_mood("scared", 2.5)
		bro.say("worm")
	elif gross >= 3:
		bro.set_mood("gross", 3.0)
		bro.say("gross")
		burst(mouth, 20, [Color("#9fd36a"), Color("#c8f080")], 300, 6, 900, 0.8, 1.0, PI)
	else:
		bro.set_mood("happy", 2.0)
		bro.say("notbad")
	if r > 0:
		shake(4 + r / 4)
		get_tree().create_timer(0.6).timeout.connect(func():
			add_rage(minf(r, 45.0), mouth + Vector2(-60, -80), "BLEGH!" if gross > 0 else "SPICY!"))
		if hot >= 3 and gross >= 4:
			get_tree().create_timer(2.2).timeout.connect(func(): Game.voice("supermean"))
	get_tree().create_timer(3.5).timeout.connect(_reset)


func _allergy() -> void:
	bro.set_mood("gross")
	bro.say("cantbreathe")
	bro.flail(3.0)
	Game.sfx("choke", 0.0)
	injure("Severe sardine allergy", 5.0)
	var tw := create_tween()
	tw.tween_property(bro, "puff", 1.0, 2.6).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(1.7).timeout.connect(func(): Game.sfx("choke", 0.0, 0, 0.85))
	get_tree().create_timer(3.2).timeout.connect(func():
		bro.set_mood("ko")
		bro.fall_over(-1.0, 0.0)
		Game.sfx("thud", 0.0)
		shake(8))


func _reset() -> void:
	layers.clear()
	sand_x = 0.0
	top_bread = false
	state = "build"
	bro.set_mood("normal")


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	sky(Color("#f6efc0"), Color("#e8d890"))
	draw_rect(Rect2(0, 380, 1280, 140), Color("#9fd0a8"))
	for i in 16:
		draw_line(Vector2(i * 80, 380), Vector2(i * 80, 520), Color("#8ac096"), 3)
	# menu board
	rrect(Rect2(480, 70, 320, 160), Color("#2a3a2a"), 8, Color("#8a5a3c"), 8)
	draw_string(ThemeDB.fallback_font, Vector2(505, 120), "TODAY'S LUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(505, 165), "Mystery Meat Surprise", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffde3b"))
	draw_string(ThemeDB.fallback_font, Vector2(505, 205), "(do not ask)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#aaa"))
	# clock
	draw_circle(Vector2(1000, 140), 56, Color.WHITE)
	draw_arc(Vector2(1000, 140), 56, 0, TAU, 32, Color("#444"), 6)
	draw_line(Vector2(1000, 140), Vector2(1000, 140) + Vector2.from_angle(time * 0.5) * 40, Color("#222"), 4)
	draw_line(Vector2(1000, 140), Vector2(1000, 140) + Vector2.from_angle(time * 0.05) * 28, Color("#222"), 6)
	# ingredient shelf
	rrect(Rect2(16, 64, 334, 456), Color(0.3, 0.2, 0.12, 0.85), 16)
	for i in ITEMS.size():
		var r := _item_rect(i)
		var it: Dictionary = ITEMS[i]
		var hov := r.has_point(mouse) and state == "build"
		rrect(r, Color("#fff8e8") if not hov else Color("#fffbd0"), 12, Color("#d63b3b") if it.gross > 0 or it.hot > 0 else Color("#3bb04a"), 3)
		_draw_layer(it.id, r.get_center() + Vector2(0, -12), 0.6)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 8, r.end.y - 10), it.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 16, Color(0.15, 0.1, 0.1))


func _draw_layer(id: String, c: Vector2, s := 1.0) -> void:
	var w := 110.0 * s
	match id:
		"lettuce":
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(c + Vector2(lerpf(-w, w, i / 12.0), (-8 if i % 2 == 0 else 4) * s))
			pts.append(c + Vector2(w, 10 * s))
			pts.append(c + Vector2(-w, 10 * s))
			draw_colored_polygon(pts, Color("#6bd14a"))
		"cheese":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-w, -8 * s), c + Vector2(w, -8 * s), c + Vector2(w * 0.9, 22 * s), c + Vector2(-w * 0.8, 10 * s)]), Color("#f7d84a"))
			draw_circle(c + Vector2(-w * 0.4, 0), 4 * s, Color("#e0b830"))
		"tomato":
			for k in 3:
				ellipse(c + Vector2((k - 1) * w * 0.6, 0), w * 0.32, 11 * s, Color("#e8403a"))
		"ham":
			ellipse(c, w, 11 * s, Color("#f59aa8"))
			ellipse(c + Vector2(0, -2 * s), w * 0.8, 6 * s, Color("#ffb8c4"))
		"hotsauce":
			ellipse(c, w * 0.95, 10 * s, Color("#ff3a10"))
			for k in 5:
				draw_circle(c + Vector2(lerpf(-w * 0.8, w * 0.8, k / 4.0), 10 * s), 5 * s, Color("#ff3a10"))
			draw_string(ThemeDB.fallback_font, c + Vector2(-14 * s, 6 * s), "XXX", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * s), Color("#ffe060"))
		"worm":
			for k in 3:
				var pts := PackedVector2Array()
				for i in 10:
					pts.append(c + Vector2(lerpf(-w * 0.8, w * 0.8, i / 9.0), sin(i * 1.2 + k * 2 + time * 3) * 7 * s + (k - 1) * 5 * s))
				draw_polyline(pts, [Color("#ff7ab0"), Color("#7ad1ff"), Color("#ffde3b")][k], 7 * s)
		"sock":
			draw_rect(Rect2(c + Vector2(-w * 0.8, -10 * s), Vector2(w * 1.3, 20 * s)), Color("#9a9a8a"))
			ellipse(c + Vector2(w * 0.55, 6 * s), 26 * s, 14 * s, Color("#9a9a8a"))
			draw_rect(Rect2(c + Vector2(-w * 0.8, -10 * s), Vector2(20 * s, 20 * s)), Color("#d63b3b"))
			for k in 3:
				draw_line(c + Vector2((k - 1) * 30 * s, -16 * s), c + Vector2((k - 1) * 30 * s + 6, -30 * s - sin(time * 4 + k) * 4), Color(0.5, 0.7, 0.2, 0.7), 3)
		"sardine":
			for k in 3:
				var p := c + Vector2((k - 1) * w * 0.6, 0)
				ellipse(p, w * 0.3, 9 * s, Color("#8aa6c0"))
				draw_colored_polygon(PackedVector2Array([p + Vector2(w * 0.28, 0), p + Vector2(w * 0.42, -9 * s), p + Vector2(w * 0.42, 9 * s)]), Color("#6a86a0"))
				draw_circle(p + Vector2(-w * 0.18, -2 * s), 3 * s, Color.BLACK)
		"onion":
			for k in 4:
				draw_arc(c + Vector2((k - 1.5) * w * 0.45, 4 * s), 18 * s, 0, TAU, 16, Color("#c9a6e0"), 5 * s)
		"goo":
			ellipse(c, w, 12 * s, Color("#8be04a"))
			for k in 4:
				draw_circle(c + Vector2(lerpf(-w * 0.7, w * 0.7, k / 3.0), 12 * s + sin(time * 3 + k) * 3), 6 * s, Color("#8be04a"))
			draw_circle(c + Vector2(w * 0.3, -2), 4 * s, Color(1, 1, 1, 0.6))


func _foreground(ci: CanvasItem) -> void:
	# table in front of Bro
	ci.draw_rect(Rect2(0, 520, 1280, 200), Color("#c98d55"))
	ci.draw_rect(Rect2(0, 520, 1280, 16), Color("#e0a870"))
	# tray + plate + sandwich
	var p := PLATE + Vector2(sand_x, 0)
	ci.draw_colored_polygon(FX.ellipse(p + Vector2(0, 10), 170, 34), Color(1, 1, 1))
	var rim := FX.ellipse(p + Vector2(0, 10), 170, 34)
	rim.append(rim[0])
	ci.draw_polyline(rim, Color("#bbb"), 3)
	ci.draw_colored_polygon(FX.ellipse(p, 130, 22), Color("#e3b06a"))
	var y := -18.0
	for id in layers:
		_draw_layer_ci(ci, id, p + Vector2(0, y))
		y -= 20.0
	if top_bread:
		var pts := PackedVector2Array()
		for i in 17:
			var a := lerpf(PI, TAU, i / 16.0)
			pts.append(p + Vector2(cos(a) * 130, y + 10 + sin(a) * 50))
		ci.draw_colored_polygon(pts, Color("#e3b06a"))
		for k in 5:
			ci.draw_circle(p + Vector2(-60 + k * 30, y - 20 + absf(k - 2) * 6), 3, Color("#fff2c8"))
	# dragged item
	if drag >= 0:
		_draw_layer_ci(ci, ITEMS[drag].id, mouse)


## Full-size sandwich layer, drawn on the foreground canvas.
func _draw_layer_ci(ci: CanvasItem, id: String, c: Vector2) -> void:
	var it := _item(id)
	var w := 110.0
	var col: Color = it.get("col", Color.WHITE)
	match id:
		"lettuce":
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(c + Vector2(lerpf(-w * 1.1, w * 1.1, i / 12.0), (-10 if i % 2 == 0 else 4)))
			pts.append(c + Vector2(w * 1.1, 10))
			pts.append(c + Vector2(-w * 1.1, 10))
			ci.draw_colored_polygon(pts, col)
		"worm":
			for k in 3:
				var pts := PackedVector2Array()
				for i in 10:
					pts.append(c + Vector2(lerpf(-w * 1.1, w * 1.1, i / 9.0), sin(i * 1.2 + k * 2 + time * 3) * 8 + (k - 1) * 6))
				ci.draw_polyline(pts, [Color("#ff7ab0"), Color("#7ad1ff"), Color("#ffde3b")][k], 8)
		"sock":
			ci.draw_rect(Rect2(c + Vector2(-w, -10), Vector2(w * 1.7, 20)), col)
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(w * 0.75, 6), 30, 15), col)
			ci.draw_rect(Rect2(c + Vector2(-w, -10), Vector2(22, 20)), Color("#d63b3b"))
		"hotsauce":
			ci.draw_colored_polygon(FX.ellipse(c, w * 1.05, 11), col)
			for k in 6:
				ci.draw_circle(c + Vector2(lerpf(-w * 0.9, w * 0.9, k / 5.0), 11 + sin(time * 2 + k) * 2), 6, col)
		"tomato":
			for k in 3:
				ci.draw_colored_polygon(FX.ellipse(c + Vector2((k - 1) * w * 0.7, 0), w * 0.36, 12), col)
		"sardine":
			for k in 3:
				var p := c + Vector2((k - 1) * w * 0.7, 0)
				ci.draw_colored_polygon(FX.ellipse(p, w * 0.34, 10), col)
				ci.draw_circle(p + Vector2(-w * 0.2, -2), 3, Color.BLACK)
		"onion":
			for k in 4:
				ci.draw_arc(c + Vector2((k - 1.5) * w * 0.5, 4), 20, 0, TAU, 16, Color("#c9a6e0"), 6)
		_:
			ci.draw_colored_polygon(FX.ellipse(c, w * 1.05, 12), col)
			if id == "cheese":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(w * 0.7, 0), c + Vector2(w * 1.1, 0), c + Vector2(w * 0.95, 24)]), col)


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	layers = ["sardine", "cheese"]
	_react()
