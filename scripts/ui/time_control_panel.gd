extends HBoxContainer
class_name TimeControlPanel

var _time_label: Label
var _speed_label: Label
var _buttons: Array[Button] = []

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	
	_time_label = Label.new()
	_time_label.text = "时间显示"
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size = Vector2(150, 0)
	add_child(_time_label)
	
	_speed_label = Label.new()
	_speed_label.text = "[速度]"
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.modulate = Color(0.7, 0.7, 1.0)
	_speed_label.custom_minimum_size = Vector2(100, 0)
	add_child(_speed_label)
	
	var btn_info = [
		{"tier": 1, "text": "0.5时"},
		{"tier": 2, "text": "1时"},
		{"tier": 3, "text": "1天"},
		{"tier": 4, "text": "1月"}
	]
	
	for info in btn_info:
		var btn := Button.new()
		btn.text = str(info["text"])
		var t: int = info["tier"]
		btn.pressed.connect(func(): _on_speed_button_pressed(t))
		add_child(btn)
		_buttons.append(btn)
	
	if get_tree() != null:
		var ts = get_tree().root.get_node_or_null("TimeService")
		if ts != null:
			ts.hour_advanced.connect(_on_hour_advanced)
			ts.speed_tier_changed.connect(_on_speed_tier_changed)
			_update_time_display(ts)
			_update_speed_display(ts)

func _on_speed_button_pressed(tier: int) -> void:
	if get_tree() == null: return
	var ts = get_tree().root.get_node_or_null("TimeService")
	if ts != null:
		ts.set_speed_tier(tier)

func _on_hour_advanced(_total_hours: float) -> void:
	if get_tree() == null: return
	var ts = get_tree().root.get_node_or_null("TimeService")
	if ts != null:
		_update_time_display(ts)

func _on_speed_tier_changed(_tier: int) -> void:
	if get_tree() == null: return
	var ts = get_tree().root.get_node_or_null("TimeService")
	if ts != null:
		_update_speed_display(ts)

func _update_time_display(ts: Node) -> void:
	_time_label.text = ts.get_clock_text_detailed()

func _update_speed_display(ts: Node) -> void:
	var tier_name: StringName = ts.get_speed_tier_name()
	var tier: int = ts.speed_tier
	
	var display_name := ""
	match tier_name:
		&"half_hour": display_name = "速度: 0.5时"
		&"one_hour": display_name = "速度: 1时"
		&"one_day": display_name = "速度: 1天"
		&"one_month": display_name = "速度: 1月"
		_: display_name = "速度: " + str(tier_name)
		
	_speed_label.text = display_name
	
	for i in range(_buttons.size()):
		if i + 1 == tier:
			_buttons[i].modulate = Color(0.2, 1.0, 0.2)
		else:
			_buttons[i].modulate = Color(1.0, 1.0, 1.0)
