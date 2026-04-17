extends RefCounted

class_name DeityModeRuntime

const FAITH_TIER_RULES := {
	"shallow_believer": {
		"label": "浅信者",
		"faith_per_follower": 1,
		"priority": 0,
	},
	"believer": {
		"label": "笃信者",
		"faith_per_follower": 2,
		"priority": 1,
	},
	"fervent_believer": {
		"label": "虔狂信众",
		"faith_per_follower": 4,
		"priority": 2,
	},
}

func build_initial_state(catalog: Resource, runtime_characters: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	if catalog == null:
		return {}
	var deity: Resource = _pick_deity(catalog, options)
	if deity == null:
		return {}
	var doctrine: Resource = _pick_doctrine(catalog, deity, options)
	var follower_state := _build_follower_state(runtime_characters, deity, doctrine)
	var deity_name := str(deity.get("display_name"))
	var domain_tags: PackedStringArray = deity.get("domain_tags")
	var worship_style_tags: PackedStringArray = deity.get("worship_style_tags")
	return {
		"deity": {
			"id": str(deity.get("id")),
			"display_name": deity_name,
			"deity_type": str(deity.get("deity_type")),
			"domain_tags": domain_tags,
			"worship_style_tags": worship_style_tags,
			"manifestation_tags": deity.get("manifestation_tags"),
			"faith_income_hint": int(deity.get("faith_income_hint")),
		},
		"doctrine": {
			"id": str(doctrine.get("id")) if doctrine != null else "",
			"display_name": str(doctrine.get("display_name")) if doctrine != null else "无教义",
			"doctrine_type": str(doctrine.get("doctrine_type")) if doctrine != null else "",
			"core_tenets": doctrine.get("core_tenets") if doctrine != null else PackedStringArray(),
			"support_tags": doctrine.get("support_tags") if doctrine != null else PackedStringArray(),
		},
		"faith": {
			"current": int(options.get("starting_faith", 6)),
			"generated_total": 0,
			"spent_total": 0,
		},
		"follower_tiers": follower_state.get("tiers", {}),
		"tier_order": ["shallow_believer", "believer", "fervent_believer"],
		"favored_intervention": _pick_favored_intervention(domain_tags, worship_style_tags),
		"favored_target_tier": _pick_favored_target_tier(domain_tags, worship_style_tags),
		"intervention_cycle": _build_intervention_cycle(domain_tags, worship_style_tags),
		"last_income": {},
		"last_intervention": {},
		"history": [
			{
				"day": 0,
				"kind": "opening",
				"summary": "%s 以%s为核心维持神明模式。" % [deity_name, str(follower_state.get("summary", "稳定供奉"))],
			}
		],
	}


func advance_day(runtime: Dictionary, simulated_day: int) -> Dictionary:
	if runtime.is_empty():
		return {
			"runtime": runtime,
			"income": {},
			"intervention": {},
		}
	var resolved_runtime := runtime.duplicate(true)
	var income := _resolve_faith_income(resolved_runtime, simulated_day)
	var intervention := _resolve_intervention(resolved_runtime, simulated_day)
	resolved_runtime["last_income"] = income
	resolved_runtime["last_intervention"] = intervention
	var history: Array = resolved_runtime.get("history", [])
	history.append({
		"day": simulated_day,
		"kind": "daily_resolution",
		"income_total": int(income.get("total_gain", 0)),
		"intervention_id": str(intervention.get("id", "none")),
	})
	resolved_runtime["history"] = history
	return {
		"runtime": resolved_runtime,
		"income": income,
		"intervention": intervention,
	}


func _pick_deity(catalog: Resource, options: Dictionary) -> Resource:
	var requested_id := StringName(str(options.get("deity_id", "")))
	if requested_id != StringName("") and catalog.has_method("find_deity"):
		var selected: Resource = catalog.find_deity(requested_id)
		if selected != null:
			return selected
	var deities: Array = catalog.get("deities")
	for deity in deities:
		if deity != null:
			return deity
	return null


func _pick_doctrine(catalog: Resource, deity: Resource, options: Dictionary) -> Resource:
	var requested_id := StringName(str(options.get("doctrine_id", "")))
	if requested_id != StringName("") and catalog.has_method("find_doctrine"):
		var requested: Resource = catalog.find_doctrine(requested_id)
		if requested != null:
			return requested
	if deity != null:
		var preferred_id: StringName = deity.get("preferred_doctrine_id")
		if preferred_id != StringName("") and catalog.has_method("find_doctrine"):
			var preferred: Resource = catalog.find_doctrine(preferred_id)
			if preferred != null:
				return preferred
	var doctrines: Array = catalog.get("doctrines")
	for doctrine in doctrines:
		if doctrine != null:
			return doctrine
	return null


func _build_follower_state(runtime_characters: Array[Dictionary], deity: Resource, doctrine: Resource) -> Dictionary:
	var deity_faction_id := ""
	if doctrine != null:
		deity_faction_id = str(doctrine.get("associated_faction_id"))
	var tiers := {
		"shallow_believer": _make_tier_state("shallow_believer"),
		"believer": _make_tier_state("believer"),
		"fervent_believer": _make_tier_state("fervent_believer"),
	}
	for character in runtime_characters:
		var tier_id := _determine_follower_tier(character, deity_faction_id)
		var tier_state: Dictionary = tiers.get(tier_id, {}).duplicate(true)
		tier_state["count"] = int(tier_state.get("count", 0)) + 1
		var sample_names: PackedStringArray = tier_state.get("sample_names", PackedStringArray())
		if sample_names.size() < 3:
			sample_names.append(str(character.get("display_name", "无名氏")))
		tier_state["sample_names"] = sample_names
		tiers[tier_id] = tier_state
	_ensure_minimum_tier_counts(tiers, deity, doctrine, runtime_characters.size())
	var summary_parts: Array[String] = []
	for tier_id in ["shallow_believer", "believer", "fervent_believer"]:
		var tier_info: Dictionary = tiers.get(tier_id, {})
		summary_parts.append("%s %d 人" % [str(tier_info.get("label", tier_id)), int(tier_info.get("count", 0))])
	return {
		"tiers": tiers,
		"summary": "、".join(summary_parts),
	}


func _make_tier_state(tier_id: String) -> Dictionary:
	var rule: Dictionary = FAITH_TIER_RULES.get(tier_id, {})
	return {
		"id": tier_id,
		"label": str(rule.get("label", tier_id)),
		"faith_per_follower": int(rule.get("faith_per_follower", 1)),
		"priority": int(rule.get("priority", 0)),
		"count": 0,
		"sample_names": PackedStringArray(),
	}


func _determine_follower_tier(character: Dictionary, deity_faction_id: String) -> String:
	var affinity := int(character.get("faith_affinity", 0))
	var tags: PackedStringArray = character.get("tags", PackedStringArray())
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var faction_id := str(character.get("faction_id", ""))
	if affinity >= 5 or tags.has("visionary") or role_tags.has("future_devotee"):
		return "fervent_believer"
	if affinity >= 3 or faction_id == deity_faction_id or tags.has("ritual_focused"):
		return "believer"
	return "shallow_believer"


func _ensure_minimum_tier_counts(tiers: Dictionary, deity: Resource, doctrine: Resource, character_count: int) -> void:
	var base_total := maxi(3, character_count)
	var deity_hint := int(deity.get("faith_income_hint")) if deity != null else 0
	var doctrine_strength := 0
	if doctrine != null:
		doctrine_strength = (doctrine.get("core_tenets") as PackedStringArray).size()
	var shallow_target := maxi(1, 1 + base_total / 2)
	var believer_target := maxi(1, 1 + deity_hint)
	var fervent_target := maxi(1, 1 + mini(2, doctrine_strength / 2))
	_apply_tier_minimum(tiers, "shallow_believer", shallow_target)
	_apply_tier_minimum(tiers, "believer", believer_target)
	_apply_tier_minimum(tiers, "fervent_believer", fervent_target)


func _apply_tier_minimum(tiers: Dictionary, tier_id: String, minimum_count: int) -> void:
	var tier_state: Dictionary = tiers.get(tier_id, {}).duplicate(true)
	tier_state["count"] = maxi(int(tier_state.get("count", 0)), minimum_count)
	var sample_names: PackedStringArray = tier_state.get("sample_names", PackedStringArray())
	if sample_names.is_empty():
		sample_names.append(str(tier_state.get("label", tier_id)))
	tier_state["sample_names"] = sample_names
	tiers[tier_id] = tier_state


func _pick_favored_intervention(domain_tags: PackedStringArray, worship_style_tags: PackedStringArray) -> String:
	var intervention_library := _build_intervention_library()
	var best_id := "blessing"
	var best_score := -999
	for intervention_id in intervention_library.keys():
		var config: Dictionary = intervention_library[intervention_id]
		var score := 0
		for domain_tag in config.get("preferred_domains", PackedStringArray()):
			if domain_tags.has(domain_tag):
				score += 2
		for style_tag in config.get("preferred_styles", PackedStringArray()):
			if worship_style_tags.has(style_tag):
				score += 1
		if score > best_score:
			best_score = score
			best_id = str(intervention_id)
	return best_id


func _pick_favored_target_tier(domain_tags: PackedStringArray, worship_style_tags: PackedStringArray) -> String:
	if domain_tags.has("omens") or worship_style_tags.has("night_ritual"):
		return "fervent_believer"
	if domain_tags.has("harvest"):
		return "shallow_believer"
	return "believer"


func _build_intervention_cycle(domain_tags: PackedStringArray, worship_style_tags: PackedStringArray) -> Array[String]:
	var favored_id := _pick_favored_intervention(domain_tags, worship_style_tags)
	var cycle: Array[String] = [favored_id]
	for intervention_id in ["blessing", "oracle", "inspiration"]:
		if not cycle.has(intervention_id):
			cycle.append(intervention_id)
	return cycle


func _resolve_faith_income(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var tiers: Dictionary = runtime.get("follower_tiers", {})
	var details := {}
	var total_gain := 0
	for tier_id in runtime.get("tier_order", []):
		var tier: Dictionary = tiers.get(str(tier_id), {})
		var count := int(tier.get("count", 0))
		var faith_per_follower := int(tier.get("faith_per_follower", 0))
		var gain := count * faith_per_follower
		total_gain += gain
		details[str(tier_id)] = {
			"label": str(tier.get("label", str(tier_id))),
			"count": count,
			"faith_per_follower": faith_per_follower,
			"gain": gain,
			"sample_names": tier.get("sample_names", PackedStringArray()),
		}
	var faith: Dictionary = runtime.get("faith", {}).duplicate(true)
	faith["current"] = int(faith.get("current", 0)) + total_gain
	faith["generated_total"] = int(faith.get("generated_total", 0)) + total_gain
	runtime["faith"] = faith
	return {
		"day": simulated_day,
		"details": details,
		"total_gain": total_gain,
		"faith_after_income": int(faith.get("current", 0)),
	}


func _resolve_intervention(runtime: Dictionary, simulated_day: int) -> Dictionary:
	var intervention_library := _build_intervention_library()
	var faith: Dictionary = runtime.get("faith", {}).duplicate(true)
	var favored_id := str(runtime.get("favored_intervention", "blessing"))
	var cycle: Array = runtime.get("intervention_cycle", [favored_id, "blessing", "oracle", "inspiration"])
	var cycle_index := posmod(simulated_day - 1, maxi(1, cycle.size()))
	var selected_id := str(cycle[cycle_index])
	var selected_config: Dictionary = intervention_library.get(selected_id, {})
	var current_faith := int(faith.get("current", 0))
	if current_faith < int(selected_config.get("cost", 999)):
		selected_id = _pick_affordable_intervention(current_faith)
		selected_config = intervention_library.get(selected_id, {}) if not selected_id.is_empty() else {}
	if selected_config.is_empty():
		return {
			"day": simulated_day,
			"id": "none",
			"label": "静观香火",
			"cost": 0,
			"target_tier": "",
			"preferred_by_aspect": false,
			"result": "信仰点不足，神明暂不干预。",
			"faith_after_spend": current_faith,
		}
	var target_tier := str(selected_config.get("target_tier", "believer"))
	if str(runtime.get("favored_target_tier", "")) == target_tier:
		target_tier = str(runtime.get("favored_target_tier", target_tier))
	var tier_state: Dictionary = runtime.get("follower_tiers", {}).get(target_tier, {})
	var target_name := _pick_target_name(tier_state)
	var cost := int(selected_config.get("cost", 0))
	faith["current"] = current_faith - cost
	faith["spent_total"] = int(faith.get("spent_total", 0)) + cost
	runtime["faith"] = faith
	return {
		"day": simulated_day,
		"id": selected_id,
		"label": str(selected_config.get("label", selected_id)),
		"cost": cost,
		"target_tier": target_tier,
		"target_name": target_name,
		"preferred_by_aspect": selected_id == favored_id,
		"result": "%s 对 %s 施行%s，%s" % [str(runtime.get("deity", {}).get("display_name", "神明")), target_name, str(selected_config.get("label", selected_id)), str(selected_config.get("effect", "维持神恩流转。"))],
		"faith_after_spend": int(faith.get("current", 0)),
	}


func _pick_affordable_intervention(current_faith: int) -> String:
	var intervention_library := _build_intervention_library()
	var affordable: Array[String] = []
	for intervention_id in ["blessing", "inspiration", "oracle"]:
		var config: Dictionary = intervention_library.get(intervention_id, {})
		if current_faith >= int(config.get("cost", 999)):
			affordable.append(intervention_id)
	if affordable.is_empty():
		return ""
	return affordable[0]


func _build_intervention_library() -> Dictionary:
	return {
		"blessing": {
			"label": "降福",
			"cost": 4,
			"preferred_domains": PackedStringArray(["protection", "harvest"]),
			"preferred_styles": PackedStringArray(["shared_offering"]),
			"target_tier": "shallow_believer",
			"effect": "稳住供奉秩序并提升基层香火。",
		},
		"oracle": {
			"label": "降下神谕",
			"cost": 6,
			"preferred_domains": PackedStringArray(["omens"]),
			"preferred_styles": PackedStringArray(["night_ritual"]),
			"target_tier": "believer",
			"effect": "通过启示统一信众行动。",
		},
		"inspiration": {
			"label": "赐下灵感",
			"cost": 5,
			"preferred_domains": PackedStringArray(["harvest", "omens"]),
			"preferred_styles": PackedStringArray(["night_ritual"]),
			"target_tier": "fervent_believer",
			"effect": "强化神眷者的领受与传播能力。",
		},
	}


func _pick_target_name(tier_state: Dictionary) -> String:
	var sample_names: PackedStringArray = tier_state.get("sample_names", PackedStringArray())
	if not sample_names.is_empty():
		return str(sample_names[0])
	return str(tier_state.get("label", "信众"))
