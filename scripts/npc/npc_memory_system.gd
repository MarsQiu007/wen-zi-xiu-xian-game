extends RefCounted
class_name NpcMemorySystem

const NpcMemoryEntry = preload("res://scripts/data/npc_memory_entry.gd")

const SNAPSHOT_VERSION := 1

var _memories: Dictionary = {}
var _max_memories_per_npc: int = 50
var _retention_threshold: float = 0.5


func add_memory(character_id: StringName, entry: NpcMemoryEntry) -> void:
	if entry == null:
		return
	if not _memories.has(character_id):
		var initial_memories: Array[NpcMemoryEntry] = []
		_memories[character_id] = initial_memories
	var memories: Array[NpcMemoryEntry] = _get_memories_typed(character_id)
	memories.append(entry)
	if memories.size() <= _max_memories_per_npc:
		return
	var latest_hours := entry.timestamp_hours
	memories.sort_custom(func(a: NpcMemoryEntry, b: NpcMemoryEntry) -> bool:
		return get_retention_score(character_id, a, latest_hours) < get_retention_score(character_id, b, latest_hours)
	)
	while memories.size() > _max_memories_per_npc:
		memories.remove_at(0)


func get_memories(character_id: StringName) -> Array[NpcMemoryEntry]:
	var source: Array[NpcMemoryEntry] = _get_memories_typed(character_id)
	if source.is_empty():
		return []
	var result: Array[NpcMemoryEntry] = source.duplicate()
	result.sort_custom(func(a: NpcMemoryEntry, b: NpcMemoryEntry) -> bool:
		if a.importance == b.importance:
			return a.timestamp_hours > b.timestamp_hours
		return a.importance > b.importance
	)
	return result


func get_recent_memories(character_id: StringName, count: int = 5) -> Array[NpcMemoryEntry]:
	if count <= 0:
		return []
	var source: Array[NpcMemoryEntry] = _get_memories_typed(character_id)
	if source.is_empty():
		return []
	var result: Array[NpcMemoryEntry] = source.duplicate()
	result.sort_custom(func(a: NpcMemoryEntry, b: NpcMemoryEntry) -> bool:
		if is_equal_approx(a.timestamp_hours, b.timestamp_hours):
			return a.importance > b.importance
		return a.timestamp_hours > b.timestamp_hours
	)
	if result.size() > count:
		result.resize(count)
	return result


func get_memories_about(character_id: StringName, about_id: StringName) -> Array[NpcMemoryEntry]:
	var result: Array[NpcMemoryEntry] = []
	var source: Array[NpcMemoryEntry] = _get_memories_typed(character_id)
	for memory in source:
		if memory.related_ids.has(String(about_id)):
			result.append(memory)
	result.sort_custom(func(a: NpcMemoryEntry, b: NpcMemoryEntry) -> bool:
		return a.timestamp_hours > b.timestamp_hours
	)
	return result


func decay_memories(character_id: StringName, current_hours: float) -> void:
	if not _memories.has(character_id):
		return
	var source: Array[NpcMemoryEntry] = _get_memories_typed(character_id)
	if source.is_empty():
		_memories.erase(character_id)
		return
	var kept: Array[NpcMemoryEntry] = []
	for memory in source:
		if get_retention_score(character_id, memory, current_hours) >= _retention_threshold:
			kept.append(memory)
	if kept.is_empty():
		_memories.erase(character_id)
		return
	_memories[character_id] = kept


func _get_memories_typed(character_id: StringName) -> Array[NpcMemoryEntry]:
	if not _memories.has(character_id):
		return []
	var raw: Variant = _memories[character_id]
	if not (raw is Array):
		var empty_entries: Array[NpcMemoryEntry] = []
		_memories[character_id] = empty_entries
		return empty_entries
	var typed_entries: Array[NpcMemoryEntry] = []
	for item in raw:
		if item is NpcMemoryEntry:
			typed_entries.append(item)
	_memories[character_id] = typed_entries
	return typed_entries


func get_retention_score(character_id: StringName, entry: NpcMemoryEntry, current_hours: float) -> float:
	if entry == null:
		return 0.0
	return entry.get_retention_score(current_hours)


func to_dict() -> Dictionary:
	var data: Dictionary = {
		"snapshot_version": SNAPSHOT_VERSION,
		"max_memories_per_npc": _max_memories_per_npc,
		"retention_threshold": _retention_threshold,
		"memories": {},
	}
	var memories_data: Dictionary = data["memories"]
	for character_id_variant in _memories.keys():
		var character_id := StringName(character_id_variant)
		var source: Array[NpcMemoryEntry] = _memories[character_id]
		if source.is_empty():
			continue
		var entries_data: Array[Dictionary] = []
		for entry in source:
			entries_data.append(entry.to_dict())
		if not entries_data.is_empty():
			memories_data[String(character_id)] = entries_data
	return data


static func from_dict(data: Dictionary) -> NpcMemorySystem:
	var result: NpcMemorySystem = load("res://scripts/npc/npc_memory_system.gd").new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result._max_memories_per_npc = max(1, int(data.get("max_memories_per_npc", 50)))
	result._retention_threshold = float(data.get("retention_threshold", 0.5))
	var memories_raw = data.get("memories", {})
	if memories_raw is Dictionary:
		for character_key in memories_raw.keys():
			var entries_raw = memories_raw[character_key]
			if not (entries_raw is Array):
				continue
			var entries: Array[NpcMemoryEntry] = []
			for entry_raw in entries_raw:
				if entry_raw is Dictionary:
					entries.append(NpcMemoryEntry.from_dict(entry_raw))
			if not entries.is_empty():
				result._memories[StringName(str(character_key))] = entries
	return result
