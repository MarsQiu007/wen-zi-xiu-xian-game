extends PanelContainer

signal mode_selected(mode: StringName)

var _vbox: VBoxContainer
var _title_label: Label
var _human_button: Button
var _deity_button: Button
var _continue_button: Button

func _ready() -> void:
	# Build UI programmatically
	anchors_preset = Control.PRESET_FULL_RECT
	
	_vbox = VBoxContainer.new()
	_vbox.anchors_preset = Control.PRESET_FULL_RECT
	_vbox.add_theme_constant_override("separation", 20)
	add_child(_vbox)
	
	_title_label = Label.new()
	_title_label.text = "选择玩法"
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_vbox.add_child(_title_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	_vbox.add_child(spacer)
	
	_human_button = Button.new()
	_human_button.text = "扮演凡人"
	_human_button.custom_minimum_size = Vector2(300, 60)
	_human_button.add_theme_font_size_override("font_size", 24)
	_vbox.add_child(_human_button)
	
	_deity_button = Button.new()
	_deity_button.text = "扮演神明"
	_deity_button.custom_minimum_size = Vector2(300, 60)
	_deity_button.add_theme_font_size_override("font_size", 24)
	_vbox.add_child(_deity_button)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	_vbox.add_child(spacer2)
	
	_continue_button = Button.new()
	_continue_button.text = "继续游戏"
	_continue_button.custom_minimum_size = Vector2(300, 40)
	_continue_button.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(_continue_button)
	
	_human_button.pressed.connect(_on_human_pressed)
	_deity_button.pressed.connect(_on_deity_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	
	# Check if save exists
	var SaveService := get_tree().root.get_node_or_null("SaveService")
	if SaveService != null and SaveService.has_method("has_save_slot"):
		if not SaveService.has_save_slot():
			_continue_button.disabled = true
			_continue_button.text = "继续游戏（无存档）"


func _on_human_pressed() -> void:
	mode_selected.emit(&"human")


func _on_deity_pressed() -> void:
	# Show placeholder dialog
	var dialog := AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = "神明模式施工中，敬请期待"
	add_child(dialog)
	dialog.popup_centered()


func _on_continue_pressed() -> void:
	# Emit a continue signal - GameRoot will handle this
	var UIRoot := get_tree().root.get_node_or_null("UIRoot")
	if UIRoot != null and UIRoot.has_signal("menu_continue_requested"):
		UIRoot.menu_continue_requested.emit()
