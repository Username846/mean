extends Node
## Global game state: audio, saving, screen switching and the shared UI theme.

const Lines = preload("res://scripts/lines.gd")
const SAVE_PATH := "user://save.cfg"

## The ten places to bug your brother. Order = order on the map.
const SCENES := [
	{"id": "living_room", "name": "Living Room", "desc": "Grab, fling, poke and tickle him!", "col": Color("#e8a23a")},
	{"id": "kitchen", "name": "Kitchen", "desc": "Pie him right in the face!", "col": Color("#ef6f8f")},
	{"id": "backyard", "name": "Backyard", "desc": "Slingshot water balloons!", "col": Color("#58b947")},
	{"id": "bedroom", "name": "Bedroom", "desc": "Draw on his face while he sleeps.", "col": Color("#7a6ff0")},
	{"id": "game_room", "name": "Game Room", "desc": "Unplug his game at the worst moment.", "col": Color("#35c6d9")},
	{"id": "cafeteria", "name": "Cafeteria", "desc": "Build him a disgusting sandwich.", "col": Color("#f2c443")},
	{"id": "snow_park", "name": "Snow Park", "desc": "Snowball whack-a-bro!", "col": Color("#9fd8ff")},
	{"id": "beach", "name": "Beach", "desc": "Bury him in sand. Add a crab.", "col": Color("#f4d58a")},
	{"id": "treehouse", "name": "Treehouse", "desc": "Shake it, squirrel it, pelt him with acorns!", "col": Color("#8a5cc2")},
	{"id": "carnival", "name": "Carnival", "desc": "Sink him in the dunk tank!", "col": Color("#ff5a4f")},
]

var holder: Node
var current: Node
var theme: Theme

var total_mean := 0
var stars := {}
var best := {}
var seen_ending := false
var injuries := {}           ## scene id -> true once its hospital accident was found
var hospital_from := ""
var hospital_cause := ""
var hospital_serious := false    ## this trip was the gunshot: he doesn't make it
var seen_revenge := false        ## his revenge + the night-time pistol purchase
var has_blaster := false

var music: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var _voice_end := 0.0        ## when the last queued voice line finishes (seconds)
var _voice_gen := 0          ## bumped to cancel queued lines on a screen change
var sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _cache := {}
var _music_id := ""
var music_on := true

var _fade: ColorRect
var _portrait: ColorRect
var volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)
	theme = _make_theme()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.05, 0.14, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_portrait = ColorRect.new()
	_portrait.color = Color(0.12, 0.07, 0.22)
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.visible = false
	var turn := make_label("Turn your device sideways\nto bug your brother!", 64, Color("#ffde3b"))
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.add_child(turn)
	layer.add_child(_portrait)
	load_game()
	set_volume(volume)


func _process(_dt: float) -> void:
	var ws := get_window().size
	_portrait.visible = ws.y > ws.x * 1.05


# ------------------------------------------------------------------ volume / fullscreen

## Master volume, 0..1. The buses themselves live in default_bus_layout.tres:
## buses created from code at runtime stay silent in web exports.
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func fullscreen_supported() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true))
	return true


func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("!!(document.fullscreenElement || document.webkitFullscreenElement)", true))
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		# Browsers only allow fullscreen during a click/tap; bmbFullscreen()
		# (in the page head) runs it now or on the very next pointer release.
		JavaScriptBridge.eval("window.bmbFullscreen && window.bmbFullscreen()", true)
	elif is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------------ screens

func goto(id: String) -> void:
	var tw := create_tween()
	if current != null:
		tw.tween_property(_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(_swap.bind(id))
	tw.tween_property(_fade, "color:a", 0.0, 0.3)


func _swap(id: String) -> void:
	if current != null:
		current.queue_free()
		current = null
	voice_player.stop()
	_voice_gen += 1
	_voice_end = 0.0
	var path := "res://scripts/%s.gd" % id
	if not ResourceLoader.exists(path):
		path = "res://scripts/scenes/%s.gd" % id
	var node: Node = load(path).new()
	node.name = id.capitalize().replace(" ", "")
	current = node
	holder.add_child(node)


func scene_info(id: String) -> Dictionary:
	for s in SCENES:
		if s.id == id:
			return s
	return {}


func star_count() -> int:
	var n := 0
	for s in SCENES:
		if stars.get(s.id, false):
			n += 1
	return n


## Hospital accidents found among the current locations.
func injury_count() -> int:
	var n := 0
	for s in SCENES:
		if injuries.get(s.id, false):
			n += 1
	return n


func rank_title() -> String:
	var ranks := [[0, "Innocent Angel"], [500, "Mildly Annoying"], [2000, "Pesky Sibling"],
		[5000, "Certified Pest"], [10000, "Prank Master"], [20000, "Chaos Gremlin"],
		[40000, "LEGENDARY Little Sibling"]]
	var t: String = ranks[0][1]
	for r in ranks:
		if total_mean >= r[0]:
			t = r[1]
	return t


# ------------------------------------------------------------------ audio

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func play_music(id: String) -> void:
	if id == _music_id and music.playing:
		return
	_music_id = id
	var st := _stream("res://assets/music/%s.ogg" % id)
	if st == null:
		music.stop()
		return
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	music.stream = st
	music.volume_db = 0.0 if music_on else -80.0
	music.play()


func stop_music() -> void:
	_music_id = ""
	music.stop()


func toggle_music() -> bool:
	music_on = not music_on
	music.volume_db = 0.0 if music_on else -80.0
	return music_on


func sfx(name: String, pitch_var := 0.08, vol_db := 0.0, pitch := 1.0) -> void:
	var st := _stream("res://assets/sfx/%s.ogg" % name)
	if st == null:
		return
	var p := sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % sfx_pool.size()
	p.stream = st
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.volume_db = vol_db
	p.play()


## Plays a voice line, or queues it until the line already playing has
## finished, so lines never cut each other off.
## Returns [speaker, subtitle, duration, delay before it starts].
func voice(id: String) -> Array:
	var info: Array = Lines.LINES.get(id, ["bro", id])
	var st := _stream("res://assets/voice/%s.ogg" % id)
	if st == null:
		return [info[0], info[1], 1.5, 0.0]
	var now := Time.get_ticks_msec() / 1000.0
	var delay := maxf(0.0, _voice_end - now)
	if voice_player.playing and delay <= 0.0:
		delay = 0.1  # the clock says it's done, but let the tail finish
	var dur := st.get_length()
	_voice_end = now + delay + dur + 0.15
	if delay <= 0.0:
		_play_voice(st, _voice_gen)
	else:
		get_tree().create_timer(delay).timeout.connect(_play_voice.bind(st, _voice_gen))
	return [info[0], info[1], dur, delay]


func _play_voice(st: AudioStream, gen: int) -> void:
	if voice_player.playing:
		await voice_player.finished
	if gen != _voice_gen:
		return  # the screen changed while it was waiting
	voice_player.stream = st
	voice_player.play()


## True while a line is playing or waiting its turn.
func voice_busy() -> bool:
	return voice_player.playing or _voice_end > Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------------ saving

func add_mean(points: int) -> void:
	total_mean += points


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "total_mean", total_mean)
	cf.set_value("game", "stars", stars)
	cf.set_value("game", "best", best)
	cf.set_value("game", "seen_ending", seen_ending)
	cf.set_value("game", "volume", volume)
	cf.set_value("game", "injuries", injuries)
	cf.set_value("game", "seen_revenge", seen_revenge)
	cf.set_value("game", "has_blaster", has_blaster)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if not FileAccess.file_exists(SAVE_PATH) or cf.load(SAVE_PATH) != OK:
		return
	total_mean = cf.get_value("game", "total_mean", 0)
	stars = cf.get_value("game", "stars", {})
	best = cf.get_value("game", "best", {})
	seen_ending = cf.get_value("game", "seen_ending", false)
	volume = cf.get_value("game", "volume", 0.8)
	injuries = cf.get_value("game", "injuries", {})
	seen_revenge = cf.get_value("game", "seen_revenge", false)
	has_blaster = cf.get_value("game", "has_blaster", false)


func reset_save() -> void:
	total_mean = 0
	stars = {}
	best = {}
	seen_ending = false
	injuries = {}
	seen_revenge = false
	has_blaster = false
	save_game()


# ------------------------------------------------------------------ theme

func _box(col: Color, radius := 14, border := Color(0, 0, 0, 0.35), bw := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Styles the engine's default theme, so every Control picks it up even when it
## sits under a Node2D or CanvasLayer (where theme inheritance stops).
func _make_theme() -> Theme:
	var t := ThemeDB.get_default_theme()
	t.default_font_size = 22
	var base := Color("#ff7b39")
	t.set_stylebox("normal", "Button", _box(base))
	t.set_stylebox("hover", "Button", _box(base.lightened(0.15)))
	t.set_stylebox("pressed", "Button", _box(base.darkened(0.15)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _box(Color(0.4, 0.4, 0.45)))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(1, 1, 0.8))
	t.set_color("font_outline_color", "Button", Color(0.2, 0.08, 0.02))
	t.set_constant("outline_size", "Button", 6)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_outline_color", "Label", Color(0.1, 0.05, 0.15))
	t.set_constant("outline_size", "Label", 8)
	var pb_bg := _box(Color(0.1, 0.06, 0.15, 0.8), 10)
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	var pb_fill := _box(Color("#ff3b3b"), 10, Color(0, 0, 0, 0), 0)
	pb_fill.content_margin_top = 0
	pb_fill.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.14, 0.09, 0.24, 0.92), 18, Color("#ffcf4a"), 4))
	return t


func make_label(text: String, size := 22, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
