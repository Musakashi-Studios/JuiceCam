<p align="center">
  <img src="https://res.cloudinary.com/dg2cuyf0t/image/upload/v1792833377/juicecam/branding/juicecam-itch-cover.png" alt="JuiceCam cover art" />
</p>

# JuiceCam for Godot

### A camera with a feel for the game.

JuiceCam is a flexible 2D camera system that responds to the action. Follow one target or frame a group, keep the view inside rooms and level limits, guide it along paths, or pull it with magnets and zoom zones. Named cinematic sequences can take over for scripted moments, while add-ons bring effects like screen shake, mouse follow, grid snap, and speed-based zoom. Tune each camera to your game, and build custom add-ons when you need more.


<p align="center">
  <a href="#quick-start"><strong>Quick start</strong></a>
  &nbsp;·&nbsp;
  <a href="addons/juicecam/documentation.md"><strong>Full guide</strong></a>
  &nbsp;·&nbsp;
  <a href="https://musakashi.itch.io/juicecam"><strong>Play online</strong></a>
  &nbsp;·&nbsp;
  <a href="SUPPORT.md"><strong>Help &amp; bug reports</strong></a>
</p>

## Quick start

1. Install JuiceCam by copying `addons/juicecam` into your project's `addons` folder, or open Godot's **AssetLib** tab, search for **JuiceCam**, and download it.
2. In Godot, open **Project → Project Settings → Plugins** and enable **JuiceCam**.
3. Add a **JuiceCam2D** node to your scene.
4. In the camera's **Targets** section, add the `Node2D` the camera should follow.

JuiceCam creates and manages its own `Camera2D` child and uses the nearest parent viewport. You can also add or change targets in code:

```gdscript
@onready var camera: JuiceCam2D = $JuiceCam2D

func _ready() -> void:
	camera.add_target($Player)
	# Target entries are live data objects.
	camera.targets[0].weight = 2.0
```

## What it does

- Tracks one or several targets, with per-target weight, radius, offset, and lookahead.
- Smooths camera movement, rotation, and zoom with selectable damping behavior.
- Frames groups of targets automatically and keeps the visible view inside camera limits.
- Uses dead zones, rooms, paths, magnets, zoom areas, and cinematic points to shape movement through a level.
- Adds optional effects such as screen shake, mouse follow, grid snap, and velocity zoom.
- Gives every camera its own targets and add-on state, including in split-screen viewports.


## Play the demo

You can [launch the demo in your browser](https://musakashi.itch.io/juicecam), or open this repository in Godot and run the main scene. Move with **WASD** and jump with **Space**. The guided demo walks through JuiceCam targets, rooms, magnets, zoom areas, paths, add-ons, and cinematics.

## Full documentation

The complete Markdown guide is included in `addons/juicecam/documentation.md`, so it stays with the add-on when you download or copy it into your project. You can [read it on GitHub](addons/juicecam/documentation.md) or open the file locally. To create custom camera behavior, see [how to create your own add-ons](docs/creating-addons.md).
## Help and bug reports

For plugin help, bug reports, or feature requests, [open a GitHub issue](https://github.com/Musakashi-Studios/JuiceCam/issues) or email [musakashi.dev@outlook.com](mailto:musakashi.dev@outlook.com). See [SUPPORT.md](SUPPORT.md) for details to include when reporting a problem.

**Donations:** The **Support this tool** button on the [JuiceCam itch.io demo page](https://musakashi.itch.io/juicecam) is for donations only. For plugin help, use GitHub Issues or email instead.

## Project status

JuiceCam's 2D plugin is in active development. The demo project targets Godot 4.7; [play it online](https://musakashi.itch.io/juicecam). The repository also leaves room for a future 3D camera that can share the core camera math.
