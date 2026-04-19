extends RefCounted
class_name UIOverlapDetector


func detect_overlaps(root: Node, visible_only: bool = true) -> Array[Dictionary]:
	if root == null:
		return []

	var controls: Array[Control] = _collect_leaf_controls(root, visible_only)
	var critical_overlaps: Array[Dictionary] = []

	for i in range(controls.size()):
		var a: Control = controls[i]
		var area_a: Rect2 = a.get_global_rect()
		if not area_a.has_area():
			continue
		for j in range(i + 1, controls.size()):
			var b: Control = controls[j]
			var area_b: Rect2 = b.get_global_rect()
			if not area_b.has_area():
				continue

			var overlap_result: Dictionary = classify_overlap(area_a, area_b, _get_node_path(a), _get_node_path(b))
			if str(overlap_result.get("level", "None")) != "Critical":
				continue

			if _is_container_sibling_exception(a, b):
				continue

			overlap_result["node_a"] = _get_node_path(a)
			overlap_result["node_b"] = _get_node_path(b)
			critical_overlaps.append(overlap_result)

	return critical_overlaps


func classify_overlap(area_a: Rect2, area_b: Rect2, node_a_name: String, node_b_name: String) -> Dictionary:
	var intersection: Rect2 = area_a.intersection(area_b)
	if not intersection.has_area():
		return {
			"level": "None",
			"node_a": node_a_name,
			"node_b": node_b_name,
			"overlap_rect": _rect2_to_dict(Rect2()),
			"overlap_percentage": 0.0,
		}

	var overlap_percentage: float = get_overlap_percentage(area_a, area_b)
	var level := "None"
	if overlap_percentage > 50.0:
		level = "Critical"
	elif overlap_percentage < 5.0:
		level = "Minor"

	return {
		"level": level,
		"node_a": node_a_name,
		"node_b": node_b_name,
		"overlap_rect": _rect2_to_dict(intersection),
		"overlap_percentage": overlap_percentage,
	}


func get_overlap_percentage(area_a: Rect2, area_b: Rect2) -> float:
	var intersection: Rect2 = area_a.intersection(area_b)
	if not intersection.has_area():
		return 0.0

	var overlap_area: float = intersection.size.x * intersection.size.y
	var area_size_a: float = area_a.size.x * area_a.size.y
	var area_size_b: float = area_b.size.x * area_b.size.y
	var min_area: float = min(area_size_a, area_size_b)
	if min_area <= 0.0:
		return 0.0

	return (overlap_area / min_area) * 100.0


func _collect_leaf_controls(root: Node, visible_only: bool) -> Array[Control]:
	var result: Array[Control] = []
	if root is Control:
		_collect_control_recursive(root as Control, visible_only, result)
	else:
		for child in root.get_children():
			if child is Control:
				_collect_control_recursive(child as Control, visible_only, result)
	return result


func _collect_control_recursive(node: Control, visible_only: bool, result: Array[Control]) -> void:
	if visible_only and not node.visible:
		return

	if node is Container:
		for child in node.get_children():
			if child is Control:
				_collect_control_recursive(child as Control, visible_only, result)
		return

	var has_control_child := false
	for child in node.get_children():
		if child is Control:
			has_control_child = true
			_collect_control_recursive(child as Control, visible_only, result)

	if not has_control_child:
		result.append(node)


func _is_container_sibling_exception(a: Control, b: Control) -> bool:
	var parent_a := a.get_parent()
	var parent_b := b.get_parent()
	if parent_a == null or parent_b == null:
		return false
	if parent_a != parent_b:
		return false
	if not (parent_a is VBoxContainer or parent_a is HBoxContainer or parent_a is MarginContainer):
		return false

	# 同级容器子节点可能存在布局抖动或边缘贴合，不计为 Critical
	return true


func _get_node_path(node: Node) -> String:
	if node == null:
		return ""
	return str(node.get_path())


func _rect2_to_dict(rect: Rect2) -> Dictionary:
	return {
		"position": {
			"x": rect.position.x,
			"y": rect.position.y,
		},
		"size": {
			"x": rect.size.x,
			"y": rect.size.y,
		},
	}
