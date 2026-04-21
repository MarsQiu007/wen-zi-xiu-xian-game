extends RefCounted
class_name NpcBehaviorLibrary

const BehaviorAction = preload("res://scripts/data/behavior_action.gd")
const WorldDataCatalog = preload("res://scripts/resources/world_data_catalog.gd")


var BEHAVIOR_DEFS: Dictionary = _build_behavior_defs()
var _custom_behaviors: Array[BehaviorAction] = []


func get_behavior(action_id: StringName) -> BehaviorAction:
	var behavior: BehaviorAction = _find_behavior_in_merged(action_id)
	if behavior == null:
		return BehaviorAction.new()
	return BehaviorAction.from_dict(behavior.to_dict())


func get_behaviors_by_category(category: StringName) -> Array[BehaviorAction]:
	var result: Array[BehaviorAction] = []
	for behavior in _get_merged_behaviors():
		if behavior.category == category:
			result.append(BehaviorAction.from_dict(behavior.to_dict()))
	return result


func get_available_behaviors(npc_state: Dictionary, current_hours: float) -> Array[BehaviorAction]:
	var result: Array[BehaviorAction] = []
	for behavior in _get_merged_behaviors():
		if not _meets_conditions(behavior.conditions, npc_state):
			continue
		if _is_on_cooldown(behavior, npc_state, current_hours):
			continue
		result.append(BehaviorAction.from_dict(behavior.to_dict()))
	return result


func load_custom_behaviors(catalog: WorldDataCatalog) -> void:
	_custom_behaviors.clear()
	if catalog == null:
		return

	var candidates: Array = []
	_append_candidates_from_dynamic_source(candidates, catalog)
	candidates.append_array(_extract_candidates_from_catalog_collections(catalog))

	var dedup: Dictionary = {}
	for candidate in candidates:
		var behavior := _coerce_behavior_action(candidate)
		if behavior.action_id == &"":
			continue
		dedup[behavior.action_id] = behavior

	if dedup.is_empty():
		var fallback_behavior := _build_catalog_fallback_custom_behavior(catalog)
		if fallback_behavior.action_id != &"":
			dedup[fallback_behavior.action_id] = fallback_behavior

	for behavior in dedup.values():
		_custom_behaviors.append(BehaviorAction.from_dict(behavior.to_dict()))


func get_random_behavior(category: StringName, rng: RefCounted) -> BehaviorAction:
	var candidates := get_behaviors_by_category(category)
	if candidates.is_empty():
		return BehaviorAction.new()

	var total_weight := 0.0
	for behavior in candidates:
		total_weight += maxf(behavior.weight, 0.0)

	if total_weight <= 0.0:
		return BehaviorAction.from_dict(candidates[0].to_dict())

	var roll := _rng_randf(rng) * total_weight
	var cumulative := 0.0
	for behavior in candidates:
		cumulative += maxf(behavior.weight, 0.0)
		if roll <= cumulative:
			return BehaviorAction.from_dict(behavior.to_dict())

	return BehaviorAction.from_dict(candidates.back().to_dict())


func _is_on_cooldown(behavior: BehaviorAction, npc_state: Dictionary, current_hours: float) -> bool:
	if behavior.cooldown_hours <= 0.0:
		return false

	var last_action_hours := npc_state.get("last_action_hours", {}) as Dictionary
	var has_time := false
	var last_time := 0.0

	if last_action_hours.has(behavior.action_id):
		has_time = true
		last_time = float(last_action_hours.get(behavior.action_id, 0.0))
	elif last_action_hours.has(String(behavior.action_id)):
		has_time = true
		last_time = float(last_action_hours.get(String(behavior.action_id), 0.0))

	if not has_time:
		return false

	return (current_hours - last_time) < behavior.cooldown_hours


func _meets_conditions(conditions: Dictionary, npc_state: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	var realm := StringName(str(npc_state.get("realm", "")))
	var realm_progress := float(npc_state.get("realm_progress", 0.0))
	var has_technique := bool(npc_state.get("has_technique", false))
	var pressures := npc_state.get("pressures", {}) as Dictionary

	var any_of = conditions.get("any_of", [])
	if any_of is Array and not (any_of as Array).is_empty():
		var matched_any := false
		for child_condition in any_of:
			if child_condition is Dictionary and _meets_conditions(child_condition as Dictionary, npc_state):
				matched_any = true
				break
		if not matched_any:
			return false

	var all_of = conditions.get("all_of", [])
	if all_of is Array and not (all_of as Array).is_empty():
		for child_condition in all_of:
			if child_condition is Dictionary and not _meets_conditions(child_condition as Dictionary, npc_state):
				return false

	for key in conditions.keys():
		var value = conditions[key]
		match StringName(key):
			&"any_of", &"all_of":
				pass
			&"has_technique":
				if has_technique != bool(value):
					return false
			&"has_region_resource", &"has_gold", &"has_consumable", &"has_technique_opportunity", &"has_grudge", &"own_territory_threatened", &"faction_strong", &"adjacent_unclaimed", &"faction_vs_rival_in_region":
				if bool(npc_state.get(String(key), false)) != bool(value):
					return false
			&"need_resource_min":
				if _get_pressure_value(pressures, "resource") < float(value):
					return false
			&"need_survival_min":
				if _get_pressure_value(pressures, "survival") < float(value):
					return false
			&"need_reputation_min":
				if _get_pressure_value(pressures, "reputation") < float(value):
					return false
			&"need_belonging_min":
				if _get_pressure_value(pressures, "belonging") < float(value):
					return false
			&"min_realm_progress":
				if realm_progress < float(value):
					return false
			&"realm":
				if realm != StringName(str(value)):
					return false
			&"realms":
				if value is Array:
					if not value.has(realm) and not value.has(String(realm)):
						return false
			_:
				pass

	return true


func _get_pressure_value(pressures: Dictionary, key: String) -> float:
	return float(pressures.get(key, pressures.get(StringName(key), 0.0)))


func _append_candidates_from_dynamic_source(candidates: Array, source) -> void:
	if source == null:
		return

	if source.has_method("get"):
		var field_names: PackedStringArray = ["custom_behaviors", "npc_behaviors", "behavior_definitions", "behavior_defs"]
		for field_name in field_names:
			var field_data = source.get(field_name)
			if field_data is Array:
				candidates.append_array(field_data)

	if source is Object:
		var object_source: Object = source
		if object_source.has_meta("custom_behaviors"):
			var meta_data = object_source.get_meta("custom_behaviors")
			if meta_data is Array:
				candidates.append_array(meta_data)
		if object_source.has_meta("npc_behaviors"):
			var npc_meta_data = object_source.get_meta("npc_behaviors")
			if npc_meta_data is Array:
				candidates.append_array(npc_meta_data)

	if source.has_method("get_custom_behaviors"):
		var method_result = source.call("get_custom_behaviors")
		if method_result is Array:
			candidates.append_array(method_result)
	if source.has_method("get_npc_behaviors"):
		var npc_method_result = source.call("get_npc_behaviors")
		if npc_method_result is Array:
			candidates.append_array(npc_method_result)


func _extract_candidates_from_catalog_collections(catalog: WorldDataCatalog) -> Array:
	var candidates: Array = []
	var collections: Array = [
		catalog.characters,
		catalog.families,
		catalog.factions,
		catalog.regions,
		catalog.event_templates,
		catalog.doctrines,
		catalog.deities,
		catalog.items,
		catalog.techniques,
		catalog.get_crafting_recipes(),
		catalog.loot_tables,
	]
	for collection in collections:
		if not (collection is Array):
			continue
		for entry in collection:
			_append_candidates_from_dynamic_source(candidates, entry)
	return candidates


func _build_catalog_fallback_custom_behavior(catalog: WorldDataCatalog) -> BehaviorAction:
	var has_catalog_payload := not catalog.items.is_empty()
	has_catalog_payload = has_catalog_payload or not catalog.techniques.is_empty()
	has_catalog_payload = has_catalog_payload or not catalog.get_crafting_recipes().is_empty()
	has_catalog_payload = has_catalog_payload or not catalog.loot_tables.is_empty()
	if not has_catalog_payload:
		return BehaviorAction.new()

	var fallback := _make_behavior(
		&"catalog_exchange_goods",
		"目录物资调配",
		&"survival",
		{"resource": 2, "learning": -1, "reputation": 1},
		{"merchant": 1},
		{},
		2.6,
		"根据世界目录中的物资与配方情报安排补给调配，作为数据驱动迁移期的兜底行为。",
		8.0
	)
	return fallback


func _coerce_behavior_action(raw_data) -> BehaviorAction:
	if raw_data is BehaviorAction:
		return BehaviorAction.from_dict((raw_data as BehaviorAction).to_dict())

	if raw_data is Dictionary:
		return BehaviorAction.from_dict(_normalize_behavior_dict(raw_data as Dictionary))

	if raw_data is Resource or raw_data is RefCounted:
		if raw_data.has_method("to_dict"):
			var serialized = raw_data.call("to_dict")
			if serialized is Dictionary:
				return BehaviorAction.from_dict(_normalize_behavior_dict(serialized as Dictionary))
		if raw_data.has_method("get"):
			var dict_candidate := {
				"snapshot_version": BehaviorAction.SNAPSHOT_VERSION,
				"action_id": str(raw_data.get("action_id", "")),
				"label": str(raw_data.get("label", "")),
				"category": str(raw_data.get("category", "")),
				"pressure_deltas": raw_data.get("pressure_deltas", {}),
				"favor_deltas": raw_data.get("favor_deltas", {}),
				"conditions": raw_data.get("conditions", {}),
				"weight": float(raw_data.get("weight", 1.0)),
				"description": str(raw_data.get("description", "")),
				"cooldown_hours": float(raw_data.get("cooldown_hours", 0.0)),
			}
			return BehaviorAction.from_dict(_normalize_behavior_dict(dict_candidate))

	return BehaviorAction.new()


func _normalize_behavior_dict(source: Dictionary) -> Dictionary:
	var normalized := {
		"snapshot_version": int(source.get("snapshot_version", BehaviorAction.SNAPSHOT_VERSION)),
		"action_id": str(source.get("action_id", "")),
		"label": str(source.get("label", "")),
		"category": str(source.get("category", "")),
		"pressure_deltas": (source.get("pressure_deltas", {}) as Dictionary).duplicate(true),
		"favor_deltas": (source.get("favor_deltas", {}) as Dictionary).duplicate(true),
		"conditions": (source.get("conditions", {}) as Dictionary).duplicate(true),
		"weight": float(source.get("weight", 1.0)),
		"description": str(source.get("description", "")),
		"cooldown_hours": float(source.get("cooldown_hours", 0.0)),
	}
	if normalized["snapshot_version"] != BehaviorAction.SNAPSHOT_VERSION:
		normalized["snapshot_version"] = BehaviorAction.SNAPSHOT_VERSION
	return normalized


func _get_merged_behaviors() -> Array[BehaviorAction]:
	var merged: Array[BehaviorAction] = []
	var custom_map: Dictionary = {}
	for behavior in _custom_behaviors:
		custom_map[behavior.action_id] = behavior

	for behavior in BEHAVIOR_DEFS.values():
		if custom_map.has(behavior.action_id):
			merged.append(BehaviorAction.from_dict((custom_map[behavior.action_id] as BehaviorAction).to_dict()))
			custom_map.erase(behavior.action_id)
		else:
			merged.append(BehaviorAction.from_dict(behavior.to_dict()))

	for behavior in custom_map.values():
		merged.append(BehaviorAction.from_dict((behavior as BehaviorAction).to_dict()))

	return merged


func _find_behavior_in_merged(action_id: StringName) -> BehaviorAction:
	for behavior in _get_merged_behaviors():
		if behavior.action_id == action_id:
			return behavior
	return null


func _rng_randf(rng: RefCounted) -> float:
	if rng != null and rng.has_method("randf"):
		return float(rng.call("randf"))
	if rng != null and rng.has_method("randf_range"):
		return float(rng.call("randf_range", 0.0, 1.0))
	return randf()


func _make_behavior(
		action_id: StringName,
		label: String,
		category: StringName,
		pressure_deltas: Dictionary,
		favor_deltas: Dictionary,
		conditions: Dictionary,
		weight: float,
		description: String,
		cooldown_hours: float
	) -> BehaviorAction:
	var behavior := BehaviorAction.new()
	behavior.action_id = action_id
	behavior.label = label
	behavior.category = category
	behavior.pressure_deltas = pressure_deltas.duplicate(true)
	behavior.favor_deltas = favor_deltas.duplicate(true)
	behavior.conditions = conditions.duplicate(true)
	behavior.weight = weight
	behavior.description = description
	behavior.cooldown_hours = cooldown_hours
	return behavior


func _build_behavior_defs() -> Dictionary:
	return {
		# survival (8)
		&"work_for_food": _make_behavior(
			&"work_for_food", "外出讨生活", &"survival",
			{"survival": -3, "resource": 2, "reputation": 1}, {}, {}, 4.5,
			"为换取口粮外出劳作，先稳住生计再图后路。", 6.0
		),
		&"gather_herbs": _make_behavior(
			&"gather_herbs", "采集草药", &"survival",
			{"survival": -2, "resource": 2, "learning": 1}, {}, {}, 3.6,
			"进山识草采药，既能补给也能增长见识。", 10.0
		),
		&"hunt_game": _make_behavior(
			&"hunt_game", "狩猎", &"survival",
			{"survival": -3, "resource": 3, "reputation": 1}, {}, {"min_realm_progress": 15.0}, 3.2,
			"追踪野兽获取肉食与皮货，但需要一定体魄与胆气。", 18.0
		),
		&"rest_at_home": _make_behavior(
			&"rest_at_home", "居家休养", &"survival",
			{"survival": -2, "belonging": 1, "cultivation": -1}, {"family": 2}, {}, 3.8,
			"留在家中调养身心，减少外界风险。", 4.0
		),
		&"trade_goods": _make_behavior(
			&"trade_goods", "市集交易", &"survival",
			{"resource": 3, "reputation": 1, "survival": -1}, {"merchant": 2}, {}, 3.4,
			"携带物资去集市互通有无，补足短缺。", 12.0
		),
		&"forage_wild": _make_behavior(
			&"forage_wild", "野外觅食", &"survival",
			{"survival": -2, "resource": 1, "learning": 1}, {}, {}, 2.8,
			"在山林河畔寻找可食之物，勉强渡过眼前难关。", 8.0
		),
		&"seek_shelter": _make_behavior(
			&"seek_shelter", "寻找庇护", &"survival",
			{"survival": -2, "belonging": 1, "reputation": -1}, {"family": 1}, {}, 2.5,
			"向可信势力寻求暂时庇护，以避风头。", 24.0
		),
		&"beg_alms": _make_behavior(
			&"beg_alms", "沿街乞讨", &"survival",
			{"survival": -1, "resource": 1, "reputation": -2}, {"stranger": -1}, {}, 1.6,
			"放下体面求得一口饭，代价是名声受损。", 6.0
		),

		# social (11)
		&"chat_with_neighbor": _make_behavior(
			&"chat_with_neighbor", "与邻里闲聊", &"social",
			{"belonging": -2, "reputation": 1, "learning": 1}, {"neighbor": 2, "friend": 1}, {}, 4.2,
			"与街坊交流近况，维持人情网络。", 3.0
		),
		&"seek_mentor_guidance": _make_behavior(
			&"seek_mentor_guidance", "向师长请教", &"social",
			{"learning": -2, "cultivation": -1, "belonging": -1}, {"mentor": 3}, {}, 3.6,
			"向阅历更深者求教，借他山之石攻玉。", 12.0
		),
		&"visit_friend": _make_behavior(
			&"visit_friend", "拜访友人", &"social",
			{"belonging": -2, "reputation": 1, "survival": -1}, {"friend": 3}, {}, 3.9,
			"登门探望旧友，巩固彼此信任。", 8.0
		),
		&"attend_gathering": _make_behavior(
			&"attend_gathering", "参加集会", &"social",
			{"belonging": -2, "reputation": 2, "resource": -1}, {"friend": 1, "mentor": 1}, {}, 3.1,
			"在集会中交换消息与立场，拓展人脉。", 18.0
		),
		&"exchange_gifts": _make_behavior(
			&"exchange_gifts", "互赠礼物", &"social",
			{"belonging": -1, "reputation": 1, "resource": -2}, {"friend": 2, "family": 2}, {}, 2.7,
			"以礼相待能增进关系，但会消耗手头物资。", 24.0
		),
		&"resolve_dispute": _make_behavior(
			&"resolve_dispute", "调解纠纷", &"social",
			{"reputation": 2, "belonging": -1, "learning": 1}, {"neighbor": 2, "friend": 1}, {"min_realm_progress": 20.0}, 2.4,
			"出面调停矛盾，既考验威望也考验分寸。", 20.0
		),
		&"spread_rumor": _make_behavior(
			&"spread_rumor", "散布流言", &"social",
			{"reputation": -2, "belonging": -1, "resource": 1}, {"friend": -2, "mentor": -1}, {}, 1.4,
			"刻意放出风声以搅动局势，短利伴随长险。", 14.0
		),
		&"form_alliance": _make_behavior(
			&"form_alliance", "结盟", &"social",
			{"reputation": 2, "belonging": -1, "resource": 1}, {"friend": 3, "mentor": 1}, {"min_realm_progress": 35.0}, 2.2,
			"与志同道合者定下互助约定，共担风险共取收益。", 36.0
		),
		&"betray_trust": _make_behavior(
			&"betray_trust", "背叛信任", &"social",
			{"resource": 2, "reputation": -3, "belonging": 2}, {"friend": -4, "mentor": -3, "family": -2}, {}, 1.0,
			"短期获利来自背信弃义，后续报复难以避免。", 72.0
		),
		&"host_feast": _make_behavior(
			&"host_feast", "设宴款待", &"social",
			{"reputation": 2, "belonging": -2, "resource": -3}, {"friend": 2, "family": 1, "mentor": 1}, {"min_realm_progress": 30.0}, 1.8,
			"设宴广邀宾客，以资源换取声望与情面。", 48.0
		),
		&"seek_disciple": _make_behavior(
			&"seek_disciple", "收徒传道", &"social",
			{"reputation": 2, "learning": -1, "cultivation": 1}, {"disciple": 3, "mentor": 1}, {"min_realm_progress": 80.0}, 1.3,
			"物色可塑之才，传授经验并建立传承关系。", 96.0
		),

		# cultivation (8)
		&"meditate": _make_behavior(
			&"meditate", "静坐冥想", &"cultivation",
			{"cultivation": -3, "learning": -1, "survival": 1}, {}, {}, 4.8,
			"收敛心神吐纳周天，稳步积累修行底子。", 4.0
		),
		&"practice_technique": _make_behavior(
			&"practice_technique", "修炼功法", &"cultivation",
			{"cultivation": -3, "learning": -1, "resource": -1}, {}, {"has_technique": true}, 4.4,
			"按功法运转灵力，提升境界掌控力。", 8.0
		),
		&"breakthrough_attempt": _make_behavior(
			&"breakthrough_attempt", "尝试突破", &"cultivation",
			{"cultivation": -4, "survival": 2, "reputation": 1}, {}, {"min_realm_progress": 90.0}, 1.7,
			"在关隘处强行冲关，成功与反噬并存。", 72.0
		),
		&"study_scroll": _make_behavior(
			&"study_scroll", "研读典籍", &"cultivation",
			{"learning": -3, "cultivation": -1, "resource": -1}, {}, {}, 3.7,
			"研习卷轴心得，补齐理论与术法细节。", 10.0
		),
		&"refine_pill": _make_behavior(
			&"refine_pill", "炼丹", &"cultivation",
			{"resource": -2, "cultivation": -2, "learning": -1}, {}, {"has_technique": true, "min_realm_progress": 40.0}, 2.3,
			"调和药性炼制丹丸，以消耗换取后续潜力。", 36.0
		),
		&"forge_weapon": _make_behavior(
			&"forge_weapon", "锻造法器", &"cultivation",
			{"resource": -2, "cultivation": -1, "reputation": 1}, {}, {"min_realm_progress": 30.0}, 2.1,
			"淬火锻材凝炼器胚，提升实战底牌。", 48.0
		),
		&"absorb_spirit": _make_behavior(
			&"absorb_spirit", "吸纳灵气", &"cultivation",
			{"cultivation": -2, "survival": 1, "resource": -1}, {}, {"min_realm_progress": 20.0}, 3.5,
			"借灵脉或灵地汲取灵气，快速补充修行所需。", 12.0
		),
		&"purify_body": _make_behavior(
			&"purify_body", "淬体", &"cultivation",
			{"cultivation": -2, "survival": 1, "resource": -1}, {}, {"has_technique": true}, 2.9,
			"以灵力洗练筋骨血脉，夯实承载上限。", 20.0
		),
		&"learn_technique": _make_behavior(
			&"learn_technique", "学习功法", &"cultivation",
			{"learning": -2, "reputation": -2, "resource": -1}, {"mentor": 1},
			{"has_technique_opportunity": true, "need_reputation_min": 35.0}, 3.3,
			"抓住机缘习得新功法，提升后续修行与战斗上限。", 24.0
		),
		&"meditate_affix": _make_behavior(
			&"meditate_affix", "参悟词条", &"cultivation",
			{"learning": -1, "reputation": -3, "resource": -2}, {"mentor": 1},
			{"has_technique": true, "has_gold": true, "need_reputation_min": 50.0}, 2.0,
			"投入灵石反复参悟功法细节，尝试打磨更契合的词条效果。", 36.0
		),

		# exploration (6)
		&"scout_area": _make_behavior(
			&"scout_area", "侦察周边", &"exploration",
			{"learning": -1, "resource": 1, "survival": 1}, {}, {}, 3.8,
			"踏查附近地形与势力动向，降低未知风险。", 6.0
		),
		&"enter_dungeon": _make_behavior(
			&"enter_dungeon", "探索秘境", &"exploration",
			{"resource": 2, "learning": -1, "survival": 2}, {}, {"min_realm_progress": 45.0}, 1.9,
			"深入秘境寻机缘，回报可观但危险同样陡增。", 60.0
		),
		&"search_ruins": _make_behavior(
			&"search_ruins", "搜寻遗迹", &"exploration",
			{"learning": -2, "resource": 2, "survival": 1}, {}, {"min_realm_progress": 35.0}, 2.4,
			"在废墟残阵中寻找可用线索与遗留资源。", 30.0
		),
		&"map_territory": _make_behavior(
			&"map_territory", "绘制地图", &"exploration",
			{"learning": -1, "resource": 1, "reputation": 1}, {}, {}, 2.7,
			"整理路径与地貌信息，为后续行动铺路。", 16.0
		),
		&"investigate_anomaly": _make_behavior(
			&"investigate_anomaly", "调查异象", &"exploration",
			{"learning": -2, "cultivation": -1, "survival": 2}, {}, {"min_realm_progress": 50.0}, 1.6,
			"追查灵力波动与异常天象，常伴不可预见事件。", 42.0
		),
		&"gather_intel": _make_behavior(
			&"gather_intel", "收集情报", &"exploration",
			{"learning": -1, "reputation": 1, "resource": 1}, {"neighbor": 1, "friend": 1}, {}, 3.0,
			"从多方渠道拼接情报，提早发现机会与威胁。", 10.0
		),
		&"gather_resource": _make_behavior(
			&"gather_resource", "采集区域资源", &"survival",
			{"resource": 3, "survival": -2, "learning": 1}, {"ally": 1},
			{"has_region_resource": true, "need_resource_min": 45.0}, 3.9,
			"在当前区域采集可用资源，缓解物资压力并补充库存。", 10.0
		),
		&"trade_item": _make_behavior(
			&"trade_item", "交易物品", &"survival",
			{"resource": 2, "reputation": 1, "belonging": -1}, {"merchant": 2, "friend": 1},
			{"has_gold": true, "need_resource_min": 35.0}, 3.2,
			"用手头灵石与人互通有无，以较低风险补全急需物资。", 14.0
		),
		&"use_consumable": _make_behavior(
			&"use_consumable", "使用消耗品", &"survival",
			{"survival": -3, "resource": -1, "cultivation": -1}, {},
			{"has_consumable": true, "need_survival_min": 40.0}, 3.6,
			"在状态不稳时优先使用消耗品，快速恢复并避免风险扩大。", 4.0
		),

		# conflict (8)
		&"challenge_duel": _make_behavior(
			&"challenge_duel", "发起决斗", &"conflict",
			{"reputation": 2, "survival": 2, "cultivation": -1}, {"rival": -2}, {"min_realm_progress": 30.0}, 2.2,
			"公开邀战证明实力，胜负都会带来名声波动。", 36.0
		),
		&"ambush_enemy": _make_behavior(
			&"ambush_enemy", "伏击敌人", &"conflict",
			{"resource": 2, "reputation": -1, "survival": 2}, {"rival": -3}, {"min_realm_progress": 40.0}, 1.5,
			"利用地形先发制人，追求速胜但风险极高。", 48.0
		),
		&"defend_territory": _make_behavior(
			&"defend_territory", "守卫领地", &"conflict",
			{"belonging": -1, "reputation": 2, "survival": 1}, {"family": 1, "friend": 1}, {}, 2.8,
			"驻守要地抵御侵扰，维护自身与同伴利益。", 20.0
		),
		&"raid_resource": _make_behavior(
			&"raid_resource", "抢夺资源", &"conflict",
			{"resource": 3, "reputation": -2, "survival": 2}, {"rival": -2, "friend": -1}, {"min_realm_progress": 45.0}, 1.3,
			"主动袭取对手补给，收益高但仇恨累积明显。", 60.0
		),
		&"assassinate": _make_behavior(
			&"assassinate", "暗杀", &"conflict",
			{"resource": 1, "reputation": -3, "survival": 3}, {"rival": -4, "mentor": -1}, {"has_technique": true, "min_realm_progress": 60.0}, 1.0,
			"潜行伏杀关键目标，成败都可能改写局势。", 96.0
		),
		&"negotiate_truce": _make_behavior(
			&"negotiate_truce", "谈判停战", &"conflict",
			{"reputation": 1, "belonging": -1, "resource": -1}, {"rival": 1, "friend": 1}, {}, 2.0,
			"通过让步与交换换取暂时和平，争取恢复时间。", 30.0
		),
		&"join_battle": _make_behavior(
			&"join_battle", "加入战斗", &"conflict",
			{"reputation": 2, "survival": 2, "cultivation": -1}, {"ally": 2, "rival": -2}, {"min_realm_progress": 25.0}, 2.6,
			"响应战局站队参战，以实力争取更高话语权。", 24.0
		),
		&"flee_conflict": _make_behavior(
			&"flee_conflict", "逃离冲突", &"conflict",
			{"survival": -2, "reputation": -1, "belonging": 1}, {"family": 1}, {}, 2.9,
			"暂避锋芒保存实力，等待更有利时机。", 12.0
		),
		&"challenge_npc": _make_behavior(
			&"challenge_npc", "挑战NPC", &"conflict",
			{"reputation": 2, "resource": 2, "survival": 2}, {"rival": -3, "enemy": -2},
			{"any_of": [{"has_grudge": true}, {"need_resource_min": 55.0}], "need_reputation_min": 25.0, "min_realm_progress": 20.0}, 2.5,
			"因旧怨或资源压力主动邀战，通过战斗解决矛盾并争取利益。", 28.0
		),
		&"expand_territory": _make_behavior(
			&"expand_territory", "扩张领地", &"conflict",
			{"belonging": -3, "reputation": 2, "resource": 1, "survival": 2}, {"ally": 2, "rival": -2},
			{"faction_strong": true, "adjacent_unclaimed": true, "need_belonging_min": 50.0, "min_realm_progress": 35.0}, 1.7,
			"在势力强盛且边境有空缺时推进扩张，提升阵营控制范围。", 72.0
		),
		&"contest_region": _make_behavior(
			&"contest_region", "争夺区域", &"conflict",
			{"belonging": -2, "reputation": 2, "resource": 1, "survival": 2}, {"ally": 1, "rival": -3},
			{"faction_vs_rival_in_region": true, "need_belonging_min": 45.0, "min_realm_progress": 30.0}, 2.1,
			"在敌对势力交界区域发起争夺，力求改变领地归属。", 54.0
		),
	}
