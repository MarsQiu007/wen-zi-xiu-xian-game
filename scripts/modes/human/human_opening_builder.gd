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
		"branch_weights": {
			"survival": 0,
			"family": 1,
			"learning": 6,
			"cultivation": 0,
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
	var strategy := str(options.get("strategy", ""))
	if strategy.is_empty():
		strategy = str(preset.get("strategy", "learning"))
	var branch_weights: Dictionary = (preset.get("branch_weights", {}) as Dictionary).duplicate(true)
	if strategy == "active_cultivation":
		branch_weights["cultivation"] = int(branch_weights.get("cultivation", 0)) + 8
		branch_weights["learning"] = maxi(0, int(branch_weights.get("learning", 0)) - 2)
	var action_plan := _normalize_action_plan(options.get("action_plan", []))
	var player := {
		"id": str(options.get("player_id", str(_resource_get(base_character, "id", "human_player")))),
		"display_name": str(options.get("player_name", str(_resource_get(base_character, "display_name", "凡俗主角")))),
		"base_character_id": str(_resource_get(base_character, "id", "")),
		"age_years": int(options.get("age_years", int(preset.get("age_years", 14)))),
		"life_stage": str(preset.get("life_stage", normalized)),
		"region_id": str(options.get("region_id", str(_resource_get(base_character, "region_id", str(DEFAULT_REGION_ID))))),
		"family_id": str(options.get("family_id", str(_resource_get(base_character, "family_id", str(DEFAULT_FAMILY_ID))))),
		"faction_id": str(options.get("faction_id", str(_resource_get(base_character, "faction_id", str(DEFAULT_FACTION_ID))))),
		"sect_id": str(options.get("sect_id", str(DEFAULT_SECT_ID))),
	}
	return {
		"opening_type": normalized,
		"opening_label": str(preset.get("label", "少年")),
		"player": player,
		"pressures": (preset.get("pressures", {}) as Dictionary).duplicate(true),
		"branch_weights": branch_weights,
		"dominant_branch": strategy,
		"cultivation_gate": {
			"contact_score": 0,
			"has_active_contact": false,
			"opportunity_unlocked": false,
			"last_contact_action": "",
		},
		"recent_actions": [],
		"strategy": strategy,
		"action_plan": action_plan,
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


static func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	return fallback if value == null else value
