extends RefCounted
class_name WorldGenerator

const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")
const NameGeneratorScript = preload("res://scripts/world/name_generator.gd")
const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const ITEM_AFFIX_POOL := {
	"weapon": [
		{"affix_id": "item_affix_sharp_edge", "affix_name": "锋锐", "effect": {"attack": 3}, "rarity": "common"},
		{"affix_id": "item_affix_burning_edge", "affix_name": "灼刃", "effect": {"fire_damage": 4}, "rarity": "rare"},
		{"affix_id": "item_affix_thunder_edge", "affix_name": "雷切", "effect": {"thunder_damage": 6}, "rarity": "epic"},
	],
	"armor": [
		{"affix_id": "item_affix_hardened_guard", "affix_name": "坚护", "effect": {"defense": 3}, "rarity": "common"},
		{"affix_id": "item_affix_spirit_guard", "affix_name": "灵御", "effect": {"damage_reduction": 0.08}, "rarity": "rare"},
	],
	"accessory": [
		{"affix_id": "item_affix_clear_mind", "affix_name": "清心", "effect": {"mp_regen": 0.04}, "rarity": "uncommon"},
		{"affix_id": "item_affix_lucky_star", "affix_name": "福星", "effect": {"drop_bonus": 0.06}, "rarity": "rare"},
	],
	"consumable": [
		{"affix_id": "item_affix_pure_refine", "affix_name": "纯炼", "effect": {"effect_power": 0.08}, "rarity": "uncommon"},
	],
}
const DEFAULT_ITEM_AFFIX_POOL := [
	{"affix_id": "item_affix_spirit_trace", "affix_name": "灵痕", "effect": {"spirit_power": 2}, "rarity": "common"},
	{"affix_id": "item_affix_ancient_mark", "affix_name": "古印", "effect": {"all_stats": 1}, "rarity": "uncommon"},
]


func generate(seed_data: WorldSeedData) -> Dictionary:
	var rng: RefCounted = SeededRandomScript.new()
	rng.set_seed(int(seed_data.seed_value))
	var catalog := _load_catalog()

	var regions := generate_regions(seed_data, rng, catalog)
	var characters := generate_characters(seed_data, regions, rng)
	var relationships := generate_relationships(characters, rng)
	var resources := generate_resources(regions, rng)
	var monsters := generate_monsters(regions, rng)
	var cultivation_methods := generate_cultivation_methods(rng, catalog)
	var techniques := generate_techniques(regions, rng, catalog, cultivation_methods)
	var items := generate_items(regions, rng, catalog)
	var loot_assignments := generate_loot_assignments(regions, rng, catalog, items)
	var region_dynamics_init := generate_region_dynamics_init(regions, rng, catalog, loot_assignments)

	return {
		"regions": regions,
		"characters": characters,
		"relationships": relationships,
		"resources": resources,
		"monsters": monsters,
		"cultivation_methods": cultivation_methods,
		"techniques": techniques,
		"items": items,
		"loot_assignments": loot_assignments,
		"region_dynamics_init": region_dynamics_init,
		"seed": int(seed_data.seed_value),
	}


func generate_regions(seed_data: WorldSeedData, rng: RefCounted, catalog: Resource = null) -> Array[Dictionary]:
	var catalog_regions := _catalog_regions(catalog)
	if not catalog_regions.is_empty():
		return _generate_regions_from_catalog(seed_data, rng, catalog_regions)

	var result: Array[Dictionary] = []
	var region_types := ["mountain", "city", "village", "secret_realm", "wilderness"]

	for i in range(int(seed_data.region_count)):
		var region_id := "region_%d" % i
		var region_name := NameGeneratorScript.generate_region_name(rng)
		var region_type: String = str(region_types[_rng_next_int(rng, region_types.size())])
		var description := _generate_region_description(region_type, region_name, rng)
		var resource_count := int(_rng_next_float(rng) * 5.0 * float(seed_data.resource_density)) + 1
		var monster_count := int(_rng_next_float(rng) * 3.0 * float(seed_data.monster_density))

		var adjacent: Array[String] = []
		var adj_count := _rng_next_int(rng, 3) + 1
		for _j in range(adj_count):
			var adj_idx := _rng_next_int(rng, int(seed_data.region_count))
			var adj_id := "region_%d" % adj_idx
			if adj_idx != i and not adjacent.has(adj_id):
				adjacent.append(adj_id)

		result.append({
			"id": region_id,
			"name": region_name,
			"type": region_type,
			"description": description,
			"resource_count": resource_count,
			"monster_count": monster_count,
			"adjacent_regions": adjacent,
		})
	return result


func _generate_regions_from_catalog(seed_data: WorldSeedData, rng: RefCounted, catalog_regions: Array[Resource]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var region_count := mini(int(seed_data.region_count), catalog_regions.size())
	if region_count <= 0:
		return result

	for index in range(region_count):
		var region_resource := catalog_regions[index]
		var region_id := str(_resource_get(region_resource, "id", "region_%d" % index)).strip_edges()
		var display_name := str(_resource_get(region_resource, "display_name", NameGeneratorScript.generate_region_name(rng)))
		var summary := str(_resource_get(region_resource, "summary", ""))
		var region_type := str(_resource_get(region_resource, "region_type", "region"))
		var adjacent_regions := _packed_string_array_to_string_array(_resource_get(region_resource, "adjacent_region_ids", PackedStringArray()))
		var resource_tags := _packed_string_array_to_string_array(_resource_get(region_resource, "resource_tags", PackedStringArray()))
		var danger_tags := _packed_string_array_to_string_array(_resource_get(region_resource, "danger_tags", PackedStringArray()))

		var resource_count := maxi(1, int(round(float(maxi(1, resource_tags.size())) * float(seed_data.resource_density) * 3.0)))
		var monster_count := maxi(0, int(round(float(maxi(1, danger_tags.size())) * float(seed_data.monster_density) * 2.0)))

		result.append({
			"id": region_id,
			"name": display_name,
			"type": region_type,
			"description": summary,
			"resource_count": resource_count,
			"monster_count": monster_count,
			"adjacent_regions": adjacent_regions,
			"controlling_faction_id": str(_resource_get(region_resource, "controlling_faction_id", "")),
			"resource_tags": resource_tags,
			"danger_tags": danger_tags,
			"active_population_hint": int(_resource_get(region_resource, "active_population_hint", 0)),
			"catalog_region_id": region_id,
		})
	return result


func generate_characters(seed_data: WorldSeedData, regions: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var genders := ["male", "female"]
	var professions := ["farmer", "merchant", "scholar", "warrior", "alchemist", "herbalist", "hunter", "artisan", "monk", "wanderer"]
	var realms := ["mortal", "qi_condensing", "foundation", "golden_core"]

	if regions.is_empty():
		return result

	for i in range(int(seed_data.npc_count)):
		var char_id := "npc_%d" % i
		var name_result := NameGeneratorScript.generate_character_name(rng)
		var gender: String = str(genders[_rng_next_int(rng, genders.size())])
		var age := _rng_next_int(rng, 50) + 14
		var realm: String = str(realms[0])
		var realm_roll := _rng_next_float(rng)
		if realm_roll < 0.05:
			realm = str(realms[2])
		elif realm_roll < 0.20:
			realm = str(realms[1])
		var birth_region := regions[_rng_next_int(rng, regions.size())]
		var morality := (_rng_next_float(rng) * 200.0) - 100.0
		var profession: String = str(professions[_rng_next_int(rng, professions.size())])

		result.append({
			"id": char_id,
			"display_name": name_result,
			"age": age,
			"gender": gender,
			"realm": realm,
			"birth_region_id": str(birth_region.get("id", "")),
			"is_alive": true,
			"morality": morality,
			"profession": profession,
			"cultivation_progress": 0.0,
			"pressures": {
				"survival": _rng_next_int(rng, 10) + 1,
				"family": _rng_next_int(rng, 10) + 1,
				"learning": _rng_next_int(rng, 10) + 1,
				"cultivation": _rng_next_int(rng, 10) + 1,
			},
		})
	return result


func generate_relationships(characters: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var relation_types := ["family", "friend", "rival", "mentor", "disciple", "ally", "enemy"]

	if characters.is_empty():
		return result

	for character in characters:
		var rel_count := _rng_next_int(rng, 3) + 1
		for _j in range(rel_count):
			var target_idx := _rng_next_int(rng, characters.size())
			var target := characters[target_idx]
			if str(target.get("id", "")) == str(character.get("id", "")):
				continue

			var relation_type: String = str(relation_types[_rng_next_int(rng, relation_types.size())])
			var favor := _rng_next_int(rng, 200) - 100
			var trust := _rng_next_int(rng, 60) - 30

			var already_exists := false
			for existing in result:
				if str(existing.get("source_id", "")) == str(character.get("id", "")) and str(existing.get("target_id", "")) == str(target.get("id", "")):
					already_exists = true
					break
			if already_exists:
				continue

			result.append({
				"source_id": str(character.get("id", "")),
				"target_id": str(target.get("id", "")),
				"relation_type": relation_type,
				"favor": favor,
				"trust": trust,
				"interaction_count": 0,
			})
	return result


func generate_resources(regions: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resource_types := ["spirit_stone", "herb", "mineral", "beast_core", "spirit_vein", "medicinal_pool"]

	for region in regions:
		for _j in range(int(region.get("resource_count", 1))):
			var res_id := "res_%d" % result.size()
			result.append({
				"id": res_id,
				"region_id": str(region.get("id", "")),
				"type": str(resource_types[_rng_next_int(rng, resource_types.size())]),
				"abundance": _rng_next_float(rng) * 0.8 + 0.2,
			})
	return result


func generate_monsters(regions: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var monster_types := ["spirit_beast", "demon_beast", "undead", "elemental", "mutant_beast"]
	var monster_names_prefix := ["赤", "玄", "青", "白", "金", "幽", "炎", "冰", "雷", "风"]
	var monster_names_suffix := ["狼", "蛇", "鹰", "熊", "虎", "蟒", "蛛", "蝎", "龟", "鹤"]

	for region in regions:
		for _j in range(int(region.get("monster_count", 0))):
			var mon_id := "mon_%d" % result.size()
			var name: String = str(monster_names_prefix[_rng_next_int(rng, monster_names_prefix.size())]) + str(monster_names_suffix[_rng_next_int(rng, monster_names_suffix.size())])
			result.append({
				"id": mon_id,
				"region_id": str(region.get("id", "")),
				"name": name,
				"type": str(monster_types[_rng_next_int(rng, monster_types.size())]),
				"threat_level": _rng_next_int(rng, 10) + 1,
			})
	return result


func generate_cultivation_methods(rng: RefCounted, catalog: Resource = null) -> Array[Dictionary]:
	var from_catalog := _generate_cultivation_methods_from_catalog(catalog)
	if not from_catalog.is_empty():
		return from_catalog

	var result: Array[Dictionary] = []
	var method_names := ["太清功", "玄天诀", "碧落心经", "紫霄剑诀", "金丹大道", "九转玄功", "混元一气", "天罡正气"]
	var elements := ["fire", "water", "earth", "wind", "lightning", "ice", "light", "dark"]

	for i in range(method_names.size()):
		result.append({
			"id": "method_%d" % i,
			"name": str(method_names[i]),
			"element": str(elements[_rng_next_int(rng, elements.size())]),
			"min_realm": "mortal",
			"power_level": _rng_next_int(rng, 5) + 1,
		})
	return result


func _generate_cultivation_methods_from_catalog(catalog: Resource) -> Array[Dictionary]:
	var techniques := _catalog_techniques(catalog)
	var result: Array[Dictionary] = []
	for raw_technique in techniques:
		var technique_id := str(_resource_get(raw_technique, "id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		result.append({
			"id": technique_id,
			"name": str(_resource_get(raw_technique, "display_name", technique_id)),
			"element": str(_resource_get(raw_technique, "element", "neutral")),
			"min_realm": _realm_index_to_name(int(_resource_get(raw_technique, "min_realm", 0))),
			"power_level": int(_resource_get(raw_technique, "power_level", 1)),
		})
	return result


func generate_techniques(regions: Array[Dictionary], rng: RefCounted, catalog: Resource, cultivation_methods: Array[Dictionary]) -> Array[Dictionary]:
	var from_catalog := _generate_techniques_from_catalog(regions, rng, catalog)
	if not from_catalog.is_empty():
		return from_catalog
	return _generate_techniques_from_legacy_methods(regions, rng, cultivation_methods)


func _generate_techniques_from_catalog(regions: Array[Dictionary], rng: RefCounted, catalog: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var technique_resources := _catalog_techniques(catalog)
	if technique_resources.is_empty() or regions.is_empty():
		return result

	var technique_affix_pool := _load_technique_affix_pool()
	for raw_technique in technique_resources:
		var technique_id := str(_resource_get(raw_technique, "id", "")).strip_edges()
		if technique_id.is_empty():
			continue
		var sect_exclusive_id := str(_resource_get(raw_technique, "sect_exclusive_id", "")).strip_edges()
		var candidate_regions := _pick_technique_regions(regions, sect_exclusive_id)
		if candidate_regions.is_empty():
			continue
		var target_region := candidate_regions[_rng_next_int(rng, candidate_regions.size())]

		var affix_slots := maxi(0, int(_resource_get(raw_technique, "affix_slots", 0)))
		var technique_type := str(_resource_get(raw_technique, "technique_type", "martial_skill"))
		var rolled_affixes := _generate_technique_affixes(technique_affix_pool, technique_type, affix_slots, rng)

		result.append({
			"id": "generated_technique_%d" % result.size(),
			"technique_id": technique_id,
			"display_name": str(_resource_get(raw_technique, "display_name", technique_id)),
			"region_id": str(target_region.get("id", "")),
			"sect_exclusive_id": sect_exclusive_id,
			"element": str(_resource_get(raw_technique, "element", "neutral")),
			"rarity": str(_resource_get(raw_technique, "rarity", "common")),
			"power_level": int(_resource_get(raw_technique, "power_level", 1)),
			"min_realm": int(_resource_get(raw_technique, "min_realm", 0)),
			"affixes": rolled_affixes,
			"source": "catalog",
		})
	return result


func _generate_techniques_from_legacy_methods(regions: Array[Dictionary], rng: RefCounted, cultivation_methods: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if regions.is_empty() or cultivation_methods.is_empty():
		return result

	for method in cultivation_methods:
		var region := regions[_rng_next_int(rng, regions.size())]
		result.append({
			"id": "generated_technique_%d" % result.size(),
			"technique_id": str(method.get("id", "")),
			"display_name": str(method.get("name", "")),
			"region_id": str(region.get("id", "")),
			"sect_exclusive_id": "",
			"element": str(method.get("element", "neutral")),
			"rarity": "common",
			"power_level": int(method.get("power_level", 1)),
			"min_realm": _realm_name_to_index(str(method.get("min_realm", "mortal"))),
			"affixes": [],
			"source": "legacy",
		})
	return result


func generate_items(regions: Array[Dictionary], rng: RefCounted, catalog: Resource) -> Array[Dictionary]:
	var item_resources := _catalog_items(catalog)
	if item_resources.is_empty():
		return _generate_items_fallback(regions, rng)

	var seeds: Array[Dictionary] = []
	for region in regions:
		var spawn_count := maxi(2, int(region.get("resource_count", 1)))
		for _index in range(spawn_count):
			var item_template := item_resources[_rng_next_int(rng, item_resources.size())]
			seeds.append({
				"region_id": str(region.get("id", "")),
				"item_template": item_template,
			})

	var rarity_plan := _build_rarity_plan(seeds.size())
	var result: Array[Dictionary] = []
	for index in range(seeds.size()):
		var seed := seeds[index]
		var template: Resource = seed.get("item_template", null)
		if template == null:
			continue
		var item_id := str(_resource_get(template, "id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var item_type := str(_resource_get(template, "item_type", "material"))
		var affix_slots := maxi(0, int(_resource_get(template, "affix_slots", 0)))
		var item_rarity := rarity_plan[index]
		var affixes := _generate_item_affixes(item_type, affix_slots, item_rarity, rng)
		result.append({
			"id": "generated_item_%d" % result.size(),
			"item_id": item_id,
			"display_name": str(_resource_get(template, "display_name", item_id)),
			"region_id": str(seed.get("region_id", "")),
			"item_type": item_type,
			"rarity": item_rarity,
			"quantity": maxi(1, _rng_next_int(rng, int(_resource_get(template, "stack_size", 1))) + 1),
			"base_value": int(_resource_get(template, "base_value", 0)),
			"element": str(_resource_get(template, "element", "neutral")),
			"affixes": affixes,
			"source": "catalog",
		})
	return result


func _generate_items_fallback(regions: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
	var fallback_items := [
		{"item_id": "generated_spirit_stone", "display_name": "灵石", "item_type": "material", "base_value": 5, "element": "neutral", "affix_slots": 0},
		{"item_id": "generated_herb_bundle", "display_name": "灵草束", "item_type": "material", "base_value": 8, "element": "wood", "affix_slots": 0},
		{"item_id": "generated_iron_blade", "display_name": "玄铁短刃", "item_type": "weapon", "base_value": 20, "element": "neutral", "affix_slots": 1},
	]
	var seeds: Array[Dictionary] = []
	for region in regions:
		for _index in range(maxi(1, int(region.get("resource_count", 1)))):
			seeds.append({
				"region_id": str(region.get("id", "")),
				"item_template": fallback_items[_rng_next_int(rng, fallback_items.size())],
			})

	var rarity_plan := _build_rarity_plan(seeds.size())
	var result: Array[Dictionary] = []
	for index in range(seeds.size()):
		var seed := seeds[index]
		var template: Dictionary = seed.get("item_template", {})
		var item_type := str(template.get("item_type", "material"))
		var item_rarity := rarity_plan[index]
		result.append({
			"id": "generated_item_%d" % result.size(),
			"item_id": str(template.get("item_id", "generated_item")),
			"display_name": str(template.get("display_name", "生成物品")),
			"region_id": str(seed.get("region_id", "")),
			"item_type": item_type,
			"rarity": item_rarity,
			"quantity": _rng_next_int(rng, 3) + 1,
			"base_value": int(template.get("base_value", 1)),
			"element": str(template.get("element", "neutral")),
			"affixes": _generate_item_affixes(item_type, int(template.get("affix_slots", 0)), item_rarity, rng),
			"source": "procedural",
		})
	return result


func generate_loot_assignments(regions: Array[Dictionary], rng: RefCounted, catalog: Resource, items: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var loot_tables := _catalog_loot_tables(catalog)
	if regions.is_empty():
		return result

	if loot_tables.is_empty():
		for region in regions:
			result.append({
				"region_id": str(region.get("id", "")),
				"loot_table_id": "procedural_%s" % str(region.get("id", "")),
				"entries": _build_procedural_loot_entries_for_region(region, items),
				"guaranteed_drops": [],
				"source": "procedural",
			})
		return result

	for region in regions:
		var candidates := _find_matching_loot_tables_for_region(region, loot_tables)
		if candidates.is_empty():
			candidates = loot_tables
		var selected := candidates[_rng_next_int(rng, candidates.size())]
		var table_id := str(_resource_get(selected, "id", ""))
		if table_id.is_empty():
			table_id = "loot_%s" % str(region.get("id", ""))
		result.append({
			"region_id": str(region.get("id", "")),
			"loot_table_id": table_id,
			"entries": _duplicate_array_of_dict(_resource_get(selected, "entries", [])),
			"guaranteed_drops": _duplicate_array_of_dict(_resource_get(selected, "guaranteed_drops", [])),
			"source": "catalog",
		})
	return result


func generate_region_dynamics_init(regions: Array[Dictionary], rng: RefCounted, catalog: Resource, loot_assignments: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	var loot_by_region: Dictionary = {}
	for assignment in loot_assignments:
		var region_id := str(assignment.get("region_id", "")).strip_edges()
		if region_id.is_empty():
			continue
		loot_by_region[region_id] = str(assignment.get("loot_table_id", "")).strip_edges()

	for region in regions:
		var region_id := str(region.get("id", "")).strip_edges()
		if region_id.is_empty():
			continue
		var stockpiles := _build_region_stockpiles(region, rng)
		var production_rates := _build_region_production_rates(stockpiles)
		var controlling_faction_id := str(region.get("controlling_faction_id", "")).strip_edges()
		var population := int(region.get("active_population_hint", 0))
		if population <= 0:
			population = _rng_next_int(rng, 200) + 80
		var danger_level := clampf(float(region.get("monster_count", 0)) * 0.08 + _rng_next_float(rng) * 0.05, 0.0, 1.0)
		result[region_id] = {
			"resource_stockpiles": stockpiles,
			"production_rates": production_rates,
			"controlling_faction_id": controlling_faction_id,
			"faction_modifier": _resolve_faction_modifier(catalog, controlling_faction_id),
			"danger_level": danger_level,
			"population": population,
			"loot_table_id": str(loot_by_region.get(region_id, "")),
		}
	return result


func _build_region_stockpiles(region: Dictionary, rng: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	var resource_tags: Array[String] = _variant_to_string_array(region.get("resource_tags", []))
	for raw_tag in resource_tags:
		var mapped_type := _map_resource_tag_to_stockpile(raw_tag)
		if mapped_type.is_empty():
			continue
		result[mapped_type] = int(result.get(mapped_type, 0)) + _rng_next_int(rng, 70) + 60
	if result.is_empty():
		result["spirit_stone"] = _rng_next_int(rng, 80) + 80
		result["herb"] = _rng_next_int(rng, 60) + 60
	return result


func _build_region_production_rates(stockpiles: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant in stockpiles.keys():
		var key := str(key_variant)
		var base_amount := maxi(1, int(stockpiles[key_variant]))
		result[key] = maxi(2, int(round(float(base_amount) * 0.05)))
	return result


func _resolve_faction_modifier(catalog: Resource, faction_id: String) -> float:
	if faction_id.is_empty():
		return 1.0
	if catalog == null or not catalog.has_method("find_faction"):
		return 1.0
	var faction: Resource = catalog.find_faction(StringName(faction_id))
	if faction == null:
		return 1.0
	var influence := clampf(float(int(_resource_get(faction, "influence", 0))) / 20.0, -10.0, 10.0)
	return clampf(1.0 + influence * 0.05, 0.5, 1.5)


func _find_matching_loot_tables_for_region(region: Dictionary, loot_tables: Array[Resource]) -> Array[Resource]:
	var result: Array[Resource] = []
	var region_tokens: Array[String] = []
	region_tokens.append(str(region.get("type", "")).to_lower())
	region_tokens.append(str(region.get("id", "")).to_lower())
	for tag in _variant_to_string_array(region.get("resource_tags", [])):
		region_tokens.append(tag.to_lower())
	for tag in _variant_to_string_array(region.get("danger_tags", [])):
		region_tokens.append(tag.to_lower())

	for table in loot_tables:
		if table == null:
			continue
		var table_tags := _variant_to_string_array(_resource_get(table, "region_tags", []))
		if table_tags.is_empty():
			result.append(table)
			continue
		for tag in table_tags:
			if region_tokens.has(tag.to_lower()):
				result.append(table)
				break
	return result


func _build_procedural_loot_entries_for_region(region: Dictionary, items: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var region_id := str(region.get("id", ""))
	for item in items:
		if str(item.get("region_id", "")) != region_id:
			continue
		result.append({
			"item_id": str(item.get("item_id", "")),
			"weight": 10,
			"min_rarity": str(item.get("rarity", "common")),
			"max_rarity": str(item.get("rarity", "common")),
			"quantity_range": [1, maxi(1, int(item.get("quantity", 1)))],
		})
		if result.size() >= 5:
			break
	return result


func _pick_technique_regions(regions: Array[Dictionary], sect_exclusive_id: String) -> Array[Dictionary]:
	if sect_exclusive_id.is_empty():
		return regions.duplicate(true)
	var result: Array[Dictionary] = []
	for region in regions:
		if str(region.get("controlling_faction_id", "")).strip_edges() == sect_exclusive_id:
			result.append(region)
	return result


func _generate_technique_affixes(pool: Array[Dictionary], technique_type: String, slot_count: int, rng: RefCounted) -> Array[Dictionary]:
	if slot_count <= 0:
		return []
	var filtered: Array[Dictionary] = []
	for affix in pool:
		var compatible := _variant_to_string_array(affix.get("compatible_types", []))
		if compatible.is_empty() or compatible.has(technique_type):
			filtered.append(affix)
	if filtered.is_empty():
		filtered = pool
	if filtered.is_empty():
		return []

	var result: Array[Dictionary] = []
	for _index in range(slot_count):
		var picked := filtered[_rng_next_int(rng, filtered.size())]
		result.append((picked as Dictionary).duplicate(true))
	return result


func _generate_item_affixes(item_type: String, slot_count: int, target_rarity: String, rng: RefCounted) -> Array[Dictionary]:
	if slot_count <= 0:
		return []
	var source_pool_raw: Variant = ITEM_AFFIX_POOL.get(item_type, DEFAULT_ITEM_AFFIX_POOL)
	var source_pool: Array = source_pool_raw if source_pool_raw is Array else DEFAULT_ITEM_AFFIX_POOL
	if source_pool.is_empty():
		return []

	var result: Array[Dictionary] = []
	for _index in range(slot_count):
		var selected: Variant = source_pool[_rng_next_int(rng, source_pool.size())]
		if not (selected is Dictionary):
			continue
		var affix: Dictionary = (selected as Dictionary).duplicate(true)
		affix["rarity"] = _clamp_rarity_to_target(str(affix.get("rarity", "common")), target_rarity)
		result.append(affix)
	return result


func _clamp_rarity_to_target(input_rarity: String, target_rarity: String) -> String:
	var input_index := _rarity_index(input_rarity)
	var target_index := _rarity_index(target_rarity)
	if input_index > target_index:
		return target_rarity
	return RARITY_ORDER[input_index]


func _build_rarity_plan(total: int) -> Array[String]:
	var result: Array[String] = []
	if total <= 0:
		return result

	var counts := {
		"common": int(round(float(total) * 0.45)),
		"uncommon": int(round(float(total) * 0.25)),
		"rare": int(round(float(total) * 0.15)),
		"epic": int(round(float(total) * 0.08)),
		"legendary": int(round(float(total) * 0.05)),
		"mythic": 0,
	}
	var assigned := int(counts["common"]) + int(counts["uncommon"]) + int(counts["rare"]) + int(counts["epic"]) + int(counts["legendary"])
	counts["mythic"] = maxi(0, total - assigned)

	_adjust_rarity_counts_for_order(counts)

	for rarity in RARITY_ORDER:
		for _index in range(int(counts[rarity])):
			result.append(rarity)

	while result.size() < total:
		result.append("common")
	while result.size() > total:
		result.remove_at(result.size() - 1)
	return result


func _adjust_rarity_counts_for_order(counts: Dictionary) -> void:
	for index in range(RARITY_ORDER.size() - 1):
		var left: String = str(RARITY_ORDER[index])
		var right: String = str(RARITY_ORDER[index + 1])
		var left_count := int(counts.get(left, 0))
		var right_count := int(counts.get(right, 0))
		if left_count < right_count:
			var move := right_count - left_count
			counts[right] = maxi(0, right_count - move)
			counts[left] = left_count + move


func _rarity_index(rarity: String) -> int:
	var idx := RARITY_ORDER.find(rarity)
	if idx == -1:
		return 0
	return idx


func _load_catalog() -> Resource:
	var catalog := load(CATALOG_PATH)
	if catalog is Resource:
		return catalog
	return null


func _catalog_regions(catalog: Resource) -> Array[Resource]:
	if catalog == null:
		return []
	var raw: Variant = catalog.get("regions")
	return _variant_to_resource_array(raw)


func _catalog_items(catalog: Resource) -> Array[Resource]:
	if catalog == null:
		return []
	var raw: Variant = catalog.get("items")
	return _variant_to_resource_array(raw)


func _catalog_techniques(catalog: Resource) -> Array[Resource]:
	if catalog == null:
		return []
	var raw: Variant = catalog.get("techniques")
	return _variant_to_resource_array(raw)


func _catalog_loot_tables(catalog: Resource) -> Array[Resource]:
	if catalog == null:
		return []
	var raw: Variant = catalog.get("loot_tables")
	return _variant_to_resource_array(raw)


func _load_technique_affix_pool() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open("res://resources/world/samples")
	if dir == null:
		return result
	var file_names: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.begins_with("mvp_affix_") or not file_name.ends_with(".tres"):
			continue
		file_names.append(file_name)
	dir.list_dir_end()
	file_names.sort()

	for file_name in file_names:
		var path := "res://resources/world/samples/%s" % file_name
		var affix_resource := load(path)
		if affix_resource == null:
			continue
		result.append({
			"affix_id": str(_resource_get(affix_resource, "affix_id", file_name.trim_suffix(".tres"))),
			"affix_name": str(_resource_get(affix_resource, "affix_name", "未知词条")),
			"affix_category": str(_resource_get(affix_resource, "affix_category", "utility")),
			"effect": _duplicate_dict(_resource_get(affix_resource, "effect", {})),
			"rarity": str(_resource_get(affix_resource, "rarity", "common")),
			"compatible_types": _variant_to_string_array(_resource_get(affix_resource, "compatible_types", [])),
		})
	return result


func _realm_index_to_name(realm_index: int) -> String:
	var table := ["mortal", "qi_condensing", "foundation", "golden_core", "nascent_soul", "spirit_sea"]
	var idx := clampi(realm_index, 0, table.size() - 1)
	return table[idx]


func _realm_name_to_index(realm_name: String) -> int:
	var table := ["mortal", "qi_condensing", "foundation", "golden_core", "nascent_soul", "spirit_sea"]
	var idx := table.find(realm_name)
	if idx == -1:
		return 0
	return idx


func _map_resource_tag_to_stockpile(tag: String) -> String:
	var normalized := tag.to_lower()
	if normalized.find("stone") >= 0 or normalized.find("ore") >= 0 or normalized.find("矿") >= 0:
		return "spirit_stone"
	if normalized.find("herb") >= 0 or normalized.find("grass") >= 0 or normalized.find("wood") >= 0 or normalized.find("药") >= 0:
		return "herb"
	if normalized.find("beast") >= 0 or normalized.find("core") >= 0 or normalized.find("兽") >= 0:
		return "beast_core"
	if normalized.find("water") >= 0 or normalized.find("river") >= 0:
		return "spirit_water"
	return ""


func _variant_to_resource_array(raw: Variant) -> Array[Resource]:
	if not (raw is Array):
		return []
	var result: Array[Resource] = []
	for entry in (raw as Array):
		if entry is Resource:
			result.append(entry)
	return result


func _variant_to_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is PackedStringArray:
		for entry in (raw as PackedStringArray):
			result.append(str(entry))
		return result
	if raw is Array:
		for entry in (raw as Array):
			result.append(str(entry))
		return result
	return result


func _packed_string_array_to_string_array(raw: Variant) -> Array[String]:
	return _variant_to_string_array(raw)


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


func _duplicate_array_of_dict(raw_value: Variant) -> Array[Dictionary]:
	if not (raw_value is Array):
		return []
	var result: Array[Dictionary] = []
	for entry in (raw_value as Array):
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _generate_region_description(region_type: String, region_name: String, rng: RefCounted) -> String:
	var descriptions := {
		"mountain": ["灵气充沛的仙山", "云雾缭绕的险峰", "隐世修仙者的洞天福地"],
		"city": ["繁华的修仙城池", "商贾云集的坊市重镇", "修仙界的交通要冲"],
		"village": ["宁静的凡人村落", "依山傍水的田园聚落", "修仙者与凡人共居之地"],
		"secret_realm": ["上古遗留的秘境", "充满机缘与危险的异空间", "传说中仙人留下的洞府"],
		"wilderness": ["荒无人烟的蛮荒之地", "妖兽横行的危险区域", "灵药遍地的原始森林"],
	}
	var options: Array = descriptions.get(region_type, ["一片未知的土地"])
	return str(options[_rng_next_int(rng, options.size())])


func _rng_next_int(rng: RefCounted, max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	if rng != null and rng.has_method("next_int"):
		return int(rng.next_int(max_exclusive))
	if rng != null and rng.has_method("randi"):
		return int(rng.randi()) % max_exclusive
	return 0


func _rng_next_float(rng: RefCounted) -> float:
	if rng != null and rng.has_method("next_float"):
		return float(rng.next_float())
	if rng != null and rng.has_method("randf"):
		return float(rng.randf())
	return 0.0
