extends Node

signal save_completed(path: String)
signal load_completed(path: String)

const SAVE_PROTOCOL_VERSION := 2
const DEFAULT_SLOT_ID := "default"
const SAVE_ROOT_DIR := "user://saves"
const SaveMigration = preload("res://scripts/data/save_migration.gd")

const ERROR_OK := "ok"
const ERROR_INVALID_SLOT_ID := "invalid_slot_id"
const ERROR_CREATE_DIR_FAILED := "create_dir_failed"
const ERROR_OPEN_TEMP_WRITE_FAILED := "open_temp_write_failed"
const ERROR_RENAME_FAILED := "rename_failed"
const ERROR_OPEN_READ_FAILED := "open_read_failed"
const ERROR_MISSING_FILE := "missing_file"
const ERROR_JSON_PARSE_FAILED := "json_parse_failed"
const ERROR_INVALID_ROOT_TYPE := "invalid_root_type"
const ERROR_MISSING_FIELD := "missing_field"
const ERROR_INVALID_FIELD_TYPE := "invalid_field_type"
const ERROR_UNSUPPORTED_VERSION := "unsupported_version"
const ERROR_SLOT_MISMATCH := "slot_mismatch"

var _last_error: String = ERROR_OK
var _last_error_context: Dictionary = {}


func save_game(data: Dictionary = {}) -> bool:
	var payload: Dictionary = data
	if not payload.has("simulation_snapshot") and payload.has("snapshot_version"):
		payload = {"simulation_snapshot": payload}
	var result := save_slot(payload, DEFAULT_SLOT_ID)
	return result.get("ok", false)


func load_game() -> Dictionary:
	var result := load_slot(DEFAULT_SLOT_ID)
	if result.get("ok", false):
		return result.get("data", {})
	return {}


func save_slot(data: Dictionary = {}, slot_id: String = DEFAULT_SLOT_ID) -> Dictionary:
	_reset_error()
	if not _is_valid_slot_id(slot_id):
		return _result(false, ERROR_INVALID_SLOT_ID, {"slot_id": slot_id})

	var dir_error := _ensure_save_dir_exists()
	if dir_error != OK:
		return _result(false, ERROR_CREATE_DIR_FAILED, {"godot_error": dir_error, "slot_id": slot_id})

	var final_path := _get_slot_path(slot_id)
	var temp_path := _get_slot_temp_path(slot_id)
	var payload := {
		"save_version": SAVE_PROTOCOL_VERSION,
		"slot_id": slot_id,
		"timestamp": int(Time.get_unix_time_from_system()),
		"data": data
	}

	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return _result(false, ERROR_OPEN_TEMP_WRITE_FAILED, {"path": temp_path, "slot_id": slot_id})

	temp_file.store_string(JSON.stringify(payload, "\t"))
	temp_file.close()

	if FileAccess.file_exists(final_path):
		var remove_error := DirAccess.remove_absolute(final_path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _result(false, ERROR_RENAME_FAILED, {
				"from": temp_path,
				"to": final_path,
				"reason": "remove_old_failed",
				"godot_error": remove_error,
				"slot_id": slot_id
			})

	var rename_error := DirAccess.rename_absolute(temp_path, final_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _result(false, ERROR_RENAME_FAILED, {
			"from": temp_path,
			"to": final_path,
			"godot_error": rename_error,
			"slot_id": slot_id
		})

	save_completed.emit(final_path)
	return _result(true, ERROR_OK, {
		"slot_id": slot_id,
		"path": final_path,
		"save_version": SAVE_PROTOCOL_VERSION,
		"timestamp": payload["timestamp"]
	}, {"data": data})


func load_slot(slot_id: String = DEFAULT_SLOT_ID) -> Dictionary:
	_reset_error()
	if not _is_valid_slot_id(slot_id):
		return _result(false, ERROR_INVALID_SLOT_ID, {"slot_id": slot_id})

	var path := _get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return _result(false, ERROR_MISSING_FILE, {"slot_id": slot_id, "path": path})

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(false, ERROR_OPEN_READ_FAILED, {"slot_id": slot_id, "path": path})

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return _result(false, ERROR_JSON_PARSE_FAILED, {
			"slot_id": slot_id,
			"path": path,
			"godot_error": parse_error,
			"message": json.get_error_message(),
			"line": json.get_error_line()
		})

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return _result(false, ERROR_INVALID_ROOT_TYPE, {
			"slot_id": slot_id,
			"path": path,
			"actual_type": typeof(parsed)
		})

	var payload: Dictionary = parsed
	var validation := _validate_payload(payload, slot_id)
	if not validation.get("ok", false):
		return validation

	load_completed.emit(path)
	return _result(true, ERROR_OK, {
		"slot_id": payload["slot_id"],
		"path": path,
		"save_version": payload["save_version"],
		"timestamp": payload["timestamp"]
	}, {"data": payload["data"], "payload": payload})


func get_last_error() -> String:
	return _last_error


func get_last_error_context() -> Dictionary:
	return _last_error_context.duplicate(true)


func migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	if from_version < SAVE_PROTOCOL_VERSION:
		for version in range(from_version, SAVE_PROTOCOL_VERSION):
			match version:
				1:
					data = SaveMigration.v1_to_v2(data)
	return data


func has_save_slot(slot_id: String = DEFAULT_SLOT_ID) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false
	return FileAccess.file_exists(_get_slot_path(slot_id))


func get_save_info(slot_id: String = DEFAULT_SLOT_ID) -> Dictionary:
	_reset_error()
	if not _is_valid_slot_id(slot_id):
		return _result(false, ERROR_INVALID_SLOT_ID, {"slot_id": slot_id})

	var path := _get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return _result(false, ERROR_MISSING_FILE, {"slot_id": slot_id, "path": path})

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(false, ERROR_OPEN_READ_FAILED, {"slot_id": slot_id, "path": path})

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return _result(false, ERROR_JSON_PARSE_FAILED, {
			"slot_id": slot_id,
			"path": path,
			"godot_error": parse_error,
			"message": json.get_error_message(),
			"line": json.get_error_line()
		})

	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return _result(false, ERROR_INVALID_ROOT_TYPE, {
			"slot_id": slot_id,
			"path": path,
			"actual_type": typeof(parsed)
		})

	var payload: Dictionary = parsed
	return {
		"ok": true,
		"error": ERROR_OK,
		"save_version": int(payload.get("save_version", 0)),
		"timestamp": int(payload.get("timestamp", 0)),
		"slot_id": str(payload.get("slot_id", "")),
	}


func _validate_payload(payload: Dictionary, expected_slot_id: String) -> Dictionary:
	if not payload.has("save_version"):
		return _result(false, ERROR_MISSING_FIELD, {"field": "save_version", "slot_id": expected_slot_id})
	if not _is_integer_number(payload["save_version"]):
		return _result(false, ERROR_INVALID_FIELD_TYPE, {
			"field": "save_version",
			"expected": "integer number",
			"actual_type": typeof(payload["save_version"]),
			"slot_id": expected_slot_id
		})
	var save_version := int(payload["save_version"])
	if save_version > SAVE_PROTOCOL_VERSION:
		return _result(false, ERROR_UNSUPPORTED_VERSION, {
			"slot_id": expected_slot_id,
			"save_version": save_version,
			"expected": SAVE_PROTOCOL_VERSION
		})
	if save_version < SAVE_PROTOCOL_VERSION:
		var payload_data: Dictionary = payload.get("data", {})
		var migrated_data: Dictionary = payload_data
		if payload_data.has("simulation_snapshot") and payload_data["simulation_snapshot"] is Dictionary:
			migrated_data = payload_data.duplicate(true)
			var wrapped_snapshot: Dictionary = (payload_data["simulation_snapshot"] as Dictionary).duplicate(true)
			migrated_data["simulation_snapshot"] = migrate_save(wrapped_snapshot, save_version)
		else:
			migrated_data = migrate_save(payload_data, save_version)
		payload["data"] = migrated_data
		payload["save_version"] = SAVE_PROTOCOL_VERSION
		save_version = SAVE_PROTOCOL_VERSION

	if not payload.has("slot_id"):
		return _result(false, ERROR_MISSING_FIELD, {"field": "slot_id", "slot_id": expected_slot_id})
	if not payload["slot_id"] is String:
		return _result(false, ERROR_INVALID_FIELD_TYPE, {
			"field": "slot_id",
			"expected": "String",
			"actual_type": typeof(payload["slot_id"]),
			"slot_id": expected_slot_id
		})
	if payload["slot_id"] != expected_slot_id:
		return _result(false, ERROR_SLOT_MISMATCH, {
			"slot_id": expected_slot_id,
			"payload_slot_id": payload["slot_id"]
		})

	if not payload.has("timestamp"):
		return _result(false, ERROR_MISSING_FIELD, {"field": "timestamp", "slot_id": expected_slot_id})
	if not _is_integer_number(payload["timestamp"]):
		return _result(false, ERROR_INVALID_FIELD_TYPE, {
			"field": "timestamp",
			"expected": "integer number",
			"actual_type": typeof(payload["timestamp"]),
			"slot_id": expected_slot_id
		})
	var timestamp := int(payload["timestamp"])

	if not payload.has("data"):
		return _result(false, ERROR_MISSING_FIELD, {"field": "data", "slot_id": expected_slot_id})
	if not payload["data"] is Dictionary:
		return _result(false, ERROR_INVALID_FIELD_TYPE, {
			"field": "data",
			"expected": "Dictionary",
			"actual_type": typeof(payload["data"]),
			"slot_id": expected_slot_id
		})

	return _result(true, ERROR_OK, {
		"slot_id": expected_slot_id,
		"save_version": save_version,
		"timestamp": timestamp
	}, {"data": payload["data"]})


func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_equal_approx(value, floor(value))
	return false


func _ensure_save_dir_exists() -> int:
	if DirAccess.dir_exists_absolute(SAVE_ROOT_DIR):
		return OK
	return DirAccess.make_dir_recursive_absolute(SAVE_ROOT_DIR)


func _get_slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_ROOT_DIR, slot_id]


func _get_slot_temp_path(slot_id: String) -> String:
	return "%s/%s.tmp" % [SAVE_ROOT_DIR, slot_id]


func _is_valid_slot_id(slot_id: String) -> bool:
	if slot_id.is_empty():
		return false
	if slot_id.find("/") != -1:
		return false
	if slot_id.find("\\") != -1:
		return false
	if slot_id.find("..") != -1:
		return false
	return true


func _reset_error() -> void:
	_last_error = ERROR_OK
	_last_error_context = {}


func _result(ok: bool, error_code: String, context: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	_last_error = error_code
	_last_error_context = context.duplicate(true)
	var result := {
		"ok": ok,
		"error": error_code,
		"context": _last_error_context.duplicate(true)
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result
