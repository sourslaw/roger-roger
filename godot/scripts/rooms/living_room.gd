extends Control

signal hotspot_selected(spot: Dictionary)

const ROOM_DATA := {
	"id": "living",
	"title": "Living Room // Seasoned Hearth",
	"hotspots": [
		{
			"kind": "move",
			"label": "Go Poolside",
			"target": "pool"
		},
		{
			"kind": "inspect",
			"id": "champagne",
			"label": "Inspect Champagne Flute",
			"keyword": "Broadhead Semiconductor",
			"message": "The flute carries a lipstick mark and initials: B.S."
		},
		{
			"kind": "inspect",
			"id": "cards",
			"label": "Examine Business Cards",
			"keyword": "Woodside Contact Chain",
			"requires": ["champagne"],
			"lock_hint": "Inspect the champagne flute first.",
			"message": "Three cards map to one shell company with different aliases."
		},
		{
			"kind": "inspect",
			"id": "dog",
			"label": "Pet the Sleeping Dog",
			"message": "Man's best friend. Smells like a newborn baby . . ."
		}
	]
}

@onready var pool_door_button: Button = $RoomArt/PoolDoorButton
@onready var champagne_button: Button = $RoomArt/ChampagneButton
@onready var cards_button: Button = $RoomArt/CardsButton
@onready var hint_label: Label = $RoomArt/HintLabel
@onready var fire_core: ColorRect = $RoomArt/FireplaceGlow/FireCore
@onready var fire_ember: ColorRect = $RoomArt/FireplaceGlow/FireEmber
@onready var fire_light_spill: ColorRect = $RoomArt/FireLightSpill
@onready var lamp: ColorRect = $RoomArt/Lamp
@onready var window_glow: ColorRect = $RoomArt/WindowGlow
@onready var moon_beam: ColorRect = $RoomArt/MoonBeam
@onready var dust_overlay: ColorRect = $RoomArt/DustOverlay
@onready var sofa_top_highlight: ColorRect = $RoomArt/SofaTopHighlight
@onready var coffee_table_highlight: ColorRect = $RoomArt/CoffeeTableHighlight

var inspect_spots: Dictionary = {}
var move_spot: Dictionary = {}
var fire_time := 0.0

func _ready() -> void:
	for spot in ROOM_DATA["hotspots"]:
		if String(spot.get("kind", "")) == "inspect":
			inspect_spots[String(spot.get("id", ""))] = spot
		elif String(spot.get("kind", "")) == "move":
			move_spot = spot

	pool_door_button.pressed.connect(_on_pool_door_pressed)
	champagne_button.pressed.connect(_on_champagne_pressed)
	cards_button.pressed.connect(_on_cards_pressed)
	_bind_hint(pool_door_button, "Move to poolside patio")
	_bind_hint(champagne_button, "Inspect the champagne flute")
	_bind_hint(cards_button, "Inspect the business cards")
	_style_hotspot_buttons()
	hint_label.text = "Hover an item, then click to interact."
	set_process(true)

func get_room_data() -> Dictionary:
	return ROOM_DATA.duplicate(true)

func set_hotspot_states(states_by_id: Dictionary) -> void:
	_apply_inspect_state(champagne_button, "champagne", states_by_id)
	_apply_inspect_state(cards_button, "cards", states_by_id)

func _apply_inspect_state(button: Button, spot_id: String, states_by_id: Dictionary) -> void:
	var state: Dictionary = states_by_id.get(spot_id, {})
	var spot: Dictionary = inspect_spots.get(spot_id, {})
	var base_label := String(spot.get("label", spot_id))
	var seen := bool(state.get("seen", false))
	var locked := bool(state.get("locked", false))
	button.text = ("%s %s%s") % [
		"✓" if seen else "◈",
		_short_label(base_label),
		" (locked)" if locked else ""
	]
	button.modulate = Color(0.95, 0.82, 0.68, 1.0) if seen else Color(1.0, 1.0, 1.0, 1.0)

func _on_pool_door_pressed() -> void:
	hotspot_selected.emit(move_spot.duplicate(true))

func _on_champagne_pressed() -> void:
	_emit_inspect("champagne")

func _on_cards_pressed() -> void:
	_emit_inspect("cards")

func _emit_inspect(spot_id: String) -> void:
	var spot: Dictionary = inspect_spots.get(spot_id, {})
	if spot.is_empty():
		return
	hotspot_selected.emit(spot.duplicate(true))

func _bind_hint(button: Button, text: String) -> void:
	button.mouse_entered.connect(func() -> void:
		hint_label.text = text
	)
	button.mouse_exited.connect(func() -> void:
		hint_label.text = "Hover an item, then click to interact."
	)

func _style_hotspot_buttons() -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.03, 0.03, 0.03, 0.3)
	base_style.border_color = Color(0.95, 0.76, 0.43, 0.38)
	base_style.border_width_left = 1
	base_style.border_width_top = 1
	base_style.border_width_right = 1
	base_style.border_width_bottom = 1
	base_style.corner_radius_top_left = 4
	base_style.corner_radius_top_right = 4
	base_style.corner_radius_bottom_right = 4
	base_style.corner_radius_bottom_left = 4
	var hover_style := base_style.duplicate()
	hover_style.bg_color = Color(0.09, 0.07, 0.04, 0.48)
	hover_style.border_color = Color(1.0, 0.86, 0.58, 0.7)

	for button in [pool_door_button, champagne_button, cards_button]:
		button.flat = true
		button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.84))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.62))
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", base_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)

func _short_label(label: String) -> String:
	if label.contains("Champagne"):
		return "Champagne flute"
	if label.contains("Business Cards"):
		return "Business cards"
	return label

func _process(delta: float) -> void:
	fire_time += delta
	var pulse := 0.8 + sin(fire_time * 3.8) * 0.2
	fire_core.modulate = Color(1.0, 0.74, 0.28, 0.7 + pulse * 0.16)
	fire_ember.modulate = Color(1.0, 0.43, 0.12, 0.5 + pulse * 0.2)
	fire_light_spill.modulate = Color(1.0, 0.44, 0.18, 0.08 + pulse * 0.04)
	lamp.modulate = Color(0.96, 0.88, 0.62, 0.58 + sin(fire_time * 2.1) * 0.08)
	window_glow.modulate = Color(0.54, 0.64, 0.74, 0.12 + sin(fire_time * 0.9) * 0.025)
	moon_beam.modulate = Color(0.52, 0.62, 0.72, 0.06 + sin(fire_time * 0.7) * 0.02)
	dust_overlay.modulate = Color(0.86, 0.76, 0.59, 0.012 + sin(fire_time * 0.4) * 0.006)
	sofa_top_highlight.modulate = Color(0.58, 0.39, 0.26, 0.09 + pulse * 0.04)
	coffee_table_highlight.modulate = Color(0.72, 0.52, 0.31, 0.12 + pulse * 0.05)
