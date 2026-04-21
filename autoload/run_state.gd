extends Node

const PHASE_MODE_SELECT: StringName = &"mode_select"
const PHASE_CHAR_CREATION: StringName = &"char_creation"
const PHASE_WORLD_INIT: StringName = &"world_init"
const PHASE_MAIN_PLAY: StringName = &"main_play"
const SUB_PHASE_COMBAT: StringName = &"combat"

signal mode_changed(mode: StringName)
signal phase_changed(phase: StringName)
signal sub_phase_changed(sub_phase: StringName)
signal player_combat_action_submitted(action: Dictionary)
signal combat_context_changed(context: Dictionary)
signal combat_result_changed(result: Dictionary)

var mode: StringName = &"human"
var phase: StringName = &"boot"
var sub_phase: StringName = &""
var creation_params: Dictionary = {}
var world_seed: int = -1
var combat_context: Dictionary = {}
var combat_result: Dictionary = {}


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


func submit_player_combat_action(action: Dictionary) -> void:
	player_combat_action_submitted.emit(action.duplicate(true))


func set_combat_context(context: Dictionary) -> void:
	combat_context = context.duplicate(true)
	combat_context_changed.emit(combat_context.duplicate(true))


func clear_combat_context() -> void:
	if combat_context.is_empty():
		return
	combat_context.clear()
	combat_context_changed.emit({})


func set_combat_result(result: Dictionary) -> void:
	combat_result = result.duplicate(true)
	combat_result_changed.emit(combat_result.duplicate(true))


func clear_combat_result() -> void:
	if combat_result.is_empty():
		return
	combat_result.clear()
	combat_result_changed.emit({})
