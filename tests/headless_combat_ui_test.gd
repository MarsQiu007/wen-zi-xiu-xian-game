extends SceneTree

func _init() -> void:
	var runner = load("res://scripts/sim/simulation_runner.gd").new()
	var ui = load("res://scripts/ui/ui_root.gd").new()
	
	# Just checking if they compile and instantiate fine without crashing
	print("SimulationRunner and UIRoot instantiated.")
	quit()
