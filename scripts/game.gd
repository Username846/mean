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
	{"id": "attic", "name": "Haunted Attic", "desc": "Hide... and jump-scare him!", "col": Color("#8a5cc2")},
	{"id": "carnival", "name": "Carnival", "desc": "Sink him in the dunk tank!", "col": Color("#ff5a4f")},
]

var holder: Node
var current: Node
var theme: Theme

var total_mean := 0
var stars := {}
var best := {}
var seen_ending := false

var music: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _cache := {}
var _music_id := ""
var music_on := true

var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
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
	load_game()


func _setup_buses() -> void:
	for b in [["Music", -9.0], ["Voice", 2.0], ["SFX", -4.0]]:
		if AudioServer.get_bus_index(b[0]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b[0])
			AudioServer.set_bus_send(i, "Master")
			AudioServer.set_bus_volume_db(i, b[1])
	# duck the music a little under dialogue
	var comp := AudioEffectCompressor.new()
	comp.sidechain = "Voice"
	comp.threshold = -22.0
	comp.ratio = 4.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), comp)


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


## Plays a voice line; returns [speaker, subtitle, duration].
func voice(id: String) -> Array:
	var info: Array = Lines.LINES.get(id, ["bro", id])
	var st := _stream("res://assets/voice/%s.ogg" % id)
	var dur := 1.5
	if st != null:
		voice_player.stream = st
		voice_player.play()
		dur = st.get_length()
	return [info[0], info[1], dur]


func voice_busy() -> bool:
	return voice_player.playing


# ------------------------------------------------------------------ saving

func add_mean(points: int) -> void:
	total_mean += points


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "total_mean", total_mean)
	cf.set_value("game", "stars", stars)
	cf.set_value("game", "best", best)
	cf.set_value("game", "seen_ending", seen_ending)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if not FileAccess.file_exists(SAVE_PATH) or cf.load(SAVE_PATH) != OK:
		return
	total_mean = cf.get_value("game", "total_mean", 0)
	stars = cf.get_value("game", "stars", {})
	best = cf.get_value("game", "best", {})
	seen_ending = cf.get_value("game", "seen_ending", false)


func reset_save() -> void:
	total_mean = 0
	stars = {}
	best = {}
	seen_ending = false
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
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
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
