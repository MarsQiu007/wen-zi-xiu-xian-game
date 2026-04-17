extends Control
class_name UIRoot

var _title_label: Label
var _status_label: Label


func _ready() -> void:
	_build_minimal_ui()
	_refresh_text()
	EventLog.entry_added.connect(_on_log_entry_added)
	TimeService.time_advanced.connect(_on_time_advanced)
	RunState.mode_changed.connect(_on_mode_changed)
	RunState.phase_changed.connect(_on_phase_changed)


func bind_runner(_runner: Node) -> void:
	_refresh_text()


func _build_minimal_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	_title_label = Label.new()
	_title_label.text = "文字修仙沙盒"
	box.add_child(_title_label)

	_status_label = Label.new()
	box.add_child(_status_label)


func _refresh_text() -> void:
	if _status_label == null:
		return

	_status_label.text = "模式：%s｜阶段：%s｜时间：%s｜日志：%d" % [
		str(RunState.mode),
		str(RunState.phase),
		TimeService.get_clock_text(),
		EventLog.entries.size()
	]


func _on_log_entry_added(_entry: Dictionary) -> void:
	_refresh_text()


func _on_time_advanced(_total_minutes: int) -> void:
	_refresh_text()


func _on_mode_changed(_mode: StringName) -> void:
	_refresh_text()


func _on_phase_changed(_phase: StringName) -> void:
	_refresh_text()
