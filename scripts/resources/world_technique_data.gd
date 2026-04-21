extends WorldBaseData
class_name WorldTechniqueData

# 功法类型：martial_skill/spirit_skill/ultimate/movement_method/passive_method
@export var technique_type: String = "martial_skill"
# 元素属性：fire/water/thunder/wind/earth/wood/neutral
@export var element: String = "neutral"
# 品质等级：common/uncommon/rare/epic/legendary/mythic
@export var rarity: String = "common"
# 学习所需最低境界
@export var min_realm: int = 0
# 威力等级（1-10）
@export var power_level: int = 1
# 词条槽数量
@export var affix_slots: int = 2
# 门派独占标识：空=野外功法，非空=门派独占
@export var sect_exclusive_id: String = ""
# 学习需求：如 {"sword_qualification": 30, "fire_root": 20}
@export var learning_requirements: Dictionary = {}
# 基础效果：如 {"damage_multiplier": 1.5, "mp_cost": 30}
@export var base_effects: Dictionary = {}
# 战斗技能列表：每项包含 name/description/damage_type/base_damage/cooldown
@export var combat_skills: Array[Dictionary] = []
