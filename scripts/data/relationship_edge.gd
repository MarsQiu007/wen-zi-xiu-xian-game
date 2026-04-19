extends RefCounted
class_name RelationshipEdge

const SNAPSHOT_VERSION := 1

var source_id: StringName = &""
var target_id: StringName = &""
var relation_type: StringName = &""
var favor: int = 0
var trust: int = 0
var interaction_count: int = 0


func modify_favor(delta: int) -> void:
	favor = clampi(favor + delta, -300, 300)


func modify_trust(delta: int) -> void:
	trust = clampi(trust + delta, -100, 100)


func to_dict() -> Dictionary:
	return {
		"snapshot_version": SNAPSHOT_VERSION,
		"source_id": String(source_id),
		"target_id": String(target_id),
		"relation_type": String(relation_type),
		"favor": favor,
		"trust": trust,
		"interaction_count": interaction_count,
	}


static func from_dict(data: Dictionary) -> RelationshipEdge:
	var result := RelationshipEdge.new()
	var version := int(data.get("snapshot_version", SNAPSHOT_VERSION))
	if version != SNAPSHOT_VERSION:
		return result
	result.source_id = StringName(str(data.get("source_id", "")))
	result.target_id = StringName(str(data.get("target_id", "")))
	result.relation_type = StringName(str(data.get("relation_type", "")))
	result.favor = clampi(int(data.get("favor", 0)), -300, 300)
	result.trust = clampi(int(data.get("trust", 0)), -100, 100)
	result.interaction_count = int(data.get("interaction_count", 0))
	return result
