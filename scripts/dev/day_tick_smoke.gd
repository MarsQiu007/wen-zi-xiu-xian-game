extends SceneTree

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")
const TIME_SERVICE_SCRIPT := preload("res://autoload/time_service.gd")
const RUN_STATE_SCRIPT := preload("res://autoload/run_state.gd")
const EVENT_LOG_SCRIPT := preload("res://autoload/event_log.gd")


func _initialize() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var seed := int(args.get("seed", 42))
	var days := int(args.get("days", 10))
	var stop_on_pause := bool(args.get("stop-on-pause", false))
	var auto_resolve_pause := bool(args.get("auto-resolve-pause", true))

	print("SMOKE_START|seed=%d|days=%d|stop_on_pause=%s|auto_resolve_pause=%s" % [seed, days, str(stop_on_pause), str(auto_resolve_pause)])
	_ensure_service("TimeService", TIME_SERVICE_SCRIPT)
	var time_service: Node = _ensure_service("TimeService", TIME_SERVICE_SCRIPT)
	var run_state: Node = _ensure_service("RunState", RUN_STATE_SCRIPT)
	var event_log: Node = _ensure_service("EventLog", EVENT_LOG_SCRIPT)

	var runner: Node = RUNNER_SCENE.instantiate()
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

	print("SUMMARY|seed=%s|requested_days=%s|advanced_days=%s|resolved_days=%s|total_minutes=%s|entries=%s|paused=%s|pause_title=%s|pause_count=%s" % [
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
	event_log.free()
	run_state.free()
	time_service.free()
	quit(0)


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {
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
			"seed", "days":
				parsed[key] = int(value)
			"stop-on-pause", "auto-resolve-pause":
				parsed[key] = value.to_lower() != "false"
	return parsed


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")


func _ensure_service(node_name: String, script_resource: Script) -> Node:
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		return existing
	var service := Node.new()
	service.name = node_name
	service.set_script(script_resource)
	root.add_child(service)
	return service
