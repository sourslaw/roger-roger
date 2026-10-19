extends Node

func get_room_data() -> Dictionary:
	return {
		"id": "study",
		"title": "The Study // Vault of Ancestral Knowledge",
		"hotspots": [
			{
				"kind": "move",
				"label": "Return Living Room",
				"target": "living"
			},
			{
				"kind": "inspect",
				"id": "terminal",
				"label": "Access CRT Terminal",
				"keyword": "Project Code: ARCHON",
				"requires": ["recorder"],
				"lock_hint": "Find the poolside recorder first.",
				"message": "ARCHON session restored. Vault lock expects six-character phrase."
			},
			{
				"kind": "inspect",
				"id": "briefcase",
				"label": "Inspect Locked Briefcase",
				"requires": ["terminal"],
				"lock_hint": "Access the CRT terminal first.",
				"message": "Briefcase engraving matches the shell company crest from the cards."
			}
		]
	}
