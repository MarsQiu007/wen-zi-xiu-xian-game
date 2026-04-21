extends WorldBaseData
class_name WorldItemData

# 物品类型：weapon/armor/accessory/consumable/material/schematic
@export var item_type: String = "material"
# 品质等级：common/uncommon/rare/epic/legendary/mythic
@export var rarity: String = "common"
# 堆叠上限：默认 1，材料类通常为 99
@export var stack_size: int = 1
# 基础价值（单位：灵石）
@export var base_value: int = 0
# 装备槽位：weapon/head/body/accessory_1/accessory_2/""
@export var equip_slot: String = ""
# 属性修正：如 {"attack": 10, "defense": 5}
@export var stat_modifiers: Dictionary = {}
# 词条槽数量：0 表示无词条（如材料）
@export var affix_slots: int = 0
# 元素属性：fire/water/thunder/wind/earth/wood/neutral
@export var element: String = "neutral"
# 使用/装备所需最低境界
@export var required_realm: int = 0
# 消耗品效果：如 {"heal_hp": 50}
@export var consumable_effect: Dictionary = {}
