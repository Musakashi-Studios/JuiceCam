<!-- COVER ART PLACEHOLDER: Add the JuiceCam wordmark and a wide in-game camera shot. -->

# JuiceCam for Godot

## A camera with a feel for the game

**2D camera plugin · Godot 4.7 demo project ([play online](https://musakashi.itch.io/juicecam)) · Version 1.0**

<!-- COVER SCREENSHOT PLACEHOLDER: A polished gameplay frame that shows camera composition in action. Suggested file: docs/images/cover-gameplay.png -->

JuiceCam is a flexible 2D camera system that responds to the action. Follow one target or frame a group, keep the view inside rooms and level limits, guide it along paths, or pull it with magnets and zoom zones. Named cinematic sequences can take over for scripted moments, while add-ons bring effects like screen shake, mouse follow, grid snap, and speed-based zoom. Tune each camera to your game, and build custom add-ons when you need more.

This guide shows you how to install and set up JuiceCam, use its camera and level features, create add-ons, and control the camera from code.

> **Project status:** This release contains the 2D camera plugin. The project is organized so a future 3D camera can share core math, but there is no user-facing `JuiceCam3D` node in this version.

## Contents

1. [What JuiceCam does](#1-what-juicecam-does)
2. [Install and enable](#2-install-and-enable)
3. [Make your first camera](#3-make-your-first-camera)
4. [Targets](#4-targets)
5. [Camera Inspector](#5-camera-inspector)
6. [Influence nodes](#6-influence-nodes)
7. [Cinematic sequences](#7-cinematic-sequences)
8. [Add-ons](#8-add-ons)
9. [Editor tools and debug drawing](#9-editor-tools-and-debug-drawing)
10. [Viewports, split screen, and scene changes](#10-viewports-split-screen-and-scene-changes)
11. [Performance notes](#11-performance-notes)
12. [Runtime API reference](#12-runtime-api-reference)
13. [Troubleshooting](#13-troubleshooting)
14. [Node and signal reference](#14-node-and-signal-reference)

---

## 1. What JuiceCam does

Add a `JuiceCam2D` node to your scene and choose what it should follow. Then shape the shot with camera settings and level features:

- Follow one target or keep a group in view, with settings for how much each target matters.
- Smooth camera movement, rotation, and zoom separately.
- Let a target move around inside a dead zone before the camera follows.
- Keep the camera inside level limits or room walls, including rotated rooms.
- Shape the camera's movement with magnets, zoom areas, and paths in the scene.
- Guide the camera through named cinematic sequences.
- Add screen shake, mouse follow, grid snap, or speed-based zoom.
- Give each camera its own targets and add-ons, including in split-screen viewports.

JuiceCam creates and controls its own `Camera2D` child. Add a `JuiceCam2D` node to your scene and control it through the properties and methods in this guide.

<!-- SCREENSHOT PLACEHOLDER: Show a side-by-side gameplay sequence: group framing, room constraint, then cinematic shot. Suggested file: docs/images/juicecam-feature-strip.png -->

## 2. Install and enable

### Install from a copy of the repository

1. Copy the `addons/juicecam` directory into the `addons` directory of your Godot project.
2. Open **Project → Project Settings → Plugins**.
3. Enable **JuiceCam**.
4. Open the **Create Node** dialog and search for `JuiceCam2D`.

You can [play the demo in your browser](https://musakashi.itch.io/juicecam). To explore the included Godot project locally, open the repository's `project.godot` and run the main scene. Move with **WASD** and jump with **Space**.

### Enable the plugin in an existing project

Enable JuiceCam to add its node types and target controls to the editor. If you copy the files but skip this step, those tools will not appear.

<!-- SCREENSHOT PLACEHOLDER: Show the JuiceCam row enabled in Project Settings → Plugins and the Create Node search result. Suggested file: docs/images/install-enable-plugin.png -->

### Requirements

- Godot 4.7 to run the included demo project locally. You can also [play it in your browser](https://musakashi.itch.io/juicecam).
- A 2D scene using `Node2D` targets.

## 3. Make your first camera

1. Add a `JuiceCam2D` node to your level or gameplay scene.
2. Select it. In **Targets**, click **Add Target**.
3. Choose a `Node2D` from the scene tree picker.
4. Run the scene.

The target list stores assigned nodes only. Adding a target opens the picker; it does not create an empty slot. Remove a target by deleting its card. If the list is empty, the Inspector shows an empty-state prompt.

JuiceCam uses the viewport that contains the camera node. There is no viewport override property. Put each camera under the `SubViewport` it should control.

```gdscript
@onready var camera: JuiceCam2D = $JuiceCam2D

func _ready() -> void:
	camera.add_target($Player)
```

With one target, JuiceCam follows it using its offset and lookahead settings. **Auto Framing** only changes the zoom when framing a group, so use **Zoom** to set the view for a single target.

<!-- SCREENSHOT PLACEHOLDER: Show the camera node selected, the expanded Targets section, one assigned target card, and the empty state in a second inset if practical. Suggested file: docs/images/camera-targets-inspector.png -->

## 4. Targets

Each target has a `JuiceCamTargetData` entry. It stores the node and the settings JuiceCam uses to follow it. Target order matters: the first target with a positive weight controls camera rotation.

| Property | Default | Effect |
| --- | ---: | --- |
| `node` | Required | The assigned `Node2D`. The Inspector picker filters to 2D nodes. |
| `weight` | `1.0` | How strongly this target pulls the camera. A weight of zero removes it from tracking and speed calculations. |
| `radius` | `32` | Extra space around this target when framing a group. |
| `offset` | `(0, 0)` | Moves the point the camera follows away from the node's origin. The offset uses the target's axes, so it turns with the target. |
| `use_lookahead` | `true` | Lets the camera aim a little ahead of this moving target. |
| `lookahead_factor` | `1.0` | How far ahead to aim. Set to `0` to turn lookahead off for this target. |

### How multiple targets are followed

With several active targets, JuiceCam finds a center point between them. A target with a higher weight pulls the center closer to itself. The camera follows this point. JuiceCam applies each target's `offset` before lookahead. A target with zero or near-zero weight does not affect the center, camera rotation, or speed-based add-ons.

Set every target's weight to zero to stop the camera following them. You can also clear the target list. With no active targets, the camera stays where it is. A room or zoom area can still affect the view if the camera is inside it.

Auto Framing changes the zoom when at least two targets are assigned and at least one has a positive weight. It fits all assigned targets in the view, including targets with zero weight. A zero-weight target does not pull the camera's center, but it still affects the framing. Remove any target that should not appear in the frame. With only one assigned target, use **Zoom** to set the view.

### Lookahead

Lookahead estimates where a moving target is heading and shifts the camera's destination a little ahead. The estimate is smoothed to avoid sudden jumps. Because the estimate includes the target's offset, a rotating target can also move the camera's destination. Set `use_lookahead = false` or `lookahead_factor = 0` to turn it off for a target.

### Access targets in code

`targets` and `get_all_targets()` return a copy of the target list, in order. The `JuiceCamTargetData` objects inside it are live, so changing one of their properties changes how the camera follows that target:

```gdscript
var target_data: Array[JuiceCamTargetData] = camera.get_all_targets()
if not target_data.is_empty():
	target_data[0].weight = 2.0
	target_data[0].offset = Vector2(24.0, -8.0)

# The same live object is available as:
camera.targets[0].weight = 2.0
```

The list itself is a copy. Calling `camera.targets.append(...)` does not add a target to the camera. Use `add_target()` or a remove method to change the list. Every target in the camera's list has an assigned node; empty target cards are not supported.

## 5. Camera Inspector

The Inspector groups camera properties in this order: **Targets**, **Motion**, **Rotation**, **Zoom**, **Auto Framing**, **Limits**, **Dead Zone**, **Add-ons**, and **Debug**. Conditional settings appear only when relevant. For example, the spring frequency and damping fields are shown only for Spring Damp.

<!-- SCREENSHOT PLACEHOLDER: Show the complete JuiceCam Inspector with groups in order. Suggested file: docs/images/camera-inspector-groups.png -->

### Motion

| Property | Default | Description |
| --- | ---: | --- |
| `smooth_motion` | On | Smooths position movement. Turn it off to move directly to each destination. Rotation and zoom have their own settings. |
| `damping_type` | Smooth Damp | Selects the position smoothing model. |
| `smooth_time` | `0.2 s` | Smooth Damp arrival time. Smaller values react faster. |
| `spring_frequency` | `5 Hz` | Oscillation frequency for Spring Damp. |
| `spring_damping` | `1.0` | Spring damping ratio. `1` is critically damped, below `1` can bounce, and above `1` settles more slowly. |
| `decay_rate` | `8.0` | Response rate for Exponential Decay. |
| `max_speed` | Unlimited | Movement speed cap used by Smooth Damp. |

The three damping choices move the camera in different ways:

- **Smooth Damp** approaches the destination without spring-style overshoot.
- **Spring Damp** models a damped spring and can overshoot when its damping ratio is below `1`.
- **Exponential Decay** follows with a rate-based response that is independent of frame rate.

`smooth_time`, `spring_frequency`, `spring_damping`, and `decay_rate` only affect their corresponding damping type. Disabling `smooth_motion` bypasses position damping.

### Rotation

Rotation is off by default. Enable `allow_rotation` to rotate toward the first target with a positive weight. A camera follows that target's world rotation plus `rotation_offset_degrees`; it does not average the facing directions of a group.

| Property | Default | Description |
| --- | ---: | --- |
| `allow_rotation` | Off | Enables target-follow rotation. |
| `smooth_rotation` | On | Smooths rotation independently from position. |
| `smooth_rotation_time` | `0.2 s` | Rotation arrival time. The shortest angular path is used. |
| `rotation_offset_degrees` | `0°` | Extra angle added to the selected target's rotation. |

An active room can supply its own rotation when **Align Camera Rotation** is enabled. Cinematic points always provide a shot rotation, even when regular target-follow rotation is off.

### Zoom

`zoom` is a linked `Vector2` by default. The chain control keeps horizontal and vertical zoom equal. Break the link only if the game should stretch the image. Zoom values above `1` show less of the world; values below `1` show more.

| Property | Default | Description |
| --- | ---: | --- |
| `zoom` | `(1, 1)` | Base zoom when group auto framing is not active. |
| `smooth_zoom` | On | Smooths zoom independently from position and rotation. |
| `smooth_zoom_time` | `0.2 s` | Zoom arrival time. |

Zoom is clamped away from zero to keep the camera transform valid. An active zoom area or room may request a different effective zoom.

### Auto Framing

Auto Framing is enabled by default. It changes the zoom when at least two targets are assigned and at least one has a positive weight. With only one assigned target, change **Zoom** to set the view.

| Property | Default | Description |
| --- | ---: | --- |
| `auto_framing` | On | Fits a multi-target group into the viewport. |
| `framing_margin` | `0.8` | How much of the view the group may fill. At `0.8`, the group fits inside 80% of the view, leaving space around it. |
| `min_framing_zoom` | `0.2` | Lowest zoom allowed by the framing calculation. |
| `max_framing_zoom` | `1.0` | Highest zoom allowed by the framing calculation. |
| `weight_space_factor` | `1.0` | Adds extra space around targets whose weight is above `1.0`. |

JuiceCam uses each target's position and radius, the viewport size, and camera rotation to calculate the group zoom. Zoom smoothing can soften changes as players spread apart or come back together.

### Limits

Limits set a rectangle that the camera view must stay inside. JuiceCam accounts for the viewport size, zoom, and rotation when it moves the camera. If the view is wider or taller than the limit area, JuiceCam zooms in until it fits.

| Property | Default | Description |
| --- | ---: | --- |
| `limits_enabled` | Off | Enables the world bounds below. |
| `smooth_limits` | On | Clamps the requested destination before smoothing. A final hard clamp still protects the rendered pose. |
| `limit_left` | `-10,000,000` | Left world coordinate. |
| `limit_right` | `10,000,000` | Right world coordinate. |
| `limit_top` | `-10,000,000` | Top world coordinate. |
| `limit_bottom` | `10,000,000` | Bottom world coordinate. |

The rectangle must have positive width and height. Keep **Limits** disabled if the scene has no global camera boundary. Room boundaries are a separate, local way to constrain the camera.

### Dead Zone

Dead zones let one target move around inside a chosen area of the camera view before the camera follows. When the target crosses a dead-zone edge, the camera moves to bring it back inside.

| Property | Default | Description |
| --- | ---: | --- |
| `horizontal_deadzone_enabled` | Off | Enables horizontal dead-zone behavior. |
| `vertical_deadzone_enabled` | Off | Enables vertical dead-zone behavior. |
| `deadzone_left_margin` | `0.3` | Distance from the view center to the left edge of the dead zone, as a fraction of half the view width. |
| `deadzone_right_margin` | `0.3` | Distance from the view center to the right edge of the dead zone, as a fraction of half the view width. |
| `deadzone_top_margin` | `0.3` | Distance from the view center to the top edge of the dead zone, as a fraction of half the view height. |
| `deadzone_bottom_margin` | `0.3` | Distance from the view center to the bottom edge of the dead zone, as a fraction of half the view height. |

Dead zones work with smoothing. The dead zone decides when the camera should move; smoothing controls how quickly it moves. The zone turns with the camera and is meant for a single target. With a group, the camera follows the targets' weighted center instead.

### Add-ons and Debug

The **Add-ons** array holds optional effects. See [Add-ons](#8-add-ons) for the built-in effects and the scripting API.

The **Debug** group contains:

| Property | Default | Description |
| --- | ---: | --- |
| `editor_preview` | On | Updates the camera preview while editing. |
| `process_callback` | Idle | Runs the camera update from `_process`. Choose Physics to update from `_physics_process` for physics-driven targets. |
| `debug_draw_enabled` | Off | Draws runtime camera diagnostics and enables runtime influence diagnostics. |

## 6. Influence nodes

Rooms, magnets, and zoom areas affect the camera while its followed point is inside their region. Paths act as camera rails and compete by priority across their `World2D` while the tracking point is within each path's endpoint range on its unconstrained axis. These nodes work without `Area2D`, collision shapes, or physics layers.

Add them from **Create Node**:

- `JuiceCamRoom2D`
- `JuiceCamMagnet2D`
- `JuiceCamZoom2D`
- `JuiceCamPath2D`

Each influence has an **Influence** group with `enabled` and `priority`. For rooms and zoom areas, the highest-priority region containing the followed point takes effect. Overlapping magnets act one after another in priority order. For paths, the camera checks enabled paths in its `World2D` and uses the highest-priority path whose endpoint range contains the tracking point on the axis that path leaves free. If a higher-priority path is out of range, the next eligible path can take over. Equal-priority eligible paths use registry order. The selected path projects the destination after target modifiers, then room and global limits are applied.

Rooms, magnets, and zoom areas provide entry and exit signals when the followed point enters or leaves their regions. The signal passes the camera node to your handler.

<!-- SCREENSHOT PLACEHOLDER: Show a level scene with a room, magnet, zoom area, and path, each with its colored outline visible. Suggested file: docs/images/influence-nodes-level.png -->

### Rooms

`JuiceCamRoom2D` marks a rectangular area in your level. It can keep the camera view inside the room's walls, let the view extend past selected sides, or rotate the camera to match the room.

| Property | Default | Description |
| --- | ---: | --- |
| `room_size` | `(1000, 600)` | Room width and height in the node's local space. |
| `zoom_multiplier` | `1.0` | Increases the zoom needed to keep the view inside closed walls. |
| `open_sides` | None | Sides where the camera view may extend beyond the room. |
| `align_camera_rotation` | On | Uses the room's rotation while the camera is inside, if `allow_rotation` is enabled on the camera. |
| `snap_on_enter` | Off | Immediately moves to the room's constrained pose when this room becomes active. |

By default, all four sides are closed. JuiceCam keeps the entire visible camera view inside those walls, accounting for zoom and rotation. An open side lets the view extend past that wall. For example, open the top and bottom of a tall room to allow vertical camera movement while keeping the view between the left and right walls.

With `snap_on_enter` off, the camera moves smoothly toward a position that fits inside the room. The hard clamp only turns on after the camera view fits, so entering a room does not make the camera jump. Turn on `snap_on_enter` if you want an immediate move to a valid position.

The room has `room_entered(camera)` and `room_exited(camera)` signals. Drag its handles in the editor to resize it. The handles follow Godot's grid and pixel snap settings.

### Magnets

`JuiceCamMagnet2D` pulls the camera's destination toward the center of its shape or pushes it toward the edge. Choose a circle or rectangle, then set how quickly it moves the camera.

| Property | Default | Description |
| --- | ---: | --- |
| `magnet_shape` | Circle | Selects a circle or rectangle region. |
| `radius` | `200` | Circle radius in local units. |
| `rectangle_size` | `(400, 200)` | Rectangle dimensions in local units. |
| `attract_repel` | Attract | Chooses center attraction or edge repulsion. |
| `use_full_force` | On | Sends the focus directly to the center or boundary. |
| `force` | `(100, 100)` | Per-axis movement speed in local units per second when full force is off. |
| `falloff_curve` | 1 at center to 0 at edge | Controls how the movement slows near the edge. |

With **Use Full Force** enabled, the destination jumps to the center or edge. Turn it off to move the destination gradually. `force` sets the speed along each axis, and `falloff_curve` reduces that speed toward the edge of the shape. Movement follows the magnet's rotation and stays consistent at different frame rates.

Signals: `magnet_entered(camera)` and `magnet_exited(camera)`. Resize the region with its editor handles; the editor's snap settings apply.

### Zoom areas

`JuiceCamZoom2D` changes the zoom while the camera's followed point is inside the shape.

| Property | Default | Description |
| --- | ---: | --- |
| `zoom_shape` | Circle | Selects a circle or rectangle region. |
| `radius` | `200` | Circle radius in local units. |
| `rectangle_size` | `(400, 200)` | Rectangle dimensions in local units. |
| `zoom_factor` | `1.5` | Zoom multiplier at the region center. |
| `gradual_zoom` | On | Blends the effect from full strength at center to zero at the edge. |

When zoom areas overlap, the highest-priority area that changes the zoom takes effect. Camera zoom smoothing controls how quickly the view changes. Room walls and global limits may also restrict the final view.

Signals: `zoom_area_entered(camera)`, `zoom_area_exited(camera)`, and `zoom_level_changed(camera, zoom_level)`. Resize circles and rectangles with the editor handles.

### Paths

`JuiceCamPath2D` makes the camera follow an editable curve along one axis. Draw at least two points with the JuiceCam path tools in the 2D toolbar; no child `Path2D` node is needed.

| Property | Default | Description |
| --- | ---: | --- |
| `constraint_axis` | Y | Selects the path-local coordinate that follows the closest curve point. |

With the default Y setting, the camera's Y position follows the curve in the path's coordinates, while its X position stays free. The path only competes while the tracking point's X coordinate is between the path's first and last points. If it moves past that range, a lower-priority eligible path can take over. Cameras in separate `World2D` instances select independently. The editor shows a warning until the curve has at least two points.

<!-- SCREENSHOT PLACEHOLDER: Show a JuiceCamPath2D node with its curve and the camera constrained on the path in the 2D editor. Suggested file: docs/images/path-constraint.png -->

## 7. Cinematic sequences

Each `JuiceCamCinematic2D` node marks a camera position, rotation, and zoom. Give the points the same **Sequence Name** and a different **Sequence Position**. When you start that sequence, the camera visits its enabled points in order.

Each camera plays its own sequence and only uses points inside its viewport. For split screen, add points to every viewport that needs them.

<!-- SCREENSHOT PLACEHOLDER: Show three named cinematic points in the scene tree and their position IDs in the Inspector. Suggested file: docs/images/cinematic-sequence-setup.png -->

### Point settings

| Group | Property | Default | Description |
| --- | --- | ---: | --- |
| Sequence | `sequence_name` | Empty | Name passed to `start_cinematic()`. |
| Sequence | `sequence_position` | `0` | Order within the named sequence. Use a unique number for every point. |
| Sequence | `enabled` | On | Disabled points are skipped when playback starts. |
| Sequence | `hold_time` | `1 s` | Time to hold after arriving. `0` advances immediately on arrival. |
| Shot | `target_zoom` | `(1, 1)` | Linked zoom for this point. |
| Motion Override | `override_motion_settings` | Off | Uses this point's smoothing settings and forces smoothing on. |

With motion override off, a point uses the camera's normal smoothing settings. When override is on, choose its position damping type and tuning, plus rotation and zoom smoothing times. Spring-only properties appear only for Spring Damp. A point always supplies position, rotation, and zoom for the shot; camera target-rotation settings do not block a cinematic rotation.

If two enabled points in one viewport have the same sequence name and position, the editor shows a warning. JuiceCam still plays them, using their scene-tree paths to decide the order. Moving or renaming nodes can change that order, so give every point a unique position.

The editor displays a fixed-size marker for each cinematic point. Cinematic nodes do not draw runtime influence diagnostics.

### Play and stop from code

```gdscript
@onready var camera: JuiceCam2D = $JuiceCam2D

func begin_intro() -> void:
	if not camera.start_cinematic("intro"):
		push_warning("No enabled 'intro' points were found in this viewport.")

func skip_intro() -> void:
	camera.stop_cinematic()
```

`start_cinematic()` returns `false` and emits `cinematic_not_found` if no enabled points with that name are available in the camera's viewport. Starting a new sequence replaces the camera's current sequence. `stop_cinematic()` ends playback immediately.

### Signals and event timing

Connect these signals on `JuiceCam2D`:

| Signal | When it fires |
| --- | --- |
| `cinematic_started(sequence_name)` | A valid sequence begins. |
| `cinematic_stopped(sequence_name)` | Playback is stopped, either manually or after normal completion. |
| `cinematic_completed(sequence_name)` | The last point completes normally. |
| `cinematic_not_found(sequence_name)` | No enabled matching points exist in this camera's viewport. |
| `cinematic_point_started(sequence_name, point)` | The camera begins moving toward a point. |
| `cinematic_point_arrived(sequence_name, point)` | The camera reaches the point's pose. |
| `cinematic_point_completed(sequence_name, point)` | The point's hold ends and playback advances. |

Use `cinematic_point_started` to trigger an effect as the camera begins moving. Use `cinematic_point_arrived` for an effect timed to the shot, or `cinematic_point_completed` to advance game logic. The [Screen Shake](#screen-shake) example connects to the point-start signal.

During a cinematic, rooms, magnets, and zoom areas do not change the shot, though their enter and exit signals still fire. Global camera limits still apply. Add-ons choose in code whether to run during a cinematic: Screen Shake does; Mouse Follow, Grid Snap, and Velocity Zoom pause their effects.

## 8. Add-ons

Add-ons are optional `Resource` scripts assigned to a camera's **Add-ons** array. They change the camera while the game runs; they are not Godot EditorPlugins. JuiceCam creates a separate runtime copy for every camera, so each camera has its own shake timers and effect state.

The Add-ons picker only shows effects you can use, such as Screen Shake. Base classes for writing your own add-ons are hidden. Add as many effects as you need, and give each one a different ID if you want to retrieve them by name.

Every add-on has an `addon_id` and an `enabled` setting. The ID is plain text: for example, enter `impact_shake` in the Inspector, then use `"impact_shake"` in code. Add-ons are enabled by default. JuiceCam makes a separate copy for each camera. It calls `setup(camera)` when the add-on starts and `exit(camera)` when it stops. To choose whether an effect runs during cinematics, override `runs_during_cinematics()` in your script. It returns `true` by default.

<!-- SCREENSHOT PLACEHOLDER: Show the Add-ons array with several concrete JuiceCam resources, including two screen shakes with different IDs. Suggested file: docs/images/addons-inspector.png -->

### Screen Shake

`JuiceCamScreenShake2D` shakes the camera view without changing the target positions. Its default ID is `screen_shake`. Choose a preset or adjust the shake pattern and timing:

| Property | Default | Description |
| --- | ---: | --- |
| `preset` | Custom | Gunshot, Earthquake, Handheld, Explosion, Impact, Rumble, Vibration, Wobbly, or Custom. Choosing a preset fills in its settings. |
| `speed` | `15` | Shake oscillation speed. |
| `intensity` | `10 px` | Position amplitude before trauma falloff. |
| `shake_type` | Vertical + Horizontal + Perlin | Selects vertical, horizontal, random, Perlin, rotate, circular, or zoom channels. |
| `trauma` | `1` | Default strength from zero to one. |
| `trauma_attack` | `0 s` | Time to reach full strength. |
| `duration` | `0.5 s` | Full-strength time before decay. |
| `trauma_decay` | `0.8 s` | Time to fade to zero. |
| `endless` | Off | Holds strength after attack until `stop()` is called. |

Shake is enabled during cinematics so cinematic signals can trigger it:

```gdscript
@onready var camera: JuiceCam2D = $JuiceCam2D
var impact_shake: JuiceCamScreenShake2D

func _ready() -> void:
	impact_shake = camera.get_addon("impact_shake") as JuiceCamScreenShake2D
	camera.cinematic_point_started.connect(_on_cinematic_point_started)

func _on_cinematic_point_started(
	_sequence_name: StringName,
	point: JuiceCamCinematic2D
) -> void:
	if point.name == "ExplosionShot" and impact_shake != null:
		impact_shake.shake(0.8)
```

Give that resource the ID `impact_shake` in its Inspector entry. `shake()` starts or restarts the effect; pass an optional strength from `0` to `1`. `add_trauma(amount)` adds to the current strength up to `1`. `stop()` ends it. `shake_started` and `shake_finished` signal the effect lifecycle. Separate shake resources can hold different presets and timers.

Screen-shake runtime API:

| Method or signal | Effect |
| --- | --- |
| `shake(trauma_amount = -1.0)` | Starts or restarts using the configured trauma. A supplied value from `0` to `1` overrides it. |
| `add_trauma(amount)` | Adds strength to an active shake, capped at `1`. Starts a shake if idle. |
| `stop()` | Ends an active shake immediately. |
| `is_shaking()` | Returns whether the instance is active. |
| `get_current_trauma()` | Returns current strength, or zero while idle. |
| `apply_preset(preset)` | Applies the selected built-in preset to the resource settings. |
| `shake_started` | Emitted when a shake starts. |
| `shake_finished` | Emitted when it ends or is stopped. |

### Mouse Follow

`JuiceCamMouseFollow2D` offsets the rendered camera toward the mouse within that camera's viewport. Its default ID is `mouse_follow`.

- `look_radius` defaults to `300` world units. The offset follows the mouse direction and is capped to this circular radius, including at viewport corners.
- `influence` scales that offset from zero to full strength.
- `smoothing` defaults to `0.2`. Set it to zero for immediate mouse response; larger values ease the offset more slowly.
- The offset is in camera-local axes and rotates with the camera.
- It is applied after target tracking, deadzones, paths, rooms, and camera smoothing. It does not affect which influences apply to the tracked targets.
- Global camera limits still clamp the final rendered view.
- It is skipped during cinematics.

Each camera reads the mouse position from its own viewport, which makes it usable in separate split-screen viewports.

### Grid Snap

`JuiceCamGridSnap2D` snaps the solved camera position to a world-space grid after target tracking and camera smoothing. Its default ID is `grid_snap`.

- `grid_size` defaults to `(64, 64)`.
- Set either grid-size axis to zero to leave that axis unsnapped.
- `grid_offset` moves the grid origin.
- `smoothing` defaults to `0` for immediate, pixel-aligned movement. Higher values ease the camera between grid points.
- It is skipped during cinematics.

Grid Snap affects the camera pose, not the tracked targets or influence selection. Mouse Follow can add an independent offset on top, so disable Mouse Follow when the entire rendered view must stay pixel-aligned. Grid Snap remains subject to room and global bounds; Mouse Follow bypasses room bounds but remains subject to global limits.

### Velocity Zoom

`JuiceCamVelocityZoom2D` smoothly zooms out as active targets move faster. Its default ID is `velocity_zoom`.

| Property | Default | Description |
| --- | ---: | --- |
| `start_speed` | `300 px/s` | Speed where zoom-out begins. |
| `full_zoom_speed` | `1200 px/s` | Speed where maximum zoom-out is reached. |
| `maximum_zoom_out` | `1.5x` | Maximum visible world width and height multiplier. |
| `zoom_out_time` | `0.25 s` | Response time as speed increases. |
| `zoom_in_time` | `0.6 s` | Return time as speed falls. |

It measures how fast each active target moves and combines those speeds using target weights. It uses speed, not direction, so targets moving in opposite directions do not cancel each other out. The measurement uses each node's origin and ignores movement caused only by a rotating offset. The zoom returns to normal during cinematics or when no targets are active. Room and global limits can still restrict the view.

### Retrieve an add-on at runtime

```gdscript
@onready var camera: JuiceCam2D = $JuiceCam2D

func _ready() -> void:
	var shake := camera.get_addon("impact_shake") as JuiceCamScreenShake2D
	if shake != null:
		shake.shake()
```

Use `get_addons()` to retrieve the camera's runtime instances. `add_addon(resource)` makes a camera-owned copy and returns its runtime instance. `remove_addon(id)` removes the configured resource with that ID. Empty IDs added at runtime receive a generated `addon_N` ID; duplicate IDs are rejected by `add_addon()` and warned about for Inspector configurations.

### Write a custom add-on

Use `JuiceCamTargetModifier2D` to change where the camera is heading before smoothing. Use `JuiceCamOutputModifier2D` to add a position offset, rotation, or zoom effect after the camera reaches its base pose. Output position offsets are constrained by rooms by default. Override `bypasses_room_clamp()` when an offset should ignore room bounds; global camera limits still clamp the final rendered position.

JuiceCam passes a `JuiceCamAddonFrame2D` to the add-on each update and reuses it on the next update. Read or change its fields inside the callback, but do not save the frame for later. Keep changing values on the add-on itself. In Inspector property setters, call `emit_changed()` so JuiceCam updates its runtime copy.

```gdscript
@tool
extends JuiceCamOutputModifier2D
class_name JuiceCamPulse2D

@export_range(0.0, 0.5, 0.01) var rotation_amplitude: float = 0.05:
	set(value):
		rotation_amplitude = value
		emit_changed()

@export_range(0.1, 20.0, 0.1) var frequency: float = 3.0:
	set(value):
		frequency = value
		emit_changed()

var _elapsed: float = 0.0

func setup(_camera: Node2D) -> void:
	_elapsed = 0.0

func runs_during_cinematics() -> bool:
	return false

func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	_elapsed += frame.delta
	frame.output_rotation_offset += sin(_elapsed * TAU * frequency) * rotation_amplitude
```

Set `runs_during_cinematics()` in your script. Return `true` to keep the effect during cinematics or `false` to hide it. The modifier still updates, so it can reset or advance its own values. The default is `true`.

`setup(camera)` and `exit(camera)` run when JuiceCam adds or removes the runtime copy. Use them to connect or disconnect signals and reset values. The frame provides these fields:

| Field | Use |
| --- | --- |
| `camera` | The camera node using this runtime add-on. |
| `delta` | Time since the previous camera update. |
| `has_target` | Whether the camera has an active target. |
| `is_cinematic` | Whether this camera is playing a cinematic point. |
| `viewport_size` | Effective viewport size in pixels. |
| `target_speed` | Weighted mean target-node speed in world units per second. |
| `target_position` | Camera destination. Target modifiers can change it. |
| `current_position`, `current_rotation`, `current_zoom` | The camera's base pose. Output modifiers see the pose after the camera update. |
| `output_position_offset` | Extra position offset in camera-aligned directions. |
| `output_rotation_offset` | Additive rotation in radians. |
| `output_zoom_multiplier` | Multiplicative zoom scale. |

Add-ons run in the order shown in the array. Target modifiers change the destination before path projection and smoothing, so enabled paths constrain the tracked pose. Output modifiers such as Mouse Follow and Grid Snap adjust the rendered camera position after that solve; they do not change target tracking or influence selection. Room and global bounds clamp the grid-snapped pose, while Mouse Follow bypasses room bounds and remains subject to global limits. A shake also affects only the rendered camera and never makes the camera chase its own movement.

## 9. Editor tools and debug drawing

### Targets Inspector

The camera's custom **Targets** control keeps target entries together in a collapsible section. Use **Add Target** to open the scene-tree picker, then choose a `Node2D`. A target card shows the selected node's name and, where available, its icon. The pencil button changes the assigned node; the delete button removes the entire target entry. Target tuning stays with the entry when its node is changed.

### Influence resizing

Room, magnet, and zoom nodes have editor drag handles for changing dimensions. The handles use the active Godot snap settings, so grid and pixel snapping work as expected. You can still enter exact dimensions in the Inspector.

<!-- SCREENSHOT PLACEHOLDER: Show a selected room with drag handles while Godot snapping is enabled. Suggested file: docs/images/room-resize-handles.png -->

### Camera diagnostics

Enable **Debug → Debug Draw Enabled** to show the camera's tracking. A purple `#BD5CBD` line connects the camera position to its destination. A large circle marks the camera, a small circle marks the destination, and squares show the target radii. The squares stay aligned with the camera when targets rotate. Their lines stay one screen pixel wide as you zoom in or out.

Influence colors are distinct:

| Node | Debug color |
| --- | --- |
| Camera | Purple `#BD5CBD` |
| Zoom area | Orange `#F1A64A` |
| Magnet | Teal `#55C8C2` |
| Room | Green `#75C98B` |
| Path | Yellow `#F2D45C` |

Influence shapes are visible in the editor. At runtime, camera debug enables diagnostics for influence nodes in the same `World2D`. Cinematic points use a fixed-size editor marker and have no runtime debug draw.

<!-- SCREENSHOT PLACEHOLDER: Show the purple camera line/circles and target squares together with colored room, magnet, zoom, and path outlines. Suggested file: docs/images/debug-overlays.png -->

## 10. Viewports, split screen, and scene changes

### Cameras and viewports

Every `JuiceCam2D` uses the viewport it is inside. For split screen, put each camera under the `SubViewport` it controls and assign the targets for that view. Each camera tracks its own targets and keeps its own smoothing, cinematic progress, and add-on effects.

JuiceCam only checks influence nodes in the camera's `World2D`. So an influence in an isolated `SubViewport` world cannot affect a camera in another world, even if both are at the same coordinates. If viewports share a `World2D`, their cameras can use the same influence nodes, but each camera reacts separately.

Call `camera.make_current()` to activate the camera in its viewport. Call `camera.is_current()` to check whether it is active. `get_internal_camera()` returns the child `Camera2D` for code that needs direct access to Godot's camera node. For normal gameplay, use the `JuiceCam2D` methods and properties.

### Scene transitions

Targets and cinematic points refer to nodes in the scene. When you replace a level, its camera, targets, and influence nodes are removed together. The next level's camera uses its own target assignments; JuiceCam does not carry targets from the old level over.

If the camera is persistent (for example, an autoload) while the player is replaced, update its targets after the new scene has entered the tree:

```gdscript
camera.clear_targets()
camera.add_target(new_player)
```

Call `clear_targets()` when removing a target while keeping the camera alive. `get_all_targets()` skips targets that have been freed or are being deleted. When the camera leaves the scene, JuiceCam cleans up its add-ons and sets them up again if the camera is added back.

For a cinematic that must play after loading a new level, start it after that level's cinematic nodes have entered the camera's viewport. Calling `start_cinematic()` earlier returns `false` and emits `cinematic_not_found` because the points are not available yet.

## 11. Performance notes

The camera updates in the mode you choose. Use **Idle** for most games. Use **Physics** if the camera follows physics-driven objects and should update in sync with them.

JuiceCam uses a spatial grid to find nearby influences, then checks whether the camera is inside each shape. It does not have to check every influence on every update. Keep shapes near the parts of the level where you use them, and disable any you do not need. The grid helps with large scenes, but it cannot guarantee a frame rate. Profile your game to see how it performs.

Add-ons with `enabled = false` do not contribute. Add only the resources needed by each camera. For split-screen, each camera owns its own runtime copies; expensive custom add-ons should account for that per-camera work.

## 12. Runtime API reference

### Targets

| Method or property | Result |
| --- | --- |
| `camera.targets` | Ordered array copy of live target-data objects. |
| `camera.get_all_targets()` | Ordered `Array[JuiceCamTargetData]` of valid assigned targets. |
| `camera.target` | Primary target node; can be read or set. |
| `camera.get_primary_target()` | First assigned target node, or `null`. |
| `camera.set_primary_target(node)` | Sets the first target, adding it if needed. |
| `camera.add_target(node, weight = 1.0, radius = 32.0, offset = Vector2.ZERO, use_lookahead = true, lookahead_factor = 1.0)` | Adds the target and returns its live data, or `null` for an invalid node. A duplicate node returns its existing entry. |
| `camera.set_target_node(index, node)` | Replaces an entry's node while preserving its settings. Returns `bool`. |
| `camera.remove_target(node)` | Removes the matching node. |
| `camera.remove_target_at(index)` | Removes by order. Returns `bool`. |
| `camera.has_target(node)` | Tests membership. |
| `camera.clear_targets()` | Removes every target. |
| `camera.calculate_target_centroid()` | Returns the targets' weighted center in world coordinates. |
| `camera.teleport_to_target()` | Immediately moves to the weighted centroid and resets smoothing state. |

`teleport_to_target()` immediately moves the camera to the targets' weighted center, applies target rotation if enabled, updates zoom, and respects global limits. It does not apply magnets, dead zones, paths, or room constraints.

### Camera state and activation

| Method | Result |
| --- | --- |
| `camera.get_effective_viewport_size()` | Effective viewport size in pixels. |
| `camera.get_current_zoom()` | Current rendered zoom, including output add-on multipliers. |
| `camera.make_current()` | Makes the camera active in its viewport. |
| `camera.is_current()` | Whether this camera is active. |
| `camera.get_internal_camera()` | Returns the internally managed `Camera2D`. |

### Cinematics

| Method | Result |
| --- | --- |
| `camera.start_cinematic(sequence_name)` | Starts the named sequence; returns `false` if none is available in this viewport. |
| `camera.stop_cinematic()` | Stops the active sequence. |
| `camera.is_cinematic_playing()` | Reports whether this camera is playing a sequence. |
| `camera.get_active_cinematic_name()` | Active name as `StringName`, or empty when idle. |
| `camera.get_current_cinematic_point()` | Current point, or `null`. |

### Add-ons

| Method | Result |
| --- | --- |
| `camera.get_addon(id)` | Camera-owned runtime instance for the ID, or `null`. Cast to its concrete add-on class for custom methods. |
| `camera.get_addons()` | Array copy of this camera's runtime add-on instances. |
| `camera.add_addon(resource)` | Adds a copied configuration and returns its runtime instance; returns `null` for invalid resources or duplicate IDs. |
| `camera.remove_addon(id)` | Removes the configured resource with that ID. Returns `bool`. |

## 13. Troubleshooting

### The camera does not move

- Check that the camera has a target in its **Targets** section.
- Check that at least one target has a weight above zero.
- Confirm the target is a `Node2D` in the same running scene and viewport.
- If you expected a stationary shot, zero weights intentionally stop target tracking.

### A target does not appear in the picker

The picker shows `Node2D` nodes in the current scene tree. Choose a node in the camera's scene and viewport. Nodes outside that scene tree are not available in the picker.

### Auto framing does not change zoom

Auto framing needs at least two valid assigned target entries and at least one positive target weight. With exactly one assigned target, the regular **Zoom** property applies. For a group, check that `auto_framing` is enabled and that the minimum and maximum framing zoom allow the requested view. Remember that a zero-weight entry is excluded from tracking but still occupies space in the framing calculation.

### A room appears to snap or its walls do not match the camera view

Check `snap_on_enter`. It is off by default; with it off, the camera eases toward a valid pose and the final hard clamp engages after the current pose fits. Inspect room size, open sides, zoom, camera rotation, and the containing viewport's actual size. The room clamp uses the visible camera rectangle, not only the camera center.

### A path does not affect the camera

Draw at least two points on the `JuiceCamPath2D`, make sure it is enabled, and check that its camera shares the same `World2D`. A path only competes while the tracking point is within its endpoint range on the unconstrained axis; among eligible paths, the highest priority controls the camera.

### An influence appears to affect the wrong camera

JuiceCam only uses influences in the camera's `World2D`. Check that the camera and influence are in the same world. If two cameras share a `World2D`, both can use the same influence nodes; move the nodes or adjust their priorities if needed.

### A cinematic does not start

Check for an exact sequence-name match, at least one enabled point, and that the points are inside the camera's viewport. Give each point a unique position ID. Use the return value from `start_cinematic()` and listen for `cinematic_not_found` when loading scenes asynchronously.

### An add-on lookup returns `null`

The ID must match the configured add-on's plain-text `addon_id`. Check spelling, capitalization, and that the resource is in the camera's Add-ons array. If several Inspector resources share an ID, the camera warns that lookup returns the first; give each resource a unique ID.

### The mouse or grid effect stops during a cinematic

That is the built-in behavior. Mouse Follow and Grid Snap suppress their contributions during cinematics. Screen Shake is enabled so sequence signals can trigger it. Custom add-ons can choose their own behavior in `runs_during_cinematics()`.

## 14. Node and signal reference

| Node / class | Purpose | Signals |
| --- | --- | --- |
| `JuiceCam2D` | Camera rig and runtime API. | `cinematic_started`, `cinematic_stopped`, `cinematic_completed`, `cinematic_not_found`, `cinematic_point_started`, `cinematic_point_arrived`, `cinematic_point_completed` |
| `JuiceCamRoom2D` | Rectangular room boundary. | `room_entered(camera)`, `room_exited(camera)` |
| `JuiceCamMagnet2D` | Attraction or repulsion region. | `magnet_entered(camera)`, `magnet_exited(camera)` |
| `JuiceCamZoom2D` | Local zoom multiplier. | `zoom_area_entered(camera)`, `zoom_area_exited(camera)`, `zoom_level_changed(camera, zoom_level)` |
| `JuiceCamPath2D` | Projects movement onto a `Path2D` curve axis. | None |
| `JuiceCamCinematic2D` | Pose within a named camera sequence. | None |
| `JuiceCamTargetData` | Runtime target settings and lookahead state. | None |
| `JuiceCamAddon2D` | Base resource for optional camera behavior. | None |
| `JuiceCamTargetModifier2D` | Add-on stage before camera smoothing. | None |
| `JuiceCamOutputModifier2D` | Add-on stage after the base camera pose. | None |
| `JuiceCamAddonFrame2D` | Per-update data passed to add-ons. | None |

Influence entry/exit signals fire for each camera when its followed point enters or leaves a shape. Cinematic signals come from `JuiceCam2D`; screen-shake signals come from each `JuiceCamScreenShake2D` instance.

---

## Screenshot and release checklist

This Markdown file is the complete guide manuscript and can be rendered as a PDF after screenshots and final branding are supplied. Before publishing, replace each `SCREENSHOT PLACEHOLDER` and `COVER ... PLACEHOLDER` comment with the final image path and caption. Keep the screenshots at a readable resolution and show real editor or gameplay states from the release build.

| Suggested image | What it should show | Section |
| --- | --- | --- |
| `docs/images/cover-gameplay.png` | Cover image and JuiceCam branding. | Cover |
| `docs/images/juicecam-feature-strip.png` | Group framing, a room-constrained shot, and a cinematic shot. | What JuiceCam does |
| `docs/images/install-enable-plugin.png` | Enabled plugin and `JuiceCam2D` in Create Node. | Install |
| `docs/images/camera-targets-inspector.png` | Target picker, assigned target card, and empty state. | First camera |
| `docs/images/camera-inspector-groups.png` | Camera Inspector group order and conditional properties. | Camera Inspector |
| `docs/images/influence-nodes-level.png` | Room, magnet, zoom area, and path outlines together. | Influence nodes |
| `docs/images/path-constraint.png` | Path node hierarchy and camera following its curve. | Paths |
| `docs/images/cinematic-sequence-setup.png` | Named points with unique position IDs. | Cinematics |
| `docs/images/addons-inspector.png` | Concrete add-on resources and two uniquely named shakes. | Add-ons |
| `docs/images/room-resize-handles.png` | Room resize handles with editor snapping enabled. | Editor tools |
| `docs/images/debug-overlays.png` | Camera diagnostics and colored influence outlines. | Debug drawing |

### Included project resources

- [Open the guided demo scene](../JuiceCamDemo/scenes/demo.tscn) in the included Godot project, or [play it online](https://musakashi.itch.io/juicecam).
- [README quick start](../README.md#quick-start)
- [Support and bug reports](../SUPPORT.md)

<!-- RELEASE PLACEHOLDER: Add the PDF download URL after the rendered guide is attached to a GitHub release. -->

