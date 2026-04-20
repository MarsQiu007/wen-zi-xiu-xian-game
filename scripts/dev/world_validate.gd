extends SceneTree

const CATALOG_PATH := "res://resources/world/world_data_catalog.tres"

const REQUIRED_REGION_TYPES := {
	"village": "村镇",
	"sect_hub": "小宗门",
	"city": "小城",
	"beast_zone": "妖兽活动区",
	"ghost_zone": "鬼怪异变点",
	"mystic_entrance": "秘境入口",
	"forbidden_zone": "绝地传闻点",
}


func _initialize() -> void:
	var catalog: Resource = load(CATALOG_PATH)
	if catalog == null:
		print("[error] 无法加载世界目录: %s" % CATALOG_PATH)
		quit(1)
		return

	var failed := false
	var region_counts := {}
	var region_ids := {}
	var region_adjacency := {}

	for region in catalog.regions:
		if region == null:
			failed = true
			print("[error] 存在空区域资源引用")
			continue
		var region_id := str(region.get("id"))
		var region_type := str(region.get("region_type"))
		var controlling_faction_id := str(region.get("controlling_faction_id"))
		var adjacent_region_ids := region.get("adjacent_region_ids") as PackedStringArray
		region_ids[region_id] = true
		region_adjacency[region_id] = adjacent_region_ids
		region_counts[region_type] = int(region_counts.get(region_type, 0)) + 1
		print("REGION|id=%s|type=%s|control=%s|parent=%s|adjacent=%s|sites=%s|danger=%s" % [
			_sanitize(region_id),
			_sanitize(region_type),
			_sanitize(controlling_faction_id),
			_sanitize(str(region.get("parent_region_id"))),
			_sanitize(",".join(adjacent_region_ids)),
			_sanitize(",".join(region.get("key_site_tags") as PackedStringArray)),
			_sanitize(",".join(region.get("danger_tags") as PackedStringArray)),
		])

	for region_type in REQUIRED_REGION_TYPES.keys():
		var count := int(region_counts.get(region_type, 0))
		print("CHECK|region_type=%s|label=%s|count=%d" % [region_type, REQUIRED_REGION_TYPES[region_type], count])
		if count < 1:
			failed = true
			print("[error] 缺少必需区域类型: %s" % REQUIRED_REGION_TYPES[region_type])

	for region_id in region_adjacency.keys():
		var adjacent_ids: PackedStringArray = region_adjacency[region_id]
		for adjacent_id in adjacent_ids:
			var target_region_id := str(adjacent_id)
			if target_region_id.is_empty() or not region_ids.has(target_region_id):
				failed = true
				print("[error] 区域邻接引用无效: %s -> %s" % [region_id, target_region_id])
				continue
			var target_adjacent: PackedStringArray = region_adjacency.get(target_region_id, PackedStringArray())
			if not target_adjacent.has(region_id):
				failed = true
				print("[error] 区域邻接非双向: %s -> %s" % [region_id, target_region_id])

	for faction in catalog.factions:
		if faction == null:
			failed = true
			print("[error] 存在空势力资源引用")
			continue
		var faction_id := str(faction.get("id"))
		var hq_region_id := str(faction.get("headquarters_region_id"))
		var territory_ids := faction.get("territory_region_ids") as PackedStringArray
		var relations_summary := str(faction.get("relations_summary"))
		print("FACTION|id=%s|hq=%s|territories=%s|summary=%s" % [
			_sanitize(faction_id),
			_sanitize(hq_region_id),
			_sanitize(",".join(territory_ids)),
			_sanitize(relations_summary),
		])
		if hq_region_id.is_empty() or not region_ids.has(hq_region_id):
			failed = true
			print("[error] 势力总部区域无效: %s -> %s" % [faction_id, hq_region_id])
		for territory_id in territory_ids:
			if not region_ids.has(str(territory_id)):
				failed = true
				print("[error] 势力领地区域无效: %s -> %s" % [faction_id, str(territory_id)])
		if relations_summary.is_empty():
			failed = true
			print("[error] 势力缺少关系摘要: %s" % faction_id)

	quit(1 if failed else 0)


func _sanitize(value: String) -> String:
	return value.replace("|", "／").replace("\n", " ")
