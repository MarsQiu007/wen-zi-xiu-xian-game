extends RefCounted
class_name TechniqueService

const EventContractsScript = preload("res://scripts/core/event_contracts.gd")

const SLOT_MARTIAL_1 := "martial_1"
const SLOT_SPIRIT_1 := "spirit_1"
const SLOT_ULTIMATE := "ultimate"
const SLOT_MOVEMENT := "movement"
const SLOT_PASSIVE_1 := "passive_1"
const SLOT_PASSIVE_2 := "passive_2"

const REASON_OK := "OK"
const REASON_ALREADY_LEARNED := "ALREADY_LEARNED"
const REASON_TECHNIQUE_NOT_FOUND := "TECHNIQUE_NOT_FOUND"
const REASON_INVALID_CHARACTER := "INVALID_CHARACTER"
const REASON_REQUIREMENT_NOT_MET := "REQUIREMENT_NOT_MET"
const REASON_SECT_RESTRICTED := "SECT_RESTRICTED"
const REASON_NOT_LEARNED := "NOT_LEARNED"
const REASON_INVALID_SLOT := "INVALID_SLOT"
const REASON_SLOT_INCOMPATIBLE := "SLOT_INCOMPATIBLE"
const REASON_AFFIX_INDEX_INVALID := "AFFIX_INDEX_INVALID"
const REASON_NO_AFFIX_TO_MEDITATE := "NO_AFFIX_TO_MEDITATE"
const REASON_NOT_ENOUGH_SPIRIT_STONES := "NOT_ENOUGH_SPIRIT_STONES"

const MEDITATION_STONE_ITEM_ID := "mvp_item_spirit_stone"

var _catalog: Resource
var _event_log: Node
var _rng_channels: RefCounted

var _learned_techniques: Dictionary = {}
var _character_resources: Dictionary = {}
var _character_profiles: Dictionary = {}
var _affix_pool_cache: Array[Dictionary] = []


func bind_catalog(catalog: Resource) -> void:
	_catalog = catalog


func bind_event_log(event_log: Node) -> void:
	_event_log = event_log


func bind_rng_channels(rng_channels: RefCounted) -> void:
	_rng_channels = rng_channels


func set_character_spirit_stones(character_id: String, amount: int) -> void:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty():
		return
	var runtime := _get_or_create_character_runtime(resolved_character_id)
	runtime["spirit_stones"] = maxi(0, amount)
	_character_resources[resolved_character_id] = runtime


func set_character_profile(character_id: String, character_data: Dictionary) -> void:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty():
		return
	_character_profiles[resolved_character_id] = character_data.duplicate(true)


func get_character_spirit_stones(character_id: String) -> int:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty():
		return 0
	var runtime := _get_or_create_character_runtime(resolved_character_id)
	return int(runtime.get("spirit_stones", 0))


func learn_technique(character_id: String, technique_id: String, catalog: WorldDataCatalog) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	var resolved_technique_id := technique_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_technique_id.is_empty():
		return _result(false, REASON_INVALID_CHARACTER)

	_catalog = catalog
	var technique := _find_technique(catalog, resolved_technique_id)
	if technique == null:
		return _result(false, REASON_TECHNIQUE_NOT_FOUND)

	if _find_learned_index(resolved_character_id, resolved_technique_id) != -1:
		return _result(false, REASON_ALREADY_LEARNED)

	var requirements := check_learning_requirements(
		resolved_character_id,
		resolved_technique_id,
		catalog,
		_resolve_character_data_for_learning(resolved_character_id)
	)
	if not bool(requirements.get("success", false)):
		return requirements

	var learned_list := _get_or_create_learned(resolved_character_id)
	var affix_slots := maxi(0, int(_resource_get(technique, "affix_slots", 0)))
	var technique_type := str(_resource_get(technique, "technique_type", "martial_skill"))
	var locked_affixes := _generate_locked_affixes(technique_type, affix_slots)
	var learned_record := {
		"technique_id": resolved_technique_id,
		"mastery_level": 0,
		"unlocked_affixes": [],
		"locked_affixes": locked_affixes,
		"equipped_slot": "",
	}
	learned_list.append(learned_record)
	_learned_techniques[resolved_character_id] = learned_list

	_emit_event(EventContractsScript.TECHNIQUE_LEARNED, {
		"character_id": resolved_character_id,
		"technique_id": resolved_technique_id,
		"affix_slots": affix_slots,
	})
	return _result(true, REASON_OK)


func meditate_affix(character_id: String, technique_id: String, affix_index: int, rng: SeededRandom) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	var resolved_technique_id := technique_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_technique_id.is_empty():
		return _result(false, REASON_INVALID_CHARACTER)

	var technique_record := _get_learned_record(resolved_character_id, resolved_technique_id)
	if technique_record.is_empty():
		return _result(false, REASON_NOT_LEARNED)

	var technique := _find_technique(_catalog, resolved_technique_id)
	if technique == null:
		return _result(false, REASON_TECHNIQUE_NOT_FOUND)

	var cost := _resolve_meditation_cost(technique)
	if not _consume_spirit_stones(resolved_character_id, cost):
		return _result(false, REASON_NOT_ENOUGH_SPIRIT_STONES, {"cost": cost})

	var locked_affixes: Array[Dictionary] = _normalize_affix_array(technique_record.get("locked_affixes", []))
	var unlocked_affixes: Array[Dictionary] = _normalize_affix_array(technique_record.get("unlocked_affixes", []))

	var unlocked_new := false
	var target_index := affix_index
	if target_index < 0:
		target_index = 0

	if not locked_affixes.is_empty():
		if target_index >= locked_affixes.size():
			target_index = 0
		var unlocked_affix: Dictionary = (locked_affixes[target_index] as Dictionary).duplicate(true)
		locked_affixes.remove_at(target_index)
		unlocked_affixes.append(unlocked_affix)
		target_index = unlocked_affixes.size() - 1
		unlocked_new = true
	elif unlocked_affixes.is_empty():
		return _result(false, REASON_NO_AFFIX_TO_MEDITATE)

	if target_index < 0 or target_index >= unlocked_affixes.size():
		return _result(false, REASON_AFFIX_INDEX_INVALID)

	var before_affix: Dictionary = (unlocked_affixes[target_index] as Dictionary).duplicate(true)
	var rerolled_affix := _reroll_affix_quality(unlocked_affixes[target_index], _resolve_loot_rng(rng))
	unlocked_affixes[target_index] = rerolled_affix

	technique_record["locked_affixes"] = locked_affixes
	technique_record["unlocked_affixes"] = unlocked_affixes
	technique_record["mastery_level"] = mini(100, int(technique_record.get("mastery_level", 0)) + 5)
	_set_learned_record(resolved_character_id, resolved_technique_id, technique_record)

	var after_stones := get_character_spirit_stones(resolved_character_id)
	_emit_event(EventContractsScript.TECHNIQUE_MEDITATED, {
		"character_id": resolved_character_id,
		"technique_id": resolved_technique_id,
		"cost": cost,
		"spirit_stones_after": after_stones,
		"unlocked_new": unlocked_new,
		"before_affix": before_affix,
		"after_affix": rerolled_affix,
	})

	return _result(true, REASON_OK, {
		"cost": cost,
		"spirit_stones_after": after_stones,
		"unlocked_new": unlocked_new,
		"before_affix": before_affix,
		"after_affix": rerolled_affix,
	})


func equip_technique(character_id: String, technique_id: String, slot: String) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_technique_id := technique_id.strip_edges()
	var resolved_slot := slot.strip_edges()
	if resolved_character_id.is_empty() or resolved_technique_id.is_empty() or resolved_slot.is_empty():
		return false
	if not _is_known_slot(resolved_slot):
		return false

	var technique_record := _get_learned_record(resolved_character_id, resolved_technique_id)
	if technique_record.is_empty():
		return false

	var technique := _find_technique(_catalog, resolved_technique_id)
	if technique == null:
		return false
	if not _is_slot_compatible(str(_resource_get(technique, "technique_type", "martial_skill")), resolved_slot):
		return false

	var learned_list := _get_or_create_learned(resolved_character_id)
	for index in range(learned_list.size()):
		var record: Dictionary = learned_list[index]
		if str(record.get("equipped_slot", "")) != resolved_slot:
			continue
		record["equipped_slot"] = ""
		learned_list[index] = record

	var target_index := _find_learned_index(resolved_character_id, resolved_technique_id)
	if target_index == -1:
		return false
	var target_record: Dictionary = learned_list[target_index]
	target_record["equipped_slot"] = resolved_slot
	learned_list[target_index] = target_record
	_learned_techniques[resolved_character_id] = learned_list

	_emit_event(EventContractsScript.TECHNIQUE_EQUIPPED, {
		"character_id": resolved_character_id,
		"technique_id": resolved_technique_id,
		"slot": resolved_slot,
		"equipped": true,
	})
	return true


func unequip_technique(character_id: String, slot: String) -> bool:
	var resolved_character_id := character_id.strip_edges()
	var resolved_slot := slot.strip_edges()
	if resolved_character_id.is_empty() or resolved_slot.is_empty():
		return false
	if not _learned_techniques.has(resolved_character_id):
		return false

	var learned_list: Array[Dictionary] = _learned_techniques[resolved_character_id]
	for index in range(learned_list.size()):
		var record: Dictionary = learned_list[index]
		if str(record.get("equipped_slot", "")) != resolved_slot:
			continue
		var technique_id := str(record.get("technique_id", ""))
		record["equipped_slot"] = ""
		learned_list[index] = record
		_learned_techniques[resolved_character_id] = learned_list
		_emit_event(EventContractsScript.TECHNIQUE_EQUIPPED, {
			"character_id": resolved_character_id,
			"technique_id": technique_id,
			"slot": resolved_slot,
			"equipped": false,
		})
		return true
	return false


func get_learned_techniques(character_id: String) -> Array[Dictionary]:
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty() or not _learned_techniques.has(resolved_character_id):
		return []
	return _duplicate_records(_learned_techniques[resolved_character_id])


func get_technique_combat_skills(character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resolved_character_id := character_id.strip_edges()
	if resolved_character_id.is_empty() or not _learned_techniques.has(resolved_character_id):
		return result

	for record in _learned_techniques[resolved_character_id]:
		var equipped_slot := str(record.get("equipped_slot", ""))
		if equipped_slot.is_empty():
			continue
		var technique_id := str(record.get("technique_id", ""))
		var technique := _find_technique(_catalog, technique_id)
		if technique == null:
			continue
		var skills: Variant = _resource_get(technique, "combat_skills", [])
		if not (skills is Array):
			continue
		for raw_skill in skills:
			if not (raw_skill is Dictionary):
				continue
			var skill_data := (raw_skill as Dictionary).duplicate(true)
			skill_data["technique_id"] = technique_id
			skill_data["equipped_slot"] = equipped_slot
			result.append(skill_data)
	return result


func check_learning_requirements(character_id: String, technique_id: String, catalog: WorldDataCatalog, character_data: Dictionary) -> Dictionary:
	var resolved_character_id := character_id.strip_edges()
	var resolved_technique_id := technique_id.strip_edges()
	if resolved_character_id.is_empty() or resolved_technique_id.is_empty():
		return _result(false, REASON_INVALID_CHARACTER)

	_catalog = catalog
	var technique := _find_technique(catalog, resolved_technique_id)
	if technique == null:
		return _result(false, REASON_TECHNIQUE_NOT_FOUND)

	var resolved_character_data := character_data.duplicate(true)
	if resolved_character_data.is_empty():
		resolved_character_data = _resolve_character_data_for_learning(resolved_character_id)

	var sect_exclusive_id := str(_resource_get(technique, "sect_exclusive_id", "")).strip_edges()
	var character_faction_id := _resolve_character_faction_id(resolved_character_data)
	if not sect_exclusive_id.is_empty() and sect_exclusive_id != character_faction_id:
		_emit_event(EventContractsScript.TECHNIQUE_SECT_RESTRICTED, {
			"character_id": resolved_character_id,
			"technique_id": resolved_technique_id,
			"required_sect": sect_exclusive_id,
			"character_faction_id": character_faction_id,
		})
		return _result(false, REASON_SECT_RESTRICTED, {
			"required_sect": sect_exclusive_id,
			"character_faction_id": character_faction_id,
		})

	if resolved_character_data.is_empty():
		return _result(true, REASON_OK)

	var realm_required := int(_resource_get(technique, "min_realm", 0))
	var realm_current := int(resolved_character_data.get("realm", resolved_character_data.get("realm_level", 0)))
	if realm_current < realm_required:
		return _result(false, REASON_REQUIREMENT_NOT_MET, {
			"key": "realm",
			"required": realm_required,
			"actual": realm_current,
		})

	var requirements: Variant = _resource_get(technique, "learning_requirements", {})
	if requirements is Dictionary:
		for key_variant in (requirements as Dictionary).keys():
			var key := str(key_variant)
			var required_value: Variant = requirements[key_variant]
			var actual_value: Variant = _lookup_character_requirement(resolved_character_data, key)
			if not _is_requirement_satisfied(required_value, actual_value):
				return _result(false, REASON_REQUIREMENT_NOT_MET, {
					"key": key,
					"required": required_value,
					"actual": actual_value,
				})

	return _result(true, REASON_OK)


func save_state() -> Dictionary:
	var learned_data: Dictionary = {}
	for character_id_variant in _learned_techniques.keys():
		var character_id := str(character_id_variant)
		learned_data[character_id] = _duplicate_records(_learned_techniques[character_id_variant])

	var resources_data: Dictionary = {}
	for character_id_variant in _character_resources.keys():
		var character_id := str(character_id_variant)
		var runtime_value: Variant = _character_resources[character_id_variant]
		if runtime_value is Dictionary:
			resources_data[character_id] = (runtime_value as Dictionary).duplicate(true)

	var profile_data: Dictionary = {}
	for character_id_variant in _character_profiles.keys():
		var character_id := str(character_id_variant)
		var profile_raw: Variant = _character_profiles[character_id_variant]
		if profile_raw is Dictionary:
			profile_data[character_id] = (profile_raw as Dictionary).duplicate(true)

	return {
		"learned_techniques": learned_data,
		"character_resources": resources_data,
		"character_profiles": profile_data,
	}


func load_state(data: Dictionary) -> void:
	_learned_techniques.clear()
	_character_resources.clear()
	_character_profiles.clear()

	var learned_raw: Variant = data.get("learned_techniques", {})
	if learned_raw is Dictionary:
		for character_id_variant in learned_raw.keys():
			var character_id := str(character_id_variant).strip_edges()
			if character_id.is_empty():
				continue
			var records_raw: Variant = learned_raw[character_id_variant]
			if not (records_raw is Array):
				continue
			var normalized_records: Array[Dictionary] = []
			for record_raw in records_raw:
				if not (record_raw is Dictionary):
					continue
				var normalized_record := _normalize_learned_record(record_raw)
				if normalized_record.is_empty():
					continue
				normalized_records.append(normalized_record)
			if not normalized_records.is_empty():
				_learned_techniques[character_id] = normalized_records

	var resources_raw: Variant = data.get("character_resources", {})
	if resources_raw is Dictionary:
		for character_id_variant in resources_raw.keys():
			var character_id := str(character_id_variant).strip_edges()
			if character_id.is_empty():
				continue
			var runtime_raw: Variant = resources_raw[character_id_variant]
			if not (runtime_raw is Dictionary):
				continue
			var runtime: Dictionary = (runtime_raw as Dictionary).duplicate(true)
			runtime["spirit_stones"] = maxi(0, int(runtime.get("spirit_stones", 1000)))
			_character_resources[character_id] = runtime

	var profiles_raw: Variant = data.get("character_profiles", {})
	if profiles_raw is Dictionary:
		for character_id_variant in profiles_raw.keys():
			var character_id := str(character_id_variant).strip_edges()
			if character_id.is_empty():
				continue
			var profile_raw: Variant = profiles_raw[character_id_variant]
			if profile_raw is Dictionary:
				_character_profiles[character_id] = (profile_raw as Dictionary).duplicate(true)


func _get_or_create_learned(character_id: String) -> Array[Dictionary]:
	if not _learned_techniques.has(character_id):
		var empty_records: Array[Dictionary] = []
		_learned_techniques[character_id] = empty_records
		return empty_records
	var raw: Variant = _learned_techniques[character_id]
	if not (raw is Array):
		var reset_records: Array[Dictionary] = []
		_learned_techniques[character_id] = reset_records
		return reset_records
	var normalized: Array[Dictionary] = []
	for record_raw in raw:
		if record_raw is Dictionary:
			var normalized_record := _normalize_learned_record(record_raw)
			if not normalized_record.is_empty():
				normalized.append(normalized_record)
	_learned_techniques[character_id] = normalized
	return normalized


func _get_learned_record(character_id: String, technique_id: String) -> Dictionary:
	var index := _find_learned_index(character_id, technique_id)
	if index == -1:
		return {}
	var learned_list: Array[Dictionary] = _get_or_create_learned(character_id)
	if index < 0 or index >= learned_list.size():
		return {}
	return (learned_list[index] as Dictionary).duplicate(true)


func _set_learned_record(character_id: String, technique_id: String, record: Dictionary) -> void:
	var index := _find_learned_index(character_id, technique_id)
	if index == -1:
		return
	var learned_list: Array[Dictionary] = _get_or_create_learned(character_id)
	learned_list[index] = _normalize_learned_record(record)
	_learned_techniques[character_id] = learned_list


func _find_learned_index(character_id: String, technique_id: String) -> int:
	var learned_list: Array[Dictionary] = _get_or_create_learned(character_id)
	for index in range(learned_list.size()):
		var record: Dictionary = learned_list[index]
		if str(record.get("technique_id", "")) == technique_id:
			return index
	return -1


func _find_technique(catalog: Resource, technique_id: String) -> Resource:
	if catalog == null or not catalog.has_method("find_technique"):
		return null
	return catalog.find_technique(StringName(technique_id))


func _normalize_learned_record(raw_record: Dictionary) -> Dictionary:
	var technique_id := str(raw_record.get("technique_id", "")).strip_edges()
	if technique_id.is_empty():
		return {}
	return {
		"technique_id": technique_id,
		"mastery_level": clampi(int(raw_record.get("mastery_level", 0)), 0, 100),
		"unlocked_affixes": _normalize_affix_array(raw_record.get("unlocked_affixes", [])),
		"locked_affixes": _normalize_affix_array(raw_record.get("locked_affixes", [])),
		"equipped_slot": str(raw_record.get("equipped_slot", "")).strip_edges(),
	}


func _normalize_affix_array(raw_affixes: Variant) -> Array[Dictionary]:
	if not (raw_affixes is Array):
		return []
	var result: Array[Dictionary] = []
	for affix_raw in raw_affixes:
		if affix_raw is Dictionary:
			result.append((affix_raw as Dictionary).duplicate(true))
	return result


func _generate_locked_affixes(technique_type: String, slot_count: int) -> Array[Dictionary]:
	if slot_count <= 0:
		return []
	var pool := _get_affix_pool_for_type(technique_type)
	if pool.is_empty():
		return _build_fallback_affixes(slot_count, technique_type)

	var result: Array[Dictionary] = []
	for index in range(slot_count):
		var source: Dictionary = pool[index % pool.size()]
		result.append(source.duplicate(true))
	return result


func _get_affix_pool_for_type(technique_type: String) -> Array[Dictionary]:
	if _affix_pool_cache.is_empty():
		_affix_pool_cache = _load_affix_pool_from_samples()
	var filtered: Array[Dictionary] = []
	for affix in _affix_pool_cache:
		var compatible: Variant = affix.get("compatible_types", [])
		if compatible is Array and (compatible as Array).has(technique_type):
			filtered.append(affix.duplicate(true))
	if filtered.is_empty():
		return _affix_pool_cache.duplicate(true)
	return filtered


func _load_affix_pool_from_samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open("res://resources/world/samples")
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.begins_with("mvp_affix_") or not file_name.ends_with(".tres"):
			continue
		var path := "res://resources/world/samples/%s" % file_name
		var affix_resource := load(path)
		if affix_resource == null:
			continue
		var compatible_raw: Variant = _resource_get(affix_resource, "compatible_types", [])
		var compatible_types: Array = compatible_raw if compatible_raw is Array else []
		result.append({
			"affix_id": str(_resource_get(affix_resource, "affix_id", file_name.trim_suffix(".tres"))),
			"affix_name": str(_resource_get(affix_resource, "affix_name", "未知词条")),
			"affix_category": str(_resource_get(affix_resource, "affix_category", "utility")),
			"effect": _duplicate_dict(_resource_get(affix_resource, "effect", {})),
			"rarity": str(_resource_get(affix_resource, "rarity", "common")),
			"compatible_types": compatible_types.duplicate(true),
		})
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("affix_id", "")) < str(b.get("affix_id", ""))
	)
	return result


func _build_fallback_affixes(slot_count: int, technique_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(slot_count):
		result.append({
			"affix_id": "fallback_affix_%s_%d" % [technique_type, index],
			"affix_name": "基础词条 %d" % (index + 1),
			"affix_category": "utility",
			"effect": {},
			"rarity": "common",
			"compatible_types": [technique_type],
		})
	return result


func _resolve_loot_rng(fallback_rng: SeededRandom) -> Variant:
	if _rng_channels != null and _rng_channels.has_method("get_loot_rng"):
		var rng = _rng_channels.get_loot_rng()
		if rng != null:
			return rng
	return fallback_rng


func _reroll_affix_quality(affix: Variant, rng_source: Variant) -> Dictionary:
	if not (affix is Dictionary):
		return {}
	var result: Dictionary = (affix as Dictionary).duplicate(true)
	var rarity_list := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	var current_rarity := str(result.get("rarity", "common"))
	var current_index := maxi(0, rarity_list.find(current_rarity))
	var roll := _roll_float(rng_source)
	var delta := 0
	if roll < 0.2:
		delta = -1
	elif roll > 0.8:
		delta = 1
	var next_index := clampi(current_index + delta, 0, rarity_list.size() - 1)
	result["rarity"] = rarity_list[next_index]

	var effect := _duplicate_dict(result.get("effect", {}))
	var multiplier := 1.0
	if delta < 0:
		multiplier = 0.9
	elif delta > 0:
		multiplier = 1.1
	for key_variant in effect.keys():
		var key := str(key_variant)
		var value = effect[key_variant]
		if value is int:
			effect[key] = int(round(float(value) * multiplier))
		elif value is float:
			effect[key] = float(value) * multiplier
	result["effect"] = effect
	return result


func _roll_float(rng_source: Variant) -> float:
	if rng_source == null:
		return randf()
	if rng_source is RandomNumberGenerator:
		return (rng_source as RandomNumberGenerator).randf()
	if rng_source is SeededRandom:
		return (rng_source as SeededRandom).next_float()
	if rng_source is Object and rng_source.has_method("next_float"):
		return float(rng_source.next_float())
	if rng_source is Object and rng_source.has_method("randf"):
		return float(rng_source.randf())
	return randf()


func _resolve_meditation_cost(technique: Resource) -> int:
	var base_value := int(_resource_get(technique, "base_value", 0))
	if base_value <= 0:
		base_value = max(10, int(_resource_get(technique, "power_level", 1)) * 10)
	return base_value * 2


func _consume_spirit_stones(character_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var runtime := _get_or_create_character_runtime(character_id)
	var current := int(runtime.get("spirit_stones", 0))
	if current < amount:
		return false
	runtime["spirit_stones"] = current - amount
	_character_resources[character_id] = runtime
	return true


func _get_or_create_character_runtime(character_id: String) -> Dictionary:
	if not _character_resources.has(character_id):
		var initial := {
			"spirit_stones": 1000,
		}
		_character_resources[character_id] = initial
		return initial
	var raw: Variant = _character_resources[character_id]
	if raw is Dictionary:
		var runtime: Dictionary = (raw as Dictionary).duplicate(true)
		runtime["spirit_stones"] = maxi(0, int(runtime.get("spirit_stones", 1000)))
		_character_resources[character_id] = runtime
		return runtime
	var reset_runtime := {"spirit_stones": 1000}
	_character_resources[character_id] = reset_runtime
	return reset_runtime


func _is_known_slot(slot: String) -> bool:
	return slot == SLOT_MARTIAL_1 or slot == SLOT_SPIRIT_1 or slot == SLOT_ULTIMATE or slot == SLOT_MOVEMENT or slot == SLOT_PASSIVE_1 or slot == SLOT_PASSIVE_2


func _is_slot_compatible(technique_type: String, slot: String) -> bool:
	match technique_type:
		"martial_skill":
			return slot == SLOT_MARTIAL_1
		"spirit_skill":
			return slot == SLOT_SPIRIT_1
		"ultimate":
			return slot == SLOT_ULTIMATE
		"movement_method":
			return slot == SLOT_MOVEMENT
		"passive_method":
			return slot == SLOT_PASSIVE_1 or slot == SLOT_PASSIVE_2
		_:
			return false


func _resolve_character_faction_id(character_data: Dictionary) -> String:
	var faction_id := str(character_data.get("faction_id", "")).strip_edges()
	if not faction_id.is_empty():
		return faction_id
	var faction_value: Variant = character_data.get("faction", "")
	if faction_value is String or faction_value is StringName:
		return str(faction_value).strip_edges()
	if faction_value is Dictionary:
		return str((faction_value as Dictionary).get("id", "")).strip_edges()
	return ""


func _resolve_character_data_for_learning(character_id: String) -> Dictionary:
	if not _character_profiles.has(character_id):
		return {}
	var raw: Variant = _character_profiles[character_id]
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func _lookup_character_requirement(character_data: Dictionary, key: String) -> Variant:
	if character_data.has(key):
		return character_data[key]
	var traits: Variant = character_data.get("traits", {})
	if traits is Dictionary and (traits as Dictionary).has(key):
		return (traits as Dictionary)[key]
	var qualifications: Variant = character_data.get("qualifications", {})
	if qualifications is Dictionary and (qualifications as Dictionary).has(key):
		return (qualifications as Dictionary)[key]
	return null


func _is_requirement_satisfied(required_value: Variant, actual_value: Variant) -> bool:
	if required_value is int or required_value is float:
		if actual_value == null:
			return false
		if not (actual_value is int or actual_value is float):
			return false
		return float(actual_value) >= float(required_value)
	if required_value is bool:
		return bool(actual_value) == bool(required_value)
	if required_value is String or required_value is StringName:
		return str(actual_value) == str(required_value)
	if required_value is Array:
		if actual_value is Array:
			for required_item in (required_value as Array):
				if not (actual_value as Array).has(required_item):
					return false
			return true
		return false
	return actual_value == required_value


func _emit_event(event_name: StringName, trace: Dictionary) -> void:
	if _event_log == null or not _event_log.has_method("add_event"):
		return
	_event_log.add_event({
		"category": "technique",
		"title": str(event_name),
		"direct_cause": str(event_name),
		"result": "technique_event",
		"trace": _duplicate_dict(trace),
	})


func _result(success: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"success": success,
		"reason": reason,
	}
	for key in extra.keys():
		result[str(key)] = extra[key]
	return result


func _duplicate_records(raw_records: Variant) -> Array[Dictionary]:
	if not (raw_records is Array):
		return []
	var result: Array[Dictionary] = []
	for record_raw in raw_records:
		if record_raw is Dictionary:
			result.append((record_raw as Dictionary).duplicate(true))
	return result


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _duplicate_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
