extends Node

const PHASE_MODE_SELECT: StringName = &"mode_select"
const PHASE_CHAR_CREATION: StringName = &"char_creation"
const PHASE_WORLD_INIT: StringName = &"world_init"
const PHASE_MAIN_PLAY: StringName = &"main_play"

signal mode_changed(mode: StringName)
signal phase_changed(phase: StringName)
signal sub_phase_changed(sub_phase: StringName)

var mode: StringName = &"human"
var phase: StringName = &"boot"
var sub_phase: StringName = &""
var creation_params: Dictionary = {}
var world_seed: int = -1


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


func set_sub_phase(new_sub_phase: StringName) -> void:
	if sub_phase == new_sub_phase:
		return
	sub_phase = new_sub_phase
	sub_phase_changed.emit(sub_phase)
