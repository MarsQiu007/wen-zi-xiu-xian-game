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

const CHOSEN_STAGE_LABELS := {
	"candidate": "候选",
	"guided": "受指引",
	"bound": "立契神眷者",
	"cult_nucleus": "教团核心",
	"cult_foundation": "教团根基",
}

const CULT_STAGE_LABELS := {
	"faith_crowd": "散漫香火",
	"cult_nucleus": "教团核心",
	"cult_foundation": "教团根基",
}

func build_initial_state(catalog: Resource, runtime_characters: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	if catalog == null:
		return {}
	var source_runtime_characters: Array[Dictionary] = runtime_characters.duplicate(true)
	if options.has("runtime_characters_override"):
		source_runtime_characters.clear()
		for character in options.get("runtime_characters_override", []):
			if character is Dictionary:
				source_runtime_characters.append(character.duplicate(true))
	var deity: Resource = _pick_deity(catalog, options)
	if deity == null:
		return {}
	var doctrine: Resource = _pick_doctrine(catalog, deity, options)
	var follower_state := _build_follower_state(source_runtime_characters, deity, doctrine)
	var deity_name := str(deity.get("display_name"))
	var domain_tags: PackedStringArray = deity.get("domain_tags")
	var worship_style_tags: PackedStringArray = deity.get("worship_style_tags")
	var chosen_preference := _build_chosen_preference(domain_tags, worship_style_tags)
	var chosen_devotee := _build_chosen_devotee_state(source_runtime_characters, deity, doctrine, chosen_preference)
	var cult_state := _build_cult_state(chosen_devotee)
	var opening_summary := "%s 以%s为核心维持神明模式。" % [deity_name, str(follower_state.get("summary", "稳定供奉"))]
	if not chosen_devotee.is_empty():
		opening_summary += " 主神眷者候选为%s，当前处于%s。" % [
			str(chosen_devotee.get("display_name", "无名氏")),
			str(chosen_devotee.get("stage_label", CHOSEN_STAGE_LABELS.get("candidate", "候选"))),
		]
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
		"chosen_preference": chosen_preference,
		"chosen_devotee": chosen_devotee,
		"cult_state": cult_state,
		"last_income": {},
		"last_intervention": {},
		"last_chosen_progress": {},
		"history": [
			{
				"day": 0,
				"kind": "opening",
				"summary": opening_summary,
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
	var chosen_progress := _resolve_chosen_devotee_progress(resolved_runtime, simulated_day, intervention)
	resolved_runtime["last_income"] = income
	resolved_runtime["last_intervention"] = intervention
	resolved_runtime["last_chosen_progress"] = chosen_progress
	var history: Array = resolved_runtime.get("history", [])
	history.append({
		"day": simulated_day,
		"kind": "daily_resolution",
		"income_total": int(income.get("total_gain", 0)),
		"intervention_id": str(intervention.get("id", "none")),
		"chosen_stage": str(resolved_runtime.get("chosen_devotee", {}).get("stage", "")),
		"cult_stage": str(resolved_runtime.get("cult_state", {}).get("stage", "faith_crowd")),
	})
	resolved_runtime["history"] = history
	return {
		"runtime": resolved_runtime,
		"income": income,
		"intervention": intervention,
		"chosen_progress": chosen_progress,
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


func _build_chosen_preference(domain_tags: PackedStringArray, worship_style_tags: PackedStringArray) -> Dictionary:
	var focus_tag := "future_devotee"
	var focus_role_tag := "future_devotee"
	var guidance_style := "balanced"
	if domain_tags.has("omens") or worship_style_tags.has("night_ritual"):
		focus_tag = "visionary"
		focus_role_tag = "seer_candidate"
		guidance_style = "omens_guidance"
	elif domain_tags.has("harvest") or worship_style_tags.has("shared_offering"):
		focus_tag = "ritual_focused"
		focus_role_tag = "future_devotee"
		guidance_style = "shared_offering_support"
	return {
		"focus_tag": focus_tag,
		"focus_role_tag": focus_role_tag,
		"guidance_style": guidance_style,
	}


func _build_chosen_devotee_state(runtime_characters: Array[Dictionary], deity: Resource, doctrine: Resource, chosen_preference: Dictionary) -> Dictionary:
	var deity_faction_id := ""
	if doctrine != null:
		deity_faction_id = str(doctrine.get("associated_faction_id"))
	var best_candidate := {}
	var best_score := -999999
	for character in runtime_characters:
		var evaluation := _evaluate_chosen_candidate(character, deity, deity_faction_id, chosen_preference)
		var score := int(evaluation.get("score", -999999))
		if score > best_score:
			best_score = score
			best_candidate = {
				"character": character,
				"reasons": evaluation.get("reasons", PackedStringArray()),
			}
		elif score == best_score and score > -999999:
			var current_id := str(best_candidate.get("character", {}).get("id", "zzzz"))
			var challenger_id := str(character.get("id", ""))
			if challenger_id < current_id:
				best_candidate = {
					"character": character,
					"reasons": evaluation.get("reasons", PackedStringArray()),
				}
	if best_candidate.is_empty() or best_score < 8:
		return {}
	var selected_character: Dictionary = best_candidate.get("character", {})
	var history: Array = []
	history.append({
		"day": 0,
		"stage": "candidate",
		"summary": "%s 被锁定为主神眷者候选。" % str(selected_character.get("display_name", "无名氏")),
	})
	return {
		"id": str(selected_character.get("id", "")),
		"display_name": str(selected_character.get("display_name", "无名氏")),
		"family_id": str(selected_character.get("family_id", "")),
		"faction_id": str(selected_character.get("faction_id", "")),
		"region_id": str(selected_character.get("region_id", "")),
		"faith_affinity": int(selected_character.get("faith_affinity", 0)),
		"role_tags": selected_character.get("role_tags", PackedStringArray()),
		"tags": selected_character.get("tags", PackedStringArray()),
		"stage": "candidate",
		"stage_label": str(CHOSEN_STAGE_LABELS.get("candidate", "候选")),
		"selection_score": best_score,
		"selection_reason": "、".join(best_candidate.get("reasons", PackedStringArray())),
		"guidance_days": 0,
		"support_days": 0,
		"bond_days": 0,
		"cult_days": 0,
		"history": history,
	}


func _evaluate_chosen_candidate(character: Dictionary, deity: Resource, deity_faction_id: String, chosen_preference: Dictionary) -> Dictionary:
	var score := int(character.get("faith_affinity", 0)) * 2 + int(character.get("talent_rank", 0))
	var reasons: PackedStringArray = PackedStringArray()
	var tags: PackedStringArray = character.get("tags", PackedStringArray())
	var role_tags: PackedStringArray = character.get("role_tags", PackedStringArray())
	var morality_tags: PackedStringArray = character.get("morality_tags", PackedStringArray())
	var temperament_tags: PackedStringArray = character.get("temperament_tags", PackedStringArray())
	var focus_tag := str(chosen_preference.get("focus_tag", "future_devotee"))
	var focus_role_tag := str(chosen_preference.get("focus_role_tag", "future_devotee"))
	if tags.has(focus_tag):
		score += 4
		reasons.append("契合神格偏好")
	if role_tags.has(focus_role_tag) or role_tags.has("future_devotee"):
		score += 3
		reasons.append("具备神眷者职责倾向")
	if str(character.get("faction_id", "")) == deity_faction_id and not deity_faction_id.is_empty():
		score += 3
		reasons.append("已在教义影响圈内")
	if morality_tags.has("devout") or morality_tags.has("patient"):
		score += 2
		reasons.append("信性稳固")
	if temperament_tags.has("observant") or temperament_tags.has("steadfast"):
		score += 1
		reasons.append("承接神谕稳定")
	if deity != null and (deity.get("domain_tags") as PackedStringArray).has("omens") and tags.has("visionary"):
		score += 2
		reasons.append("可承接神兆")
	return {
		"score": score,
		"reasons": reasons,
	}


func _build_cult_state(chosen_devotee: Dictionary) -> Dictionary:
	var history: Array = []
	history.append({
		"day": 0,
		"stage": "faith_crowd",
		"summary": "香火仍停留在散漫供奉层面。",
	})
	return {
		"stage": "faith_crowd",
		"stage_label": str(CULT_STAGE_LABELS.get("faith_crowd", "散漫香火")),
		"progress": 0,
		"required_chosen_id": str(chosen_devotee.get("id", "")),
		"foundation_ready": false,
		"history": history,
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
	var shallow_target := maxi(1, 1 + int(base_total / 2.0))
	var believer_target := maxi(1, 1 + deity_hint)
	var fervent_target := maxi(1, 1 + mini(2, int(doctrine_strength / 2.0)))
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
	var chosen_devotee: Dictionary = runtime.get("chosen_devotee", {})
	if not chosen_devotee.is_empty():
		target_name = str(chosen_devotee.get("display_name", target_name))
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


func _resolve_chosen_devotee_progress(runtime: Dictionary, simulated_day: int, intervention: Dictionary) -> Dictionary:
	var chosen_devotee: Dictionary = runtime.get("chosen_devotee", {}).duplicate(true)
	var cult_state: Dictionary = runtime.get("cult_state", {}).duplicate(true)
	if chosen_devotee.is_empty():
		cult_state["required_chosen_id"] = ""
		runtime["cult_state"] = cult_state
		return {
			"day": simulated_day,
			"has_chosen": false,
			"action_id": "no_chosen",
			"action_label": "无主神眷者",
			"chosen_stage_after": "",
			"cult_stage_after": str(cult_state.get("stage", "faith_crowd")),
			"result": "尚无主神眷者，香火暂不能直接凝成教团。",
		}
	var chosen_stage_before := str(chosen_devotee.get("stage", "candidate"))
	var cult_stage_before := str(cult_state.get("stage", "faith_crowd"))
	var action_info := _apply_chosen_intervention(chosen_devotee, intervention, runtime)
	_apply_chosen_stage_progress(chosen_devotee)
	_apply_cult_stage_progress(chosen_devotee, cult_state, chosen_stage_before, intervention)
	runtime["chosen_devotee"] = chosen_devotee
	runtime["cult_state"] = cult_state
	var chosen_stage_after := str(chosen_devotee.get("stage", chosen_stage_before))
	var cult_stage_after := str(cult_state.get("stage", cult_stage_before))
	var chosen_stage_changed := chosen_stage_before != chosen_stage_after
	var cult_stage_changed := cult_stage_before != cult_stage_after
	var result_text := str(action_info.get("summary", "神眷培养暂未推进。"))
	if chosen_stage_changed:
		result_text += " %s 晋入%s。" % [str(chosen_devotee.get("display_name", "无名氏")), str(chosen_devotee.get("stage_label", "新阶段"))]
	if cult_stage_changed:
		result_text += " 教团推进至%s。" % str(cult_state.get("stage_label", "新阶段"))
	return {
		"day": simulated_day,
		"has_chosen": true,
		"devotee_id": str(chosen_devotee.get("id", "")),
		"devotee_name": str(chosen_devotee.get("display_name", "无名氏")),
		"action_id": str(action_info.get("action_id", "observe")),
		"action_label": str(action_info.get("action_label", "静观")),
		"chosen_stage_before": chosen_stage_before,
		"chosen_stage_after": chosen_stage_after,
		"chosen_stage_changed": chosen_stage_changed,
		"cult_stage_before": cult_stage_before,
		"cult_stage_after": cult_stage_after,
		"cult_stage_changed": cult_stage_changed,
		"cult_progress": int(cult_state.get("progress", 0)),
		"result": result_text,
	}


func _apply_chosen_intervention(chosen_devotee: Dictionary, intervention: Dictionary, runtime: Dictionary) -> Dictionary:
	var intervention_id := str(intervention.get("id", "none"))
	var chosen_preference: Dictionary = runtime.get("chosen_preference", {})
	var guidance_style := str(chosen_preference.get("guidance_style", "balanced"))
	match intervention_id:
		"oracle":
			chosen_devotee["guidance_days"] = int(chosen_devotee.get("guidance_days", 0)) + 1
			if guidance_style == "omens_guidance":
				chosen_devotee["guidance_days"] = int(chosen_devotee.get("guidance_days", 0)) + 1
			_append_chosen_history(chosen_devotee, int(intervention.get("day", 0)), "guidance", "%s 接住神谕，逐渐能代神传意。" % str(chosen_devotee.get("display_name", "无名氏")))
			return {
				"action_id": "guided",
				"action_label": "受神谕指引",
				"summary": "%s 借神谕获得明确方向。" % str(chosen_devotee.get("display_name", "无名氏")),
			}
		"blessing":
			chosen_devotee["support_days"] = int(chosen_devotee.get("support_days", 0)) + 1
			if guidance_style == "shared_offering_support":
				chosen_devotee["support_days"] = int(chosen_devotee.get("support_days", 0)) + 1
			_append_chosen_history(chosen_devotee, int(intervention.get("day", 0)), "support", "%s 获得神恩扶持，能稳住周围香火。" % str(chosen_devotee.get("display_name", "无名氏")))
			return {
				"action_id": "supported",
				"action_label": "获得神恩扶持",
				"summary": "%s 获得神恩扶持，开始稳住供奉者。" % str(chosen_devotee.get("display_name", "无名氏")),
			}
		"inspiration":
			if str(chosen_devotee.get("stage", "candidate")) == "candidate":
				chosen_devotee["guidance_days"] = int(chosen_devotee.get("guidance_days", 0)) + 1
				_append_chosen_history(chosen_devotee, int(intervention.get("day", 0)), "awakening", "%s 因灵感启示开始真正回应神意。" % str(chosen_devotee.get("display_name", "无名氏")))
				return {
					"action_id": "guided",
					"action_label": "灵感启示",
					"summary": "%s 因灵感启示更接近神谕。" % str(chosen_devotee.get("display_name", "无名氏")),
				}
			chosen_devotee["bond_days"] = int(chosen_devotee.get("bond_days", 0)) + 1
			_append_chosen_history(chosen_devotee, int(intervention.get("day", 0)), "bond", "%s 完成一次更深的神契回响。" % str(chosen_devotee.get("display_name", "无名氏")))
			return {
				"action_id": "bound",
				"action_label": "完成神契回响",
				"summary": "%s 与神意之间的约束更稳固。" % str(chosen_devotee.get("display_name", "无名氏")),
			}
		_:
			return {
				"action_id": "observe",
				"action_label": "静观",
				"summary": "%s 暂时只能维持香火，不足以推进主神眷者培养。" % str(runtime.get("deity", {}).get("display_name", "神明")),
			}


func _apply_chosen_stage_progress(chosen_devotee: Dictionary) -> void:
	var stage := str(chosen_devotee.get("stage", "candidate"))
	if stage == "candidate" and int(chosen_devotee.get("guidance_days", 0)) >= 2:
		_set_chosen_stage(chosen_devotee, "guided")
		return
	if stage == "guided" and int(chosen_devotee.get("support_days", 0)) >= 2 and int(chosen_devotee.get("bond_days", 0)) >= 1:
		_set_chosen_stage(chosen_devotee, "bound")


func _apply_cult_stage_progress(chosen_devotee: Dictionary, cult_state: Dictionary, previous_chosen_stage: String, intervention: Dictionary) -> void:
	if str(intervention.get("id", "none")) == "none":
		return
	if previous_chosen_stage != "bound" and previous_chosen_stage != "cult_nucleus" and previous_chosen_stage != "cult_foundation":
		return
	chosen_devotee["cult_days"] = int(chosen_devotee.get("cult_days", 0)) + 1
	cult_state["progress"] = int(cult_state.get("progress", 0)) + 1
	var current_stage := str(cult_state.get("stage", "faith_crowd"))
	if current_stage == "faith_crowd" and int(cult_state.get("progress", 0)) >= 2:
		cult_state["stage"] = "cult_nucleus"
		cult_state["stage_label"] = str(CULT_STAGE_LABELS.get("cult_nucleus", "教团核心"))
		_append_cult_history(cult_state, int(intervention.get("day", 0)), "cult_nucleus", "%s 开始把散漫香火凝成可见教团核心。" % str(chosen_devotee.get("display_name", "无名氏")))
		_set_chosen_stage(chosen_devotee, "cult_nucleus")
		return
	if current_stage == "cult_nucleus" and int(cult_state.get("progress", 0)) >= 5:
		cult_state["stage"] = "cult_foundation"
		cult_state["stage_label"] = str(CULT_STAGE_LABELS.get("cult_foundation", "教团根基"))
		cult_state["foundation_ready"] = true
		_append_cult_history(cult_state, int(intervention.get("day", 0)), "cult_foundation", "%s 已能以主神眷者为轴建立稳定教团根基。" % str(chosen_devotee.get("display_name", "无名氏")))
		_set_chosen_stage(chosen_devotee, "cult_foundation")


func _set_chosen_stage(chosen_devotee: Dictionary, stage_id: String) -> void:
	chosen_devotee["stage"] = stage_id
	chosen_devotee["stage_label"] = str(CHOSEN_STAGE_LABELS.get(stage_id, stage_id))


func _append_chosen_history(chosen_devotee: Dictionary, day: int, kind: String, summary: String) -> void:
	var history: Array = chosen_devotee.get("history", [])
	history.append({
		"day": day,
		"kind": kind,
		"stage": str(chosen_devotee.get("stage", "candidate")),
		"summary": summary,
	})
	chosen_devotee["history"] = history


func _append_cult_history(cult_state: Dictionary, day: int, stage_id: String, summary: String) -> void:
	var history: Array = cult_state.get("history", [])
	history.append({
		"day": day,
		"stage": stage_id,
		"summary": summary,
	})
	cult_state["history"] = history


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
			"cost": 6,
			"preferred_domains": PackedStringArray(["protection", "harvest"]),
			"preferred_styles": PackedStringArray(["shared_offering"]),
			"target_tier": "shallow_believer",
			"effect": "稳住供奉秩序并提升基层香火。",
		},
		"oracle": {
			"label": "降下神谕",
			"cost": 10,
			"preferred_domains": PackedStringArray(["omens"]),
			"preferred_styles": PackedStringArray(["night_ritual"]),
			"target_tier": "believer",
			"effect": "通过启示统一信众行动。",
		},
		"inspiration": {
			"label": "赐下灵感",
			"cost": 8,
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
