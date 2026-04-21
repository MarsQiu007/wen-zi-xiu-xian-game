extends RefCounted
class_name RNGChannels

const STATE_VERSION := 1

var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _master_seed: int = 1
var _world_seed: int = 1
var _combat_seed: int = 1
var _loot_seed: int = 1


func seed_all(master_seed: int) -> void:
	_master_seed = master_seed
	_world_seed = _derive_seed(master_seed, 0)
	_combat_seed = _derive_seed(master_seed, 1)
	_loot_seed = _derive_seed(master_seed, 2)
	world_rng.seed = _world_seed
	combat_rng.seed = _combat_seed
	loot_rng.seed = _loot_seed


func get_world_rng() -> RandomNumberGenerator:
	return world_rng


func get_combat_rng() -> RandomNumberGenerator:
	return combat_rng


func get_loot_rng() -> RandomNumberGenerator:
	return loot_rng


func save_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"master_seed": _master_seed,
		"world_rng": _capture_rng_state(world_rng, _world_seed),
		"combat_rng": _capture_rng_state(combat_rng, _combat_seed),
		"loot_rng": _capture_rng_state(loot_rng, _loot_seed),
	}


func load_state(d: Dictionary) -> void:
	if d.is_empty():
		seed_all(1)
		return

	_master_seed = int(d.get("master_seed", 1))
	_world_seed = _derive_seed(_master_seed, 0)
	_combat_seed = _derive_seed(_master_seed, 1)
	_loot_seed = _derive_seed(_master_seed, 2)

	_apply_rng_state(world_rng, d.get("world_rng", {}), _world_seed)
	_apply_rng_state(combat_rng, d.get("combat_rng", {}), _combat_seed)
	_apply_rng_state(loot_rng, d.get("loot_rng", {}), _loot_seed)


func _capture_rng_state(rng: RandomNumberGenerator, fallback_seed: int) -> Dictionary:
	return {
		"seed": int(rng.seed) if int(rng.seed) != 0 else fallback_seed,
		"state": int(rng.state),
	}


func _apply_rng_state(rng: RandomNumberGenerator, value: Variant, fallback_seed: int) -> void:
	var state_data: Dictionary = value if value is Dictionary else {}
	var seed_value := int(state_data.get("seed", fallback_seed))
	var state_value := int(state_data.get("state", 0))
	rng.seed = seed_value
	if state_value != 0:
		rng.state = state_value


func _derive_seed(master_seed: int, channel_index: int) -> int:
	var value := int(master_seed)
	value ^= int(channel_index + 1) * 6364136223846793005
	value = int((value ^ (value >> 30)) * 1442695040888963407)
	value = int((value ^ (value >> 27)) * 7046029254386353131)
	value ^= value >> 31
	if value == 0:
		return channel_index + 1
	return value
