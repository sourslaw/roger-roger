extends Node

func get_room_data() -> Dictionary:
	return {
		"id": "pool",
		"title": "Poolside Patio // Open Air Sanctuary",
		"hotspots": [
			{
				"kind": "move",
				"label": "Enter Study",
				"target": "study"
			},
			{
				"kind": "inspect",
				"id": "recorder",
				"label": "Check Recorder",
				"keyword": "Roger's Wiretap",
				"message": "The tape starts with rain static, then Roger's voice at 00:14."
			},
			{
				"kind": "inspect",
				"id": "glass",
				"label": "Inspect Poolside Footprints",
				"requires": ["cards"],
				"lock_hint": "Study the business cards first.",
				"message": "Wet prints leave the patio and angle toward the study side door."
			}
		]
	}
