@tool
@icon("res://addons/juicecam/icons/juice_cam_path_2d.png")
class_name JuiceCamPath2D
extends "res://addons/juicecam/2d/juice_cam_influence_2d.gd"

## Constrains camera movement to an editable curve owned by this node.

const DEBUG_COLOR: Color = JuiceCamDebugPalette2D.PATH
const ENDPOINT_SIZE: Vector2 = Vector2(10.0, 10.0)
const PATH_GROUP_NAME: StringName = &"juice_cam_paths_2d"
const CAPTURE_RANGE_EPSILON: float = 0.001

enum ConstraintAxis {
	X,
	Y,
}

@export_group("Path")
## Camera movement is projected onto the selected axis of the path.
@export var constraint_axis: ConstraintAxis = ConstraintAxis.Y

var _connected_curve: Curve2D = null
var _last_path_point_by_camera: Dictionary[int, Vector2] = {}

@export_storage var curve: Curve2D = Curve2D.new():
	set(value):
		if curve == value:
			return
		_disconnect_curve()
		curve = value
		if is_inside_tree():
			_connect_curve()
			_on_curve_changed()

@export_storage var smooth_points: PackedByteArray = PackedByteArray()


func _init() -> void:
	curve = Curve2D.new()
	curve.resource_local_to_scene = true


func _enter_tree() -> void:
	add_to_group(PATH_GROUP_NAME)
	super._enter_tree()
	_connect_curve()


func _ready() -> void:
	super._ready()
	_connect_curve()
	update_configuration_warnings()


func _exit_tree() -> void:
	_disconnect_curve()
	_last_path_point_by_camera.clear()
	super._exit_tree()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not has_valid_path():
		warnings.append("Draw at least two path points with the JuiceCam path tools in the 2D toolbar.")
	return warnings


func has_valid_path() -> bool:
	return curve != null and curve.get_point_count() >= 2


## A path only competes while the tracking position is between its endpoints
## on the axis that this path leaves unconstrained.
func contains_tracking_position_in_free_axis_range(world_position: Vector2) -> bool:
	if not has_valid_path():
		return false
	var tracking_position: Vector2 = to_local(world_position)
	var first_point: Vector2 = curve.get_point_position(0)
	var last_point: Vector2 = curve.get_point_position(curve.get_point_count() - 1)
	var tracking_axis: float
	var first_axis: float
	var last_axis: float
	if constraint_axis == ConstraintAxis.X:
		tracking_axis = tracking_position.y
		first_axis = first_point.y
		last_axis = last_point.y
	else:
		tracking_axis = tracking_position.x
		first_axis = first_point.x
		last_axis = last_point.x
	var minimum_axis: float = minf(first_axis, last_axis) - CAPTURE_RANGE_EPSILON
	var maximum_axis: float = maxf(first_axis, last_axis) + CAPTURE_RANGE_EPSILON
	return tracking_axis >= minimum_axis and tracking_axis <= maximum_axis


func add_path_point(position: Vector2, smooth: bool = true) -> int:
	if curve == null:
		curve = Curve2D.new()
	var point_index: int = curve.get_point_count()
	var was_connected: bool = _suspend_curve_updates()
	curve.add_point(position)
	var updated_smooth_points: PackedByteArray = smooth_points.duplicate()
	updated_smooth_points.resize(point_index)
	updated_smooth_points.append(1 if smooth else 0)
	smooth_points = updated_smooth_points
	_rebuild_automatic_handles(point_index - 1, point_index + 1)
	_resume_curve_updates(was_connected)
	_on_curve_changed()
	return point_index


func insert_path_point(point_index: int, position: Vector2, smooth: bool) -> void:
	if curve == null:
		curve = Curve2D.new()
	var bounded_index: int = clampi(point_index, 0, curve.get_point_count())
	var was_connected: bool = _suspend_curve_updates()
	curve.add_point(position, Vector2.ZERO, Vector2.ZERO, bounded_index)
	var updated_smooth_points: PackedByteArray = smooth_points.duplicate()
	updated_smooth_points.resize(curve.get_point_count() - 1)
	updated_smooth_points.insert(bounded_index, 1 if smooth else 0)
	smooth_points = updated_smooth_points
	_rebuild_automatic_handles(bounded_index - 1, bounded_index + 1)
	_resume_curve_updates(was_connected)
	_on_curve_changed()


func remove_path_point(point_index: int) -> void:
	if curve == null or point_index < 0 or point_index >= curve.get_point_count():
		return
	var was_connected: bool = _suspend_curve_updates()
	curve.remove_point(point_index)
	var updated_smooth_points: PackedByteArray = smooth_points.duplicate()
	if point_index < updated_smooth_points.size():
		updated_smooth_points.remove_at(point_index)
	updated_smooth_points.resize(curve.get_point_count())
	smooth_points = updated_smooth_points
	_rebuild_automatic_handles(point_index - 1, point_index + 1)
	_resume_curve_updates(was_connected)
	_on_curve_changed()


func set_path_point_position(point_index: int, position: Vector2) -> void:
	if curve == null or point_index < 0 or point_index >= curve.get_point_count():
		return
	if curve.get_point_position(point_index).is_equal_approx(position):
		return
	var was_connected: bool = _suspend_curve_updates()
	curve.set_point_position(point_index, position)
	_rebuild_automatic_handles(point_index - 1, point_index + 1)
	_resume_curve_updates(was_connected)
	_on_curve_changed()


func set_path_point_smooth(point_index: int, smooth: bool) -> void:
	if curve == null or point_index < 0 or point_index >= curve.get_point_count():
		return
	var current_smooth: bool = get_path_point_smooth(point_index)
	if current_smooth == smooth:
		return
	var updated_smooth_points: PackedByteArray = smooth_points.duplicate()
	updated_smooth_points.resize(curve.get_point_count())
	updated_smooth_points[point_index] = 1 if smooth else 0
	smooth_points = updated_smooth_points
	var was_connected: bool = _suspend_curve_updates()
	_rebuild_automatic_handles(point_index, point_index)
	_resume_curve_updates(was_connected)
	_on_curve_changed()


func get_path_point_smooth(point_index: int) -> bool:
	return (
		curve != null
		and point_index >= 0
		and point_index < curve.get_point_count()
		and point_index < smooth_points.size()
		and smooth_points[point_index] != 0
	)


## Projects a camera destination onto the path while preserving its free axis.
func constrain_camera_position(camera: Node2D, world_position: Vector2) -> Vector2:
	if not enabled or not has_valid_path():
		return world_position
	var camera_id: int = camera.get_instance_id()
	var path_local_position: Vector2 = to_local(world_position)
	var projection_query: Vector2 = path_local_position
	if _last_path_point_by_camera.has(camera_id):
		var previous_path_point: Vector2 = _last_path_point_by_camera[camera_id]
		if constraint_axis == ConstraintAxis.X:
			projection_query.x = previous_path_point.x
		else:
			projection_query.y = previous_path_point.y
	var closest_offset: float = curve.get_closest_offset(projection_query)
	var path_point: Vector2 = curve.sample_baked(closest_offset, true)
	_last_path_point_by_camera[camera_id] = path_point
	if constraint_axis == ConstraintAxis.X:
		path_local_position.x = path_point.x
	else:
		path_local_position.y = path_point.y
	return to_global(path_local_position)


func reset_camera_path_state(camera: Node2D) -> void:
	if is_instance_valid(camera):
		_last_path_point_by_camera.erase(camera.get_instance_id())


func forget_camera(camera: Node2D) -> void:
	if is_instance_valid(camera):
		_last_path_point_by_camera.erase(camera.get_instance_id())
	super.forget_camera(camera)


func _should_draw_influence_debug() -> bool:
	return Engine.is_editor_hint() or super._should_draw_influence_debug()


func _draw_influence_debug() -> void:
	var points: PackedVector2Array = _get_path_points()
	if points.size() >= 2:
		draw_polyline(points, DEBUG_COLOR, DEBUG_STROKE_WIDTH, false)
		draw_rect(
			Rect2(curve.get_point_position(0) - ENDPOINT_SIZE * 0.5, ENDPOINT_SIZE),
			DEBUG_COLOR,
			false,
			DEBUG_STROKE_WIDTH
		)
		var last_index: int = curve.get_point_count() - 1
		draw_rect(
			Rect2(curve.get_point_position(last_index) - ENDPOINT_SIZE * 0.5, ENDPOINT_SIZE),
			DEBUG_COLOR,
			false,
			DEBUG_STROKE_WIDTH
		)
	for camera_id: int in _last_path_point_by_camera:
		var path_point: Vector2 = _last_path_point_by_camera[camera_id]
		draw_circle(path_point, 5.0, DEBUG_COLOR)


func _get_path_points() -> PackedVector2Array:
	if curve == null:
		return PackedVector2Array()
	var path_points: PackedVector2Array = curve.get_baked_points()
	if path_points.is_empty():
		for point_index: int in range(curve.get_point_count()):
			path_points.append(curve.get_point_position(point_index))
	return path_points


func _rebuild_automatic_handles(first_index: int, last_index: int) -> void:
	if curve == null:
		return
	var point_count: int = curve.get_point_count()
	var start_index: int = maxi(first_index, 0)
	var end_index: int = mini(last_index, point_count - 1)
	for point_index: int in range(start_index, end_index + 1):
		if not get_path_point_smooth(point_index):
			curve.set_point_in(point_index, Vector2.ZERO)
			curve.set_point_out(point_index, Vector2.ZERO)
			continue
		var point_position: Vector2 = curve.get_point_position(point_index)
		var tangent: Vector2 = Vector2.ZERO
		var handle_length: float = 0.0
		if point_count == 1:
			pass
		elif point_index == 0:
			var next_delta: Vector2 = curve.get_point_position(1) - point_position
			tangent = next_delta.normalized()
			handle_length = next_delta.length() / 3.0
		elif point_index == point_count - 1:
			var previous_delta: Vector2 = point_position - curve.get_point_position(point_index - 1)
			tangent = previous_delta.normalized()
			handle_length = previous_delta.length() / 3.0
		else:
			var previous_delta: Vector2 = point_position - curve.get_point_position(point_index - 1)
			var next_delta: Vector2 = curve.get_point_position(point_index + 1) - point_position
			var previous_length: float = previous_delta.length()
			var next_length: float = next_delta.length()
			if previous_length > 0.0001 and next_length > 0.0001:
				tangent = (previous_delta / previous_length + next_delta / next_length).normalized()
				handle_length = minf(previous_length, next_length) / 3.0
				if tangent.is_zero_approx():
					tangent = next_delta.normalized()
		curve.set_point_in(point_index, -tangent * handle_length)
		curve.set_point_out(point_index, tangent * handle_length)


func _connect_curve() -> void:
	if curve == null:
		return
	curve.resource_local_to_scene = true
	if _connected_curve == curve:
		return
	_disconnect_curve()
	_connected_curve = curve
	_connected_curve.changed.connect(_on_curve_changed)


func _disconnect_curve() -> void:
	if _connected_curve != null and _connected_curve.changed.is_connected(_on_curve_changed):
		_connected_curve.changed.disconnect(_on_curve_changed)
	_connected_curve = null


func _suspend_curve_updates() -> bool:
	if _connected_curve == null or not _connected_curve.changed.is_connected(_on_curve_changed):
		return false
	_connected_curve.changed.disconnect(_on_curve_changed)
	return true


func _resume_curve_updates(was_connected: bool) -> void:
	if (
		was_connected
		and _connected_curve == curve
		and not _connected_curve.changed.is_connected(_on_curve_changed)
	):
		_connected_curve.changed.connect(_on_curve_changed)


func _on_curve_changed() -> void:
	_last_path_point_by_camera.clear()
	_influence_shape_changed()
	if Engine.is_editor_hint():
		update_configuration_warnings()
