extends Node

signal save_completed(path: String)
signal load_completed(path: String)

const SAVE_PATH := "user://savegame.json"


func save_game(data: Dictionary = {}) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit(SAVE_PATH)
	return true


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		load_completed.emit(SAVE_PATH)
		return parsed

	return {}
