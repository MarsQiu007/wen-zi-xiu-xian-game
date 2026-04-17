extends RefCounted
class_name Task8Smoke

const RUNNER_SCENE := preload("res://scenes/sim/simulation_runner.tscn")


func run(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, scenario: String, seed: int, days: int) -> Dictionary:
	var normalized_scenario := scenario.to_lower()
	match normalized_scenario:
		"age_openings":
			return _run_age_openings(scene_root, time_service, run_state, event_log, seed, days)
		"cultivation_gate":
			return _run_cultivation_gate(scene_root, time_service, run_state, event_log, seed, days)
		_:
			return {
				"failed": true,
				"message": "未知 task8 场景: %s" % normalized_scenario,
			}


func _run_age_openings(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int) -> Dictionary:
	var resolved_days := maxi(5, days)
	print("SMOKE_START|task=task8|scenario=age_openings|seed=%d|days=%d" % [seed, resolved_days])
	var opening_types := ["youth", "young_adult", "adult"]
	var snapshots := []
	for opening_type in opening_types:
		var outcome := _run_case(scene_root, time_service, run_state, event_log, seed, resolved_days, {
			"opening_type": opening_type,
		})
		if bool(outcome.get("failed", false)):
			return outcome
		var runtime: Dictionary = outcome.get("runtime", {})
		var snapshot := {
			"opening_type": opening_type,
			"age_years": int(runtime.get("player", {}).get("age_years", 0)),
			"dominant_branch": str(runtime.get("dominant_branch", "")),
			"survival_pressure": int(runtime.get("pressures", {}).get("survival", 0)),
			"family_pressure": int(runtime.get("pressures", {}).get("family", 0)),
			"learning_pressure": int(runtime.get("pressures", {}).get("learning", 0)),
		}
		snapshots.append(snapshot)
		print("CASE|scenario=age_openings|opening_type=%s|age_years=%d|dominant_branch=%s|survival_pressure=%d|family_pressure=%d|learning_pressure=%d" % [
			str(snapshot.get("opening_type", "")),
			int(snapshot.get("age_years", 0)),
			str(snapshot.get("dominant_branch", "")),
			int(snapshot.get("survival_pressure", 0)),
			int(snapshot.get("family_pressure", 0)),
			int(snapshot.get("learning_pressure", 0)),
		])
	if snapshots.size() != 3:
		return {
			"failed": true,
			"message": "age_openings 场景未获得三类开局快照",
		}
	var youth: Dictionary = snapshots[0]
	var young_adult: Dictionary = snapshots[1]
	var adult: Dictionary = snapshots[2]
	var ages_distinct := int(youth.get("age_years", 0)) < int(young_adult.get("age_years", 0)) and int(young_adult.get("age_years", 0)) < int(adult.get("age_years", 0))
	var branches_distinct := {
		str(youth.get("dominant_branch", "")): true,
		str(young_adult.get("dominant_branch", "")): true,
		str(adult.get("dominant_branch", "")): true,
	}.size() == 3
	var pressure_diff_visible := int(youth.get("learning_pressure", 0)) != int(young_adult.get("learning_pressure", 0)) or int(youth.get("family_pressure", 0)) != int(young_adult.get("family_pressure", 0)) or int(youth.get("survival_pressure", 0)) != int(adult.get("survival_pressure", 0))
	print("ASSERT|scenario=age_openings|ages_distinct=%s|branches_distinct=%s|pressure_diff_visible=%s" % [
		str(ages_distinct),
		str(branches_distinct),
		str(pressure_diff_visible),
	])
	return {
		"failed": not (ages_distinct and branches_distinct and pressure_diff_visible),
		"message": "age_openings 场景完成",
	}


func _run_cultivation_gate(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int) -> Dictionary:
	var resolved_days := maxi(3, days)
	print("SMOKE_START|task=task8|scenario=cultivation_gate|seed=%d|days=%d" % [seed, resolved_days])
	var passive_outcome := _run_case(scene_root, time_service, run_state, event_log, seed, resolved_days, {
		"opening_type": "youth",
		"strategy": "passive",
	})
	if bool(passive_outcome.get("failed", false)):
		return passive_outcome
	var active_outcome := _run_case(scene_root, time_service, run_state, event_log, seed, resolved_days, {
		"opening_type": "youth",
		"strategy": "active_cultivation",
	})
	if bool(active_outcome.get("failed", false)):
		return active_outcome
	var passive_runtime: Dictionary = passive_outcome.get("runtime", {})
	var active_runtime: Dictionary = active_outcome.get("runtime", {})
	print("CASE|scenario=cultivation_gate|path=passive|contact_score=%d|active_contact=%s|opportunity_unlocked=%s|dominant_branch=%s" % [
		int(passive_runtime.get("cultivation_gate", {}).get("contact_score", 0)),
		str(passive_runtime.get("cultivation_gate", {}).get("has_active_contact", false)),
		str(passive_runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false)),
		str(passive_runtime.get("dominant_branch", "")),
	])
	print("CASE|scenario=cultivation_gate|path=active|contact_score=%d|active_contact=%s|opportunity_unlocked=%s|dominant_branch=%s" % [
		int(active_runtime.get("cultivation_gate", {}).get("contact_score", 0)),
		str(active_runtime.get("cultivation_gate", {}).get("has_active_contact", false)),
		str(active_runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false)),
		str(active_runtime.get("dominant_branch", "")),
	])
	var passive_blocked := not bool(passive_runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false))
	var active_unlocked := bool(active_runtime.get("cultivation_gate", {}).get("opportunity_unlocked", false))
	var contact_gap := int(active_runtime.get("cultivation_gate", {}).get("contact_score", 0)) > int(passive_runtime.get("cultivation_gate", {}).get("contact_score", 0))
	print("ASSERT|scenario=cultivation_gate|passive_blocked=%s|active_unlocked=%s|contact_gap=%s" % [
		str(passive_blocked),
		str(active_unlocked),
		str(contact_gap),
	])
	return {
		"failed": not (passive_blocked and active_unlocked and contact_gap),
		"message": "cultivation_gate 场景完成",
	}


func _run_case(scene_root: Node, time_service: Node, run_state: Node, event_log: Node, seed: int, days: int, options: Dictionary) -> Dictionary:
	event_log.clear()
	time_service.reset_clock()
	run_state.set_mode(&"human")
	var runner: Node = RUNNER_SCENE.instantiate()
	scene_root.add_child(runner)
	runner.setup_services(time_service, event_log, run_state)
	runner.configure_human_mode(options)
	runner.bootstrap(seed)
	runner.advance_days(days, false, true)
	for line in event_log.get_summary_lines(20):
		print(line)
	var runtime: Dictionary = runner.get_human_runtime()
	runner.free()
	return {
		"failed": runtime.is_empty(),
		"message": "human runtime 为空",
		"runtime": runtime,
	}
