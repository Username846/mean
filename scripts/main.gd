extends Node
## Root of the game. The Game autoload swaps screens in and out of this node.
## Run with `-- --smoke` to cycle through every screen (used for testing).


func _ready() -> void:
	Game.holder = self
	var args := OS.get_cmdline_user_args()
	if "--smoke" in args:
		_smoke.call_deferred()
		return
	for a in args:
		if a.begins_with("--shot="):
			_shot.call_deferred(a.substr(7), args)
			return
	Game.goto("title")


func _smoke() -> void:
	var ids := ["title", "menu"]
	for s in Game.SCENES:
		ids.append(s.id)
	ids.append("ending")
	for id in ids:
		if not ResourceLoader.exists("res://scripts/%s.gd" % id) and not ResourceLoader.exists("res://scripts/scenes/%s.gd" % id):
			print("SMOKE skip ", id)
			continue
		print("SMOKE ", id)
		Game._swap(id)
		for i in 240:
			if i % 7 == 0:
				_fake_click(Vector2(randf_range(100, 1180), randf_range(120, 640)), i % 14 == 0)
			await get_tree().process_frame
		if Game.current.get("rage") != null:
			Game.current.add_rage(100, Vector2(640, 360))
			for i in 30:
				await get_tree().process_frame
	print("SMOKE done")
	get_tree().quit()


## Screenshot mode: `-- --shot=<screen> --out=<png> [--wait=<frames>] [--debug=<n>]`
func _shot(id: String, args: PackedStringArray) -> void:
	var out := "/tmp/shot.png"
	var wait := 90
	var dbg := 0
	for a in args:
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--wait="):
			wait = int(a.substr(7))
		elif a.begins_with("--debug="):
			dbg = int(a.substr(8))
	Game._swap(id)
	for i in 20:
		await get_tree().process_frame
	if dbg > 0 and Game.current.has_method("debug_state"):
		Game.current.debug_state(dbg)
	for i in wait:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()


func _fake_click(p: Vector2, down: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	m.relative = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	Input.parse_input_event(m)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = p
	b.global_position = p
	b.pressed = down
	Input.parse_input_event(b)
