extends RefCounted
class_name NpcMemoryEntry

const SNAPSHOT_VERSION := 1

var event_id: StringName = &""
var event_type: StringName = &""
var timestamp_hours: float = 0.0
var importance: int = 1
var summary: String = ""
var related_ids: PackedStringArray = PackedStringArray()


func get_age_hours(current_hours: float) -> float:
	return maxf(0.0, current_hours - timestamp_hours)


func get_retention_score(current_hours: float) -> float:
	var age_hours := get_age_hours(current_hours)
	return float(importance) / (1.0 + age_hours / 24.0)


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"event_id": String(event_id),
		"event_type": String(event_type),
		"timestamp_hours": timestamp_hours,
		"importance": importance,
		"summary": summary,
		"related_ids": Array(related_ids),
	}


static func from_dict(data: Dictionary) -> NpcMemoryEntry:
	var result := NpcMemoryEntry.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.event_id = StringName(str(data.get("event_id", "")))
	result.event_type = StringName(str(data.get("event_type", "")))
	result.timestamp_hours = float(data.get("timestamp_hours", 0.0))
	result.importance = clampi(int(data.get("importance", 1)), 1, 10)
	result.summary = str(data.get("summary", ""))
	var ids_raw = data.get("related_ids", [])
	if ids_raw is PackedStringArray:
		result.related_ids = ids_raw
	elif ids_raw is Array:
		result.related_ids = PackedStringArray(ids_raw)
	return result
