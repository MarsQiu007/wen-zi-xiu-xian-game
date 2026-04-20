extends SceneTree

class_name Task9LocationSmoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")
const TIME_SERVICE_SCRIPT := preload("res://autoload/time_service.gd")
const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")
const EVENT_LOG_SCRIPT := preload("res://autoload/event_log.gd")
const LOCATION_SERVICE_SCRIPT := preload("res://autoload/location_service.gd")

const CHARACTER_ID := &"mvp_village_heir"
const ADJACENT_TARGET := &"mvp_small_city_region"
const NON_ADJACENT_TARGET := &"mvp_beast_ridge_region"


func _initialize() -> void:
	var time_service: Node = _ensure_service("TimeService", TIME_SERVICE_SCRIPT)
	var run_state: Node = _ensure_service("RunState", RUN_STATE_SCRIPT)
	var event_log: Node = _ensure_service("EventLog", EVENT_LOG_SCRIPT)
	var location_service: Node = _ensure_service("LocationService", LOCATION_SERVICE_SCRIPT)
	var result := _run_smoke(root, time_service, run_state, event_log, location_service)
	print("SUMMARY|script=task9_location_smoke|failed=%s|message=%s" % [
		str(result.get("failed", true)),
		_sanitize(str(result.get("message", ""))),
	])
	event_log.free()
	run_state.free()
	time_service.free()
	location_service.free()
	quit(1 if bool(result.get("failed", true)) else 0)


func _run_smoke(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, location_service: Node) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")

	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state, location_service)
	runner.bootstrap(42)

	if location_service == null:
		runner.free()
		return {
			"failed": true,
			"message": "LocationService 不可用",
		}

	var moved_events: Array[Dictionary] = []
	location_service.moved.connect(func(character_id: StringName, from_region_id: StringName, to_region_id: StringName) -> void:
		moved_events.append({
			"character_id": str(character_id),
			"from_region_id": str(from_region_id),
			"to_region_id": str(to_region_id),
		})
	)

	var start_region := str(location_service.get_character_region(CHARACTER_ID))
	var valid_result: Dictionary = location_service.set_character_region(CHARACTER_ID, ADJACENT_TARGET)
	var after_valid_region := str(location_service.get_character_region(CHARACTER_ID))
	var invalid_result: Dictionary = location_service.set_character_region(CHARACTER_ID, NON_ADJACENT_TARGET)
	var final_region := str(location_service.get_character_region(CHARACTER_ID))

	print("CASE|scenario=task9_location|start_region=%s|valid_ok=%s|valid_error=%s|after_valid_region=%s|moved_count=%d" % [
		_sanitize(start_region),
		str(valid_result.get("ok", false)),
		_sanitize(str(valid_result.get("error", ""))),
		_sanitize(after_valid_region),
		moved_events.size(),
	])
	print("CASE|scenario=task9_location|invalid_ok=%s|invalid_error=%s|final_region=%s" % [
		str(invalid_result.get("ok", false)),
		_sanitize(str(invalid_result.get("error", ""))),
		_sanitize(final_region),
	])

	var valid_ok := bool(valid_result.get("ok", false)) and str(valid_result.get("error", "")) == "ok"
	var valid_changed := bool(valid_result.get("context", {}).get("changed", false))
	var invalid_rejected := not bool(invalid_result.get("ok", true)) and str(invalid_result.get("error", "")) == str(location_service.ERROR_NON_ADJACENT_MOVE)
	var signal_once := moved_events.size() == 1
	var region_kept := final_region == after_valid_region

	print("ASSERT|scenario=task9_location|valid_ok=%s|valid_changed=%s|invalid_rejected=%s|signal_once=%s|region_kept=%s" % [
		str(valid_ok),
		str(valid_changed),
		str(invalid_rejected),
		str(signal_once),
		str(region_kept),
	])

	runner.free()
	return {
		"failed": not (valid_ok and valid_changed and invalid_rejected and signal_once and region_kept),
		"message": "task9 位置服务烟测完成",
	}


func _ensure_service(node_name: String, script_resource: Script) -> Node:
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		return existing
	var service := Node.new()
	service.name = node_name
	service.set_script(script_resource)
	root.add_child(service)
	return service


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")
