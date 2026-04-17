extends Node

signal day_changed(day: int)
signal day_completed(day: int, total_minutes: int)
signal time_advanced(total_minutes: int)

const MINUTES_PER_DAY := 24 * 60

var day: int = 1
var minute_of_day: int = 0


func reset_clock(start_day: int = 1, start_minute: int = 0) -> void:
	day = maxi(1, start_day)
	minute_of_day = clampi(start_minute, 0, MINUTES_PER_DAY - 1)
	time_advanced.emit(get_total_minutes())


func advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return

	minute_of_day += minutes
	while minute_of_day >= MINUTES_PER_DAY:
		var completed_day := day
		minute_of_day -= MINUTES_PER_DAY
		day_completed.emit(completed_day, get_total_minutes() - minute_of_day)
		day += 1
		day_changed.emit(day)

	time_advanced.emit(get_total_minutes())


func advance_day() -> Dictionary:
	var completed_day := day
	advance_minutes(MINUTES_PER_DAY)
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
	return (day - 1) * MINUTES_PER_DAY + minute_of_day


func get_completed_day() -> int:
	if minute_of_day == 0:
		return maxi(1, day - 1)
	return day


func get_clock_text() -> String:
	var hour := minute_of_day / 60
	var minute := minute_of_day % 60
	return "第%d天 %02d:%02d" % [day, hour, minute]


func get_snapshot() -> Dictionary:
	return {
		"day": day,
		"completed_day": get_completed_day(),
		"minute_of_day": minute_of_day,
		"total_minutes": get_total_minutes(),
		"clock_text": get_clock_text(),
	}
