extends Node

signal day_changed(day: int)
signal day_completed(day: int, total_minutes: int)
signal time_advanced(total_minutes: int)
signal hour_advanced(total_hours: float)
signal month_changed(month: int)
signal speed_tier_changed(tier: int)

const MINUTES_PER_DAY := 24 * 60
const HOURS_PER_DAY := 24.0
const DAYS_PER_MONTH := 30
const EPSILON := 0.000001

var day: int = 1
var minute_of_day: int = 0
var total_hours: float = 0.0
var speed_tier: int = 2


func _recalculate_from_total_hours() -> void:
	var total_minutes := int(floor(total_hours * 60.0 + EPSILON))
	day = int(total_minutes / MINUTES_PER_DAY) + 1
	minute_of_day = total_minutes % MINUTES_PER_DAY


func get_month() -> int:
	return int((day - 1) / DAYS_PER_MONTH) + 1


func reset_clock(start_day: int = 1, start_minute: int = 0) -> void:
	day = maxi(1, start_day)
	minute_of_day = clampi(start_minute, 0, MINUTES_PER_DAY - 1)
	total_hours = float((day - 1) * 24) + float(minute_of_day) / 60.0
	time_advanced.emit(get_total_minutes())
	hour_advanced.emit(total_hours)


func advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return
	advance_hours(float(minutes) / 60.0)


func advance_hours(hours: float) -> void:
	if hours <= 0.0:
		return
	
	var prev_day := day
	var prev_month := get_month()
	
	total_hours += hours
	_recalculate_from_total_hours()
	
	hour_advanced.emit(total_hours)
	
	# Emit day_completed for each day boundary crossed
	var current_day := day
	while prev_day < current_day:
		var completed_day := prev_day
		prev_day += 1
		day_completed.emit(completed_day, completed_day * MINUTES_PER_DAY)
	
	if prev_day != day:
		day_changed.emit(day)
	
	# Emit month_changed for each month boundary crossed
	var current_month := get_month()
	while prev_month < current_month:
		prev_month += 1
		month_changed.emit(prev_month)
	
	time_advanced.emit(get_total_minutes())


func advance_day() -> Dictionary:
	var completed_day := day
	advance_hours(HOURS_PER_DAY)
	return {
		"completed_day": completed_day,
		"current_day": day,
		"minute_of_day": minute_of_day,
		"total_minutes": get_total_minutes(),
	}


func advance_days(days_to_advance: int) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for _index in range(maxi(0, days_to_advance)):
		reports.append(advance_day())
	return reports


func get_total_minutes() -> int:
	return int(floor(total_hours * 60.0 + EPSILON))


func get_completed_day() -> int:
	if minute_of_day == 0:
		return maxi(1, day - 1)
	return day


func get_clock_text() -> String:
	var hour := int(minute_of_day / 60.0)
	var minute := minute_of_day % 60
	return "第%d天 %02d:%02d" % [day, hour, minute]


func get_clock_text_detailed() -> String:
	return get_clock_text()


func get_hours_per_tick() -> float:
	match speed_tier:
		1: return 0.5
		2: return 1.0
		3: return 24.0
		4: return 720.0
		_: return 1.0


func set_speed_tier(tier: int) -> void:
	var clamped := clampi(tier, 1, 4)
	if clamped == speed_tier:
		return
	speed_tier = clamped
	speed_tier_changed.emit(speed_tier)


func get_speed_tier_name() -> StringName:
	match speed_tier:
		1: return &"half_hour"
		2: return &"one_hour"
		3: return &"one_day"
		4: return &"one_month"
		_: return &"one_hour"


func get_snapshot() -> Dictionary:
	return {
		"day": day,
		"completed_day": get_completed_day(),
		"minute_of_day": minute_of_day,
		"total_minutes": get_total_minutes(),
		"clock_text": get_clock_text(),
		"total_hours": total_hours,
		"speed_tier": speed_tier,
		"hours_per_tick": get_hours_per_tick(),
		"month": get_month(),
	}
