extends RefCounted
class_name NpcBehaviorLibrary

const BehaviorActionScript = preload("res://scripts/data/behavior_action.gd")


const BEHAVIOR_DEFS := {
	# === SURVIVAL ===
	"work_for_food": {
		"label": "外出讨生活",
		"category": &"survival",
		"pressure_deltas": {"survival": -3, "family": 0, "learning": 1, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 3.0,
		"description": "在市集或田间劳作，换取食物和基本生活物资。",
		"cooldown_hours": 4.0,
	},
	"forage_herbs": {
		"label": "采药觅食",
		"category": &"survival",
		"pressure_deltas": {"survival": -2, "learning": 1, "cultivation": 0},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.5,
		"description": "在山林间寻找草药和可食之物。",
		"cooldown_hours": 6.0,
	},
	"rest_recover": {
		"label": "休息调养",
		"category": &"survival",
		"pressure_deltas": {"survival": -2, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.0,
		"description": "静养恢复体力，调息养神。",
		"cooldown_hours": 3.0,
	},
	"trade_goods": {
		"label": "市集交易",
		"category": &"survival",
		"pressure_deltas": {"survival": -2, "learning": 0},
		"favor_deltas": {"merchant": 1},
		"conditions": {},
		"weight": 2.5,
		"description": "在市集买卖货物，维持生计。",
		"cooldown_hours": 8.0,
	},
	"hunt_beasts": {
		"label": "猎杀妖兽",
		"category": &"survival",
		"pressure_deltas": {"survival": -1, "cultivation": 2},
		"favor_deltas": {},
		"conditions": {},
		"weight": 1.5,
		"description": "深入荒野猎杀妖兽，获取兽核与材料。",
		"cooldown_hours": 12.0,
	},
	"build_shelter": {
		"label": "修缮居所",
		"category": &"survival",
		"pressure_deltas": {"survival": -2, "family": -1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.0,
		"description": "修缮住所，改善居住条件。",
		"cooldown_hours": 24.0,
	},
	"scavenge_ruins": {
		"label": "搜寻遗迹",
		"category": &"survival",
		"pressure_deltas": {"survival": -1, "learning": 2, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 1.5,
		"description": "在古老遗迹中搜寻遗物和功法残卷。",
		"cooldown_hours": 24.0,
	},
	"farm_crops": {
		"label": "耕种灵田",
		"category": &"survival",
		"pressure_deltas": {"survival": -2, "family": -1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.0,
		"description": "照料灵田，种植灵谷灵药。",
		"cooldown_hours": 12.0,
	},

	# === SOCIAL ===
	"chat_with_neighbor": {
		"label": "与邻里闲聊",
		"category": &"social",
		"pressure_deltas": {"survival": 0, "family": 0, "learning": 0, "cultivation": 0},
		"favor_deltas": {"friend": 2, "neighbor": 1},
		"conditions": {},
		"weight": 3.0,
		"description": "与邻里闲话家常，增进感情。",
		"cooldown_hours": 4.0,
	},
	"seek_mentor_guidance": {
		"label": "向师长请教",
		"category": &"social",
		"pressure_deltas": {"learning": -3, "cultivation": 1},
		"favor_deltas": {"mentor": 5},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 2.0,
		"description": "向有经验的师长请教修行之道。",
		"cooldown_hours": 24.0,
	},
	"visit_tavern": {
		"label": "酒楼小聚",
		"category": &"social",
		"pressure_deltas": {"survival": 1, "learning": 1},
		"favor_deltas": {"friend": 1, "rival": -1},
		"conditions": {},
		"weight": 2.5,
		"description": "在酒楼与各色人等交流消息。",
		"cooldown_hours": 8.0,
	},
	"attend_gathering": {
		"label": "参加聚会",
		"category": &"social",
		"pressure_deltas": {"survival": 1, "family": -1},
		"favor_deltas": {"friend": 2, "ally": 1},
		"conditions": {},
		"weight": 2.0,
		"description": "参加修仙者的聚会，结交同道。",
		"cooldown_hours": 48.0,
	},
	"exchange_techniques": {
		"label": "交流功法",
		"category": &"social",
		"pressure_deltas": {"learning": -2, "cultivation": 2},
		"favor_deltas": {"friend": 3, "rival": -2},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 1.5,
		"description": "与同道交流修炼心得，互相启发。",
		"cooldown_hours": 48.0,
	},
	"help_neighbor": {
		"label": "帮助邻里",
		"category": &"social",
		"pressure_deltas": {"survival": 1, "family": -2},
		"favor_deltas": {"neighbor": 3, "friend": 2},
		"conditions": {},
		"weight": 2.0,
		"description": "帮助邻里解决困难，积累善缘。",
		"cooldown_hours": 12.0,
	},
	"seek_disciple": {
		"label": "收徒传道",
		"category": &"social",
		"pressure_deltas": {"learning": -1, "cultivation": 2},
		"favor_deltas": {"disciple": 5},
		"conditions": {"minimum_realm": "foundation"},
		"weight": 1.0,
		"description": "收徒传授修行之道，延续传承。",
		"cooldown_hours": 168.0,
	},
	"form_alliance": {
		"label": "结盟立约",
		"category": &"social",
		"pressure_deltas": {"survival": -1, "cultivation": 1},
		"favor_deltas": {"ally": 5},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 1.0,
		"description": "与志同道合者结盟，共谋大事。",
		"cooldown_hours": 168.0,
	},
	"visit_family": {
		"label": "探望家人",
		"category": &"social",
		"pressure_deltas": {"family": -3, "survival": 1},
		"favor_deltas": {"family": 3},
		"conditions": {},
		"weight": 2.5,
		"description": "回家探望亲人，尽孝尽责。",
		"cooldown_hours": 24.0,
	},
	"spread_rumor": {
		"label": "散布消息",
		"category": &"social",
		"pressure_deltas": {"learning": 1},
		"favor_deltas": {"rival": -3, "enemy": -2},
		"conditions": {},
		"weight": 1.5,
		"description": "散布消息或谣言，影响舆论。",
		"cooldown_hours": 24.0,
	},

	# === CULTIVATION ===
	"meditate": {
		"label": "静坐冥想",
		"category": &"cultivation",
		"pressure_deltas": {"cultivation": -2, "survival": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 4.0,
		"description": "静坐冥想，感悟天地灵气。",
		"cooldown_hours": 2.0,
	},
	"practice_technique": {
		"label": "修炼功法",
		"category": &"cultivation",
		"pressure_deltas": {"cultivation": -4, "survival": 1},
		"favor_deltas": {},
		"conditions": {"has_technique": true},
		"weight": 3.0,
		"description": "专心修炼已得功法，提升修为。",
		"cooldown_hours": 6.0,
	},
	"breakthrough_attempt": {
		"label": "尝试突破",
		"category": &"cultivation",
		"pressure_deltas": {"cultivation": -8, "survival": 3},
		"favor_deltas": {},
		"conditions": {"minimum_realm_progress": 90},
		"weight": 1.0,
		"description": "尝试突破当前境界，风险与机遇并存。",
		"cooldown_hours": 168.0,
	},
	"refine_pill": {
		"label": "炼制丹药",
		"category": &"cultivation",
		"pressure_deltas": {"cultivation": -2, "learning": 2},
		"favor_deltas": {"ally": 1},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 2.0,
		"description": "炼制辅助修行的丹药。",
		"cooldown_hours": 24.0,
	},
	"absorb_spirit_stone": {
		"label": "吸收灵石",
		"category": &"cultivation",
		"pressure_deltas": {"cultivation": -3},
		"favor_deltas": {},
		"conditions": {},
		"weight": 3.0,
		"description": "吸收灵石中的灵气，加速修行。",
		"cooldown_hours": 4.0,
	},
	"study_classics": {
		"label": "研读典籍",
		"category": &"cultivation",
		"pressure_deltas": {"learning": -3, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 3.0,
		"description": "研读乡塾典籍，增长见闻。",
		"cooldown_hours": 4.0,
	},
	"seek_master": {
		"label": "打听仙门引路人",
		"category": &"cultivation",
		"pressure_deltas": {"survival": 1, "family": 1, "cultivation": -2},
		"favor_deltas": {"mentor": 2},
		"conditions": {},
		"weight": 2.0,
		"description": "四处打听仙门引路人的消息。",
		"cooldown_hours": 12.0,
	},
	"visit_sect": {
		"label": "前往山门外探访",
		"category": &"cultivation",
		"pressure_deltas": {"survival": 1, "family": 1, "cultivation": -1},
		"favor_deltas": {"mentor": 2},
		"conditions": {},
		"weight": 2.0,
		"description": "前往修仙宗门探访，寻求机缘。",
		"cooldown_hours": 24.0,
	},

	# === EXPLORATION ===
	"explore_wilderness": {
		"label": "探索荒野",
		"category": &"exploration",
		"pressure_deltas": {"survival": 1, "learning": 2, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.0,
		"description": "深入荒野探索未知之地。",
		"cooldown_hours": 12.0,
	},
	"search_secret_realm": {
		"label": "寻找秘境",
		"category": &"exploration",
		"pressure_deltas": {"survival": 2, "learning": 3, "cultivation": 2},
		"favor_deltas": {},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 1.0,
		"description": "寻找传说中的秘境入口。",
		"cooldown_hours": 72.0,
	},
	"map_region": {
		"label": "绘制地图",
		"category": &"exploration",
		"pressure_deltas": {"learning": 2},
		"favor_deltas": {"ally": 1},
		"conditions": {},
		"weight": 1.5,
		"description": "探索并绘制区域地图。",
		"cooldown_hours": 24.0,
	},
	"investigate_anomaly": {
		"label": "调查异象",
		"category": &"exploration",
		"pressure_deltas": {"learning": 3, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 1.5,
		"description": "调查天地异象，寻找机缘。",
		"cooldown_hours": 48.0,
	},
	"collect_herbs": {
		"label": "采集灵药",
		"category": &"exploration",
		"pressure_deltas": {"survival": -1, "learning": 2, "cultivation": 1},
		"favor_deltas": {},
		"conditions": {},
		"weight": 2.5,
		"description": "在野外采集灵药和珍稀材料。",
		"cooldown_hours": 8.0,
	},
	"scout_danger": {
		"label": "侦察险地",
		"category": &"exploration",
		"pressure_deltas": {"survival": 2, "learning": 1},
		"favor_deltas": {"ally": 2},
		"conditions": {},
		"weight": 1.5,
		"description": "侦察危险区域，为同伴探路。",
		"cooldown_hours": 12.0,
	},

	# === CONFLICT ===
	"challenge_rival": {
		"label": "挑战对手",
		"category": &"conflict",
		"pressure_deltas": {"survival": 2, "cultivation": 2},
		"favor_deltas": {"rival": -3, "enemy": -2},
		"conditions": {},
		"weight": 1.5,
		"description": "向对手发起挑战，一较高下。",
		"cooldown_hours": 48.0,
	},
	"defend_territory": {
		"label": "守卫领地",
		"category": &"conflict",
		"pressure_deltas": {"survival": -1, "family": -2},
		"favor_deltas": {"ally": 3, "enemy": -3},
		"conditions": {},
		"weight": 2.0,
		"description": "守卫自己的领地和资源。",
		"cooldown_hours": 24.0,
	},
	"ambush_enemy": {
		"label": "伏击仇敌",
		"category": &"conflict",
		"pressure_deltas": {"survival": 3, "cultivation": 1},
		"favor_deltas": {"enemy": -5},
		"conditions": {},
		"weight": 0.5,
		"description": "暗中伏击仇敌，出其不意。",
		"cooldown_hours": 72.0,
	},
	"compete_resource": {
		"label": "争夺资源",
		"category": &"conflict",
		"pressure_deltas": {"survival": -2, "cultivation": 1},
		"favor_deltas": {"rival": -2},
		"conditions": {},
		"weight": 2.0,
		"description": "与他人争夺稀缺资源。",
		"cooldown_hours": 12.0,
	},
	"sabotage_rival": {
		"label": "暗中破坏",
		"category": &"conflict",
		"pressure_deltas": {"survival": 1, "learning": 1},
		"favor_deltas": {"rival": -5, "enemy": -3},
		"conditions": {},
		"weight": 0.5,
		"description": "暗中破坏对手的计划和资源。",
		"cooldown_hours": 72.0,
	},
	"duel_honor": {
		"label": "决斗争名",
		"category": &"conflict",
		"pressure_deltas": {"survival": 2, "cultivation": 3},
		"favor_deltas": {"rival": -4, "friend": 2},
		"conditions": {"minimum_realm": "q Condensing"},
		"weight": 1.0,
		"description": "为名誉而决斗，胜者为王。",
		"cooldown_hours": 168.0,
	},
	"repel_monster": {
		"label": "击退妖兽",
		"category": &"conflict",
		"pressure_deltas": {"survival": -1, "cultivation": 2},
		"favor_deltas": {"ally": 2, "neighbor": 1},
		"conditions": {},
		"weight": 2.0,
		"description": "击退侵扰的妖兽，保护乡邻。",
		"cooldown_hours": 24.0,
	},
	"suppress_evil": {
		"label": "镇压邪修",
		"category": &"conflict",
		"pressure_deltas": {"survival": 2, "cultivation": 3},
		"favor_deltas": {"ally": 3, "enemy": -5},
		"conditions": {"minimum_realm": "foundation"},
		"weight": 0.5,
		"description": "镇压为祸一方的邪修。",
		"cooldown_hours": 168.0,
	},
}


var _behaviors: Dictionary = {}


func _init() -> void:
	_build_behaviors()


func _build_behaviors() -> void:
	for key in BEHAVIOR_DEFS:
		var def: Dictionary = BEHAVIOR_DEFS[key]
		var action := BehaviorActionScript.new()
		action.action_id = StringName(key)
		action.label = str(def.get("label", key))
		action.category = StringName(str(def.get("category", "")))
		action.pressure_deltas = def.get("pressure_deltas", {})
		action.favor_deltas = def.get("favor_deltas", {})
		action.conditions = def.get("conditions", {})
		action.weight = float(def.get("weight", 1.0))
		action.description = str(def.get("description", ""))
		action.cooldown_hours = float(def.get("cooldown_hours", 0.0))
		_behaviors[key] = action


func get_behavior(action_id: StringName) -> BehaviorAction:
	var key := String(action_id)
	if _behaviors.has(key):
		return _behaviors[key]
	return null


func get_behaviors_by_category(category: StringName) -> Array[BehaviorAction]:
	var result: Array[BehaviorAction] = []
	for key in _behaviors:
		var action: BehaviorAction = _behaviors[key]
		if action.category == category:
			result.append(action)
	return result


func get_available_behaviors(npc_state: Dictionary, current_hours: float) -> Array[BehaviorAction]:
	var result: Array[BehaviorAction] = []
	var realm := str(npc_state.get("cultivation_state", {}).get("realm", "mortal"))
	var has_technique := bool(npc_state.get("cultivation_state", {}).get("has_technique", false))
	var realm_progress := int(npc_state.get("cultivation_state", {}).get("progress", 0))
	var last_action_hours := float(npc_state.get("last_action_hours", -999999.0))

	for key in _behaviors:
		var action: BehaviorAction = _behaviors[key]
		var conditions: Dictionary = action.conditions

		# 检查 minimum_realm 条件
		if conditions.has("minimum_realm"):
			var required_realm := str(conditions["minimum_realm"])
			if not _is_realm_sufficient(realm, required_realm):
				continue

		# 检查 has_technique 条件
		if conditions.has("has_technique"):
			if bool(conditions["has_technique"]) != has_technique:
				continue

		# 检查 minimum_realm_progress 条件
		if conditions.has("minimum_realm_progress"):
			if realm_progress < int(conditions["minimum_realm_progress"]):
				continue

		# 检查冷却
		if action.cooldown_hours > 0.0 and last_action_hours >= 0.0:
			if current_hours - last_action_hours < action.cooldown_hours:
				continue

		result.append(action)
	return result


func get_random_behavior(category: StringName, rng: RefCounted) -> BehaviorAction:
	var behaviors := get_behaviors_by_category(category)
	if behaviors.is_empty():
		return null
	return behaviors[rng.randi() % behaviors.size()]


func _is_realm_sufficient(current: String, required: String) -> bool:
	var realm_order := ["mortal", "q Condensing", "foundation", "golden_core"]
	var current_idx := realm_order.find(current)
	var required_idx := realm_order.find(required)
	if current_idx == -1:
		current_idx = 0
	if required_idx == -1:
		required_idx = 0
	return current_idx >= required_idx
