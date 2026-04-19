extends Control
class_name UIRoot

signal menu_new_game_requested(mode: StringName)
signal menu_continue_requested()
signal mode_selected(mode: StringName)
signal character_created(params: Dictionary)
signal world_initialized()

var _main_menu_panel: PanelContainer
var _mode_select_screen: PanelContainer
var _char_creation_screen: PanelContainer
var _game_ui_container: MarginContainer
var _world_init_screen: PanelContainer
var _time_control_panel: HBoxContainer

var _status_panel: PanelContainer
var _status_label: Label
var _guide_label: Label

var _action_panel: PanelContainer
var _action_box: VBoxContainer

var _log_panel: PanelContainer
var _log_label: RichTextLabel
var _log_view_mode_btn: OptionButton
var _log_actor_filter_btn: OptionButton
var _log_category_filter_btn: OptionButton

var _known_actors: Array[String] = []
var _known_categories: Array[String] = []

var _event_modal: PanelContainer
var _sim_runner: Node

# Character UI components
var _character_panel: PanelContainer
var _roster_list: ItemList
var _detail_label: RichTextLabel
var _timeline_label: RichTextLabel
var _current_roster: Array[Dictionary] = []

# Map UI components
var _map_panel: PanelContainer
var _region_tree: Tree
var _region_detail_label: RichTextLabel
var _region_characters_list: ItemList
var _current_regions: Array[Dictionary] = []
var _map_region_items: Dictionary = {} # region_id -> TreeItem
var _map_focus_region_id: String = ""

var EventLog: Node
var TimeService: Node
var RunState: Node
var CharacterService: Node
var LocationService: Node

var _loading_label: Label

func _ready() -> void:
	_bind_singletons()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_loading_label = Label.new()
	_loading_label.text = " 正在生成世界，请稍候... "
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.hide()
	add_child(_loading_label)

	_build_minimal_ui()
	_build_main_menu()
	
	_mode_select_screen = preload("res://scenes/ui/mode_select_screen.tscn").instantiate()
	add_child(_mode_select_screen)
	_mode_select_screen.mode_selected.connect(func(m): mode_selected.emit(m))
	_mode_select_screen.hide()
	
	_char_creation_screen = preload("res://scenes/ui/char_creation_screen.tscn").instantiate()
	add_child(_char_creation_screen)
	_char_creation_screen.character_created.connect(func(p): character_created.emit(p))
	_char_creation_screen.hide()
	
	_world_init_screen = preload("res://scenes/ui/world_init_screen.tscn").instantiate()
	add_child(_world_init_screen)
	_world_init_screen.world_initialized.connect(func(): world_initialized.emit())
	_world_init_screen.hide()
	
	_build_character_ui()
	_build_map_ui()
	
	_refresh_text()
	_refresh_log()
	EventLog.entry_added.connect(_on_log_entry_added)
	TimeService.time_advanced.connect(_on_time_advanced)
	RunState.mode_changed.connect(_on_mode_changed)
	RunState.phase_changed.connect(_on_phase_changed)


func _bind_singletons() -> void:
	var root_node := get_tree().root if get_tree() != null else null
	if root_node == null:
		return
	if EventLog == null:
		EventLog = root_node.get_node_or_null("EventLog")
	if TimeService == null:
		TimeService = root_node.get_node_or_null("TimeService")
	if RunState == null:
		RunState = root_node.get_node_or_null("RunState")
	if CharacterService == null:
		CharacterService = root_node.get_node_or_null("CharacterService")
	if LocationService == null:
		LocationService = root_node.get_node_or_null("LocationService")


func bind_runner(runner: Node) -> void:
	_sim_runner = runner
	_refresh_text()
	_refresh_log()


func show_main_menu() -> void:
	if _main_menu_panel:
		_main_menu_panel.show()
	if _game_ui_container:
		_game_ui_container.hide()


func hide_main_menu() -> void:
	if _main_menu_panel:
		_main_menu_panel.hide()
	if _game_ui_container:
		_game_ui_container.show()


func _build_main_menu() -> void:
	_main_menu_panel = PanelContainer.new()
	_main_menu_panel.name = "MainMenuPanel"
	_main_menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_menu_panel)

	var center_container := CenterContainer.new()
	_main_menu_panel.add_child(center_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center_container.add_child(vbox)
	
	var title_lbl := Label.new()
	title_lbl.text = "【文字修仙沙盒】"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title_lbl)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	btn_vbox.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(btn_vbox)

	var new_human_btn := Button.new()
	new_human_btn.name = "NewHumanGameBtn"
	new_human_btn.text = "新游戏 (凡人视角)"
	new_human_btn.pressed.connect(func(): menu_new_game_requested.emit(&"human"))
	btn_vbox.add_child(new_human_btn)

	var new_deity_btn := Button.new()
	new_deity_btn.name = "NewDeityGameBtn"
	new_deity_btn.text = "新游戏 (神明视角)"
	new_deity_btn.pressed.connect(func(): menu_new_game_requested.emit(&"deity"))
	btn_vbox.add_child(new_deity_btn)

	var continue_btn := Button.new()
	continue_btn.name = "ContinueBtn"
	continue_btn.text = "继续游戏"
	continue_btn.disabled = true # 暂不支持
	continue_btn.pressed.connect(func(): menu_continue_requested.emit())
	btn_vbox.add_child(continue_btn)


func _build_minimal_ui() -> void:
	_game_ui_container = MarginContainer.new()
	_game_ui_container.name = "GameUIContainer"
	_game_ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_ui_container.add_theme_constant_override("margin_left", 8)
	_game_ui_container.add_theme_constant_override("margin_right", 8)
	_game_ui_container.add_theme_constant_override("margin_top", 8)
	_game_ui_container.add_theme_constant_override("margin_bottom", 8)
	_game_ui_container.hide() # 默认隐藏
	add_child(_game_ui_container)

	var main_vbox := VBoxContainer.new()
	_game_ui_container.add_child(main_vbox)

	# --- Status Area ---
	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusPanel"
	main_vbox.add_child(_status_panel)
	
	var status_hbox := HBoxContainer.new()
	_status_panel.add_child(status_hbox)
	
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "【文字修仙沙盒】"
	status_hbox.add_child(title_lbl)
	
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	status_hbox.add_child(_status_label)
	
	_guide_label = Label.new()
	_guide_label.name = "GuideLabel"
	_guide_label.modulate = Color(0.7, 0.7, 1.0)
	status_hbox.add_child(_guide_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(spacer)
	
	_time_control_panel = preload("res://scripts/ui/time_control_panel.gd").new()
	_time_control_panel.name = "TimeControlPanel"
	status_hbox.add_child(_time_control_panel)
	_time_control_panel.hide()

	# --- Main Content Area ---
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Action Area (Left)
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionPanel"
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.size_flags_stretch_ratio = 1.0
	content_hbox.add_child(_action_panel)
	
	_action_box = VBoxContainer.new()
	_action_box.name = "ActionBox"
	_action_panel.add_child(_action_box)
	
	var action_title := Label.new()
	action_title.text = "- 操作区 -"
	_action_box.add_child(action_title)
	
	var view_char_btn := Button.new()
	view_char_btn.name = "ViewCharactersBtn"
	view_char_btn.text = "查看角色情报"
	view_char_btn.pressed.connect(_on_view_characters_pressed)
	_action_box.add_child(view_char_btn)
	
	var view_map_btn := Button.new()
	view_map_btn.name = "ViewMapBtn"
	view_map_btn.text = "查看世界地图"
	view_map_btn.pressed.connect(_on_view_map_pressed)
	_action_box.add_child(view_map_btn)
	
	var test_action_btn := Button.new()
	test_action_btn.name = "TestActionBtn"
	test_action_btn.text = "执行基础修炼"
	test_action_btn.pressed.connect(_on_test_action_pressed)
	_action_box.add_child(test_action_btn)

	# Log Area (Right)
	_log_panel = PanelContainer.new()
	_log_panel.name = "LogPanel"
	_log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_panel.size_flags_stretch_ratio = 2.0
	content_hbox.add_child(_log_panel)
	
	var log_vbox := VBoxContainer.new()
	_log_panel.add_child(log_vbox)
	
	var log_toolbar := HBoxContainer.new()
	log_toolbar.add_theme_constant_override("separation", 8)
	log_vbox.add_child(log_toolbar)
	
	var log_title := Label.new()
	log_title.text = "- 日志区 -"
	log_toolbar.add_child(log_title)
	
	_log_view_mode_btn = OptionButton.new()
	_log_view_mode_btn.add_item("Summary")
	_log_view_mode_btn.add_item("Standard")
	_log_view_mode_btn.add_item("Detail")
	_log_view_mode_btn.item_selected.connect(func(_idx): _refresh_log())
	log_toolbar.add_child(_log_view_mode_btn)
	
	_log_actor_filter_btn = OptionButton.new()
	_log_actor_filter_btn.add_item("All Actors")
	_log_actor_filter_btn.item_selected.connect(func(_idx): _refresh_log())
	log_toolbar.add_child(_log_actor_filter_btn)
	
	_log_category_filter_btn = OptionButton.new()
	_log_category_filter_btn.add_item("All Categories")
	_log_category_filter_btn.item_selected.connect(func(_idx): _refresh_log())
	log_toolbar.add_child(_log_category_filter_btn)
	
	_log_label = RichTextLabel.new()
	_log_label.name = "LogTextLabel"
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	log_vbox.add_child(_log_label)


func _refresh_text() -> void:
	if _status_label == null:
		return

	_status_label.text = " 模式：%s | 阶段：%s | 时间：%s " % [
		str(RunState.mode),
		str(RunState.phase),
		TimeService.get_clock_text()
	]

	if RunState.mode == &"human":
		_guide_label.text = "引导：平衡压力，寻找仙缘；或暗自寻神，走上神道。"
	elif RunState.mode == &"deity":
		_guide_label.text = "引导：收集香火，培养眷者；建立教团，应对巡察。"
	else:
		_guide_label.text = ""

func _refresh_log() -> void:
	if _log_label == null:
		return
		
	var view_mode := _log_view_mode_btn.get_selected_id()
	
	var actor_filter := ""
	if _log_actor_filter_btn.get_selected_id() > 0:
		actor_filter = _log_actor_filter_btn.get_item_text(_log_actor_filter_btn.get_selected_id())
		
	var category_filter := ""
	if _log_category_filter_btn.get_selected_id() > 0:
		category_filter = _log_category_filter_btn.get_item_text(_log_category_filter_btn.get_selected_id())

	var filtered_entries: Array[Dictionary] = []
	
	for entry in EventLog.entries:
		var cat := str(entry.get("category", "world"))
		if not cat in _known_categories:
			_known_categories.append(cat)
			_log_category_filter_btn.add_item(cat)
			
		var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
		for a in actors:
			var actor_str := str(a)
			if not actor_str in _known_actors:
				_known_actors.append(actor_str)
				_log_actor_filter_btn.add_item(actor_str)
				
		if category_filter != "" and cat != category_filter:
			continue
			
		if actor_filter != "":
			var has_actor := false
			for a in actors:
				if str(a) == actor_filter:
					has_actor = true
					break
			if not has_actor:
				continue
				
		filtered_entries.append(entry)

	var text := ""
	
	if view_mode == 0:
		# Summary view: aggregate consecutive similar events
		var i := 0
		while i < filtered_entries.size():
			var entry: Dictionary = filtered_entries[i]
			var count := 1
			var j := i + 1
			
			var title := str(entry.get("title", ""))
			var result_str := str(entry.get("result", title))
			var trace: Dictionary = entry.get("trace", {})
			var location := str(trace.get("location", ""))
			var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
			var actor_desc := ",".join(actors) if actors.size() > 0 else "系统"
			
			while j < filtered_entries.size():
				var next_entry: Dictionary = filtered_entries[j]
				var next_title := str(next_entry.get("title", ""))
				var next_trace: Dictionary = next_entry.get("trace", {})
				var next_location := str(next_trace.get("location", ""))
				var next_actors: PackedStringArray = next_entry.get("actor_ids", PackedStringArray())
				var next_result := str(next_entry.get("result", next_title))
				var next_actor_desc := ",".join(next_actors) if next_actors.size() > 0 else "系统"
				
				# Same title, actors, location, and result can be aggregated
				if next_title == title and next_location == location and next_result == result_str and next_actor_desc == actor_desc:
					count += 1
					j += 1
					continue
				break
				
			var loc_desc := (" @ " + location) if location != "" else ""
			var timestamp := str(entry.get("timestamp", ""))
			
			if count > 1:
				text += "[%s] %s%s: %s (x%d)\n" % [timestamp, actor_desc, loc_desc, result_str, count]
			else:
				text += "[%s] %s%s: %s\n" % [timestamp, actor_desc, loc_desc, result_str]
				
			i = j
			
	elif view_mode == 1:
		# Standard view: title and result
		for entry in filtered_entries:
			var timestamp := str(entry.get("timestamp", ""))
			var title := str(entry.get("title", ""))
			var result_str := str(entry.get("result", title))
			if result_str != title and result_str != "":
				text += "[%s] %s => %s\n" % [timestamp, title, result_str]
			else:
				text += "[%s] %s\n" % [timestamp, title]
				
	else:
		# Detail view: dump all trace variables
		for entry in filtered_entries:
			var timestamp := str(entry.get("timestamp", ""))
			var title := str(entry.get("title", ""))
			var cat := str(entry.get("category", "world"))
			var cause := str(entry.get("direct_cause", ""))
			var result_str := str(entry.get("result", title))
			var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
			var trace: Dictionary = entry.get("trace", {})
			
			text += "[%s] [%s] %s\n" % [timestamp, cat, title]
			text += "    Actors: %s | Cause: %s | Result: %s\n" % [",".join(actors), cause, result_str]
			if not trace.is_empty():
				text += "    Trace:\n"
				for k in trace.keys():
					text += "      %s: %s\n" % [str(k), str(trace[k])]
			text += "\n"

	_log_label.text = text

func _on_log_entry_added(_entry: Dictionary) -> void:
	_refresh_text()
	_refresh_log()


func _on_time_advanced(_total_minutes: int) -> void:
	_refresh_text()


func _on_mode_changed(_mode: StringName) -> void:
	_refresh_text()


func _on_phase_changed(phase: StringName) -> void:
	_refresh_text()
	
	if phase == &"menu":
		if _mode_select_screen: _mode_select_screen.hide()
		if _char_creation_screen: _char_creation_screen.hide()
		if _world_init_screen: _world_init_screen.hide()
		if _time_control_panel: _time_control_panel.hide()
		if _main_menu_panel: _main_menu_panel.show()
		if _game_ui_container: _game_ui_container.hide()
		if _loading_label: _loading_label.hide()
	elif phase == &"mode_select":
		if _mode_select_screen: _mode_select_screen.show()
		if _char_creation_screen: _char_creation_screen.hide()
		if _world_init_screen: _world_init_screen.hide()
		if _time_control_panel: _time_control_panel.hide()
		if _main_menu_panel: _main_menu_panel.hide()
		if _game_ui_container: _game_ui_container.hide()
		if _loading_label: _loading_label.hide()
	elif phase == &"char_creation":
		if _mode_select_screen: _mode_select_screen.hide()
		if _char_creation_screen: _char_creation_screen.show()
		if _world_init_screen: _world_init_screen.hide()
		if _time_control_panel: _time_control_panel.hide()
		if _main_menu_panel: _main_menu_panel.hide()
		if _game_ui_container: _game_ui_container.hide()
		if _loading_label: _loading_label.hide()
	elif phase == &"world_init":
		if _mode_select_screen: _mode_select_screen.hide()
		if _char_creation_screen: _char_creation_screen.hide()
		if _main_menu_panel: _main_menu_panel.hide()
		if _game_ui_container: _game_ui_container.hide()
		if _loading_label: _loading_label.hide()
		if _time_control_panel: _time_control_panel.hide()
		if _world_init_screen: _world_init_screen.show()
	elif phase == &"main_play" or phase == &"running" or phase == &"ready":
		if _mode_select_screen: _mode_select_screen.hide()
		if _char_creation_screen: _char_creation_screen.hide()
		if _world_init_screen: _world_init_screen.hide()
		if _main_menu_panel: _main_menu_panel.hide()
		if _game_ui_container: _game_ui_container.show()
		if _time_control_panel: _time_control_panel.show()
		if _loading_label: _loading_label.hide()



func _on_test_action_pressed() -> void:
	if _sim_runner != null and _sim_runner.has_method("advance_one_day"):
		_sim_runner.call("advance_one_day", false, true)
		return
	EventLog.add_entry("你进行了一次基础修炼，修为略有精进。")


func show_event_modal(title: String, desc: String, options: Array[Dictionary] = []) -> void:
	if _event_modal != null and is_instance_valid(_event_modal):
		_event_modal.queue_free()

	_event_modal = PanelContainer.new()
	_event_modal.name = "EventModal"
	_event_modal.set_anchors_preset(Control.PRESET_CENTER)
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.6, 0.2)
	_event_modal.add_theme_stylebox_override("panel", panel_style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_event_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	var title_lbl := Label.new()
	title_lbl.name = "EventTitle"
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.name = "EventDesc"
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(desc_lbl)
	
	var hs := HSeparator.new()
	vbox.add_child(hs)
	
	var btn_vbox := VBoxContainer.new()
	btn_vbox.name = "EventOptions"
	vbox.add_child(btn_vbox)

	if options.is_empty():
		var btn := Button.new()
		btn.name = "EventOption_0"
		btn.text = "确定"
		btn.pressed.connect(func(): _close_event_modal())
		btn_vbox.add_child(btn)
	else:
		for i in range(options.size()):
			var opt: Dictionary = options[i]
			var btn := Button.new()
			btn.name = "EventOption_" + str(i)
			btn.text = opt.get("text", "选项")
			btn.pressed.connect(func():
				_close_event_modal()
				var callback: Callable = opt.get("callback", Callable())
				if callback.is_valid():
					callback.call()
			)
			btn_vbox.add_child(btn)

	add_child(_event_modal)

func _close_event_modal() -> void:
	if _event_modal != null and is_instance_valid(_event_modal):
		_event_modal.queue_free()
		_event_modal = null

# --- Character UI ---

func _build_character_ui() -> void:
	_character_panel = PanelContainer.new()
	_character_panel.name = "CharacterPanel"
	_character_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_character_panel.hide()
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.98)
	_character_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(_character_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_character_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	# Header
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var title := Label.new()
	title.text = "【 角色情报库 】"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_hbox.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): _character_panel.hide())
	header_hbox.add_child(close_btn)
	
	# Body
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)
	
	# Left: Roster
	var roster_vbox := VBoxContainer.new()
	roster_vbox.custom_minimum_size = Vector2(250, 0)
	hsplit.add_child(roster_vbox)
	
	var roster_title := Label.new()
	roster_title.text = "- 角色名册 -"
	roster_vbox.add_child(roster_title)
	
	_roster_list = ItemList.new()
	_roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_list.item_selected.connect(_on_roster_item_selected)
	roster_vbox.add_child(_roster_list)
	
	# Right: Detail + Timeline
	var right_vsplit := VSplitContainer.new()
	right_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_vsplit)
	
	var detail_vbox := VBoxContainer.new()
	detail_vbox.custom_minimum_size = Vector2(0, 200)
	right_vsplit.add_child(detail_vbox)
	
	var detail_title := Label.new()
	detail_title.text = "- 属性/关系/位置 -"
	detail_vbox.add_child(detail_title)
	
	_detail_label = RichTextLabel.new()
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.bbcode_enabled = true
	detail_vbox.add_child(_detail_label)
	
	var timeline_vbox := VBoxContainer.new()
	timeline_vbox.custom_minimum_size = Vector2(0, 200)
	right_vsplit.add_child(timeline_vbox)
	
	var timeline_title := Label.new()
	timeline_title.text = "- 近期经历 -"
	timeline_vbox.add_child(timeline_title)
	
	_timeline_label = RichTextLabel.new()
	_timeline_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_label.scroll_following = true
	_timeline_label.bbcode_enabled = true
	timeline_vbox.add_child(_timeline_label)


func _on_view_characters_pressed() -> void:
	_character_panel.show()
	_refresh_roster()

func _refresh_roster() -> void:
	_current_roster = CharacterService.get_roster(RunState.mode)
	_roster_list.clear()
	for c in _current_roster:
		_roster_list.add_item(str(c.get("display_name", "Unknown")))
	
	_detail_label.text = "请选择左侧角色查看详情。"
	_timeline_label.text = ""

func _on_roster_item_selected(index: int) -> void:
	if index < 0 or index >= _current_roster.size():
		return
	var character_id: StringName = StringName(_current_roster[index].get("id", ""))
	var view: Dictionary = CharacterService.get_character_view(character_id, 20, RunState.mode)
	if view.is_empty():
		_detail_label.text = "无法获取角色详情。"
		_timeline_label.text = ""
		return
	
	var detail: Dictionary = view.get("detail", {}) as Dictionary
	var text := ""
	text += "[b]%s[/b] (ID: %s)\n" % [detail.get("display_name", ""), detail.get("id", "")]
	text += "简介: %s\n" % [detail.get("summary", "")]
	
	var aff := detail.get("affiliation", {}) as Dictionary
	text += "所属: 地区[%s] 阵营[%s] 家族[%s]\n" % [aff.get("region_id", ""), aff.get("faction_id", ""), aff.get("family_id", "")]
	
	var attrs := detail.get("attributes", {}) as Dictionary
	text += "资质: %d | 信仰亲和: %d\n" % [attrs.get("talent_rank", 0), attrs.get("faith_affinity", 0)]
	
	var morality := ",".join(attrs.get("morality_tags", []))
	var temp := ",".join(attrs.get("temperament_tags", []))
	var roles := ",".join(attrs.get("role_tags", []))
	text += "特质: %s | 性格: %s | 身份: %s\n" % [morality, temp, roles]
	
	var rt := detail.get("runtime", {}) as Dictionary
	text += "当前需求: %s\n" % [rt.get("dominant_need", "无")]
	
	var goal := rt.get("active_goal", {}) as Dictionary
	text += "活跃目标: %s\n" % [goal.get("summary", "无")]
	
	var focus := rt.get("focus_state", {}) as Dictionary
	text += "关注度: %s | 位置: %s\n\n" % [focus.get("tier", "未知"), focus.get("location_id", "未知")]
	
	var region_id := str(aff.get("region_id", ""))
	if not region_id.is_empty():
		_map_focus_region_id = region_id
		text += "[color=green]★ 已将地图焦点同步至该区域[/color]"
	
	_detail_label.text = text
	
	var timeline: Array = view.get("timeline", []) as Array
	var tl_text := ""
	for entry in timeline:
		var tl_item: Dictionary = entry as Dictionary
		tl_text += "[color=gray][%s][/color] %s: %s\n" % [
			str(tl_item.get("timestamp", "")),
			str(tl_item.get("title", "")),
			str(tl_item.get("result", ""))
		]
	
	if timeline.is_empty():
		tl_text = "尚无经历。"
		
	_timeline_label.text = tl_text


# --- Map UI ---

func _build_map_ui() -> void:
	_map_panel = PanelContainer.new()
	_map_panel.name = "MapPanel"
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.hide()
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	_map_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(_map_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_map_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	# Header
	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var title := Label.new()
	title.text = "【 区域层级与分布地图 】"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_hbox.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): _map_panel.hide())
	header_hbox.add_child(close_btn)
	
	# Body
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)
	
	# Left: Region Tree
	var tree_vbox := VBoxContainer.new()
	tree_vbox.custom_minimum_size = Vector2(250, 0)
	hsplit.add_child(tree_vbox)
	
	var tree_title := Label.new()
	tree_title.text = "- 区域层级 -"
	tree_vbox.add_child(tree_title)
	
	_region_tree = Tree.new()
	_region_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_region_tree.hide_root = true
	_region_tree.item_selected.connect(_on_region_tree_item_selected)
	tree_vbox.add_child(_region_tree)
	
	# Right: Info & Characters
	var right_vsplit := VSplitContainer.new()
	right_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(right_vsplit)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.custom_minimum_size = Vector2(0, 150)
	right_vsplit.add_child(info_vbox)
	
	var info_title := Label.new()
	info_title.text = "- 区域情报与连通 -"
	info_vbox.add_child(info_title)
	
	_region_detail_label = RichTextLabel.new()
	_region_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_region_detail_label.bbcode_enabled = true
	info_vbox.add_child(_region_detail_label)
	
	var chars_vbox := VBoxContainer.new()
	chars_vbox.custom_minimum_size = Vector2(0, 200)
	right_vsplit.add_child(chars_vbox)
	
	var chars_title := Label.new()
	chars_title.text = "- 当前驻留角色 -"
	chars_vbox.add_child(chars_title)
	
	_region_characters_list = ItemList.new()
	_region_characters_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_region_characters_list.item_activated.connect(_on_region_character_activated)
	chars_vbox.add_child(_region_characters_list)


func _on_region_character_activated(index: int) -> void:
	var char_id := str(_region_characters_list.get_item_metadata(index))
	if not char_id.is_empty():
		_map_panel.hide()
		_character_panel.show()
		_refresh_roster()
		for i in range(_roster_list.item_count):
			if _current_roster[i].get("id", "") == char_id:
				_roster_list.select(i)
				_on_roster_item_selected(i)
				break


func _on_view_map_pressed() -> void:
	_map_panel.show()
	_refresh_map()


func _refresh_map() -> void:
	_region_tree.clear()
	_map_region_items.clear()
	
	var root: TreeItem = _region_tree.create_item()
	_current_regions = LocationService.get_all_regions(RunState.mode)
	
	var unassigned_regions: Array[Dictionary] = _current_regions.duplicate()
	var assigned_ids: Dictionary = {}
	var has_progress := true
	
	while has_progress and not unassigned_regions.is_empty():
		has_progress = false
		var i := 0
		while i < unassigned_regions.size():
			var r: Dictionary = unassigned_regions[i]
			var rid := str(r.get("id", ""))
			var pid := str(r.get("parent_region_id", ""))
			
			var parent_item: TreeItem = root
			if not pid.is_empty():
				if assigned_ids.has(pid):
					parent_item = _map_region_items[pid]
				else:
					# Skip this one for now, wait for parent to be assigned
					i += 1
					continue
			
			var item: TreeItem = _region_tree.create_item(parent_item)
			item.set_text(0, str(r.get("display_name", rid)))
			item.set_metadata(0, rid)
			_map_region_items[rid] = item
			assigned_ids[rid] = true
			
			unassigned_regions.remove_at(i)
			has_progress = true
			# We don't increment i because we removed an element
	
	# Any remaining ones are orphaned, attach to root
	for r in unassigned_regions:
		var rid := str(r.get("id", ""))
		var item: TreeItem = _region_tree.create_item(root)
		item.set_text(0, str(r.get("display_name", rid)) + " (未连接)")
		item.set_metadata(0, rid)
		_map_region_items[rid] = item
		
	_region_detail_label.text = "请在左侧选择一个区域以查看情报。"
	_region_characters_list.clear()
	
	if not _map_focus_region_id.is_empty() and _map_region_items.has(_map_focus_region_id):
		var item: TreeItem = _map_region_items[_map_focus_region_id]
		item.select(0)
		_region_tree.scroll_to_item(item)
		_on_region_tree_item_selected()


func _on_region_tree_item_selected() -> void:
	var item: TreeItem = _region_tree.get_selected()
	if item == null:
		return
		
	var rid := str(item.get_metadata(0))
	_map_focus_region_id = rid
	
	var r: Dictionary = {}
	for region in _current_regions:
		if str(region.get("id", "")) == rid:
			r = region
			break
			
	if r.is_empty():
		_region_detail_label.text = "未找到区域数据。"
		_region_characters_list.clear()
		return
		
	var text := ""
	text += "[b]%s[/b] (ID: %s)\n\n" % [r.get("display_name", ""), rid]
	text += "%s\n\n" % [r.get("summary", "")]
	
	var adj_ids: PackedStringArray = r.get("adjacent_region_ids", PackedStringArray())
	if adj_ids.is_empty():
		text += "[color=gray]无相邻连通区域[/color]"
	else:
		text += "连通区域:\n"
		for adj_id in adj_ids:
			var adj_name := str(adj_id)
			for region in _current_regions:
				if str(region.get("id", "")) == str(adj_id):
					adj_name = str(region.get("display_name", ""))
					break
			text += " - %s (%s)\n" % [adj_name, adj_id]
			
	_region_detail_label.text = text
	
	_region_characters_list.clear()
	var roster: Array[Dictionary] = CharacterService.get_roster(RunState.mode)
	for c in roster:
		if str(c.get("region_id", "")) == rid:
			var c_name := str(c.get("display_name", "Unknown"))
			var role := str(c.get("focus_tier", ""))
			var char_id := str(c.get("id", ""))
			var idx := _region_characters_list.add_item("%s (%s)" % [c_name, role])
			_region_characters_list.set_item_metadata(idx, char_id)
