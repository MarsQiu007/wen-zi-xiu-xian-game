extends RefCounted
class_name LayoutValidation

const REPORT_PATH := "res://.sisyphus/evidence/task-17-layout-report.txt"

const TIME_TEXT_PATTERN := "^第\\d+天\\s\\d{2}:\\d{2}$"
const LEFT_RATIO_MIN := 0.25
const LEFT_RATIO_MAX := 0.35
const RIGHT_RATIO_MIN := 0.65
const RIGHT_RATIO_MAX := 0.75

var _overlap_detector := preload("res://scripts/dev/ui_overlap_detector.gd").new()


func validate_all_phases(root: Node) -> Dictionary:
	var report := {
		"ok": true,
		"main_menu": validate_main_menu(root),
		"char_creation": validate_char_creation(root),
		"world_init": validate_world_init(root),
		"main_play": validate_main_play(root),
		"split_ratio": validate_split_ratio(root),
		"time_format": validate_time_format(root),
		"buttons_have_handlers": validate_buttons_have_handlers(root),
	}

	for key in report.keys():
		if key == "ok":
			continue
		var section: Dictionary = report[key] as Dictionary
		if not bool(section.get("ok", false)):
			report["ok"] = false

	_write_report(report)
	return report


func validate_main_menu(root: Node) -> Dictionary:
	return _validate_panel_overlap(root, "MainMenuPanel", "main_menu")


func validate_char_creation(root: Node) -> Dictionary:
	var candidates := ["CharCreationScreen", "_char_creation_screen"]
	return _validate_first_existing(root, candidates, "char_creation")


func validate_world_init(root: Node) -> Dictionary:
	var candidates := ["WorldInitScreen", "_world_init_screen"]
	return _validate_first_existing(root, candidates, "world_init")


func validate_main_play(root: Node) -> Dictionary:
	return _validate_panel_overlap(root, "GameUIContainer", "main_play")


func validate_split_ratio(root: Node) -> Dictionary:
	var left_panel := root.find_child("LeftPanel", true, false)
	var right_panel := root.find_child("RightPanel", true, false)
	if left_panel == null or right_panel == null:
		return {
			"ok": false,
			"section": "split_ratio",
			"error": "未找到 LeftPanel 或 RightPanel",
		}

	if not (left_panel is Control) or not (right_panel is Control):
		return {
			"ok": false,
			"section": "split_ratio",
			"error": "分栏节点不是 Control",
		}

	var left_rect: Rect2 = (left_panel as Control).get_global_rect()
	var right_rect: Rect2 = (right_panel as Control).get_global_rect()
	var total_width := left_rect.size.x + right_rect.size.x
	if total_width <= 0.0:
		return {
			"ok": false,
			"section": "split_ratio",
			"error": "分栏总宽度无效",
		}

	var left_ratio := left_rect.size.x / total_width
	var right_ratio := right_rect.size.x / total_width
	var left_ok := left_ratio >= LEFT_RATIO_MIN and left_ratio <= LEFT_RATIO_MAX
	var right_ok := right_ratio >= RIGHT_RATIO_MIN and right_ratio <= RIGHT_RATIO_MAX

	return {
		"ok": left_ok and right_ok,
		"section": "split_ratio",
		"left_ratio": left_ratio,
		"right_ratio": right_ratio,
		"left_expected": [LEFT_RATIO_MIN, LEFT_RATIO_MAX],
		"right_expected": [RIGHT_RATIO_MIN, RIGHT_RATIO_MAX],
	}


func validate_time_format(root: Node) -> Dictionary:
	var regex := RegEx.new()
	var compile_err := regex.compile(TIME_TEXT_PATTERN)
	if compile_err != OK:
		return {
			"ok": false,
			"section": "time_format",
			"error": "时间正则编译失败",
		}

	var time_panel := root.find_child("TimeControlPanel", true, false)
	if time_panel == null:
		return {
			"ok": false,
			"section": "time_format",
			"error": "未找到 TimeControlPanel",
		}

	var label_node := _find_first_label_with_day_pattern(time_panel)
	if label_node == null:
		return {
			"ok": false,
			"section": "time_format",
			"error": "未找到时间文本 Label",
		}

	var label: Label = label_node as Label
	var text := label.text.strip_edges()
	var matched := regex.search(text) != null

	return {
		"ok": matched,
		"section": "time_format",
		"text": text,
		"pattern": TIME_TEXT_PATTERN,
	}


func validate_buttons_have_handlers(root: Node) -> Dictionary:
	var buttons := _collect_buttons(root)
	var missing: Array[String] = []
	for btn in buttons:
		var conns: Array = btn.get_signal_connection_list("pressed")
		if conns.is_empty():
			missing.append(str(btn.get_path()))

	return {
		"ok": missing.is_empty(),
		"section": "buttons_have_handlers",
		"button_count": buttons.size(),
		"missing_handlers": missing,
	}


func _validate_first_existing(root: Node, candidates: Array, section: String) -> Dictionary:
	for name_variant in candidates:
		var node_name := str(name_variant)
		var node := root.find_child(node_name, true, false)
		if node != null:
			return _validate_node_overlap(root, node, section)
	return {
		"ok": false,
		"section": section,
		"error": "未找到候选节点: %s" % str(candidates),
	}


func _validate_panel_overlap(root: Node, panel_name: String, section: String) -> Dictionary:
	var panel := root.find_child(panel_name, true, false)
	if panel == null:
		return {
			"ok": false,
			"section": section,
			"error": "未找到节点 %s" % panel_name,
		}
	return _validate_node_overlap(root, panel, section)


func _validate_node_overlap(root: Node, panel: Node, section: String) -> Dictionary:
	if not (panel is CanvasItem):
		return {
			"ok": false,
			"section": section,
			"error": "目标节点不是 CanvasItem",
		}

	var top_owner := _find_top_level_owner(root, panel)
	if top_owner == null:
		return {
			"ok": false,
			"section": section,
			"error": "目标节点不在 root 子树内",
		}

	var restore_list: Array[Dictionary] = []
	for child in root.get_children():
		if child is CanvasItem:
			restore_list.append({"node": child, "visible": (child as CanvasItem).visible})
	for item in restore_list:
		var node: CanvasItem = item["node"]
		node.visible = (node == top_owner)

	var panel_canvas := panel as CanvasItem
	var panel_prev_visible := panel_canvas.visible
	panel_canvas.visible = true

	var critical := _overlap_detector.detect_overlaps(panel, true)
	panel_canvas.visible = panel_prev_visible

	for item in restore_list:
		var node: CanvasItem = item["node"]
		node.visible = bool(item["visible"])

	return {
		"ok": critical.is_empty(),
		"section": section,
		"panel": str(panel.get_path()),
		"critical_count": critical.size(),
		"critical_overlaps": critical,
	}


func _find_top_level_owner(root: Node, target: Node) -> CanvasItem:
	if root == null or target == null:
		return null
	if root == target:
		return null

	var current: Node = target
	while current != null and current.get_parent() != root:
		current = current.get_parent()
	if current == null:
		return null
	if current is CanvasItem:
		return current as CanvasItem
	return null


func _collect_buttons(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	_collect_buttons_recursive(root, result)
	return result


func _collect_buttons_recursive(node: Node, result: Array[Button]) -> void:
	if node is Button:
		var canvas := node as CanvasItem
		if canvas.visible:
			result.append(node as Button)
	for child in node.get_children():
		_collect_buttons_recursive(child, result)


func _find_first_label_with_day_pattern(root: Node) -> Label:
	for child in root.get_children():
		if child is Label:
			var text := (child as Label).text
			if text.find("第") != -1 and text.find("天") != -1 and text.find(":") != -1:
				return child as Label
		var nested := _find_first_label_with_day_pattern(child)
		if nested != null:
			return nested
	return null


func _write_report(report: Dictionary) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入布局验证报告: %s" % REPORT_PATH)
		return

	file.store_string("=== Task 17 Layout Validation Report ===\n")
	file.store_string("overall_ok=%s\n\n" % str(report.get("ok", false)))

	for key in ["main_menu", "char_creation", "world_init", "main_play", "split_ratio", "time_format", "buttons_have_handlers"]:
		var section: Dictionary = report.get(key, {})
		file.store_string("[%s]\n" % key)
		for k in section.keys():
			file.store_string("%s=%s\n" % [str(k), str(section[k])])
		file.store_string("\n")

	file.close()
