extends SceneTree

var _ui_root_scene: PackedScene
var _ui_root: Node
var _capture_main := false
var _capture_event := false
var _mode := "human"
var _step := 0
var _frames_waited := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	
	for arg in args:
		if arg == "--capture-main-ui":
			_capture_main = true
		elif arg == "--capture-event-ui":
			_capture_event = true
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	
	_ui_root_scene = load("res://scenes/ui/ui_root.tscn")
	get_root().size = Vector2i(800, 600)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if _step == 0:
		var run_state := get_root().get_node("RunState")
		run_state.set("mode", _mode)
		
		_ui_root = _ui_root_scene.instantiate()
		get_root().add_child(_ui_root)
		_step = 1
	elif _step == 1:
		_frames_waited += 1
		# Wait a couple of frames for UI to layout properly
		if _frames_waited >= 3:
			if _capture_main:
				_dump_ui_tree("res://.sisyphus/evidence/task-5-main-ui-%s.txt" % _mode, _ui_root)
				_save_mock_screenshot("res://.sisyphus/evidence/task-5-main-ui-%s.png" % _mode)
				print("Captured main UI block-diagram screenshot and dumped UI tree.")
			_step = 2
			_frames_waited = 0
	elif _step == 2:
		if _capture_event:
			if _ui_root.has_method("show_event_modal"):
				var opts: Array[Dictionary] = []
				var opt1 = {}
				opt1["text"] = "接受功法，立即修炼"
				opt1["callback"] = _on_option_1
				opts.append(opt1)
				
				var opt2 = {}
				opt2["text"] = "婉言谢绝，防人之心不可无"
				opt2["callback"] = _on_option_2
				opts.append(opt2)
				
				_ui_root.show_event_modal("事件：奇遇", "你遇到了一位老爷爷，他要传授你功法。", opts)
			else:
				print("UIRoot has no show_event_modal method!")
			_step = 3
		else:
			quit()
	elif _step == 3:
		_frames_waited += 1
		# Wait for event modal to layout
		if _frames_waited >= 3:
			_dump_ui_tree("res://.sisyphus/evidence/task-5-event-modal-%s.txt" % _mode, _ui_root)
			_save_mock_screenshot("res://.sisyphus/evidence/task-5-event-modal-%s.png" % _mode)
			
			# Append a marker
			var file := FileAccess.open("res://.sisyphus/evidence/task-5-event-modal-%s.txt" % _mode, FileAccess.READ_WRITE)
			if file:
				file.seek_end()
				file.store_string("\n=== AFTER CLICKING OPTION 0 ===\n\n")
				file.close()

			# Simulate click on first option
			var event_modal = _ui_root.get_node_or_null("EventModal")
			if event_modal:
				var btn = event_modal.find_child("EventOption_0", true, false)
				if btn and btn is Button:
					btn.pressed.emit()
			
			_step = 4
			_frames_waited = 0
	elif _step == 4:
		_frames_waited += 1
		if _frames_waited >= 3:
			# Append the new UI tree
			var text := _get_node_tree_text(_ui_root, 0)
			var file := FileAccess.open("res://.sisyphus/evidence/task-5-event-modal-%s.txt" % _mode, FileAccess.READ_WRITE)
			if file:
				file.seek_end()
				file.store_string(text)
				file.close()

			print("Captured event modal block-diagram screenshot and dumped UI tree before and after click.")
			quit()

func _on_option_1() -> void:
	var event_log = get_root().get_node("EventLog")
	event_log.add_entry("你接受了老爷爷的功法，感觉体内灵力涌动！")

func _on_option_2() -> void:
	var event_log = get_root().get_node("EventLog")
	event_log.add_entry("你谢绝了功法，老爷爷叹了口气便消失了。")

func _save_mock_screenshot(path: String) -> void:
	var img := Image.create(800, 600, false, Image.FORMAT_RGBA8)
	# Fill background with dark gray
	img.fill(Color(0.1, 0.1, 0.1, 1.0))
	
	# Draw all UI controls as colored blocks/borders
	_draw_ui_blocks(img, _ui_root)
	
	var err := img.save_png(path)
	if err != OK:
		print("Error saving image to ", path, ": ", err)

func _draw_ui_blocks(img: Image, node: Node) -> void:
	if node is Control and node.visible:
		var rect := Rect2i(node.get_global_rect())
		var img_rect := Rect2i(0, 0, img.get_width(), img.get_height())
		var draw_rect := rect.intersection(img_rect)
		
		if draw_rect.has_area():
			var color := _get_color_for_class(node.get_class())
			_draw_rect_border(img, draw_rect, color, 2)
			
			# If it's a structural container, give it a light fill so we see nesting
			if "Container" in node.get_class() or "Panel" in node.get_class():
				var fill_color := color
				fill_color.a = 0.2
				_fill_rect_alpha(img, draw_rect, fill_color)

	for child in node.get_children():
		_draw_ui_blocks(img, child)

func _get_color_for_class(_class_name: String) -> Color:
	match _class_name:
		"Label", "RichTextLabel": return Color(0.9, 0.9, 0.9, 1.0)
		"Button": return Color(0.2, 0.6, 1.0, 1.0)
		"PanelContainer", "Panel": return Color(0.3, 0.3, 0.3, 1.0)
		"VBoxContainer", "HBoxContainer": return Color(0.2, 0.8, 0.2, 1.0)
		"MarginContainer": return Color(0.8, 0.2, 0.2, 1.0)
		_: return Color(0.5, 0.5, 0.5, 1.0)

func _draw_rect_border(img: Image, rect: Rect2i, color: Color, thickness: int) -> void:
	var t := clampi(thickness, 1, rect.size.y / 2)
	var t_x := clampi(thickness, 1, rect.size.x / 2)
	# Top
	_fill_rect_solid(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, t), color)
	# Bottom
	_fill_rect_solid(img, Rect2i(rect.position.x, rect.position.y + rect.size.y - t, rect.size.x, t), color)
	# Left
	_fill_rect_solid(img, Rect2i(rect.position.x, rect.position.y, t_x, rect.size.y), color)
	# Right
	_fill_rect_solid(img, Rect2i(rect.position.x + rect.size.x - t_x, rect.position.y, t_x, rect.size.y), color)

func _fill_rect_solid(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, color)

func _fill_rect_alpha(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				var bg := img.get_pixel(x, y)
				var out := bg.lerp(color, color.a)
				out.a = 1.0
				img.set_pixel(x, y, out)

func _dump_ui_tree(path: String, root_node: Node) -> void:
	var text := _get_node_tree_text(root_node, 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
	else:
		print("Error writing UI tree to ", path)

func _get_node_tree_text(node: Node, depth: int) -> String:
	var indent := ""
	for i in range(depth):
		indent += "  "
		
	var info := node.name + " (" + node.get_class() + ")"
	if node is Control:
		info += " rect:" + str(node.get_global_rect())
	if node is Label:
		info += " text: [" + node.text + "]"
	if node is Button:
		info += " text: [" + node.text + "]"
	if node is RichTextLabel:
		info += " text: [" + node.text + "]"
		
	var result := indent + info + "\n"
	for child in node.get_children():
		result += _get_node_tree_text(child, depth + 1)
		
	return result
