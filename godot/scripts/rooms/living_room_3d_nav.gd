extends Node3D

@export var move_speed := 4.5
@export var sprint_multiplier := 1.7
@export var mouse_sensitivity := 0.0022
@export var touch_look_sensitivity := 0.003
@export var touch_move_radius := 120.0
@export var force_touch_controls := false
@export var min_pitch_deg := -75.0
@export var max_pitch_deg := 75.0
@export var interact_distance := 12.0

const ROOM_SCRIPTS := [
	preload("res://scripts/rooms/living_room.gd"),
	preload("res://scripts/rooms/pool_room.gd"),
	preload("res://scripts/rooms/study_room.gd")
]
const MARKER_STATE_AVAILABLE := "available"
const MARKER_STATE_LOCKED := "locked"
const MARKER_STATE_DISCOVERED := "discovered"

const MARKER_STATE_COLORS := {
	MARKER_STATE_AVAILABLE: Color(0.48, 0.82, 1.0, 0.68),
	MARKER_STATE_LOCKED: Color(1.0, 0.78, 0.34, 0.7),
	MARKER_STATE_DISCOVERED: Color(0.46, 1.0, 0.58, 0.72)
}

const MARKER_STATE_EMISSION := {
	MARKER_STATE_AVAILABLE: 2.3,
	MARKER_STATE_LOCKED: 2.0,
	MARKER_STATE_DISCOVERED: 2.45
}

@onready var camera: Camera3D = $Camera3D
@onready var controls_label: Label = $HUD/ControlsPanel/ControlsLabel
@onready var notebook_label: Label = $HUD/NotebookPanel/NotebookLabel
@onready var focus_label: Label = $HUD/FocusPanel/FocusLabel
@onready var clue_log_label: Label = $HUD/ClueLogPanel/ClueLogLabel
@onready var touch_controls: Control = $HUD/TouchControls
@onready var touch_move_zone: Control = $HUD/TouchControls/MoveZone
@onready var touch_look_zone: Control = $HUD/TouchControls/LookZone
@onready var touch_interact_button: Button = $HUD/TouchControls/InteractButton
@onready var touch_sprint_button: Button = $HUD/TouchControls/SprintButton
@onready var fire_light: OmniLight3D = $FireLight
@onready var firebox: MeshInstance3D = $Firebox
@onready var moon_floor_patch: MeshInstance3D = $MoonFloorPatch
@onready var moon_floor_core_patch: MeshInstance3D = $MoonFloorCorePatch
@onready var champagne_marker: MeshInstance3D = $Hotspots/ChampagneFloatingMarker
@onready var cards_marker: MeshInstance3D = $Hotspots/CardsFloatingMarker
@onready var pool_door_marker: MeshInstance3D = $Hotspots/PoolDoorFloatingMarker
@onready var dog_marker: MeshInstance3D = $Hotspots/DogFloatingMarker

var _pitch := 0.0
var _yaw := 0.0
var _base_camera_height := 0.0
var _pressed_keys: Dictionary = {}
var _flicker_time := 0.0
var _base_fire_light_energy := 0.0
var _base_fire_emission := 0.0
var _fire_material: StandardMaterial3D = null
var _moon_patch_material: StandardMaterial3D = null
var _moon_core_material: StandardMaterial3D = null
var _base_moon_patch_emission := 0.0
var _base_moon_core_emission := 0.0
var _room_catalog: Dictionary = {}
var _active_room_data: Dictionary = {}
var _spot_by_area_name := {
	"ChampagneInteract": "champagne",
	"CardsInteract": "cards",
	"PoolDoorInteract": "pool_door",
	"DogInteract": "dog"
}
var _spot_areas: Dictionary = {}
var _target_node_by_spot_id := {
	"champagne": "Hotspots/ChampagneTargetGlow",
	"cards": "Hotspots/CardsTargetGlow",
	"pool_door": "Hotspots/PoolDoorTargetGlow",
	"dog": "Hotspots/DogTargetGlow"
}
var _target_nodes: Dictionary = {}
var _active_focus_spot_id := ""
var _marker_nodes: Dictionary = {}
var _marker_base_positions: Dictionary = {}
var _marker_materials: Dictionary = {}
var _marker_state_cache: Dictionary = {}
var _marker_time := 0.0
var _focus_message_hold_remaining := 0.0
var _touch_enabled := false
var _touch_move_input := Vector2.ZERO
var _touch_move_origin := Vector2.ZERO
var _touch_move_finger := -1
var _touch_look_finger := -1
var _touch_sprint_pressed := false

func _ready() -> void:
	GameState.reset()
	_build_room_catalog()
	GameState.configure_total(_count_total_discoveries())
	GameState.current_room_id = "living"
	_active_room_data = _room_catalog.get("living", {})
	_cache_spot_areas()
	_cache_target_nodes()
	_cache_floating_markers()

	_pitch = camera.rotation.x
	_yaw = camera.rotation.y
	_base_camera_height = camera.global_position.y
	_base_fire_light_energy = fire_light.light_energy
	_fire_material = firebox.get_active_material(0) as StandardMaterial3D
	if is_instance_valid(_fire_material):
		_fire_material = _fire_material.duplicate() as StandardMaterial3D
		firebox.set_surface_override_material(0, _fire_material)
		_base_fire_emission = _fire_material.emission_energy_multiplier
	_moon_patch_material = moon_floor_patch.get_active_material(0) as StandardMaterial3D
	if is_instance_valid(_moon_patch_material):
		_moon_patch_material = _moon_patch_material.duplicate() as StandardMaterial3D
		moon_floor_patch.set_surface_override_material(0, _moon_patch_material)
		_base_moon_patch_emission = _moon_patch_material.emission_energy_multiplier
	_moon_core_material = moon_floor_core_patch.get_active_material(0) as StandardMaterial3D
	if is_instance_valid(_moon_core_material):
		_moon_core_material = _moon_core_material.duplicate() as StandardMaterial3D
		moon_floor_core_patch.set_surface_override_material(0, _moon_core_material)
		_base_moon_core_emission = _moon_core_material.emission_energy_multiplier

	set_process(true)
	set_process_input(true)
	_setup_touch_controls()
	_refresh_notebook_ui()
	_set_focus_text("Look at an object and click or press E to interact.")
	_set_focus_target("")

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and not _touch_enabled:
		_touch_enabled = true
		_activate_touch_controls()

	if _touch_enabled:
		if event is InputEventScreenTouch:
			_handle_touch_press(event)
			return
		if event is InputEventScreenDrag:
			_handle_touch_drag(event)
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
		_try_interact()

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera.rotation = Vector3(_pitch, _yaw, 0.0)

	if event is InputEventKey and not event.echo:
		if event.keycode != KEY_NONE:
			_pressed_keys[event.keycode] = event.pressed
		if event.physical_keycode != KEY_NONE:
			_pressed_keys[event.physical_keycode] = event.pressed
		if event.pressed and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			_try_interact()

func _process(delta: float) -> void:
	_update_fireplace_flicker(delta)
	_update_moonlight_shimmer()
	_update_floating_markers(delta)
	if _focus_message_hold_remaining > 0.0:
		_focus_message_hold_remaining = max(_focus_message_hold_remaining - delta, 0.0)

	var move_input := Vector2.ZERO
	if _is_any_key_pressed([KEY_A, KEY_LEFT]):
		move_input.x -= 1.0
	if _is_any_key_pressed([KEY_D, KEY_RIGHT]):
		move_input.x += 1.0
	if _is_any_key_pressed([KEY_W, KEY_UP]):
		move_input.y -= 1.0
	if _is_any_key_pressed([KEY_S, KEY_DOWN]):
		move_input.y += 1.0
	move_input += _touch_move_input
	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	_update_controls_label(move_input)
	_update_focus_hover()

	if move_input == Vector2.ZERO:
		return

	move_input = move_input.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var sprinting := _is_any_key_pressed([KEY_SHIFT]) or _touch_sprint_pressed
	var speed := move_speed * (sprint_multiplier if sprinting else 1.0)
	var forward_input := -move_input.y
	var velocity := (right * move_input.x + forward * forward_input) * speed
	camera.global_position += velocity * delta
	camera.global_position.y = _base_camera_height

func _build_room_catalog() -> void:
	_room_catalog.clear()
	for room_script in ROOM_SCRIPTS:
		var room_node: Node = room_script.new()
		if room_node.has_method("get_room_data"):
			var room_data: Dictionary = room_node.get_room_data()
			var room_id := String(room_data.get("id", ""))
			if not room_id.is_empty():
				_room_catalog[room_id] = room_data
		if room_node is Node:
			room_node.free()

func _cache_spot_areas() -> void:
	_spot_areas.clear()
	for area_name in _spot_by_area_name.keys():
		var area_node := get_node_or_null("Hotspots/%s" % area_name)
		if area_node is Area3D:
			_spot_areas[area_name] = area_node

func _cache_target_nodes() -> void:
	_target_nodes.clear()
	for spot_id in _target_node_by_spot_id.keys():
		var target_node := get_node_or_null(String(_target_node_by_spot_id[spot_id]))
		if target_node is Node3D:
			_target_nodes[spot_id] = target_node

func _cache_floating_markers() -> void:
	_marker_nodes = {
		"champagne": champagne_marker,
		"cards": cards_marker,
		"pool_door": pool_door_marker,
		"dog": dog_marker
	}
	_marker_base_positions.clear()
	_marker_materials.clear()
	_marker_state_cache.clear()
	for marker_id in _marker_nodes.keys():
		var marker_node: MeshInstance3D = _marker_nodes[marker_id]
		if is_instance_valid(marker_node):
			_marker_base_positions[marker_id] = marker_node.position
			var marker_material := marker_node.get_active_material(0) as StandardMaterial3D
			if is_instance_valid(marker_material):
				var marker_material_instance := marker_material.duplicate() as StandardMaterial3D
				marker_node.set_surface_override_material(0, marker_material_instance)
				_marker_materials[marker_id] = marker_material_instance

func _count_total_discoveries() -> int:
	var total := 0
	for room_data in _room_catalog.values():
		for spot in room_data.get("hotspots", []):
			if String(spot.get("kind", "")) == "inspect":
				total += 1
	return total

func _try_interact() -> void:
	var hit: Dictionary = _get_focused_spot()
	if hit.is_empty():
		_set_focus_text("No interactable in focus.", 1.6)
		return

	var spot: Dictionary = hit.get("spot", {})
	if spot.is_empty():
		return

	var kind := String(spot.get("kind", ""))
	if kind == "move":
		var target := String(spot.get("target", ""))
		_set_focus_text("Path to %s noted. 3D transition is next." % target.capitalize(), 2.6)
		return

	if GameState.is_locked(spot):
		_set_focus_text("Locked: " + String(spot.get("lock_hint", "This clue is currently locked.")), 2.8)
		return

	var first_time: bool = GameState.discover(spot)
	var message := String(spot.get("message", "Clue reviewed."))
	if not first_time:
		message += " (already discovered)"
	_set_focus_text(message, 4.2)
	_refresh_notebook_ui()

func _update_focus_hover() -> void:
	var hit: Dictionary = _get_focused_spot()
	if hit.is_empty():
		_set_focus_target("")
		return

	var spot: Dictionary = hit.get("spot", {})
	var spot_id := _spot_id_for_spot(spot)
	_set_focus_target(spot_id)
	if _focus_message_hold_remaining > 0.0:
		return
	var kind := String(spot.get("kind", ""))
	if kind == "move":
		_set_focus_text("↗ " + String(spot.get("label", "Move")) + " (click/E)")
		return

	var label := String(spot.get("label", "Inspect"))
	if GameState.is_locked(spot):
		_set_focus_text("◈ %s (locked) — %s" % [label, String(spot.get("lock_hint", ""))])
	elif GameState.has_discovered(spot_id):
		_set_focus_text("✓ %s (already discovered) — click/E to review." % label)
	else:
		_set_focus_text("◈ %s — click/E to inspect." % label)

func _get_focused_spot() -> Dictionary:
	var origin := camera.global_transform.origin
	var direction := (-camera.global_transform.basis.z).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * interact_distance)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider: Object = result.get("collider")
		if collider is Area3D:
			var ray_spot_id := String(_spot_by_area_name.get(collider.name, ""))
			if not ray_spot_id.is_empty():
				var ray_spot := _get_spot_by_id(ray_spot_id)
				if not ray_spot.is_empty():
					return {"spot": ray_spot}

	var best_area_name := ""
	var best_score := -1.0
	for area_name in _spot_areas.keys():
		var area: Area3D = _spot_areas[area_name]
		if not is_instance_valid(area):
			continue
		var candidate_spot_id := String(_spot_by_area_name.get(area_name, ""))
		var candidate_spot := _get_spot_by_id(candidate_spot_id)
		if candidate_spot.is_empty():
			continue
		var to_target := area.global_transform.origin - origin
		var distance := to_target.length()
		if distance > interact_distance or distance <= 0.001:
			continue
		var alignment := direction.dot(to_target.normalized())
		if alignment < 0.88:
			continue
		var score := alignment - distance * 0.02
		if String(candidate_spot.get("kind", "")) == "inspect" and GameState.is_locked(candidate_spot):
			score -= 0.25
		if score > best_score:
			best_score = score
			best_area_name = String(area_name)

	if best_area_name.is_empty():
		return {}

	var spot_id := String(_spot_by_area_name.get(best_area_name, ""))
	var spot := _get_spot_by_id(spot_id)
	if spot.is_empty():
		return {}
	return {"spot": spot}

func _spot_id_for_spot(spot: Dictionary) -> String:
	var kind := String(spot.get("kind", ""))
	if kind == "move":
		return "pool_door"
	var spot_id := String(spot.get("id", ""))
	return spot_id

func _set_focus_target(spot_id: String) -> void:
	if _active_focus_spot_id == spot_id:
		return
	_active_focus_spot_id = spot_id
	for key in _target_nodes.keys():
		var target_node: Node3D = _target_nodes[key]
		if not is_instance_valid(target_node):
			continue
		target_node.visible = (String(key) == spot_id)

func _get_spot_by_id(spot_id: String) -> Dictionary:
	for spot in _active_room_data.get("hotspots", []):
		if String(spot.get("id", "")) == spot_id:
			return spot
	if spot_id == "pool_door":
		for spot in _active_room_data.get("hotspots", []):
			if String(spot.get("kind", "")) == "move":
				return spot
	return {}

func _update_fireplace_flicker(delta: float) -> void:
	_flicker_time += delta
	var pulse := (
		sin(_flicker_time * 10.3) * 0.5 +
		sin(_flicker_time * 17.7 + 1.4) * 0.3 +
		sin(_flicker_time * 29.0 + 0.8) * 0.2
	)
	var normalized: float = clamp(0.5 + pulse * 0.45, 0.0, 1.0)
	fire_light.light_energy = _base_fire_light_energy * (0.75 + normalized * 0.55)

	if is_instance_valid(_fire_material):
		_fire_material.emission_energy_multiplier = _base_fire_emission * (0.78 + normalized * 0.5)

func _update_moonlight_shimmer() -> void:
	if is_instance_valid(_moon_patch_material):
		var patch_pulse := sin(_flicker_time * 0.62) * 0.5 + sin(_flicker_time * 1.07 + 0.8) * 0.5
		var patch_norm: float = clamp(0.5 + patch_pulse * 0.2, 0.0, 1.0)
		_moon_patch_material.emission_energy_multiplier = _base_moon_patch_emission * (0.88 + patch_norm * 0.28)
	if is_instance_valid(_moon_core_material):
		var core_pulse := sin(_flicker_time * 0.74 + 1.3) * 0.6 + sin(_flicker_time * 1.42) * 0.4
		var core_norm: float = clamp(0.5 + core_pulse * 0.24, 0.0, 1.0)
		_moon_core_material.emission_energy_multiplier = _base_moon_core_emission * (0.86 + core_norm * 0.34)

func _update_floating_markers(delta: float) -> void:
	_marker_time += delta
	for marker_id in _marker_nodes.keys():
		var marker_node: MeshInstance3D = _marker_nodes[marker_id]
		if not is_instance_valid(marker_node):
			continue
		var base_pos: Vector3 = _marker_base_positions.get(marker_id, marker_node.position)
		var phase := 0.0
		if marker_id == "cards":
			phase = 1.7
		elif marker_id == "pool_door":
			phase = 3.1
		elif marker_id == "dog":
			phase = 4.6
		var bob := sin(_marker_time * 2.8 + phase) * 0.07
		marker_node.position = Vector3(base_pos.x, base_pos.y + bob, base_pos.z)
		var pulse := 1.0 + sin(_marker_time * 3.6 + phase) * 0.14
		marker_node.scale = Vector3.ONE * pulse
	_update_marker_visual_states()

func _update_marker_visual_states() -> void:
	for marker_id in _marker_materials.keys():
		var marker_material: StandardMaterial3D = _marker_materials[marker_id]
		if not is_instance_valid(marker_material):
			continue
		var state := _marker_state_for_id(String(marker_id))
		if String(_marker_state_cache.get(marker_id, "")) == state:
			continue
		_marker_state_cache[marker_id] = state
		var tint: Color = MARKER_STATE_COLORS.get(state, MARKER_STATE_COLORS[MARKER_STATE_AVAILABLE])
		marker_material.albedo_color = tint
		marker_material.emission = Color(tint.r, tint.g, tint.b, 1.0)
		marker_material.emission_energy_multiplier = float(MARKER_STATE_EMISSION.get(state, MARKER_STATE_EMISSION[MARKER_STATE_AVAILABLE]))

func _marker_state_for_id(marker_id: String) -> String:
	var spot: Dictionary = _get_spot_by_id(marker_id)
	if spot.is_empty():
		return MARKER_STATE_AVAILABLE
	var kind := String(spot.get("kind", ""))
	if kind == "inspect":
		if GameState.has_discovered(marker_id):
			return MARKER_STATE_DISCOVERED
		if GameState.is_locked(spot):
			return MARKER_STATE_LOCKED
	return MARKER_STATE_AVAILABLE

func _update_controls_label(move_input: Vector2) -> void:
	if not is_instance_valid(controls_label):
		return
	var active_inputs: Array[String] = []
	if _is_any_key_pressed([KEY_W, KEY_UP]):
		active_inputs.append("W/Up")
	if _is_any_key_pressed([KEY_S, KEY_DOWN]):
		active_inputs.append("S/Down")
	if _is_any_key_pressed([KEY_A, KEY_LEFT]):
		active_inputs.append("A/Left")
	if _is_any_key_pressed([KEY_D, KEY_RIGHT]):
		active_inputs.append("D/Right")
	if _is_any_key_pressed([KEY_SHIFT]):
		active_inputs.append("Shift")
	if _touch_sprint_pressed:
		active_inputs.append("TouchSprint")
	if active_inputs.is_empty():
		active_inputs.append("None")
	var controls_prefix := "Click to capture mouse | WASD/Arrows move | Shift sprint | Esc release"
	if _touch_enabled:
		controls_prefix = "Touch: left zone move | right zone look | INTERACT | SPRINT"
	controls_label.text = "%s\nInputs: %s | Move Vec: (%.1f, %.1f) | Pos: (%.2f, %.2f, %.2f)" % [
		controls_prefix,
		", ".join(active_inputs),
		move_input.x,
		move_input.y,
		camera.global_position.x,
		camera.global_position.y,
		camera.global_position.z
	]

func _refresh_notebook_ui() -> void:
	if not is_instance_valid(notebook_label):
		return

	var keyword_text := "None"
	if not GameState.keywords.is_empty():
		keyword_text = ", ".join(GameState.keywords)

	var clue_ids: Array[String] = []
	for clue_id in GameState.discovered.keys():
		clue_ids.append(String(clue_id))
	clue_ids.sort()
	var clue_text := "None"
	if not clue_ids.is_empty():
		clue_text = ", ".join(clue_ids)

	notebook_label.text = "Notebook: %d/%d clues\nKeywords: %s\nDiscovered: %s" % [
		GameState.discovered_count(),
		GameState.total_discoveries,
		keyword_text,
		clue_text
	]
	_refresh_clue_log_ui()

func _refresh_clue_log_ui() -> void:
	if not is_instance_valid(clue_log_label):
		return

	var recent_count: int = min(3, GameState.notes.size())
	if recent_count <= 0:
		clue_log_label.text = "Latest clues:\n- No clue text yet. Interact with an object."
		return

	var start_index: int = GameState.notes.size() - recent_count
	var entries: Array[String] = []
	for i in range(start_index, GameState.notes.size()):
		entries.append("- " + String(GameState.notes[i]))
	clue_log_label.text = "Latest clues:\n%s" % "\n".join(entries)

func _set_focus_text(message: String, hold_seconds: float = 0.0) -> void:
	if hold_seconds > 0.0:
		_focus_message_hold_remaining = hold_seconds
	if is_instance_valid(focus_label):
		focus_label.text = message

func _is_any_key_pressed(keycodes: Array[Key]) -> bool:
	for code in keycodes:
		if bool(_pressed_keys.get(code, false)):
			return true
	return false

func _setup_touch_controls() -> void:
	_touch_enabled = force_touch_controls or DisplayServer.is_touchscreen_available()
	_activate_touch_controls()

func _activate_touch_controls() -> void:
	if is_instance_valid(touch_controls):
		touch_controls.visible = _touch_enabled
	if not _touch_enabled:
		return
	if is_instance_valid(touch_interact_button) and not touch_interact_button.pressed.is_connected(_on_touch_interact_pressed):
		touch_interact_button.pressed.connect(_on_touch_interact_pressed)
	if is_instance_valid(touch_sprint_button):
		if not touch_sprint_button.button_down.is_connected(_on_touch_sprint_down):
			touch_sprint_button.button_down.connect(_on_touch_sprint_down)
		if not touch_sprint_button.button_up.is_connected(_on_touch_sprint_up):
			touch_sprint_button.button_up.connect(_on_touch_sprint_up)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _handle_touch_press(event: InputEventScreenTouch) -> void:
	var touch_pos: Vector2 = event.position
	if event.pressed:
		if _touch_move_finger == -1 and _is_touch_in_zone(touch_move_zone, touch_pos):
			_touch_move_finger = event.index
			_touch_move_origin = touch_pos
			_touch_move_input = Vector2.ZERO
			return
		if _touch_look_finger == -1 and _is_touch_in_zone(touch_look_zone, touch_pos):
			_touch_look_finger = event.index
			return
		return

	if event.index == _touch_move_finger:
		_touch_move_finger = -1
		_touch_move_input = Vector2.ZERO
	if event.index == _touch_look_finger:
		_touch_look_finger = -1

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_move_finger:
		var delta: Vector2 = event.position - _touch_move_origin
		if delta.length() > touch_move_radius:
			delta = delta.normalized() * touch_move_radius
		var normalized: Vector2 = delta / max(touch_move_radius, 1.0)
		_touch_move_input = Vector2(normalized.x, normalized.y)
		return

	if event.index == _touch_look_finger:
		_yaw -= event.relative.x * touch_look_sensitivity
		_pitch = clamp(_pitch - event.relative.y * touch_look_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		camera.rotation = Vector3(_pitch, _yaw, 0.0)

func _is_touch_in_zone(zone: Control, position: Vector2) -> bool:
	if not is_instance_valid(zone):
		return false
	return zone.get_global_rect().has_point(position)

func _on_touch_interact_pressed() -> void:
	_try_interact()

func _on_touch_sprint_down() -> void:
	_touch_sprint_pressed = true

func _on_touch_sprint_up() -> void:
	_touch_sprint_pressed = false
