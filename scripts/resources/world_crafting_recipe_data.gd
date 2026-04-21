extends WorldBaseData
class_name WorldCraftingRecipeData

@export var recipe_type: String = ""
@export var result_item_id: String = ""
@export var result_quantity: int = 1
@export var result_rarity_min: String = ""
@export var materials: Array[Dictionary] = []
@export var required_skill_level: int = 0
@export var success_rate_base: float = 0.0
