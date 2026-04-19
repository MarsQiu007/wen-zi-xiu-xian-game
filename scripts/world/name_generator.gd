extends RefCounted
class_name NameGenerator

const SURNAMES := ["李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴", "徐", "孙", "马", "朱", "胡", "郭", "林", "何", "高", "罗", "郑", "梁", "谢", "宋", "唐", "韩", "冯", "邓", "曹", "彭", "曾", "萧", "田", "董", "潘", "袁", "蔡", "蒋", "余", "于", "杜", "叶", "程", "魏", "苏", "吕", "丁", "任", "沈"]
const MALE_NAMES := ["天行", "云飞", "志远", "浩然", "明轩", "子墨", "逸风", "清源", "玄明", "道生", "修远", "凌云", "承志", "文渊", "景行", "思远", "鸿飞", "正阳", "长青", "无极", "太初", "归元", "守一", "明德", "致远"]
const FEMALE_NAMES := ["月华", "云裳", "紫烟", "清韵", "灵珊", "若水", "飞雪", "凝霜", "素心", "瑶光", "碧落", "青莲", "如梦", "含烟", "沐风", "静远", "思雨", "映月", "兰心", "芷若"]
const REGION_PREFIXES := ["青云", "紫霄", "碧落", "玄天", "太虚", "灵台", "九华", "苍穹", "玉清", "金顶", "天柱", "仙霞", "龙脊", "凤鸣", "虎啸", "鹤鸣", "云台", "星河", "月华", "日曜"]
const REGION_SUFFIXES := ["山", "峰", "谷", "城", "镇", "村", "境", "洞", "湖", "林", "崖", "台", "阁", "观", "寺"]


static func generate_character_name(rng: RefCounted) -> String:
	var surname: String = str(SURNAMES[_rng_next_int(rng, SURNAMES.size())])
	var is_male := _rng_next_int(rng, 2) == 0
	var given_name: String
	if is_male:
		given_name = str(MALE_NAMES[_rng_next_int(rng, MALE_NAMES.size())])
	else:
		given_name = str(FEMALE_NAMES[_rng_next_int(rng, FEMALE_NAMES.size())])
	return surname + given_name


static func generate_region_name(rng: RefCounted) -> String:
	var prefix: String = str(REGION_PREFIXES[_rng_next_int(rng, REGION_PREFIXES.size())])
	var suffix: String = str(REGION_SUFFIXES[_rng_next_int(rng, REGION_SUFFIXES.size())])
	return prefix + suffix


static func _rng_next_int(rng: RefCounted, max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	if rng != null and rng.has_method("next_int"):
		return int(rng.next_int(max_exclusive))
	if rng != null and rng.has_method("randi"):
		return int(rng.randi()) % max_exclusive
	return 0
