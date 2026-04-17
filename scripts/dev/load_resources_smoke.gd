extends SceneTree

const SAMPLE_PATHS := {
	"characters": [
		"res://resources/world/samples/mvp_character_village_heir.tres",
		"res://resources/world/samples/mvp_character_divine_visionary.tres",
	],
	"families": [
		"res://resources/world/samples/mvp_family_lin_family.tres",
		"res://resources/world/samples/mvp_family_shen_family.tres",
	],
	"factions": [
		"res://resources/world/samples/mvp_faction_village_settlement.tres",
		"res://resources/world/samples/mvp_faction_small_sect.tres",
		"res://resources/world/samples/mvp_faction_small_city.tres",
		"res://resources/world/samples/mvp_divine_cult.tres",
	],
	"regions": [
		"res://resources/world/samples/mvp_village_region.tres",
		"res://resources/world/samples/mvp_sect_mountain_region.tres",
		"res://resources/world/samples/mvp_small_city_region.tres",
		"res://resources/world/samples/mvp_beast_ridge_region.tres",
		"res://resources/world/samples/mvp_ghost_ruins_region.tres",
		"res://resources/world/samples/mvp_secret_realm_gate_region.tres",
		"res://resources/world/samples/mvp_deadfall_abyss_region.tres",
	],
	"event_templates": [
		"res://resources/world/samples/mvp_event_harvest_festival.tres",
		"res://resources/world/samples/mvp_event_sect_recruitment.tres",
	],
	"doctrines": [
		"res://resources/world/samples/mvp_doctrine_orthodox_doctrine.tres",
		"res://resources/world/samples/mvp_doctrine_divine_doctrine.tres",
	],
	"deities": [
		"res://resources/world/samples/mvp_deity_patron_deity.tres",
	],
}


func _initialize() -> void:
	var output_lines: PackedStringArray = PackedStringArray()
	var failed := false

	output_lines.append("[task-2] 开始加载首版资源样例")
	for group_name in SAMPLE_PATHS.keys():
		var paths: Array = SAMPLE_PATHS[group_name]
		for path in paths:
			var resource := load(path)
			if resource == null:
				failed = true
				output_lines.append("[error] 无法加载: %s" % path)
				continue
			output_lines.append(_describe_resource(group_name, path, resource))

	var catalog := load("res://resources/world/world_data_catalog.tres")
	if catalog == null:
		failed = true
		output_lines.append("[error] 无法加载目录资源: res://resources/world/world_data_catalog.tres")
	elif catalog != null and catalog.has_method("validate_required_fields"):
		var world_catalog := catalog
		var issues: PackedStringArray = world_catalog.validate_required_fields()
		output_lines.append("[catalog] characters=%d families=%d factions=%d regions=%d events=%d doctrines=%d deities=%d" % [
			world_catalog.characters.size(),
			world_catalog.families.size(),
			world_catalog.factions.size(),
			world_catalog.regions.size(),
			world_catalog.event_templates.size(),
			world_catalog.doctrines.size(),
			world_catalog.deities.size(),
		])
		if issues.is_empty():
			output_lines.append("[catalog] 字段校验通过")
		else:
			failed = true
			for issue in issues:
				output_lines.append("[catalog-error] %s" % issue)
	else:
		failed = true
		output_lines.append("[error] 目录资源类型不正确")

	for line in output_lines:
		print(line)

	quit(1 if failed else 0)


func _describe_resource(group_name: String, path: String, resource: Resource) -> String:
	if resource == null or not resource.has_method("get"):
		return "[error] %s 不是资源对象: %s" % [group_name, path]

	var base_id = resource.get("id")
	var base_name = resource.get("display_name")
	var human_visible = resource.get("human_visible")
	var deity_visible = resource.get("deity_visible")
	if base_id == null:
		base_id = ""
	if base_name == null:
		base_name = ""
	if human_visible == null:
		human_visible = true
	if deity_visible == null:
		deity_visible = true
	if str(base_name).is_empty() and str(base_id).is_empty():
		return "[error] %s 不是 WorldBaseData 派生资源: %s" % [group_name, path]

	var mode_summary := "human=%s deity=%s" % [str(human_visible), str(deity_visible)]
	match group_name:
		"characters":
			return "[character] %s | %s | family=%s faction=%s region=%s faith=%s inheritance=%s" % [base_id, base_name, str(resource.get("family_id")), str(resource.get("faction_id")), str(resource.get("region_id")), str(resource.get("faith_affinity")), str(resource.get("inheritance_priority"))]
		"families":
			return "[family] %s | %s | seat=%s rule=%s members=%s" % [base_id, base_name, str(resource.get("seat_region_id")), str(resource.get("inheritance_rule")), str((resource.get("notable_member_ids") as PackedStringArray).size())]
		"factions":
			return "[faction] %s | %s | type=%s tier=%s region=%s doctrine=%s deity=%s" % [base_id, base_name, str(resource.get("faction_type")), str(resource.get("faction_tier")), str(resource.get("headquarters_region_id")), str(resource.get("associated_doctrine_id")), str(resource.get("patron_deity_id"))]
		"regions":
			return "[region] %s | %s | type=%s control=%s pop=%s resources=%s" % [base_id, base_name, str(resource.get("region_type")), str(resource.get("controlling_faction_id")), str(resource.get("active_population_hint")), ",".join(resource.get("resource_tags") as PackedStringArray)]
		"event_templates":
			return "[event] %s | %s | type=%s severity=%s %s" % [base_id, base_name, str(resource.get("event_type")), str(resource.get("severity")), mode_summary]
		"doctrines":
			return "[doctrine] %s | %s | type=%s scope=%s deity=%s tenets=%s" % [base_id, base_name, str(resource.get("doctrine_type")), str(resource.get("authority_scope")), str(resource.get("associated_deity_id")), str((resource.get("core_tenets") as PackedStringArray).size())]
		"deities":
			return "[deity] %s | %s | type=%s scope=%s faith=%s domains=%s" % [base_id, base_name, str(resource.get("deity_type")), str(resource.get("manifestation_scope")), str(resource.get("faith_income_hint")), str((resource.get("domain_tags") as PackedStringArray).size())]
		_:
			return "[warn] 未知分组 %s: %s (%s)" % [group_name, path, mode_summary]
