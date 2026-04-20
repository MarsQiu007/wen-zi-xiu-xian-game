extends Control
class_name UIRoot

signal menu_new_game_requested(mode: StringName)
signal menu_continue_requested()
signal mode_selected(mode: StringName)
signal character_created(params: Dictionary)
signal world_initialized()

var _main_menu_panel: PanelContainer
var _main_menu_continue_btn: Button
var _main_menu_save_info_label: Label
var _mode_select_screen: PanelContainer
var _char_creation_screen: PanelContainer
var _game_ui_container: MarginContainer
var _world_init_screen: PanelContainer
var _time_control_panel: HBoxContainer
var _save_button: Button

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

# Left panel - NPC brief info
var _npc_brief_panel: PanelContainer
var _npc_name_label: Label
var _npc_realm_label: Label
var _npc_age_label: Label
var _npc_location_label: Label
var _npc_detail_btn: Button

# Left panel - Tab buttons
var _tab_button_box: VBoxContainer
var _tab_buttons: Dictionary = {}  # tab_name -> Button
var _active_tab: String = "log"  # Default tab

# Right panel - Content panels
var _right_content_panel: PanelContainer
var _log_content_panel: PanelContainer
var _map_content_panel: PanelContainer
var _map_hsplit: HSplitContainer
var _world_chars_panel: PanelContainer
var _favor_panel: PanelContainer
var _favor_list_vbox: VBoxContainer
var _favor_sort_mode: String = "favor"
var _inventory_panel: PanelContainer

# Map UI components
var _map_panel: PanelContainer
var _region_tree: Tree
var _region_detail_label: RichTextLabel
var _region_characters_list: ItemList
var _current_regions: Array[Dictionary] = []
var _map_region_items: Dictionary = {} # region_id -> TreeItem
var _map_focus_region_id: String = ""

# Embedded world chars panel
var _embedded_roster_list: ItemList
var _embedded_detail_label: RichTextLabel
var _embedded_sort_mode: String = "realm"

var EventLog: Node
var TimeService: Node
var RunState: Node
var CharacterService: Node
var LocationService: Node
var SaveService: Node

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
	if SaveService == null:
		SaveService = root_node.get_node_or_null("SaveService")


func bind_runner(runner: Node) -> void:
	_sim_runner = runner
	_refresh_text()
	_refresh_log()


func show_main_menu() -> void:
	_refresh_main_menu_continue_button()
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
	continue_btn.pressed.connect(func(): menu_continue_requested.emit())
	btn_vbox.add_child(continue_btn)
	_main_menu_continue_btn = continue_btn

	var save_info_label := Label.new()
	save_info_label.name = "SaveInfoLabel"
	save_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_info_label.modulate = Color(0.75, 0.9, 1.0)
	btn_vbox.add_child(save_info_label)
	_main_menu_save_info_label = save_info_label

	_refresh_main_menu_continue_button()


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

	_save_button = Button.new()
	_save_button.name = "SaveButton"
	_save_button.text = "保存"
	_save_button.pressed.connect(_on_save_pressed)
	status_hbox.add_child(_save_button)

	# --- Main Content Area (HSplitContainer) ---
	var content_hsplit := HSplitContainer.new()
	content_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hsplit)

	# --- Left Panel (ratio 3) ---
	var left_panel := PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 3.0
	content_hsplit.add_child(left_panel)
	
	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)

	# NPC Brief Info Area
	_npc_brief_panel = PanelContainer.new()
	_npc_brief_panel.name = "NPCBriefPanel"
	left_vbox.add_child(_npc_brief_panel)
	
	var npc_vbox := VBoxContainer.new()
	_npc_brief_panel.add_child(npc_vbox)
	
	var avatar_rect := ColorRect.new()
	avatar_rect.color = Color(0.3, 0.3, 0.4)
	avatar_rect.custom_minimum_size = Vector2(80, 80)
	avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	npc_vbox.add_child(avatar_rect)
	
	var avatar_lbl := Label.new()
	avatar_lbl.text = "头像"
	avatar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_rect.add_child(avatar_lbl)

	_npc_name_label = Label.new()
	_npc_name_label.text = "姓名: 未知"
	_npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_vbox.add_child(_npc_name_label)

	_npc_realm_label = Label.new()
	_npc_realm_label.text = "境界: 凡人"
	_npc_realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_vbox.add_child(_npc_realm_label)

	_npc_age_label = Label.new()
	_npc_age_label.text = "年龄: 未知"
	_npc_age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_vbox.add_child(_npc_age_label)

	_npc_location_label = Label.new()
	_npc_location_label.text = "位置: 未知"
	_npc_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_vbox.add_child(_npc_location_label)

	_npc_detail_btn = Button.new()
	_npc_detail_btn.text = "详情"
	_npc_detail_btn.pressed.connect(_on_view_characters_pressed)
	npc_vbox.add_child(_npc_detail_btn)

	# Separator
	var left_sep := HSeparator.new()
	left_vbox.add_child(left_sep)

	# Tab Buttons Area
	_tab_button_box = VBoxContainer.new()
	_tab_button_box.name = "TabButtonBox"
	_tab_button_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_button_box.add_theme_constant_override("separation", 8)
	left_vbox.add_child(_tab_button_box)

	var tabs := [
		{"id": "log", "name": "事件日志"},
		{"id": "map", "name": "世界地图"},
		{"id": "world_chars", "name": "世界角色"},
		{"id": "favor", "name": "人际好感"},
		{"id": "inventory", "name": "个人背包"}
	]

	for tab in tabs:
		var btn := Button.new()
		btn.text = tab["name"]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(func(): _on_tab_button_pressed(tab["id"]))
		_tab_button_box.add_child(btn)
		_tab_buttons[tab["id"]] = btn

	# --- Right Panel (ratio 7) ---
	_right_content_panel = PanelContainer.new()
	_right_content_panel.name = "RightPanel"
	_right_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_content_panel.size_flags_stretch_ratio = 7.0
	_right_content_panel.clip_contents = true
	content_hsplit.add_child(_right_content_panel)
	
	# Log Content Panel
	_log_content_panel = PanelContainer.new()
	_log_content_panel.name = "LogContentPanel"
	_log_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_content_panel.clip_contents = true
	_right_content_panel.add_child(_log_content_panel)
	
	var log_vbox := VBoxContainer.new()
	_log_content_panel.add_child(log_vbox)
	
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
	_log_category_filter_btn.add_item("所有类别")
	_log_category_filter_btn.set_item_metadata(0, "all")
	_log_category_filter_btn.add_item("社交")
	_log_category_filter_btn.set_item_metadata(1, "social")
	_log_category_filter_btn.add_item("修炼")
	_log_category_filter_btn.set_item_metadata(2, "cultivation")
	_log_category_filter_btn.add_item("探索")
	_log_category_filter_btn.set_item_metadata(3, "explore")
	_log_category_filter_btn.add_item("冲突")
	_log_category_filter_btn.set_item_metadata(4, "conflict")
	_log_category_filter_btn.add_item("系统")
	_log_category_filter_btn.set_item_metadata(5, "system")
	_known_categories = ["social", "cultivation", "explore", "conflict", "system"]
	_log_category_filter_btn.item_selected.connect(func(_idx): _refresh_log())
	log_toolbar.add_child(_log_category_filter_btn)
	
	_log_label = RichTextLabel.new()
	_log_label.name = "LogTextLabel"
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.bbcode_enabled = true
	log_vbox.add_child(_log_label)

	# Map Content Panel
	_map_content_panel = PanelContainer.new()
	_map_content_panel.name = "MapContentPanel"
	_map_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_content_panel.clip_contents = true
	_map_content_panel.hide()
	
	var map_vbox := VBoxContainer.new()
	map_vbox.name = "MapVBox"
	_map_content_panel.add_child(map_vbox)
	
	var map_toolbar := HBoxContainer.new()
	map_toolbar.add_theme_constant_override("separation", 8)
	map_vbox.add_child(map_toolbar)
	
	var map_title := Label.new()
	map_title.text = "- 区域地图 -"
	map_toolbar.add_child(map_title)
	
	var spacer_map := Control.new()
	spacer_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_toolbar.add_child(spacer_map)
	
	var fullscreen_map_btn := Button.new()
	fullscreen_map_btn.text = "全屏查看"
	fullscreen_map_btn.pressed.connect(_on_view_map_pressed)
	map_toolbar.add_child(fullscreen_map_btn)
	
	_right_content_panel.add_child(_map_content_panel)

	# World Chars Content Panel
	_world_chars_panel = PanelContainer.new()
	_world_chars_panel.name = "WorldCharsContentPanel"
	_world_chars_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_chars_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world_chars_panel.clip_contents = true
	_world_chars_panel.hide()
	
	var chars_vbox := VBoxContainer.new()
	_world_chars_panel.add_child(chars_vbox)
	
	var chars_toolbar := HBoxContainer.new()
	chars_toolbar.add_theme_constant_override("separation", 8)
	chars_vbox.add_child(chars_toolbar)
	
	var chars_title := Label.new()
	chars_title.text = "- 世界角色 -"
	chars_toolbar.add_child(chars_title)
	
	var chars_spacer := Control.new()
	chars_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chars_toolbar.add_child(chars_spacer)
	
	var chars_sort_realm_btn := Button.new()
	chars_sort_realm_btn.text = "按修为"
	chars_sort_realm_btn.pressed.connect(func():
		_embedded_sort_mode = "realm"
		_refresh_world_characters()
	)
	chars_toolbar.add_child(chars_sort_realm_btn)
	
	var chars_sort_favor_btn := Button.new()
	chars_sort_favor_btn.text = "按好感"
	chars_sort_favor_btn.pressed.connect(func():
		_embedded_sort_mode = "favor"
		_refresh_world_characters()
	)
	chars_toolbar.add_child(chars_sort_favor_btn)
	
	var chars_sort_region_btn := Button.new()
	chars_sort_region_btn.text = "按区域"
	chars_sort_region_btn.pressed.connect(func():
		_embedded_sort_mode = "region"
		_refresh_world_characters()
	)
	chars_toolbar.add_child(chars_sort_region_btn)
	
	var chars_hsplit := HSplitContainer.new()
	chars_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chars_vbox.add_child(chars_hsplit)
	
	_embedded_roster_list = ItemList.new()
	_embedded_roster_list.custom_minimum_size = Vector2(150, 0)
	_embedded_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_embedded_roster_list.item_selected.connect(_on_embedded_roster_selected)
	chars_hsplit.add_child(_embedded_roster_list)
	
	var detail_vbox := VBoxContainer.new()
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.size_flags_stretch_ratio = 2.0
	chars_hsplit.add_child(detail_vbox)
	
	_embedded_detail_label = RichTextLabel.new()
	_embedded_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_embedded_detail_label.bbcode_enabled = true
	detail_vbox.add_child(_embedded_detail_label)
	
	var view_full_btn := Button.new()
	view_full_btn.text = "查看完整信息"
	view_full_btn.pressed.connect(func():
		var idxs = _embedded_roster_list.get_selected_items()
		if idxs.size() > 0:
			var cid = _embedded_roster_list.get_item_metadata(idxs[0])
			_open_full_character_panel(cid)
		else:
			_character_panel.show()
			_refresh_roster()
	)
	detail_vbox.add_child(view_full_btn)
	
	_right_content_panel.add_child(_world_chars_panel)

	# Favor Content Panel
	_favor_panel = PanelContainer.new()
	_favor_panel.name = "FavorContentPanel"
	_favor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_favor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_favor_panel.clip_contents = true
	_favor_panel.hide()
	
	var favor_margin := MarginContainer.new()
	favor_margin.add_theme_constant_override("margin_left", 20)
	favor_margin.add_theme_constant_override("margin_right", 20)
	favor_margin.add_theme_constant_override("margin_top", 20)
	favor_margin.add_theme_constant_override("margin_bottom", 20)
	_favor_panel.add_child(favor_margin)

	var favor_vbox := VBoxContainer.new()
	favor_margin.add_child(favor_vbox)

	var favor_title := Label.new()
	favor_title.text = "- 人际好感 -"
	favor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	favor_vbox.add_child(favor_title)
	
	var sort_hbox := HBoxContainer.new()
	sort_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sort_hbox.add_theme_constant_override("separation", 20)
	favor_vbox.add_child(sort_hbox)
	
	var sort_favor_btn := Button.new()
	sort_favor_btn.text = "按好感排序"
	sort_favor_btn.pressed.connect(_on_sort_favor_pressed)
	sort_hbox.add_child(sort_favor_btn)
	
	var sort_type_btn := Button.new()
	sort_type_btn.text = "按类型排序"
	sort_type_btn.pressed.connect(_on_sort_type_pressed)
	sort_hbox.add_child(sort_type_btn)
	
	var favor_sep := HSeparator.new()
	favor_vbox.add_child(favor_sep)

	var favor_scroll := ScrollContainer.new()
	favor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	favor_vbox.add_child(favor_scroll)
	
	_favor_list_vbox = VBoxContainer.new()
	_favor_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	favor_scroll.add_child(_favor_list_vbox)

	_right_content_panel.add_child(_favor_panel)

	# Inventory Content Panel Placeholder
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryContentPanel"
	_inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.clip_contents = true
	_inventory_panel.hide()
	var inv_lbl := Label.new()
	inv_lbl.text = "背包功能正在开发中"
	inv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_panel.add_child(inv_lbl)
	_right_content_panel.add_child(_inventory_panel)
	
	_active_tab = "log"
	_update_tab_highlight()
	_update_right_content_visibility()


func _on_tab_button_pressed(tab_name: String) -> void:
	_active_tab = tab_name
	_update_tab_highlight()
	_update_right_content_visibility()
	
	if _active_tab == "map":
		_refresh_map()
	elif _active_tab == "world_chars":
		_refresh_world_characters()
	elif _active_tab == "favor":
		_refresh_favor_panel()

func _on_sort_favor_pressed() -> void:
	_favor_sort_mode = "favor"
	_refresh_favor_panel()

func _on_sort_type_pressed() -> void:
	_favor_sort_mode = "type"
	_refresh_favor_panel()

func _refresh_favor_panel() -> void:
	if _favor_list_vbox == null:
		return
		
	for child in _favor_list_vbox.get_children():
		child.queue_free()
		
	if _sim_runner == null or not _sim_runner.has_method("get_snapshot"):
		var lbl := Label.new()
		lbl.text = "暂无关系数据。"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_favor_list_vbox.add_child(lbl)
		return
		
	var snapshot: Dictionary = _sim_runner.get_snapshot()
	var net: Dictionary = snapshot.get("relationship_network", {})
	var edges: Array = net.get("edges", [])
	
	if edges.is_empty():
		var lbl := Label.new()
		lbl.text = "尚未结识任何角色。"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_favor_list_vbox.add_child(lbl)
		return
		
	var characters: Array = _sim_runner.get_runtime_characters()
	if characters.is_empty():
		return
		
	var player_id := str(characters[0].get("id", ""))
	if player_id.is_empty():
		return
		
	var char_names: Dictionary = {}
	var roster: Array[Dictionary] = CharacterService.get_roster(RunState.mode)
	for c in roster:
		char_names[str(c.get("id", ""))] = str(c.get("display_name", "Unknown"))
		
	var rels: Array[Dictionary] = []
	for edge in edges:
		var edge_dict: Dictionary = edge as Dictionary
		var src := str(edge_dict.get("source_id", ""))
		var tgt := str(edge_dict.get("target_id", ""))
		
		if src == player_id:
			var target_name: String = char_names.get(tgt, tgt)
			var type_str := str(edge_dict.get("relation_type", "unknown"))
			var favor := int(edge_dict.get("favor", 0))
			rels.append({"name": target_name, "type": type_str, "favor": favor})
		elif tgt == player_id:
			var source_name: String = char_names.get(src, src)
			var type_str := str(edge_dict.get("relation_type", "unknown"))
			var favor := int(edge_dict.get("favor", 0))
			rels.append({"name": source_name, "type": type_str, "favor": favor})
			
	if _favor_sort_mode == "favor":
		rels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["favor"]) > int(b["favor"]))
	else:
		rels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: 
			if str(a["type"]) == str(b["type"]):
				return int(a["favor"]) > int(b["favor"])
			return str(a["type"]) < str(b["type"])
		)
		
	if rels.is_empty():
		var lbl := Label.new()
		lbl.text = "暂无人际关系。"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_favor_list_vbox.add_child(lbl)
		return
		
	for rel in rels:
		var rel_dict: Dictionary = rel as Dictionary
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		_favor_list_vbox.add_child(hbox)
		
		var name_lbl := Label.new()
		name_lbl.text = str(rel_dict["name"])
		name_lbl.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(name_lbl)
		
		var type_lbl := Label.new()
		type_lbl.text = str(rel_dict["type"])
		type_lbl.custom_minimum_size = Vector2(100, 0)
		type_lbl.modulate = Color(0.7, 0.7, 1.0)
		hbox.add_child(type_lbl)
		
		var favor_lbl := Label.new()
		var fav_val: int = rel_dict["favor"]
		favor_lbl.text = "%+d" % fav_val if fav_val > 0 else str(fav_val)
		if fav_val > 0:
			favor_lbl.modulate = Color(0.2, 1.0, 0.2)
		elif fav_val < 0:
			favor_lbl.modulate = Color(1.0, 0.2, 0.2)
		else:
			favor_lbl.modulate = Color(0.7, 0.7, 0.7)
		hbox.add_child(favor_lbl)

func _update_tab_highlight() -> void:
	for tab_name in _tab_buttons:
		var btn: Button = _tab_buttons[tab_name]
		if tab_name == _active_tab:
			btn.modulate = Color(0.2, 1.0, 0.2)  # Green highlight
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)  # Normal

func _update_right_content_visibility() -> void:
	if _log_content_panel:
		_log_content_panel.visible = (_active_tab == "log")
	if _map_content_panel:
		_map_content_panel.visible = (_active_tab == "map")
	if _world_chars_panel:
		_world_chars_panel.visible = (_active_tab == "world_chars")
	if _favor_panel:
		_favor_panel.visible = (_active_tab == "favor")
	if _inventory_panel:
		_inventory_panel.visible = (_active_tab == "inventory")

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

	# Update NPC brief info
	var has_char_data := false
	if _sim_runner != null and _sim_runner.has_method("get_runtime_characters"):
		var characters: Array = _sim_runner.get_runtime_characters()
		if characters.size() > 0:
			var player_id: StringName = StringName(characters[0].get("id", ""))
			if player_id != StringName(""):
				var view: Dictionary = CharacterService.get_character_view(player_id, 20, RunState.mode)
				if not view.is_empty():
					has_char_data = true
					var detail: Dictionary = view.get("detail", {})
					var attrs: Dictionary = detail.get("attributes", {})
					var aff: Dictionary = detail.get("affiliation", {})
					var rt: Dictionary = detail.get("runtime", {})
					
					var p_name: String = str(detail.get("display_name", "未知"))
					var p_realm: String = str(attrs.get("realm", "凡人"))
					var p_age: String = str(detail.get("age", attrs.get("age", "未知")))
					
					var p_loc: String = str(aff.get("region_id", "未知"))
					var f_state: Dictionary = rt.get("focus_state", {})
					if not f_state.is_empty() and str(f_state.get("location_id", "")) != "":
						p_loc = str(f_state.get("location_id", ""))
					
					if _npc_name_label: _npc_name_label.text = "姓名: %s" % p_name
					if _npc_realm_label: _npc_realm_label.text = "境界: %s" % p_realm
					if _npc_age_label: _npc_age_label.text = "年龄: %s" % p_age
					if _npc_location_label: _npc_location_label.text = "位置: %s" % p_loc
					
	if not has_char_data:
		if _npc_name_label: _npc_name_label.text = "姓名: 未知"
		if _npc_realm_label: _npc_realm_label.text = "境界: 凡人"
		if _npc_age_label: _npc_age_label.text = "年龄: 未知"
		if _npc_location_label: _npc_location_label.text = "位置: 未知"

func _refresh_log() -> void:
	if _log_label == null:
		return
		
	var view_mode := _log_view_mode_btn.get_selected_id()
	
	var actor_filter := ""
	if _log_actor_filter_btn.get_selected_id() > 0:
		actor_filter = _log_actor_filter_btn.get_item_text(_log_actor_filter_btn.get_selected_id())
		
	var category_filter := ""
	if _log_category_filter_btn.get_selected_id() > 0:
		var meta = _log_category_filter_btn.get_item_metadata(_log_category_filter_btn.get_selected_id())
		if meta != null:
			category_filter = str(meta)
		else:
			category_filter = _log_category_filter_btn.get_item_text(_log_category_filter_btn.get_selected_id())

	var filtered_entries: Array[Dictionary] = []
	
	for entry in EventLog.entries:
		var cat := str(entry.get("category", "world"))
		if not cat in _known_categories and cat != "world":
			_known_categories.append(cat)
			_log_category_filter_btn.add_item(cat)
			_log_category_filter_btn.set_item_metadata(_log_category_filter_btn.get_item_count() - 1, cat)
			
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
			
			var colored_actors := []
			for a in actors:
				colored_actors.append("[color=cyan]" + str(a) + "[/color]")
			var actor_desc := ",".join(colored_actors) if colored_actors.size() > 0 else "系统"
			
			while j < filtered_entries.size():
				var next_entry: Dictionary = filtered_entries[j]
				var next_title := str(next_entry.get("title", ""))
				var next_trace: Dictionary = next_entry.get("trace", {})
				var next_location := str(next_trace.get("location", ""))
				var next_actors: PackedStringArray = next_entry.get("actor_ids", PackedStringArray())
				var next_result := str(next_entry.get("result", next_title))
				var next_colored_actors := []
				for a in next_actors:
					next_colored_actors.append("[color=cyan]" + str(a) + "[/color]")
				var next_actor_desc := ",".join(next_colored_actors) if next_colored_actors.size() > 0 else "系统"
				
				# Same title, actors, location, and result can be aggregated
				if next_title == title and next_location == location and next_result == result_str and next_actor_desc == actor_desc:
					count += 1
					j += 1
					continue
				break
				
			var loc_desc := (" @ " + location) if location != "" else ""
			var day := int(entry.get("day", 1))
			var minute_time := int(entry.get("minute_of_day", 0))
			var timestamp := "第%d天 %02d:%02d" % [day, int(minute_time / 60.0), minute_time % 60]
			
			if count > 1:
				text += "[[color=gray]%s[/color]] %s%s: %s (x%d)\n" % [timestamp, actor_desc, loc_desc, result_str, count]
			else:
				text += "[[color=gray]%s[/color]] %s%s: %s\n" % [timestamp, actor_desc, loc_desc, result_str]
				
			i = j
			
	elif view_mode == 1:
		# Standard view: title and result
		for entry in filtered_entries:
			var day := int(entry.get("day", 1))
			var minute_time := int(entry.get("minute_of_day", 0))
			var timestamp := "第%d天 %02d:%02d" % [day, int(minute_time / 60.0), minute_time % 60]
			var title := str(entry.get("title", ""))
			var result_str := str(entry.get("result", title))
			
			var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
			var colored_actors := []
			for a in actors:
				colored_actors.append("[color=cyan]" + str(a) + "[/color]")
			var actor_desc := ",".join(colored_actors) if colored_actors.size() > 0 else "系统"
			
			if result_str != title and result_str != "":
				text += "[[color=gray]%s[/color]] %s => %s\n" % [timestamp, title, result_str]
			else:
				text += "[[color=gray]%s[/color]] %s: %s\n" % [timestamp, actor_desc, title]
				
	else:
		# Detail view: dump all trace variables
		for entry in filtered_entries:
			var day := int(entry.get("day", 1))
			var minute_time := int(entry.get("minute_of_day", 0))
			var timestamp := "第%d天 %02d:%02d" % [day, int(minute_time / 60.0), minute_time % 60]
			var title := str(entry.get("title", ""))
			var cat := str(entry.get("category", "world"))
			var cause := str(entry.get("direct_cause", ""))
			var result_str := str(entry.get("result", title))
			var actors: PackedStringArray = entry.get("actor_ids", PackedStringArray())
			var trace: Dictionary = entry.get("trace", {})
			
			text += "[[color=gray]%s[/color]] [%s] %s\n" % [timestamp, cat, title]
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


func _on_save_pressed() -> void:
	if SaveService == null:
		EventLog.add_entry("保存失败：SaveService 不可用")
		return
	if _sim_runner == null or not _sim_runner.has_method("get_snapshot"):
		EventLog.add_entry("保存失败：SimulationRunner 不可用")
		return
	var snapshot: Dictionary = _sim_runner.get_snapshot()
	var save_ok: bool = SaveService.save_game(snapshot)
	if save_ok:
		EventLog.add_entry("保存成功")
	else:
		var save_error := "unknown"
		if SaveService.has_method("get_last_error"):
			save_error = str(SaveService.get_last_error())
		EventLog.add_entry("保存失败：%s" % save_error)


func _refresh_main_menu_continue_button() -> void:
	if _main_menu_continue_btn == null:
		return
	if SaveService == null:
		_main_menu_continue_btn.disabled = true
		_main_menu_continue_btn.text = "继续游戏（存档服务不可用）"
		if _main_menu_save_info_label != null:
			_main_menu_save_info_label.text = ""
		return
	if not SaveService.has_method("has_save_slot") or not SaveService.has_method("get_save_info"):
		_main_menu_continue_btn.disabled = true
		_main_menu_continue_btn.text = "继续游戏（功能不可用）"
		if _main_menu_save_info_label != null:
			_main_menu_save_info_label.text = ""
		return

	if not SaveService.has_save_slot():
		_main_menu_continue_btn.disabled = true
		_main_menu_continue_btn.text = "继续游戏（无存档）"
		if _main_menu_save_info_label != null:
			_main_menu_save_info_label.text = ""
		return

	_main_menu_continue_btn.disabled = false
	_main_menu_continue_btn.text = "继续游戏"

	var save_info: Dictionary = SaveService.get_save_info()
	if not bool(save_info.get("ok", false)):
		if _main_menu_save_info_label != null:
			_main_menu_save_info_label.text = "存档信息读取失败"
		return

	var timestamp := int(save_info.get("timestamp", 0))
	var time_text := Time.get_datetime_string_from_unix_time(timestamp, true)
	if _main_menu_save_info_label != null:
		_main_menu_save_info_label.text = "存档时间：%s | 模式：凡人" % time_text


func _extract_snapshot_from_save_payload(loaded_data: Dictionary) -> Dictionary:
	var wrapped_snapshot: Variant = loaded_data.get("simulation_snapshot", {})
	if wrapped_snapshot is Dictionary:
		var snapshot: Dictionary = wrapped_snapshot
		if not snapshot.is_empty():
			return snapshot

	if loaded_data.has("seed") and loaded_data.has("runtime_characters"):
		return loaded_data

	return {}


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
	_open_full_character_panel("")

func _open_full_character_panel(target_id: String) -> void:
	_character_panel.show()
	_refresh_roster()
	if not target_id.is_empty():
		for i in range(_roster_list.item_count):
			if _current_roster[i].get("id", "") == target_id:
				_roster_list.select(i)
				_on_roster_item_selected(i)
				break

func _refresh_world_characters() -> void:
	if _embedded_roster_list == null:
		return
		
	var chars = CharacterService.get_roster(RunState.mode)
	
	if _embedded_sort_mode == "realm":
		chars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("realm", 0)) > int(b.get("realm", 0))
		)
	elif _embedded_sort_mode == "region":
		chars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("region_id", "")) < str(b.get("region_id", ""))
		)
	elif _embedded_sort_mode == "favor":
		# Assuming favor sorting requires simulation snapshot
		var edges := []
		if _sim_runner and _sim_runner.has_method("get_snapshot"):
			var snap: Dictionary = _sim_runner.get_snapshot()
			edges = snap.get("relationship_network", {}).get("edges", [])
		var player_id := ""
		if _sim_runner and _sim_runner.has_method("get_runtime_characters"):
			var rc = _sim_runner.get_runtime_characters()
			if not rc.is_empty(): player_id = str(rc[0].get("id", ""))
		
		var favors := {}
		for e in edges:
			if str(e.get("source_id", "")) == player_id:
				favors[str(e.get("target_id", ""))] = int(e.get("favor", 0))
			elif str(e.get("target_id", "")) == player_id:
				favors[str(e.get("source_id", ""))] = int(e.get("favor", 0))
				
		chars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var fa := int(favors.get(str(a.get("id", "")), 0))
			var fb := int(favors.get(str(b.get("id", "")), 0))
			return fa > fb
		)
	
	_embedded_roster_list.clear()
	for c in chars:
		var txt := str(c.get("display_name", "Unknown"))
		if _embedded_sort_mode == "region":
			txt += " [%s]" % str(c.get("region_id", "未知"))
		var idx = _embedded_roster_list.add_item(txt)
		_embedded_roster_list.set_item_metadata(idx, str(c.get("id", "")))
		
	_embedded_detail_label.text = "请选择左侧角色查看详情。"

func _on_embedded_roster_selected(index: int) -> void:
	if index < 0:
		return
	var cid := str(_embedded_roster_list.get_item_metadata(index))
	var view: Dictionary = CharacterService.get_character_view(StringName(cid), 5, RunState.mode)
	if view.is_empty():
		_embedded_detail_label.text = "无法获取角色详情。"
		return
		
	var detail: Dictionary = view.get("detail", {}) as Dictionary
	var text := ""
	text += "[b]%s[/b] (ID: %s)\n" % [detail.get("display_name", ""), cid]
	var aff := detail.get("affiliation", {}) as Dictionary
	text += "位置: %s\n" % [aff.get("region_id", "")]
	
	var attrs := detail.get("attributes", {}) as Dictionary
	text += "特质: %s\n" % [",".join(attrs.get("morality_tags", []))]
	text += "性格: %s\n\n" % [",".join(attrs.get("temperament_tags", []))]
	
	text += "[b]- 近期行为 -[/b]\n"
	var timeline: Array = view.get("timeline", []) as Array
	for i in range(min(5, timeline.size())):
		var t = timeline[i]
		text += "[color=gray][%s][/color] %s: %s\n" % [t.get("timestamp", ""), t.get("title", ""), t.get("result", "")]
	if timeline.is_empty():
		text += "尚无近期行为。"
	_embedded_detail_label.text = text

func _refresh_roster() -> void:
	if CharacterService == null or RunState == null:
		_current_roster.clear()
		_roster_list.clear()
		_detail_label.text = "角色服务不可用。"
		_timeline_label.text = ""
		return

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
	close_btn.pressed.connect(func():
		_map_panel.hide()
		if _map_hsplit and _map_hsplit.get_parent() != _map_content_panel.get_node("MapVBox"):
			_map_hsplit.get_parent().remove_child(_map_hsplit)
			_map_content_panel.get_node("MapVBox").add_child(_map_hsplit)
	)
	header_hbox.add_child(close_btn)
	
	# Body
	_map_hsplit = HSplitContainer.new()
	_map_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_content_panel.get_node("MapVBox").add_child(_map_hsplit)
	
	# Left: Region Tree
	var tree_vbox := VBoxContainer.new()
	tree_vbox.custom_minimum_size = Vector2(250, 0)
	_map_hsplit.add_child(tree_vbox)
	
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
	_map_hsplit.add_child(right_vsplit)
	
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
		if index < 0 or index >= _current_roster.size():
			return
		for i in range(_roster_list.item_count):
			if i < 0 or i >= _current_roster.size():
				continue
			if _current_roster[i].get("id", "") == char_id:
				_roster_list.select(i)
				_on_roster_item_selected(i)
				break


func _on_view_map_pressed() -> void:
	if _map_hsplit and _map_panel:
		var map_vbox = _map_panel.get_child(0).get_child(0) # margin -> vbox
		if _map_hsplit.get_parent() != map_vbox:
			_map_hsplit.get_parent().remove_child(_map_hsplit)
			map_vbox.add_child(_map_hsplit)
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
