extends RefCounted
class_name WorldDynamicsService

const EventContractsScript = preload("res://scripts/core/event_contracts.gd")

const STATE_VERSION := 1
const MIN_FACTION_MODIFIER := 0.5
const MAX_FACTION_MODIFIER := 1.5
const MIN_DANGER_LEVEL := 0.0
const MAX_DANGER_LEVEL := 1.0
const MIN_INFLUENCE := -10.0
const MAX_INFLUENCE := 10.0
const LOW_INFLUENCE_RELEASE_THRESHOLD := -7.5

var _catalog: Resource
var _event_log: Node
var _rng_channels: RefCounted

var _region_states: Dictionary = {}
var _faction_influence: Dictionary = {}
var _fallback_world_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func bind_catalog(catalog: Resource) -> void:
	_catalog = catalog


func bind_event_log(event_log: Node) -> void:
	_event_log = event_log


func bind_rng_channels(rng_channels: RefCounted) -> void:
	_rng_channels = rng_channels


func init_region_states(regions: Array, rng: SeededRandom) -> void:
	_region_states.clear()
	_faction_influence.clear()
	_seed_fallback_rng(rng)

	for raw_region in regions:
		var region_id := _resolve_region_id(raw_region)
		if region_id.is_empty():
			continue

		var controlling_faction_id := _resolve_region_controlling_faction_id(raw_region)
		if not controlling_faction_id.is_empty() and not _faction_influence.has(controlling_faction_id):
			_faction_influence[controlling_faction_id] = _resolve_initial_faction_influence(controlling_faction_id)

		var state := {
			"resource_stockpiles": _resolve_initial_stockpiles(raw_region),
			"production_rates": _resolve_production_rates(raw_region),
			"controlling_faction_id": controlling_faction_id,
			"faction_modifier": _resolve_faction_modifier(controlling_faction_id),
			"danger_level": _resolve_region_danger_level(raw_region),
			"population": _resolve_region_population(raw_region),
		}
		_region_states[region_id] = _normalize_region_state(state)


func advance_production() -> void:
	var rng_source: Variant = _resolve_world_rng()
	for region_id_variant in _region_states.keys():
		var region_id := str(region_id_variant)
		var state := _normalize_region_state(_region_states[region_id_variant])
		var stockpiles: Dictionary = state.get("resource_stockpiles", {})
		var production_rates: Dictionary = state.get("production_rates", {})
		var faction_modifier := float(state.get("faction_modifier", 1.0))

		for resource_variant in production_rates.keys():
			var resource_type := str(resource_variant)
			var base_rate := maxf(0.0, float(production_rates[resource_variant]))
			if base_rate <= 0.0:
				continue
			var variance := _roll_range(rng_source, 0.95, 1.05)
			var produced := maxi(0, int(round(base_rate * faction_modifier * variance)))
			if produced <= 0:
				continue
			var previous_amount := int(stockpiles.get(resource_type, 0))
			stockpiles[resource_type] = previous_amount + produced
			_emit_event(EventContractsScript.REGION_RESOURCE_PRODUCED, {
				"region_id": region_id,
				"resource_type": resource_type,
				"amount": produced,
				"before": previous_amount,
				"after": int(stockpiles[resource_type]),
			})

		state["resource_stockpiles"] = stockpiles
		_region_states[region_id] = _normalize_region_state(state)


func advance_consumption(population_modifier: float) -> void:
	var effective_population_modifier := maxf(0.0, population_modifier)
	for region_id_variant in _region_states.keys():
		var region_id := str(region_id_variant)
		var state := _normalize_region_state(_region_states[region_id_variant])
		var stockpiles: Dictionary = state.get("resource_stockpiles", {})
		var population := maxi(1, int(state.get("population", 1)))
		var danger_level := clampf(float(state.get("danger_level", 0.0)), MIN_DANGER_LEVEL, MAX_DANGER_LEVEL)

		var total_before := _sum_stockpiles(stockpiles)
		for resource_variant in stockpiles.keys():
			var resource_type := str(resource_variant)
			var current_amount := maxi(0, int(stockpiles[resource_variant]))
			if current_amount <= 0:
				continue
			var base_factor := 0.012
			if resource_type == "spirit_stone":
				base_factor = 0.009
			var demand := int(round(float(population) * effective_population_modifier * base_factor * (1.0 + danger_level * 0.25)))
			demand = maxi(0, demand)
			if demand <= 0:
				continue
			var consumed := mini(current_amount, demand)
			stockpiles[resource_type] = current_amount - consumed
			if consumed > 0:
				_emit_event(EventContractsScript.REGION_RESOURCE_DEPLETED, {
					"region_id": region_id,
					"resource_type": resource_type,
					"amount": consumed,
					"before": current_amount,
					"after": int(stockpiles[resource_type]),
				})

		state["resource_stockpiles"] = stockpiles
		_region_states[region_id] = _normalize_region_state(state)

		var total_after := _sum_stockpiles(stockpiles)
		var faction_id := str(state.get("controlling_faction_id", "")).strip_edges()
		if faction_id.is_empty():
			continue
		if total_after >= total_before:
			update_faction_influence(faction_id, 0.01)
		else:
			update_faction_influence(faction_id, -0.02)


func gather_resource(region_id: String, resource_type: String, amount: int) -> bool:
	var resolved_region_id := region_id.strip_edges()
	var resolved_resource_type := resource_type.strip_edges()
	if resolved_region_id.is_empty() or resolved_resource_type.is_empty() or amount <= 0:
		return false
	if not _region_states.has(resolved_region_id):
		return false

	var state := _normalize_region_state(_region_states[resolved_region_id])
	var stockpiles: Dictionary = state.get("resource_stockpiles", {})
	var current_amount := maxi(0, int(stockpiles.get(resolved_resource_type, 0)))
	if current_amount < amount:
		return false

	stockpiles[resolved_resource_type] = current_amount - amount
	state["resource_stockpiles"] = stockpiles
	_region_states[resolved_region_id] = _normalize_region_state(state)

	_emit_event(EventContractsScript.REGION_RESOURCE_DEPLETED, {
		"region_id": resolved_region_id,
		"resource_type": resolved_resource_type,
		"amount": amount,
		"before": current_amount,
		"after": int(stockpiles[resolved_resource_type]),
		"cause": "gather",
	})
	return true


func contest_territory(region_id: String, challenger_faction_id: String, combat_result: CombatResultData) -> void:
	var resolved_region_id := region_id.strip_edges()
	var resolved_challenger_id := challenger_faction_id.strip_edges()
	if resolved_region_id.is_empty() or resolved_challenger_id.is_empty():
		return
	if not _region_states.has(resolved_region_id):
		return
	if combat_result == null:
		return
	if str(combat_result.victor_id).strip_edges().is_empty():
		return

	if not _faction_influence.has(resolved_challenger_id):
		_faction_influence[resolved_challenger_id] = _resolve_initial_faction_influence(resolved_challenger_id)

	var state := _normalize_region_state(_region_states[resolved_region_id])
	var previous_faction_id := str(state.get("controlling_faction_id", "")).strip_edges()
	if previous_faction_id == resolved_challenger_id:
		return

	state["controlling_faction_id"] = resolved_challenger_id
	state["faction_modifier"] = _resolve_faction_modifier(resolved_challenger_id)
	_region_states[resolved_region_id] = _normalize_region_state(state)

	update_faction_influence(resolved_challenger_id, 0.25)
	if not previous_faction_id.is_empty():
		update_faction_influence(previous_faction_id, -0.35)

	_emit_event(EventContractsScript.TERRITORY_CHANGED, {
		"region_id": resolved_region_id,
		"from_faction_id": previous_faction_id,
		"to_faction_id": resolved_challenger_id,
		"victor_id": str(combat_result.victor_id),
		"turns_elapsed": combat_result.turns_elapsed,
	})


func update_faction_influence(faction_id: String, delta: float) -> void:
	var resolved_faction_id := faction_id.strip_edges()
	if resolved_faction_id.is_empty() or is_zero_approx(delta):
		return

	var previous_value := float(_faction_influence.get(resolved_faction_id, _resolve_initial_faction_influence(resolved_faction_id)))
	var next_value := clampf(previous_value + delta, MIN_INFLUENCE, MAX_INFLUENCE)
	_faction_influence[resolved_faction_id] = next_value

	for region_id_variant in _region_states.keys():
		var region_id := str(region_id_variant)
		var state := _normalize_region_state(_region_states[region_id_variant])
		if str(state.get("controlling_faction_id", "")).strip_edges() != resolved_faction_id:
			continue
		state["faction_modifier"] = _resolve_faction_modifier(resolved_faction_id)
		_region_states[region_id] = _normalize_region_state(state)

	_emit_event(EventContractsScript.FACTION_INFLUENCE_CHANGED, {
		"faction_id": resolved_faction_id,
		"before": previous_value,
		"after": next_value,
		"delta": next_value - previous_value,
	})

	if next_value <= LOW_INFLUENCE_RELEASE_THRESHOLD:
		_release_edge_territory_if_needed(resolved_faction_id)


func get_region_state(region_id: String) -> Dictionary:
	var resolved_region_id := region_id.strip_edges()
	if resolved_region_id.is_empty() or not _region_states.has(resolved_region_id):
		return {}
	return _normalize_region_state(_region_states[resolved_region_id])


func get_all_region_states() -> Dictionary:
	var result: Dictionary = {}
	for region_id_variant in _region_states.keys():
		var region_id := str(region_id_variant)
		result[region_id] = _normalize_region_state(_region_states[region_id_variant])
	return result


func get_faction_territories(faction_id: String) -> Array[String]:
	var resolved_faction_id := faction_id.strip_edges()
	var result: Array[String] = []
	if resolved_faction_id.is_empty():
		return result
	for region_id_variant in _region_states.keys():
		var region_id := str(region_id_variant)
		var state := _normalize_region_state(_region_states[region_id_variant])
		if str(state.get("controlling_faction_id", "")).strip_edges() == resolved_faction_id:
			result.append(region_id)
	result.sort()
	return result


func save_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"region_states": get_all_region_states(),
		"faction_influence": _duplicate_dict(_faction_influence),
		"fallback_world_rng": {
			"seed": int(_fallback_world_rng.seed),
			"state": int(_fallback_world_rng.state),
		},
	}


func load_state(data: Dictionary) -> void:
	_region_states.clear()
	_faction_influence.clear()

	if data.is_empty() or int(data.get("version", STATE_VERSION)) != STATE_VERSION:
		return

	var raw_region_states: Variant = data.get("region_states", {})
	if raw_region_states is Dictionary:
		for region_id_variant in (raw_region_states as Dictionary).keys():
			var region_id := str(region_id_variant).strip_edges()
			if region_id.is_empty():
				continue
			var state_raw: Variant = (raw_region_states as Dictionary)[region_id_variant]
			if state_raw is Dictionary:
				_region_states[region_id] = _normalize_region_state(state_raw)

	var raw_faction_influence: Variant = data.get("faction_influence", {})
	if raw_faction_influence is Dictionary:
		for faction_id_variant in (raw_faction_influence as Dictionary).keys():
			var faction_id := str(faction_id_variant).strip_edges()
			if faction_id.is_empty():
				continue
			var influence_value := float((raw_faction_influence as Dictionary)[faction_id_variant])
			_faction_influence[faction_id] = clampf(influence_value, MIN_INFLUENCE, MAX_INFLUENCE)

	var raw_rng: Variant = data.get("fallback_world_rng", {})
	if raw_rng is Dictionary:
		var seed_value := int((raw_rng as Dictionary).get("seed", 0))
		var state_value := int((raw_rng as Dictionary).get("state", 0))
		if seed_value != 0:
			_fallback_world_rng.seed = seed_value
		if state_value != 0:
			_fallback_world_rng.state = state_value


func _resolve_region_id(raw_region: Variant) -> String:
	if raw_region is Resource:
		return str(_resource_get(raw_region, "id", "")).strip_edges()
	if raw_region is Dictionary:
		return str((raw_region as Dictionary).get("id", "")).strip_edges()
	return ""


func _resolve_region_controlling_faction_id(raw_region: Variant) -> String:
	if raw_region is Resource:
		return str(_resource_get(raw_region, "controlling_faction_id", "")).strip_edges()
	if raw_region is Dictionary:
		return str((raw_region as Dictionary).get("controlling_faction_id", "")).strip_edges()
	return ""


func _resolve_region_population(raw_region: Variant) -> int:
	var population_hint := 0
	if raw_region is Resource:
		population_hint = int(_resource_get(raw_region, "active_population_hint", 0))
	elif raw_region is Dictionary:
		population_hint = int((raw_region as Dictionary).get("active_population_hint", (raw_region as Dictionary).get("population", 0)))
	if population_hint > 0:
		return population_hint
	return _roll_int_range(_resolve_world_rng(), 80, 200)


func _resolve_region_danger_level(raw_region: Variant) -> float:
	var base_danger := 0.15
	if raw_region is Resource:
		var danger_tags: Variant = _resource_get(raw_region, "danger_tags", PackedStringArray())
		if danger_tags is PackedStringArray:
			base_danger += float((danger_tags as PackedStringArray).size()) * 0.1
	elif raw_region is Dictionary:
		base_danger = float((raw_region as Dictionary).get("danger_level", base_danger))
	base_danger = clampf(base_danger, MIN_DANGER_LEVEL, MAX_DANGER_LEVEL)
	var variance := _roll_range(_resolve_world_rng(), 0.9, 1.1)
	return clampf(base_danger * variance, MIN_DANGER_LEVEL, MAX_DANGER_LEVEL)


func _resolve_initial_stockpiles(raw_region: Variant) -> Dictionary:
	var explicit_stockpiles := _read_dict_field(raw_region, "initial_stockpiles")
	if explicit_stockpiles.is_empty():
		explicit_stockpiles = _read_dict_field(raw_region, "resource_stockpiles")
	if not explicit_stockpiles.is_empty():
		return _normalize_numeric_dict(explicit_stockpiles, 0)

	var inferred_resources := _infer_resources_from_tags(raw_region)
	var result: Dictionary = {}
	for resource_type in inferred_resources:
		result[resource_type] = _roll_int_range(_resolve_world_rng(), 80, 140)
	if result.is_empty():
		result["spirit_stone"] = 100
		result["herb"] = 80
	return _normalize_numeric_dict(result, 0)


func _resolve_production_rates(raw_region: Variant) -> Dictionary:
	var explicit_rates := _read_dict_field(raw_region, "production_rates")
	if not explicit_rates.is_empty():
		return _normalize_numeric_dict(explicit_rates, 0)

	var inferred_resources := _infer_resources_from_tags(raw_region)
	var result: Dictionary = {}
	for resource_type in inferred_resources:
		var base_rate := 4
		if resource_type == "spirit_stone":
			base_rate = 6
		elif resource_type == "herb":
			base_rate = 5
		result[resource_type] = base_rate
	if result.is_empty():
		result["spirit_stone"] = 6
		result["herb"] = 4
	return _normalize_numeric_dict(result, 0)


func _read_dict_field(raw_region: Variant, key: String) -> Dictionary:
	if raw_region is Resource:
		var value: Variant = _resource_get(raw_region, key, {})
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
		return {}
	if raw_region is Dictionary:
		var dict_region: Dictionary = raw_region
		var field_value: Variant = dict_region.get(key, {})
		if field_value is Dictionary:
			return (field_value as Dictionary).duplicate(true)
		return {}
	return {}


func _infer_resources_from_tags(raw_region: Variant) -> Array[String]:
	var tags: Array[String] = []
	if raw_region is Resource:
		var resource_tags: Variant = _resource_get(raw_region, "resource_tags", PackedStringArray())
		if resource_tags is PackedStringArray:
			for tag in resource_tags:
				tags.append(str(tag))
	elif raw_region is Dictionary:
		var resource_tags_value: Variant = (raw_region as Dictionary).get("resource_tags", [])
		if resource_tags_value is Array:
			for tag in (resource_tags_value as Array):
				tags.append(str(tag))

	var resources: Array[String] = []
	for tag_raw in tags:
		var tag := tag_raw.to_lower()
		var resource_type := ""
		if tag.find("stone") >= 0 or tag.find("ore") >= 0 or tag.find("矿") >= 0:
			resource_type = "spirit_stone"
		elif tag.find("herb") >= 0 or tag.find("wood") >= 0 or tag.find("药") >= 0 or tag.find("草") >= 0:
			resource_type = "herb"
		elif tag.find("beast") >= 0 or tag.find("core") >= 0 or tag.find("兽") >= 0:
			resource_type = "beast_core"
		if resource_type.is_empty():
			continue
		if not resources.has(resource_type):
			resources.append(resource_type)

	if not resources.has("spirit_stone"):
		resources.append("spirit_stone")
	return resources


func _resolve_initial_faction_influence(faction_id: String) -> float:
	var resolved_faction_id := faction_id.strip_edges()
	if resolved_faction_id.is_empty():
		return 0.0
	if _catalog != null and _catalog.has_method("find_faction"):
		var faction: Resource = _catalog.find_faction(StringName(resolved_faction_id))
		if faction != null:
			var raw_influence := int(_resource_get(faction, "influence", 0))
			return clampf(float(raw_influence) / 20.0, MIN_INFLUENCE, MAX_INFLUENCE)
	return 0.0


func _resolve_faction_modifier(faction_id: String) -> float:
	var resolved_faction_id := faction_id.strip_edges()
	if resolved_faction_id.is_empty():
		return 1.0
	var influence := float(_faction_influence.get(resolved_faction_id, _resolve_initial_faction_influence(resolved_faction_id)))
	var modifier := 1.0 + influence * 0.05
	return clampf(modifier, MIN_FACTION_MODIFIER, MAX_FACTION_MODIFIER)


func _release_edge_territory_if_needed(faction_id: String) -> void:
	var territories := get_faction_territories(faction_id)
	if territories.size() <= 1:
		return

	var release_region_id := ""
	var release_score := INF
	for region_id in territories:
		var state := get_region_state(region_id)
		if state.is_empty():
			continue
		var score := float(_sum_stockpiles(state.get("resource_stockpiles", {}))) + float(state.get("population", 0)) * 0.1
		if score < release_score:
			release_score = score
			release_region_id = region_id

	if release_region_id.is_empty():
		return

	var state_to_release := _normalize_region_state(_region_states[release_region_id])
	state_to_release["controlling_faction_id"] = ""
	state_to_release["faction_modifier"] = 1.0
	_region_states[release_region_id] = state_to_release

	_emit_event(EventContractsScript.TERRITORY_CHANGED, {
		"region_id": release_region_id,
		"from_faction_id": faction_id,
		"to_faction_id": "",
		"reason": "low_influence_release",
	})


func _sum_stockpiles(raw_stockpiles: Variant) -> int:
	if not (raw_stockpiles is Dictionary):
		return 0
	var total := 0
	for value in (raw_stockpiles as Dictionary).values():
		total += maxi(0, int(value))
	return total


func _normalize_region_state(raw_state: Variant) -> Dictionary:
	if not (raw_state is Dictionary):
		return {
			"resource_stockpiles": {},
			"production_rates": {},
			"controlling_faction_id": "",
			"faction_modifier": 1.0,
			"danger_level": 0.0,
			"population": 1,
		}
	var state: Dictionary = (raw_state as Dictionary).duplicate(true)
	return {
		"resource_stockpiles": _normalize_numeric_dict(state.get("resource_stockpiles", {}), 0),
		"production_rates": _normalize_numeric_dict(state.get("production_rates", {}), 0),
		"controlling_faction_id": str(state.get("controlling_faction_id", "")).strip_edges(),
		"faction_modifier": clampf(float(state.get("faction_modifier", 1.0)), MIN_FACTION_MODIFIER, MAX_FACTION_MODIFIER),
		"danger_level": clampf(float(state.get("danger_level", 0.0)), MIN_DANGER_LEVEL, MAX_DANGER_LEVEL),
		"population": maxi(1, int(state.get("population", 1))),
	}


func _normalize_numeric_dict(raw_value: Variant, min_value: int) -> Dictionary:
	if not (raw_value is Dictionary):
		return {}
	var result: Dictionary = {}
	for key_variant in (raw_value as Dictionary).keys():
		var key := str(key_variant).strip_edges()
		if key.is_empty():
			continue
		result[key] = maxi(min_value, int((raw_value as Dictionary)[key_variant]))
	return result


func _seed_fallback_rng(rng: SeededRandom) -> void:
	if rng == null:
		_fallback_world_rng.seed = 1
		return
	var seed_value := rng.next_int(2147483646) + 1
	_fallback_world_rng.seed = seed_value


func _resolve_world_rng() -> Variant:
	if _rng_channels != null and _rng_channels.has_method("get_world_rng"):
		var world_rng: Variant = _rng_channels.get_world_rng()
		if world_rng != null:
			return world_rng
	return _fallback_world_rng


func _roll_float(rng_source: Variant) -> float:
	if rng_source == null:
		return randf()
	if rng_source is SeededRandom:
		return (rng_source as SeededRandom).next_float()
	if rng_source is RandomNumberGenerator:
		return (rng_source as RandomNumberGenerator).randf()
	if rng_source is Object and rng_source.has_method("next_float"):
		return float(rng_source.next_float())
	if rng_source is Object and rng_source.has_method("randf"):
		return float(rng_source.randf())
	return randf()


func _roll_range(rng_source: Variant, minimum: float, maximum: float) -> float:
	var t := _roll_float(rng_source)
	return minimum + (maximum - minimum) * t


func _roll_int_range(rng_source: Variant, minimum: int, maximum: int) -> int:
	if maximum < minimum:
		var swap := minimum
		minimum = maximum
		maximum = swap
	if minimum == maximum:
		return minimum
	if rng_source is SeededRandom:
		var span := maximum - minimum + 1
		return minimum + (rng_source as SeededRandom).next_int(span)
	if rng_source is RandomNumberGenerator:
		return (rng_source as RandomNumberGenerator).randi_range(minimum, maximum)
	if rng_source is Object and rng_source.has_method("randi_range"):
		return int(rng_source.randi_range(minimum, maximum))
	return randi_range(minimum, maximum)


func _emit_event(event_name: StringName, trace: Dictionary) -> void:
	if _event_log == null or not _event_log.has_method("add_event"):
		return
	_event_log.add_event({
		"category": "world_dynamics",
		"title": str(event_name),
		"direct_cause": str(event_name),
		"result": "world_dynamics_event",
		"trace": _duplicate_dict(trace),
	})


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _duplicate_dict(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)
	return {}
