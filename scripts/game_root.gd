extends Node

const AUTO_ADVANCE_INTERVAL_SECONDS := 2.0

@onready var simulation_runner: Node = $SimulationRunner
@onready var ui_root: Node = $UIRoot

var RunState: Node
var EventLog: Node
var TimeService: Node
var LocationService: Node
var SaveService: Node

var _auto_advance_timer: Timer


func _ready() -> void:
	_bind_singletons()
	RunState.set_phase(&"menu")
	EventLog.add_entry("GameRoot 已初始化，等待玩家选择...")
	
	if is_instance_valid(ui_root):
		if is_instance_valid(simulation_runner):
			ui_root.bind_runner(simulation_runner)
		ui_root.menu_new_game_requested.connect(_on_new_game_requested)
		ui_root.menu_continue_requested.connect(_on_continue_requested)
		ui_root.show_main_menu()


func _on_new_game_requested(mode: StringName) -> void:
	_bind_singletons()
	RunState.set_mode(mode)
	RunState.set_phase(&"mode_select")
	EventLog.add_entry("新游戏流程已启动，进入模式选择阶段：%s" % str(mode))
		
	if is_instance_valid(ui_root):
		ui_root.hide_main_menu()


func _on_mode_selected(mode: StringName) -> void:
	_bind_singletons()
	RunState.set_mode(mode)
	if mode == &"human":
		RunState.set_phase(&"char_creation")
		return
	# Deity mode: show placeholder
	var dialog := AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = "神明模式施工中，敬请期待"
	add_child(dialog)
	dialog.popup_centered()


func _on_character_created(params: Dictionary) -> void:
	RunState.creation_params = params.duplicate(true)
	RunState.set_phase(&"world_init")


func _on_world_initialized() -> void:
	RunState.set_phase(&"main_play")
	_setup_auto_advance_timer()


func _on_continue_requested() -> void:
	_bind_singletons()
	if not is_instance_valid(simulation_runner):
		EventLog.add_entry("继续游戏失败：SimulationRunner 不可用")
		return

	simulation_runner.setup_services(TimeService, EventLog, RunState, LocationService)
	var loaded_data: Dictionary = SaveService.load_game()
	if loaded_data.is_empty():
		EventLog.add_entry("继续游戏失败：未找到可用存档")
		return

	var snapshot: Dictionary = _extract_snapshot_from_save_payload(loaded_data)
	if snapshot.is_empty():
		EventLog.add_entry("继续游戏失败：存档中缺少 simulation_snapshot")
		return

	var mode_name := StringName(str(snapshot.get("mode", "human")))
	RunState.set_mode(mode_name)
	var restore_result: Dictionary = simulation_runner.load_snapshot(snapshot)
	if not bool(restore_result.get("ok", false)):
		EventLog.add_entry("继续游戏失败：快照恢复错误 %s" % str(restore_result.get("error", "unknown")))
		return

	RunState.set_phase(&"running")
	if is_instance_valid(ui_root):
		ui_root.hide_main_menu()
	_setup_auto_advance_timer()


func _bind_singletons() -> void:
	var root_node := get_tree().root if get_tree() != null else null
	if root_node == null:
		return
	if RunState == null:
		RunState = root_node.get_node_or_null("RunState")
	if EventLog == null:
		EventLog = root_node.get_node_or_null("EventLog")
	if TimeService == null:
		TimeService = root_node.get_node_or_null("TimeService")
	if LocationService == null:
		LocationService = root_node.get_node_or_null("LocationService")
	if SaveService == null:
		SaveService = root_node.get_node_or_null("SaveService")


func _extract_snapshot_from_save_payload(loaded_data: Dictionary) -> Dictionary:
	var wrapped_snapshot: Variant = loaded_data.get("simulation_snapshot", {})
	if wrapped_snapshot is Dictionary:
		var snapshot: Dictionary = wrapped_snapshot
		if not snapshot.is_empty():
			return snapshot

	if loaded_data.has("seed") and loaded_data.has("runtime_characters"):
		return loaded_data

	return {}



func _setup_auto_advance_timer() -> void:
	# TODO(T2): Change to hour-based advance in T11
	if is_instance_valid(_auto_advance_timer):
		_auto_advance_timer.stop()
		_auto_advance_timer.queue_free()
		_auto_advance_timer = null

	_auto_advance_timer = Timer.new()
	_auto_advance_timer.name = "AutoAdvanceTimer"
	_auto_advance_timer.wait_time = AUTO_ADVANCE_INTERVAL_SECONDS
	_auto_advance_timer.one_shot = false
	_auto_advance_timer.timeout.connect(_on_auto_advance_timeout)
	add_child(_auto_advance_timer)
	_auto_advance_timer.start()


func _on_auto_advance_timeout() -> void:
	if not is_instance_valid(simulation_runner):
		return
	if RunState.phase != &"running" and RunState.phase != &"ready" and RunState.phase != &"main_play":
		return
	simulation_runner.advance_one_day(false, true)
