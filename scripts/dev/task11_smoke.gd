extends RefCounted

class_name Task11Smoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, _scenario: String, seed: int, days: int) -> Dictionary:
	var resolved_days := maxi(4, days)
	print("SMOKE_START|task=task11|scenario=minimal_deity_loop|seed=%d|days=%d" % [seed, resolved_days])
	var outcome := _run_case(scene_root, time_service, run_state, event_log, seed, resolved_days, {})
	if bool(outcome.get("failed", false)):
		return outcome
	var runtime: Dictionary = outcome.get("runtime", {})
	var faith_state: Dictionary = runtime.get("faith", {})
	var income: Dictionary = runtime.get("last_income", {})
	var tiers: Dictionary = runtime.get("follower_tiers", {})
	var favored_intervention := str(runtime.get("favored_intervention", ""))
	var favored_target_tier := str(runtime.get("favored_target_tier", ""))
	var tier_ok := _assert_faith_tiers(tiers, income)
	var intervention_ok := _assert_interventions(event_log, favored_intervention, favored_target_tier)
	var faith_balanced := int(faith_state.get("generated_total", 0)) > int(faith_state.get("spent_total", 0)) and int(faith_state.get("current", 0)) > 0
	print("ASSERT|scenario=task11_deity_loop|tier_ok=%s|intervention_ok=%s|faith_balanced=%s|faith_current=%d|faith_generated=%d|faith_spent=%d|favored_intervention=%s|favored_target_tier=%s" % [
		str(tier_ok),
		str(intervention_ok),
		str(faith_balanced),
		int(faith_state.get("current", 0)),
		int(faith_state.get("generated_total", 0)),
		int(faith_state.get("spent_total", 0)),
		favored_intervention,
		favored_target_tier,
	])
	return {
		"failed": not (tier_ok and intervention_ok and faith_balanced),
		"message": "task11 最小神明循环验证通过" if tier_ok and intervention_ok and faith_balanced else "task11 神明循环断言失败",
	}


func _run_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int, options: Dictionary) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"deity")
	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.configure_deity_mode(options)
	runner.bootstrap(seed)
	runner.advance_days(days, false, true)
	for line in event_log.get_summary_lines(40):
		print(line)
	var runtime: Dictionary = runner.get_deity_runtime()
	runner.free()
	return {
		"failed": runtime.is_empty(),
		"message": "task11 运行时为空",
		"runtime": runtime,
	}


func _assert_faith_tiers(tiers: Dictionary, income: Dictionary) -> bool:
	var shallow: Dictionary = income.get("details", {}).get("shallow_believer", {})
	var believer: Dictionary = income.get("details", {}).get("believer", {})
	var fervent: Dictionary = income.get("details", {}).get("fervent_believer", {})
	var counts_visible := int(tiers.get("shallow_believer", {}).get("count", 0)) >= 1 and int(tiers.get("believer", {}).get("count", 0)) >= 1 and int(tiers.get("fervent_believer", {}).get("count", 0)) >= 1
	var gain_ordered := int(shallow.get("faith_per_follower", 0)) < int(believer.get("faith_per_follower", 0)) and int(believer.get("faith_per_follower", 0)) < int(fervent.get("faith_per_follower", 0))
	var total_visible := int(income.get("total_gain", 0)) == int(shallow.get("gain", 0)) + int(believer.get("gain", 0)) + int(fervent.get("gain", 0))
	print("CASE|scenario=task11_faith_income|shallow_count=%d|believer_count=%d|fervent_count=%d|shallow_gain=%d|believer_gain=%d|fervent_gain=%d|total_gain=%d" % [
		int(tiers.get("shallow_believer", {}).get("count", 0)),
		int(tiers.get("believer", {}).get("count", 0)),
		int(tiers.get("fervent_believer", {}).get("count", 0)),
		int(shallow.get("gain", 0)),
		int(believer.get("gain", 0)),
		int(fervent.get("gain", 0)),
		int(income.get("total_gain", 0)),
	])
	return counts_visible and gain_ordered and total_visible


func _assert_interventions(event_log: Node, favored_intervention: String, favored_target_tier: String) -> bool:
	var intervention_ids := {}
	var favored_seen := false
	var target_bias_seen := false
	for entry in event_log.entries:
		if str(entry.get("category", "")) != "deity_intervention":
			continue
		var direct_cause := str(entry.get("direct_cause", ""))
		intervention_ids[direct_cause] = true
		var trace: Dictionary = entry.get("trace", {})
		if bool(trace.get("preferred_by_aspect", false)) and direct_cause == favored_intervention:
			favored_seen = true
		if str(trace.get("target_tier", "")) == favored_target_tier:
			target_bias_seen = true
	print("CASE|scenario=task11_interventions|types=%d|favored_seen=%s|target_bias_seen=%s|favored_intervention=%s|favored_target_tier=%s" % [
		intervention_ids.size(),
		str(favored_seen),
		str(target_bias_seen),
		favored_intervention,
		favored_target_tier,
	])
	return intervention_ids.size() >= 3 and favored_seen and target_bias_seen
