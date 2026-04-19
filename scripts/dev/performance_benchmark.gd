extends RefCounted
class_name PerformanceBenchmark

const WorldSeedDataScript = preload("res://scripts/data/world_seed_data.gd")
const WorldGeneratorScript = preload("res://scripts/world/world_generator.gd")
const SimulationRunnerScript = preload("res://scripts/sim/simulation_runner.gd")
const TimeServiceScript = preload("res://autoload/time_service.gd")
const EventLogScript = preload("res://autoload/event_log.gd")
const RunStateScript = preload("res://autoload/run_state.gd")
const LocationServiceScript = preload("res://autoload/location_service.gd")

const DEFAULT_REGION_COUNT := 7
const DEFAULT_RESOURCE_DENSITY := 0.5
const DEFAULT_MONSTER_DENSITY := 0.3
const DEFAULT_TICK_HOURS := 24.0
const REPORT_PATH := ".sisyphus/evidence/task-18-benchmark-report.txt"


func benchmark_tick_performance(npc_count: int = 200, ticks: int = 30) -> Dictionary:
	var errors: Array = []
	var tick_samples_usec: Array = []
	var runner_pack := _create_runner(npc_count)
	if not bool(runner_pack.get("ok", false)):
		errors.append(str(runner_pack.get("error", "runner_setup_failed")))
		return {
			"p50_ms": 0.0,
			"p95_ms": 0.0,
			"p99_ms": 0.0,
			"total_ticks": 0,
			"errors": errors,
		}

	var runner: Node = runner_pack.get("runner")
	for _i in range(maxi(0, ticks)):
		var start_usec := Time.get_ticks_usec()
		runner.advance_tick(DEFAULT_TICK_HOURS)
		var end_usec := Time.get_ticks_usec()
		tick_samples_usec.append(end_usec - start_usec)

	var p50_ms := _percentile_ms(tick_samples_usec, 0.50)
	var p95_ms := _percentile_ms(tick_samples_usec, 0.95)
	var p99_ms := _percentile_ms(tick_samples_usec, 0.99)

	_cleanup_runner(runner_pack)
	return {
		"p50_ms": p50_ms,
		"p95_ms": p95_ms,
		"p99_ms": p99_ms,
		"total_ticks": tick_samples_usec.size(),
		"errors": errors,
	}


func benchmark_world_generation(npc_count: int = 30, iterations: int = 10) -> Dictionary:
	var generator := WorldGeneratorScript.new()
	var samples_ms: Array = []
	for i in range(maxi(0, iterations)):
		var seed_data := WorldSeedDataScript.new()
		seed_data.seed_value = 1000 + i
		seed_data.region_count = DEFAULT_REGION_COUNT
		seed_data.npc_count = npc_count
		seed_data.resource_density = DEFAULT_RESOURCE_DENSITY
		seed_data.monster_density = DEFAULT_MONSTER_DENSITY

		var start_usec := Time.get_ticks_usec()
		var world_data: Dictionary = generator.call("generate", seed_data)
		var end_usec := Time.get_ticks_usec()
		if world_data.is_empty():
			continue
		samples_ms.append(float(end_usec - start_usec) / 1000.0)

	if samples_ms.is_empty():
		return {
			"avg_ms": 0.0,
			"min_ms": 0.0,
			"max_ms": 0.0,
			"iterations": 0,
		}

	var total_ms := 0.0
	var min_ms: float = float(samples_ms[0])
	var max_ms: float = float(samples_ms[0])
	for sample in samples_ms:
		var value := float(sample)
		total_ms += value
		if value < min_ms:
			min_ms = value
		if value > max_ms:
			max_ms = value

	return {
		"avg_ms": total_ms / float(samples_ms.size()),
		"min_ms": min_ms,
		"max_ms": max_ms,
		"iterations": samples_ms.size(),
	}


func benchmark_save_size(npc_count: int = 200, advance_days: int = 7) -> Dictionary:
	var runner_pack := _create_runner(npc_count)
	if not bool(runner_pack.get("ok", false)):
		return {
			"size_bytes": 0,
			"size_kb": 0.0,
			"npc_count": npc_count,
			"advance_days": advance_days,
		}

	var runner: Node = runner_pack.get("runner")
	for _i in range(maxi(0, advance_days)):
		runner.advance_tick(DEFAULT_TICK_HOURS)

	var snapshot: Dictionary = runner.get_snapshot()
	var json_text := JSON.stringify(snapshot)
	var size_bytes := json_text.to_utf8_buffer().size()
	_cleanup_runner(runner_pack)

	return {
		"size_bytes": size_bytes,
		"size_kb": float(size_bytes) / 1024.0,
		"npc_count": npc_count,
		"advance_days": advance_days,
	}


func run_all_benchmarks() -> Dictionary:
	var tick_result := benchmark_tick_performance(200, 30)
	var world_result_30 := benchmark_world_generation(30, 10)
	var world_result_200 := benchmark_world_generation(200, 10)
	var save_result := benchmark_save_size(200, 7)

	var summary := {
		"tick": tick_result,
		"world_generation_30": world_result_30,
		"world_generation_200": world_result_200,
		"save_size": save_result,
		"targets": {
			"tick_p95_lt_50ms": float(tick_result.get("p95_ms", 999999.0)) < 50.0,
			"world_30_lt_100ms": float(world_result_30.get("avg_ms", 999999.0)) < 100.0,
			"world_200_lt_500ms": float(world_result_200.get("avg_ms", 999999.0)) < 500.0,
			"save_lt_1mb": int(save_result.get("size_bytes", 999999999)) < 1024 * 1024,
		},
	}

	# 若指标不达标，仅记录瓶颈提示，不修改核心逻辑。
	# 已知潜在瓶颈：
	# 1) 200 NPC + 30 tick 时，SimulationRunner 的 NPC 决策循环与事件日志写入占用主要时间。
	# 2) 世界生成平均耗时受角色/关系批量生成影响明显。
	# 3) 存档体积主要由 runtime_characters、relationship_network、event_log_entries 增长驱动。
	_write_report(summary)
	return summary


func _create_runner(npc_count: int) -> Dictionary:
	var time_service: Node = TimeServiceScript.new()
	var event_log: Node = EventLogScript.new()
	var run_state: Node = RunStateScript.new()
	var location_service: Node = LocationServiceScript.new()
	var runner: Node = SimulationRunnerScript.new()

	runner.setup_services(time_service, event_log, run_state, location_service)

	var seed_data := WorldSeedDataScript.new()
	seed_data.seed_value = int(Time.get_ticks_usec() % 2147483647)
	seed_data.region_count = DEFAULT_REGION_COUNT
	seed_data.npc_count = npc_count
	seed_data.resource_density = DEFAULT_RESOURCE_DENSITY
	seed_data.monster_density = DEFAULT_MONSTER_DENSITY

	var creation_params := {
		"snapshot_version": 1,
		"character_name": "性能测试主角",
		"morality_value": 0.0,
		"birth_region_id": "region_0",
		"opening_type": "youth",
		"difficulty": 1,
		"custom_seed": int(seed_data.seed_value),
	}

	runner.bootstrap_from_creation(creation_params, seed_data.to_dict())
	return {
		"ok": true,
		"runner": runner,
		"time_service": time_service,
		"event_log": event_log,
		"run_state": run_state,
		"location_service": location_service,
	}


func _cleanup_runner(runner_pack: Dictionary) -> void:
	var runner: Node = runner_pack.get("runner")
	if runner != null:
		runner.free()
	for key in ["location_service", "run_state", "event_log", "time_service"]:
		var node: Node = runner_pack.get(key)
		if node != null:
			node.free()


func _percentile_ms(samples_usec: Array, percentile: float) -> float:
	if samples_usec.is_empty():
		return 0.0
	var sorted: Array = samples_usec.duplicate()
	sorted.sort()
	var clamped := clampf(percentile, 0.0, 1.0)
	var index := int(ceili(clamped * float(sorted.size())) - 1)
	index = clampi(index, 0, sorted.size() - 1)
	return float(sorted[index]) / 1000.0


func _write_report(report: Dictionary) -> void:
	var evidence_dir_abs := ProjectSettings.globalize_path("res://.sisyphus/evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir_abs)
	var report_abs := ProjectSettings.globalize_path("res://" + REPORT_PATH)
	var file := FileAccess.open(report_abs, FileAccess.WRITE)
	if file == null:
		return

	file.store_string("=== Task 18 性能基准报告 ===\n")
	file.store_string("tick: %s\n" % JSON.stringify(report.get("tick", {})))
	file.store_string("world_generation_30: %s\n" % JSON.stringify(report.get("world_generation_30", {})))
	file.store_string("world_generation_200: %s\n" % JSON.stringify(report.get("world_generation_200", {})))
	file.store_string("save_size: %s\n" % JSON.stringify(report.get("save_size", {})))
	file.store_string("targets: %s\n" % JSON.stringify(report.get("targets", {})))
	file.flush()
