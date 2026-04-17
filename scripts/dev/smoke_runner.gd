extends SceneTree

const TASK_BOOT := "boot"
const TASK_RESOURCES := "resources"
const TASK_DAY_TICK := "day_tick"

const MODE_HUMAN := "human"
const MODE_DEITY := "deity"

const GAME_ROOT_SCENE_PATH := "res://scenes/main/game_root.tscn"
const SIMULATION_RUNNER_SCENE_PATH := "res://scenes/sim/simulation_runner.tscn"

const TIME_SERVICE_SCRIPT := preload("res://autoload/time_service.gd")
const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")
const EVENT_LOG_SCRIPT := preload("res://autoload/event_log.gd")

const SAMPLE_PATHS := {
	"characters": [
		"res://resources/world/samples/mvp_character_village_heir.tres",
		"res://resources/world/samples/mvp_character_divine_visionary.tres",
	],
	"families": [
		"res://resources/world/samples/mvp_family_lin_family.tres",
		"res://resources/world/samples/mvp_family_shen_family.tres",
	],
	"factions": [
		"res://resources/world/samples/mvp_faction_village_settlement.tres",
		"res://resources/world/samples/mvp_faction_small_sect.tres",
		"res://resources/world/samples/mvp_faction_small_city.tres",
		"res://resources/world/samples/mvp_divine_cult.tres",
	],
	"regions": [
		"res://resources/world/samples/mvp_village_region.tres",
		"res://resources/world/samples/mvp_sect_mountain_region.tres",
		"res://resources/world/samples/mvp_small_city_region.tres",
		"res://resources/world/samples/mvp_beast_ridge_region.tres",
		"res://resources/world/samples/mvp_ghost_ruins_region.tres",
		"res://resources/world/samples/mvp_secret_realm_gate_region.tres",
		"res://resources/world/samples/mvp_deadfall_abyss_region.tres",
	],
	"event_templates": [
		"res://resources/world/samples/mvp_event_harvest_festival.tres",
		"res://resources/world/samples/mvp_event_sect_recruitment.tres",
	],
	"doctrines": [
		"res://resources/world/samples/mvp_doctrine_orthodox_doctrine.tres",
		"res://resources/world/samples/mvp_doctrine_divine_doctrine.tres",
	],
	"deities": [
		"res://resources/world/samples/mvp_deity_patron_deity.tres",
	],
}


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var task := str(args.get("task", TASK_BOOT))
	var mode := str(args.get("mode", MODE_HUMAN))
	var seed := int(args.get("seed", 42))
	var days := int(args.get("days", 10))
	var stop_on_pause := bool(args.get("stop-on-pause", false))
	var auto_resolve_pause := bool(args.get("auto-resolve-pause", true))

	match task:
		TASK_BOOT:
			_run_boot_task()
		TASK_RESOURCES:
			_run_resources_task()
		TASK_DAY_TICK:
			_run_day_tick_task(mode, seed, days, stop_on_pause, auto_resolve_pause)
		_:
			print("错误：未知任务 %s，可选值为 boot/resources/day_tick" % _sanitize(task))
			quit(1)


func _run_boot_task() -> void:
	print("SMOKE_START|task=boot")
	var scene_text := FileAccess.get_file_as_string(GAME_ROOT_SCENE_PATH)
	if scene_text.is_empty():
		print("[error] 无法读取场景文件: %s" % GAME_ROOT_SCENE_PATH)
		quit(1)
		return

	var ext_resources: Dictionary = {}
	var root_name := ""
	var root_type := ""
	var child_count := 0
	for raw_line in scene_text.split("\n", false):
		var line := raw_line.strip_edges()
		if line.begins_with("[ext_resource"):
			var ext_id := _extract_quoted_value(line, "id")
			var ext_path := _extract_quoted_value(line, "path")
			if not ext_id.is_empty():
				ext_resources[ext_id] = ext_path
		elif line.begins_with("[node"):
			var node_name := _extract_quoted_value(line, "name")
			var node_type := _extract_quoted_value(line, "type")
			var instance_id := _extract_instance_id(line)
			var parent := _extract_quoted_value(line, "parent")
			if parent.is_empty():
				root_name = node_name
				root_type = node_type
			else:
				child_count += 1
				print("CHILD|name=%s|class=%s|instance=%s" % [
					_sanitize(node_name),
					_sanitize(node_type),
					_sanitize(str(ext_resources.get(instance_id, ""))) if not instance_id.is_empty() else "",
				])

	print("ROOT|name=%s|class=%s|children=%d" % [_sanitize(root_name), _sanitize(root_type), child_count])
	quit(0)


func _run_resources_task() -> void:
	print("SMOKE_START|task=resources")
	var failed := false

	for group_name in SAMPLE_PATHS.keys():
		var paths: Array = SAMPLE_PATHS[group_name]
		for path in paths:
			var resource := load(path)
			if resource == null:
				failed = true
				print("[error] 无法加载: %s" % path)
				continue
			print(_describe_resource(str(group_name), path, resource))

	var catalog := load("res://resources/world/world_data_catalog.tres")
	if catalog == null:
		failed = true
		print("[error] 无法加载目录资源: res://resources/world/world_data_catalog.tres")
	elif catalog.has_method("validate_required_fields"):
		var world_catalog: Resource = catalog
		print("[catalog] characters=%d families=%d factions=%d regions=%d events=%d doctrines=%d deities=%d" % [
			world_catalog.characters.size(),
			world_catalog.families.size(),
			world_catalog.factions.size(),
			world_catalog.regions.size(),
			world_catalog.event_templates.size(),
			world_catalog.doctrines.size(),
			world_catalog.deities.size(),
		])
		var issues: PackedStringArray = world_catalog.validate_required_fields()
		if issues.is_empty():
			print("[catalog] 字段校验通过")
		else:
			failed = true
			for issue in issues:
				print("[catalog-error] %s" % issue)
	else:
		failed = true
		print("[error] 目录资源类型不正确")

	quit(1 if failed else 0)


func _run_day_tick_task(mode: String, seed: int, days: int, stop_on_pause: bool, auto_resolve_pause: bool) -> void:
	var validated_mode := _normalize_mode(mode)
	print("SMOKE_START|task=day_tick|mode=%s|seed=%d|days=%d|stop_on_pause=%s|auto_resolve_pause=%s" % [
		validated_mode,
		seed,
		days,
		str(stop_on_pause),
		str(auto_resolve_pause),
	])

	var time_service_info := _ensure_service("TimeService", TIME_SERVICE_SCRIPT)
	var run_state_info := _ensure_service("RunState", RUN_STATE_SCRIPT)
	var event_log_info := _ensure_service("EventLog", EVENT_LOG_SCRIPT)

	var time_service: Node = time_service_info.get("node")
	var run_state: Node = run_state_info.get("node")
	var event_log: Node = event_log_info.get("node")

	run_state.mode = StringName(validated_mode)
	if run_state.has_method("set_mode"):
		run_state.set_mode(StringName(validated_mode))

	var runner_scene: PackedScene = load(SIMULATION_RUNNER_SCENE_PATH)
	if runner_scene == null:
		print("[error] 无法加载模拟场景: %s" % SIMULATION_RUNNER_SCENE_PATH)
		quit(1)
		return

	var runner: Node = runner_scene.instantiate()
	root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.bootstrap(seed)

	var summary: Dictionary = runner.advance_days(days, stop_on_pause, auto_resolve_pause)
	for line in event_log.get_summary_lines():
		print(line)

	if runner.has_pending_pause():
		var checkpoint: Dictionary = runner.get_pending_checkpoint()
		print("PAUSE|day=%s|title=%s|cause=%s|result=%s" % [
			str(checkpoint.get("day", 0)),
			_sanitize(str(checkpoint.get("title", ""))),
			_sanitize(str(checkpoint.get("direct_cause", ""))),
			_sanitize(str(checkpoint.get("result", ""))),
		])

	print("SUMMARY|task=day_tick|mode=%s|seed=%s|requested_days=%s|advanced_days=%s|resolved_days=%s|total_minutes=%s|entries=%s|paused=%s|pause_title=%s|pause_count=%s" % [
		validated_mode,
		str(summary.get("seed", seed)),
		str(summary.get("requested_days", days)),
		str(summary.get("advanced_days", 0)),
		str(summary.get("resolved_days", 0)),
		str(summary.get("total_minutes", 0)),
		str(summary.get("entries", 0)),
		str(summary.get("paused", false)),
		_sanitize(str(summary.get("pause_title", ""))),
		str(summary.get("pause_count", 0)),
	])

	runner.free()
	if bool(event_log_info.get("created", false)):
		event_log.free()
	if bool(run_state_info.get("created", false)):
		run_state.free()
	if bool(time_service_info.get("created", false)):
		time_service.free()
	quit(0)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"task": TASK_BOOT,
		"mode": MODE_HUMAN,
		"seed": 42,
		"days": 10,
		"stop-on-pause": false,
		"auto-resolve-pause": true,
	}
	for arg in raw_args:
		if not arg.begins_with("--"):
			continue
		var trimmed := arg.trim_prefix("--")
		var parts := trimmed.split("=", false, 1)
		var key := parts[0]
		var value := "true"
		if parts.size() > 1:
			value = parts[1]
		match key:
			"task", "mode":
				parsed[key] = value
			"seed", "days":
				parsed[key] = int(value)
			"stop-on-pause", "auto-resolve-pause":
				parsed[key] = _to_bool(value)
	return parsed


func _normalize_mode(mode: String) -> String:
	var lowered := mode.to_lower()
	if lowered != MODE_HUMAN and lowered != MODE_DEITY:
		return MODE_HUMAN
	return lowered


func _ensure_service(node_name: String, script_resource: Script) -> Dictionary:
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		return {
			"node": existing,
			"created": false,
		}

	var service := Node.new()
	service.name = node_name
	service.set_script(script_resource)
	root.add_child(service)
	return {
		"node": service,
		"created": true,
	}


func _describe_resource(group_name: String, path: String, resource: Resource) -> String:
	if resource == null or not resource.has_method("get"):
		return "[error] %s 不是资源对象: %s" % [group_name, path]

	var base_id: Variant = resource.get("id")
	var base_name: Variant = resource.get("display_name")
	var human_visible: Variant = resource.get("human_visible")
	var deity_visible: Variant = resource.get("deity_visible")
	if base_id == null:
		base_id = ""
	if base_name == null:
		base_name = ""
	if human_visible == null:
		human_visible = true
	if deity_visible == null:
		deity_visible = true
	if str(base_name).is_empty() and str(base_id).is_empty():
		return "[error] %s 不是 WorldBaseData 派生资源: %s" % [group_name, path]

	var mode_summary := "human=%s deity=%s" % [str(human_visible), str(deity_visible)]
	match group_name:
		"characters":
			return "[character] %s | %s | family=%s faction=%s region=%s faith=%s inheritance=%s" % [base_id, base_name, str(resource.get("family_id")), str(resource.get("faction_id")), str(resource.get("region_id")), str(resource.get("faith_affinity")), str(resource.get("inheritance_priority"))]
		"families":
			return "[family] %s | %s | seat=%s rule=%s members=%s" % [base_id, base_name, str(resource.get("seat_region_id")), str(resource.get("inheritance_rule")), str((resource.get("notable_member_ids") as PackedStringArray).size())]
		"factions":
			return "[faction] %s | %s | type=%s tier=%s region=%s doctrine=%s deity=%s" % [base_id, base_name, str(resource.get("faction_type")), str(resource.get("faction_tier")), str(resource.get("headquarters_region_id")), str(resource.get("associated_doctrine_id")), str(resource.get("patron_deity_id"))]
		"regions":
			return "[region] %s | %s | type=%s control=%s pop=%s resources=%s" % [base_id, base_name, str(resource.get("region_type")), str(resource.get("controlling_faction_id")), str(resource.get("active_population_hint")), ",".join(resource.get("resource_tags") as PackedStringArray)]
		"event_templates":
			return "[event] %s | %s | type=%s severity=%s %s" % [base_id, base_name, str(resource.get("event_type")), str(resource.get("severity")), mode_summary]
		"doctrines":
			return "[doctrine] %s | %s | type=%s scope=%s deity=%s tenets=%s" % [base_id, base_name, str(resource.get("doctrine_type")), str(resource.get("authority_scope")), str(resource.get("associated_deity_id")), str((resource.get("core_tenets") as PackedStringArray).size())]
		"deities":
			return "[deity] %s | %s | type=%s scope=%s faith=%s domains=%s" % [base_id, base_name, str(resource.get("deity_type")), str(resource.get("manifestation_scope")), str(resource.get("faith_income_hint")), str((resource.get("domain_tags") as PackedStringArray).size())]
		_:
			return "[warn] 未知分组 %s: %s (%s)" % [group_name, path, mode_summary]


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")


func _to_bool(value: String) -> bool:
	var lowered := value.to_lower()
	return lowered != "false" and lowered != "0" and lowered != "off" and lowered != "no"


func _extract_quoted_value(line: String, key: String) -> String:
	var marker := key + "=\""
	var start := line.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)


func _extract_instance_id(line: String) -> String:
	var marker := "instance=ExtResource(\""
	var start := line.find(marker)
	if start == -1:
		return ""
	start += marker.length()
	var end := line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)
