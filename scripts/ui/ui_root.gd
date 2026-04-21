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
var _inventory_item_list: ItemList
var _inventory_detail_label: RichTextLabel
var _inventory_equipment_label: RichTextLabel
var _inventory_stats_label: RichTextLabel
var _inventory_equip_btn: Button
var _inventory_use_btn: Button
var _inventory_drop_btn: Button
var _inventory_selected_record: Dictionary = {}
var _inventory_entries: Array[Dictionary] = []
var _inventory_item_defs: Dictionary = {}
var _inventory_catalog: Resource

# Crafting UI components
var _crafting_panel: PanelContainer
var _crafting_recipe_list: ItemList
var _crafting_detail_label: RichTextLabel
var _crafting_btn: Button
var _crafting_type_filter: OptionButton
var _current_recipes: Array[Resource] = []
var _crafting_selected_recipe: Resource = null

# Technique UI components
var _technique_panel: PanelContainer
var _technique_list: ItemList
var _technique_detail_label: RichTextLabel
var _technique_equip_btn: Button
var _technique_meditate_btn: Button
var _technique_slot_option: OptionButton
var _learned_techniques: Array[Dictionary] = []
var _technique_selected_id: String = ""

# Trade UI components
var _trade_panel: PanelContainer
var _trade_goods_list: ItemList
var _trade_detail_label: RichTextLabel
var _trade_buy_btn: Button
var _trade_sell_btn: Button
var _trade_spirit_stone_label: Label
var _trade_goods: Array[Dictionary] = []
var _trade_selected_good: Dictionary = {}

# Combat Popup UI components
var _combat_panel: PanelContainer
var _combat_player_hp_bar: ProgressBar
var _combat_enemy_hp_bar: ProgressBar
var _combat_player_hp_label: Label
var _combat_enemy_hp_label: Label
var _combat_log_label: RichTextLabel
var _combat_attack_btn: Button
var _combat_item_btn: Button
var _combat_flee_btn: Button
var _combat_result_label: RichTextLabel


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
	_inventory_catalog = null
	_refresh_text()
	_refresh_log()
	_refresh_inventory_panel()


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
				{"id": "inventory", "name": "个人背包"},
		{"id": "crafting", "name": "炼丹炼器"},
		{"id": "technique", "name": "功法"},
		{"id": "trade", "name": "交易"}
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

	# Inventory Content Panel
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryContentPanel"
	_inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_panel.clip_contents = true
	_inventory_panel.hide()

	var inv_vbox := VBoxContainer.new()
	_inventory_panel.add_child(inv_vbox)

	var inv_title := Label.new()
	inv_title.text = "- 个人背包 -"
	inv_vbox.add_child(inv_title)

	var inv_hsplit := HSplitContainer.new()
	inv_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_vbox.add_child(inv_hsplit)

	_inventory_item_list = ItemList.new()
	_inventory_item_list.custom_minimum_size = Vector2(260, 0)
	_inventory_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_item_list.item_selected.connect(_on_inventory_item_selected)
	inv_hsplit.add_child(_inventory_item_list)

	var inv_right_vsplit := VSplitContainer.new()
	inv_right_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_hsplit.add_child(inv_right_vsplit)

	_inventory_detail_label = RichTextLabel.new()
	_inventory_detail_label.bbcode_enabled = true
	_inventory_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_detail_label.text = "请选择左侧物品查看详情。"
	inv_right_vsplit.add_child(_inventory_detail_label)

	var inv_action_hbox := HBoxContainer.new()
	inv_action_hbox.add_theme_constant_override("separation", 8)
	inv_right_vsplit.add_child(inv_action_hbox)

	_inventory_equip_btn = Button.new()
	_inventory_equip_btn.text = "装备"
	_inventory_equip_btn.disabled = true
	_inventory_equip_btn.pressed.connect(_on_inventory_equip_pressed)
	inv_action_hbox.add_child(_inventory_equip_btn)

	_inventory_use_btn = Button.new()
	_inventory_use_btn.text = "使用"
	_inventory_use_btn.disabled = true
	_inventory_use_btn.pressed.connect(_on_inventory_use_pressed)
	inv_action_hbox.add_child(_inventory_use_btn)

	_inventory_drop_btn = Button.new()
	_inventory_drop_btn.text = "丢弃1个"
	_inventory_drop_btn.disabled = true
	_inventory_drop_btn.pressed.connect(_on_inventory_drop_pressed)
	inv_action_hbox.add_child(_inventory_drop_btn)

	var inv_summary_vbox := VBoxContainer.new()
	inv_summary_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_right_vsplit.add_child(inv_summary_vbox)

	_inventory_equipment_label = RichTextLabel.new()
	_inventory_equipment_label.bbcode_enabled = true
	_inventory_equipment_label.custom_minimum_size = Vector2(0, 120)
	_inventory_equipment_label.text = "[b]- 已装备槽位 -[/b]\n暂无"
	inv_summary_vbox.add_child(_inventory_equipment_label)

	_inventory_stats_label = RichTextLabel.new()
	_inventory_stats_label.bbcode_enabled = true
	_inventory_stats_label.custom_minimum_size = Vector2(0, 140)
	_inventory_stats_label.text = "[b]- 属性总览 -[/b]\n暂无"
	inv_summary_vbox.add_child(_inventory_stats_label)

	_right_content_panel.add_child(_inventory_panel)

	# Crafting Content Panel
	_crafting_panel = PanelContainer.new()
	_crafting_panel.name = "CraftingContentPanel"
	_crafting_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crafting_panel.clip_contents = true
	_crafting_panel.hide()
	
	var craft_vbox := VBoxContainer.new()
	_crafting_panel.add_child(craft_vbox)
	
	var craft_toolbar := HBoxContainer.new()
	craft_toolbar.add_theme_constant_override("separation", 8)
	craft_vbox.add_child(craft_toolbar)
	
	var craft_title := Label.new()
	craft_title.text = "- 炼丹与炼器 -"
	craft_toolbar.add_child(craft_title)
	
	var craft_spacer := Control.new()
	craft_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_toolbar.add_child(craft_spacer)
	
	_crafting_type_filter = OptionButton.new()
	_crafting_type_filter.add_item("全部配方")
	_crafting_type_filter.set_item_metadata(0, "all")
	_crafting_type_filter.add_item("炼丹 (Alchemy)")
	_crafting_type_filter.set_item_metadata(1, "alchemy")
	_crafting_type_filter.add_item("炼器 (Forge)")
	_crafting_type_filter.set_item_metadata(2, "forge")
	_crafting_type_filter.item_selected.connect(func(_idx): _refresh_crafting_panel())
	craft_toolbar.add_child(_crafting_type_filter)
	
	var craft_hsplit := HSplitContainer.new()
	craft_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_vbox.add_child(craft_hsplit)
	
	_crafting_recipe_list = ItemList.new()
	_crafting_recipe_list.custom_minimum_size = Vector2(250, 0)
	_crafting_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_recipe_list.item_selected.connect(_on_crafting_recipe_selected)
	craft_hsplit.add_child(_crafting_recipe_list)
	
	var c_detail_vbox := VBoxContainer.new()
	c_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_detail_vbox.size_flags_stretch_ratio = 2.0
	craft_hsplit.add_child(c_detail_vbox)
	
	_crafting_detail_label = RichTextLabel.new()
	_crafting_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crafting_detail_label.bbcode_enabled = true
	c_detail_vbox.add_child(_crafting_detail_label)
	
	var craft_btn_margin := MarginContainer.new()
	craft_btn_margin.add_theme_constant_override("margin_top", 10)
	craft_btn_margin.add_theme_constant_override("margin_bottom", 10)
	c_detail_vbox.add_child(craft_btn_margin)
	
	_crafting_btn = Button.new()
	_crafting_btn.text = "开始制作"
	_crafting_btn.custom_minimum_size = Vector2(0, 40)
	_crafting_btn.disabled = true
	_crafting_btn.pressed.connect(_on_crafting_btn_pressed)
	craft_btn_margin.add_child(_crafting_btn)
	
	_right_content_panel.add_child(_crafting_panel)
	
	# Technique Content Panel
	_technique_panel = PanelContainer.new()
	_technique_panel.name = "TechniqueContentPanel"
	_technique_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_technique_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_technique_panel.clip_contents = true
	_technique_panel.hide()
	
	var tech_vbox := VBoxContainer.new()
	_technique_panel.add_child(tech_vbox)
	
	var tech_title := Label.new()
	tech_title.text = "- 功法 -"
	tech_vbox.add_child(tech_title)
	
	var tech_hsplit := HSplitContainer.new()
	tech_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tech_vbox.add_child(tech_hsplit)
	
	_technique_list = ItemList.new()
	_technique_list.custom_minimum_size = Vector2(250, 0)
	_technique_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_technique_list.item_selected.connect(_on_technique_item_selected)
	tech_hsplit.add_child(_technique_list)
	
	var tech_right_vbox := VBoxContainer.new()
	tech_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_right_vbox.size_flags_stretch_ratio = 2.0
	tech_hsplit.add_child(tech_right_vbox)
	
	_technique_detail_label = RichTextLabel.new()
	_technique_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_technique_detail_label.bbcode_enabled = true
	_technique_detail_label.text = "请选择左侧功法查看详情。"
	tech_right_vbox.add_child(_technique_detail_label)
	
	var tech_action_hbox := HBoxContainer.new()
	tech_action_hbox.add_theme_constant_override("separation", 8)
	tech_right_vbox.add_child(tech_action_hbox)
	
	_technique_slot_option = OptionButton.new()
	_technique_slot_option.add_item("martial_1")
	_technique_slot_option.add_item("martial_2")
	_technique_slot_option.add_item("utility_1")
	tech_action_hbox.add_child(_technique_slot_option)
	
	_technique_equip_btn = Button.new()
	_technique_equip_btn.text = "装备"
	_technique_equip_btn.disabled = true
	_technique_equip_btn.pressed.connect(_on_technique_equip_pressed)
	tech_action_hbox.add_child(_technique_equip_btn)
	
	_technique_meditate_btn = Button.new()
	_technique_meditate_btn.text = "参悟"
	_technique_meditate_btn.disabled = true
	_technique_meditate_btn.pressed.connect(_on_technique_meditate_pressed)
	tech_action_hbox.add_child(_technique_meditate_btn)
	
	_right_content_panel.add_child(_technique_panel)

	# Trade Content Panel
	_trade_panel = PanelContainer.new()
	_trade_panel.name = "TradeContentPanel"
	_trade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_panel.clip_contents = true
	_trade_panel.hide()

	var trade_vbox := VBoxContainer.new()
	_trade_panel.add_child(trade_vbox)

	_trade_spirit_stone_label = Label.new()
	_trade_spirit_stone_label.text = "灵石: 0"
	_trade_spirit_stone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade_vbox.add_child(_trade_spirit_stone_label)

	var trade_hsplit := HSplitContainer.new()
	trade_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trade_vbox.add_child(trade_hsplit)

	_trade_goods_list = ItemList.new()
	_trade_goods_list.custom_minimum_size = Vector2(250, 0)
	_trade_goods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_goods_list.item_selected.connect(_on_trade_item_selected)
	trade_hsplit.add_child(_trade_goods_list)

	var trade_right_vbox := VBoxContainer.new()
	trade_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_right_vbox.size_flags_stretch_ratio = 2.0
	trade_hsplit.add_child(trade_right_vbox)

	_trade_detail_label = RichTextLabel.new()
	_trade_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_detail_label.bbcode_enabled = true
	_trade_detail_label.text = "请选择左侧物品查看详情。"
	trade_right_vbox.add_child(_trade_detail_label)

	var trade_action_hbox := HBoxContainer.new()
	trade_action_hbox.add_theme_constant_override("separation", 8)
	trade_right_vbox.add_child(trade_action_hbox)

	_trade_buy_btn = Button.new()
	_trade_buy_btn.text = "买入"
	_trade_buy_btn.disabled = true
	_trade_buy_btn.pressed.connect(_on_trade_buy_pressed)
	trade_action_hbox.add_child(_trade_buy_btn)

	_trade_sell_btn = Button.new()
	_trade_sell_btn.text = "卖出"
	_trade_sell_btn.disabled = true
	_trade_sell_btn.pressed.connect(_on_trade_sell_pressed)
	trade_action_hbox.add_child(_trade_sell_btn)

	_right_content_panel.add_child(_trade_panel)

	# Combat Popup Panel (overlay, not a tab)
	_combat_panel = PanelContainer.new()
	_combat_panel.name = "CombatPopupPanel"
	_combat_panel.set_anchors_preset(Control.PRESET_CENTER)
	_combat_panel.custom_minimum_size = Vector2(600, 500)
	_combat_panel.hide()

	var combat_style := StyleBoxFlat.new()
	combat_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	_combat_panel.add_theme_stylebox_override("panel", combat_style)

	var combat_vbox := VBoxContainer.new()
	_combat_panel.add_child(combat_vbox)

	var combat_title := Label.new()
	combat_title.text = "- 战斗 -"
	combat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_vbox.add_child(combat_title)

	# Player HP
	var player_hp_hbox := HBoxContainer.new()
	combat_vbox.add_child(player_hp_hbox)

	var player_hp_name := Label.new()
	player_hp_name.text = "玩家: "
	player_hp_hbox.add_child(player_hp_name)

	_combat_player_hp_bar = ProgressBar.new()
	_combat_player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_player_hp_bar.max_value = 100
	_combat_player_hp_bar.value = 100
	player_hp_hbox.add_child(_combat_player_hp_bar)

	_combat_player_hp_label = Label.new()
	_combat_player_hp_label.text = "100/100"
	player_hp_hbox.add_child(_combat_player_hp_label)

	# Enemy HP
	var enemy_hp_hbox := HBoxContainer.new()
	combat_vbox.add_child(enemy_hp_hbox)

	var enemy_hp_name := Label.new()
	enemy_hp_name.text = "敌人: "
	enemy_hp_hbox.add_child(enemy_hp_name)

	_combat_enemy_hp_bar = ProgressBar.new()
	_combat_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_enemy_hp_bar.max_value = 100
	_combat_enemy_hp_bar.value = 100
	enemy_hp_hbox.add_child(_combat_enemy_hp_bar)

	_combat_enemy_hp_label = Label.new()
	_combat_enemy_hp_label.text = "100/100"
	enemy_hp_hbox.add_child(_combat_enemy_hp_label)

	# Combat log
	_combat_log_label = RichTextLabel.new()
	_combat_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_log_label.bbcode_enabled = true
	combat_vbox.add_child(_combat_log_label)

	# Action buttons
	var combat_action_hbox := HBoxContainer.new()
	combat_action_hbox.add_theme_constant_override("separation", 12)
	combat_action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	combat_vbox.add_child(combat_action_hbox)

	_combat_attack_btn = Button.new()
	_combat_attack_btn.text = "攻击"
	_combat_attack_btn.pressed.connect(func(): RunState.submit_player_combat_action({"action_type": "attack"}))
	combat_action_hbox.add_child(_combat_attack_btn)

	_combat_item_btn = Button.new()
	_combat_item_btn.text = "使用物品"
	_combat_item_btn.pressed.connect(func(): RunState.submit_player_combat_action({"action_type": "use_item", "item_id": ""}))
	combat_action_hbox.add_child(_combat_item_btn)

	_combat_flee_btn = Button.new()
	_combat_flee_btn.text = "逃跑"
	_combat_flee_btn.pressed.connect(func(): RunState.submit_player_combat_action({"action_type": "flee"}))
	combat_action_hbox.add_child(_combat_flee_btn)

	# Result label
	_combat_result_label = RichTextLabel.new()
	_combat_result_label.custom_minimum_size = Vector2(0, 60)
	_combat_result_label.bbcode_enabled = true
	combat_vbox.add_child(_combat_result_label)

	_game_ui_container.add_child(_combat_panel)

	
	_active_tab = "log"
	_update_tab_highlight()

	if RunState:
		if not RunState.sub_phase_changed.is_connected(_on_combat_sub_phase_changed):
			RunState.sub_phase_changed.connect(_on_combat_sub_phase_changed)
		if not RunState.combat_context_changed.is_connected(_refresh_combat_panel):
			RunState.combat_context_changed.connect(_refresh_combat_panel)
		if not RunState.combat_result_changed.is_connected(_refresh_combat_panel):
			RunState.combat_result_changed.connect(_refresh_combat_panel)

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
	elif _active_tab == "inventory":
		_refresh_inventory_panel()
	elif _active_tab == "crafting":
		_refresh_crafting_panel()
	elif _active_tab == "technique":
		_refresh_technique_panel()
	elif _active_tab == "trade":
		_refresh_trade_panel()

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

func _refresh_inventory_panel() -> void:
	if _inventory_item_list == null or _inventory_detail_label == null or _inventory_equipment_label == null or _inventory_stats_label == null:
		return

	_inventory_selected_record = {}
	_inventory_entries.clear()
	_inventory_item_defs.clear()
	_inventory_item_list.clear()
	_inventory_detail_label.text = "请选择左侧物品查看详情。"
	_inventory_equipment_label.text = "[b]- 已装备槽位 -[/b]\n暂无"
	_inventory_stats_label.text = "[b]- 属性总览 -[/b]\n暂无"
	_update_inventory_action_buttons({})

	var player_id: String = _resolve_player_character_id()
	if player_id.is_empty():
		_inventory_detail_label.text = "暂无玩家角色。"
		return

	var inventory_service: Node = _inventory_service_node()
	if inventory_service == null or not inventory_service.has_method("get_inventory"):
		_inventory_detail_label.text = "背包服务不可用。"
		return

	var catalog: Resource = _resolve_inventory_catalog()
	var inv_raw: Variant = inventory_service.get_inventory(player_id)
	if not (inv_raw is Array):
		_inventory_detail_label.text = "背包数据读取失败。"
		return

	var inv_array: Array = inv_raw as Array
	for record_raw in inv_array:
		if not (record_raw is Dictionary):
			continue
		var record: Dictionary = (record_raw as Dictionary).duplicate(true)
		_inventory_entries.append(record)

		var item_id := str(record.get("item_id", ""))
		var item_def: Resource = null
		if catalog != null and catalog.has_method("find_item"):
			item_def = catalog.find_item(StringName(item_id))
		if item_def != null:
			_inventory_item_defs[item_id] = item_def

		var item_name := _inventory_display_name(item_id, item_def)
		var quantity: int = int(record.get("quantity", 1))
		if quantity < 1:
			quantity = 1
		var rarity := str(record.get("rarity", "common"))
		var equipped_slot := str(record.get("equipped_slot", ""))

		var line := "%s x%d" % [item_name, quantity]
		if not equipped_slot.is_empty():
			line += "  [装备:%s]" % _inventory_slot_name(equipped_slot)

		var idx := _inventory_item_list.add_item(line)
		_inventory_item_list.set_item_metadata(idx, record)
		_inventory_item_list.set_item_custom_fg_color(idx, _inventory_rarity_color(rarity))

	if _inventory_entries.is_empty():
		_inventory_detail_label.text = "背包为空。可通过探索、战斗、交易或制作获取物品。"
	else:
		_inventory_item_list.select(0)
		_on_inventory_item_selected(0)

	_inventory_equipment_label.text = _build_inventory_equipment_text(_inventory_entries)

	var equipped_stats: Dictionary = {}
	if inventory_service.has_method("get_equipped_stats"):
		var stats_raw: Variant = inventory_service.get_equipped_stats(player_id)
		if stats_raw is Dictionary:
			equipped_stats = (stats_raw as Dictionary).duplicate(true)

	var player_runtime: Dictionary = _resolve_player_runtime_character(player_id)
	_inventory_stats_label.text = _build_inventory_stats_text(player_runtime, equipped_stats)


func _on_inventory_item_selected(index: int) -> void:
	if _inventory_item_list == null or _inventory_detail_label == null:
		return
	if index < 0 or index >= _inventory_item_list.item_count:
		return

	var metadata: Variant = _inventory_item_list.get_item_metadata(index)
	if not (metadata is Dictionary):
		_inventory_selected_record = {}
		_update_inventory_action_buttons({})
		_inventory_detail_label.text = "物品数据无效。"
		return

	var record: Dictionary = (metadata as Dictionary).duplicate(true)
	_inventory_selected_record = record.duplicate(true)
	var item_id := str(record.get("item_id", ""))
	var item_def: Resource = null
	if _inventory_item_defs.has(item_id):
		var def_raw: Variant = _inventory_item_defs.get(item_id)
		if def_raw is Resource:
			item_def = def_raw as Resource
	_update_inventory_action_buttons(record)

	var item_name := _inventory_display_name(item_id, item_def)
	var rarity := str(record.get("rarity", "common"))
	var quantity := int(record.get("quantity", 0))
	var equipped_slot := str(record.get("equipped_slot", ""))

	var text := "[b]%s[/b]\n" % item_name
	text += "ID: %s\n" % item_id
	text += "品质: [color=%s]%s[/color]\n" % [_inventory_rarity_bbcode_color(rarity), _inventory_rarity_label(rarity)]
	text += "数量: %d\n" % quantity
	if not equipped_slot.is_empty():
		text += "装备槽位: %s\n" % _inventory_slot_name(equipped_slot)
	else:
		text += "装备槽位: 未装备\n"

	if item_def != null:
		var item_type := str(_resource_get_or(item_def, "item_type", "unknown"))
		var element := str(_resource_get_or(item_def, "element", "neutral"))
		var base_value := int(_resource_get_or(item_def, "base_value", 0))
		var required_realm := int(_resource_get_or(item_def, "required_realm", 0))
		text += "类型: %s\n" % item_type
		text += "元素: %s\n" % element
		text += "基础价值: %d\n" % base_value
		text += "需求境界: %d\n" % required_realm

		var summary := str(_resource_get_or(item_def, "summary", ""))
		if not summary.is_empty():
			text += "\n%s\n" % summary

		var stat_modifiers_raw: Variant = _resource_get_or(item_def, "stat_modifiers", {})
		if stat_modifiers_raw is Dictionary and not (stat_modifiers_raw as Dictionary).is_empty():
			text += "\n[b]- 基础属性加成 -[/b]\n"
			var stat_modifiers: Dictionary = stat_modifiers_raw as Dictionary
			for key_variant in stat_modifiers.keys():
				var stat_key := str(key_variant)
				text += "%s: %+d\n" % [_inventory_stat_name(stat_key), int(stat_modifiers[stat_key])]

		var consumable_effect_raw: Variant = _resource_get_or(item_def, "consumable_effect", {})
		if consumable_effect_raw is Dictionary and not (consumable_effect_raw as Dictionary).is_empty():
			text += "\n[b]- 消耗效果 -[/b]\n"
			var consumable_effect: Dictionary = consumable_effect_raw as Dictionary
			for key_variant in consumable_effect.keys():
				text += "%s: %s\n" % [str(key_variant), str(consumable_effect[key_variant])]

	var affixes_raw: Variant = record.get("affixes", [])
	if affixes_raw is Array and not (affixes_raw as Array).is_empty():
		text += "\n[b]- 已实例化词条 -[/b]\n"
		var affixes: Array = affixes_raw as Array
		for affix_raw in affixes:
			if not (affix_raw is Dictionary):
				continue
			var affix: Dictionary = affix_raw as Dictionary
			var affix_name := str(affix.get("affix_name", affix.get("affix_id", "词条")))
			text += "- %s" % affix_name
			var effect_raw: Variant = affix.get("effect", {})
			if effect_raw is Dictionary and not (effect_raw as Dictionary).is_empty():
				var effect_parts: Array[String] = []
				var effect_dict: Dictionary = effect_raw as Dictionary
				for k in effect_dict.keys():
					effect_parts.append("%s:%s" % [str(k), str(effect_dict[k])])
				text += " (%s)" % ", ".join(effect_parts)
			text += "\n"

	_inventory_detail_label.text = text


func _update_inventory_action_buttons(record: Dictionary) -> void:
	if _inventory_equip_btn == null or _inventory_use_btn == null or _inventory_drop_btn == null:
		return

	_inventory_equip_btn.disabled = true
	_inventory_use_btn.disabled = true
	_inventory_drop_btn.disabled = true
	_inventory_equip_btn.text = "装备"

	if record.is_empty():
		return

	var inventory_service: Node = _inventory_service_node()
	if inventory_service == null:
		return

	var item_id := str(record.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return

	var quantity := int(record.get("quantity", 0))
	var equipped_slot := str(record.get("equipped_slot", "")).strip_edges()
	var item_def := _resolve_inventory_item_def(item_id)
	var item_type := str(_resource_get_or(item_def, "item_type", "")).strip_edges()
	var equip_slot := str(_resource_get_or(item_def, "equip_slot", "")).strip_edges()

	if not equipped_slot.is_empty() and inventory_service.has_method("unequip_item"):
		_inventory_equip_btn.text = "卸下"
		_inventory_equip_btn.disabled = false
	elif not equip_slot.is_empty() and quantity > 0 and inventory_service.has_method("equip_item"):
		_inventory_equip_btn.text = "装备"
		_inventory_equip_btn.disabled = false

	if item_type == "consumable" and quantity > 0 and equipped_slot.is_empty() and inventory_service.has_method("use_consumable"):
		_inventory_use_btn.disabled = false

	if quantity > 0 and equipped_slot.is_empty() and inventory_service.has_method("remove_item"):
		_inventory_drop_btn.disabled = false


func _resolve_inventory_item_def(item_id: String) -> Resource:
	if item_id.is_empty():
		return null
	if _inventory_item_defs.has(item_id):
		var def_raw: Variant = _inventory_item_defs.get(item_id)
		if def_raw is Resource:
			return def_raw as Resource
	var catalog: Resource = _resolve_inventory_catalog()
	if catalog != null and catalog.has_method("find_item"):
		return catalog.find_item(StringName(item_id))
	return null


func _on_inventory_equip_pressed() -> void:
	if _inventory_selected_record.is_empty():
		return
	var inventory_service: Node = _inventory_service_node()
	if inventory_service == null:
		return
	var player_id: String = _resolve_player_character_id()
	if player_id.is_empty():
		return

	var item_id := str(_inventory_selected_record.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return
	var equipped_slot := str(_inventory_selected_record.get("equipped_slot", "")).strip_edges()
	var action_ok := false

	if not equipped_slot.is_empty() and inventory_service.has_method("unequip_item"):
		action_ok = bool(inventory_service.unequip_item(player_id, equipped_slot))
	else:
		var item_def := _resolve_inventory_item_def(item_id)
		var target_slot := str(_resource_get_or(item_def, "equip_slot", "")).strip_edges()
		if target_slot.is_empty() or not inventory_service.has_method("equip_item"):
			return
		action_ok = bool(inventory_service.equip_item(player_id, item_id, target_slot))

	if action_ok:
		_refresh_inventory_panel()


func _on_inventory_use_pressed() -> void:
	if _inventory_selected_record.is_empty():
		return
	var inventory_service: Node = _inventory_service_node()
	if inventory_service == null or not inventory_service.has_method("use_consumable"):
		return
	var player_id: String = _resolve_player_character_id()
	if player_id.is_empty():
		return

	var item_id := str(_inventory_selected_record.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return
	var use_result: Variant = inventory_service.use_consumable(player_id, item_id)
	if use_result is Dictionary:
		_refresh_inventory_panel()


func _on_inventory_drop_pressed() -> void:
	if _inventory_selected_record.is_empty():
		return
	var inventory_service: Node = _inventory_service_node()
	if inventory_service == null or not inventory_service.has_method("remove_item"):
		return
	var player_id: String = _resolve_player_character_id()
	if player_id.is_empty():
		return

	var item_id := str(_inventory_selected_record.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return
	var remove_ok := bool(inventory_service.remove_item(player_id, item_id, 1))
	if remove_ok:
		_refresh_inventory_panel()


func _resolve_player_character_id() -> String:
	if _sim_runner == null or not _sim_runner.has_method("get_runtime_characters"):
		return ""
	var chars_raw: Variant = _sim_runner.get_runtime_characters()
	if not (chars_raw is Array):
		return ""
	var chars: Array = chars_raw as Array
	if chars.is_empty() or not (chars[0] is Dictionary):
		return ""
	return str((chars[0] as Dictionary).get("id", "")).strip_edges()


func _resolve_player_runtime_character(player_id: String) -> Dictionary:
	if player_id.is_empty() or _sim_runner == null or not _sim_runner.has_method("get_runtime_characters"):
		return {}
	var chars_raw: Variant = _sim_runner.get_runtime_characters()
	if not (chars_raw is Array):
		return {}
	var chars: Array = chars_raw as Array
	for char_raw in chars:
		if not (char_raw is Dictionary):
			continue
		var character: Dictionary = char_raw as Dictionary
		if str(character.get("id", "")) == player_id:
			return character
	return {}


func _inventory_service_node() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("InventoryService")
	return null


func _resolve_inventory_catalog() -> Resource:
	if _sim_runner == null or not _sim_runner.has_method("get_catalog_path"):
		return null
	var catalog_path := str(_sim_runner.get_catalog_path())
	if catalog_path.is_empty():
		return null
	if _inventory_catalog != null and _inventory_catalog.resource_path == catalog_path:
		return _inventory_catalog
	_inventory_catalog = load(catalog_path) as Resource
	return _inventory_catalog


func _build_inventory_equipment_text(entries: Array[Dictionary]) -> String:
	var equipped_by_slot: Dictionary = {}
	for record in entries:
		var slot := str(record.get("equipped_slot", "")).strip_edges()
		if slot.is_empty():
			continue
		equipped_by_slot[slot] = record

	var slot_order: Array[String] = [
		"weapon",
		"head",
		"body",
		"accessory_1",
		"accessory_2",
	]

	var text := "[b]- 已装备槽位 -[/b]\n"
	for slot in slot_order:
		if not equipped_by_slot.has(slot):
			text += "%s: [color=gray]空[/color]\n" % _inventory_slot_name(slot)
			continue
		var record: Dictionary = equipped_by_slot[slot] as Dictionary
		var item_id := str(record.get("item_id", ""))
		var item_def: Resource = null
		if _inventory_item_defs.has(item_id):
			var def_raw: Variant = _inventory_item_defs.get(item_id)
			if def_raw is Resource:
				item_def = def_raw as Resource
		var item_name := _inventory_display_name(item_id, item_def)
		var rarity := str(record.get("rarity", "common"))
		text += "%s: [color=%s]%s[/color]\n" % [_inventory_slot_name(slot), _inventory_rarity_bbcode_color(rarity), item_name]
	return text


func _build_inventory_stats_text(player_runtime: Dictionary, equipped_stats: Dictionary) -> String:
	var text := "[b]- 属性总览 -[/b]\n"

	var fallback_stats: Dictionary = {
		"max_hp": 100,
		"attack": 10,
		"defense": 5,
		"speed": 10,
	}
	var base_stats: Dictionary = fallback_stats.duplicate(true)
	var final_stats: Dictionary = fallback_stats.duplicate(true)
	var base_raw: Variant = player_runtime.get("combat_stats_base", player_runtime.get("combat_stats", fallback_stats))
	if base_raw is Dictionary:
		base_stats = (base_raw as Dictionary).duplicate(true)
	var final_raw: Variant = player_runtime.get("combat_stats", fallback_stats)
	if final_raw is Dictionary:
		final_stats = (final_raw as Dictionary).duplicate(true)

	var core_stats: Array[String] = ["max_hp", "attack", "defense", "speed"]
	for stat_key in core_stats:
		var base_val := int(base_stats.get(stat_key, 0))
		var final_val := int(final_stats.get(stat_key, base_val))
		var equip_bonus_val := int(equipped_stats.get(stat_key, final_val - base_val))
		text += "%s: %d" % [_inventory_stat_name(stat_key), final_val]
		if base_stats.has(stat_key) or final_stats.has(stat_key):
			text += " (基础 %d" % base_val
			if equip_bonus_val != 0:
				text += ", 装备 %+d" % equip_bonus_val
			text += ")"
		text += "\n"

	var extra_lines: Array[String] = []
	for stat_key_variant in equipped_stats.keys():
		var stat_key := str(stat_key_variant)
		if stat_key in core_stats:
			continue
		extra_lines.append("%s %+d" % [_inventory_stat_name(stat_key), int(equipped_stats[stat_key_variant])])

	if not extra_lines.is_empty():
		text += "\n[b]- 额外装备加成 -[/b]\n"
		for line in extra_lines:
			text += "%s\n" % line

	return text


func _inventory_display_name(item_id: String, item_def: Resource) -> String:
	if item_def != null:
		var name_raw: Variant = item_def.get("display_name")
		if name_raw != null:
			var resolved := str(name_raw).strip_edges()
			if not resolved.is_empty():
				return resolved
	return item_id


func _inventory_slot_name(slot: String) -> String:
	match slot:
		"weapon":
			return "武器"
		"head":
			return "头部"
		"body":
			return "躯干"
		"accessory_1":
			return "饰品一"
		"accessory_2":
			return "饰品二"
		_:
			return slot


func _inventory_stat_name(stat_key: String) -> String:
	match stat_key:
		"max_hp":
			return "最大生命"
		"attack":
			return "攻击"
		"defense":
			return "防御"
		"speed":
			return "速度"
		_:
			return stat_key


func _inventory_rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "凡品"
		"uncommon":
			return "良品"
		"rare":
			return "珍品"
		"epic":
			return "极品"
		"legendary":
			return "传说"
		"mythic":
			return "神话"
		_:
			return rarity


func _inventory_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.8, 0.8, 0.8)
		"uncommon":
			return Color(0.3, 0.9, 0.3)
		"rare":
			return Color(0.3, 0.5, 1.0)
		"epic":
			return Color(0.7, 0.3, 0.9)
		"legendary":
			return Color(1.0, 0.6, 0.1)
		"mythic":
			return Color(1.0, 0.2, 0.2)
		_:
			return Color(0.8, 0.8, 0.8)


func _inventory_rarity_bbcode_color(rarity: String) -> String:
	match rarity:
		"common":
			return "#cccccc"
		"uncommon":
			return "#4de64d"
		"rare":
			return "#4d80ff"
		"epic":
			return "#b34de6"
		"legendary":
			return "#ff9a1a"
		"mythic":
			return "#ff3333"
		_:
			return "#cccccc"


func _resource_get_or(resource: Resource, property_name: String, fallback: Variant) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _should_refresh_inventory_from_entry(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var category := str(entry.get("category", ""))
	if category == "inventory":
		return true
	var title := str(entry.get("title", ""))
	if title.begins_with("ITEM_"):
		return true
	var cause := str(entry.get("direct_cause", ""))
	if cause.begins_with("ITEM_"):
		return true
	return false

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
	if _crafting_panel:
		_crafting_panel.visible = (_active_tab == "crafting")
	if _technique_panel:
		_technique_panel.visible = (_active_tab == "technique")
	if _trade_panel:
		_trade_panel.visible = (_active_tab == "trade")

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
	if _should_refresh_inventory_from_entry(_entry):
		_refresh_inventory_panel()


func _on_time_advanced(_total_minutes: int) -> void:
	_refresh_text()


func _on_save_pressed() -> void:
	if SaveService == null:
		if EventLog != null and EventLog.has_method("add_entry"):
			EventLog.add_entry("保存失败：SaveService 不可用")
		else:
			push_warning("保存失败：SaveService 不可用")
		return
	if _sim_runner == null or not _sim_runner.has_method("get_snapshot"):
		if EventLog != null and EventLog.has_method("add_entry"):
			EventLog.add_entry("保存失败：SimulationRunner 不可用")
		else:
			push_warning("保存失败：SimulationRunner 不可用")
		return
	var snapshot: Dictionary = _sim_runner.get_snapshot()
	var save_ok: bool = SaveService.save_game({"simulation_snapshot": snapshot})
	if save_ok:
		if EventLog != null and EventLog.has_method("add_entry"):
			EventLog.add_entry("保存成功")
		else:
			push_warning("保存成功")
	else:
		var save_error := "unknown"
		if SaveService.has_method("get_last_error"):
			save_error = str(SaveService.get_last_error())
		if EventLog != null and EventLog.has_method("add_entry"):
			EventLog.add_entry("保存失败：%s" % save_error)
		else:
			push_warning("保存失败：%s" % save_error)


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



func _update_region_tree_item_display(rid: String, item: TreeItem, display_name: String) -> void:
	if _sim_runner == null:
		item.set_text(0, display_name)
		return
	
	var dynamic_state: Dictionary = {}
	if _sim_runner.has_method("get_region_dynamic_state"):
		dynamic_state = _sim_runner.get_region_dynamic_state(rid)
		
	if dynamic_state.is_empty():
		item.set_text(0, display_name)
		return
		
	var faction_id: String = dynamic_state.get("controlling_faction_id", "")
	if not faction_id.is_empty():
		var h: float = float(faction_id.hash() % 1000) / 1000.0
		var faction_color := Color.from_hsv(h, 0.6, 0.9)
		item.set_custom_color(0, faction_color)
		
	var danger_level: int = dynamic_state.get("danger_level", 0)
	if danger_level > 0:
		item.set_text(0, "%s [危%d]" % [display_name, danger_level])
	else:
		item.set_text(0, display_name)

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
			item.set_metadata(0, rid)
			_update_region_tree_item_display(rid, item, str(r.get("display_name", rid)))
			_map_region_items[rid] = item
			assigned_ids[rid] = true
			
			unassigned_regions.remove_at(i)
			has_progress = true
			# We don't increment i because we removed an element
	
	# Any remaining ones are orphaned, attach to root
	for r in unassigned_regions:
		var rid := str(r.get("id", ""))
		var item: TreeItem = _region_tree.create_item(root)
		item.set_metadata(0, rid)
		_update_region_tree_item_display(rid, item, str(r.get("display_name", rid)) + " (未连接)")
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
			
	var dynamic_state: Dictionary = {}
	if _sim_runner != null and _sim_runner.has_method("get_region_dynamic_state"):
		dynamic_state = _sim_runner.get_region_dynamic_state(rid)

	if not dynamic_state.is_empty():
		text += "

[b]动态情报:[/b]
"
		
		var faction_id: String = dynamic_state.get("controlling_faction_id", "")
		if not faction_id.is_empty():
			var h: float = float(faction_id.hash() % 1000) / 1000.0
			var faction_color := Color.from_hsv(h, 0.6, 0.9)
			text += "控制势力: [color=#%s]%s[/color]
" % [faction_color.to_html(false), faction_id]
		else:
			text += "控制势力: 无
"
			
		var danger_level: int = dynamic_state.get("danger_level", 0)
		var danger_color := "green"
		if danger_level >= 4:
			danger_color = "red"
		elif danger_level >= 1:
			danger_color = "yellow"
		text += "危险等级: [color=%s]%d[/color]
" % [danger_color, danger_level]
			
		var stockpiles: Dictionary = dynamic_state.get("resource_stockpiles", {})
		if stockpiles.is_empty():
			text += "资源产出: 无
"
		else:
			text += "资源产出:
"
			for res_id in stockpiles:
				var res_qty: int = stockpiles[res_id]
				text += "  - %s: %d
" % [res_id, res_qty]
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


# --- Crafting UI ---

func _refresh_crafting_panel() -> void:
	if _crafting_recipe_list == null:
		return
		
	_current_recipes.clear()
	_crafting_recipe_list.clear()
	_crafting_selected_recipe = null
	if _crafting_btn != null:
		_crafting_btn.disabled = true
	if _crafting_detail_label != null:
		_crafting_detail_label.text = "请在左侧选择配方。"
	
	if _sim_runner == null or not _sim_runner.has_method("get_catalog_path"):
		if _crafting_detail_label != null:
			_crafting_detail_label.text = "模拟运行器不可用。"
		return
		
	var catalog_path: String = _sim_runner.get_catalog_path()
	var catalog: Resource = load(catalog_path) as Resource
	if catalog == null:
		if _crafting_detail_label != null:
			_crafting_detail_label.text = "数据目录不可用。"
		return
		
	var all_recipes: Array = []
	if catalog.has_method("get_crafting_recipes"):
		var crafting_recipes: Variant = catalog.get_crafting_recipes()
		if crafting_recipes is Array:
			all_recipes = crafting_recipes
	if all_recipes.is_empty():
		var recipes_variant: Variant = catalog.get("recipes")
		if recipes_variant is Array:
			all_recipes = recipes_variant
	if all_recipes.is_empty():
		return
		
	var filter_idx := _crafting_type_filter.get_selected_id()
	var type_filter := str(_crafting_type_filter.get_item_metadata(filter_idx))
	
	for r_raw in all_recipes:
		if not (r_raw is Resource):
			continue
		var r: Resource = r_raw as Resource
		
		var r_type_val: Variant = r.get("recipe_type")
		var r_type := str(r_type_val) if r_type_val != null else ""
		
		if type_filter != "all" and r_type != type_filter:
			continue
			
		_current_recipes.append(r)
		
		var r_name_val: Variant = r.get("display_name")
		var r_name := str(r_name_val) if r_name_val != null and str(r_name_val) != "" else str(r.get("id"))
		
		var type_display := "丹" if r_type == "alchemy" else "器" if r_type == "forge" else "?"
		var display_text := "[%s] %s" % [type_display, r_name]
		_crafting_recipe_list.add_item(display_text)


func _on_crafting_recipe_selected(index: int) -> void:
	if index < 0 or index >= _current_recipes.size():
		return
		
	var recipe: Resource = _current_recipes[index]
	_crafting_selected_recipe = recipe
	_update_crafting_detail()


func _update_crafting_detail() -> void:
	if _crafting_selected_recipe == null:
		if _crafting_detail_label != null:
			_crafting_detail_label.text = "请在左侧选择配方。"
		if _crafting_btn != null:
			_crafting_btn.disabled = true
		return
		
	var r: Resource = _crafting_selected_recipe
	var catalog_path: String = _sim_runner.get_catalog_path()
	var catalog: Resource = load(catalog_path) as Resource
	var chars: Array = _sim_runner.get_runtime_characters()
	
	if chars.is_empty():
		if _crafting_detail_label != null:
			_crafting_detail_label.text = "找不到玩家数据。"
		if _crafting_btn != null:
			_crafting_btn.disabled = true
		return
		
	var player_id := str(chars[0].get("id", ""))
	
	var r_name_val: Variant = r.get("display_name")
	var r_name := str(r_name_val) if r_name_val != null and str(r_name_val) != "" else str(r.get("id"))
	
	var r_desc_val: Variant = r.get("description")
	var r_desc := str(r_desc_val) if r_desc_val != null else ""
	
	var req_skill_val: Variant = r.get("required_skill_level")
	var req_skill := int(req_skill_val) if req_skill_val != null else 0
	
	var result_item_id_val: Variant = r.get("result_item_id")
	var result_item_id := str(result_item_id_val) if result_item_id_val != null else ""
	
	var result_qty_val: Variant = r.get("result_quantity")
	var result_qty := int(result_qty_val) if result_qty_val != null else 1
	
	var rarity_min_val: Variant = r.get("result_rarity_min")
	var rarity_min := str(rarity_min_val) if rarity_min_val != null else "common"
	
	var base_rate_val: Variant = r.get("success_rate_base")
	var base_rate := float(base_rate_val) if base_rate_val != null else 0.0
	
	var materials: Array = []
	var raw_mat: Variant = r.get("materials")
	if raw_mat is Array:
		materials = raw_mat as Array
		
	var result_item_name := result_item_id
	if catalog.has_method("find_item"):
		var i_def: Resource = catalog.find_item(StringName(result_item_id))
		if i_def != null:
			var d_name_val: Variant = i_def.get("display_name")
			var d_name := str(d_name_val) if d_name_val != null else ""
			if d_name != "":
				result_item_name = d_name

	var text := "[b]%s[/b]\n" % r_name
	if r_desc != "":
		text += "%s\n\n" % r_desc
	else:
		text += "\n"
	
	text += "[b]- 制作产出 -[/b]\n"
	text += "产物: %s x%d\n" % [result_item_name, result_qty]
	text += "最低品质: %s\n" % rarity_min
	text += "基础成功率: %d%%\n\n" % int(base_rate * 100)
	
	# Get player inventory to check materials
	var inventory_service: Node = null
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var st := main_loop as SceneTree
		if st.root != null:
			inventory_service = st.root.get_node_or_null("InventoryService")
			
	var inv: Array[Dictionary] = []
	if inventory_service != null and inventory_service.has_method("get_inventory"):
		var inv_raw: Variant = inventory_service.get_inventory(player_id)
		if inv_raw is Array:
			for i in inv_raw:
				if i is Dictionary:
					inv.append(i as Dictionary)
		
	var all_materials_met := true
	text += "[b]- 材料需求 -[/b]\n"
	
	for m_raw in materials:
		if not (m_raw is Dictionary): continue
		var m: Dictionary = m_raw as Dictionary
		var m_id := str(m.get("item_id", ""))
		var m_qty := int(m.get("quantity", 0))
		
		# Find how many we have
		var current_qty := 0
		for inv_item in inv:
			if str(inv_item.get("item_id", "")) == m_id:
				current_qty += int(inv_item.get("quantity", 0))
				
		var m_name := m_id
		if catalog.has_method("find_item"):
			var i_def: Resource = catalog.find_item(StringName(m_id))
			if i_def != null:
				var d_name_val: Variant = i_def.get("display_name")
				var d_name := str(d_name_val) if d_name_val != null else ""
				if d_name != "":
					m_name = d_name
					
		if current_qty >= m_qty:
			text += "[color=green]√ %s: %d / %d[/color]\n" % [m_name, current_qty, m_qty]
		else:
			all_materials_met = false
			text += "[color=red]x %s: %d / %d[/color]\n" % [m_name, current_qty, m_qty]
			
	if materials.is_empty():
		text += "无需材料\n"
		
	text += "\n"
	
	var r_type_val: Variant = r.get("recipe_type")
	var r_type := str(r_type_val) if r_type_val != null else ""
	
	# Check skill level via CraftingService if available
	var skill_level := 1
	var crafting_service: Node = null
	if main_loop is SceneTree:
		var st := main_loop as SceneTree
		if st.root != null:
			crafting_service = st.root.get_node_or_null("CraftingService")
			
	if crafting_service != null and crafting_service.has_method("get_character_skill_level"):
		skill_level = crafting_service.get_character_skill_level(player_id, r_type)
		
	if skill_level >= req_skill:
		text += "[color=green]当前技艺等级: %d (需要: %d)[/color]\n" % [skill_level, req_skill]
	else:
		all_materials_met = false
		text += "[color=red]当前技艺等级: %d (需要: %d)[/color]\n" % [skill_level, req_skill]
	
	if _crafting_detail_label != null:
		_crafting_detail_label.text = text
	if _crafting_btn != null:
		_crafting_btn.disabled = not all_materials_met


func _on_crafting_btn_pressed() -> void:
	if _crafting_selected_recipe == null:
		return
		
	var main_loop := Engine.get_main_loop()
	var crafting_service: Node = null
	if main_loop is SceneTree:
		var st := main_loop as SceneTree
		if st.root != null:
			crafting_service = st.root.get_node_or_null("CraftingService")
			
	if crafting_service == null or not crafting_service.has_method("craft_item"):
		show_event_modal("制作失败", "找不到制作服务 (CraftingService)。")
		return
		
	var chars: Array = _sim_runner.get_runtime_characters()
	if chars.is_empty():
		return
	var player_id := str(chars[0].get("id", ""))
	
	var recipe_id_val: Variant = _crafting_selected_recipe.get("id")
	var recipe_id := str(recipe_id_val) if recipe_id_val != null else ""
	if recipe_id == "":
		return
		
	var catalog_path: String = _sim_runner.get_catalog_path()
	var catalog: Resource = load(catalog_path) as Resource
	var rng: RefCounted = null
	
	var result_raw: Variant = crafting_service.craft_item(player_id, recipe_id, catalog, rng)
	if not (result_raw is Dictionary):
		show_event_modal("制作失败", "内部错误：返回值无效。")
		return
	var result: Dictionary = result_raw as Dictionary
	
	var success := bool(result.get("success", false))
	var reason := str(result.get("reason", ""))
	
	if success:
		var c_id := str(result.get("crafted_item_id", ""))
		var c_qty := int(result.get("crafted_quantity", 0))
		var c_rarity := str(result.get("crafted_rarity", ""))
		
		var c_name := c_id
		if catalog.has_method("find_item"):
			var i_def: Resource = catalog.find_item(StringName(c_id))
			if i_def != null:
				var d_name_val: Variant = i_def.get("display_name")
				var d_name := str(d_name_val) if d_name_val != null else ""
				if d_name != "":
					c_name = d_name
					
		show_event_modal("制作成功", "成功制作出 [color=cyan]%s[/color] x%d (品质: %s)。\n最终成功率: %d%%" % [
			c_name, c_qty, c_rarity,
			int(float(result.get("success_rate", 0)) * 100)
		])
	else:
		show_event_modal("制作失败", "制作过程中出现失误，部分材料已损毁。\n失败原因: %s" % reason)
		
	_update_crafting_detail() # Refresh material counts


# --- Technique Panel Logic ---
func _refresh_technique_panel() -> void:
	if _technique_list == null or _technique_detail_label == null:
		return

	_technique_list.clear()
	_technique_detail_label.text = "请选择左侧功法查看详情。"
	_technique_equip_btn.disabled = true
	_technique_meditate_btn.disabled = true
	_learned_techniques.clear()
	_technique_selected_id = ""
	
	if _sim_runner == null:
		return
		
	var player_id: String = ""
	if _sim_runner.has_method("get_human_runtime"):
		var human_rt: Dictionary = _sim_runner.get_human_runtime()
		player_id = str(human_rt.get("player", {}).get("id", "")).strip_edges()
	if player_id.is_empty():
		return
		
	var service_raw: Variant = _sim_runner.get("_technique_service")
	if not (service_raw is Object):
		return
	var technique_service: Object = service_raw
	
	if not technique_service.has_method("get_learned_techniques"):
		return
		
	_learned_techniques = technique_service.call("get_learned_techniques", player_id)
	
	for tech in _learned_techniques:
		var t_id: String = tech.get("id", "")
		var slot_str: String = tech.get("equipped_slot", "")
		var d_name: String = t_id
		if slot_str != "":
			d_name += " (已装备)"
		var idx: int = _technique_list.add_item(d_name)
		_technique_list.set_item_metadata(idx, t_id)

func _on_technique_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _learned_techniques.size():
		return
		
	var tech: Dictionary = _learned_techniques[idx]
	_technique_selected_id = tech.get("id", "")
	
	var text := ""
	text += "[b]功法ID:[/b] %s\n" % _technique_selected_id
	text += "[b]宗门:[/b] %s\n" % tech.get("sect", "无")
	text += "[b]境界要求:[/b] %s\n" % tech.get("realm_req", "无")
	
	var affixes: Array = tech.get("affixes", [])
	if affixes.is_empty():
		text += "\n[color=gray]无词缀[/color]\n"
	else:
		text += "\n[b]词缀:[/b]\n"
		for i in range(affixes.size()):
			var a: Dictionary = affixes[i]
			text += "  - %s (进度: %d)\n" % [a.get("id", ""), a.get("progress", 0)]
			
	var slot_str: String = tech.get("equipped_slot", "")
	if slot_str != "":
		text += "\n[color=green]当前装备在: %s[/color]" % slot_str
		
	_technique_detail_label.text = text
	_technique_equip_btn.disabled = false
	_technique_meditate_btn.disabled = false

func _on_technique_equip_pressed() -> void:
	if _sim_runner == null or _technique_selected_id == "":
		return
	
	var slot_opt_idx: int = _technique_slot_option.get_selected_id()
	var slot_str: String = _technique_slot_option.get_item_text(slot_opt_idx)
	
	if _sim_runner.has_method("request_equip_technique"):
		_sim_runner.request_equip_technique(_technique_selected_id, slot_str)
	_refresh_technique_panel()

func _on_technique_meditate_pressed() -> void:
	if _sim_runner == null or _technique_selected_id == "":
		return
		
	if _sim_runner.has_method("request_meditate_technique"):
		# Just passing affix index 0 as placeholder since UI doesn't select affix
		_sim_runner.request_meditate_technique(_technique_selected_id, 0)
	_refresh_technique_panel()

# --- Trade Panel Logic ---
func _refresh_trade_panel() -> void:
	if _trade_goods_list == null or _trade_detail_label == null:
		return

	_trade_goods_list.clear()
	_trade_detail_label.text = "请选择左侧物品查看详情。"
	_trade_buy_btn.disabled = true
	_trade_sell_btn.disabled = true
	_trade_goods.clear()
	_trade_selected_good.clear()
	_trade_spirit_stone_label.text = "灵石: 0"
	
	if _sim_runner == null:
		return
		
	var player: Dictionary = {}
	if _sim_runner.has_method("get_human_runtime"):
		player = _sim_runner.get_human_runtime().get("player", {}) as Dictionary
	var player_id: String = str(player.get("id", "")).strip_edges()
	if player_id.is_empty():
		return
		
	var service_raw: Variant = _sim_runner.get("_technique_service")
	if service_raw is Object and service_raw.has_method("get_character_spirit_stones"):
		var stones: int = service_raw.call("get_character_spirit_stones", player_id)
		_trade_spirit_stone_label.text = "灵石: %d" % stones

	var catalog_path: String = _sim_runner.get_catalog_path()
	var catalog: Resource = load(catalog_path) as Resource
	
	var all_items_variant: Variant = catalog.get("items") if catalog != null else null
	if all_items_variant is Array:
		for item_def in all_items_variant:
			var base_val: int = 0
			var v: Variant = item_def.get("base_value")
			if v != null:
				base_val = v as int
			if base_val > 0:
				var item_id: String = ""
				var id_v: Variant = item_def.get("id")
				if id_v != null: item_id = id_v as String
				
				var item_name: String = ""
				var name_v: Variant = item_def.get("name")
				if name_v != null: item_name = name_v as String
				
				var good: Dictionary = {
					"id": item_id,
					"name": item_name,
					"price": base_val,
					"type": "buy"
				}
				_trade_goods.append(good)
				
	var inv: Array = player.get("inventory", [])
	for inv_item in inv:
		var base_val: int = 10 # Default
		var item_id: String = inv_item.get("id", "")
		if catalog and catalog.has_method("get_item"):
			var d: Resource = catalog.get_item(item_id)
			if d:
				var v: Variant = d.get("base_value")
				if v != null:
					base_val = v as int
		if base_val > 0:
			var good: Dictionary = {
				"id": item_id,
				"name": item_id + " (持有)",
				"price": int(base_val * 0.5), # Sell price is 50%
				"type": "sell",
				"quantity": inv_item.get("quantity", 1)
			}
			_trade_goods.append(good)
				
	for good in _trade_goods:
		var t: String = ""
		if good["type"] == "buy":
			t = "[买] %s - %d灵石" % [good["name"], good["price"]]
		else:
			t = "[卖] %s - %d灵石" % [good["name"], good["price"]]
		_trade_goods_list.add_item(t)

func _on_trade_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _trade_goods.size():
		return
		
	var good: Dictionary = _trade_goods[idx]
	_trade_selected_good = good
	
	var text := ""
	text += "[b]物品:[/b] %s\n" % good["name"]
	text += "[b]价格:[/b] %d 灵石\n" % good["price"]
	if good["type"] == "sell":
		text += "[b]持有数量:[/b] %d\n" % good["quantity"]
	
	_trade_detail_label.text = text
	
	if good["type"] == "buy":
		_trade_buy_btn.disabled = false
		_trade_sell_btn.disabled = true
	else:
		_trade_buy_btn.disabled = true
		_trade_sell_btn.disabled = false

func _on_trade_buy_pressed() -> void:
	if _sim_runner == null or _trade_selected_good.is_empty():
		return
		
	var player_id: String = ""
	if _sim_runner.has_method("get_human_runtime"):
		var human_rt: Dictionary = _sim_runner.get_human_runtime()
		player_id = str(human_rt.get("player", {}).get("id", "")).strip_edges()
	var inv_srv: Node = get_node_or_null("/root/InventoryService")
	var tech_srv_raw: Variant = _sim_runner.get("_technique_service")
	if not (tech_srv_raw is Object):
		return
	var tech_srv: Object = tech_srv_raw
	
	if inv_srv and inv_srv.has_method("add_item") and tech_srv.has_method("set_character_spirit_stones") and tech_srv.has_method("get_character_spirit_stones"):
		var current_stones: int = tech_srv.call("get_character_spirit_stones", player_id)
		var price: int = _trade_selected_good.get("price", 0)
		if current_stones >= price:
			tech_srv.call("set_character_spirit_stones", player_id, current_stones - price)
			inv_srv.call("add_item", player_id, _trade_selected_good.get("id", ""), 1, 0, [])
			_refresh_trade_panel()
		else:
			EventLog.add_entry("灵石不足！")

func _on_trade_sell_pressed() -> void:
	if _sim_runner == null or _trade_selected_good.is_empty():
		return
		
	var player_id: String = ""
	if _sim_runner.has_method("get_human_runtime"):
		var human_rt: Dictionary = _sim_runner.get_human_runtime()
		player_id = str(human_rt.get("player", {}).get("id", "")).strip_edges()
	var inv_srv: Node = get_node_or_null("/root/InventoryService")
	var tech_srv_raw: Variant = _sim_runner.get("_technique_service")
	if not (tech_srv_raw is Object):
		return
	var tech_srv: Object = tech_srv_raw
	
	if inv_srv and inv_srv.has_method("remove_item") and tech_srv.has_method("set_character_spirit_stones") and tech_srv.has_method("get_character_spirit_stones"):
		var current_stones: int = tech_srv.call("get_character_spirit_stones", player_id)
		var price: int = _trade_selected_good.get("price", 0)
		
		inv_srv.call("remove_item", player_id, _trade_selected_good.get("id", ""), 1)
		tech_srv.call("set_character_spirit_stones", player_id, current_stones + price)
		_refresh_trade_panel()

# --- Combat Popup Panel Logic ---
func _on_combat_sub_phase_changed(new_sub_phase: StringName) -> void:
	if _combat_panel == null:
		return
	if new_sub_phase == &"combat":
		_combat_panel.show()
		_refresh_combat_panel()
	else:
		_combat_panel.hide()

func _refresh_combat_panel() -> void:
	if _combat_panel == null or _combat_player_hp_bar == null:
		return

	var ctx: Dictionary = RunState.combat_context
	if ctx.is_empty():
		return
		
	var p_hp: int = ctx.get("player_hp", 0)
	var p_mhp: int = ctx.get("player_max_hp", 1)
	var e_hp: int = ctx.get("enemy_hp", 0)
	var e_mhp: int = ctx.get("enemy_max_hp", 1)
	
	_combat_player_hp_bar.max_value = p_mhp
	_combat_player_hp_bar.value = p_hp
	_combat_player_hp_label.text = "%d/%d" % [p_hp, p_mhp]
	
	_combat_enemy_hp_bar.max_value = e_mhp
	_combat_enemy_hp_bar.value = e_hp
	_combat_enemy_hp_label.text = "%d/%d" % [e_hp, e_mhp]
	
	var res: Dictionary = RunState.combat_result
	if not res.is_empty():
		var winner: String = res.get("winner", "")
		_combat_result_label.text = "[center][b]战斗结束！[/b]\n获胜者: %s\n掉落: %s[/center]" % [winner, str(res.get("loot", []))]
		_combat_attack_btn.disabled = true
		_combat_item_btn.disabled = true
		_combat_flee_btn.disabled = true
	else:
		_combat_result_label.text = ""
		_combat_attack_btn.disabled = false
		_combat_item_btn.disabled = false
		_combat_flee_btn.disabled = false
		
	if EventLog != null and EventLog.has_method("get_entries"):
		var all_entries: Array = EventLog.get_entries()
		var combat_logs: Array = []
		for entry in all_entries:
			if entry is Dictionary and str(entry.get("category", "")) == "combat":
				combat_logs.append(entry)
		var log_text := ""
		# show last 15 logs
		var start_idx: int = max(0, combat_logs.size() - 15)
		for i in range(start_idx, combat_logs.size()):
			log_text += "%s\n" % combat_logs[i].get("text", "")
		_combat_log_label.text = log_text
