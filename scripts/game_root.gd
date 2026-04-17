extends Node

@onready var simulation_runner: Node = $SimulationRunner
@onready var ui_root: Node = $UIRoot


func _ready() -> void:
	RunState.set_phase(&"running")
	EventLog.add_entry("GameRoot 已初始化")
	if is_instance_valid(simulation_runner):
		simulation_runner.bootstrap()
	if is_instance_valid(ui_root):
		ui_root.bind_runner(simulation_runner)
