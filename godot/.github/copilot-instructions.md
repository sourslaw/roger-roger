# Godot + Copilot coding instructions

- Target Godot 4.x and GDScript 2.0 syntax.
- Prefer explicit typing for variables, parameters, and return values.
  - Example: `var speed: float = 200.0`
  - Example: `func move(dir: Vector2) -> void:`
- Use `@onready` node references for stable scene bindings instead of ad-hoc `get_node()` lookups in `_ready()`.
- Prefer signal-based decoupling for gameplay events and UI interactions.
  - Example: `signal health_changed(new_health: int)`
- Do not suggest Godot 3 APIs or deprecated node types.
  - Use `CharacterBody2D` / `CharacterBody3D` instead of `KinematicBody2D` / `KinematicBody`.
- Use Godot 4 conditional expression syntax (`value_if_true if condition else value_if_false`), not `?:`.
- Keep solutions aligned with 2D-first gameplay unless a task explicitly asks for 3D.
