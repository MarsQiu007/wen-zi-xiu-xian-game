extends PanelContainer
class_name WorldInitScreen

signal world_initialized()

var _stages: Array[String] = [
	"生成地形...",
	"创建NPC...",
	"建立关系...",
	"放置资源...",
	"生成怪物...",
	"创建功法..."
]

var _stage_labels: Array[Label] = []
var _current_stage_idx: int = 0
var _timer: Timer
var RunState: Node

var _seed_label: Label
var _stages_container: VBoxContainer
var _start_button: Button

func _ready() -> void:
	_bind_singletons()
	_seed_label = get_node_or_null("MarginContainer/VBoxContainer/SeedLabel") as Label
	_stages_container = get_node_or_null("MarginContainer/VBoxContainer/StagesContainer") as VBoxContainer
	_start_button = get_node_or_null("MarginContainer/VBoxContainer/StartButton") as Button

	if _start_button != null:
		_start_button.disabled = true
		_start_button.pressed.connect(func(): world_initialized.emit())
	
	if _stages_container != null:
		for stage_name in _stages:
			var lbl := Label.new()
			lbl.text = stage_name + " [等待中]"
			_stages_container.add_child(lbl)
			_stage_labels.append(lbl)
		
	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	
	visibility_changed.connect(_on_visibility_changed)


func _bind_singletons() -> void:
	var root_node := get_tree().root if get_tree() != null else null
	if root_node == null:
		return
	if RunState == null:
		RunState = root_node.get_node_or_null("RunState")

func _on_visibility_changed() -> void:
	if visible:
		start_init()
	else:
		if _timer != null:
			_timer.stop()

func start_init() -> void:
	_bind_singletons()
	if RunState == null:
		if _seed_label != null:
			_seed_label.text = "世界种子: 未知"
		return

	var seed_val: int = int(RunState.get("world_seed"))
	var _cp: Variant = RunState.get("creation_params")
	var creation_params: Dictionary = _cp if _cp is Dictionary else {}
	if seed_val == -1 and creation_params.has("custom_seed"):
		seed_val = int(creation_params.get("custom_seed", seed_val))
	if seed_val == 0 and creation_params.has("custom_seed"):
		seed_val = int(creation_params.get("custom_seed", seed_val))
	if _seed_label != null:
		_seed_label.text = "世界种子: " + str(seed_val)
	
	_current_stage_idx = 0
	if _start_button != null:
		_start_button.disabled = true
	for i in range(_stage_labels.size()):
		_stage_labels[i].text = _stages[i] + " [等待中]"
		_stage_labels[i].modulate = Color.WHITE
		
	if _timer != null:
		_timer.start()

func _on_timer_timeout() -> void:
	if _current_stage_idx < _stage_labels.size():
		var lbl := _stage_labels[_current_stage_idx]
		lbl.text = _stages[_current_stage_idx] + " [✓]"
		lbl.modulate = Color(0.2, 0.8, 0.2)
		_current_stage_idx += 1
	else:
		if _timer != null:
			_timer.stop()
		if _start_button != null:
			_start_button.disabled = false
