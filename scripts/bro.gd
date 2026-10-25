extends Node2D
## The big brother, drawn procedurally. Origin is between his feet.
##
## Moods: normal, angry, happy, laugh, scared, surprised, sleep, dizzy, gross,
## smug, sad, hurt, hot

const FX = preload("res://scripts/fx.gd")

const SKIN := Color("#f2c79b")
const HAIR := Color("#5a3418")
const SHIRT := Color("#3fae5a")
const PANTS := Color("#3858a8")
const SHOE := Color("#2b2b33")
const INK := Color("#1d1a26")

var mood := "normal"
var base_mood := "normal"
var _mood_t := 0.0
var red := 0.0               ## 0..1 anger flush
var look := Vector2.ZERO     ## pupils direction (-1..1)
var look_at_mouse := true
var arm_l := 0.25            ## upper arm angle from straight down (radians, outward +)
var arm_r := 0.25
var elbow_l := 0.3
var elbow_r := 0.3
var leg_spread := 0.0
var bob := true
var pie := 0.0               ## 0..1 pie cream on face
var wet := 0.0               ## 0..1 soaked
var snow := 0.0
var hair_up := 0.0           ## hair standing on end (scared)
var puff := 0.0              ## 0..1 allergic swelling
var bandage := 0                 ## 0 none, 1 head wrap, 2 over the eyes
var cap_col := Color(0, 0, 0, 0)  ## baseball cap (used for the player's character)
var shirt_col := SHIRT
var sitting := false
var hide_legs := false
var t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _bubble: Node2D
var bubble_target: Node2D      ## optional node the speech bubble follows instead of Bro
var bubble_offset := Vector2.ZERO
var talk_cooldown := 0.0
var _shake := 0.0
var _flail := 0.0


func _process(dt: float) -> void:
	t += dt
	talk_cooldown = maxf(0.0, talk_cooldown - dt)
	if _mood_t > 0:
		_mood_t -= dt
		if _mood_t <= 0:
			mood = base_mood
	_next_blink -= dt
	if _next_blink <= 0:
		_blink = 0.13
		_next_blink = randf_range(1.5, 4.0)
	_blink = maxf(0.0, _blink - dt)
	_shake = maxf(0.0, _shake - dt)
	_flail = maxf(0.0, _flail - dt)
	if look_at_mouse:
		var m := get_global_mouse_position() - (global_position + Vector2(0, -235) * scale)
		look = look.lerp((m / 300.0).limit_length(1.0), 0.2)
	queue_redraw()


func set_mood(m: String, dur := 0.0) -> void:
	mood = m
	_mood_t = dur
	if dur <= 0:
		base_mood = m


## Says a voice line with a speech bubble. Returns false if he was busy talking.
func say(id: String, force := true) -> bool:
	if not force and (talk_cooldown > 0 or Game.voice_busy()):
		return false
	var info := Game.voice(id)
	talk_cooldown = info[3] + info[2] + 0.6
	if is_instance_valid(_bubble):
		# the current bubble stays up until this line actually starts
		_bubble.life = minf(_bubble.life, _bubble.age + info[3])
	var col := Color.WHITE
	if info[0] == "you":
		col = Color("#fff3a8")
	if bubble_target:
		_bubble = FX.Bubble.new(bubble_target, info[1], info[2], bubble_offset, col, info[3])
	else:
		_bubble = FX.Bubble.new(self, info[1], info[2], Vector2.ZERO, col, info[3])
		_bubble.follow = func(): return head_pos() + Vector2(0, -105 * absf(scale.y) * (1.0 + puff * 0.45))
		_bubble.tip_at = head_pos
	get_parent().add_child(_bubble)
	return true


## Topples over sideways (dir +1 = head to the right) and lies there.
func fall_over(dir := 1.0, lift := 40.0) -> void:
	bob = false
	var tw := create_tween()
	tw.tween_property(self, "rotation", dir * 1.45, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:y", position.y - lift * absf(scale.y), 0.55)


func shake(dur := 0.4) -> void:
	_shake = dur


func flail(dur := 0.8) -> void:
	_flail = dur


func hop(height := 40.0) -> void:
	var y0 := position.y
	var tw := create_tween()
	tw.tween_property(self, "position:y", y0 - height, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:y", y0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func head_pos() -> Vector2:
	## Global position of the head center.
	return to_global(Vector2(0, -240 + (60 if sitting else 0)))


func head_radius() -> float:
	return 48.0 * scale.x


# ------------------------------------------------------------------ drawing

static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w / 2, col)
	ci.draw_circle(b, w / 2, col)


func _draw() -> void:
	var off := Vector2.ZERO
	if _shake > 0:
		off = Vector2(randf_range(-4, 4), randf_range(-2, 2))
	var breathe := sin(t * 2.2) * 2.5 if bob else 0.0
	var sit := 60.0 if sitting else 0.0
	var hip := Vector2(0, -95 + sit) + off
	var sh := Vector2(0, -182 + sit - breathe) + off
	var head := Vector2(0, -240 + sit - breathe * 1.2) + off
	var shirt := shirt_col.lerp(shirt_col.darkened(0.4), wet)
	var pants := PANTS.lerp(PANTS.darkened(0.35), wet)
	var fl := _flail > 0

	# legs
	if not hide_legs:
		for s: int in [-1, 1]:
			var knee: Vector2
			var foot: Vector2
			if sitting:
				knee = hip + Vector2(s * 26, 6) + Vector2(s * 40, 0)
				foot = knee + Vector2(s * 8, 70)
			else:
				var spread := leg_spread + (sin(t * 25 + s) * 14 if fl else 0.0)
				foot = Vector2(s * (24 + spread), -8)
				knee = (hip + Vector2(s * 16, 0) + foot) / 2 + Vector2(s * 6, 0)
			limb(self, hip + Vector2(s * 16, 0), knee, 30, pants)
			limb(self, knee, foot, 28, pants)
			draw_colored_polygon(FX.ellipse(foot + Vector2(s * 10, 4), 24, 13), SHOE)

	# torso
	var tr := Rect2(sh.x - 46, sh.y - 6, 92, hip.y - sh.y + 22)
	FX.rounded_rect(self, tr, shirt, 26)
	draw_rect(Rect2(tr.position.x + 4, tr.position.y + 40, tr.size.x - 8, 14), shirt.lightened(0.25))
	draw_rect(Rect2(tr.position.x + 4, hip.y + 2, tr.size.x - 8, 12), pants.darkened(0.2))

	# arms
	for s: int in [-1, 1]:
		var ang: float = (arm_l if s < 0 else arm_r)
		var el: float = (elbow_l if s < 0 else elbow_r)
		if fl:
			ang += sin(t * 22 + s * 2) * 1.2
			el += sin(t * 17) * 0.8
		var shoulder := sh + Vector2(s * 44, 16)
		var d1 := Vector2(sin(ang) * s, cos(ang))
		var elbow := shoulder + d1 * 48
		var d2 := d1.rotated(-el * s)
		var hand := elbow + d2 * 44
		limb(self, shoulder, elbow, 24, shirt)
		limb(self, elbow, hand, 20, SKIN)
		draw_circle(hand, 14, SKIN)

	draw_rect(Rect2(head.x - 12, head.y + 30, 24, 26), SKIN.darkened(0.05))
	draw_head(self, head + Vector2(0, -puff * 18), 48 * (1.0 + puff * 0.45), mood, look, _blink > 0, red,
		{"pie": pie, "wet": wet, "snow": snow, "hair_up": hair_up, "t": t, "puff": puff, "bandage": bandage})
	if cap_col.a > 0:
		var hc := head + Vector2(0, -puff * 18)
		var cap := PackedVector2Array()
		for i in 13:
			var a := lerpf(PI, TAU, i / 12.0)
			cap.append(hc + Vector2(cos(a) * 52, sin(a) * 50 - 14))
		draw_colored_polygon(cap, cap_col)
		draw_colored_polygon(FX.ellipse(hc + Vector2(34, -14), 40, 9), cap_col.darkened(0.2))
		draw_circle(hc + Vector2(0, -64), 6, cap_col.darkened(0.3))


static func draw_head(ci: CanvasItem, c: Vector2, r: float, mood: String, look: Vector2,
		blink: bool, red: float, ex := {}) -> void:
	var tt: float = ex.get("t", 0.0)
	var skin := SKIN.lerp(Color("#ff4b3e"), clampf(red, 0, 1) * 0.55)
	if mood == "gross":
		skin = skin.lerp(Color("#9fd36a"), 0.55)
	if mood == "hot":
		skin = skin.lerp(Color("#ff2a1a"), 0.7)
	# ears
	ci.draw_circle(c + Vector2(-r * 0.97, r * 0.08), r * 0.22, skin.darkened(0.1))
	ci.draw_circle(c + Vector2(r * 0.97, r * 0.08), r * 0.22, skin.darkened(0.1))
	ci.draw_circle(c, r, skin)

	# hair
	var hu: float = ex.get("hair_up", 0.0)
	var cap := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI * 0.93, PI * 2.07, i / 16.0)
		cap.append(c + Vector2(cos(a), sin(a)) * r * 1.05)
	cap.append(c + Vector2(r * 0.78, -r * 0.1))
	for i in 7:
		var x := lerpf(0.6, -0.6, i / 6.0)
		cap.append(c + Vector2(x * r, (-0.22 if i % 2 == 0 else -0.42) * r))
	cap.append(c + Vector2(-r * 0.78, -r * 0.1))
	ci.draw_colored_polygon(cap, HAIR)
	for i in 5:
		var a := lerpf(PI * 1.15, PI * 1.85, i / 4.0)
		var base := c + Vector2(cos(a), sin(a)) * r * 0.95
		var dir := Vector2(cos(a), sin(a)).lerp(Vector2.UP, hu * 0.8).normalized()
		var tip := base + dir * r * (0.42 + hu * 0.7 + (i % 2) * 0.12)
		var side := dir.orthogonal() * r * 0.22
		ci.draw_colored_polygon(PackedVector2Array([base - side, base + side, tip]), HAIR)

	# eyes
	var ey := c.y - r * 0.05
	var ex_off := r * 0.38
	var eye_r := r * 0.24
	if mood in ["scared", "surprised"]:
		eye_r = r * 0.3
	for s: int in [-1, 1]:
		var e := Vector2(c.x + s * ex_off, ey)
		if mood == "ko":
			var k := eye_r * 0.75
			ci.draw_line(e + Vector2(-k, -k), e + Vector2(k, k), INK, r * 0.08)
			ci.draw_line(e + Vector2(-k, k), e + Vector2(k, -k), INK, r * 0.08)
		elif mood == "eyes":
			ci.draw_arc(e + Vector2(0, r * 0.02), eye_r * 0.85, 0.2, PI - 0.2, 10, INK, r * 0.08)
			for k in 3:
				var o := Vector2((k - 1) * eye_r * 0.5, 0)
				ci.draw_line(e + o + Vector2(-eye_r * 0.3, -eye_r * 0.9), e + o + Vector2(eye_r * 0.3, eye_r * 0.8), Color("#d0102a"), r * 0.05)
			ci.draw_colored_polygon(FX.ellipse(e + Vector2(s * eye_r * 0.4, eye_r + fmod(tt * 60, r * 0.6)), r * 0.05, r * 0.08, 10), Color(0.5, 0.8, 1, 0.9))
		elif blink and not mood in ["scared", "surprised", "dizzy"] or mood == "sleep":
			ci.draw_arc(e + Vector2(0, -r * 0.04), eye_r * 0.8, 0.15, PI - 0.15, 10, INK, r * 0.07)
		elif mood in ["happy", "laugh"]:
			ci.draw_arc(e + Vector2(0, r * 0.08), eye_r * 0.8, PI + 0.3, TAU - 0.3, 10, INK, r * 0.08)
		elif mood == "hurt":
			var k := eye_r * 0.8
			ci.draw_polyline(PackedVector2Array([e + Vector2(-k * s, -k), e + Vector2(k * s, 0),
				e + Vector2(-k * s, k)]), INK, r * 0.08)
		elif mood == "dizzy":
			var pts := PackedVector2Array()
			for i in 24:
				var a := i * 0.6 + tt * 8.0 * s
				pts.append(e + Vector2(cos(a), sin(a)) * eye_r * (0.1 + i / 26.0))
			ci.draw_circle(e, eye_r, Color.WHITE)
			ci.draw_polyline(pts, INK, r * 0.04)
		else:
			ci.draw_circle(e, eye_r, Color.WHITE)
			ci.draw_arc(e, eye_r, 0, TAU, 20, INK.lerp(skin, 0.5), r * 0.03)
			var pr := r * (0.07 if mood in ["scared", "surprised"] else 0.12)
			ci.draw_circle(e + look * eye_r * 0.45, pr, INK)
			ci.draw_circle(e + look * eye_r * 0.45 + Vector2(-pr * 0.4, -pr * 0.4), pr * 0.35, Color.WHITE)
			if mood == "smug" or mood == "angry":
				# heavy eyelid
				var cut := 0.15 if mood == "smug" else 0.35
				var al := asin(cut)
				var lid := PackedVector2Array()
				for i in 11:
					var a := lerpf(PI + al, TAU - al, i / 10.0)
					lid.append(e + Vector2(cos(a), sin(a)) * (eye_r + 2))
				ci.draw_colored_polygon(lid, skin.darkened(0.06))
				ci.draw_line(lid[0], lid[10], INK, r * 0.04)
		# brows
		var inner := e + Vector2(-s * r * 0.12, -r * 0.3)
		var outer := e + Vector2(s * r * 0.22, -r * 0.34)
		match mood:
			"angry", "hot":
				inner.y += r * 0.14
				outer.y -= r * 0.1
			"scared", "sad", "surprised":
				inner.y -= r * 0.14
				outer.y += r * 0.02
			"smug":
				if s > 0:
					outer.y -= r * 0.12
		ci.draw_line(inner, outer, HAIR.darkened(0.3), r * 0.1)

	# mouth
	var m := c + Vector2(0, r * 0.5)
	match mood:
		"angry":
			var mr := Rect2(m - Vector2(r * 0.34, r * 0.13), Vector2(r * 0.68, r * 0.26))
			FX.rounded_rect(ci, mr, Color.WHITE, r * 0.06, INK, 3)
			ci.draw_line(Vector2(mr.position.x, m.y), Vector2(mr.end.x, m.y), INK, 2)
			for i in 3:
				var x := mr.position.x + mr.size.x * (i + 1) / 4.0
				ci.draw_line(Vector2(x, mr.position.y), Vector2(x, mr.end.y), INK, 2)
		"happy", "laugh":
			var big := 1.3 if mood == "laugh" else 1.0
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(0, PI, i / 12.0)
				pts.append(m + Vector2(-r * 0.36 * big * cos(a), r * 0.3 * big * sin(a) - r * 0.06))
			ci.draw_colored_polygon(pts, Color("#7a1d2a"))
			ci.draw_circle(m + Vector2(0, r * 0.15 * big), r * 0.12 * big, Color("#ff7f8f"))
		"scared", "surprised":
			var open := 1.0 + (sin(tt * 30) * 0.15 if mood == "scared" else 0.0)
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(0, r * 0.05), r * 0.17, r * 0.24 * open, 16), Color("#5a1020"))
		"sleep":
			ci.draw_colored_polygon(FX.ellipse(m, r * 0.08, r * 0.06, 12), Color("#7a1d2a"))
		"ko":
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(m + Vector2(lerpf(-r * 0.3, r * 0.3, i / 10.0), sin(i * 1.4) * r * 0.05))
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(r * 0.12, r * 0.14), r * 0.1, r * 0.13, 12), Color("#ff6f86"))
			ci.draw_polyline(pts, INK, r * 0.06)
		"eyes":
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(0, r * 0.05), r * 0.3, r * 0.22 * (1.0 + sin(tt * 25) * 0.15), 16), Color("#5a1020"))
		"dizzy":
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(m + Vector2(lerpf(-r * 0.3, r * 0.3, i / 10.0), sin(i * 1.4 + tt * 6) * r * 0.06))
			ci.draw_polyline(pts, INK, r * 0.06)
		"gross":
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(m + Vector2(lerpf(-r * 0.3, r * 0.3, i / 10.0), sin(i * 1.9) * r * 0.05))
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(r * 0.08, r * 0.16), r * 0.11, r * 0.15, 12), Color("#ff6f86"))
			ci.draw_polyline(pts, INK, r * 0.06)
		"hot":
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(0, r * 0.05), r * 0.26, r * 0.2, 16), Color("#5a1020"))
			ci.draw_colored_polygon(FX.ellipse(m + Vector2(0, r * 0.2), r * 0.13, r * 0.14, 12), Color("#ff6f86"))
		"sad":
			ci.draw_arc(m + Vector2(0, r * 0.2), r * 0.24, PI + 0.5, TAU - 0.5, 12, INK, r * 0.07)
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(r * 0.45, r * 0.2 + fmod(tt * 40, r * 0.5)), r * 0.06, r * 0.1, 10),
				Color(0.5, 0.8, 1, 0.9))
		"hurt":
			ci.draw_colored_polygon(FX.ellipse(m, r * 0.28, r * 0.12, 16), Color("#5a1020"))
			ci.draw_line(m + Vector2(-r * 0.25, 0), m + Vector2(r * 0.25, 0), Color.WHITE, r * 0.05)
		"smug":
			ci.draw_polyline(PackedVector2Array([m + Vector2(-r * 0.25, r * 0.02),
				m + Vector2(r * 0.05, r * 0.06), m + Vector2(r * 0.3, -r * 0.08)]), INK, r * 0.06)
		_:
			ci.draw_arc(m + Vector2(0, -r * 0.12), r * 0.24, 0.5, PI - 0.5, 12, INK, r * 0.06)

	# allergic swelling: blotches and puffy lips
	var puff: float = ex.get("puff", 0.0)
	if puff > 0.05:
		for i in 9:
			var a := i * 2.3
			ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * (0.35 + fmod(i * 0.29, 0.5)), r * 0.09, Color(0.85, 0.2, 0.45, 0.6 * puff))
		ci.draw_colored_polygon(FX.ellipse(m, r * 0.32 * (0.6 + puff), r * 0.16 * (0.6 + puff), 16), Color("#e0607a"))
	# knocked-out stars
	if mood == "ko":
		for i in 3:
			var a := tt * 3.0 + i * TAU / 3
			var sp := c + Vector2(cos(a) * r * 0.9, -r * 1.15 + sin(a) * r * 0.25)
			var star := PackedVector2Array()
			for k in 10:
				star.append(sp + Vector2.from_angle(-PI / 2 + k * PI / 5) * r * (0.16 if k % 2 == 0 else 0.07))
			ci.draw_colored_polygon(star, Color("#ffe14a"))
	# bandages
	var band: int = ex.get("bandage", 0)
	if band == 1:
		ci.draw_arc(c, r * 0.95, PI * 1.05, PI * 1.95, 16, Color("#f4f4f4"), r * 0.32)
		ci.draw_line(c + Vector2(-r, -r * 0.35), c + Vector2(r, -r * 0.35), Color("#f4f4f4"), r * 0.28)
		ci.draw_circle(c + Vector2(r * 0.3, -r * 0.55), r * 0.12, Color("#e02a3a"))
	elif band == 2:
		ci.draw_line(c + Vector2(-r * 1.02, -r * 0.05), c + Vector2(r * 1.02, -r * 0.05), Color("#f4f4f4"), r * 0.42)
	# blush / anger
	if red > 0.3 or mood in ["laugh", "hot"]:
		var a := clampf(red, 0.3, 1.0) * 0.5
		ci.draw_circle(c + Vector2(-r * 0.58, r * 0.28), r * 0.15, Color(1, 0.2, 0.2, a))
		ci.draw_circle(c + Vector2(r * 0.58, r * 0.28), r * 0.15, Color(1, 0.2, 0.2, a))
	if red > 0.75:
		# anger vein + steam
		var v := c + Vector2(r * 0.55, -r * 0.6)
		for k in 4:
			var a := k * PI / 2 + PI / 4
			ci.draw_line(v + Vector2.from_angle(a) * r * 0.05, v + Vector2.from_angle(a) * r * 0.18, Color("#d01010"), r * 0.06)
		for s: int in [-1, 1]:
			var ph := fmod(tt * 1.6 + (0.5 if s > 0 else 0.0), 1.0)
			var p := c + Vector2(s * r * (1.1 + ph * 0.3), -r * (0.2 + ph * 0.9))
			ci.draw_circle(p, r * (0.12 + ph * 0.18), Color(1, 1, 1, 0.7 * (1.0 - ph)))

	# pie cream
	var pie: float = ex.get("pie", 0.0)
	if pie > 0:
		var n := int(3 + pie * 10)
		for i in n:
			var a := i * 2.4
			var d := r * 0.55 * fmod(i * 0.37, 1.0)
			ci.draw_circle(c + Vector2(cos(a) * d, sin(a) * d + r * 0.1), r * (0.22 + 0.2 * pie), Color(1, 0.98, 0.9))
		for i in int(pie * 6):
			var x := lerpf(-r * 0.7, r * 0.7, fmod(i * 0.618, 1.0))
			var drip := r * (0.3 + 0.4 * fmod(i * 0.41, 1.0)) * pie
			ci.draw_line(c + Vector2(x, r * 0.3), c + Vector2(x, r * 0.3 + drip), Color(1, 0.98, 0.9), r * 0.12)
			ci.draw_circle(c + Vector2(x, r * 0.3 + drip), r * 0.07, Color(1, 0.98, 0.9))
		if pie > 0.3:
			ci.draw_circle(c + Vector2(r * 0.1, -r * 0.55), r * 0.1, Color("#d42033"))
	var wet: float = ex.get("wet", 0.0)
	if wet > 0.05:
		for i in int(wet * 8):
			var x := lerpf(-r * 0.9, r * 0.9, fmod(i * 0.618 + 0.1, 1.0))
			var y := fmod(tt * 120 + i * 37, r * 1.6) - r * 0.6
			ci.draw_colored_polygon(FX.ellipse(c + Vector2(x, y), r * 0.05, r * 0.09, 8), Color(0.55, 0.8, 1, 0.85))
	var snow: float = ex.get("snow", 0.0)
	if snow > 0.05:
		for i in int(snow * 12):
			var a := i * 2.1
			var d := r * 0.8 * fmod(i * 0.53, 1.0)
			ci.draw_circle(c + Vector2(cos(a) * d, sin(a) * d), r * 0.13, Color(0.96, 0.98, 1))
