extends PanelContainer

signal character_created(params: Dictionary)

var _vbox: VBoxContainer
var _title_label: Label
var _name_edit: LineEdit
var _morality_slider: HSlider
var _morality_label: Label
var _birth_region_option: OptionButton
var _opening_type_group: VBoxContainer
var _opening_youth_btn: Button
var _opening_young_adult_btn: Button
var _opening_adult_btn: Button
var _difficulty_group: VBoxContainer
var _diff_easy_btn: Button
var _diff_normal_btn: Button
var _diff_hard_btn: Button
var _seed_spinbox: SpinBox
var _confirm_button: Button

var _selected_opening: StringName = &"youth"
var _selected_difficulty: int = 1

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	
	_vbox = VBoxContainer.new()
	_vbox.anchors_preset = Control.PRESET_FULL_RECT
	_vbox.add_theme_constant_override("separation", 12)
	add_child(_vbox)
	
	_title_label = Label.new()
	_title_label.text = "角色设定"
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_vbox.add_child(_title_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = "姓名："
	_vbox.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "输入角色名字"
	_name_edit.max_length = 10
	_name_edit.custom_minimum_size = Vector2(300, 30)
	_vbox.add_child(_name_edit)
	
	# Morality slider
	_morality_label = Label.new()
	_morality_label.text = "道德偏好：刚正 ← → 唯我 (0)"
	_vbox.add_child(_morality_label)
	_morality_slider = HSlider.new()
	_morality_slider.min_value = -100
	_morality_slider.max_value = 100
	_morality_slider.step = 1
	_morality_slider.value = 0
	_morality_slider.custom_minimum_size = Vector2(300, 20)
	_morality_slider.value_changed.connect(_on_morality_changed)
	_vbox.add_child(_morality_slider)
	
	# Birth region
	var region_label := Label.new()
	region_label.text = "出生地："
	_vbox.add_child(region_label)
	_birth_region_option = OptionButton.new()
	_birth_region_option.add_item("山村", 0)
	_birth_region_option.add_item("城镇", 1)
	_birth_region_option.add_item("水乡", 2)
	_birth_region_option.add_item("边塞", 3)
	_birth_region_option.add_item("隐谷", 4)
	_vbox.add_child(_birth_region_option)
	
	# Opening type
	var opening_label := Label.new()
	opening_label.text = "开局类型："
	_vbox.add_child(opening_label)
	_opening_type_group = VBoxContainer.new()
	_opening_youth_btn = Button.new()
	_opening_youth_btn.text = "少年（14岁）"
	_opening_youth_btn.toggle_mode = true
	_opening_youth_btn.button_pressed = true
	_opening_youth_btn.pressed.connect(_on_opening_selected.bind(&"youth"))
	_opening_type_group.add_child(_opening_youth_btn)
	_opening_young_adult_btn = Button.new()
	_opening_young_adult_btn.text = "青年（18岁）"
	_opening_young_adult_btn.toggle_mode = true
	_opening_young_adult_btn.pressed.connect(_on_opening_selected.bind(&"young_adult"))
	_opening_type_group.add_child(_opening_young_adult_btn)
	_opening_adult_btn = Button.new()
	_opening_adult_btn.text = "成年（26岁）"
	_opening_adult_btn.toggle_mode = true
	_opening_adult_btn.pressed.connect(_on_opening_selected.bind(&"adult"))
	_opening_type_group.add_child(_opening_adult_btn)
	_vbox.add_child(_opening_type_group)
	
	# Difficulty
	var diff_label := Label.new()
	diff_label.text = "难度："
	_vbox.add_child(diff_label)
	_difficulty_group = VBoxContainer.new()
	_diff_easy_btn = Button.new()
	_diff_easy_btn.text = "简单"
	_diff_easy_btn.toggle_mode = true
	_diff_easy_btn.pressed.connect(_on_difficulty_selected.bind(1))
	_difficulty_group.add_child(_diff_easy_btn)
	_diff_normal_btn = Button.new()
	_diff_normal_btn.text = "普通"
	_diff_normal_btn.toggle_mode = true
	_diff_normal_btn.button_pressed = true
	_diff_normal_btn.pressed.connect(_on_difficulty_selected.bind(2))
	_difficulty_group.add_child(_diff_normal_btn)
	_diff_hard_btn = Button.new()
	_diff_hard_btn.text = "困难"
	_diff_hard_btn.toggle_mode = true
	_diff_hard_btn.pressed.connect(_on_difficulty_selected.bind(3))
	_difficulty_group.add_child(_diff_hard_btn)
	_vbox.add_child(_difficulty_group)
	
	# Seed
	var seed_label := Label.new()
	seed_label.text = "世界种子（-1为随机）："
	_vbox.add_child(seed_label)
	_seed_spinbox = SpinBox.new()
	_seed_spinbox.min_value = -1
	_seed_spinbox.max_value = 999999999
	_seed_spinbox.value = -1
	_seed_spinbox.custom_minimum_size = Vector2(200, 30)
	_vbox.add_child(_seed_spinbox)
	
	# Confirm button
	_confirm_button = Button.new()
	_confirm_button.text = "踏入修仙界"
	_confirm_button.custom_minimum_size = Vector2(300, 50)
	_confirm_button.add_theme_font_size_override("font_size", 22)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_vbox.add_child(_confirm_button)


func _on_morality_changed(value: float) -> void:
	_morality_label.text = "道德偏好：刚正 ← → 唯我 (%d)" % int(value)


func _on_opening_selected(type: StringName) -> void:
	_selected_opening = type
	_opening_youth_btn.button_pressed = (type == &"youth")
	_opening_young_adult_btn.button_pressed = (type == &"young_adult")
	_opening_adult_btn.button_pressed = (type == &"adult")


func _on_difficulty_selected(diff: int) -> void:
	_selected_difficulty = diff
	_diff_easy_btn.button_pressed = (diff == 1)
	_diff_normal_btn.button_pressed = (diff == 2)
	_diff_hard_btn.button_pressed = (diff == 3)


func _on_confirm_pressed() -> void:
	var params := {
		"character_name": _name_edit.text.strip_edges(),
		"morality_value": _morality_slider.value,
		"birth_region_id": _get_selected_region_id(),
		"opening_type": _selected_opening,
		"difficulty": _selected_difficulty,
		"custom_seed": int(_seed_spinbox.value),
	}
	character_created.emit(params)


func _get_selected_region_id() -> StringName:
	match _birth_region_option.selected:
		0: return &"region_0"  # 山村
		1: return &"region_1"  # 城镇
		2: return &"region_2"  # 水乡
		3: return &"region_3"  # 边塞
		4: return &"region_4"  # 隐谷
		_: return &"region_0"
