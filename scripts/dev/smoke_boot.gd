extends SceneTree


func _initialize() -> void:
	print("SMOKE_BOOT_START")
	var packed: PackedScene = load("res://scenes/main/game_root.tscn")
	var root: Node = packed.instantiate()
	print("ROOT_SCENE: %s" % root.name)
	print("CHILDREN: %d" % root.get_child_count())
	for child in root.get_children():
		print("CHILD: %s:%s" % [child.name, child.get_class()])
	root.free()
	quit()
