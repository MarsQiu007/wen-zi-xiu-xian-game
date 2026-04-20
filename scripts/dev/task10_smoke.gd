extends RefCounted
class_name Task10Smoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, scenario: String, seed: int, _days: int) -> Dictionary:
	var normalized_scenario := scenario.to_lower()
	if normalized_scenario == "map":
		print("SMOKE_START|task=task10|scenario=map|seed=%d" % seed)
		return _run_map_case(scene_root, time_service, run_state, event_log, seed)
	print("SMOKE_START|task=task10|scenario=minimal_closure|seed=%d" % seed)
	var blocked_case := _run_blocked_before_unlock(scene_root, time_service, run_state, event_log, seed)
	if bool(blocked_case.get("failed", false)):
		return blocked_case
	var growth_case := _run_unlock_then_grow(scene_root, time_service, run_state, event_log, seed)
	if bool(growth_case.get("failed", false)):
		return growth_case
	var failure_case := _run_breakthrough_failure(scene_root, time_service, run_state, event_log, seed)
	if bool(failure_case.get("failed", false)):
		return failure_case
	var inheritance_case := _run_inheritance_continuity(scene_root, time_service, run_state, event_log, seed)
	if bool(inheritance_case.get("failed", false)):
		return inheritance_case
	return {
		"failed": false,
		"message": "task10 最小闭环验证通过",
	}


func _run_map_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	var location_service: Node = scene_root.get_node_or_null("LocationService")

	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state, location_service)
	runner.bootstrap(seed)

	var ui_scene: PackedScene = load("res://scenes/ui/ui_root.tscn")
	if ui_scene == null:
		runner.free()
		return {
			"failed": true,
			"message": "Map smoke: 无法加载 ui_root.tscn",
		}
	var ui_root: Node = ui_scene.instantiate()
	scene_root.add_child(ui_root)
	if ui_root == null:
		runner.free()
		return {
			"failed": true,
			"message": "Map smoke: 找不到 UIRoot",
		}

	if ui_root.find_child("MapPanel", true, false) == null and ui_root.has_method("_ready"):
		ui_root.call("_ready")

	var view_map_btn := ui_root.find_child("ViewMapBtn", true, false)
	if view_map_btn == null or not (view_map_btn is Button):
		ui_root.free()
		runner.free()
		return {
			"failed": true,
			"message": "Map smoke: 找不到 ViewMapBtn",
		}
	(view_map_btn as Button).pressed.emit()

	var map_panel := ui_root.find_child("MapPanel", true, false)
	var region_tree: Tree = _find_tree_node(map_panel)
	var detail_label: RichTextLabel = _find_rich_text_label_node(map_panel)
	var visible_ok := map_panel != null and (map_panel as CanvasItem).visible
	var tree_ok := region_tree != null
	var detail_ok := detail_label != null
	var region_count := _count_region_items(region_tree)
	var has_regions := region_count >= 1

	print("CASE|scenario=task10_map|map_panel_visible=%s|tree_exists=%s|detail_exists=%s|region_items=%d" % [
		str(visible_ok),
		str(tree_ok),
		str(detail_ok),
		region_count,
	])
	print("ASSERT|scenario=task10_map|stable_ui=%s|has_regions=%s" % [
		str(visible_ok and tree_ok and detail_ok),
		str(has_regions),
	])

	ui_root.free()
	runner.free()
	return {
		"failed": not (visible_ok and tree_ok and detail_ok and has_regions),
		"message": "task10 地图最小烟测通过" if (visible_ok and tree_ok and detail_ok and has_regions) else "task10 地图最小烟测失败",
	}


func _find_tree_node(root_node: Node) -> Tree:
	if root_node == null:
		return null
	if root_node is Tree:
		return root_node as Tree
	for child in root_node.get_children():
		var found := _find_tree_node(child)
		if found != null:
			return found
	return null


func _find_rich_text_label_node(root_node: Node) -> RichTextLabel:
	if root_node == null:
		return null
	if root_node is RichTextLabel:
		return root_node as RichTextLabel
	for child in root_node.get_children():
		var found := _find_rich_text_label_node(child)
		if found != null:
			return found
	return null


func _count_region_items(region_tree: Tree) -> int:
	if region_tree == null:
		return 0
	var root_item := region_tree.get_root()
	if root_item == null:
		return 0
	var count := 0
	var child := root_item.get_first_child()
	while child != null:
		count += _count_tree_item_recursive(child)
		child = child.get_next()
	return count


func _count_tree_item_recursive(item: TreeItem) -> int:
	if item == null:
		return 0
	var total := 1
	var child := item.get_first_child()
	while child != null:
		total += _count_tree_item_recursive(child)
		child = child.get_next()
	return total


func _run_blocked_before_unlock(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed, 3, {
		"opening_type": "youth",
		"strategy": "passive",
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var cultivation_state: Dictionary = runtime.get("cultivation_state", {})
	var blocked := not bool(runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false))
	var still_mortal := str(cultivation_state.get("realm", "")) == "mortal"
	var no_practice := int(cultivation_state.get("practice_days", 0)) == 0
	print("ASSERT|scenario=task10_blocked_before_unlock|blocked=%s|realm=%s|practice_days=%d" % [
		str(blocked),
		str(cultivation_state.get("realm", "")),
		int(cultivation_state.get("practice_days", 0)),
	])
	return {
		"failed": not (blocked and still_mortal and no_practice),
		"message": "未解锁前仍进入修炼闭环",
	}


func _run_unlock_then_grow(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed + 1, 3, {
		"opening_type": "youth",
		"action_plan": ["seek_master", "visit_sect", "study_classics"],
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var cultivation_state: Dictionary = runtime.get("cultivation_state", {})
	var unlocked := bool(runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false))
	var reached_qi := str(cultivation_state.get("realm", "")) == "qi_training" and int(cultivation_state.get("stage_index", 0)) >= 1
	var lifespan_visible := int(cultivation_state.get("lifespan_remaining_years", 0)) > 40
	print("ASSERT|scenario=task10_unlock_then_grow|unlocked=%s|realm=%s|stage_index=%d|lifespan_remaining=%d" % [
		str(unlocked),
		str(cultivation_state.get("realm_label", "")),
		int(cultivation_state.get("stage_index", 0)),
		int(cultivation_state.get("lifespan_remaining_years", 0)),
	])
	return {
		"failed": not (unlocked and reached_qi and lifespan_visible),
		"message": "解锁后未能稳定进入炼气",
	}


func _run_breakthrough_failure(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed + 2, 5, {
		"opening_type": "youth",
		"action_plan": ["seek_master", "visit_sect", "study_classics", "work_for_food", "support_family"],
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var cultivation_state: Dictionary = runtime.get("cultivation_state", {})
	var found_failure_log := false
	for entry in event_log.entries:
		if str(entry.get("category", "")) == "human_cultivation" and str(entry.get("direct_cause", "")) == "breakthrough_failed":
			found_failure_log = true
	var failed_breakthrough := str(cultivation_state.get("last_breakthrough_outcome", "")) == "failed"
	var weakness_applied := int(cultivation_state.get("weakness_days", 0)) >= 1
	var lifespan_lost := int(cultivation_state.get("lifespan_remaining_years", 0)) == 63
	print("ASSERT|scenario=task10_breakthrough_failure|failed_breakthrough=%s|weakness_days=%d|lifespan_remaining=%d|failure_log=%s" % [
		str(failed_breakthrough),
		int(cultivation_state.get("weakness_days", 0)),
		int(cultivation_state.get("lifespan_remaining_years", 0)),
		str(found_failure_log),
	])
	return {
		"failed": not (failed_breakthrough and weakness_applied and lifespan_lost and found_failure_log),
		"message": "稳定冲关失败后果未写入运行时或日志",
	}


func _run_inheritance_continuity(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int) -> Dictionary:
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed + 3, 4, {
		"player_id": "task10_founder",
		"player_name": "许见山",
		"family_id": "mvp_lin_family",
		"direct_line_child_ids": ["task10_heir"],
		"forced_death_day": 1,
		"runtime_characters": [
			{
				"id": "task10_heir",
				"display_name": "许承岳",
				"family_id": "mvp_lin_family",
				"inheritance_priority": 1,
				"cultivation_gate": {
					"contact_score": 4,
					"has_active_contact": true,
					"opportunity_unlocked": true,
					"last_contact_action": "seek_master",
				},
				"cultivation_state": {
					"realm": "mortal",
					"realm_label": "凡体",
					"stage_index": 0,
					"progress": 1,
					"progress_to_next": 2,
				},
			},
		],
		"action_plan": ["seek_master", "study_classics", "work_for_food", "support_family"],
	})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var cultivation_state: Dictionary = runtime.get("cultivation_state", {})
	var switched := str(runtime.get("player", {}).get("id", "")) == "task10_heir"
	var heir_qi := str(cultivation_state.get("realm", "")) == "qi_training"
	print("ASSERT|scenario=task10_inheritance_continuity|current_player=%s|realm=%s|stage_index=%d" % [
		str(runtime.get("player", {}).get("id", "")),
		str(cultivation_state.get("realm_label", "")),
		int(cultivation_state.get("stage_index", 0)),
	])
	return {
		"failed": not (switched and heir_qi),
		"message": "视角切换后新主角未能继续修炼",
	}


func _run_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int, options: Dictionary) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.configure_human_mode(options)
	runner.bootstrap(seed)
	runner.advance_days(days, false, true)
	for line in event_log.get_summary_lines(40):
		print(line)
	var runtime: Dictionary = runner.get_human_runtime()
	runner.free()
	return {
		"failed": runtime.is_empty(),
		"message": "task10 运行时为空",
		"runtime": runtime,
	}
