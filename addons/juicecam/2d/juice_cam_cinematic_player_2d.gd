@tool
class_name JuiceCamCinematicPlayer2D
extends RefCounted

## Per-camera sequence state machine. Cinematic scene nodes are immutable
## configuration while playing; this class owns ordering, holds, and signals.

signal cinematic_started(sequence_name: StringName)
signal cinematic_stopped(sequence_name: StringName)
signal cinematic_completed(sequence_name: StringName)
signal cinematic_not_found(sequence_name: StringName)
signal cinematic_point_started(sequence_name: StringName, point: JuiceCamCinematic2D)
signal cinematic_point_arrived(sequence_name: StringName, point: JuiceCamCinematic2D)
signal cinematic_point_completed(sequence_name: StringName, point: JuiceCamCinematic2D)

var _sequence_name: StringName = &""
var _points: Array[JuiceCamCinematic2D] = []
var _point_index: int = -1
var _hold_elapsed: float = 0.0
var _has_arrived: bool = false
var _playback_generation: int = 0
var _warned_duplicate_position_ids: Dictionary[StringName, bool] = {}

var is_playing: bool:
	get:
		return not _points.is_empty() and _point_index >= 0


func start(camera: Node2D, sequence_name: StringName) -> bool:
	var points: Array[JuiceCamCinematic2D] = _collect_points(camera, sequence_name)
	if points.is_empty():
		cinematic_not_found.emit(sequence_name)
		return false
	_warn_duplicate_position_ids(points, sequence_name)

	if is_playing:
		stop()
	_playback_generation += 1
	var generation: int = _playback_generation
	_sequence_name = sequence_name
	_points = points
	_point_index = 0
	_hold_elapsed = 0.0
	_has_arrived = false
	cinematic_started.emit(_sequence_name)
	if generation == _playback_generation and is_playing:
		_emit_current_point_started()
	return true


func stop() -> void:
	if not is_playing:
		return
	var stopped_name: StringName = _sequence_name
	_clear()
	cinematic_stopped.emit(stopped_name)


func get_current_point() -> JuiceCamCinematic2D:
	if not is_playing:
		return null
	if _point_index >= _points.size():
		stop()
		return null
	var point: JuiceCamCinematic2D = _points[_point_index]
	if not is_instance_valid(point) or not point.enabled or not point.is_inside_tree():
		stop()
		return null
	return point


func get_active_sequence_name() -> StringName:
	return _sequence_name if is_playing else &""


func update_progress(delta: float, has_arrived: bool) -> void:
	var point: JuiceCamCinematic2D = get_current_point()
	if point == null or not has_arrived:
		return

	var generation: int = _playback_generation
	var arrived_this_frame: bool = false
	if not _has_arrived:
		_has_arrived = true
		_hold_elapsed = 0.0
		arrived_this_frame = true
		cinematic_point_arrived.emit(_sequence_name, point)
		if generation != _playback_generation or not is_playing:
			return

	if point.hold_time <= 0.0:
		_complete_current_point()
		return
	if not arrived_this_frame and delta > 0.0:
		_hold_elapsed += delta
	if _hold_elapsed >= point.hold_time:
		_complete_current_point()


func _collect_points(camera: Node2D, sequence_name: StringName) -> Array[JuiceCamCinematic2D]:
	var result: Array[JuiceCamCinematic2D] = []
	if sequence_name == &"" or not is_instance_valid(camera) or not camera.is_inside_tree():
		return result
	var camera_viewport: Viewport = camera.get_viewport()
	for candidate: Node in camera.get_tree().get_nodes_in_group(JuiceCamCinematic2D.GROUP_NAME):
		if not candidate is JuiceCamCinematic2D:
			continue
		var point: JuiceCamCinematic2D = candidate as JuiceCamCinematic2D
		if (
			point.enabled
			and not point.is_queued_for_deletion()
			and StringName(point.sequence_name) == sequence_name
			and point.get_viewport() == camera_viewport
		):
			result.append(point)
	result.sort_custom(_sort_points)
	return result


func _warn_duplicate_position_ids(
	points: Array[JuiceCamCinematic2D],
	sequence_name: StringName
) -> void:
	var first_point_by_position: Dictionary[int, JuiceCamCinematic2D] = {}
	for point: JuiceCamCinematic2D in points:
		var position_id: int = point.sequence_position
		if not first_point_by_position.has(position_id):
			first_point_by_position[position_id] = point
			continue
		var warning_key: StringName = StringName("%s:%d" % [String(sequence_name), position_id])
		if _warned_duplicate_position_ids.has(warning_key):
			continue
		_warned_duplicate_position_ids[warning_key] = true
		var first_point: JuiceCamCinematic2D = first_point_by_position[position_id]
		var warning_message: String = (
			"JuiceCam cinematic '%s' has duplicate position ID %d in this viewport: '%s' and '%s'. "
			+ "Give each enabled point a unique sequence_position; duplicate IDs use scene-path order."
		)
		push_warning(warning_message % [
			String(sequence_name),
			position_id,
			str(first_point.get_path()),
			str(point.get_path()),
		])


func _sort_points(a: JuiceCamCinematic2D, b: JuiceCamCinematic2D) -> bool:
	if a.sequence_position != b.sequence_position:
		return a.sequence_position < b.sequence_position
	return str(a.get_path()) < str(b.get_path())


func _emit_current_point_started() -> void:
	var point: JuiceCamCinematic2D = get_current_point()
	if point != null:
		cinematic_point_started.emit(_sequence_name, point)


func _complete_current_point() -> void:
	var completed_point: JuiceCamCinematic2D = get_current_point()
	if completed_point == null:
		return
	var completed_name: StringName = _sequence_name
	var generation: int = _playback_generation
	_point_index += 1
	_hold_elapsed = 0.0
	_has_arrived = false
	if _point_index >= _points.size():
		_clear()
		cinematic_point_completed.emit(completed_name, completed_point)
		cinematic_completed.emit(completed_name)
		cinematic_stopped.emit(completed_name)
		return
	cinematic_point_completed.emit(completed_name, completed_point)
	if generation != _playback_generation or not is_playing:
		return
	_emit_current_point_started()


func _clear() -> void:
	_playback_generation += 1
	_sequence_name = &""
	_points.clear()
	_point_index = -1
	_hold_elapsed = 0.0
	_has_arrived = false
