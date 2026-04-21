extends RefCounted
class_name CombatManager

const CombatResultDataScript = preload("res://scripts/data/combat_result_data.gd")
const CombatActionDataScript = preload("res://scripts/data/combat_action_data.gd")
const EventContractsScript = preload("res://scripts/core/event_contracts.gd")

const MAX_TURNS := 30
const ELEMENT_ADVANTAGE_MULTIPLIER := 1.3
const ELEMENT_DISADVANTAGE_MULTIPLIER := 0.7
const MIN_VARIANCE := 0.8
const MAX_VARIANCE := 1.2
const NORMAL_ATTACK_NAME := "普通攻击"
const NORMAL_ATTACK_DESCRIPTION := "以基础攻击进行普通攻击。"
const NORMAL_ATTACK_ELEMENT := "neutral"
const NORMAL_ATTACK_TECHNIQUE_POWER := 1.0
const FLEE_BASE_SUCCESS_RATE := 0.35

const STATUS_TYPE_BURN := "burn"
const STATUS_TYPE_POISON := "poison"
const STATUS_TYPE_FREEZE := "freeze"

const STATE_VERSION := 1

const TEAM_PLAYER := "player"
const TEAM_NPC := "npc"
const TEAM_A := "team_a"
const TEAM_B := "team_b"

const ELEMENT_ADVANTAGE: Dictionary = {
	"fire": "wind",
	"wind": "thunder",
	"thunder": "water",
	"water": "fire",
	"earth": "wood",
	"wood": "earth",
}

var _catalog: Resource
var _event_log: Node
var _rng_channels: RefCounted
var _player_action_resolver: Callable
var _active_loot_table_id: String = ""
var _ongoing_state: Dictionary = {}


func bind_catalog(catalog: Resource) -> void:
	_catalog = catalog


func bind_event_log(event_log: Node) -> void:
	_event_log = event_log


func bind_rng_channels(rng_channels: RefCounted) -> void:
	_rng_channels = rng_channels


func bind_player_action_resolver(resolver: Callable) -> void:
	_player_action_resolver = resolver


func set_active_loot_table_id(loot_table_id: String) -> void:
	_active_loot_table_id = loot_table_id.strip_edges()


func start_combat(participants: Array[CombatantData], rng: SeededRandom) -> CombatResultData:
	return _run_combat(participants, rng, false)


func resolve_npc_combat_only(participants: Array[CombatantData], rng: SeededRandom) -> CombatResultData:
	return _run_combat(participants, rng, true)


func save_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"active_loot_table_id": _active_loot_table_id,
		"ongoing_state": _ongoing_state.duplicate(true),
	}


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		_active_loot_table_id = ""
		_ongoing_state.clear()
		return
	var version := int(data.get("version", STATE_VERSION))
	if version != STATE_VERSION:
		_active_loot_table_id = ""
		_ongoing_state.clear()
		return
	_active_loot_table_id = str(data.get("active_loot_table_id", "")).strip_edges()
	var raw_state: Variant = data.get("ongoing_state", {})
	if raw_state is Dictionary:
		_ongoing_state = (raw_state as Dictionary).duplicate(true)
	else:
		_ongoing_state.clear()


func _run_combat(participants: Array[CombatantData], rng: SeededRandom, force_npc_decision: bool) -> CombatResultData:
	var result: CombatResultData = CombatResultDataScript.new()
	var combatants: Array[CombatantData] = _clone_participants(participants)
	if combatants.size() <= 1:
		_finalize_result(result, combatants, 0, [], rng)
		return result

	var teams := _build_team_map(combatants, force_npc_decision)
	_emit_event(EventContractsScript.COMBAT_STARTED, {
		"participants": _snapshot_participants(combatants),
		"force_npc_decision": force_npc_decision,
		"loot_table_id": _active_loot_table_id,
	})

	var runtime_state := {
		"turn": 0,
		"participants": _snapshot_participants(combatants),
		"teams": teams.duplicate(true),
		"log": [],
		"active_loot_table_id": _active_loot_table_id,
		"ended": false,
	}
	_ongoing_state = runtime_state.duplicate(true)

	var combat_log: Array[String] = []
	for turn in range(1, MAX_TURNS + 1):
		var turn_log: Array[String] = []
		_decrement_cooldowns(combatants)
		var action_order := _build_action_order(combatants)
		var fled_actor_id := ""
		for actor_index in action_order:
			if not _is_combatant_alive(combatants, actor_index):
				continue
			if _is_combat_finished(combatants, teams):
				break
			if _is_frozen(combatants[actor_index]):
				turn_log.append("[回合%d] %s 因冰冻无法行动" % [turn, combatants[actor_index].name])
				continue

			var action := _choose_action(combatants, teams, actor_index, rng, force_npc_decision)
			var action_outcome := _resolve_action(combatants, teams, actor_index, action, rng, turn)
			var action_lines: Variant = action_outcome.get("log", [])
			if action_lines is Array:
				for line in action_lines:
					turn_log.append(str(line))
			if bool(action_outcome.get("fled", false)):
				fled_actor_id = str(action_outcome.get("actor_id", ""))
				break

		var status_lines := _apply_status_effects(combatants, turn)
		for status_line in status_lines:
			turn_log.append(status_line)

		for line in turn_log:
			combat_log.append(line)

		_emit_event(EventContractsScript.COMBAT_TURN_RESOLVED, {
			"turn": turn,
			"log": turn_log.duplicate(true),
			"participant_states": _snapshot_participants(combatants),
		})

		runtime_state["turn"] = turn
		runtime_state["participants"] = _snapshot_participants(combatants)
		runtime_state["log"] = combat_log.duplicate(true)
		runtime_state["ended"] = _is_combat_finished(combatants, teams)
		if not fled_actor_id.is_empty():
			runtime_state["fled_actor_id"] = fled_actor_id
		_ongoing_state = runtime_state.duplicate(true)

		if not fled_actor_id.is_empty() or _is_combat_finished(combatants, teams):
			break

	_finalize_result(result, combatants, runtime_state.get("turn", 0), combat_log, rng, teams)
	runtime_state["ended"] = true
	runtime_state["victor_id"] = result.victor_id
	runtime_state["loot"] = result.loot.duplicate(true)
	_ongoing_state = runtime_state.duplicate(true)

	_emit_event(EventContractsScript.COMBAT_ENDED, {
		"turns_elapsed": result.turns_elapsed,
		"victor_id": result.victor_id,
		"loot": result.loot.duplicate(true),
		"participant_states": result.participant_states.duplicate(true),
	})

	return result


func _clone_participants(participants: Array[CombatantData]) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for participant in participants:
		if participant == null:
			continue
		var cloned := CombatantData.new()
		cloned.character_id = participant.character_id
		cloned.name = participant.name
		cloned.max_hp = participant.max_hp
		cloned.current_hp = clampi(participant.current_hp, 0, maxi(1, participant.max_hp))
		cloned.attack = participant.attack
		cloned.defense = participant.defense
		cloned.speed = participant.speed
		cloned.is_player = participant.is_player
		for raw_technique in participant.equipped_techniques:
			if raw_technique is Dictionary:
				cloned.equipped_techniques.append((raw_technique as Dictionary).duplicate(true))
		for raw_status in participant.status_effects:
			if raw_status is Dictionary:
				cloned.status_effects.append((raw_status as Dictionary).duplicate(true))
		for raw_item in participant.inventory_snapshot:
			if raw_item is Dictionary:
				cloned.inventory_snapshot.append((raw_item as Dictionary).duplicate(true))
		result.append(cloned)
	return result


func _build_team_map(combatants: Array[CombatantData], force_npc_decision: bool) -> Dictionary:
	var teams: Dictionary = {}
	var has_player := false
	for combatant in combatants:
		if combatant.is_player and not force_npc_decision:
			has_player = true
			break

	if has_player:
		for index in range(combatants.size()):
			teams[index] = TEAM_PLAYER if combatants[index].is_player else TEAM_NPC
		return teams

	var split := maxi(1, int(ceil(float(combatants.size()) * 0.5)))
	for index in range(combatants.size()):
		teams[index] = TEAM_A if index < split else TEAM_B
	return teams


func _decrement_cooldowns(combatants: Array[CombatantData]) -> void:
	for combatant in combatants:
		for entry_index in range(combatant.equipped_techniques.size()):
			var entry: Dictionary = combatant.equipped_techniques[entry_index]
			entry["current_cooldown"] = maxi(0, int(entry.get("current_cooldown", 0)) - 1)
			combatant.equipped_techniques[entry_index] = entry


func _build_action_order(combatants: Array[CombatantData]) -> Array[int]:
	var indices: Array[int] = []
	for index in range(combatants.size()):
		indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var left := combatants[a]
		var right := combatants[b]
		if left.speed != right.speed:
			return left.speed > right.speed
		return left.character_id < right.character_id
	)
	return indices


func _choose_action(combatants: Array[CombatantData], teams: Dictionary, actor_index: int, rng: SeededRandom, force_npc_decision: bool) -> CombatActionData:
	var actor := combatants[actor_index]
	if actor.is_player and not force_npc_decision and _player_action_resolver.is_valid():
		var player_action_variant: Variant = _player_action_resolver.call(actor, _snapshot_participants(combatants))
		if player_action_variant is CombatActionData:
			return player_action_variant
		if player_action_variant is Dictionary:
			return CombatActionData.from_dict(player_action_variant)

	return _choose_npc_action(combatants, teams, actor_index, rng)


func _choose_npc_action(combatants: Array[CombatantData], teams: Dictionary, actor_index: int, _rng: SeededRandom) -> CombatActionData:
	var actor := combatants[actor_index]
	var action := CombatActionDataScript.new()
	var enemies := _get_enemy_indices(combatants, teams, actor_index)
	if enemies.is_empty():
		action.action_type = "wait"
		action.target_index = actor_index
		return action

	var primary_target := _pick_target_with_lowest_hp(combatants, enemies)
	var hp_ratio := float(actor.current_hp) / float(maxi(1, actor.max_hp))
	if hp_ratio < 0.3:
		var heal_item_id := _find_healing_item_id(actor)
		if not heal_item_id.is_empty():
			action.action_type = "item"
			action.item_id = heal_item_id
			action.target_index = actor_index
			return action

	var best_skill := _pick_best_skill(actor, combatants[primary_target])
	if not best_skill.is_empty():
		action.action_type = "technique"
		action.technique_id = str(best_skill.get("technique_id", ""))
		action.target_index = primary_target
		return action

	if hp_ratio < 0.15:
		action.action_type = "flee"
		action.target_index = actor_index
		return action

	action.action_type = "attack"
	action.target_index = primary_target
	return action


func _resolve_action(combatants: Array[CombatantData], teams: Dictionary, actor_index: int, action: CombatActionData, rng: SeededRandom, turn: int) -> Dictionary:
	var actor := combatants[actor_index]
	var action_log: Array[String] = []
	var result := {
		"log": action_log,
		"fled": false,
		"actor_id": actor.character_id,
	}

	var action_type := str(action.action_type)
	match action_type:
		"item":
			_resolve_item_action(actor, action, action_log, turn)
		"flee":
			var flee_success := _try_flee(combatants, teams, actor_index, rng)
			if flee_success:
				action_log.append("[回合%d] %s 尝试逃跑并成功脱离战斗" % [turn, actor.name])
				_emit_event(EventContractsScript.COMBAT_FLED, {
					"character_id": actor.character_id,
					"turn": turn,
				})
				result["fled"] = true
			else:
				action_log.append("[回合%d] %s 尝试逃跑失败" % [turn, actor.name])
		"technique":
			var target_index := _normalize_target_index(combatants, teams, actor_index, action.target_index)
			if target_index == -1:
				action_log.append("[回合%d] %s 未找到有效目标" % [turn, actor.name])
				return result
			var skill := _consume_skill(actor, action.technique_id)
			if skill.is_empty():
				skill = _build_normal_attack_skill(actor)
			_resolve_damage_action(combatants, actor_index, target_index, skill, rng, action_log, turn)
		"attack":
			var target_index := _normalize_target_index(combatants, teams, actor_index, action.target_index)
			if target_index == -1:
				action_log.append("[回合%d] %s 未找到有效目标" % [turn, actor.name])
				return result
			var normal_skill := _build_normal_attack_skill(actor)
			_resolve_damage_action(combatants, actor_index, target_index, normal_skill, rng, action_log, turn)
		_:
			action_log.append("[回合%d] %s 选择观望" % [turn, actor.name])

	return result


func _resolve_item_action(actor: CombatantData, action: CombatActionData, action_log: Array[String], turn: int) -> void:
	var target_item_id := action.item_id.strip_edges()
	if target_item_id.is_empty():
		action_log.append("[回合%d] %s 尝试使用物品失败" % [turn, actor.name])
		return
	for item_index in range(actor.inventory_snapshot.size()):
		var item_entry: Dictionary = actor.inventory_snapshot[item_index]
		if str(item_entry.get("item_id", "")) != target_item_id:
			continue
		var quantity := int(item_entry.get("quantity", 0))
		if quantity <= 0:
			continue
		var effect := _resolve_consumable_effect(item_entry)
		var heal_hp := maxi(0, int(effect.get("heal_hp", 0)))
		if heal_hp > 0:
			actor.current_hp = mini(actor.max_hp, actor.current_hp + heal_hp)
		item_entry["quantity"] = quantity - 1
		actor.inventory_snapshot[item_index] = item_entry
		action_log.append("[回合%d] %s 使用 %s 恢复 %d 点生命" % [turn, actor.name, target_item_id, heal_hp])
		return
	action_log.append("[回合%d] %s 未找到可用物品 %s" % [turn, actor.name, target_item_id])


func _resolve_damage_action(combatants: Array[CombatantData], actor_index: int, target_index: int, skill: Dictionary, rng: SeededRandom, action_log: Array[String], turn: int) -> void:
	var attacker := combatants[actor_index]
	var defender := combatants[target_index]
	var technique_power := float(skill.get("technique_power", NORMAL_ATTACK_TECHNIQUE_POWER))
	if technique_power <= 0.0:
		technique_power = NORMAL_ATTACK_TECHNIQUE_POWER
	var damage_base := maxf(1.0, float(attacker.attack) * technique_power - float(defender.defense))
	var element := str(skill.get("element", NORMAL_ATTACK_ELEMENT))
	var defender_element := _resolve_combatant_element(defender)
	var element_modifier := _get_element_modifier(element, defender_element)
	var variance := _roll_range(rng, MIN_VARIANCE, MAX_VARIANCE)
	var final_damage := maxi(1, int(round(damage_base * element_modifier * variance)))
	defender.current_hp = maxi(0, defender.current_hp - final_damage)

	var skill_name := str(skill.get("name", NORMAL_ATTACK_NAME))
	action_log.append("[回合%d] %s 使用 %s 对 %s 造成 %d 点%s伤害" % [turn, attacker.name, skill_name, defender.name, final_damage, element])

	_try_apply_action_status(attacker, defender, skill, rng, action_log, turn)


func _apply_status_effects(combatants: Array[CombatantData], turn: int) -> Array[String]:
	var lines: Array[String] = []
	for combatant in combatants:
		if combatant.current_hp <= 0:
			continue
		var new_effects: Array[Dictionary] = []
		for raw_effect in combatant.status_effects:
			if not (raw_effect is Dictionary):
				continue
			var effect: Dictionary = (raw_effect as Dictionary).duplicate(true)
			var status_type := str(effect.get("type", ""))
			var remaining_turns := int(effect.get("remaining_turns", 0))
			if remaining_turns <= 0:
				continue

			var damage_per_turn := maxi(0, int(effect.get("damage_per_turn", 0)))
			if damage_per_turn > 0:
				combatant.current_hp = maxi(0, combatant.current_hp - damage_per_turn)
				lines.append("[回合%d] %s 受到%s效果影响，损失 %d 点生命" % [turn, combatant.name, _status_name(status_type), damage_per_turn])

			effect["remaining_turns"] = remaining_turns - 1
			if int(effect.get("remaining_turns", 0)) > 0:
				new_effects.append(effect)
			else:
				lines.append("[回合%d] %s 的%s状态结束" % [turn, combatant.name, _status_name(status_type)])

		combatant.status_effects = new_effects
	return lines


func _is_combat_finished(combatants: Array[CombatantData], teams: Dictionary) -> bool:
	var alive_by_team: Dictionary = {}
	for index in range(combatants.size()):
		if not _is_combatant_alive(combatants, index):
			continue
		var team := str(teams.get(index, TEAM_A))
		alive_by_team[team] = int(alive_by_team.get(team, 0)) + 1
	return alive_by_team.size() <= 1


func _is_combatant_alive(combatants: Array[CombatantData], index: int) -> bool:
	if index < 0 or index >= combatants.size():
		return false
	return combatants[index].current_hp > 0


func _get_enemy_indices(combatants: Array[CombatantData], teams: Dictionary, actor_index: int) -> Array[int]:
	var result: Array[int] = []
	var actor_team := str(teams.get(actor_index, TEAM_A))
	for index in range(combatants.size()):
		if index == actor_index:
			continue
		if str(teams.get(index, TEAM_A)) == actor_team:
			continue
		if combatants[index].current_hp <= 0:
			continue
		result.append(index)
	return result


func _normalize_target_index(combatants: Array[CombatantData], teams: Dictionary, actor_index: int, target_index: int) -> int:
	var enemies := _get_enemy_indices(combatants, teams, actor_index)
	if enemies.is_empty():
		return -1
	if enemies.has(target_index):
		return target_index
	return enemies[0]


func _pick_target_with_lowest_hp(combatants: Array[CombatantData], enemy_indices: Array[int]) -> int:
	var selected := enemy_indices[0]
	for index in enemy_indices:
		if combatants[index].current_hp < combatants[selected].current_hp:
			selected = index
	return selected


func _pick_best_skill(actor: CombatantData, target: CombatantData) -> Dictionary:
	var available_skills := _collect_available_skills(actor)
	if available_skills.is_empty():
		return {}

	var target_element := _resolve_combatant_element(target)
	available_skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_modifier := _get_element_modifier(str(a.get("element", NORMAL_ATTACK_ELEMENT)), target_element)
		var b_modifier := _get_element_modifier(str(b.get("element", NORMAL_ATTACK_ELEMENT)), target_element)
		if not is_equal_approx(a_modifier, b_modifier):
			return a_modifier > b_modifier
		var a_damage := float(a.get("base_damage", 0.0))
		var b_damage := float(b.get("base_damage", 0.0))
		if not is_equal_approx(a_damage, b_damage):
			return a_damage > b_damage
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return available_skills[0]


func _collect_available_skills(actor: CombatantData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entry in actor.equipped_techniques:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if int(entry.get("current_cooldown", 0)) > 0:
			continue
		var skill := _resolve_skill_from_entry(entry)
		if skill.is_empty():
			continue
		result.append(skill)
	return result


func _resolve_skill_from_entry(entry: Dictionary) -> Dictionary:
	if entry.has("base_damage") or entry.has("damage_multiplier"):
		var inline_skill := entry.duplicate(true)
		inline_skill["technique_id"] = str(entry.get("technique_id", ""))
		if not inline_skill.has("name"):
			inline_skill["name"] = str(entry.get("display_name", "技能"))
		if not inline_skill.has("element"):
			inline_skill["element"] = str(entry.get("damage_type", NORMAL_ATTACK_ELEMENT))
		if not inline_skill.has("technique_power"):
			inline_skill["technique_power"] = _resolve_technique_power(inline_skill, 1)
		return inline_skill

	var technique_id := str(entry.get("technique_id", "")).strip_edges()
	if technique_id.is_empty() or _catalog == null or not _catalog.has_method("find_technique"):
		return {}
	var technique: Resource = _catalog.find_technique(StringName(technique_id))
	if technique == null:
		return {}
	var combat_skills: Variant = technique.get("combat_skills")
	if not (combat_skills is Array) or (combat_skills as Array).is_empty():
		return {}

	var first_skill_raw: Variant = (combat_skills as Array)[0]
	if not (first_skill_raw is Dictionary):
		return {}
	var first_skill: Dictionary = (first_skill_raw as Dictionary).duplicate(true)
	var base_effects: Dictionary = _safe_dict(technique.get("base_effects"))
	var technique_element := str(technique.get("element"))
	first_skill["technique_id"] = technique_id
	first_skill["name"] = str(first_skill.get("name", technique.get("display_name")))
	first_skill["element"] = _resolve_skill_element(first_skill, technique_element)
	first_skill["damage_multiplier"] = float(base_effects.get("damage_multiplier", 1.0))
	if base_effects.has("burn_chance"):
		first_skill["burn_chance"] = float(base_effects.get("burn_chance", 0.0))
	first_skill["technique_power"] = _resolve_technique_power(first_skill, 1)
	return first_skill


func _consume_skill(actor: CombatantData, technique_id: String) -> Dictionary:
	var resolved_technique_id := technique_id.strip_edges()
	for index in range(actor.equipped_techniques.size()):
		var entry: Dictionary = actor.equipped_techniques[index]
		var entry_technique_id := str(entry.get("technique_id", "")).strip_edges()
		if entry_technique_id != resolved_technique_id:
			continue
		if int(entry.get("current_cooldown", 0)) > 0:
			return {}
		var skill := _resolve_skill_from_entry(entry)
		if skill.is_empty():
			return {}
		var cooldown := maxi(0, int(skill.get("cooldown", entry.get("cooldown", 0))))
		entry["current_cooldown"] = cooldown
		actor.equipped_techniques[index] = entry
		return skill
	return {}


func _build_normal_attack_skill(actor: CombatantData) -> Dictionary:
	return {
		"technique_id": "",
		"name": NORMAL_ATTACK_NAME,
		"description": NORMAL_ATTACK_DESCRIPTION,
		"element": NORMAL_ATTACK_ELEMENT,
		"base_damage": actor.attack,
		"cooldown": 0,
		"technique_power": NORMAL_ATTACK_TECHNIQUE_POWER,
	}


func _resolve_technique_power(skill: Dictionary, attacker_attack: int) -> float:
	if skill.has("technique_power"):
		return maxf(0.1, float(skill.get("technique_power", 1.0)))
	if skill.has("damage_multiplier"):
		return maxf(0.1, float(skill.get("damage_multiplier", 1.0)))
	var base_damage := float(skill.get("base_damage", 0.0))
	if base_damage <= 0.0:
		return NORMAL_ATTACK_TECHNIQUE_POWER
	return maxf(0.1, base_damage / float(maxi(1, attacker_attack)))


func _resolve_skill_element(skill: Dictionary, fallback_element: String) -> String:
	if skill.has("element"):
		return str(skill.get("element", NORMAL_ATTACK_ELEMENT)).to_lower()
	if skill.has("damage_type"):
		var damage_type := str(skill.get("damage_type", NORMAL_ATTACK_ELEMENT)).to_lower()
		if _is_known_element(damage_type):
			return damage_type
	return fallback_element.to_lower()


func _resolve_combatant_element(combatant: CombatantData) -> String:
	for raw_entry in combatant.equipped_techniques:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if entry.has("element"):
			var element := str(entry.get("element", NORMAL_ATTACK_ELEMENT)).to_lower()
			if _is_known_element(element):
				return element
		if entry.has("damage_type"):
			var damage_type := str(entry.get("damage_type", NORMAL_ATTACK_ELEMENT)).to_lower()
			if _is_known_element(damage_type):
				return damage_type
		var technique_id := str(entry.get("technique_id", "")).strip_edges()
		if not technique_id.is_empty() and _catalog != null and _catalog.has_method("find_technique"):
			var technique: Resource = _catalog.find_technique(StringName(technique_id))
			if technique != null:
				var technique_element := str(_resource_get(technique, "element", NORMAL_ATTACK_ELEMENT)).to_lower()
				if _is_known_element(technique_element):
					return technique_element
	return NORMAL_ATTACK_ELEMENT


func _get_element_modifier(attacker_element: String, defender_element: String) -> float:
	var attacker := attacker_element.to_lower()
	var defender := defender_element.to_lower()
	if not _is_known_element(attacker) or not _is_known_element(defender):
		return 1.0
	if attacker == defender:
		return 1.0
	if str(ELEMENT_ADVANTAGE.get(attacker, "")) == defender:
		return ELEMENT_ADVANTAGE_MULTIPLIER
	if str(ELEMENT_ADVANTAGE.get(defender, "")) == attacker:
		return ELEMENT_DISADVANTAGE_MULTIPLIER
	return 1.0


func _is_known_element(element: String) -> bool:
	return element == "fire" or element == "water" or element == "thunder" or element == "wind" or element == "earth" or element == "wood" or element == "neutral"


func _try_apply_action_status(attacker: CombatantData, defender: CombatantData, skill: Dictionary, rng: SeededRandom, action_log: Array[String], turn: int) -> void:
	var status_effect: Dictionary = {}
	if skill.has("status_effect") and skill.get("status_effect") is Dictionary:
		status_effect = _safe_dict(skill.get("status_effect", {}))
	elif str(skill.get("element", "")) == "fire" and float(skill.get("burn_chance", 0.0)) > 0.0:
		status_effect = {
			"type": STATUS_TYPE_BURN,
			"chance": float(skill.get("burn_chance", 0.0)),
			"damage_per_turn": maxi(1, int(round(float(attacker.attack) * 0.1))),
			"remaining_turns": 2,
		}

	if status_effect.is_empty():
		return
	var chance := clampf(float(status_effect.get("chance", 1.0)), 0.0, 1.0)
	if _roll_float(rng) > chance:
		return

	var normalized := {
		"type": str(status_effect.get("type", STATUS_TYPE_BURN)),
		"damage_per_turn": maxi(0, int(status_effect.get("damage_per_turn", 0))),
		"remaining_turns": maxi(1, int(status_effect.get("remaining_turns", 1))),
	}
	defender.status_effects.append(normalized)
	action_log.append("[回合%d] %s 附加了%s状态" % [turn, defender.name, _status_name(str(normalized.get("type", "")))])


func _is_frozen(combatant: CombatantData) -> bool:
	for raw_effect in combatant.status_effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect
		if str(effect.get("type", "")) == STATUS_TYPE_FREEZE and int(effect.get("remaining_turns", 0)) > 0:
			return true
	return false


func _status_name(status_type: String) -> String:
	match status_type:
		STATUS_TYPE_BURN:
			return "灼烧"
		STATUS_TYPE_POISON:
			return "中毒"
		STATUS_TYPE_FREEZE:
			return "冰冻"
		_:
			return "异常"


func _find_healing_item_id(actor: CombatantData) -> String:
	for raw_item in actor.inventory_snapshot:
		if not (raw_item is Dictionary):
			continue
		var item_entry: Dictionary = raw_item
		if int(item_entry.get("quantity", 0)) <= 0:
			continue
		var effect := _resolve_consumable_effect(item_entry)
		if int(effect.get("heal_hp", 0)) > 0:
			return str(item_entry.get("item_id", ""))
	return ""


func _resolve_consumable_effect(item_entry: Dictionary) -> Dictionary:
	if item_entry.has("consumable_effect") and item_entry.get("consumable_effect") is Dictionary:
		return _safe_dict(item_entry.get("consumable_effect", {}))
	var item_id := str(item_entry.get("item_id", "")).strip_edges()
	if item_id.is_empty() or _catalog == null or not _catalog.has_method("find_item"):
		return {}
	var item: Resource = _catalog.find_item(StringName(item_id))
	if item == null:
		return {}
	return _safe_dict(item.get("consumable_effect"))


func _try_flee(combatants: Array[CombatantData], teams: Dictionary, actor_index: int, rng: SeededRandom) -> bool:
	var actor := combatants[actor_index]
	var enemies := _get_enemy_indices(combatants, teams, actor_index)
	if enemies.is_empty():
		return true
	var highest_enemy_speed := 0
	for enemy_index in enemies:
		highest_enemy_speed = maxi(highest_enemy_speed, combatants[enemy_index].speed)
	var speed_delta := actor.speed - highest_enemy_speed
	var chance := clampf(FLEE_BASE_SUCCESS_RATE + float(speed_delta) * 0.01, 0.1, 0.9)
	if _roll_float(rng) <= chance:
		actor.current_hp = 0
		return true
	return false


func _finalize_result(result: CombatResultData, combatants: Array[CombatantData], turns_elapsed: int, combat_log: Array[String], rng: SeededRandom, teams: Dictionary = {}) -> void:
	result.turns_elapsed = turns_elapsed
	result.combat_log = combat_log.duplicate(true)
	result.participant_states = _snapshot_participants(combatants)
	result.victor_id = _resolve_victor_id(combatants, teams)
	result.loot = _generate_loot(result.victor_id, rng)


func _resolve_victor_id(combatants: Array[CombatantData], teams: Dictionary) -> String:
	if combatants.is_empty():
		return ""

	if teams.is_empty():
		var best: CombatantData = combatants[0]
		for combatant in combatants:
			if combatant.current_hp > best.current_hp:
				best = combatant
		return best.character_id

	var alive_by_team: Dictionary = {}
	for index in range(combatants.size()):
		if combatants[index].current_hp <= 0:
			continue
		var team := str(teams.get(index, TEAM_A))
		alive_by_team[team] = int(alive_by_team.get(team, 0)) + combatants[index].current_hp

	if alive_by_team.is_empty():
		return ""

	if alive_by_team.size() == 1:
		var winning_team := str(alive_by_team.keys()[0])
		for index in range(combatants.size()):
			if str(teams.get(index, TEAM_A)) == winning_team and combatants[index].current_hp > 0:
				return combatants[index].character_id
		return winning_team

	var top_team := ""
	var top_hp := -1
	for team_variant in alive_by_team.keys():
		var team := str(team_variant)
		var hp_sum := int(alive_by_team[team_variant])
		if hp_sum > top_hp:
			top_hp = hp_sum
			top_team = team

	for index in range(combatants.size()):
		if str(teams.get(index, TEAM_A)) == top_team and combatants[index].current_hp > 0:
			return combatants[index].character_id
	return top_team


func _generate_loot(victor_id: String, rng: SeededRandom) -> Array[Dictionary]:
	if victor_id.is_empty():
		return []
	var loot_table := _resolve_active_loot_table()
	if loot_table == null:
		return []

	var loot_rng: Variant = _resolve_loot_rng(rng)
	var result: Array[Dictionary] = []
	var guaranteed_raw: Variant = loot_table.get("guaranteed_drops")
	if guaranteed_raw is Array:
		for raw_entry in guaranteed_raw:
			if raw_entry is Dictionary:
				var guaranteed_drop := _roll_drop_entry(raw_entry, loot_rng, true)
				if not guaranteed_drop.is_empty():
					result.append(guaranteed_drop)

	var entries_raw: Variant = loot_table.get("entries")
	if entries_raw is Array and not (entries_raw as Array).is_empty():
		var weighted_entries: Array[Dictionary] = []
		for raw_entry in entries_raw:
			if raw_entry is Dictionary and int((raw_entry as Dictionary).get("weight", 0)) > 0:
				weighted_entries.append((raw_entry as Dictionary).duplicate(true))
		if not weighted_entries.is_empty():
			var rolled_index := _roll_weighted_index(weighted_entries, loot_rng)
			if rolled_index >= 0:
				var rolled_drop := _roll_drop_entry(weighted_entries[rolled_index], loot_rng, false)
				if not rolled_drop.is_empty():
					result.append(rolled_drop)
	return _merge_loot_entries(result)


func _resolve_active_loot_table() -> Resource:
	if _active_loot_table_id.is_empty() or _catalog == null or not _catalog.has_method("find_loot_table"):
		return null
	return _catalog.find_loot_table(StringName(_active_loot_table_id))


func _resolve_loot_rng(fallback_rng: SeededRandom) -> Variant:
	if _rng_channels != null and _rng_channels.has_method("get_loot_rng"):
		var channel_rng: Variant = _rng_channels.get_loot_rng()
		if channel_rng != null:
			return channel_rng
	return fallback_rng


func _roll_weighted_index(entries: Array[Dictionary], rng_source: Variant) -> int:
	var total_weight := 0
	for entry in entries:
		total_weight += maxi(0, int(entry.get("weight", 0)))
	if total_weight <= 0:
		return -1
	var roll := _roll_int_range(rng_source, 1, total_weight)
	var cursor := 0
	for index in range(entries.size()):
		cursor += maxi(0, int(entries[index].get("weight", 0)))
		if roll <= cursor:
			return index
	return entries.size() - 1


func _roll_drop_entry(entry: Dictionary, rng_source: Variant, is_guaranteed: bool) -> Dictionary:
	var item_id := str(entry.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return {}

	var quantity := 1
	var quantity_range: Variant = entry.get("quantity_range", [])
	if quantity_range is Array and (quantity_range as Array).size() >= 2:
		var min_quantity := int((quantity_range as Array)[0])
		var max_quantity := int((quantity_range as Array)[1])
		if max_quantity < min_quantity:
			var swap := min_quantity
			min_quantity = max_quantity
			max_quantity = swap
		quantity = _roll_int_range(rng_source, min_quantity, max_quantity)

	var rarity := "common"
	if not is_guaranteed:
		var min_rarity := str(entry.get("min_rarity", "common"))
		var max_rarity := str(entry.get("max_rarity", min_rarity))
		rarity = _roll_rarity_in_range(min_rarity, max_rarity, rng_source)

	return {
		"item_id": item_id,
		"quantity": maxi(1, quantity),
		"rarity": rarity,
	}


func _roll_rarity_in_range(min_rarity: String, max_rarity: String, rng_source: Variant) -> String:
	var rarity_order := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	var min_index := rarity_order.find(min_rarity)
	var max_index := rarity_order.find(max_rarity)
	if min_index == -1:
		min_index = 0
	if max_index == -1:
		max_index = min_index
	if max_index < min_index:
		var swap := min_index
		min_index = max_index
		max_index = swap
	var rolled_index := _roll_int_range(rng_source, min_index, max_index)
	return rarity_order[clampi(rolled_index, 0, rarity_order.size() - 1)]


func _merge_loot_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var merged: Dictionary = {}
	for entry in entries:
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		var rarity := str(entry.get("rarity", "common"))
		var key := "%s|%s" % [item_id, rarity]
		if not merged.has(key):
			merged[key] = {
				"item_id": item_id,
				"quantity": 0,
				"rarity": rarity,
			}
		var bucket: Dictionary = merged[key]
		bucket["quantity"] = int(bucket.get("quantity", 0)) + maxi(1, int(entry.get("quantity", 1)))
		merged[key] = bucket

	var result: Array[Dictionary] = []
	for value in merged.values():
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left_key := "%s|%s" % [str(a.get("item_id", "")), str(a.get("rarity", ""))]
		var right_key := "%s|%s" % [str(b.get("item_id", "")), str(b.get("rarity", ""))]
		return left_key < right_key
	)
	return result


func _snapshot_participants(combatants: Array[CombatantData]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for combatant in combatants:
		states.append({
			"character_id": combatant.character_id,
			"name": combatant.name,
			"is_player": combatant.is_player,
			"max_hp": combatant.max_hp,
			"current_hp": combatant.current_hp,
			"alive": combatant.current_hp > 0,
			"status_effects": combatant.status_effects.duplicate(true),
		})
	return states


func _emit_event(event_name: StringName, trace: Dictionary) -> void:
	if _event_log == null or not _event_log.has_method("add_event"):
		return
	_event_log.add_event({
		"category": "combat",
		"title": str(event_name),
		"direct_cause": str(event_name),
		"result": "combat_event",
		"trace": trace.duplicate(true),
	})


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


func _safe_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _resource_get(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value
