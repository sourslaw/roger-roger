extends Node

var discovered: Dictionary = {}
var keywords: Array[String] = []
var notes: Array[String] = []
var current_room_id: String = "living"
var total_discoveries: int = 0

func reset() -> void:
	discovered.clear()
	keywords.clear()
	notes.clear()
	current_room_id = "living"
	total_discoveries = 0

func configure_total(count: int) -> void:
	total_discoveries = max(count, 0)

func is_locked(spot: Dictionary) -> bool:
	if not spot.has("requires"):
		return false
	var requires: Array = spot["requires"]
	for requirement in requires:
		if not discovered.has(String(requirement)):
			return true
	return false

func discover(spot: Dictionary) -> bool:
	var spot_id := String(spot.get("id", ""))
	if spot_id.is_empty():
		return false
	if discovered.has(spot_id):
		return false

	discovered[spot_id] = true
	if spot.has("keyword"):
		var keyword := String(spot["keyword"])
		if not keyword.is_empty() and not keywords.has(keyword):
			keywords.append(keyword)
	notes.append(String(spot.get("message", "Clue discovered.")))
	return true

func has_discovered(spot_id: String) -> bool:
	return discovered.has(spot_id)

func discovered_count() -> int:
	return discovered.size()
