extends Resource
class_name TechniqueAffix

# 词条唯一标识
@export var affix_id: String = ""
# 词条名称
@export var affix_name: String = ""
# 词条分类：offensive/defensive/utility
@export var affix_category: String = "utility"
# 词条效果：如 {"damage_bonus": 0.1}
@export var effect: Dictionary = {}
# 词条品质：common/uncommon/rare/epic/legendary/mythic
@export var rarity: String = "common"
# 兼容功法类型列表
@export var compatible_types: Array[String] = []
