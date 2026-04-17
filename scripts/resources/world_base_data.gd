extends Resource
class_name WorldBaseData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var human_visible: bool = true
@export var deity_visible: bool = true


func is_visible_for_mode(mode: StringName) -> bool:
	match mode:
		&"human":
			return human_visible
		&"deity":
			return deity_visible
		_:
			return true


func has_tag(tag: StringName) -> bool:
	return tags.has(String(tag))
