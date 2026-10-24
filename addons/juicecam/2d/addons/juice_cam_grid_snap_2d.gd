@tool
class_name JuiceCamGridSnap2D
extends JuiceCamOutputModifier2D

## Snaps the solved camera position to a world-space grid.

var _smoothed_camera_position: Vector2 = Vector2.ZERO
var _has_smoothed_camera_position: bool = false

@export_group("Grid Snap")
## Grid spacing in world units. Set either component to zero to leave that axis unsnapped.
@export_custom(PROPERTY_HINT_LINK, "") var grid_size: Vector2 = Vector2(64.0, 64.0):
	set(value):
		var new_value := Vector2(maxf(0.0, value.x), maxf(0.0, value.y))
		if grid_size == new_value:
			return
		grid_size = new_value
		emit_changed()
## World-space origin used to align the grid.
@export var grid_offset: Vector2 = Vector2.ZERO:
	set(value):
		if grid_offset == value:
			return
		grid_offset = value
		emit_changed()
## Higher values smooth movement between grid points. Zero snaps immediately.
@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.0:
	set(value):
		var new_value: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(smoothing, new_value):
			return
		smoothing = new_value
		emit_changed()


func _init() -> void:
	if addon_id.is_empty():
		addon_id = "grid_snap"


func runs_during_cinematics() -> bool:
	return false


func setup(camera: Node2D) -> void:
	_smoothed_camera_position = camera.global_position
	_has_smoothed_camera_position = is_instance_valid(camera)


func modify_output(frame: JuiceCamAddonFrame2D) -> void:
	if frame.is_cinematic:
		_has_smoothed_camera_position = false
		return

	if not _has_smoothed_camera_position:
		_smoothed_camera_position = frame.current_position
		_has_smoothed_camera_position = true

	var snapped_position: Vector2 = frame.current_position
	if grid_size.x > 0.0:
		snapped_position.x = snappedf(snapped_position.x - grid_offset.x, grid_size.x) + grid_offset.x
	if grid_size.y > 0.0:
		snapped_position.y = snappedf(snapped_position.y - grid_offset.y, grid_size.y) + grid_offset.y
	if grid_size.x > 0.0:
		_smoothed_camera_position.x = JuiceCamOutputModifier2D.smooth_value(
			_smoothed_camera_position.x,
			snapped_position.x,
			smoothing,
			frame.delta
		)
	else:
		_smoothed_camera_position.x = frame.current_position.x
	if grid_size.y > 0.0:
		_smoothed_camera_position.y = JuiceCamOutputModifier2D.smooth_value(
			_smoothed_camera_position.y,
			snapped_position.y,
			smoothing,
			frame.delta
		)
	else:
		_smoothed_camera_position.y = frame.current_position.y

	var world_offset: Vector2 = _smoothed_camera_position - frame.current_position
	frame.output_position_offset += world_offset.rotated(-frame.current_rotation)
