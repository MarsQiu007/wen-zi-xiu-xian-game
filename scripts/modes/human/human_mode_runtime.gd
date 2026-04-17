extends RefCounted
class_name HumanModeRuntime

const HumanOpeningBuilderScript = preload("res://scripts/modes/human/human_opening_builder.gd")
const HumanEarlyLoopScript = preload("res://scripts/modes/human/human_early_loop.gd")


func build_initial_state(catalog: Resource, options: Dictionary = {}) -> Dictionary:
	var opening_type := str(options.get("opening_type", "youth"))
	return HumanOpeningBuilderScript.build_opening(catalog, opening_type, options)


func advance_day(runtime: Dictionary, simulated_day: int) -> Dictionary:
	return HumanEarlyLoopScript.advance_day(runtime, simulated_day)
