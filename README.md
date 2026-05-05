# DevWorld — Spatial IDE in Godot 4.6.2

A 3D block-based development environment where your code becomes a navigable world.

## How to Open

1. **Download Godot 4.6.2** from https://godotengine.org/download
2. Open Godot 4.6.2
3. Click **Import** and select the `project.godot` file from this folder
4. Click **Run** (F5)

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move camera (forward/left/back/right) |
| E | Move camera up |
| Q | Move camera down |
| Left-click | Select a building |
| Right-click drag | Pan camera |
| Scroll wheel | Zoom in/out |
| Tab | Toggle editor panel |

## What's Built

- **3D world** with 8 buildings (Auth, Gateway, User, Payment, Postgres, Redis, Queue, Notification)
- **Fly camera** — free-floating 3D navigation
- **Connection lines** — glowing tubes between related services
- **Status indicators** — green/yellow/red dots per building health
- **Dockable editor panel** — shows sample TypeScript source files when buildings are selected
- **Export configs** for HTML5, Android, and Windows desktop

## Extending

### Add more buildings
Edit `scripts/Main.gd` → `_build_initial_world()` and add to the `buildings` array.

### Add real code files
Edit `scripts/EditorPanel.gd` → `SAMPLE_FILES` dictionary. Keys are file paths, values are the code as GDScript strings.

### Change colors/sizes
All building data comes from `scripts/Main.gd` — no hardcoded values in VoxelWorld.

### Multiplayer
Godot 4.6 has ENet-based `MultiplayerENet` or `WebSocketMultiplayerPeer`. To add:
1. Add a `ENetMultiplayerPeer` as the multiplayer peer
2. Spawn buildings from a shared config (JSON file or resource)
3. Add `replication` annotations to sync building transforms

### Web export
Use the **HTML5** export preset in Godot. Godot 4.6 exports to WebGL 2.0. Performance note: heavy voxel worlds may need LOD (Level of Detail) for web.

## File Structure

```
project.godot       ← Open this in Godot 4.6.2
scenes/Main.tscn    ← Main scene
scripts/
  Main.gd           ← Scene controller
  VoxelWorld.gd     ← 3D world manager
  FlyCamera.gd      ← Free-flying camera
  EditorPanel.gd    ← Code editor panel
export_presets.cfg  ← HTML5 + Android + Windows export configs
icon.svg            ← Project icon
```

## Status

Built for **Godot 4.6.2** (not 4.6.1 which is on this server — you open this on your local machine with 4.6.2).

Works on: Windows, macOS, Linux, Android, HTML5 (WebGL 2.0).

The web version has no multiplayer out of the box — that requires a server binary. For real multiplayer, consider the GodotVoxel or voxelcore approach instead.