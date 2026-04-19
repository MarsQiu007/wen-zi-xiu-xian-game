extends RefCounted
class_name WorldGenerator

const SeededRandomScript = preload("res://scripts/sim/seeded_random.gd")
const NameGeneratorScript = preload("res://scripts/world/name_generator.gd")


func generate(seed_data: Resource) -> Dictionary:
	var rng: RefCounted = SeededRandomScript.new()
	rng.set_seed(int(seed_data.seed_value))

	var regions := generate_regions(seed_data, rng)
	var characters := generate_characters(seed_data, regions, rng)
	var relationships := generate_relationships(characters, rng)
	var resources := generate_resources(regions, rng)
	var monsters := generate_monsters(regions, rng)
	var cultivation_methods := generate_cultivation_methods(rng)

	return {
		"regions": regions,
		"characters": characters,
		"relationships": relationships,
		"resources": resources,
		"monsters": monsters,
		"cultivation_methods": cultivation_methods,
		"seed": int(seed_data.seed_value),
	}


func generate_regions(seed_data: Resource, rng: RefCounted) -> Array[Dictionary]:
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


func generate_characters(seed_data: Resource, regions: Array[Dictionary], rng: RefCounted) -> Array[Dictionary]:
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


func generate_cultivation_methods(rng: RefCounted) -> Array[Dictionary]:
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
