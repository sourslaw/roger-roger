extends Control

const ROOM_SCENES := {
	"living": preload("res://scenes/rooms/LivingRoom.tscn"),
	"pool": preload("res://scenes/rooms/PoolRoom.tscn"),
	"study": preload("res://scenes/rooms/StudyRoom.tscn")
}

@onready var room_title_label: Label = $Shell/Columns/LeftPane/RoomTitle
@onready var log_label: Label = $Shell/Columns/LeftPane/LogText
@onready var hotspot_list: VBoxContainer = $Shell/Columns/CenterPane/HotspotList
@onready var notebook_count_label: Label = $Shell/Columns/RightPane/NotebookCount
@onready var keyword_list: ItemList = $Shell/Columns/RightPane/KeywordList
@onready var discovered_list: ItemList = $Shell/Columns/RightPane/DiscoveredList
@onready var room_root: Node = $Shell/Columns/LeftPane/RoomViewport/RoomRoot

var room_catalog: Dictionary = {}
var active_room_node: Node = null
var active_room_data: Dictionary = {}

func _ready() -> void:
	GameState.reset()
	_build_room_catalog()
	_switch_room("living")

func _build_room_catalog() -> void:
	room_catalog.clear()
	var inspect_total := 0
	for room_id in ROOM_SCENES.keys():
		var room_node: Node = ROOM_SCENES[room_id].instantiate()
		var room_data: Dictionary = room_node.get_room_data()
		room_catalog[room_id] = room_data
		for spot in room_data.get("hotspots", []):
			if String(spot.get("kind", "")) == "inspect":
				inspect_total += 1
		room_node.queue_free()
	GameState.configure_total(inspect_total)

func _switch_room(room_id: String) -> void:
	if not ROOM_SCENES.has(room_id):
		return
	if active_room_node:
		active_room_node.queue_free()
	active_room_node = ROOM_SCENES[room_id].instantiate()
	room_root.add_child(active_room_node)
	if active_room_node.has_signal("hotspot_selected"):
		active_room_node.connect("hotspot_selected", _on_room_hotspot_selected)
	active_room_data = room_catalog[room_id]
	GameState.current_room_id = room_id

	room_title_label.text = String(active_room_data.get("title", room_id.capitalize()))
	log_label.text = "Tap a hotspot to inspect clues or move to another room."
	_rebuild_hotspot_buttons()
	_refresh_notebook()
	_refresh_room_interactables()

func _rebuild_hotspot_buttons() -> void:
	for child in hotspot_list.get_children():
		child.queue_free()

	for spot in active_room_data.get("hotspots", []):
		var button := Button.new()
		var kind := String(spot.get("kind", ""))
		var label := String(spot.get("label", "Hotspot"))
		if kind == "move":
			button.text = "↗ " + label
		else:
			var prefix := "◈ "
			var spot_id := String(spot.get("id", ""))
			if GameState.has_discovered(spot_id):
				prefix = "✓ "
			button.text = prefix + label
			if GameState.is_locked(spot):
				button.text += " (locked)"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_hotspot_pressed.bind(spot))
		hotspot_list.add_child(button)
	_refresh_room_interactables()

func _on_hotspot_pressed(spot: Dictionary) -> void:
	var kind := String(spot.get("kind", ""))
	if kind == "move":
		_switch_room(String(spot.get("target", "living")))
		return

	if GameState.is_locked(spot):
		log_label.text = "Locked: " + String(spot.get("lock_hint", "This clue is currently locked."))
		return

	var first_time := GameState.discover(spot)
	log_label.text = String(spot.get("message", "Clue reviewed."))
	if first_time:
		_rebuild_hotspot_buttons()
		_refresh_notebook()
	_refresh_room_interactables()

func _on_room_hotspot_selected(spot: Dictionary) -> void:
	_on_hotspot_pressed(spot)

func _refresh_notebook() -> void:
	notebook_count_label.text = "Notebook: %d/%d clues discovered" % [GameState.discovered_count(), GameState.total_discoveries]

	keyword_list.clear()
	if GameState.keywords.is_empty():
		keyword_list.add_item("No keywords discovered yet.")
	else:
		for keyword in GameState.keywords:
			keyword_list.add_item(keyword)

	discovered_list.clear()
	if GameState.discovered.is_empty():
		discovered_list.add_item("No clues discovered yet.")
	else:
		for clue_id in GameState.discovered.keys():
			discovered_list.add_item(clue_id)

func _refresh_room_interactables() -> void:
	if not active_room_node or not active_room_node.has_method("set_hotspot_states"):
		return

	var states_by_id: Dictionary = {}
	for spot in active_room_data.get("hotspots", []):
		if String(spot.get("kind", "")) != "inspect":
			continue
		var spot_id := String(spot.get("id", ""))
		if spot_id.is_empty():
			continue
		states_by_id[spot_id] = {
			"seen": GameState.has_discovered(spot_id),
			"locked": GameState.is_locked(spot)
		}

	active_room_node.call("set_hotspot_states", states_by_id)
