# JuiceCam

JuiceCam is a 2D camera system for Godot 4.7. It follows one or more targets and supports group framing, camera limits, rooms, paths, magnets, zoom zones, cinematics, and optional camera add-ons.

## Install

Copy the `addons/juicecam` folder into your project's `addons` folder, then enable **JuiceCam** in **Project → Project Settings → Plugins**. The Asset Store package keeps this same `addons/juicecam` path at the ZIP root.

Add a `JuiceCam2D` node to a scene and assign one or more `Node2D` targets in its **Targets** section. The camera creates and manages its own `Camera2D` child and uses the nearest parent viewport.

## Documentation

See [documentation.md](documentation.md) for setup, camera features, runtime API, and custom add-ons.

- [Play the demo](https://musakashi.itch.io/juicecam)
- [Source code and issues](https://github.com/Musakashi-Studios/JuiceCam)
