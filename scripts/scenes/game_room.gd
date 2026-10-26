extends "res://scripts/minigame.gd"
## Game Room: Bro is fighting a video game boss. Pull the plug at the worst
## possible moment - the closer he is to winning, the madder he gets.

const TV := Rect2(90, 110, 600, 360)
const BEANBAG_X := 390.0  ## right in front of the TV
const PLUG := Vector2(780, 590)

var boss_hp := 100.0
var state := "play"   # play, off, won
var state_t := 0.0
var plug_out := 0.0
var static_t := 0.0
var shot_t := 0.0
var shots: Array = []
var flash := 0.0
var heal_msg := 0.0
var said_almost := false
var mouse := Vector2.ZERO
var tv_fall := 0.0


func _init() -> void:
	scene_id = "game_room"


func hint() -> String:
	return "Click the PLUG to cut the power. Wait until he's ALMOST won for max rage!"


func idle_lines() -> Array:
	return ["gaming"] if state == "play" else []


func setup() -> void:
	spawn_bro(Vector2(BEANBAG_X, 660), 1.0)
	bro.sitting = true
	bro.arm_l = -0.6
	bro.arm_r = -0.6
	bro.elbow_l = -1.3
	bro.elbow_r = -1.3
	bro.look_at_mouse = false
	bro.look = Vector2(-0.8, -0.2)
	get_tree().create_timer(2.0).timeout.connect(func(): chat("gaming"))


func debug_state(n: int) -> void:
	boss_hp = 18
	if n == 2:
		_unplug()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if TV.grow(16).has_point(e.position):
			_push_tv()
		elif e.position.distance_to(PLUG + Vector2(plug_out * 60, 0)) < 70 or Rect2(700, 520, 160, 140).has_point(e.position):
			_unplug()


## Clicking the TV topples it onto him (he's sitting right in front of it).
func _push_tv() -> void:
	state = "off"
	static_t = 0.0
	bro.set_mood("scared")
	bro.say("aaah")
	injure("Crushed by a falling TV", 4.0)
	var tw := create_tween()
	tw.tween_property(self, "tv_fall", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Game.sfx("crash", 0.0)
		Game.sfx("thud", 0.0)
		shake(18)
		bro.set_mood("ko")
		burst(Vector2(bro.position.x, 640), 40, [Color("#fff36a"), Color("#ccc"), Color("#8ae0ff")], 500, 5, 900, 0.9))


func _unplug() -> void:
	if state != "play" or plug_out > 0.1:
		return
	state = "off"
	state_t = 3.8
	static_t = 0.45
	Game.sfx("unplug", 0.0)
	create_tween().tween_property(self, "plug_out", 1.0, 0.12)
	var progress := (100.0 - boss_hp) / 100.0
	var r := 4.0 + progress * 26.0
	var label := "UNPLUGGED"
	if boss_hp < 10:
		r += 14.0
		label = "SO CRUEL!"
		get_tree().create_timer(1.6).timeout.connect(func(): Game.voice("supermean"))
	elif boss_hp < 30:
		r += 5.0
		label = "OOOH, CLOSE!"
	shake(6 + progress * 10)
	bro.set_mood("angry" if progress > 0.6 else "surprised", 3.0)
	bro.flail(1.2 if progress > 0.6 else 0.4)
	if progress > 0.65:
		bro.say("nooo")
		bro.hop(30)
	else:
		bro.say(["hey", "ohcomeon", "whyyou"].pick_random())
	add_rage(r, PLUG + Vector2(0, -80), label)


func tick(dt: float) -> void:
	if injured:
		return
	state_t -= dt
	static_t -= dt
	flash = maxf(0.0, flash - dt * 4)
	heal_msg -= dt
	match state:
		"play":
			shot_t -= dt
			if shot_t <= 0:
				shot_t = randf_range(0.35, 0.7)
				shots.append({"x": 0.0})
			for s in shots.duplicate():
				s.x += dt * 2.2
				if s.x >= 1.0:
					shots.erase(s)
					boss_hp -= randf_range(1.5, 4.5)
					flash = 1.0
					Game.sfx("hit8", 0.2, -14)
			if randf() < dt * 0.12 and boss_hp < 70 and boss_hp > 12:
				boss_hp = minf(100, boss_hp + 12)
				heal_msg = 1.2
				chat("ohcomeon")
			if boss_hp < 30 and not said_almost:
				said_almost = true
				bro.set_mood("happy")
				bro.say("almost", false)
			if boss_hp <= 0:
				boss_hp = 0
				state = "won"
				state_t = 4.0
				shots.clear()
				bro.set_mood("smug")
				bro.say("won")
				Game.sfx("powerup", 0.0, -6)
		"off":
			if state_t <= 0:
				_restart()
				bro.say("notagain", false)
		"won":
			if state_t <= 0:
				_restart()
	bro.position.y = 660 + (sin(time * 9) * 2 if state == "play" else 0.0)


func _restart() -> void:
	create_tween().tween_property(self, "plug_out", 0.0, 0.3)
	state = "play"
	boss_hp = 100
	said_almost = false
	shots.clear()
	bro.set_mood("normal")
	Game.sfx("powerup", 0.0, -10)


func _draw() -> void:
	sky(Color("#1d1430"), Color("#3a2550"))
	# posters
	rrect(Rect2(740, 90, 140, 190), Color("#35c6d9"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(752, 190), "LVL 99", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	rrect(Rect2(1040, 120, 180, 120), Color("#ff6df0"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(1056, 192), "GAMER", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	# floor
	draw_rect(Rect2(0, 560, 1280, 160), Color("#2a1f3a"))
	draw_rect(Rect2(0, 556, 1280, 8), Color("#4a3a60"))
	# TV stand + TV
	draw_rect(Rect2(60, 470, 660, 110), Color("#3b2a20"))
	if tv_fall <= 0.0:
		rrect(TV.grow(16), Color("#111"), 16)
		_draw_screen()
	# cord from TV to outlet
	var plug := PLUG + Vector2(plug_out * 70, plug_out * -10)
	var pts := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		pts.append(Vector2(lerpf(650, plug.x - 20, t), lerpf(480, plug.y, t) + sin(t * PI) * 60))
	draw_polyline(pts, Color("#111"), 6)
	# outlet
	rrect(Rect2(PLUG + Vector2(-34, -44), Vector2(68, 88)), Color("#f0ece0"), 8, Color("#888"), 3)
	draw_rect(Rect2(PLUG + Vector2(-12, -14), Vector2(6, 16)), Color("#333"))
	draw_rect(Rect2(PLUG + Vector2(6, -14), Vector2(6, 16)), Color("#333"))
	# plug body
	rrect(Rect2(plug + Vector2(-26, -26), Vector2(52, 52)), Color("#2a2a2a"), 10)
	if state == "play" and not absent:
		var pulse := 0.5 + 0.5 * sin(time * 6)
		draw_arc(PLUG, 52 + pulse * 6, 0, TAU, 32, Color(1, 0.9, 0.2, 0.5 + pulse * 0.4), 4)
		draw_string(ThemeDB.fallback_font, PLUG + Vector2(-48, -62), "PULL ME", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffde3b"))
	# beanbag
	ellipse(Vector2(BEANBAG_X, 640), 170, 70, Color("#e8a23a"))
	ellipse(Vector2(BEANBAG_X, 610), 140, 60, Color("#f2b450"))


func _draw_screen() -> void:
	if absent:
		draw_rect(TV, Color("#050505"))  # nobody's playing
		return
	if state == "off":
		if static_t > 0:
			for i in 160:
				var p := Vector2(randf_range(TV.position.x, TV.end.x - 8), randf_range(TV.position.y, TV.end.y - 8))
				draw_rect(Rect2(p, Vector2(8, 8)), Color(randf(), randf(), randf()).lerp(Color.WHITE, 0.5))
			draw_rect(TV, Color(0, 0, 0, 0.3))
		else:
			draw_rect(TV, Color("#050505"))
			draw_circle(TV.get_center(), 3, Color(1, 1, 1, maxf(0, state_t - 2.5)))
		return
	var bg := Color("#2a1a5a").lerp(Color("#ff4a4a"), flash * 0.25)
	draw_rect(TV, bg)
	draw_rect(Rect2(TV.position.x, TV.end.y - 70, TV.size.x, 70), Color("#3a7a3a"))
	# hero
	var hero := Vector2(TV.position.x + 120, TV.end.y - 110)
	draw_rect(Rect2(hero - Vector2(20, 30), Vector2(40, 60)), Color("#4ab0ff"))
	draw_rect(Rect2(hero - Vector2(12, 50), Vector2(24, 22)), Color("#f2c79b"))
	draw_line(hero + Vector2(20, 0), hero + Vector2(56, -24), Color("#e0e0e0"), 6)
	# boss
	var bc := Vector2(TV.end.x - 150, TV.end.y - 170 + sin(time * 2) * 10)
	var bs := 0.6 + boss_hp / 250.0
	if boss_hp > 0:
		draw_circle(bc, 95 * bs, Color("#9a3ac2"))
		draw_circle(bc + Vector2(-30, -20) * bs, 18 * bs, Color("#ffde3b"))
		draw_circle(bc + Vector2(30, -20) * bs, 18 * bs, Color("#ffde3b"))
		draw_circle(bc + Vector2(-30, -20) * bs, 7 * bs, Color.BLACK)
		draw_circle(bc + Vector2(30, -20) * bs, 7 * bs, Color.BLACK)
		for k in 5:
			draw_colored_polygon(PackedVector2Array([bc + Vector2(-50 + k * 25, 30) * bs, bc + Vector2(-38 + k * 25, 30) * bs,
				bc + Vector2(-44 + k * 25, 48) * bs]), Color.WHITE)
	for s in shots:
		var p: Vector2 = hero.lerp(bc, s.x) + Vector2(56, -24) * (1.0 - s.x)
		draw_circle(p, 10, Color("#fff36a"))
	# HP bar
	var hb := Rect2(TV.position.x + 30, TV.position.y + 20, TV.size.x - 60, 28)
	draw_rect(hb, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * boss_hp / 100.0, hb.size.y)), Color("#ff3b3b"))
	draw_string(ThemeDB.fallback_font, hb.position + Vector2(8, 22), "MEGA BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if heal_msg > 0:
		draw_string(ThemeDB.fallback_font, TV.get_center() + Vector2(-110, -60), "BOSS HEALS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#7dff6a"))
	if state == "won":
		draw_string(ThemeDB.fallback_font, TV.get_center() + Vector2(-150, 0), "YOU WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color("#ffde3b"))


func _foreground(ci: CanvasItem) -> void:
	if tv_fall > 0.0:
		# the TV toppling onto him
		var c := TV.get_center().lerp(Vector2(bro.position.x, 440), tv_fall)
		ci.draw_set_transform(c, lerpf(0.0, 0.12, tv_fall), Vector2.ONE)
		var r := Rect2(-TV.size / 2, TV.size).grow(16)
		FX.rounded_rect(ci, r, Color("#111"), 16)
		ci.draw_rect(Rect2(-TV.size / 2, TV.size), Color("#151520"))
		if tv_fall >= 1.0:
			for k in 6:
				var a := k * 1.1
				ci.draw_polyline(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a) * 90 + Vector2(12, 8), Vector2.from_angle(a) * 200]), Color("#aaa"), 3)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	if absent:
		return
	# controller in Bro's hands
	var c := bro.position + Vector2(0, -95)
	FX.rounded_rect(ci, Rect2(c + Vector2(-48, -20), Vector2(96, 40)), Color("#3a3a48"), 18)
	ci.draw_circle(c + Vector2(26, -4), 6, Color("#ff5a4f"))
	ci.draw_circle(c + Vector2(36, 6), 6, Color("#5ad16a"))
	ci.draw_rect(Rect2(c + Vector2(-34, -4), Vector2(22, 8)), Color("#ccc"))
	ci.draw_rect(Rect2(c + Vector2(-27, -11), Vector2(8, 22)), Color("#ccc"))
	# TV glow on Bro
	if state == "play":
		ci.draw_circle(bro.head_pos(), 60, Color(0.3, 0.5, 1.0, 0.08 + flash * 0.08))


func _enter_tree() -> void:
	add_child(FX.Layer.new(_foreground, 5))


## Test hook: triggers this location's hospital accident.
func debug_injure() -> void:
	_push_tv()
