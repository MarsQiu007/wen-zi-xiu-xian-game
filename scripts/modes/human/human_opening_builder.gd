extends RefCounted
class_name HumanOpeningBuilder

const DEFAULT_CHARACTER_ID := &"mvp_village_heir"
const DEFAULT_REGION_ID := &"mvp_village_region"
const DEFAULT_FAMILY_ID := &"mvp_lin_family"
const DEFAULT_FACTION_ID := &"mvp_village_settlement"
const DEFAULT_SECT_ID := &"mvp_small_sect"

const OPENING_PRESETS := {
	"youth": {
		"label": "少年",
		"age_years": 14,
		"life_stage": "youth",
		"strategy": "learning",
		"default_action_plan": [
			"study_classics",
			"support_family",
			"study_classics",
			"seek_master",
			"visit_sect",
			"ask_for_guidance",
			"study_classics",
			"support_family",
		],
		"branch_weights": {
			"survival": 0,
			"family": 1,
			"learning": 6,
			"cultivation": 2,
		},
		"pressures": {
			"survival": 3,
			"family": 4,
			"learning": 8,
			"cultivation": 5,
		},
	},
	"young_adult": {
		"label": "青年",
		"age_years": 18,
		"life_stage": "young_adult",
		"strategy": "family",
		"branch_weights": {
			"survival": 1,
			"family": 6,
			"learning": 0,
			"cultivation": 1,
		},
		"pressures": {
			"survival": 5,
			"family": 8,
			"learning": 3,
			"cultivation": 4,
		},
	},
	"adult": {
		"label": "成年",
		"age_years": 26,
		"life_stage": "adult",
		"strategy": "survival",
		"branch_weights": {
			"survival": 5,
			"family": 1,
			"learning": 0,
			"cultivation": 0,
		},
		"pressures": {
			"survival": 8,
			"family": 6,
			"learning": 1,
			"cultivation": 2,
		},
	},
}


static func normalize_opening_type(opening_type: String) -> String:
	var lowered := opening_type.to_lower()
	match lowered:
		"少年", "shaonian", "youth":
			return "youth"
		"青年", "qingnian", "young", "young_adult":
			return "young_adult"
		"成年", "chengnian", "adult":
			return "adult"
		_:
			return "youth"


static func build_opening(catalog: Resource, opening_type: String, options: Dictionary = {}) -> Dictionary:
	var normalized := normalize_opening_type(opening_type)
	var preset: Dictionary = OPENING_PRESETS.get(normalized, OPENING_PRESETS["youth"])
	var base_character := _pick_base_character(catalog)
	var base_character_id := str(_resource_get(base_character, "id", ""))
	var strategy := str(options.get("strategy", ""))
	if strategy.is_empty():
		strategy = str(preset.get("strategy", "learning"))
	var branch_weights: Dictionary = (preset.get("branch_weights", {}) as Dictionary).duplicate(true)
	if strategy == "active_cultivation":
		branch_weights["cultivation"] = int(branch_weights.get("cultivation", 0)) + 8
		branch_weights["learning"] = maxi(0, int(branch_weights.get("learning", 0)) - 2)
	var action_plan := _normalize_action_plan(options.get("action_plan", []))
	if action_plan.is_empty() and not options.has("strategy") and not options.has("action_plan"):
		action_plan = _normalize_action_plan(preset.get("default_action_plan", []))
	var base_player := {
		"id": str(options.get("player_id", str(_resource_get(base_character, "id", "human_player")))),
		"display_name": str(options.get("player_name", str(_resource_get(base_character, "display_name", "凡俗主角")))),
		"base_character_id": base_character_id,
		"age_years": int(options.get("age_years", int(preset.get("age_years", 14)))),
		"life_stage": str(preset.get("life_stage", normalized)),
		"region_id": str(options.get("region_id", str(_resource_get(base_character, "region_id", str(DEFAULT_REGION_ID))))),
		"family_id": str(options.get("family_id", str(_resource_get(base_character, "family_id", str(DEFAULT_FAMILY_ID))))),
		"faction_id": str(options.get("faction_id", str(_resource_get(base_character, "faction_id", str(DEFAULT_FACTION_ID))))),
		"sect_id": str(options.get("sect_id", str(DEFAULT_SECT_ID))),
		"spouse_character_id": str(options.get("spouse_character_id", str(_resource_get(base_character, "spouse_character_id", "")))),
		"dao_companion_character_id": str(options.get("dao_companion_character_id", str(_resource_get(base_character, "dao_companion_character_id", "")))),
		"direct_line_child_ids": _coerce_string_array(options.get("direct_line_child_ids", _resource_get(base_character, "direct_line_child_ids", PackedStringArray()))),
		"legal_heir_character_id": str(options.get("legal_heir_character_id", str(_resource_get(base_character, "legal_heir_character_id", "")))),
		"inheritance_priority": int(options.get("inheritance_priority", int(_resource_get(base_character, "inheritance_priority", 0)))),
		"is_alive": true,
	}
	base_player = _normalize_runtime_character(base_player, options)
	var registry := _build_character_registry(catalog, options, base_player)
	var current_player_id := str(options.get("current_player_id", str(base_player.get("id", "human_player"))))
	var player: Dictionary = base_player.duplicate(true)
	if registry.has(current_player_id):
		player = (registry[current_player_id] as Dictionary).duplicate(true)
	var player_gate: Dictionary = (player.get("cultivation_gate", {}) as Dictionary).duplicate(true)
	var player_state: Dictionary = (player.get("cultivation_state", {}) as Dictionary).duplicate(true)
	return {
		"opening_type": normalized,
		"opening_label": str(preset.get("label", "少年")),
		"player": player,
		"current_player_id": str(player.get("id", current_player_id)),
		"character_registry": registry,
		"lineage": {
			"active_character_id": str(player.get("id", current_player_id)),
			"founding_character_id": str(base_player.get("id", "human_player")),
			"inheritance_rule": str(options.get("inheritance_rule", _resolve_inheritance_rule(catalog, str(player.get("family_id", ""))))),
			"last_death": {},
			"terminated": false,
			"termination_reason": "",
			"perspective_history": [str(player.get("id", current_player_id))],
		},
		"pressures": (preset.get("pressures", {}) as Dictionary).duplicate(true),
		"branch_weights": branch_weights,
		"dominant_branch": strategy,
		"cultivation_gate": player_gate,
		"cultivation_state": player_state,
		"recent_actions": [],
		"strategy": strategy,
		"action_plan": action_plan,
		"forced_death_day": int(options.get("forced_death_day", 0)),
		"day_count": 0,
	}


static func _pick_base_character(catalog: Resource) -> Resource:
	if catalog != null and catalog.has_method("find_character"):
		var by_id: Resource = catalog.find_character(DEFAULT_CHARACTER_ID)
		if by_id != null:
			return by_id
	if catalog == null:
		return null
	var characters: Array = catalog.get("characters") if catalog.has_method("get") else []
	for character in characters:
		if character != null:
			return character
	return null


static func _normalize_action_plan(raw_plan: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_plan is Array:
		for action_id in raw_plan:
			result.append(str(action_id))
	return result


static func _build_character_registry(catalog: Resource, options: Dictionary, base_player: Dictionary) -> Dictionary:
	var registry: Dictionary = {}
	if catalog != null:
		var characters: Array = catalog.get("characters") if catalog.has_method("get") else []
		for character in characters:
			if character == null:
				continue
			var character_id := str(_resource_get(character, "id", ""))
			if character_id.is_empty():
				continue
			registry[character_id] = {
				"id": character_id,
				"display_name": str(_resource_get(character, "display_name", "无名氏")),
				"base_character_id": character_id,
				"age_years": int(_resource_get(character, "age_years", 0)),
				"life_stage": str(_resource_get(character, "life_stage", "ordinary")),
				"region_id": str(_resource_get(character, "region_id", "")),
				"family_id": str(_resource_get(character, "family_id", "")),
				"faction_id": str(_resource_get(character, "faction_id", "")),
				"sect_id": str(options.get("sect_id", str(DEFAULT_SECT_ID))),
				"spouse_character_id": str(_resource_get(character, "spouse_character_id", "")),
				"dao_companion_character_id": str(_resource_get(character, "dao_companion_character_id", "")),
				"direct_line_child_ids": _coerce_string_array(_resource_get(character, "direct_line_child_ids", PackedStringArray())),
				"legal_heir_character_id": str(_resource_get(character, "legal_heir_character_id", "")),
				"inheritance_priority": int(_resource_get(character, "inheritance_priority", 0)),
				"is_alive": true,
			}
			registry[character_id] = _normalize_runtime_character(registry[character_id], options)
	registry[str(base_player.get("id", "human_player"))] = base_player.duplicate(true)
	var runtime_characters: Variant = options.get("runtime_characters", [])
	if runtime_characters is Array:
		for raw_character in runtime_characters:
			if not (raw_character is Dictionary):
				continue
			var character_id := str(raw_character.get("id", ""))
			if character_id.is_empty():
				continue
			var existing: Dictionary = (registry.get(character_id, {}) as Dictionary).duplicate(true)
			for key in raw_character.keys():
				existing[key] = raw_character[key]
			existing["id"] = character_id
			existing["display_name"] = str(existing.get("display_name", character_id))
			existing["base_character_id"] = str(existing.get("base_character_id", character_id))
			existing["sect_id"] = str(existing.get("sect_id", str(options.get("sect_id", str(DEFAULT_SECT_ID)))))
			existing["spouse_character_id"] = str(existing.get("spouse_character_id", ""))
			existing["dao_companion_character_id"] = str(existing.get("dao_companion_character_id", ""))
			existing["direct_line_child_ids"] = _coerce_string_array(existing.get("direct_line_child_ids", []))
			existing["legal_heir_character_id"] = str(existing.get("legal_heir_character_id", ""))
			existing["inheritance_priority"] = int(existing.get("inheritance_priority", 0))
			existing["is_alive"] = bool(existing.get("is_alive", true))
			registry[character_id] = _normalize_runtime_character(existing, options)
	return registry


static func _normalize_runtime_character(character: Dictionary, options: Dictionary) -> Dictionary:
	var normalized: Dictionary = character.duplicate(true)
	normalized["cultivation_gate"] = _normalize_cultivation_gate(normalized.get("cultivation_gate", options.get("cultivation_gate", {})))
	normalized["cultivation_state"] = _normalize_cultivation_state(normalized, normalized.get("cultivation_state", options.get("cultivation_state", {})))
	return normalized


static func _normalize_cultivation_gate(raw_gate: Variant) -> Dictionary:
	var source: Dictionary = raw_gate.duplicate(true) if raw_gate is Dictionary else {}
	return {
		"contact_score": int(source.get("contact_score", 0)),
		"has_active_contact": bool(source.get("has_active_contact", false)),
		"opportunity_unlocked": bool(source.get("opportunity_unlocked", false)),
		"last_contact_action": str(source.get("last_contact_action", "")),
		"faith_contact_score": int(source.get("faith_contact_score", 0)),
		"orthodox_suspicion": int(source.get("orthodox_suspicion", 0)),
		"last_faith_action": str(source.get("last_faith_action", "")),
		"faith_marked": bool(source.get("faith_marked", false)),
	}


static func _normalize_cultivation_state(character: Dictionary, raw_state: Variant) -> Dictionary:
	var source: Dictionary = raw_state.duplicate(true) if raw_state is Dictionary else {}
	var age_years := int(character.get("age_years", 14))
	var lifespan_limit := int(source.get("lifespan_limit_years", maxi(60, age_years + 40)))
	var lifespan_remaining := int(source.get("lifespan_remaining_years", maxi(0, lifespan_limit - age_years)))
	return {
		"realm": str(source.get("realm", "mortal")),
		"realm_label": str(source.get("realm_label", "凡体")),
		"stage_index": int(source.get("stage_index", 0)),
		"progress": int(source.get("progress", 0)),
		"progress_to_next": int(source.get("progress_to_next", 2)),
		"practice_days": int(source.get("practice_days", 0)),
		"breakthrough_attempts": int(source.get("breakthrough_attempts", 0)),
		"setback_count": int(source.get("setback_count", 0)),
		"weakness_days": int(source.get("weakness_days", 0)),
		"lifespan_limit_years": lifespan_limit,
		"lifespan_remaining_years": lifespan_remaining,
		"last_breakthrough_outcome": str(source.get("last_breakthrough_outcome", "")),
		"last_failure_reason": str(source.get("last_failure_reason", "")),
		"last_event": str(source.get("last_event", "")),
	}


static func _resolve_inheritance_rule(catalog: Resource, family_id: String) -> String:
	if catalog == null or family_id.is_empty() or not catalog.has_method("find_family"):
		return "direct_descendant_first"
	var family: Resource = catalog.find_family(StringName(family_id))
	return str(_resource_get(family, "inheritance_rule", "direct_descendant_first"))


static func _coerce_string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_value is PackedStringArray:
		for item in raw_value:
			result.append(str(item))
	elif raw_value is Array:
		for item in raw_value:
			result.append(str(item))
	return result


static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return fallback if value == null else value
