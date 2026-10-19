# Godot 4 Skeleton (Myst-style Flow)

This folder contains a minimal Godot 4 skeleton that mirrors the current prototype gameplay loop:

- Room switching (`living` → `pool` → `study` → `living`)
- Clickable interactables
- Lock dependencies between clues
- Notebook tracking for discovered clues and keywords
- A visual living room scene with in-room clickable clue targets, ambient lighting flicker, subtle camera parallax, and material/detail layers (panel lines, plank lines, seams, highlights)
- added cozy wall decor details (trim, shelves, framed accents) and a resting dog prop for scene warmth
- added an inspectable dog clue in the moonlit window area
- added an opposite-wall doorway flanked by full-height bookshelves
- added dedicated overhead bookshelf lights to improve readability of book detail

## Open and run

1. Open Godot 4.
2. **Import** this project using [project.godot](./project.godot).
3. Run the main scene [LivingRoom3D.tscn](./scenes/rooms/LivingRoom3D.tscn).

Current default controls in the main scene:

- Click the viewport to capture mouse look
- `W/A/S/D` to move
- `Shift` to sprint
- Look at a hotspot and click or press `E` to interact
- `Esc` to release cursor
- Floating marker orbs show where interactables are located

The 3D HUD now includes:

- a live interaction hint panel
- notebook progress (`discovered/total`, keywords, and discovered clue ids) powered by `GameState`
- hotspot focus + interaction prompts tied to the center reticle
- clue/story response text that stays visible briefly after each interaction
- a latest clues mini-log that shows the most recent story discoveries
- moonlight beam plus a subtle floor light pool with gentle shimmer

## VS Code + Godot workflow (configured)

This repo now includes VS Code workspace files for Godot:

- [tasks.json](../.vscode/tasks.json): run/open Godot from VS Code tasks
- [launch.json](../.vscode/launch.json): `F5` run profile + editor-only launch profile
- [settings.json](../.vscode/settings.json): Godot Tools defaults and GDScript association
- [extensions.json](../.vscode/extensions.json): recommends Godot Tools extension

One-time setup:

1. Install the **Godot Tools** extension in VS Code (recommended automatically in this workspace).
2. Open this folder in VS Code and run **Tasks: Run Task** → `Godot: Open editor`.
3. In Godot, set **Editor > Editor Settings > Text Editor > External**:
   - Enable **Use External Editor**
   - Exec Path: `/Applications/Visual Studio Code.app/Contents/MacOS/Code`
   - Exec Flags: `{project} --goto {file}:{line}:{col}`
4. Keep Godot open while editing scripts so LSP and debugging remain available in VS Code.
5. In **Run and Debug**, you can choose:
   - `Godot: Run project (F5)`
   - `Godot: Open editor only`

## Browser URL workflow (web export)

You can now run a web preview directly from VS Code:

1. Run **Tasks: Run Task** and choose `Godot: Export + Serve Web`.
2. The task opens your browser to `http://127.0.0.1:8060` (or your chosen port).
3. Keep the task running while you test; stop it from the terminal when done.

Note: `Cmd+Shift+B` now defaults to native run via `Godot: Run project`.

First-time setup in Godot (required once):

1. Open **Project > Export**.
2. Add a **Web** preset named `Web`.
3. Install export templates if Godot prompts for them.

If needed, you can also run these tasks separately:

- `Godot: Export Web build`
- `Godot: Serve Web build`

## Structure

- [project.godot](./project.godot): project config and `GameState` autoload
- [scripts/game_state.gd](./scripts/game_state.gd): global clue/keyword/lock state
- [scenes/Main.tscn](./scenes/Main.tscn) + [scripts/main.gd](./scripts/main.gd): room loading, in-room interaction wiring, notebook UI
- [scenes/rooms/](./scenes/rooms/) + [scripts/rooms/](./scripts/rooms/): per-room scene definitions and hotspot data
- [tools/blender/generate_german_shepherd_laying.py](./tools/blender/generate_german_shepherd_laying.py): Blender helper script to generate/export a lying shepherd `.glb`
- [assets/models/dog/GermanShepherdLying.glb](./assets/models/dog/GermanShepherdLying.glb): imported dog mesh used by the living room scene

## Next implementation step

Bring pool and study to the same in-room quality as living room:

- add room art composition for pool/study scenes
- place in-room clickable objects for their clues
- replace simple shape placeholders with texture-backed art assets
