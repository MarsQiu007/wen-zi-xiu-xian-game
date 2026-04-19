extends RefCounted
class_name NpcDecisionEngine

const BehaviorAction = preload("res://scripts/data/behavior_action.gd")
const NpcBehaviorLibrary = preload("res://scripts/npc/npc_behavior_library.gd")
const RelationshipNetwork = preload("res://scripts/npc/relationship_network.gd")
const NpcMemorySystem = preload("res://scripts/npc/npc_memory_system.gd")

const NEEDS_WEIGHT := 0.4
const RELATIONSHIP_WEIGHT := 0.2
const MEMORY_WEIGHT := 0.2
const PERSONALITY_WEIGHT := 0.2
const PICK_RANDOM_JITTER := 0.05

const CONFLICT_KEYWORDS: PackedStringArray = [
	"conflict", "battle", "duel", "raid", "ambush", "assassinate", "fight", "war", "enemy", "rival",
]
const SOCIAL_KEYWORDS: PackedStringArray = [
	"social", "chat", "visit", "mentor", "alliance", "gathering", "gift", "friend", "neighbor", "family",
]

var _behavior_library: NpcBehaviorLibrary = NpcBehaviorLibrary.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func decide_action(npc_state: Dictionary, context: Dictionary) -> Dictionary:
	var current_hours := float(context.get("current_hours", 0.0))
	var available_behaviors := _behavior_library.get_available_behaviors(npc_state, current_hours)
	if available_behaviors.is_empty():
		return {
			"action": BehaviorAction.new(),
			"reason": "no_available_behavior",
			"scores": {},
		}

	var scored_behaviors := score_behaviors(npc_state, context, available_behaviors)
	if scored_behaviors.is_empty():
		return {
			"action": BehaviorAction.new(),
			"reason": "no_scored_behavior",
			"scores": {},
		}

	var selected: Dictionary = {}
	var best_pick_score := -INF
	for scored in scored_behaviors:
		var pick_score := float(scored.get("total_score", 0.0)) + _rng.randf_range(-PICK_RANDOM_JITTER, PICK_RANDOM_JITTER)
		if pick_score > best_pick_score:
			best_pick_score = pick_score
			selected = scored

	if selected.is_empty():
		return {
			"action": BehaviorAction.new(),
			"reason": "selection_failed",
			"scores": {},
		}

	var action: BehaviorAction = selected.get("behavior", BehaviorAction.new())
	var scores := {
		"total_score": float(selected.get("total_score", 0.0)),
		"needs_score": float(selected.get("needs_score", 0.0)),
		"relationship_score": float(selected.get("relationship_score", 0.0)),
		"memory_score": float(selected.get("memory_score", 0.0)),
		"personality_score": float(selected.get("personality_score", 0.0)),
	}
	var reason := "selected:%s total=%.3f" % [String(action.action_id), float(scores["total_score"])]
	return {
		"action": action,
		"reason": reason,
		"scores": scores,
	}


func score_behaviors(npc_state: Dictionary, context: Dictionary, available_behaviors: Array[BehaviorAction]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var relationships: RefCounted = context.get("relationships", null)
	var memories: RefCounted = context.get("memory_system", null)

	for behavior in available_behaviors:
		var needs_score := _score_by_needs(npc_state, behavior)
		var relationship_score := _score_by_relationships(npc_state, behavior, relationships)
		var memory_score := _score_by_memory(npc_state, behavior, memories)
		var personality_score := _score_by_personality(npc_state, behavior)
		var total_score := needs_score * NEEDS_WEIGHT
		total_score += relationship_score * RELATIONSHIP_WEIGHT
		total_score += memory_score * MEMORY_WEIGHT
		total_score += personality_score * PERSONALITY_WEIGHT

		result.append({
			"behavior": behavior,
			"total_score": total_score,
			"needs_score": needs_score,
			"relationship_score": relationship_score,
			"memory_score": memory_score,
			"personality_score": personality_score,
		})

	return result


func _score_by_needs(npc_state: Dictionary, behavior: BehaviorAction) -> float:
	var pressures: Dictionary = npc_state.get("pressures", {})
	if pressures.is_empty() or behavior.pressure_deltas.is_empty():
		return 0.0

	var score := 0.0
	for pressure_key_variant in behavior.pressure_deltas.keys():
		var pressure_key := str(pressure_key_variant)
		var delta := float(behavior.pressure_deltas[pressure_key_variant])
		if delta >= 0.0:
			continue
		var pressure_value := float(pressures.get(pressure_key, pressures.get(StringName(pressure_key), 0.0)))
		if pressure_value <= 0.0:
			continue
		score += pressure_value * absf(delta)

	return score


func _score_by_relationships(npc_state: Dictionary, behavior: BehaviorAction, relationships: RefCounted) -> float:
	if relationships == null or not relationships.has_method("get_edges_for"):
		return 0.0

	var npc_id := _resolve_npc_id(npc_state, {})
	if npc_id == &"":
		return 0.0

	var edges: Array = relationships.call("get_edges_for", npc_id)
	if edges.is_empty():
		return 0.0

	var positive_favor_sum := 0.0
	var positive_count := 0
	var negative_favor_sum := 0.0
	var negative_count := 0
	var enemy_count := 0

	for edge_variant in edges:
		if edge_variant == null:
			continue
		var favor := int(edge_variant.favor)
		var relation_type := StringName(str(edge_variant.relation_type))
		if favor > 0:
			positive_favor_sum += float(favor)
			positive_count += 1
		elif favor < 0:
			negative_favor_sum += float(absi(favor))
			negative_count += 1
		if relation_type == &"enemy" or favor <= -50:
			enemy_count += 1

	var score := 0.0
	if _is_social_behavior(behavior):
		var positive_avg := positive_favor_sum / maxf(1.0, float(positive_count))
		score += positive_avg / 100.0
		score += float(positive_count) * 0.05
	if _is_conflict_behavior(behavior):
		var negative_avg := negative_favor_sum / maxf(1.0, float(negative_count))
		score += negative_avg / 100.0
		score += float(enemy_count) * 0.15

	return score


func _score_by_memory(npc_state: Dictionary, behavior: BehaviorAction, memories: RefCounted) -> float:
	if memories == null or not memories.has_method("get_recent_memories"):
		return 0.0

	var npc_id := _resolve_npc_id(npc_state, {})
	if npc_id == &"":
		return 0.0

	var recent_memories: Array = memories.call("get_recent_memories", npc_id, 8)
	if recent_memories.is_empty():
		return 0.0

	var current_hours := float(npc_state.get("current_hours", 0.0))
	var conflict_signal := 0.0
	var social_signal := 0.0

	for memory_variant in recent_memories:
		if memory_variant == null:
			continue
		var event_type := str(memory_variant.event_type).to_lower()
		var importance := float(memory_variant.importance)
		var retention := 1.0
		if memory_variant.has_method("get_retention_score"):
			retention = float(memory_variant.call("get_retention_score", current_hours))
		if _matches_keywords(event_type, CONFLICT_KEYWORDS):
			conflict_signal += importance * retention
		elif _matches_keywords(event_type, SOCIAL_KEYWORDS):
			social_signal += importance * retention

	if _is_conflict_behavior(behavior):
		return conflict_signal
	if _is_social_behavior(behavior):
		return social_signal
	return 0.0


func _score_by_personality(npc_state: Dictionary, behavior: BehaviorAction) -> float:
	if not _is_conflict_behavior(behavior):
		return 0.0

	var morality := float(npc_state.get("morality", 0.0))
	var morality_norm := _normalize_morality(morality)
	return -morality_norm


func get_decision_interval(npc_state: Dictionary) -> float:
	var life_stage := StringName(str(npc_state.get("life_stage", "young_adult")))
	match life_stage:
		&"youth":
			return 12.0
		&"young_adult":
			return 8.0
		&"adult":
			return 6.0
		_:
			return 8.0


func _is_social_behavior(behavior: BehaviorAction) -> bool:
	return behavior.category == &"social"


func _is_conflict_behavior(behavior: BehaviorAction) -> bool:
	if behavior.category == &"conflict":
		return true
	var action_name := str(behavior.action_id).to_lower()
	return _matches_keywords(action_name, CONFLICT_KEYWORDS)


func _matches_keywords(source_text: String, keywords: PackedStringArray) -> bool:
	for keyword in keywords:
		if source_text.contains(keyword):
			return true
	return false


func _normalize_morality(morality: float) -> float:
	if absf(morality) <= 1.0:
		return clampf(morality, -1.0, 1.0)
	return clampf(morality / 100.0, -1.0, 1.0)


func _resolve_npc_id(npc_state: Dictionary, context: Dictionary) -> StringName:
	var id_value = npc_state.get("npc_id", npc_state.get("id", context.get("npc_id", context.get("id", ""))))
	return StringName(str(id_value))
