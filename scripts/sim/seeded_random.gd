extends RefCounted
class_name SeededRandom

var seed_value: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	_rng.seed = new_seed


func next_int(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	return _rng.randi_range(0, max_exclusive - 1)


func next_float() -> float:
	return _rng.randf()


func pick_index(items: Array) -> int:
	if items.is_empty():
		return -1
	return next_int(items.size())
