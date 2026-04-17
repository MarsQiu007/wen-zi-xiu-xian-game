extends Node

signal mode_changed(mode: StringName)
signal phase_changed(phase: StringName)

var mode: StringName = &"human"
var phase: StringName = &"boot"


func set_mode(new_mode: StringName) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func set_phase(new_phase: StringName) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(phase)
