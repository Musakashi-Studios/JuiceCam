# Create a custom JuiceCam add-on

JuiceCam add-ons are small `Resource` scripts that extend a camera. They are different from Godot `EditorPlugin`s: an add-on runs with a `JuiceCam2D` instance and can change its tracked destination or its rendered pose.

Keep your scripts in your game project, outside `addons/juicecam`. For example:

```text
res://camera_addons/juice_cam_pulse_2d.gd
```

That keeps your work separate from JuiceCam's files when you update the plugin.

## Choose when the add-on runs

Extend one of these base classes:

| Base class | Callback | Use it for |
| --- | --- | --- |
| `JuiceCamTargetModifier2D` | `modify_target(frame)` | Change the camera destination before camera smoothing and path projection. |
| `JuiceCamOutputModifier2D` | `modify_output(frame)` | Add a visual position, rotation, or zoom effect after the camera solves its base pose. |

An output effect does not change target tracking or influence selection. Its position offset is camera-aligned. Room bounds constrain that offset by default; global camera limits still constrain the final view. Override `bypasses_room_clamp()` only when the effect should ignore room bounds.

## Build a simple output add-on

Create `res://camera_addons/juice_cam_pulse_2d.gd`:

```gdscript
@tool
class_name JuiceCamPulse2D
extends JuiceCamOutputModifier2D

@export_range(0.0, 0.5, 0.01) var rotation_amplitude: float = 0.05:
	set(value):
		if is_equal_approx(rotation_amplitude, value):
			return
		rotation_amplitude = value
		emit_changed()

@export_range(0.1, 20.0, 0.1) var frequency: float = 3.0:
	set(value):
		if is_equal_approx(frequency, value):
			return
		frequency = value
		emit_changed()

var _elapsed: float = 0.0


func setup(_camera: Node2D) -> void:
	_elapsed = 0.0


func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	_elapsed += frame.delta
	frame.output_rotation_offset += sin(_elapsed * TAU * frequency) * rotation_amplitude
```

`@tool` and `class_name` make the script available as a named resource type in the editor. After Godot scans the new script, add it to a camera's **Add-ons** array and set its `addon_id`, for example `pulse`. Each camera receives its own runtime copy, so `_elapsed` is independent per camera.

Use the frame's output fields to contribute effects:

| Field | Meaning |
| --- | --- |
| `output_position_offset` | Add a camera-aligned offset in world units. |
| `output_rotation_offset` | Add rotation in radians. |
| `output_zoom_multiplier` | Multiply the base zoom. `(1, 1)` leaves zoom unchanged. |

You can add to position and rotation fields. Multiply `output_zoom_multiplier` by your desired factor. JuiceCam resets these output fields each camera update, then accumulates each enabled output add-on's contribution.

## Modify the tracked destination

For a destination modifier, extend `JuiceCamTargetModifier2D` and change `frame.target_position`:

```gdscript
@tool
class_name JuiceCamTargetOffset2D
extends JuiceCamTargetModifier2D

@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		if offset == value:
			return
		offset = value
		emit_changed()


func modify_target(frame: JuiceCamAddonFrame2D) -> void:
	frame.target_position += offset
```

The camera then applies its normal path projection, smoothing, and constraints to the modified destination. Use an output modifier when you want an effect that does not steer target tracking.

## Add settings and runtime state

Export settings as ordinary GDScript properties so users can tune them in the Inspector. Call `emit_changed()` from setters when a setting changes; JuiceCam uses that signal to rebuild the camera-owned runtime copy from the configured resource.

Use `setup(camera)` to initialize state or connect signals. Use `exit(camera)` to disconnect them and release anything the add-on owns. These methods receive the runtime copy's camera when the copy is attached or removed. Keep changing state on the add-on instance itself.

JuiceCam reuses one `JuiceCamAddonFrame2D` object on every update. Read or change it only inside `modify_target()` or `modify_output()`; do not store the frame for later. Its useful values include:

| Field | Meaning |
| --- | --- |
| `camera` | The camera using this add-on. |
| `delta` | Time since the previous camera update. |
| `has_target` | Whether the camera has an active target or cinematic point. |
| `is_cinematic` | Whether this camera is playing a cinematic point. |
| `viewport_size` | Effective viewport size in pixels. |
| `target_speed` | Weighted mean speed of active targets, in world units per second. |
| `target_position` | Mutable destination for target modifiers. |
| `current_position`, `current_rotation`, `current_zoom` | The camera's base pose. Output modifiers see the solved pose. |

Keep per-frame callbacks lightweight. Avoid creating temporary nodes or large collections every update, especially when a game uses several cameras.

## Choose cinematic behavior

Add-ons run during cinematics by default. Override `runs_during_cinematics()` when the effect should pause:

```gdscript
func runs_during_cinematics() -> bool:
	return false
```

The callback still runs so the add-on can keep its timing state current, but JuiceCam discards its contribution during the cinematic. Screen Shake uses the default behavior so cinematic signals can trigger it.

## Access an add-on from code

Give the Inspector resource a unique `addon_id`, then retrieve its camera-owned runtime instance:

```gdscript
var pulse: JuiceCamPulse2D

func _ready() -> void:
	pulse = $JuiceCam2D.get_addon("pulse") as JuiceCamPulse2D
```

You can also add one at runtime. `add_addon()` duplicates the supplied resource and returns the camera-owned copy:

```gdscript
var pulse := JuiceCamPulse2D.new()
pulse.addon_id = "pulse"
var runtime_pulse := $JuiceCam2D.add_addon(pulse) as JuiceCamPulse2D
```

Use `remove_addon("pulse")` to remove it. Add-on IDs must be unique on each camera; duplicate IDs make `get_addon()` return the first matching resource.
