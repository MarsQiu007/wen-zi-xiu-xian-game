extends PanelContainer

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

@onready var _seed_label: Label = $MarginContainer/VBoxContainer/SeedLabel
@onready var _stages_container: VBoxContainer = $MarginContainer/VBoxContainer/StagesContainer
@onready var _start_button: Button = $MarginContainer/VBoxContainer/StartButton

func _ready() -> void:
	_start_button.disabled = true
	_start_button.pressed.connect(func(): world_initialized.emit())
	
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

func _on_visibility_changed() -> void:
	if visible:
		start_init()
	else:
		_timer.stop()

func start_init() -> void:
	var seed_val: int = RunState.world_seed
	if seed_val == -1 and RunState.creation_params.has("custom_seed"):
		seed_val = RunState.creation_params.custom_seed
	if seed_val == 0 and RunState.creation_params.has("custom_seed"):
		seed_val = RunState.creation_params.custom_seed
	_seed_label.text = "世界种子: " + str(seed_val)
	
	_current_stage_idx = 0
	_start_button.disabled = true
	for i in range(_stage_labels.size()):
		_stage_labels[i].text = _stages[i] + " [等待中]"
		_stage_labels[i].modulate = Color.WHITE
		
	_timer.start()

func _on_timer_timeout() -> void:
	if _current_stage_idx < _stage_labels.size():
		var lbl := _stage_labels[_current_stage_idx]
		lbl.text = _stages[_current_stage_idx] + " [✓]"
		lbl.modulate = Color(0.2, 0.8, 0.2)
		_current_stage_idx += 1
	else:
		_timer.stop()
		_start_button.disabled = false
